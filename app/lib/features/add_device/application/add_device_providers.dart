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

      Future<void> ask(LanService service, String id) async {
        final found = await probe.probeService(service);
        if (controller.isClosed) return;
        probed[id] = found;
        if (found != null) {
          final home = ref.read(localHomeProvider);
          final known = home.devices
              .where((d) => d.key == found.device.key)
              .firstOrNull;
          if (known != null && known.host != service.host) {
            unawaited(
              ref
                  .read(localHomeProvider.notifier)
                  .updateHost(known.key, service.host),
            );
          }
        }
        controller.add([for (final p in probed.values) ?p]);
      }

      final sub = discovery.browse().listen((services) {
        for (final s in services) {
          final id = '${s.type}/${s.host}';
          if (probed.containsKey(id)) continue;
          probed[id] = null; // asking
          unawaited(ask(s, id));
        }
      });
      ref.onDispose(() {
        unawaited(sub.cancel());
        unawaited(controller.close());
      });
      controller.add(const []);
      return controller.stream;
    });
