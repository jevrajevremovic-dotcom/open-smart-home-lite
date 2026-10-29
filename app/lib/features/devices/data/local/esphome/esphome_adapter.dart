import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../../domain/capability.dart';
import '../../../domain/device_command.dart';
import '../../../domain/device_kind.dart';
import '../../../domain/smart_home_device.dart';
import '../device_adapter.dart';
import '../local_home.dart';
import 'esphome_client.dart';
import 'proto.dart';

/// ESPHome devices over their native API: one lasting connection per
/// device, which pushes every change (no polling). Switches, lights
/// (brightness, colour, colour temperature), covers, buttons, sensors,
/// binary sensors and text sensors. Diagnostic and configuration entities
/// are kept but not shown in lists.
///
/// The encryption key (base64, from the device's YAML) comes from [keys];
/// without one the connection is plaintext.
class EsphomeAdapter extends DeviceAdapter {
  EsphomeAdapter({EsphomeConnector? connector, this.keys})
    : _connector = connector ?? tcpConnector;

  final EsphomeConnector _connector;
  final Future<String?> Function(String key)? keys;
  static final _log = AppLogger('Adapter:esphome');

  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();
  final Map<String, _Session> _sessions = {};
  List<SmartHomeDevice> _current = const [];
  bool _active = true;
  bool _started = false;
  bool _disposed = false;

  @override
  String get id => 'esphome';

  @override
  Stream<List<SmartHomeDevice>> get devices => _controller.stream;

  @override
  List<SmartHomeDevice> get current => _current;

  @override
  void configure(List<ConfiguredDevice> devices) {
    final next = {for (final d in devices) d.key: d};
    for (final key in _sessions.keys.toList()) {
      final session = _sessions[key]!;
      if (next[key] != session.config) {
        // Gone, or moved / given another key: start over.
        session.stop();
        _sessions.remove(key);
      }
    }
    for (final d in devices) {
      _sessions.putIfAbsent(d.key, () => _Session(this, d));
    }
    if (_started && _active) {
      for (final s in _sessions.values) {
        s.connectSoon();
      }
    }
    _publish();
  }

  @override
  Future<void> start() async {
    _started = true;
    await refresh();
  }

  @override
  Future<void> refresh() async {
    if (!_active) return;
    await Future.wait([for (final s in _sessions.values) s.connectNow()]);
  }

  @override
  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    for (final s in _sessions.values) {
      if (active) {
        s.connectSoon();
      } else {
        s.stop();
      }
    }
  }

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async {
    final session = _sessions[device.deviceId];
    final client = session?.client;
    if (session == null || client == null || client.isClosed) {
      throw AppFailure(
        FailureKind.unavailableEntity,
        debugMessage: '${device.id} not connected',
      );
    }
    final entity = session.entityOf(device.id);
    if (entity == null) {
      throw AppFailure(
        FailureKind.unavailableEntity,
        debugMessage: '${device.id} unknown',
      );
    }
    final (type, data) = entity.command(command);
    client.send(type, data);
  }

  void _publish() {
    if (_disposed) return;
    _current = List.unmodifiable([
      for (final s in _sessions.values) ...s.devices(),
    ]);
    _controller.add(_current);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final s in _sessions.values) {
      s.stop();
    }
    await _controller.close();
  }
}

/// The connection to one device, and what it told about itself.
class _Session {
  _Session(this._adapter, this.config);

  final EsphomeAdapter _adapter;
  final ConfiguredDevice config;
  EsphomeClient? client;
  EsphomeDeviceInfo? _info;
  final Map<int, _Entity> _entities = {};
  final Map<int, ProtoMessage> _states = {};
  Timer? _retry;
  int _failures = 0;
  bool _connecting = false;
  bool _stopped = false;

  bool get _connected => client != null && !client!.isClosed;

  _Entity? entityOf(String deviceId) =>
      _entities.values.where((e) => e.id(config) == deviceId).firstOrNull;

