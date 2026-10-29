import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/data/local/esphome/esphome_client.dart';
import '../../devices/data/local/lan_http.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/data/local/shelly_adapter.dart';
import '../../devices/data/local/tasmota_adapter.dart';
import '../../devices/data/local/wled_adapter.dart';
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

  /// The device's name, else its model.
  String get title => name ?? device.model ?? brand;
}

/// Asks a device on the local network what it is: Shelly (`/shelly`),
/// WLED (`/json/info`), Tasmota (`Status 0`) or ESPHome (its API, or what
/// it announces). Only reads; `null` for anything else.
class DeviceProbe {
  const DeviceProbe(this._http, this._esphome);

  final LanHttp _http;
  final EsphomeConnector _esphome;

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

  /// An address typed in: a web device, else an ESPHome device.
  Future<ProbedDevice?> probeAddress(String host) async =>
      await probe(host) ?? await probeEsphome(host);

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
  ),
);
