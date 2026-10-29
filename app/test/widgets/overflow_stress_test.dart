import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/presentation/kiosk_columns.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_fixtures.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import 'app_widget_test.dart' show goTo, pumpApp, settle, unmount;

/// Real Home Assistant names are long ("Xiaomi Mi Smart Air Fryer 3.5L
/// Air Fryer Time Remaining"): every card must cope without overflowing.
MockHomeAssistantServer _longNames() => MockHomeAssistantServer(
  states: [
    for (final s in buildMockStates(DateTime.now()))
      {
        ...s,
        'attributes': {
          ...(s['attributes']! as Map<String, Object?>),
          'friendly_name':
              '${(s['attributes']! as Map)['friendly_name'] ?? s['entity_id']}'
              ' Xiaomi Mi Smart Plug 2 Bluetooth Gateway Edition',
        },
      },
  ],
);

const _rooms = [
  'living_room',
  'bedroom',
  'hallway',
  'kitchen',
  'garage',
  'yard',
];

void main() {
  for (final scale in [1.0, 1.3]) {
    for (final size in [const Size(360, 780), const Size(412, 915)]) {
      testWidgets('phone ${size.width.toInt()} × $scale: no card overflows', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(tester, signedIn: true, size: size, server: _longNames());
        await settle(tester, 10);
        expect(tester.takeException(), isNull, reason: 'home');
        for (final r in [..._rooms, null]) {
          await goTo(tester, AppRoutes.room(r));
          await settle(tester, 4);
          expect(tester.takeException(), isNull, reason: 'room $r');
        }
        await unmount(tester);
      });
    }
    for (final size in [
      const Size(1280, 800),
      const Size(1920, 1200),
      const Size(800, 1280),
    ]) {
      testWidgets(
        'kiosk ${size.width.toInt()}×${size.height.toInt()} × $scale: '
        'no card overflows',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpApp(
            tester,
            signedIn: true,
            size: size,
            server: _longNames(),
          );
          await settle(tester, 10);
          ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
              .read(kioskActiveProvider.notifier)
              .enter();
          await goTo(tester, AppRoutes.kiosk);
          await settle(tester, 8);
          expect(tester.takeException(), isNull, reason: 'kiosk home');
          for (final r in [..._rooms, '__no_room__']) {
            final row = find.byKey(ValueKey('kioskColumnsRoom-$r'));
            final none = find.byKey(const ValueKey('kioskColumnsRoom-none'));
            final target = r == '__no_room__' ? none : row;
            if (target.evaluate().isEmpty) continue;
            await tester.ensureVisible(target);
            await tester.tap(target);
            await settle(tester, 4);
            expect(tester.takeException(), isNull, reason: 'kiosk room $r');
          }
          await unmount(tester);
        },
      );
    }
  }

  testWidgets('every device screen on a narrow phone with large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(360, 780),
      server: _longNames(),
    );
    await settle(tester, 10);
    for (final s in buildMockStates(DateTime.now())) {
      final id = s['entity_id']! as String;
      await goTo(tester, AppRoutes.device(id));
      await settle(tester, 3);
      expect(tester.takeException(), isNull, reason: id);
    }
    await unmount(tester);
  });

  testWidgets('kiosk: every device card chosen, details on the right', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
      server: _longNames(),
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 8);
    for (final r in _rooms) {
      container.read(kioskColumnsRoomProvider.notifier).select(r);
      await settle(tester, 3);
      final cards = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'kioskColumnsDevice-',
            ),
      );
      for (final key in [for (final e in cards.evaluate()) e.widget.key!]) {
        final card = find.byKey(key);
        if (card.evaluate().isEmpty) continue;
        await tester.ensureVisible(card);
        await tester.tap(card);
        await settle(tester, 3);
        expect(tester.takeException(), isNull, reason: '$r $key');
      }
    }
    await unmount(tester);
  });
}