  void connectSoon() {
    _stopped = false;
    if (_connected || _connecting || _retry != null) return;
    unawaited(connectNow());
  }

  Future<void> connectNow() async {
    _stopped = false;
    _retry?.cancel();
    _retry = null;
    if (_connected || _connecting || _adapter._disposed) return;
    _connecting = true;
    try {
      final key = config.secured ? await _adapter.keys?.call(config.key) : null;
      final c = await EsphomeClient.connect(
        _adapter._connector,
        config.host,
        psk: key == null ? null : base64.decode(key),
      );
      if (_stopped || _adapter._disposed) {
        await c.close();
        return;
      }
      client = c;
      _info = c.info;
      final entities = <int, _Entity>{};
      final done = c.expect(EsphomeMessage.listEntitiesDone);
      final listing = c.messages.listen((m) {
        final e = _Entity.fromList(m.$1, m.$2);
        if (e != null) entities[e.key] = e;
      });
      c.send(EsphomeMessage.listEntitiesRequest, Uint8List(0));
      await done.timeout(const Duration(seconds: 10));
      await listing.cancel();
      _entities
        ..clear()
        ..addAll(entities);
      c.messages.listen(
        _onMessage,
        onError: (Object e) =>
            EsphomeAdapter._log.warning('${config.host} connection error', e),
        onDone: _onClosed,
      );
      c.send(EsphomeMessage.subscribeStates, Uint8List(0));
      _failures = 0;
      _adapter._publish();
    } on Object catch (e) {
      if (_failures == 0) {
        EsphomeAdapter._log.warning('${config.host} not reached', e);
      }
      final c = client;
      client = null;
      if (c != null) unawaited(c.close());
      _scheduleRetry();
      _adapter._publish();
    } finally {
      _connecting = false;
    }
  }

  void _onMessage((int, ProtoMessage) m) {
    final (type, message) = m;
    if (!_Entity.stateTypes.contains(type)) return;
    final key = message.fixed32(1);
    if (!_entities.containsKey(key)) return;
    _states[key] = message;
    _adapter._publish();
  }

  void _onClosed() {
    client = null;
    _adapter._publish();
    if (!_stopped) _scheduleRetry();
  }

  /// 5 s, 10 s, 20 s… up to a minute.
  void _scheduleRetry() {
    if (_stopped || _adapter._disposed || !_adapter._active) return;
    _retry?.cancel();
    final delay = Duration(seconds: min(60, 5 << min(_failures, 4)));
    _failures++;
    _retry = Timer(delay, () {
      _retry = null;
      unawaited(connectNow());
    });
  }

  void stop() {
    _stopped = true;
    _retry?.cancel();
    _retry = null;
    final c = client;
    client = null;
    if (c != null) unawaited(c.close());
  }

  List<SmartHomeDevice> devices() {
    final info = _info;
    final deviceName = info == null
        ? (config.label ?? config.model ?? config.host)
        : (info.friendlyName.isNotEmpty ? info.friendlyName : info.name);
    if (_entities.isEmpty) {
      return [
        SmartHomeDevice(
          id: '${config.key}:device',
          sourceId: config.host,
          deviceId: config.key,
          name: deviceName,
          kind: DeviceKind.switchDevice,
          protocol: DeviceProtocol.esphome,
          available: false,
          capabilities: const {},
          state: const DeviceState(raw: 'unknown'),
        ),
      ];
    }
    return [
      for (final e in _entities.values)
        e.device(
          config,
          deviceName,
          _states[e.key],
          available: _connected,
          model: info?.model,
        ),
    ];
  }
}

/// One entity from `ListEntities…Response`.
class _Entity {
  _Entity({
    required this.platform,
    required this.key,
    required this.objectId,
    required this.name,
    this.deviceClass = '',
    this.unit = '',
    this.colorModes = const [],
    this.minMireds = 0,
    this.maxMireds = 0,
    this.supportsPosition = false,
    this.supportsStop = false,
    this.auxiliary = false,
  });

