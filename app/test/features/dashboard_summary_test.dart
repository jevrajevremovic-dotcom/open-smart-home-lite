import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/utils/value_list.dart';
import 'package:open_smart_home_lite/features/dashboard/application/home_summaries.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_fixtures.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';

void main() {
  final reg = buildMockRegistries();
  final devices = const HaDeviceMapper().mapAll(
    parseStateList(buildMockStates(DateTime(2026, 10, 13))),
    HaRegistries.parse(
      areas: reg.areas,
      devices: reg.devices,
      entities: reg.entities,
    ),
  );

  test('dashboard summary uses only real readings', () {
    final s = summarize(devices.values);
    expect(s.averageTemperature, 22.4);
    expect(s.averageHumidity, 48);
    expect((s.lightsOn, s.lightsTotal), (2, 3));
    expect(s.openingIds, isEmpty);
    expect(s.powerDeviceId, 'sensor.house_power');
    expect(s.criticalIds, isEmpty);
    expect(s.lowBatteryIds, ['binary_sensor.bedroom_window']);
    expect(s.unavailableIds, ['switch.garage_heater']);
    expect(s.sceneIds, ['scene.movie_night']);
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
    expect(AppRoutes.shellIndexFor(AppRoutes.device('light.x')), 1);
    expect(AppRoutes.shellIndexFor('/favorites'), 2);
    expect(AppRoutes.shellIndexFor('/scenes'), 3);
    expect(AppRoutes.shellIndexFor('/settings'), 4);
    expect(AppRoutes.room(null), '/rooms/${AppRoutes.noRoomId}');
  });
}
