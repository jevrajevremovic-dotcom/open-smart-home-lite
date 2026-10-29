import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/server_address.dart';
import '../../../integrations/home_assistant/api/home_assistant_api.dart';
import '../../../integrations/home_assistant/home_assistant_providers.dart';
import '../../authentication/application/session_controller.dart';
import '../../authentication/application/web_login.dart';
import '../../authentication/data/server_profile.dart';
import '../../authentication/domain/stored_credential.dart';

enum ProbeStatus { idle, checking, reachable, failed }

@immutable
class ConnectionSetupState {
  const ConnectionSetupState({
    this.address,
    this.addressError,
    this.insecureAcknowledged = false,
    this.pinnedCertificateSha256,
    this.probeStatus = ProbeStatus.idle,
    this.failure,
    this.authenticating = false,
    this.authFailure,
  });

  final ServerAddress? address;
  final ServerAddressError? addressError;
  final bool insecureAcknowledged;
  final String? pinnedCertificateSha256;
  final ProbeStatus probeStatus;
  final AppFailure? failure;
  final bool authenticating;
  final AppFailure? authFailure;

  bool get needsInsecureAcknowledgement =>
      address?.risk == ConnectionRisk.insecureRemote && !insecureAcknowledged;

  ServerProfile? get profile => address == null
      ? null
      : ServerProfile(
          address: address!,
          pinnedCertificateSha256: pinnedCertificateSha256,
          insecureConnectionAcknowledged: insecureAcknowledged,
        );

  ConnectionSetupState copyWith({
    ServerAddress? address,
    ServerAddressError? addressError,
    bool? insecureAcknowledged,
    String? pinnedCertificateSha256,
    ProbeStatus? probeStatus,
    AppFailure? failure,
    bool? authenticating,
    AppFailure? authFailure,
    bool clearAddressError = false,
    bool clearFailure = false,
    bool clearAuthFailure = false,
  }) => ConnectionSetupState(
    address: address ?? this.address,
    addressError: clearAddressError
        ? null
        : (addressError ?? this.addressError),
    insecureAcknowledged: insecureAcknowledged ?? this.insecureAcknowledged,
    pinnedCertificateSha256:
        pinnedCertificateSha256 ?? this.pinnedCertificateSha256,
    probeStatus: probeStatus ?? this.probeStatus,
    failure: clearFailure ? null : (failure ?? this.failure),
    authenticating: authenticating ?? this.authenticating,
    authFailure: clearAuthFailure ? null : (authFailure ?? this.authFailure),
  );
}

/// Drives the "server address → access token" onboarding flow.
class ConnectionSetupController extends Notifier<ConnectionSetupState> {
  static final _log = AppLogger('ConnectionSetup');

  @override
  ConnectionSetupState build() => const ConnectionSetupState();

  void reset() => state = const ConnectionSetupState();

  void setInsecureAcknowledged(bool value) =>
      state = state.copyWith(insecureAcknowledged: value);

  /// Validates [input] and checks that a Home Assistant API answers there.
  /// Returns `true` when the user can continue to the token step.
  Future<bool> checkServer(String input) async {
    final parsed = ServerAddress.parse(input);
    switch (parsed) {
      case InvalidServerAddress(:final error):
        state = ConnectionSetupState(addressError: error);
        return false;
      case ValidServerAddress(:final address)
          when _blockedAsMixedContent(address):
        state = const ConnectionSetupState(
          addressError: ServerAddressError.blockedMixedContent,
        );
        return false;
      case ValidServerAddress(:final address):
        final sameAddress = address == state.address;
        state = ConnectionSetupState(
          address: address,
          // Acknowledgement and certificate pin only apply to the same server.
          insecureAcknowledged: sameAddress && state.insecureAcknowledged,
          pinnedCertificateSha256: sameAddress
              ? state.pinnedCertificateSha256
              : null,
        );
    }
    if (state.needsInsecureAcknowledgement) return false;
    return _probe();
  }

  bool _blockedAsMixedContent(ServerAddress address) {
    if (!ref.read(platformInfoProvider).isSecurePage || address.isSecure) {
      return false;
    }
    // Browsers treat loopback as potentially trustworthy and allow it.
    return !const {'localhost', '127.0.0.1', '::1'}.contains(address.host);
  }

