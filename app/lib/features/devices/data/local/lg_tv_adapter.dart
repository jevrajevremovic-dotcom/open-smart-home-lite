import 'dart:async';
import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'device_adapter.dart';
import 'lan_transport.dart';
import 'local_home.dart';

/// LG smart TVs (webOS) over their WebSocket API: on newer TVs `wss`
/// port 3001, on older ones `ws` port 3000. The first connection asks on
/// the TV whether to allow the app ([lgLink]); the client key it gives is
/// kept like a password. Volume, mute, inputs and the remote's keys; on
/// with Wake-on-LAN ("Turn on via Wi-Fi" in the TV's settings).
///
/// One connection per TV while the app is active, opened again when lost.
class LgTvAdapter extends DeviceAdapter {
  LgTvAdapter(
    this._sockets,
    this._udp, {
    this.keys,
    this.pollEvery = const Duration(seconds: 10),
  });

  final LanSockets _sockets;
  final LanUdp _udp;
  final Future<String?> Function(String key)? keys;
  final Duration pollEvery;

  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();
  final Map<String, ConfiguredDevice> _configs = {};
  final Map<String, Future<LgSession>> _sessions = {};
  final Map<String, SmartHomeDevice> _state = {};
  Timer? _timer;
  bool _active = true;

  @override
  String get id => 'lg';

  @override
  Stream<List<SmartHomeDevice>> get devices => _controller.stream;

  @override
  List<SmartHomeDevice> get current => List.unmodifiable(_state.values);

  @override
  void configure(List<ConfiguredDevice> devices) {
    final next = {for (final d in devices) d.key: d};
    for (final key in _configs.keys.toList()) {
      if (next[key] != _configs[key]) _drop(key);
    }
    _configs
      ..clear()
      ..addAll(next);
    _state.removeWhere((k, _) => !_configs.containsKey(k));
    _publish();
    unawaited(refresh());
  }

  @override
  Future<void> start() async {
    _schedule();
    await refresh();
  }

