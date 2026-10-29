import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/value_list.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';

/// Groups used to organise devices inside a room.
enum DeviceGroup {
  lights,
  climate,
  covers,
  switches,
  security,
  sensors,
  media,
  energy,
  other,
}

DeviceGroup groupOf(DeviceKind kind) => switch (kind) {
  _ when kind.isLight => DeviceGroup.lights,
  DeviceKind.thermostat ||
  DeviceKind.climate ||
  DeviceKind.fan ||
  DeviceKind.airPurifier ||
  DeviceKind.humidifier ||
  DeviceKind.dehumidifier => DeviceGroup.climate,
  DeviceKind.blind ||
  DeviceKind.curtain ||
  DeviceKind.garageDoor => DeviceGroup.covers,
  DeviceKind.switchDevice ||
  DeviceKind.outlet ||
  DeviceKind.irrigation => DeviceGroup.switches,
  DeviceKind.lock ||
  DeviceKind.alarm ||
  DeviceKind.siren ||
  DeviceKind.camera ||
  DeviceKind.doorbell ||
  DeviceKind.smokeSensor ||
  DeviceKind.coSensor ||
  DeviceKind.waterLeakSensor => DeviceGroup.security,
  DeviceKind.energyMeter ||
  DeviceKind.powerMeter ||
  DeviceKind.waterMeter ||
  DeviceKind.gasMeter => DeviceGroup.energy,
  DeviceKind.mediaPlayer ||
  DeviceKind.speaker ||
  DeviceKind.television => DeviceGroup.media,
  _ when kind.isSensor => DeviceGroup.sensors,
  _ => DeviceGroup.other,
};

bool isCriticalAlert(SmartHomeDevice d) =>
    d.available &&
    (((d.kind == DeviceKind.smokeSensor ||
                d.kind == DeviceKind.coSensor ||
                d.kind == DeviceKind.waterLeakSensor) &&
            d.state.isActive == true) ||
        (d.kind == DeviceKind.alarm &&
            d.state.alarmState == AlarmState.triggered) ||
        (d.kind == DeviceKind.lock &&
            d.state.lockState == DoorLockState.jammed));

bool isOpening(SmartHomeDevice d) =>
    d.available &&
    ((d.kind == DeviceKind.contactSensor && d.state.isActive == true) ||
        (d.kind == DeviceKind.garageDoor &&
            d.state.coverState != CoverState.closed &&
            d.state.coverState != null));

