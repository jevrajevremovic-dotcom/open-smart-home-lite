import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_command_translator.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('arm modes from supported features; arm service per mode', () {
    final panel = const HaDeviceMapper().map(
      const HaEntityState(
        entityId: 'alarm_control_panel.a',
        state: 'disarmed',
        attributes: {
          'code_format': 'number',
          'code_arm_required': true,
          'supported_features': 1 | 2 | 32,
        },
      ),
      HaRegistries.empty,
    );
    expect(panel.limits.alarmArmModes, ['home', 'away', 'vacation']);
    expect(panel.limits.alarmCodeArmRequired, isTrue);
    const t = HaCommandTranslator();
    final call = t.translate(panel, const ArmAlarm('away', code: '12'));
    expect((call.service, call.data['code']), ('alarm_arm_away', '12'));
    expect(
      () => t.translate(panel, const ArmAlarm('night')),
      throwsA(anything),
      reason: 'night not supported',
    );
  });

  testWidgets('arm away, then disarm with the keypad (wrong, then right)', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('alarm_control_panel.home_alarm'));
    await settle(tester, 4);
    expect(find.text(en.alarmDisarmed), findsWidgets);
    await tapKey(tester, 'alarmArm-away');
    await settle(tester, 6);
    expect(find.text('${en.alarmArmed} · ${en.alarmArm_away}'), findsWidgets);

    Future<void> enterCode(String code) async {
      await tapKey(tester, 'alarmDisarm');
      await settle(tester, 2);
      for (final digit in code.split('')) {
        await tester.tap(find.byKey(ValueKey('alarmKey-$digit')));
        await tester.pump();
      }
      await tapKey(tester, 'alarmCodeOk');
      await settle(tester, 2);
      await tapKey(tester, 'confirmCriticalAction');
      await settle(tester, 6);
    }

    await enterCode('9999');
    expect(find.text(en.alarmDisarmed), findsNothing, reason: 'wrong code');
    await enterCode('1234');
    expect(find.text(en.alarmDisarmed), findsWidgets);
    await unmount(tester);
  });
}
