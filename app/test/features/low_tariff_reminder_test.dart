import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/energy/application/energy_providers.dart';
import 'package:open_smart_home_lite/features/energy/application/low_tariff_reminder.dart';
import 'package:open_smart_home_lite/features/energy/data/tariff.dart';
import 'package:open_smart_home_lite/features/ha_notify/ha_push.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeAlertNotifier;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

const _phone = MobileAppRegistration(
  webhookId: 'w',
  deviceName: 'Zidni tablet',
);
const _low = LowTariff(fromHour: 23, toHour: 7, price: 5.5);

void main() {
  test('automation: message at the start, cleared at the end', () {
    final c = lowTariffAutomation(
      l10n: AppLocalizationsEn(),
      registration: _phone,
      low: _low,
      currency: 'RSD',
    );
    expect(lowTariffReminderId(_phone), 'osh_low_tariff_zidni_tablet');
    expect(c['triggers'], [
      {'trigger': 'time', 'at': '23:00:00', 'id': 'start'},
      {'trigger': 'time', 'at': '07:00:00', 'id': 'end'},
    ]);
    final step = (c['actions']! as List).single as Map;
    final send = (step['then']! as List).single as Map;
    expect(send['action'], 'notify.mobile_app_zidni_tablet');
    expect(send['data'], {
      'title': en.lowTariffTitle,
      'message': en.lowTariffMessage('07:00', '5.5 RSD'),
      'data': {'tag': lowTariffTag},
    });
    expect(((step['else']! as List).single as Map)['data'], {
      'message': 'clear_notification',
      'data': {'tag': lowTariffTag},
    });
  });

  Future<void> registerPhone(WidgetTester tester) async {
    await goTo(tester, AppRoutes.settingsSection('notifications'));
    await tapKey(tester, 'haPushTile');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('haPushName')), 'Zidni tablet');
    await tester.tap(find.byKey(const Key('haPushRegister')));
    await settle(tester, 8);
  }

  testWidgets('bell on the energy screen: reminder on, message, off', (
    tester,
  ) async {
    final alerts = FakeAlertNotifier();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      alerts: alerts,
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    await container
        .read(tariffProvider.notifier)
        .save(const Tariff(importPrice: 15, low: _low));
    await registerPhone(tester);

    await goTo(tester, AppRoutes.energy);
    await settle(tester, 8);
    expect(find.byTooltip(en.lowTariffRemind), findsOneWidget);
    await tapKey(tester, 'lowTariffReminder');
    await settle(tester, 3);
    expect(find.text(en.lowTariffDialogBody('23:00')), findsOneWidget);
    await tapKey(tester, 'lowTariffConfirm');
    await settle(tester, 6);
    expect(find.text(en.lowTariffCreated), findsOneWidget);
    final config = server.automations['osh_low_tariff_zidni_tablet']!;
    expect(find.byTooltip(en.lowTariffRemindOn), findsOneWidget);

    // What the automation does at 23:00 and at 07:00, run on the server.
    final step = (config['actions']! as List).single as Map;
    for (final branch in ['then', 'else']) {
      final action = (step[branch]! as List).single as Map;
      final service = (action['action']! as String).split('.');
      server.callService(
        service[0],
        service[1],
        Map<String, Object?>.from(action['data']! as Map),
      );
      await settle(tester, 4);
      if (branch == 'then') {
        expect(alerts.messages.last, (
          en.lowTariffTitle,
          en.lowTariffMessage('07:00', '5.5 RSD'),
        ));
        // A tap on it opens the energy screen.
        await goTo(tester, AppRoutes.home);
        alerts.tapMessage();
        await settle(tester, 6);
        expect(find.byKey(const Key('lowTariffReminder')), findsOneWidget);
      }
    }
    expect(alerts.cancelled, ['ha-tag-$lowTariffTag']);

    // New price: the reminder in Home Assistant follows.
    await tester.ensureVisible(find.byKey(const Key('energyCost')));
    await tapKey(tester, 'energyCost');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('tariffLowPrice')), '6');
    await tapKey(tester, 'tariffSave');
    await settle(tester, 6);
    final updated =
        ((server.automations['osh_low_tariff_zidni_tablet']!['actions']!
                        as List)
                    .single
                as Map)['then']!
            as List;
    expect(
      ((updated.single as Map)['data'] as Map)['message'],
      en.lowTariffMessage('07:00', '6 RSD'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('lowTariffReminder')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );

    await tapKey(tester, 'lowTariffReminder');
    await settle(tester, 3);
    await tapKey(tester, 'lowTariffConfirm');
    await settle(tester, 6);
    expect(server.automations, isEmpty);
    expect(find.byTooltip(en.lowTariffRemind), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('without messages from Home Assistant it says what to do', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    await ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
        .read(tariffProvider.notifier)
        .save(const Tariff(importPrice: 15, low: _low));
    await goTo(tester, AppRoutes.energy);
    await settle(tester, 8);
    await tapKey(tester, 'lowTariffReminder');
    await settle(tester, 3);
    expect(find.text(en.lowTariffNeedsPush), findsOneWidget);
    await unmount(tester);
  });
}
