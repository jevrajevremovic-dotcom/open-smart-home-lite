import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/browser_port.dart';
import '../../../integrations/home_assistant/home_assistant_providers.dart';
import '../data/server_profile.dart';
import '../data/session_repository.dart';
import '../domain/stored_credential.dart';

/// OAuth2 authorization-code sign-in for the web build.
///
/// The app's own URL is both `client_id` (its origin) and `redirect_uri`.
/// Home Assistant accepts a redirect on the same host as the client id
/// without fetching anything, so this works fully offline on a LAN – the
/// same way Home Assistant's own frontend signs in.
class WebLoginService {
  WebLoginService(this._ref);

  final Ref _ref;
  static const _pendingKey = 'oauth_pending_login';
  static final _log = AppLogger('WebLogin');

  BrowserPort get _browser => _ref.read(browserPortProvider);

  bool get isSupported => _browser.isAvailable;

  String get _clientId {
    final url = _browser.currentUrl;
    return '${url.origin}/';
  }

  /// Remembers what we are doing, then leaves for Home Assistant's login
  /// page. Nothing secret is stored: only the server and a random state.
  void start(ServerProfile profile, {required bool remember}) {
    final state = _randomState();
    final redirect = _cleanRedirect();
    _browser.sessionSet(
      _pendingKey,
      jsonEncode({
        'state': state,
        'profile': profile.toJson(),
        'remember': remember,
        'clientId': _clientId,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    final url = _ref
        .read(haAuthClientFactoryProvider)(profile)
        .authorizeUrl(clientId: _clientId, redirectUri: redirect, state: state);
    _log.info('Redirecting to Home Assistant login');
    _browser.navigate(url);
  }

  /// `true` when the page was opened by Home Assistant's redirect.
  bool get hasCallback {
    if (!_browser.isAvailable) return false;
    final q = _browser.currentUrl.queryParameters;
    return q.containsKey('code') && q.containsKey('state');
  }

  /// Exchanges the code from the callback URL and saves the session.
  /// Always removes the code from the address bar and the pending state.
  Future<ServerProfile> complete() async {
    final url = _browser.currentUrl;
    final code = url.queryParameters['code'];
    final state = url.queryParameters['state'];
    final pendingRaw = _browser.sessionGet(_pendingKey);
    _browser
      ..sessionRemove(_pendingKey)
      ..replaceUrl(
        _cleanRedirect().replace(
          fragment: url.fragment.isEmpty ? null : url.fragment,
        ),
      );

    final pending = pendingRaw == null ? null : jsonDecode(pendingRaw);
    if (code == null ||
        state == null ||
        pending is! Map<String, Object?> ||
        pending['state'] != state) {
      // Protects against login CSRF: only accept a callback we started.
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'OAuth state mismatch or no pending login',
      );
    }
    final createdAt = DateTime.tryParse(pending['createdAt'] as String? ?? '');
    if (createdAt == null ||
        DateTime.now().difference(createdAt) > const Duration(minutes: 15)) {
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'OAuth login expired',
      );
    }
    final profile = ServerProfile.tryFromJson(
      pending['profile'] as Map<String, Object?>?,
    );
    final clientId = pending['clientId'];
    if (profile == null || clientId is! String) {
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'pending login is corrupt',
      );
    }

    final response = await _ref
        .read(haAuthClientFactoryProvider)(profile)
        .exchangeCode(code: code, clientId: clientId);
    final refresh = response.refreshToken;
    if (refresh == null) {
      throw const AppFailure(
        FailureKind.parsing,
        debugMessage: 'no refresh token in code exchange',
      );
    }
    await _ref
        .read(sessionRepositoryProvider)
        .save(
          profile,
          OAuthTokens(
            accessToken: response.accessToken,
            refreshToken: refresh,
            clientId: clientId,
            expiresAt: DateTime.now().add(response.expiresIn),
            persistent: pending['remember'] == true,
          ),
        );
    _log.info('Signed in with OAuth2');
    return profile;
  }

  Uri _cleanRedirect() {
    final url = _browser.currentUrl;
    return Uri(
      scheme: url.scheme,
      host: url.host,
      port: url.hasPort ? url.port : null,
      path: url.path,
    );
  }

  static String _randomState() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(24, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }
}

final webLoginServiceProvider = Provider<WebLoginService>(WebLoginService.new);

/// Error of the last web sign-in attempt, shown on the welcome screen.
class LoginErrorController extends Notifier<AppFailure?> {
  @override
  AppFailure? build() => null;

  void set(AppFailure? failure) => state = failure;
}

final loginErrorProvider = NotifierProvider<LoginErrorController, AppFailure?>(
  LoginErrorController.new,
);
