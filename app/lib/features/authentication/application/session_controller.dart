import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/server_address.dart';
import '../../../core/storage/credential_store.dart';
import '../../../integrations/home_assistant/api/home_assistant_api.dart';
import '../../../integrations/home_assistant/home_assistant_providers.dart';
import '../../../integrations/home_assistant/models/ha_models.dart';
import '../../../integrations/home_assistant/websocket/connection_status.dart';
import '../../../integrations/home_assistant/websocket/ha_websocket_manager.dart';
import '../../connection/application/connection_route.dart';
import '../../first_run/first_run_controller.dart';
import '../data/server_profile.dart';
import '../data/session_repository.dart';
import '../domain/stored_credential.dart';
import 'access_token_manager.dart';
import 'web_login.dart';

/// The signed-in state. `null` in [SessionController] means signed out.
@immutable
class Session {
  const Session(this.profile);
  final ServerProfile profile;
}

class SessionController extends AsyncNotifier<Session?> {
  static final _log = AppLogger('Session');

  SessionRepository get _repository => ref.read(sessionRepositoryProvider);

  // Built directly (not via accessTokenManagerProvider, which depends on
  // this notifier) to revoke OAuth2 tokens during sign-out.
  AccessTokenManager _tokenManagerFor(ServerProfile profile) =>
      AccessTokenManager(
        serverId: profile.id,
        store: ref.read(credentialStoreProvider),
        authClient: () => ref.read(haAuthClientFactoryProvider)(profile),
      );

  @override
  Future<Session?> build() async {
    // Web: returning from Home Assistant's login page with ?code=…&state=…
    final webLogin = ref.read(webLoginServiceProvider);
    if (webLogin.hasCallback) {
      try {
        await webLogin.complete();
        ref.read(firstRunProvider.notifier).signedIn();
      } on AppFailure catch (e) {
        _log.warning('Web sign-in failed', e);
        // Report after build so listeners exist.
        unawaited(
          Future.microtask(() => ref.read(loginErrorProvider.notifier).set(e)),
        );
      }
    }
    final profile = await _repository.loadProfile();
    return profile == null ? null : Session(profile);
  }

  /// Persists a profile whose credential was already verified by the caller.
  Future<void> signIn(
    ServerProfile profile,
    StoredCredential credential,
  ) async {
    await _repository.save(profile, credential);
    _log.info('Signed in to ${profile.address.host}');
    final addedAnother = ref.read(addingHomeProvider);
    ref.read(addingHomeProvider.notifier).set(false);
    if (!addedAnother) ref.read(firstRunProvider.notifier).signedIn();
    state = AsyncData(Session(profile));
  }

  /// Sets or clears the active home's address for use away from home.
  Future<void> setRemoteAddress(ServerAddress? remote) async {
    final profile = state.value?.profile;
    if (profile == null || profile.remoteAddress == remote) return;
    final updated = profile.withRemoteAddress(remote);
    await _repository.update(updated);
    state = AsyncData(Session(updated));
  }

  /// Switches to another saved home (its credential is already stored).
  Future<void> switchTo(ServerProfile profile) async {
    if (state.value?.profile.id == profile.id) return;
    await _repository.activate(profile);
    _log.info('Switched to ${profile.address.host}');
    state = AsyncData(Session(profile));
  }

  /// Revokes OAuth2 tokens (best effort), closes connections and deletes the
  /// stored credential.
  Future<void> signOut() async {
    final profile = state.value?.profile;
    if (profile != null) await _tokenManagerFor(profile).revoke();
    state = const AsyncData(null); // disposes session-scoped providers
    final next = await _repository.signOut(profile);
    _log.info('Signed out');
    // Another saved home takes over, if there is one.
    if (next != null) state = AsyncData(Session(next));
  }

  /// Signs out and wipes every local value, including theme and language.
  Future<void> deleteAllLocalData() async {
    final profile = state.value?.profile;
    if (profile != null) await _tokenManagerFor(profile).revoke();
    state = const AsyncData(null);
    await _repository.deleteAllLocalData();
    _log.info('All local data deleted');
  }
}

/// `true` while the user adds another home from Settings: the connect
/// screens are then reachable although a session exists.
class AddingHomeController extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool adding) => state = adding;
}

final addingHomeProvider = NotifierProvider<AddingHomeController, bool>(
  AddingHomeController.new,
);

/// Saved homes with their display names, active first.
final savedHomesProvider =
    FutureProvider<List<({ServerProfile profile, String name})>>((ref) async {
      final active = ref.watch(activeProfileProvider);
      final repo = ref.watch(sessionRepositoryProvider);
      final names = repo.homeNames();
      final profiles = await repo.savedProfiles();
      return [
        for (final p in profiles)
          (profile: p, name: names[p.id] ?? p.address.host),
      ]..sort((a, b) {
        if (a.profile.id == active?.id) return -1;
        if (b.profile.id == active?.id) return 1;
        return a.name.compareTo(b.name);
      });
    });

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

/// The active server profile, or `null` when signed out.
final activeProfileProvider = Provider<ServerProfile?>(
  (ref) => ref.watch(sessionControllerProvider).value?.profile,
);

/// Valid access tokens for the active session (refreshes OAuth2 tokens).
final accessTokenManagerProvider = Provider<AccessTokenManager?>((ref) {
  final profile = ref.watch(activeProfileProvider);
  if (profile == null) return null;
  final authClients = ref.watch(haAuthClientFactoryProvider);
  return AccessTokenManager(
    serverId: profile.id,
    store: ref.watch(credentialStoreProvider),
    authClient: () => authClients(profile),
  );
});

/// The active profile as reached right now: through its home address or,
/// away from home, through its remote one (see [connectionRouteProvider]).
final effectiveProfileProvider = Provider<ServerProfile?>((ref) {
  final profile = ref.watch(activeProfileProvider);
  final remote = profile?.remoteAddress;
  if (profile == null || remote == null) return profile;
  return ref.watch(connectionRouteProvider) == ConnectionRoute.remote
      ? profile.via(remote)
      : profile;
});

/// REST client for the active session.
final homeAssistantApiProvider = Provider<HomeAssistantApi?>((ref) {
  final profile = ref.watch(effectiveProfileProvider);
  final tokens = ref.watch(accessTokenManagerProvider);
  if (profile == null || tokens == null) return null;
  final api = ref.watch(homeAssistantApiFactoryProvider)(
    profile,
    tokens.accessToken,
  );
  ref.onDispose(api.close);
  return api;
});

/// The WebSocket manager lives exactly as long as the session.
final webSocketManagerProvider = Provider<HaWebSocketManager?>((ref) {
  final profile = ref.watch(effectiveProfileProvider);
  final tokens = ref.watch(accessTokenManagerProvider);
  if (profile == null || tokens == null) return null;
  final manager = HaWebSocketManager(
    uri: profile.address.webSocketUri,
    readToken: tokens.accessToken,
    connector: ref.watch(haSocketConnectorFactoryProvider)(profile.tlsTrust),
  )..connect();
  ref.onDispose(() => unawaited(manager.dispose()));
  return manager;
});

final connectionStatusProvider = StreamProvider<HaConnectionStatus>((
  ref,
) async* {
  final manager = ref.watch(webSocketManagerProvider);
  if (manager == null) {
    yield HaConnectionStatus.initial;
    return;
  }
  yield manager.status;
  yield* manager.statusStream;
});

/// `GET /api/config` for the active session.
final serverConfigProvider = FutureProvider<HaConfig?>((ref) async {
  final api = ref.watch(homeAssistantApiProvider);
  return api?.fetchConfig();
});