  @override
  void setActive(bool active) {
    _active = active;
    _schedule();
    if (!active) {
      for (final key in _sessions.keys.toList()) {
        _drop(key);
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = _active
        ? Timer.periodic(pollEvery, (_) => unawaited(refresh()))
        : null;
  }

  @override
  Future<void> refresh() =>
      Future.wait([for (final c in _configs.values.toList()) _read(c)]);

  Future<void> _read(ConfiguredDevice device) async {
    try {
      final s = await _session(device);
      final (volume, app) = await (
        s.request('ssap://audio/getVolume'),
        s.request('ssap://com.webos.applicationManager/getForegroundAppInfo'),
      ).wait;
      _state[device.key] = parseLgTv(
        device,
        on: true,
        volume: volume,
        app: app,
      );
    } on Object {
      _drop(device.key);
      _state[device.key] = parseLgTv(device, on: false);
    }
    _publish();
  }

  Future<LgSession> _session(ConfiguredDevice device) =>
      _sessions[device.key] ??= () async {
        final key = await keys?.call(device.key);
        final s = await LgSession.open(
          _sockets,
          device.host,
          key,
          pin: device.options['cert'],
        );
        unawaited(s.closed.then((_) => _sessions.remove(device.key)));
        return s;
      }();

  void _drop(String key) {
    final s = _sessions.remove(key);
    if (s != null) unawaited(s.then((s) => s.close(), onError: (_) {}));
  }

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async {
    final config = _configs.values
        .where((c) => device.id.startsWith('${c.key}:'))
        .firstOrNull;
    if (config == null) {
      throw AppFailure(
        FailureKind.unavailableEntity,
        debugMessage: '${device.id} not added',
      );
    }
    final on = device.state.isOn == true;
    if (command is TurnOn || (command is Toggle && !on)) {
      final mac = config.options['mac'];
      if (mac == null) {
        throw const AppFailure(
          FailureKind.unsupportedFeature,
          debugMessage: 'lg: no MAC for Wake-on-LAN',
        );
      }
      await wakeOnLan(_udp, mac);
      return;
    }
    final s = await _session(config);
    switch (command) {
      case TurnOff() || Toggle():
        await s.request('ssap://system/turnOff');
      case SetVolume(:final percent):
        await s.request('ssap://audio/setVolume', {'volume': percent});
      case StepVolume(:final up):
        await s.request(
          up ? 'ssap://audio/volumeUp' : 'ssap://audio/volumeDown',
        );
      case SetMute(:final muted):
        await s.request('ssap://audio/setMute', {'mute': muted});
      case MediaPlayPause():
        await s.request(
          device.state.raw == 'playing'
              ? 'ssap://media.controls/pause'
              : 'ssap://media.controls/play',
        );
      case SelectSource(:final source):
        final inputs = await s.request('ssap://tv/getExternalInputList');
        final id = [
          for (final d in (inputs['devices'] as List?) ?? const [])
            if (d is Map && d['label'] == source) d['id'],
        ].firstOrNull;
        if (id == null) {
          throw AppFailure(
            FailureKind.validation,
            debugMessage: 'lg: no input $source',
          );
        }
        await s.request('ssap://tv/switchInput', {'inputId': id});
      case PressTvKey(:final key):
        switch (key) {
          case TvKey.volumeUp:
            await s.request('ssap://audio/volumeUp');
          case TvKey.volumeDown:
            await s.request('ssap://audio/volumeDown');
          case TvKey.mute:
            await s.request('ssap://audio/setMute', {
              'mute': device.state.isMuted != true,
            });
          case TvKey.channelUp:
            await s.request('ssap://tv/channelUp');
          case TvKey.channelDown:
            await s.request('ssap://tv/channelDown');
          case TvKey.playPause:
            await s.request('ssap://media.controls/play');
          default:
            await s.button(lgButtons[key]!);
        }
      default:
        throw AppFailure(
          FailureKind.unsupportedFeature,
          debugMessage: '${command.runtimeType} for LG',
        );
    }
    await _read(config);
  }

  void _publish() {
    if (_controller.isClosed) return;
    _controller.add(current);
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    for (final key in _sessions.keys.toList()) {
      _drop(key);
    }
    await _controller.close();
  }
}

/// Keys that go through the TV's pointer socket.
const lgButtons = <TvKey, String>{
  TvKey.up: 'UP',
  TvKey.down: 'DOWN',
  TvKey.left: 'LEFT',
  TvKey.right: 'RIGHT',
  TvKey.ok: 'ENTER',
  TvKey.back: 'BACK',
  TvKey.home: 'HOME',
  TvKey.menu: 'MENU',
};

const _lgPermissions = [
  'LAUNCH',
  'CONTROL_AUDIO',
  'CONTROL_DISPLAY',
  'CONTROL_INPUT_JOYSTICK',
  'CONTROL_INPUT_MEDIA_PLAYBACK',
  'CONTROL_INPUT_TV',
  'CONTROL_POWER',
  'CONTROL_MOUSE_AND_KEYBOARD',
  'READ_APP_STATUS',
  'READ_CURRENT_CHANNEL',
  'READ_INPUT_DEVICE_LIST',
  'READ_NETWORK_STATE',
  'READ_POWER_STATE',
  'READ_RUNNING_APPS',
];

Map<String, Object?> lgRegister(String? clientKey) => {
  'type': 'register',
  'id': 'register_0',
  'payload': {
    'forcePairing': false,
    'pairingType': 'PROMPT',
    'client-key': ?clientKey,
    'manifest': {
      'manifestVersion': 1,
      'appVersion': '1.1',
      'permissions': _lgPermissions,
    },
  },
};

/// A registered connection to an LG TV.
class LgSession {
  LgSession._(this._socket, this._sockets) {
    _sub = _socket.messages.listen(_onMessage, onDone: _onDone);
  }

  final LanWebSocket _socket;
  final LanSockets _sockets;
  late final StreamSubscription<String> _sub;
  final Map<String, Completer<Map<String, Object?>>> _waiting = {};
  final _closed = Completer<void>();
  Completer<String?>? _registered;
  LanWebSocket? _pointer;
  int _id = 0;

  Future<void> get closed => _closed.future;

  /// Opens and registers with [clientKey]; on newer TVs over wss 3001,
  /// else ws 3000. With no key the TV asks, and this waits for the answer.
  static Future<LgSession> open(
    LanSockets sockets,
    String host,
    String? clientKey, {
    String? pin,
    Duration wait = const Duration(seconds: 8),
  }) async {
    LanWebSocket socket;
    try {
      socket = await sockets.connect(
        Uri.parse('wss://$host:3001/'),
        insecure: true,
        pin: pin,
      );
    } on AppFailure {
      // A TV paired over wss stays on wss (else its certificate would
      // not matter).
      if (pin != null) rethrow;
      socket = await sockets.connect(Uri.parse('ws://$host:3000/'));
    }
    final s = LgSession._(socket, sockets);
    final key = await s
        ._register(clientKey)
        .timeout(wait, onTimeout: () => null);
    if (key == null) {
      await s.close();
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'lg: not allowed on the TV',
      );
    }
    s.clientKey = key;
    return s;
  }

  /// The key the TV gave (the one asked with, or a new one).
  String? clientKey;

  /// The TV's certificate (wss), to require from then on.
  String? get certificate => _socket.certificate;

  Future<String?> _register(String? clientKey) {
    _registered = Completer<String?>();
    _socket.send(jsonEncode(lgRegister(clientKey)));
    return _registered!.future;
  }

  void _onMessage(String text) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      return;
    }
    if (j is! Map) return;
    final id = j['id'];
    final payload = (j['payload'] as Map?)?.cast<String, Object?>() ?? const {};
    if (id == 'register_0') {
      final done = _registered;
      if (done == null || done.isCompleted) return;
      if (j['type'] == 'registered') {
        done.complete(payload['client-key'] as String?);
      } else if (j['type'] == 'error') {
        done.complete(null);
      }
      return;
    }
    final waiting = _waiting.remove(id);
    if (waiting == null) return;
    if (j['type'] == 'error' || payload['returnValue'] == false) {
      waiting.completeError(
        AppFailure(FailureKind.server, debugMessage: 'lg: ${j['error']}'),
      );
    } else {
      waiting.complete(payload);
    }
  }

  void _onDone() {
    for (final w in _waiting.values) {
      w.completeError(
        const AppFailure(FailureKind.network, debugMessage: 'lg'),
      );
    }
    _waiting.clear();
    if (!_closed.isCompleted) _closed.complete();
  }

  Future<Map<String, Object?>> request(
    String uri, [
    Map<String, Object?>? payload,
  ]) {
    final id = 'r${++_id}';
    final done = Completer<Map<String, Object?>>();
    _waiting[id] = done;
    _socket.send(
      jsonEncode({
        'type': 'request',
        'id': id,
        'uri': uri,
        'payload': ?payload,
      }),
    );
    return done.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _waiting.remove(id);
        throw const AppFailure(FailureKind.timeout, debugMessage: 'lg');
      },
    );
  }

  /// A remote button (`UP`, `ENTER`…) through the pointer socket.
  Future<void> button(String name) async {
    var pointer = _pointer;
    if (pointer == null) {
      final r = await request(
        'ssap://com.webos.service.networkinput/getPointerInputSocket',
      );
      final path = r['socketPath'];
      if (path is! String) {
        throw const AppFailure(FailureKind.server, debugMessage: 'lg pointer');
      }
      pointer = _pointer = await _sockets.connect(
        Uri.parse(path),
        insecure: true,
      );
    }
    pointer.send('type:button\nname:$name\n\n');
  }

  Future<void> close() async {
    await _sub.cancel();
    await _pointer?.close();
    await _socket.close();
    if (!_closed.isCompleted) _closed.complete();
  }
}

