import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../devices/data/local/local_home.dart';
import '../data/device_probe.dart';
import '../data/lan_discovery.dart';

/// Keeps the added devices' addresses current: when the app starts or
/// comes back, it looks around the network for a while, and a device that
/// answers at another address (the router gave it a new one) is followed.
/// Only addresses that are no added device's are asked.
class AddressKeeper {
  AddressKeeper(this._ref, {this.lookFor = const Duration(seconds: 30)});

  final Ref _ref;
  final Duration lookFor;
  static final _log = AppLogger('AddressKeeper');

  StreamSubscription<Object?>? _sub;
  Timer? _stop;

  bool get running => _sub != null;

  void check() {
    final discovery = _ref.read(lanDiscoveryProvider);
    final home = _ref.read(localHomeProvider);
    if (running || !discovery.isSupported || home.devices.isEmpty) return;
    final asked = <String>{};
    _sub = discovery.browse().listen((services) {
      final known = {
        for (final d in _ref.read(localHomeProvider).devices) d.host,
      };
      for (final s in services) {
        if (known.contains(s.host) || !asked.add('${s.type}/${s.host}')) {
          continue;
        }
        unawaited(_ask(s));
      }
    }, onDone: stop);
    _stop = Timer(lookFor, stop);
  }

  Future<void> _ask(LanService service) async {
    final host = service.host;
    final found = await _ref.read(deviceProbeProvider).probeService(service);
    if (found == null) return;
    final home = _ref.read(localHomeProvider);
    final known = home.devices
        .where((d) => d.key == found.device.key)
        .firstOrNull;
    if (known == null || known.host == host) return;
    _log.info('${known.key} moved to a new address');
    await _ref.read(localHomeProvider.notifier).updateHost(known.key, host);
  }

  void stop() {
    _stop?.cancel();
    _stop = null;
    unawaited(_sub?.cancel());
    _sub = null;
  }
}

final addressKeeperProvider = Provider<AddressKeeper>((ref) {
  final keeper = AddressKeeper(ref);
  ref.onDispose(keeper.stop);
  return keeper;
});
