import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/data/local/local_home.dart';
import '../data/device_probe.dart';
import '../data/lan_discovery.dart';

/// Shelly and WLED devices found on the network while the screen is open.
/// Each address is asked once. A device already added that answers at a
/// new address (DHCP) gets its address updated.
final discoveredDevicesProvider =
    StreamProvider.autoDispose<List<ProbedDevice>>((ref) {
      final discovery = ref.watch(lanDiscoveryProvider);
      if (!discovery.isSupported) return Stream.value(const []);
      final probe = ref.watch(deviceProbeProvider);
      final controller = StreamController<List<ProbedDevice>>();
      final probed = <String, ProbedDevice?>{};

      Future<void> ask(String host) async {
        final found = await probe.probe(host);
        if (controller.isClosed) return;
        probed[host] = found;
        if (found != null) {
          final home = ref.read(localHomeProvider);
          final known = home.devices
              .where((d) => d.key == found.device.key)
              .firstOrNull;
          if (known != null && known.host != host) {
            unawaited(
              ref.read(localHomeProvider.notifier).updateHost(known.key, host),
            );
          }
        }
        controller.add([for (final p in probed.values) ?p]);
      }

      final sub = discovery.browse().listen((services) {
        for (final s in services) {
          if (probed.containsKey(s.host)) continue;
          probed[s.host] = null; // asking
          unawaited(ask(s.host));
        }
      });
      ref.onDispose(() {
        unawaited(sub.cancel());
        unawaited(controller.close());
      });
      controller.add(const []);
      return controller.stream;
    });
