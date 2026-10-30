import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/utils/value_list.dart';
import 'package:open_smart_home_lite/features/dashboard/application/home_summaries.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../home_fixture.dart';

void main() {
  final devices = {
    for (final d in [
      ...fixtureDevices(DateTime(2026, 10, 13)),
      const SmartHomeDevice(
        id: 'routine:scene_movie_night',
        sourceId: 'movie_night',
        name: 'Filmsko veče',
        kind: DeviceKind.scene,
        available: true,
        capabilities: {},
        state: DeviceState(raw: 'scene'),
      ),
    ])
      d.id: d,
  };

  test('dashboard summary uses only real readings', () {
    final s = summarize(devices.values);
    expect(s.averageTemperature, 22.4);
    expect(s.averageHumidity, 48);
    expect((s.lightsOn, s.lightsTotal), (2, 3));
    expect(s.openingIds, isEmpty);
    expect(s.powerDeviceId, 'fx:sensor.house_power');
    expect(s.criticalIds, isEmpty);
    expect(s.lowBatteryIds, ['fx:binary_sensor.bedroom_window']);
    expect(s.unavailableIds, ['fx:switch.garage_heater']);
    expect(s.sceneIds, ['routine:scene_movie_night']);
  });

  test('missing data stays null instead of being invented', () {
    final s = summarize(devices.values.where((d) => d.kind.isLight));
    expect(s.averageTemperature, isNull);
    expect(s.averageHumidity, isNull);
    expect(s.powerDeviceId, isNull);
  });

  test('summary has value equality (no needless rebuilds)', () {
    expect(summarize(devices.values), summarize(devices.values));
  });

  test('device groups', () {
    expect(groupOf(DeviceKind.rgbLight), DeviceGroup.lights);
    expect(groupOf(DeviceKind.climate), DeviceGroup.climate);
    expect(groupOf(DeviceKind.lock), DeviceGroup.security);
    expect(groupOf(DeviceKind.temperatureSensor), DeviceGroup.sensors);
    expect(groupOf(DeviceKind.powerMeter), DeviceGroup.energy);
  });

  test('ValueList compares by value', () {
    expect(ValueList(['a', 'b']), ValueList(['a', 'b']));
    expect(ValueList(['a', 'b']).hashCode, ValueList(['a', 'b']).hashCode);
    expect(ValueList(['a', 'b']) == ValueList(['b', 'a']), isFalse);
    expect(() => ValueList(['a']).add('b'), throwsUnsupportedError);
  });

  test('navigation highlights the right destination', () {
    expect(AppRoutes.shellIndexFor('/home'), 0);
    expect(AppRoutes.shellIndexFor(AppRoutes.room('living_room')), 1);
    expect(AppRoutes.shellIndexFor(AppRoutes.device('fx:light.x')), 1);
    expect(AppRoutes.shellIndexFor('/favorites'), 2);
    expect(AppRoutes.shellIndexFor('/scenes'), 3);
    expect(AppRoutes.shellIndexFor('/settings'), 4);
    expect(AppRoutes.room(null), '/rooms/${AppRoutes.noRoomId}');
  });
}