  /// Pins the certificate the user reviewed and probes again.
  Future<bool> trustCertificate(String sha256Fingerprint) async {
    state = state.copyWith(pinnedCertificateSha256: sha256Fingerprint);
    return _probe();
  }

  Future<bool> _probe() async {
    final profile = state.profile;
    if (profile == null) return false;
    state = state.copyWith(
      probeStatus: ProbeStatus.checking,
      clearFailure: true,
    );
    final api = ref.read(homeAssistantApiFactoryProvider)(
      profile,
      () async => null,
    );
    try {
      final result = await api.probe();
      if (result == ServerProbeResult.reachableRequiresAuth) {
        state = state.copyWith(probeStatus: ProbeStatus.reachable);
        return true;
      }
      state = state.copyWith(
        probeStatus: ProbeStatus.failed,
        failure: const AppFailure(
          FailureKind.server,
          debugMessage: 'response does not look like Home Assistant',
        ),
      );
    } on AppFailure catch (e) {
      _log.info('Probe failed: $e');
      state = state.copyWith(probeStatus: ProbeStatus.failed, failure: e);
    } finally {
      api.close();
    }
    return false;
  }

  /// Web only: continues on Home Assistant's own login page (OAuth2).
  void startWebSignIn({required bool remember}) {
    final profile = state.profile;
    if (profile == null) return;
    ref.read(webLoginServiceProvider).start(profile, remember: remember);
  }

  /// Shows a sign-in error that happened outside this controller.
  void reportAuthFailure(AppFailure failure) =>
      state = state.copyWith(authenticating: false, authFailure: failure);

  /// Finishes the in-app OAuth2 sign-in: exchanges [code] for tokens,
  /// checks they work, and signs in. The refresh token is bound to
  /// [clientId] and revoked again on sign-out.
  Future<bool> signInWithCode(String code, String clientId) async {
    final profile = state.profile;
    if (profile == null) return false;
    state = state.copyWith(authenticating: true, clearAuthFailure: true);
    try {
      final response = await ref
          .read(haAuthClientFactoryProvider)(profile)
          .exchangeCode(code: code, clientId: clientId);
      final refresh = response.refreshToken;
      if (refresh == null) {
        throw const AppFailure(
          FailureKind.parsing,
          debugMessage: 'no refresh token in code exchange',
        );
      }
      final api = ref.read(homeAssistantApiFactoryProvider)(
        profile,
        () async => response.accessToken,
      );
      try {
        final config = await api.fetchConfig(); // proves it really is HA
        _log.info('Signed in with OAuth2 to Home Assistant ${config.version}');
      } finally {
        api.close();
      }
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(
            profile,
            OAuthTokens(
              accessToken: response.accessToken,
              refreshToken: refresh,
              clientId: clientId,
              expiresAt: DateTime.now().add(response.expiresIn),
            ),
          );
      state = const ConnectionSetupState();
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(authenticating: false, authFailure: e);
      return false;
    }
  }

  /// Verifies [rawToken] against the server and, on success, signs in.
  Future<bool> authenticate(String rawToken) async {
    final profile = state.profile;
    final token = rawToken.trim();
    if (profile == null) return false;
    if (token.isEmpty || token.length > 4096 || token.contains(RegExp(r'\s'))) {
      state = state.copyWith(
        authFailure: const AppFailure(
          FailureKind.validation,
          debugMessage: 'token format',
        ),
      );
      return false;
    }
    state = state.copyWith(authenticating: true, clearAuthFailure: true);
    final api = ref.read(homeAssistantApiFactoryProvider)(
      profile,
      () async => token,
    );
    try {
      await api.verifyAccessToken();
      final config = await api.fetchConfig(); // proves it really is HA
      _log.info('Token accepted by Home Assistant ${config.version}');
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(profile, LongLivedToken(token, persistent: false));
      state = const ConnectionSetupState();
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(authenticating: false, authFailure: e);
      return false;
    } finally {
      api.close();
    }
  }
}

final connectionSetupControllerProvider =
    NotifierProvider<ConnectionSetupController, ConnectionSetupState>(
      ConnectionSetupController.new,
    );
