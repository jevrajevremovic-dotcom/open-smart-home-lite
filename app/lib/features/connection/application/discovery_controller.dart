import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/server_discovery.dart';

@immutable
class DiscoveryState {
  const DiscoveryState({
    this.searching = false,
    this.servers = const [],
    this.finished = false,
  });

  final bool searching;
  final List<DiscoveredServer> servers;

  /// A search ran to its end (used to show "nothing found").
  final bool finished;
}

/// Runs a time-limited network search for Home Assistant servers while the
/// server-address screen is visible.
class DiscoveryController extends Notifier<DiscoveryState> {
  static const searchDuration = Duration(seconds: 10);

  StreamSubscription<List<DiscoveredServer>>? _subscription;
  Timer? _timer;

  @override
  DiscoveryState build() {
    ref.onDispose(_stop);
    return const DiscoveryState();
  }

  bool get isSupported => ref.read(serverDiscoveryProvider).isSupported;

  void start() {
    if (!isSupported) return;
    _stop();
    state = const DiscoveryState(searching: true);
    _subscription = ref
        .read(serverDiscoveryProvider)
        .discover()
        .listen(
          (servers) =>
              state = DiscoveryState(searching: true, servers: servers),
          onError: (Object _) => _finish(),
          onDone: _finish,
        );
    _timer = Timer(searchDuration, _finish);
  }

  void _finish() {
    _stop();
    state = DiscoveryState(servers: state.servers, finished: true);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

final discoveryControllerProvider =
    NotifierProvider.autoDispose<DiscoveryController, DiscoveryState>(
      DiscoveryController.new,
    );
