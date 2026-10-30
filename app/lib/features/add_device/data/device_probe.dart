import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/data/local/esphome/esphome_client.dart';
import '../../devices/data/local/ble/ble_advert.dart';
import '../../devices/data/local/hue_adapter.dart';
import '../../devices/data/local/govee_adapter.dart';
import '../../devices/data/local/kasa_adapter.dart';
import '../../devices/data/local/lan_transport.dart';
import '../../devices/data/local/lifx_adapter.dart';
import '../../devices/data/local/wiz_adapter.dart';
import '../../devices/data/local/lan_http.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/data/local/shelly_adapter.dart';
import '../../devices/data/local/tasmota_adapter.dart';
import '../../devices/data/local/wled_adapter.dart';
import '../../devices/data/local/yeelight_adapter.dart';
import 'lan_discovery.dart';

/// A device recognised at an address, ready to be added.
@immutable
class ProbedDevice {
  const ProbedDevice({
    required this.device,
    required this.brand,
    this.name,
    this.needsPassword = false,
    this.needsKey = false,
    this.needsLink = false,
    this.detail,
  });

  final ConfiguredDevice device;

  /// `Shelly`, `WLED` or `Tasmota`.
  final String brand;

  /// The name set on the device itself, if any.
  final String? name;

  /// The device asks for a password.
  final bool needsPassword;

  /// An ESPHome device that encrypts its API: the key is needed (and,
  /// when found by its address only, it tells who it is with the key).
  final bool needsKey;

  /// A Hue bridge: paired with its button before it can be added.
  final bool needsLink;

  /// What it reports now (a Bluetooth thermometer's `21.4 °C · 48 %`).
  final String? detail;

  /// The device's name, else its model.
  String get title => name ?? device.model ?? brand;
}

/// Asks a device on the local network what it is: Shelly (`/shelly`),
/// WLED (`/json/info`), a Hue bridge (`/api/config`), Tasmota
/// (`Status 0`), Kasa (`get_sysinfo`) or ESPHome (its API, or what it
/// announces). Only reads; `null` for anything else.
class DeviceProbe {
  const DeviceProbe(this._http, this._esphome, {this.kasa, this.udp});

  final LanHttp _http;
  final EsphomeConnector _esphome;
  final KasaTransport? kasa;
  final LanUdp? udp;

  /// Devices that answer a search of their own on the network (WiZ, LIFX,
  /// Govee), as each search ends.
  Stream<List<ProbedDevice>> search() async* {
    final udp = this.udp;
    if (udp == null) return;
    final found = <ProbedDevice>[];
    Future<List<ProbedDevice>> quiet(Future<List<ProbedDevice>> f) =>
        f.catchError((Object _) => const <ProbedDevice>[]);
    final searches = [
      quiet(wizDiscover(udp).then((l) => l.map(fromWiz).toList())),
      quiet(lifxDiscover(udp).then((l) => l.map(fromLifx).toList())),
      quiet(goveeDiscover(udp).then((l) => l.map(fromGovee).toList())),
    ];
    for (final s in searches) {
      found.addAll(await s);
      yield List.unmodifiable(found);
    }
  }

  static ProbedDevice fromWiz(WizFound w) => ProbedDevice(
    brand: 'WiZ',
    device: ConfiguredDevice(
      adapter: 'wiz',
      id: w.mac,
      host: w.host,
      model: w.module,
      label: 'WiZ',
    ),
  );

  static ProbedDevice fromLifx(({String host, String mac, String? label}) l) =>
      ProbedDevice(
        brand: 'LIFX',
        name: l.label?.isEmpty ?? true ? null : l.label,
        device: ConfiguredDevice(
          adapter: 'lifx',
          id: l.mac,
          host: l.host,
          label: l.label?.isEmpty ?? true ? 'LIFX' : l.label,
        ),
      );

  static ProbedDevice fromGovee(({String host, String id, String? sku}) g) =>
      ProbedDevice(
        brand: 'Govee',
        device: ConfiguredDevice(
          adapter: 'govee',
          id: g.id,
          host: g.host,
          model: g.sku,
          label: g.sku == null ? 'Govee' : 'Govee ${g.sku}',
        ),
      );

  /// A Yeelight that answered the search.
  static ProbedDevice fromYeelight(YeelightFound bulb) => ProbedDevice(
    brand: 'Yeelight',
    name: bulb.name.isEmpty ? null : bulb.name,
    device: ConfiguredDevice(
      adapter: 'yeelight',
      id: bulb.id,
      host: bulb.host,
      model: bulb.model,
      label: bulb.name.isEmpty ? 'Yeelight' : bulb.name,
    ),
  );

  /// A Bluetooth sensor heard nearby; `null` when its format is unknown.
  static ProbedDevice? fromBle(BleAdvert advert) {
    final r = parseAdvert(advert);
    if (r == null) return null;
    String n(double v) => v.toStringAsFixed(1);
    return ProbedDevice(
      brand: 'Bluetooth',
      name: advert.name,
      detail: [
        if (r.temperature case final t?) '${n(t)} °C',
        if (r.humidity case final h?) '${h.round()} %',
        if (r.illuminance case final lx?) '${lx.round()} lx',
        if (r.battery case final b?) '🔋 $b %',
      ].join(' · '),
      device: ConfiguredDevice(
        adapter: 'ble',
        id: advert.id,
        host: advert.address,
        model: r.model,
        label: advert.name ?? r.model,
      ),
    );
  }

  /// A Kasa device by its `get_sysinfo`; `null` without a MAC.
  static ProbedDevice? fromKasa(String host, Map<String, Object?> sysinfo) {
    final mac = kasaMac(sysinfo);
    if (mac == null) return null;
    final alias = sysinfo['alias'] as String?;
    return ProbedDevice(
      brand: 'Kasa',
      name: alias,
      device: ConfiguredDevice(
        adapter: 'kasa',
        id: mac,
        host: host,
        model: sysinfo['model'] as String?,
        label: alias ?? 'Kasa',
      ),
    );
  }

