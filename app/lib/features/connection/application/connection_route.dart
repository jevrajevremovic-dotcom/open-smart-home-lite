import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../integrations/home_assistant/api/home_assistant_api.dart';
import '../../../integrations/home_assistant/home_assistant_providers.dart';
import '../../authentication/application/session_controller.dart';
import '../../authentication/data/server_profile.dart';

/// Which address of the active home the app uses right now.
enum ConnectionRoute { local, remote }

/// Picks the home address when it answers, the remote address otherwise.
///
/// Starts on the home address; [reevaluate] is called when the connection
/// keeps failing and when the app comes back to the foreground, so it moves
/// to the remote address away from home and back again at home.
class ConnectionRouteController extends Notifier<ConnectionRoute> {
  static final _log = AppLogger('Route');

  /// How long the home address gets to answer before the remote one is
  /// tried. Short: on a foreign network it usually never answers at all.
  static const probeTimeout = Duration(seconds: 3);

  bool _busy = false;

  @override
  ConnectionRoute build() {
    // A different home (or a changed remote address) starts over at home.
    ref.watch(activeProfileProvider);
    return ConnectionRoute.local;
  }

  Future<bool> _reachable(ServerProfile profile) async {
    // Probing needs no token: an unauthenticated `GET /api/` answers 401.
    final api = ref.read(homeAssistantApiFactoryProvider)(
      profile,
      () async => null,
    );
    try {
      return await api.probe().timeout(probeTimeout) ==
          ServerProbeResult.reachableRequiresAuth;
    } on Object {
      return false;
    } finally {
      api.close();
    }
  }

  Future<void> reevaluate() async {
    final profile = ref.read(activeProfileProvider);
    final remote = profile?.remoteAddress;
    if (profile == null || remote == null || _busy) return;
    _busy = true;
    try {
      final ConnectionRoute? next = await _reachable(profile)
          ? ConnectionRoute.local
          : await _reachable(profile.via(remote))
          ? ConnectionRoute.remote
          : null; // neither answers: keep retrying where we are
      if (next == null || next == state) return;
      // The home changed meanwhile: its own route starts over.
      if (ref.read(activeProfileProvider) != profile) return;
      _log.info('Using the ${next.name} address');
      state = next;
    } finally {
      _busy = false;
    }
  }
}

final connectionRouteProvider =
    NotifierProvider<ConnectionRouteController, ConnectionRoute>(
      ConnectionRouteController.new,
    );
