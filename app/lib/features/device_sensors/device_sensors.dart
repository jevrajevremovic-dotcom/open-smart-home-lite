import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_preferences.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../ha_notify/ha_push.dart';
import '../kiosk/application/kiosk_controller.dart';

/// Battery as the system reports it.
@immutable
class BatteryReading {
  const BatteryReading({
    required this.level,
    required this.state,
    required this.charger,
  });

  /// 0–100 %.
  final int level;

  /// `charging`, `discharging`, `full`, `not_charging` or `unknown`.
  final String state;

  /// `ac`, `usb`, `wireless`, `dock` or `none`.
  final String charger;

  bool get charging => state == 'charging' || state == 'full';

  static BatteryReading? tryParse(Object? data) {
    if (data is! Map) return null;
    final level = data['level'];
    final state = data['state'];
    final charger = data['charger'];
    if (level is! int || state is! String || charger is! String) return null;
    return BatteryReading(
      level: level.clamp(0, 100),
      state: state,
      charger: charger,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BatteryReading &&
      other.level == level &&
      other.state == state &&
      other.charger == charger;

  @override
  int get hashCode => Object.hash(level, state, charger);
}

abstract interface class DeviceBatteryPlatform {
  bool get supported;

  /// The current reading first, then every change.
  Stream<BatteryReading> readings();
}

/// Android: the system battery broadcast (no extra permission).
class AndroidDeviceBattery implements DeviceBatteryPlatform {
  static const _channel = EventChannel('org.opensmarthome/battery');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<BatteryReading> readings() => _channel
      .receiveBroadcastStream()
      .map(BatteryReading.tryParse)
      .where((r) => r != null)
      .cast<BatteryReading>();
}

final deviceBatteryProvider = Provider<DeviceBatteryPlatform>(
  (ref) => AndroidDeviceBattery(),
);

/// Opt-in: send this device's battery and kiosk state to Home Assistant as
/// sensors of its Mobile App device.
class DeviceSensorsController extends Notifier<bool> {
  static const _key = 'deviceSensors';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
  }
}

final deviceSensorsProvider = NotifierProvider<DeviceSensorsController, bool>(
  DeviceSensorsController.new,
);

/// The sensors, as Mobile App's `register_sensor` / `update_sensor_states`
/// webhooks take them (homeassistant/components/mobile_app/webhook.py).
@visibleForTesting
List<Map<String, Object?>> sensorPayloads(
  AppLocalizations l10n, {
  required BatteryReading? battery,
  required bool kiosk,
  bool full = false,
}) => [
  if (battery != null) ...[
    {
      'type': 'sensor',
      'unique_id': 'battery_level',
      'state': battery.level,
      'icon': battery.charging ? 'mdi:battery-charging' : 'mdi:battery',
      if (full) ...{
        'name': l10n.deviceSensorBattery,
        'device_class': 'battery',
        'unit_of_measurement': '%',
        'state_class': 'measurement',
      },
    },
    {
      'type': 'sensor',
      'unique_id': 'battery_state',
      'state': battery.state,
      'icon': 'mdi:battery-charging-outline',
      'attributes': {'charger': battery.charger},
      if (full) 'name': l10n.deviceSensorBatteryState,
    },
    {
      'type': 'binary_sensor',
      'unique_id': 'is_charging',
      'state': battery.charging,
      'icon': battery.charging ? 'mdi:power-plug' : 'mdi:power-plug-off',
      if (full) ...{
        'name': l10n.deviceSensorCharging,
        'device_class': 'battery_charging',
      },
    },
  ],
  {
    'type': 'binary_sensor',
    'unique_id': 'kiosk',
    'state': kiosk,
    'icon': 'mdi:tablet-dashboard',
    if (full) 'name': l10n.deviceSensorKiosk,
  },
];

/// Sends the sensors while signed in, registered and connected: registers
/// them once per registration, then only sends changes.
class DeviceSensorsHost extends ConsumerStatefulWidget {
  const DeviceSensorsHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeviceSensorsHost> createState() => _DeviceSensorsHostState();
}

class _DeviceSensorsHostState extends ConsumerState<DeviceSensorsHost> {
  static final _log = AppLogger('DeviceSensors');
  StreamSubscription<BatteryReading>? _batterySub;
  BatteryReading? _battery;
  String? _registeredFor;
  String? _lastSent;
  bool _busy = false;

  /// A change arrived while sending: send again right after.
  bool _again = false;

