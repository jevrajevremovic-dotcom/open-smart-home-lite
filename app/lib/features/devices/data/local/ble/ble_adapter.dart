import 'dart:async';

import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../../domain/capability.dart';
import '../../../domain/device_command.dart';
import '../../../domain/device_kind.dart';
import '../../../domain/smart_home_device.dart';
import '../device_adapter.dart';
import '../local_home.dart';
import 'ble_advert.dart';
import 'ble_scanner.dart';

/// Bluetooth LE sensors read from their advertisements, without
/// connecting: thermometers, door/window, motion, leak and button
/// sensors (BTHome, pvvx/ATC, SwitchBot Meter, Govee). One device per
/// value (`ble:<mac>:temperature`…), the battery with each.
///
/// A sensor not heard for [staleAfter] is shown unavailable, with its
/// last values.
class BleAdapter extends DeviceAdapter {
  BleAdapter(
    this._scanner, {
    this.staleAfter = const Duration(hours: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BleScanner _scanner;
  final Duration staleAfter;
  final DateTime Function() _clock;
  static final _log = AppLogger('Adapter:ble');

  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();
  final Map<String, ConfiguredDevice> _configs = {};
  final Map<String, BleReading> _readings = {};
  final Map<String, DateTime> _heard = {};
  final Map<String, DateTime> _pressed = {};
  StreamSubscription<BleAdvert>? _sub;
  Timer? _stale;
  List<SmartHomeDevice> _current = const [];
  bool _active = true;
  bool _started = false;

  @override
  String get id => 'ble';

  @override
  Stream<List<SmartHomeDevice>> get devices => _controller.stream;

  @override
  List<SmartHomeDevice> get current => _current;

  @override
  void configure(List<ConfiguredDevice> devices) {
    _configs
      ..clear()
      ..addAll({for (final d in devices) d.id: d});
    _readings.removeWhere((id, _) => !_configs.containsKey(id));
    _listen();
    _publish();
  }

  @override
  Future<void> start() async {
    _started = true;
    _listen();
    // Re-publish now and then: a sensor gone quiet becomes unavailable.
    _stale = Timer.periodic(const Duration(minutes: 5), (_) => _publish());
  }

  @override
  void setActive(bool active) {
    _active = active;
    _listen();
  }

  /// Scans only while there is something to hear and the app is active.
  void _listen() {
    final want =
        _started && _active && _configs.isNotEmpty && _scanner.supported;
    if (want && _sub == null) {
      _sub = _scanner.scan().listen(
        _onAdvert,
        onError: (Object e) => _log.warning('Bluetooth scan unavailable', e),
      );
    } else if (!want && _sub != null) {
      unawaited(_sub!.cancel());
      _sub = null;
    }
  }

  void _onAdvert(BleAdvert advert) {
    if (!_configs.containsKey(advert.id)) return;
    final r = parseAdvert(advert);
    if (r == null) return;
    final old = _readings[advert.id];
    // A repeat of the same advertisement changes nothing.
    if (r.packetId != null && old?.packetId == r.packetId && r.button == null) {
      _heard[advert.id] = _clock();
      return;
    }
    if (r.button != null) _pressed[advert.id] = _clock();
    // Sensors send some values in one advertisement, some in another.
    _readings[advert.id] = BleReading(
      model: r.model,
      temperature: r.temperature ?? old?.temperature,
      humidity: r.humidity ?? old?.humidity,
      battery: r.battery ?? old?.battery,
      illuminance: r.illuminance ?? old?.illuminance,
      motion: r.motion ?? old?.motion,
      open: r.open ?? old?.open,
      moisture: r.moisture ?? old?.moisture,
      button: r.button ?? old?.button,
      packetId: r.packetId,
    );
    _heard[advert.id] = _clock();
    _publish();
  }

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async =>
      throw const AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: 'Bluetooth sensors are only read',
      );

  void _publish() {
    final now = _clock();
    final out = <SmartHomeDevice>[];
    for (final config in _configs.values) {
      final r = _readings[config.id];
      final heard = _heard[config.id];
      final fresh = heard != null && now.difference(heard) < staleAfter;
      final name = config.label ?? r?.model ?? 'Bluetooth';
      final key = config.key;
      final metadata = DeviceMetadata(batteryPercent: r?.battery);
      SmartHomeDevice make(
        String part,
        String label,
        DeviceKind kind,
        Set<Capability> capabilities,
        DeviceState state,
      ) => SmartHomeDevice(
        id: '$key:$part',
        sourceId: config.host,
        deviceId: key,
        name: label,
        kind: kind,
        protocol: DeviceProtocol.bluetooth,
        model: r?.model ?? config.model,
        available: fresh,
        capabilities: capabilities,
        state: state,
        metadata: metadata,
      );
      if (r == null) {
        out.add(
          make(
            'device',
            name,
            DeviceKind.sensor,
            const {},
            const DeviceState(raw: 'unknown'),
          ),
        );
        continue;
      }
      if (r.temperature case final t?) {
        out.add(
          make(
            'temperature',
            name,
            DeviceKind.temperatureSensor,
            {Capability.currentTemperature},
            DeviceState(
              raw: '$t',
              numericValue: t,
              currentTemperature: t,
              unit: '°C',
            ),
          ),
        );
      }
      if (r.humidity case final h?) {
        out.add(
          make(
            'humidity',
            r.temperature == null ? name : '$name · %',
            DeviceKind.humiditySensor,
            {Capability.humidity},
            DeviceState(
              raw: '$h',
              numericValue: h,
              currentHumidity: h,
              unit: '%',
            ),
          ),
        );
      }
      if (r.illuminance case final lx?) {
        out.add(
          make(
            'illuminance',
            '$name · lx',
            DeviceKind.illuminanceSensor,
            const {},
            DeviceState(raw: '$lx', numericValue: lx, unit: 'lx'),
          ),
        );
      }
      for (final (part, value, kind) in [
        ('motion', r.motion, DeviceKind.motionSensor),
        ('open', r.open, DeviceKind.contactSensor),
        ('moisture', r.moisture, DeviceKind.waterLeakSensor),
      ]) {
        if (value == null) continue;
        out.add(
          make(
            part,
            name,
            kind,
            const {},
            DeviceState(raw: value ? 'on' : 'off', isActive: value),
          ),
        );
      }
      if (r.button case final event?) {
        out.add(
          make(
            'button',
            name,
            DeviceKind.button,
            const {},
            DeviceState(
              raw: event,
              textValue: event,
              lastTriggered: _pressed[config.id],
            ),
          ),
        );
      }
    }
    _current = List.unmodifiable(out);
    if (!_controller.isClosed) _controller.add(_current);
  }

  @override
  Future<void> dispose() async {
    _stale?.cancel();
    await _sub?.cancel();
    await _controller.close();
  }
}