  final String platform;
  final int key;
  final String objectId;
  final String name;
  final String deviceClass;
  final String unit;
  final List<int> colorModes;
  final double minMireds;
  final double maxMireds;
  final bool supportsPosition;
  final bool supportsStop;

  /// A diagnostic or configuration entity (Wi-Fi signal, uptime, restart).
  final bool auxiliary;

  static const stateTypes = {
    EsphomeMessage.binarySensorState,
    EsphomeMessage.coverState,
    EsphomeMessage.lightState,
    EsphomeMessage.sensorState,
    EsphomeMessage.switchState,
    EsphomeMessage.textSensorState,
  };

  String id(ConfiguredDevice config) => '${config.key}:${platform}_$objectId';

  /// `null` for entities this does not show (fans, climate…) and for
  /// those hidden by default.
  static _Entity? fromList(int type, ProtoMessage m) {
    // Field numbers differ per message: (disabled_by_default, category).
    final (platform, disabled, category) = switch (type) {
      EsphomeMessage.listSwitch => ('switch', 7, 8),
      EsphomeMessage.listLight => ('light', 13, 15),
      EsphomeMessage.listCover => ('cover', 9, 11),
      EsphomeMessage.listSensor => ('sensor', 12, 13),
      EsphomeMessage.listBinarySensor => ('binary_sensor', 7, 9),
      EsphomeMessage.listTextSensor => ('text_sensor', 6, 7),
      EsphomeMessage.listButton => ('button', 6, 7),
      _ => ('', 0, 0),
    };
    if (platform.isEmpty || m.boolean(disabled)) return null;
    return _Entity(
      platform: platform,
      key: m.fixed32(2),
      objectId: m.string(1),
      name: m.string(3),
      deviceClass: switch (type) {
        EsphomeMessage.listSwitch => m.string(9),
        EsphomeMessage.listCover => m.string(8),
        EsphomeMessage.listSensor => m.string(9),
        EsphomeMessage.listBinarySensor => m.string(5),
        EsphomeMessage.listTextSensor ||
        EsphomeMessage.listButton => m.string(8),
        _ => '',
      },
      unit: type == EsphomeMessage.listSensor ? m.string(6) : '',
      colorModes: type == EsphomeMessage.listLight ? m.uints(12) : const [],
      minMireds: type == EsphomeMessage.listLight ? m.float(9) : 0,
      maxMireds: type == EsphomeMessage.listLight ? m.float(10) : 0,
      supportsPosition: type == EsphomeMessage.listCover && m.boolean(6),
      supportsStop: type == EsphomeMessage.listCover && m.boolean(12),
      auxiliary:
          m.uint(category) != 0 ||
          (type == EsphomeMessage.listBinarySensor && m.boolean(6)),
    );
  }

  // ColorMode bits (api.proto): brightness 2, colour temperature 8,
  // cold/warm white 16, RGB 32.
  bool _mode(int bit) => colorModes.any((m) => m & bit != 0);

  SmartHomeDevice device(
    ConfiguredDevice config,
    String deviceName,
    ProtoMessage? s, {
    required bool available,
    String? model,
  }) {
    final (kind, capabilities, state, limits) = _shape(s);
    return SmartHomeDevice(
      id: id(config),
      sourceId: '$platform.$objectId',
      deviceId: config.key,
      name: name.isEmpty ? deviceName : name,
      kind: kind,
      protocol: DeviceProtocol.esphome,
      manufacturer: 'ESPHome',
      model: model,
      available: available,
      capabilities: capabilities,
      state: state,
      limits: limits,
      // A battery level is shown with its device (and in Batteries).
      isAuxiliary:
          auxiliary || (platform == 'sensor' && deviceClass == 'battery'),
      metadata: DeviceMetadata(
        haDeviceClass: deviceClass.isEmpty ? null : deviceClass,
      ),
    );
  }