double? _average(Iterable<double?> values) {
  final list = values.whereType<double>().toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

/// Facts shown in the dashboard header. Only real readings are used; a
/// `null` field means "no such data in this home" and is shown as such.
@immutable
class DashboardSummary {
  const DashboardSummary({
    this.averageTemperature,
    this.averageHumidity,
    this.lightsOn = 0,
    this.lightsTotal = 0,
    this.openingIds = const [],
    this.powerDeviceId,
    this.criticalIds = const [],
    this.lowBatteryIds = const [],
    this.unavailableIds = const [],
    this.sceneIds = const [],
  });

  final double? averageTemperature;
  final double? averageHumidity;
  final int lightsOn;
  final int lightsTotal;

  /// Open doors/windows/garage doors.
  final List<String> openingIds;

  /// Power meter with the highest reading (normally the whole-home meter).
  final String? powerDeviceId;
  final List<String> criticalIds;
  final List<String> lowBatteryIds;
  final List<String> unavailableIds;
  final List<String> sceneIds;

  int get attentionCount =>
      criticalIds.length + lowBatteryIds.length + unavailableIds.length;

  @override
  bool operator ==(Object other) =>
      other is DashboardSummary &&
      other.averageTemperature == averageTemperature &&
      other.averageHumidity == averageHumidity &&
      other.lightsOn == lightsOn &&
      other.lightsTotal == lightsTotal &&
      other.powerDeviceId == powerDeviceId &&
      listEquals(other.openingIds, openingIds) &&
      listEquals(other.criticalIds, criticalIds) &&
      listEquals(other.lowBatteryIds, lowBatteryIds) &&
      listEquals(other.unavailableIds, unavailableIds) &&
      listEquals(other.sceneIds, sceneIds);

  @override
  int get hashCode => Object.hash(
    averageTemperature,
    averageHumidity,
    lightsOn,
    lightsTotal,
    powerDeviceId,
    Object.hashAll(openingIds),
    Object.hashAll(criticalIds),
    Object.hashAll(lowBatteryIds),
    Object.hashAll(unavailableIds),
    Object.hashAll(sceneIds),
  );
}

DashboardSummary summarize(Iterable<SmartHomeDevice> all) {
  final devices = all.where((d) => !d.isAuxiliary).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final available = devices.where((d) => d.available);
  final lights = devices.where((d) => d.kind.isLight).toList();
  final temperatures = available
      .where((d) => d.kind == DeviceKind.temperatureSensor)
      .map((d) => d.state.numericValue);
  final climateTemps = available
      .where(
        (d) => d.kind == DeviceKind.climate || d.kind == DeviceKind.thermostat,
      )
      .map((d) => d.state.currentTemperature);
  final power =
      available
          .where(
            (d) =>
                d.kind == DeviceKind.powerMeter && d.state.numericValue != null,
          )
          .toList()
        ..sort(
          (a, b) => b.state.numericValue!.compareTo(a.state.numericValue!),
        );

  return DashboardSummary(
    averageTemperature: _average(temperatures) ?? _average(climateTemps),
    averageHumidity: _average(
      available
          .where((d) => d.kind == DeviceKind.humiditySensor)
          .map((d) => d.state.numericValue),
    ),
    lightsOn: lights.where((d) => d.available && d.state.isOn == true).length,
    lightsTotal: lights.length,
    openingIds: [
      for (final d in devices)
        if (isOpening(d)) d.id,
    ],
    powerDeviceId: power.isEmpty ? null : power.first.id,
    criticalIds: [
      for (final d in devices)
        if (isCriticalAlert(d)) d.id,
    ],
    lowBatteryIds: [
      for (final d in devices)
        if (d.available && d.hasLowBattery) d.id,
    ],
    unavailableIds: [
      for (final d in devices)
        if (!d.available) d.id,
    ],
    sceneIds: [
      for (final d in devices)
        if (d.kind == DeviceKind.scene) d.id,
    ],
  );
}

final dashboardSummaryProvider = Provider<DashboardSummary>(
  (ref) => summarize(
    ref.watch(homeSnapshotProvider.select((s) => s.devices)).values,
  ),
);

@immutable
class RoomSummary {
  const RoomSummary({
    required this.deviceCount,
    required this.lightsOn,
    required this.activeCount,
    required this.alertCount,
    this.temperature,
    this.humidity,
  });

  final int deviceCount;
  final int lightsOn;

  /// Devices currently on/open (lights, switches, open covers, …).
  final int activeCount;

  /// Critical alerts + low batteries + unavailable devices.
  final int alertCount;
  final double? temperature;
  final double? humidity;

  @override
  bool operator ==(Object other) =>
      other is RoomSummary &&
      other.deviceCount == deviceCount &&
      other.lightsOn == lightsOn &&
      other.activeCount == activeCount &&
      other.alertCount == alertCount &&
      other.temperature == temperature &&
      other.humidity == humidity;

  @override
  int get hashCode => Object.hash(
    deviceCount,
    lightsOn,
    activeCount,
    alertCount,
    temperature,
    humidity,
  );
}

/// Summary for one room; `null` id = devices without a room.
final roomSummaryProvider = Provider.family<RoomSummary, String?>((
  ref,
  roomId,
) {
  final ids = ref.watch(
    deviceIdsByRoomProvider.select(
      (m) => m[roomId] ?? ValueList<String>(const []),
    ),
  );
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final list = [for (final id in ids) ?devices[id]];
  final summary = summarize(list);
  return RoomSummary(
    deviceCount: list.length,
    lightsOn: summary.lightsOn,
    activeCount: list
        .where((d) => d.available && (d.state.isOn == true || isOpening(d)))
        .length,
    alertCount: summary.attentionCount,
    temperature: summary.averageTemperature,
    humidity: summary.averageHumidity,
  );
});

/// Device ids of one room, grouped and in display order.
final roomDeviceGroupsProvider =
    Provider.family<ValueList<(DeviceGroup, ValueList<String>)>, String?>((
      ref,
      roomId,
    ) {
      final ids = ref.watch(
        deviceIdsByRoomProvider.select(
          (m) => m[roomId] ?? ValueList<String>(const []),
        ),
      );
      final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
      final groups = <DeviceGroup, List<String>>{};
      for (final id in ids) {
        final d = devices[id];
        if (d != null) groups.putIfAbsent(groupOf(d.kind), () => []).add(id);
      }
      return ValueList([
        for (final g in DeviceGroup.values)
          if (groups[g] != null) (g, ValueList(groups[g]!)),
      ]);
    });
