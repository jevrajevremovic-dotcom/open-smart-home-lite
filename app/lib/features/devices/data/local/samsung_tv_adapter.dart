import 'dart:async';
import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// Samsung smart TVs (Tizen, 2016 and later): state over HTTP (port 8001),
/// the remote's keys over the TV's WebSocket (wss, port 8002). The first
/// connection asks on the TV whether to allow the app ([samsungLink]); the
/// token it gives is kept like a password. Turned on with Wake-on-LAN, if
/// "Power on with mobile" is on in the TV's settings.
class SamsungTvAdapter extends PolledAdapter {
  SamsungTvAdapter(
    this._http,
    this._sockets,
    this._udp, {
    this.tokens,
    super.pollEvery = const Duration(seconds: 10),
  });

  final LanRequests _http;
  final LanSockets _sockets;
  final LanUdp _udp;
  final Future<String?> Function(String key)? tokens;

  @override
  String get id => 'samsung';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    Map<String, Object?>? info;
    try {
      info = await samsungInfo(_http, device.host);
    } on AppFailure {
      // Off: the TV does not answer at all.
    }
    return [parseSamsungTv(device, info)];
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final on = channel.state.isOn == true;
    if (command is TurnOn || (command is Toggle && !on)) {
      final mac = device.options['mac'];
      if (mac == null) {
        throw const AppFailure(
          FailureKind.unsupportedFeature,
          debugMessage: 'samsung: no MAC for Wake-on-LAN',
        );
      }
      await wakeOnLan(_udp, mac);
      return;
    }
    final key = switch (command) {
      TurnOff() || Toggle() => 'KEY_POWER',
      StepVolume(:final up) => up ? 'KEY_VOLUP' : 'KEY_VOLDOWN',
      SetMute() => 'KEY_MUTE',
      MediaPlayPause() => 'KEY_PLAY',
      MediaNext() => 'KEY_FF',
      MediaPrevious() => 'KEY_REWIND',
      PressTvKey(:final key) => samsungKeys[key],
      _ => null,
    };
    if (key == null) {
      throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for Samsung',
      );
    }
    final token = await tokens?.call(device.key);
    final socket = await _sockets.connect(
      samsungRemoteUri(device.host, token),
      insecure: true,
    );
    try {
      // Keys count only once the TV has said the app may connect.
      final event = await _firstEvent(socket, const Duration(seconds: 5));
      if (event == null) {
        throw const AppFailure(FailureKind.timeout, debugMessage: 'samsung');
      }
      if (event.name != 'ms.channel.connect') {
        throw const AppFailure(
          FailureKind.authentication,
          debugMessage: 'samsung: not allowed on the TV',
        );
      }
      socket.send(
        jsonEncode({
          'method': 'ms.remote.control',
          'params': {
            'Cmd': 'Click',
            'DataOfCmd': key,
            'Option': 'false',
            'TypeOfRemote': 'SendRemoteKey',
          },
        }),
      );
      // Give the TV a moment before the connection goes.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    } finally {
      await socket.close();
    }
  }
}

const samsungKeys = <TvKey, String>{
  TvKey.up: 'KEY_UP',
  TvKey.down: 'KEY_DOWN',
  TvKey.left: 'KEY_LEFT',
  TvKey.right: 'KEY_RIGHT',
  TvKey.ok: 'KEY_ENTER',
  TvKey.back: 'KEY_RETURN',
  TvKey.home: 'KEY_HOME',
  TvKey.menu: 'KEY_MENU',
  TvKey.volumeUp: 'KEY_VOLUP',
  TvKey.volumeDown: 'KEY_VOLDOWN',
  TvKey.mute: 'KEY_MUTE',
  TvKey.channelUp: 'KEY_CHUP',
  TvKey.channelDown: 'KEY_CHDOWN',
  TvKey.playPause: 'KEY_PLAY',
};

Uri samsungRemoteUri(String host, String? token) => Uri(
  scheme: 'wss',
  host: host,
  port: 8002,
  path: '/api/v2/channels/samsung.remote.control',
  queryParameters: {
    'name': base64.encode(utf8.encode('Open Smart Home')),
    'token': ?token,
  },
);