  (DeviceKind, Set<Capability>, DeviceState, DeviceLimits) _shape(
    ProtoMessage? s,
  ) {
    switch (platform) {
      case 'switch':
        final on = s?.boolean(2);
        return (
          deviceClass == 'outlet' ? DeviceKind.outlet : DeviceKind.switchDevice,
          {Capability.power},
          DeviceState(raw: _onOff(on), isOn: on),
          DeviceLimits.none,
        );
      case 'light':
        final on = s?.boolean(2);
        final rgb = _mode(32);
        final temperature = _mode(8) || _mode(16);
        final brightness = rgb || temperature || _mode(2);
        final mireds = s?.float(8) ?? 0;
        return (
          rgb
              ? DeviceKind.rgbLight
              : brightness
              ? DeviceKind.dimmableLight
              : DeviceKind.light,
          {
            Capability.power,
            if (brightness) Capability.brightness,
            if (rgb) Capability.rgb,
            if (temperature && minMireds > 0) Capability.colorTemperature,
          },
          DeviceState(
            raw: _onOff(on),
            isOn: on,
            brightnessPercent: on == true && brightness
                ? (s!.float(3) * 100).round().clamp(1, 100)
                : null,
            rgb: on == true && rgb
                ? RgbColor(
                    (s!.float(4) * 255).round(),
                    (s.float(5) * 255).round(),
                    (s.float(6) * 255).round(),
                  )
                : null,
            colorTemperatureKelvin: on == true && temperature && mireds > 0
                ? (1e6 / mireds).round()
                : null,
          ),
          DeviceLimits(
            minColorTemperatureKelvin: maxMireds > 0
                ? (1e6 / maxMireds).round()
                : null,
            maxColorTemperatureKelvin: minMireds > 0
                ? (1e6 / minMireds).round()
                : null,
          ),
        );
      case 'cover':
        final position = s == null ? null : (s.float(3) * 100).round();
        final operation = s?.uint(5) ?? 0;
        return (
          switch (deviceClass) {
            'garage' || 'gate' => DeviceKind.garageDoor,
            'curtain' => DeviceKind.curtain,
            _ => DeviceKind.blind,
          },
          {
            Capability.open,
            Capability.close,
            if (supportsStop) Capability.stop,
            if (supportsPosition) Capability.position,
          },
          DeviceState(
            raw: '$position',
            position: supportsPosition ? position : null,
            coverState: switch (operation) {
              1 => CoverState.opening,
              2 => CoverState.closing,
              _ when position != null =>
                position > 0 ? CoverState.open : CoverState.closed,
              _ => null,
            },
          ),
          DeviceLimits.none,
        );
      case 'button':
        return (
          DeviceKind.button,
          {Capability.trigger},
          const DeviceState(raw: 'idle'),
          DeviceLimits.none,
        );
      case 'binary_sensor':
        final active = s == null || s.boolean(3) ? null : s.boolean(2);
        return (
          switch (deviceClass) {
            'motion' || 'presence' => DeviceKind.motionSensor,
            'occupancy' => DeviceKind.occupancySensor,
            'door' ||
            'window' ||
            'opening' ||
            'garage_door' => DeviceKind.contactSensor,
            'moisture' => DeviceKind.waterLeakSensor,
            'smoke' => DeviceKind.smokeSensor,
            'gas' || 'carbon_monoxide' => DeviceKind.coSensor,
            'vibration' => DeviceKind.vibrationSensor,
            _ => DeviceKind.binarySensor,
          },
          const <Capability>{},
          DeviceState(raw: _onOff(active), isActive: active),
          DeviceLimits.none,
        );
      case 'text_sensor':
        final text = s == null || s.boolean(3) ? null : s.string(2);
        return (
          DeviceKind.sensor,
          const <Capability>{},
          DeviceState(raw: text ?? 'unknown', textValue: text),
          DeviceLimits.none,
        );
      default: // sensor
        final value = s == null || s.boolean(3) ? null : s.float(2);
        final v = value == null || value.isNaN
            ? null
            : double.parse(value.toStringAsFixed(2));
        final (kind, capability) = switch (deviceClass) {
          'temperature' => (
            DeviceKind.temperatureSensor,
            Capability.currentTemperature,
          ),
          'humidity' => (DeviceKind.humiditySensor, Capability.humidity),
          'power' => (DeviceKind.powerMeter, Capability.powerConsumption),
          'energy' => (DeviceKind.energyMeter, Capability.energyConsumption),
          'illuminance' => (DeviceKind.illuminanceSensor, null),
          'battery' => (DeviceKind.batterySensor, Capability.battery),
          _ => (DeviceKind.sensor, null),
        };
        return (
          kind,
          {?capability},
          DeviceState(
            raw: '$v',
            numericValue: v,
            unit: unit.isEmpty ? null : unit,
            currentTemperature: kind == DeviceKind.temperatureSensor ? v : null,
            currentHumidity: kind == DeviceKind.humiditySensor ? v : null,
          ),
          DeviceLimits.none,
        );
    }
  }

