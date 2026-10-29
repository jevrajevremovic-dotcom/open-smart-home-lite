import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_settings.dart';
import 'package:open_smart_home_lite/features/settings/application/appearance_controllers.dart';
import 'package:open_smart_home_lite/features/settings/data/ha_backup.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('save to Home Assistant, change things, restore; no secrets', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    final kiosk = container.read(kioskSettingsProvider.notifier);
    await kiosk.update(
      (s) => s.copyWith(
        quickControls: ['light.hallway'],
        homeCards: [HomeCard.weather],
      ),
    );
    await kiosk.setPin('2468');
    await container.read(accentProvider.notifier).set(AppAccent.teal);

    await goTo(tester, AppRoutes.settingsSection('backup'));
    await settle(tester, 4);
    expect(find.text(en.haBackupNone), findsOneWidget);
    await tester.enterText(find.byKey(const Key('haBackupName')), 'Zid');
    await tapKey(tester, 'haBackupSave');
    await settle(tester, 6);
    expect(find.text(en.haBackupSavedHome('Zid')), findsOneWidget);
    final stored = server.systemData[HaBackupService.key]! as Map;
    final settings = (stored['Zid']! as Map)['settings']! as Map;
    expect((settings['kiosk']! as Map)['quickControls'], ['light.hallway']);
    expect(settings.toString(), isNot(contains('pinHash')));
    expect(settings.toString(), isNot(contains('token')));

    // Lost: another look, other cards.
    await kiosk.update(
      (s) => s.copyWith(quickControls: [], homeCards: HomeCard.values),
    );
    await container.read(accentProvider.notifier).set(AppAccent.terracotta);
    await tapKey(tester, 'haBackupRestore-Zid');
    await settle(tester, 2);
    await tapKey(tester, 'haBackupRestoreConfirm');
    await settle(tester, 6);
    final back = container.read(kioskSettingsProvider);
    expect(back.quickControls, ['light.hallway']);
    expect(back.homeCards, [HomeCard.weather]);
    expect(back.hasPin, isTrue, reason: 'this device keeps its PIN');
    expect(container.read(accentProvider), AppAccent.teal);

    await tapKey(tester, 'haBackupDelete-Zid');
    await settle(tester, 6);
    expect((server.systemData[HaBackupService.key]! as Map), isEmpty);
    expect(find.text(en.haBackupNone), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('without admin rights the copy goes to the user\'s own store', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider)
      ..configAdmin = false;
    await goTo(tester, AppRoutes.settingsSection('backup'));
    await settle(tester, 4);
    await tester.enterText(find.byKey(const Key('haBackupName')), 'Telefon');
    await tapKey(tester, 'haBackupSave');
    await settle(tester, 6);
    expect(find.text(en.haBackupSavedUser('Telefon')), findsOneWidget);
    expect(server.userData[HaBackupService.key], isA<Map<String, Object?>>());
    expect(server.systemData[HaBackupService.key], isNull);
    expect(find.byKey(const ValueKey('haBackup-user-Telefon')), findsOneWidget);
    await unmount(tester);
  });
}