  /// A service found by mDNS: ESPHome tells who it is in its announcement.
  Future<ProbedDevice?> probeService(LanService service) async {
    if (!service.isEsphome) return probe(service.host);
    final mac = service.txt['mac'];
    if (mac == null || mac.isEmpty) return probeEsphome(service.host);
    final name = service.txt['friendly_name'] ?? service.name;
    return ProbedDevice(
      brand: 'ESPHome',
      name: name,
      needsKey: (service.txt['api_encryption'] ?? '').isNotEmpty,
      device: ConfiguredDevice(
        adapter: 'esphome',
        id: normalizeMac(mac),
        host: service.host,
        model: service.txt['board'],
        label: name,
      ),
    );
  }

  /// Connects to the ESPHome API at [host] (with [key], base64): who it is.
  /// Without a key, a device that wants one comes back with [needsKey] and
  /// no id yet. Throws [EsphomeKeyError] for a wrong key.
  Future<ProbedDevice?> probeEsphome(String host, {String? key}) async {
    final Uint8List? psk;
    try {
      psk = key == null ? null : base64.decode(key.trim());
    } on FormatException {
      throw const EsphomeKeyError('wrong'); // not base64
    }
    if (psk != null && psk.length != 32) throw const EsphomeKeyError('wrong');
    final EsphomeClient client;
    try {
      client = await EsphomeClient.connect(_esphome, host, psk: psk);
    } on EsphomeKeyError catch (e) {
      if (e.reason == 'required' && key == null) {
        return ProbedDevice(
          brand: 'ESPHome',
          needsKey: true,
          device: ConfiguredDevice(adapter: 'esphome', id: '', host: host),
        );
      }
      rethrow;
    } on Object {
      return null;
    }
    final info = client.info;
    await client.close();
    final name = info.friendlyName.isNotEmpty ? info.friendlyName : info.name;
    return ProbedDevice(
      brand: 'ESPHome',
      name: name,
      needsKey: key != null,
      device: ConfiguredDevice(
        adapter: 'esphome',
        id: normalizeMac(info.mac),
        host: host,
        model: info.model.isEmpty ? null : info.model,
        label: name,
      ),
    );
  }

  Future<ProbedDevice?> probe(String host) async {
    final shelly = parseShellyInfo(await _quiet(host, '/shelly'));
    if (shelly != null) {
      return ProbedDevice(
        brand: 'Shelly',
        name: shelly.name,
        needsPassword: shelly.auth,
        device: ConfiguredDevice(
          adapter: 'shelly',
          id: shelly.mac,
          host: host,
          model: shelly.model,
          label: shelly.name ?? shelly.model,
        ),
      );
    }
    final wled = parseWledInfo(await _quiet(host, '/json/info'));
    if (wled != null) {
      return ProbedDevice(
        brand: 'WLED',
        name: wled.name,
        device: ConfiguredDevice(
          adapter: 'wled',
          id: wled.mac,
          host: host,
          model: 'WLED ${wled.version}'.trim(),
          label: wled.name ?? 'WLED',
        ),
      );
    }
    final hue = parseHueInfo(await _quiet(host, '/api/config'));
    if (hue != null) {
      return ProbedDevice(
        brand: 'Hue',
        name: hue.name,
        needsLink: true,
        device: ConfiguredDevice(
          adapter: 'hue',
          id: hue.id,
          host: host,
          model: hue.model,
          label: hue.name,
        ),
      );
    }
    final tasmota = parseTasmotaInfo(
      await _quiet(host, '/cm', {'cmnd': 'Status 0'}),
    );
    if (tasmota != null) {
      return ProbedDevice(
        brand: 'Tasmota',
        name: tasmota.name,
        device: ConfiguredDevice(
          adapter: 'tasmota',
          id: tasmota.mac,
          host: host,
          model: tasmota.module,
          label: tasmota.name ?? 'Tasmota',
        ),
      );
    }
    return null;
  }

  /// An address typed in: a web device, a Kasa, a WiZ, else an ESPHome
  /// device.
  Future<ProbedDevice?> probeAddress(String host) async =>
      await probe(host) ??
      await _probeKasa(host) ??
      await _probeWiz(host) ??
      await probeEsphome(host);

  Future<ProbedDevice?> _probeWiz(String host) async {
    final udp = this.udp;
    if (udp == null) return null;
    final w = await wizProbe(udp, host);
    return w == null ? null : fromWiz(w);
  }

  Future<ProbedDevice?> _probeKasa(String host) async {
    final kasa = this.kasa;
    if (kasa == null) return null;
    try {
      final answer = await kasa.send(host, {
        'system': {'get_sysinfo': <String, Object?>{}},
      });
      final sysinfo = answer['system'];
      return sysinfo is Map
          ? DeviceProbe.fromKasa(host, {
              for (final e in (sysinfo['get_sysinfo'] as Map? ?? {}).entries)
                '${e.key}': e.value,
            })
          : null;
    } on Object {
      return null;
    }
  }

  Future<Object?> _quiet(
    String host,
    String path, [
    Map<String, Object?> query = const {},
  ]) async {
    try {
      return await _http.get(host, path, query: query);
    } on Object {
      return null;
    }
  }
}

final deviceProbeProvider = Provider<DeviceProbe>(
  (ref) => DeviceProbe(
    ref.watch(lanHttpProvider),
    ref.watch(esphomeConnectorProvider),
    kasa: ref.watch(kasaTransportProvider),
    udp: ref.watch(lanUdpProvider),
  ),
);
