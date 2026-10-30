import '../../restricted/application/restricted_mode.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/credential_store.dart';
import '../../../core/utils/value_list.dart';
import '../../automations/application/automation_engine.dart';
import '../data/local/ble/ble_adapter.dart';
import '../data/local/ble/ble_scanner.dart';
import '../data/local/demo_adapter.dart';
import '../data/local/esphome/esphome_adapter.dart';
import '../data/local/esphome/esphome_client.dart';
import '../data/local/hue_adapter.dart';
import '../data/local/dirigera_adapter.dart';
import '../data/local/kasa_adapter.dart';
import '../data/local/klap.dart';
import '../data/local/govee_adapter.dart';
import '../data/local/lan_transport.dart';
import '../data/local/lg_tv_adapter.dart';
import '../data/local/lifx_adapter.dart';
import '../data/local/miio.dart';
import '../data/local/nanoleaf_adapter.dart';
import '../data/local/roku_adapter.dart';
import '../data/local/samsung_tv_adapter.dart';
import '../data/local/sonoff_adapter.dart';
import '../data/local/sonos_adapter.dart';
import '../data/local/tapo_adapter.dart';
import '../data/local/tuya.dart';
import '../data/local/wiz_adapter.dart';
import '../data/local/lan_http.dart';
import '../data/local/local_backend.dart';
import '../data/local/local_home.dart';
import '../data/local/shelly_adapter.dart';
import '../data/local/tasmota_adapter.dart';
import '../data/local/wled_adapter.dart';
import '../data/local/yeelight_adapter.dart';
import '../domain/home_snapshot.dart';
import '../domain/device_kind.dart';
import '../domain/smart_home_device.dart';

/// Id of the home on this phone, for what is kept per home (favourites,
/// layout, tiles). There is one home for now.
final homeIdProvider = Provider<String>((ref) => 'local');

/// The home's backend: the devices the phone talks to itself (and the
/// demo home until the first real device is added). Follows the
/// household's changes to [localHomeProvider] without starting over.
final homeBackendProvider = Provider<LocalBackend?>((ref) {
  final http = ref.watch(lanHttpProvider);
  // A device's password, key or token, from the phone's secure storage.
  Future<String?> secret(String key) =>
      ref.read(credentialStoreProvider).readCredential(devicePasswordId(key));
  final backend = LocalBackend(
    [
      DemoAdapter(),
      ShellyAdapter(
        http,
        passwords: (key) => ref
            .read(credentialStoreProvider)
            .readCredential(devicePasswordId(key)),
      ),
      WledAdapter(http),
      TasmotaAdapter(http),
      HueAdapter(
        http,
        users: (key) => ref
            .read(credentialStoreProvider)
            .readCredential(devicePasswordId(key)),
      ),
      YeelightAdapter(ref.watch(yeelightTransportProvider)),
      KasaAdapter(
        ref.watch(kasaTransportProvider),
        klap: ref.watch(klapClientProvider),
        accounts: secret,
      ),
      TapoAdapter(ref.watch(klapClientProvider), accounts: secret),
      DirigeraAdapter(ref.watch(lanRequestsProvider), tokens: secret),
      TuyaAdapter(ref.watch(tuyaClientProvider), keys: secret),
      MiioAdapter(ref.watch(miioClientProvider), tokens: secret),
      WizAdapter(ref.watch(lanUdpProvider)),
      NanoleafAdapter(
        ref.watch(lanRequestsProvider),
        tokens: (key) => ref
            .read(credentialStoreProvider)
            .readCredential(devicePasswordId(key)),
      ),
      SonoffAdapter(ref.watch(lanRequestsProvider)),
      RokuAdapter(ref.watch(lanRequestsProvider)),
      SamsungTvAdapter(
        ref.watch(lanRequestsProvider),
        ref.watch(lanSocketsProvider),
        ref.watch(lanUdpProvider),
        tokens: secret,
      ),
      LgTvAdapter(
        ref.watch(lanSocketsProvider),
        ref.watch(lanUdpProvider),
        keys: secret,
      ),
      SonosAdapter(ref.watch(lanRequestsProvider)),
      LifxAdapter(ref.watch(lanUdpProvider)),
      GoveeAdapter(
        ref.watch(lanUdpProvider),
        pollEvery: const Duration(seconds: 10),
      ),
      BleAdapter(ref.watch(bleScannerProvider)),
      ref.watch(routineAdapterProvider),
      EsphomeAdapter(
        connector: ref.watch(esphomeConnectorProvider),
        keys: (key) => ref
            .read(credentialStoreProvider)
            .readCredential(devicePasswordId(key)),
      ),
    ],
    rooms: demoRooms,
    home: ref.read(localHomeProvider),
  )..start();
  ref.listen(localHomeProvider, (_, home) => backend.configure(home));
  ref.onDispose(() => unawaited(backend.dispose()));
  return backend;
});

class HomeSnapshotController extends Notifier<HomeSnapshot> {
  @override
  HomeSnapshot build() {
    final backend = ref.watch(homeBackendProvider);
    if (backend == null) return HomeSnapshot.empty;
    final subscription = backend.snapshots.listen((s) => state = s);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return backend.current;
  }
}

final homeSnapshotProvider =
    NotifierProvider<HomeSnapshotController, HomeSnapshot>(
      HomeSnapshotController.new,
    );

/// One device. Widgets watching it rebuild only when *this* device changes,
/// because the repository keeps unchanged devices identical.
final deviceProvider = Provider.family<SmartHomeDevice?, String>(
  (ref, id) => ref.watch(homeSnapshotProvider.select((s) => s.devices[id])),
);

final syncStatusProvider = Provider<SyncStatus>(
  (ref) => ref.watch(homeSnapshotProvider.select((s) => s.status)),
);

/// Devices meant for normal lists: no auxiliary entities, no routines.
final visibleDeviceIdsProvider = Provider<ValueList<String>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final restricted = ref.watch(restrictedModeProvider);
  final visible =
      devices.values
          .where(
            (d) =>
                !d.isAuxiliary &&
                !d.kind.isRoutine &&
                d.kind != DeviceKind.unknown &&
                d.kind != DeviceKind.weather &&
                d.kind != DeviceKind.person &&
                d.kind != DeviceKind.todoList &&
                !restricted.hides(d),
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList([for (final d in visible) d.id]);
});

/// Rooms sorted by name.
final roomsProvider = Provider<ValueList<Room>>((ref) {
  final rooms =
      ref.watch(homeSnapshotProvider.select((s) => s.rooms)).values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList(rooms);
});

/// Visible device ids per room id; devices without a room use `null`.
final deviceIdsByRoomProvider = Provider<Map<String?, ValueList<String>>>((
  ref,
) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final result = <String?, List<String>>{};
  for (final id in ref.watch(visibleDeviceIdsProvider)) {
    result.putIfAbsent(devices[id]?.roomId, () => []).add(id);
  }
  return {for (final e in result.entries) e.key: ValueList(e.value)};
});