/// Connects without a key: the TV asks whether to allow the app. The client
/// key once allowed, and the TV's MAC for Wake-on-LAN when it tells it;
/// `null` when refused or not answered in time.
Future<({String key, String? mac, String? certificate})?> lgLink(
  LanSockets sockets,
  String host,
) async {
  final LgSession s;
  try {
    s = await LgSession.open(
      sockets,
      host,
      null,
      wait: const Duration(seconds: 30),
    );
  } on AppFailure {
    return null;
  }
  try {
    String? mac;
    try {
      final info = await s.request(
        'ssap://com.webos.service.connectionmanager/getinfo',
      );
      final wired = (info['wiredInfo'] as Map?)?['macAddress'];
      final wifi = (info['wifiInfo'] as Map?)?['macAddress'];
      mac = ((wired ?? wifi) as String?)?.toLowerCase().replaceAll(':', '');
    } on AppFailure {
      // Not every TV tells.
    }
    final key = s.clientKey;
    return key == null
        ? null
        : (key: key, mac: mac, certificate: s.certificate);
  } finally {
    await s.close();
  }
}

SmartHomeDevice parseLgTv(
  ConfiguredDevice device, {
  required bool on,
  Map<String, Object?> volume = const {},
  Map<String, Object?> app = const {},
}) {
  // Newer TVs nest it: {"volumeStatus": {"volume": 12, "muteStatus": false}}.
  final status = (volume['volumeStatus'] as Map?)?.cast<String, Object?>();
  final level = (status?['volume'] ?? volume['volume']) as num?;
  final muted = (status?['muteStatus'] ?? volume['muted']) as bool?;
  final appId = app['appId'] as String?;
  return SmartHomeDevice(
    id: '${device.key}:tv',
    sourceId: device.host,
    deviceId: device.key,
    name: device.label ?? 'LG TV',
    kind: DeviceKind.television,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'LG',
    model: device.model,
    available: true,
    capabilities: {
      if (device.options['mac'] != null) Capability.power,
      Capability.tvKeys,
      Capability.volume,
      Capability.volumeStep,
      Capability.mute,
      Capability.mediaPlay,
      Capability.mediaPause,
    },
    state: DeviceState(
      raw: on ? 'on' : 'off',
      isOn: on,
      volumePercent: on ? level?.round() : null,
      isMuted: on ? muted : null,
      // `com.webos.app.livetv` → `livetv`.
      source: on && appId != null ? appId.split('.').last : null,
    ),
    limits: DeviceLimits(tvKeys: {...lgButtons.keys, ...TvKey.values}),
  );
}
