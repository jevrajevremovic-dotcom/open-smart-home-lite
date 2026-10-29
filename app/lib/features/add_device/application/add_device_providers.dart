import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/data/local/ble/ble_scanner.dart';
import '../../devices/data/local/kasa_adapter.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/data/local/yeelight_adapter.dart';
import '../data/device_probe.dart';
import '../data/lan_discovery.dart';

/// Devices found on the network while the screen is open: announced by
/// mDNS (Shelly, WLED, Hue, ESPHome; each address asked once) or answering
/// a search of their own (Yeelight, Kasa). A device already added that
/// answers at a new address (DHCP) gets its address updated.
final discoveredDevicesProvider =
    StreamProvider.autoDispose<List<ProbedDevice>>((ref) {
      final discovery = ref.watch(lanDiscoveryProvider);
      final probe = ref.watch(deviceProbeProvider);
      final controller = StreamController<List<ProbedDevice>>();
      final probed = <String, ProbedDevice?>{};
      final searched = <String, ProbedDevice>{};

      void emit() {
        if (controller.isClosed) return;
        controller.add([for (final p in probed.values) ?p, ...searched.values]);
      }

      void follow(ProbedDevice found) {
        final known = ref
            .read(localHomeProvider)
            .devices
            .where((d) => d.key == found.device.key)
            .firstOrNull;
        if (known != null && known.host != found.device.host) {
          unawaited(
            ref
                .read(localHomeProvider.notifier)
                .updateHost(known.key, found.device.host),
          );
        }
      }

      Future<void> ask(LanService service, String id) async {
        final found = await probe.probeService(service);
        if (controller.isClosed) return;
        probed[id] = found;
        if (found != null) follow(found);
        emit();
      }

      void add(ProbedDevice? found) {
        if (found == null) return;
        searched[found.device.key] = found;
        follow(found);
      }

      final subscriptions = <StreamSubscription<Object?>>[
        if (discovery.isSupported)
          discovery.browse().listen((services) {
            for (final s in services) {
              final id = '${s.type}/${s.host}';
              if (probed.containsKey(id)) continue;
              probed[id] = null; // asking
              unawaited(ask(s, id));
            }
          }),
        ref.read(yeelightTransportProvider).discover().listen((bulbs) {
          bulbs.map(DeviceProbe.fromYeelight).forEach(add);
          emit();
        }, onError: (Object _) {}),
        ref.read(kasaTransportProvider).discover().listen((found) {
          for (final f in found) {
            add(DeviceProbe.fromKasa(f.host, f.sysinfo));
          }
          emit();
        }, onError: (Object _) {}),
      ];
      ref.onDispose(() {
        for (final s in subscriptions) {
          unawaited(s.cancel());
        }
        unawaited(controller.close());
      });
      controller.add(const []);
      return controller.stream;
    });

/// Bluetooth sensors heard nearby while the screen is open (strongest
/// first). Fails with `BleScanError` (no permission, Bluetooth off).
final bleNearbyProvider = StreamProvider.autoDispose<List<ProbedDevice>>((
  ref,
) async* {
  final scanner = ref.watch(bleScannerProvider);
  if (!scanner.supported) throw const BleScanError('unsupported');
  if (!await scanner.hasPermission()) throw const BleScanError('permission');
  final heard = <String, (ProbedDevice, int)>{};
  yield const [];
  await for (final advert in scanner.scan()) {
    final found = DeviceProbe.fromBle(advert);
    if (found == null) continue;
    heard[advert.id] = (found, advert.rssi ?? -100);
    yield [
      for (final e
          in heard.values.toList()..sort((a, b) => b.$2.compareTo(a.$2)))
        e.$1,
    ];
  }
});
