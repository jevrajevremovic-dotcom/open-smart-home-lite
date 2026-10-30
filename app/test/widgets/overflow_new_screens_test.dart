import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/extras/batteries.dart';
import 'package:open_smart_home_lite/features/extras/bedtime.dart';
import 'package:open_smart_home_lite/features/extras/extras_sheet.dart';
import 'package:open_smart_home_lite/features/extras/guest_wifi.dart';
import 'package:open_smart_home_lite/features/extras/party.dart';
import 'package:open_smart_home_lite/features/extras/sunrise_wake.dart';
import 'package:open_smart_home_lite/features/extras/vacation.dart';
import 'package:open_smart_home_lite/features/first_run/first_run_screen.dart';
import 'package:open_smart_home_lite/features/floor_plan/floor_plan.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/search/command_palette.dart';
import 'package:open_smart_home_lite/features/simple_mode/simple_mode.dart';

import '../home_fixture.dart';
import 'app_widget_test.dart' show goTo, pumpApp, settle, unmount;

/// Long names, as real devices have them.
HomeFixture _longNames() => HomeFixture(
  devices: [
    for (final d in fixtureDevices(DateTime.now()))
      renamed(d, '${d.name} Xiaomi Mi Smart Plug 2 Bluetooth Gateway Edition'),
  ],
);

/// Every sheet and dialog the newer features open, from Home.
final _openers = <String, Future<void> Function(BuildContext)>{
  'more': showExtras,
  'batteries': showBatteries,
  'vacation': showVacation,
  'guest wifi': showGuestWifi,
  'party': showParty,
  'sunrise': showSunriseWake,
  'bedtime': showBedtime,
  'floor plan': showFloorPlan,
  'search': showCommandPalette,
};

/// Fails with the whole report (which widget, how much), not one line.
void _noOverflow(WidgetTester tester, String where) {
  final e = tester.takeException();
  if (e == null) return;
  // Which Row/Column: the render tree marks it OVERFLOWING.
  final culprits = <String>[];
  void visit(RenderObject o) {
    if (o.toStringShort().contains('OVERFLOWING')) {
      culprits.add('${o.debugCreator}');
    }
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  fail('$where: $e\n${culprits.join('\n')}');
}

Future<void> _closePopups(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.popUntil((r) => r is! PopupRoute && r is! RawDialogRoute);
  await settle(tester, 4);
}

void main() {
  for (final scale in [1.0, 1.3, 1.6]) {
    testWidgets('narrow phone × $scale: the newer screens fit', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, adapter: _longNames(), size: const Size(360, 740));
      await settle(tester, 10);
      _noOverflow(tester, 'home');

      for (final MapEntry(key: name, value: open) in _openers.entries) {
        final context = tester.element(find.byType(Scaffold).first);
        unawaited(open(context));
        await settle(tester, 8);
        _noOverflow(tester, name);
        await _closePopups(tester);
      }

      for (final section in [
        'appearance',
        'kiosk',
        'notifications',
        'security',
      ]) {
        await goTo(tester, AppRoutes.settingsSection(section));
        await settle(tester, 4);
        // Down to the bottom, where the newer settings are.
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await settle(tester, 3);
        _noOverflow(tester, 'settings $section');
      }

      await goTo(tester, AppRoutes.firstRun);
      await settle(tester, 4);
      _noOverflow(tester, 'first run');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartHomeApp)),
      );
      await container.read(simpleModeProvider.notifier).setItems([
        'fx:light.living_room_main',
        'fx:climate.living_room',
        'routine:scene_movie_night',
        'fx:cover.living_room_blinds',
      ]);
      await container.read(simpleModeProvider.notifier).setEnabled(true);
      await settle(tester, 6);
      expect(find.byKey(const Key('simpleMode')), findsOneWidget);
      _noOverflow(tester, 'simple mode');
      await container.read(simpleModeProvider.notifier).setEnabled(false);
      await settle(tester, 4);
      await unmount(tester);
    });
  }

  testWidgets('wall panel × 1.3: the newer kiosk parts fit', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, adapter: _longNames(), size: const Size(1280, 800));
    await settle(tester, 10);
    ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
        .read(kioskActiveProvider.notifier)
        .enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 8);
    _noOverflow(tester, 'kiosk');
    for (final MapEntry(key: name, value: open) in _openers.entries) {
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(open(context));
      await settle(tester, 8);
      _noOverflow(tester, 'kiosk $name');
      await _closePopups(tester);
    }
    await unmount(tester);
  });

  test('first run screen is a widget (kept for the import)', () {
    expect(const FirstRunScreen(), isA<Widget>());
  });
}