  void _sync() {
    final platform = ref.read(deviceBatteryProvider);
    final enabled = ref.read(deviceSensorsProvider) && platform.supported;
    if (!enabled) {
      unawaited(_batterySub?.cancel());
      _batterySub = null;
      _battery = null;
      _lastSent = null;
      return;
    }
    _batterySub ??= platform.readings().listen((r) {
      _battery = r;
      unawaited(_send());
    }, onError: (Object e) => _log.warning('battery unavailable', e));
    unawaited(_send());
  }

  Future<void> _send() async {
    if (!mounted) return;
    if (_busy) {
      _again = true;
      return;
    }
    final registration = ref.read(haPushProvider).value;
    final manager = ref.read(webSocketManagerProvider);
    final connected =
        ref.read(connectionStatusProvider).value?.isConnected ?? false;
    if (registration == null || manager == null || !connected) return;
    final l10n = context.l10n;
    final kiosk = ref.read(kioskActiveProvider);
    // One reading for the whole send, though a new one may arrive meanwhile.
    final battery = _battery;
    _busy = true;
    try {
      Future<int?> webhook(String type, Object data) async {
        final answer = await manager.sendCommand({
          'type': 'webhook/handle',
          'webhook_id': registration.webhookId,
          'method': 'POST',
          'headers': {'Content-Type': 'application/json'},
          'body': jsonEncode({'type': type, 'data': data}),
        });
        return answer is Map ? answer['status'] as int? : null;
      }

      if (_registeredFor != registration.webhookId) {
        for (final s in sensorPayloads(
          l10n,
          battery: battery,
          kiosk: kiosk,
          full: true,
        )) {
          await webhook('register_sensor', s);
        }
        // Without a reading the battery sensors are registered later.
        _registeredFor = battery == null ? null : registration.webhookId;
        _lastSent = null;
      }
      final updates = sensorPayloads(l10n, battery: battery, kiosk: kiosk);
      final key = jsonEncode(updates);
      if (key != _lastSent) {
        final status = await webhook('update_sensor_states', updates);
        if (status == 200) _lastSent = key;
      }
    } on Object catch (e) {
      // Sent again with the next change or reconnect.
      _log.info('sensors not sent: ${e.runtimeType}');
    } finally {
      _busy = false;
    }
    if (_again) {
      _again = false;
      await _send();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    unawaited(_batterySub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(deviceSensorsProvider, (_, _) => _sync())
      ..listen(haPushProvider, (_, _) {
        _registeredFor = null;
        _sync();
      })
      ..listen(connectionStatusProvider, (_, next) {
        if (next.value?.isConnected ?? false) unawaited(_send());
      })
      ..listen(kioskActiveProvider, (_, _) => unawaited(_send()));
    return widget.child;
  }
}

/// The battery sensor's entity in Home Assistant, once registered. Home
/// Assistant picks the id from the (localized) name, so it is found as the
/// battery sensor named after this device.
final deviceBatteryEntityProvider = Provider<String?>((ref) {
  final registration = ref.watch(haPushProvider).value;
  if (registration == null) return null;
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final prefix = '${registration.deviceName} ';
  return devices.values
      .where(
        (d) =>
            d.kind == DeviceKind.batterySensor &&
            d.id.startsWith('sensor.') &&
            d.name.startsWith(prefix),
      )
      .map((d) => d.id)
      .firstOrNull;
});

/// A Home Assistant automation that keeps the battery between [low] and
/// [high] % by switching the charger's [plug] on and off.
Map<String, Object?> chargeAutomation({
  required String alias,
  required String battery,
  required String plug,
  int low = 40,
  int high = 80,
}) {
  final domain = plug.split('.').first;
  return {
    'alias': alias,
    'description': 'Open Smart Home: $low–$high %',
    'mode': 'single',
    'triggers': [
      {
        'trigger': 'numeric_state',
        'entity_id': battery,
        'below': low,
        'id': 'low',
      },
      {
        'trigger': 'numeric_state',
        'entity_id': battery,
        'above': high,
        'id': 'high',
      },
    ],
    'conditions': <Object>[],
    'actions': [
      {
        'choose': [
          {
            'conditions': [
              {'condition': 'trigger', 'id': 'low'},
            ],
            'sequence': [
              {
                'action': '$domain.turn_on',
                'target': {'entity_id': plug},
              },
            ],
          },
          {
            'conditions': [
              {'condition': 'trigger', 'id': 'high'},
            ],
            'sequence': [
              {
                'action': '$domain.turn_off',
                'target': {'entity_id': plug},
              },
            ],
          },
        ],
      },
    ],
  };
}