/// `GET /api/v2/` (no pairing needed); throws when the TV does not answer.
Future<Map<String, Object?>> samsungInfo(LanRequests http, String host) async {
  final r = await http.send(
    'GET',
    Uri.parse('http://$host:8001/api/v2/'),
    timeout: const Duration(seconds: 3),
  );
  final json = r.json;
  if (!r.ok || json is! Map || json['device'] is! Map) {
    throw const AppFailure(FailureKind.server, debugMessage: 'samsung info');
  }
  return json.cast<String, Object?>();
}

/// Connects without a token: the TV asks whether to allow the app. The
/// token once allowed; `null` while it waits or when refused.
Future<String?> samsungLink(LanSockets sockets, String host) async {
  final socket = await sockets.connect(
    samsungRemoteUri(host, null),
    insecure: true,
  );
  try {
    final event = await _firstEvent(socket, const Duration(seconds: 30));
    if (event?.name != 'ms.channel.connect') return null;
    final token = event?.data['token'];
    // Older TVs allow without a token.
    return token is String ? token : '';
  } finally {
    await socket.close();
  }
}

/// The TV's first answer to connecting (`ms.channel.connect` or
/// `ms.channel.unauthorized`), or `null` after [wait].
Future<({String name, Map<String, Object?> data})?> _firstEvent(
  LanWebSocket socket,
  Duration wait,
) async {
  final done = Completer<({String name, Map<String, Object?> data})?>();
  final sub = socket.messages.listen((m) {
    final Object? j;
    try {
      j = jsonDecode(m);
    } on FormatException {
      return;
    }
    final name = j is Map ? j['event'] : null;
    if (name is! String || !name.startsWith('ms.channel.')) return;
    if (name != 'ms.channel.connect' && name != 'ms.channel.unauthorized') {
      return;
    }
    if (!done.isCompleted) {
      done.complete((
        name: name,
        data: ((j as Map)['data'] as Map?)?.cast<String, Object?>() ?? const {},
      ));
    }
  });
  final timer = Timer(wait, () {
    if (!done.isCompleted) done.complete(null);
  });
  try {
    return await done.future;
  } finally {
    timer.cancel();
    unawaited(sub.cancel());
  }
}

SmartHomeDevice parseSamsungTv(
  ConfiguredDevice device,
  Map<String, Object?>? info,
) {
  final d = (info?['device'] as Map?)?.cast<String, Object?>() ?? const {};
  final power = d['PowerState'] as String?;
  // Newer TVs answer in standby too, and say so.
  final on = info != null && (power == null || power == 'on');
  final name = (d['name'] ?? info?['name']) as String?;
  return SmartHomeDevice(
    id: '${device.key}:tv',
    sourceId: device.host,
    deviceId: device.key,
    name: (name ?? device.label ?? 'Samsung TV').replaceFirst('[TV] ', ''),
    kind: DeviceKind.television,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Samsung',
    model: d['modelName'] as String? ?? device.model,
    // Off is a state here, not "unavailable": it can still be woken.
    available: true,
    capabilities: {
      if (device.options['mac'] != null) Capability.power,
      Capability.tvKeys,
      Capability.volumeStep,
      Capability.mute,
      Capability.mediaPlay,
      Capability.mediaPause,
    },
    state: DeviceState(raw: on ? 'on' : 'off', isOn: on),
    limits: DeviceLimits(tvKeys: samsungKeys.keys.toSet()),
  );
}

/// The Samsung TV at [host]: its id, name, model and MAC, or `null`.
Future<({String id, String? name, String? model, String? mac})?> samsungProbe(
  LanRequests http,
  String host,
) async {
  try {
    final info = await samsungInfo(http, host);
    final d = (info['device'] as Map).cast<String, Object?>();
    final id = (d['id'] ?? info['id']) as String?;
    final mac = (d['wifiMac'] as String?)?.toLowerCase().replaceAll(':', '');
    return (
      id: (id ?? mac ?? host).replaceFirst('uuid:', '').toLowerCase(),
      name: (d['name'] as String?)?.replaceFirst('[TV] ', ''),
      model: d['modelName'] as String?,
      mac: mac,
    );
  } on AppFailure {
    return null;
  }
}
