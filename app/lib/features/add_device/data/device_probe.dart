import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/data/local/lan_http.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/data/local/shelly_adapter.dart';
import '../../devices/data/local/tasmota_adapter.dart';
import '../../devices/data/local/wled_adapter.dart';

/// A device recognised at an address, ready to be added.
@immutable
class ProbedDevice {
  const ProbedDevice({
    required this.device,
    required this.brand,
    this.name,
    this.needsPassword = false,
  });

  final ConfiguredDevice device;

  /// `Shelly`, `WLED` or `Tasmota`.
  final String brand;

  /// The name set on the device itself, if any.
  final String? name;

  /// The device asks for a password.
  final bool needsPassword;

  /// The device's name, else its model.
  String get title => name ?? device.model ?? brand;
}

/// Asks a web server on the local network what it is: Shelly (`/shelly`),
/// WLED (`/json/info`) or Tasmota (`Status 0`). Only reads; `null` for
/// anything else.
class DeviceProbe {
  const DeviceProbe(this._http);

  final LanHttp _http;

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
  (ref) => DeviceProbe(ref.watch(lanHttpProvider)),
);
