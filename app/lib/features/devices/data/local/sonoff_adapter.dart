import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// Sonoff switches and plugs in DIY mode (eWeLink "DIY" or the DIY jumper):
/// JSON over HTTP on port 8081. One relay, or several (`switches`) on
/// multi-channel models.
class SonoffAdapter extends PolledAdapter {
  SonoffAdapter(this._http, {super.pollEvery});

  final LanRequests _http;

  static const port = 8081;

  @override
  String get id => 'sonoff';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async =>
      parseSonoff(
        device,
        await sonoffCall(_http, device.host, device.id, 'info'),
      );

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final on = switch (command) {
      TurnOn() => true,
      TurnOff() => false,
      Toggle() => channel.state.isOn != true,
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for Sonoff',
      ),
    };
    final part = channel.id.split(':').last;
    final value = on ? 'on' : 'off';
    if (part == 'switch') {
      await sonoffCall(_http, device.host, device.id, 'switch', {
        'switch': value,
      });
    } else {
      await sonoffCall(_http, device.host, device.id, 'switches', {
        'switches': [
          {'switch': value, 'outlet': int.parse(part.substring(6))},
        ],
      });
    }
  }
}

/// `POST /zeroconf/<path>`; the answer's `data` (older firmware sends it
/// as a JSON string). Throws `AppFailure` for an `error` other than 0.
Future<Map<String, Object?>> sonoffCall(
  LanRequests http,
  String host,
  String deviceId,
  String path, [
  Map<String, Object?> data = const {},
]) async {
  final b = jsonBody({'deviceid': deviceId, 'data': data});
  final r = await http.send(
    'POST',
    Uri.parse('http://$host:${SonoffAdapter.port}/zeroconf/$path'),
    headers: b.headers,
    body: b.body,
  );
  final json = r.json;
  if (json is! Map || json['error'] != 0) {
    throw AppFailure(
      FailureKind.server,
      debugMessage: 'sonoff $path: ${json is Map ? json['error'] : r.status}',
    );
  }
  final d = json['data'];
  final Object? decoded = switch (d) {
    final String text when text.isNotEmpty => () {
      try {
        return jsonDecode(text);
      } on FormatException {
        return null;
      }
    }(),
    _ => d,
  };
  return decoded is Map ? decoded.cast<String, Object?>() : const {};
}

List<SmartHomeDevice> parseSonoff(
  ConfiguredDevice device,
  Map<String, Object?> info,
) {
  final signal = (info['signalStrength'] as num?)?.toDouble();
  SmartHomeDevice relay(String part, String name, bool on) => SmartHomeDevice(
    id: '${device.key}:$part',
    sourceId: device.host,
    deviceId: device.key,
    name: name,
    kind: DeviceKind.switchDevice,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Sonoff',
    model: device.model,
    available: true,
    capabilities: const {Capability.power},
    state: DeviceState(raw: on ? 'on' : 'off', isOn: on),
    metadata: DeviceMetadata(signalStrength: signal, signalUnit: 'dBm'),
  );
  final name = device.label ?? 'Sonoff';
  final switches = info['switches'];
  if (switches is List && switches.isNotEmpty) {
    return [
      for (final s in switches)
        if (s is Map && s['outlet'] is int)
          relay(
            'switch${s['outlet']}',
            '$name ${(s['outlet'] as int) + 1}',
            s['switch'] == 'on',
          ),
    ];
  }
  return [relay('switch', name, info['switch'] == 'on')];
}

/// The Sonoff in DIY mode at [host]: its device id and firmware, or `null`.
Future<({String id, String? firmware})?> sonoffProbe(
  LanRequests http,
  String host,
) async {
  try {
    final info = await sonoffCall(http, host, '', 'info');
    final id = info['deviceid'];
    return (
      id: id is String && id.isNotEmpty ? id : host,
      firmware: info['fwVersion'] as String?,
    );
  } on AppFailure {
    return null;
  }
}
