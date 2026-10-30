import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/extras/batteries.dart';
import 'package:open_smart_home_lite/features/extras/extras_sheet.dart';
import 'package:open_smart_home_lite/features/extras/vacation.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/search/command_palette.dart';
import 'package:open_smart_home_lite/features/simple_mode/simple_mode.dart';

import '../home_fixture.dart';
import 'app_widget_test.dart' show goTo, pumpApp, settle, unmount;

/// Every tappable thing has a name for TalkBack, and is big enough for a
/// finger (48 dp on Android).
Future<void> _guidelines(WidgetTester tester, String where) async {
  for (final g in [androidTapTargetGuideline, labeledTapTargetGuideline]) {
    final result = await g.evaluate(tester);
    expect(result.passed, isTrue, reason: '$where: ${result.reason}');
  }
}

void main() {
  testWidgets('newer screens: named buttons, finger-sized', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(412, 915));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );

    for (final (name, open) in [
      ('more', showExtras),
      ('batteries', showBatteries),
      ('vacation', showVacation),
      ('search', showCommandPalette),
    ]) {
      unawaited(open(tester.element(find.byType(Scaffold).first)));
      await settle(tester, 8);
      await _guidelines(tester, name);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .popUntil((r) => r is! PopupRoute && r is! RawDialogRoute);
      await settle(tester, 4);
    }

    await goTo(tester, AppRoutes.firstRun);
    await settle(tester, 4);
    await _guidelines(tester, 'first run');

    await container.read(simpleModeProvider.notifier).setItems([
      'fx:light.living_room_main',
      'fx:climate.living_room',
    ]);
    await container.read(simpleModeProvider.notifier).setEnabled(true);
    await settle(tester, 6);
    await _guidelines(tester, 'simple mode');
    await container.read(simpleModeProvider.notifier).setEnabled(false);
    await settle(tester, 4);

    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 8);
    await _guidelines(tester, 'kiosk');
    semantics.dispose();
    await unmount(tester);
  });
}
