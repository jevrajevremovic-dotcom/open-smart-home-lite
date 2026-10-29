import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_command_translator.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  const mapper = HaDeviceMapper();
  const t = HaCommandTranslator();
  SmartHomeDevice map(String id, String state, Map<String, Object?> attrs) =>
      mapper.map(
        HaEntityState(entityId: id, state: state, attributes: attrs),
        HaRegistries.empty,
      );

  test('number: clamped and rounded to the step', () {
    final n = map('input_number.x', '19', {'min': 15, 'max': 25, 'step': 0.5});
    expect(n.kind, DeviceKind.number);
    expect(t.translate(n, const SetNumber(19.3)).data['value'], 19.5);
    expect(t.translate(n, const SetNumber(40)).data['value'], 25);
  });

  test('select: only listed options', () {
    final s = map('select.x', 'a', {
      'options': ['a', 'b'],
    });
    expect(t.translate(s, const SelectOption('b')).service, 'select_option');
    expect(() => t.translate(s, const SelectOption('c')), throwsA(anything));
  });

  test('fan speed 0 turns the fan off; vacuum services', () {
    final f = map('fan.x', 'on', {'supported_features': 1, 'percentage': 50});
    expect(t.translate(f, const SetFanSpeed(0)).service, 'turn_off');
    expect(t.translate(f, const SetFanSpeed(66)).data['percentage'], 66);
    final v = map('vacuum.x', 'docked', {'supported_features': 8192 | 16});
    expect(t.translate(v, const VacuumStart()).service, 'start');
    expect(t.translate(v, const VacuumReturnHome()).service, 'return_to_base');
  });

  testWidgets('vacuum, select and fan from their device screens', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);

    await goTo(tester, AppRoutes.device('vacuum.robot'));
    await settle(tester, 4);
    expect(find.text(en.vacuumDocked), findsWidgets);
    await tapKey(tester, 'vacuumStart');
    await settle(tester, 6);
    expect(find.text(en.vacuumCleaning), findsWidgets);
    await tapKey(tester, 'vacuumReturnHome');
    await settle(tester, 6);
    expect(find.text(en.vacuumReturning), findsWidgets);

    await goTo(tester, AppRoutes.device('input_select.house_mode'));
    await settle(tester, 4);
    await tester.tap(find.byKey(const ValueKey('option-Noć')));
    await settle(tester, 6);
    expect(find.text('Noć'), findsWidgets);

    await goTo(tester, AppRoutes.device('fan.bedroom_fan'));
    await settle(tester, 4);
    await tapKey(tester, 'fanOscillate');
    await settle(tester, 6);
    final sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('fanOscillate')),
    );
    expect(sw.value, isTrue);
    await unmount(tester);
  });
}