  static String _onOff(bool? on) => switch (on) {
    true => 'on',
    false => 'off',
    null => 'unknown',
  };

  /// The request for [command] on this entity.
  (int, Uint8List) command(DeviceCommand command) {
    final w = ProtoWriter()..fixed32(1, key);
    switch ((platform, command)) {
      case ('switch', TurnOn()):
        w.boolean(2, true);
        return (EsphomeMessage.switchCommand, w.toBytes());
      case ('switch', TurnOff()):
        return (EsphomeMessage.switchCommand, w.toBytes());
      case ('light', TurnOn() || TurnOff()):
        w
          ..boolean(2, true)
          ..boolean(3, command is TurnOn);
        return (EsphomeMessage.lightCommand, w.toBytes());
      case ('light', SetBrightness(:final percent)):
        w
          ..boolean(2, true)
          ..boolean(3, percent > 0);
        if (percent > 0) {
          w
            ..boolean(4, true)
            ..float(5, percent / 100);
        }
        return (EsphomeMessage.lightCommand, w.toBytes());
      case ('light', SetRgbColor(:final color)):
        w
          ..boolean(2, true)
          ..boolean(3, true)
          ..boolean(6, true)
          ..float(7, color.red / 255)
          ..float(8, color.green / 255)
          ..float(9, color.blue / 255);
        return (EsphomeMessage.lightCommand, w.toBytes());
      case ('light', SetColorTemperature(:final kelvin)):
        w
          ..boolean(2, true)
          ..boolean(3, true)
          ..boolean(12, true)
          ..float(13, 1e6 / kelvin);
        return (EsphomeMessage.lightCommand, w.toBytes());
      case ('cover', OpenCover()):
        w
          ..boolean(4, true)
          ..float(5, 1);
        return (EsphomeMessage.coverCommand, w.toBytes());
      case ('cover', CloseCover()):
        // position 0.0 is the default, so it is not written; has_position is.
        w.boolean(4, true);
        return (EsphomeMessage.coverCommand, w.toBytes());
      case ('cover', SetCoverPosition(:final percent)):
        w
          ..boolean(4, true)
          ..float(5, percent / 100);
        return (EsphomeMessage.coverCommand, w.toBytes());
      case ('cover', StopCover()):
        w.boolean(8, true);
        return (EsphomeMessage.coverCommand, w.toBytes());
      case ('button', Activate()):
        return (EsphomeMessage.buttonCommand, w.toBytes());
      default:
        throw AppFailure(
          FailureKind.unsupportedFeature,
          debugMessage: '${command.runtimeType} for $platform',
        );
    }
  }
}
