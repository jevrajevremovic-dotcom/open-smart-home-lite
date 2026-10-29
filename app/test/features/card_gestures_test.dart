import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('tap: controls in a sheet, then the full screen', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);
    await tester.tap(find.text('Glavno svetlo'));
    await settle(tester, 4);
    expect(find.byKey(const Key('deviceSheet')), findsOneWidget);
    // A real control works in the sheet.
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const Key('deviceSheet')),
            matching: find.byType(Switch),
          )
          .first,
    );
    await settle(tester, 4);
    expect(server.stateForTest('light.living_room_main'), 'off');
    await tapKey(tester, 'deviceSheetMore');
    await settle(tester, 6);
    expect(find.byKey(const Key('deviceSheet')), findsNothing);
    expect(find.byKey(const Key('favoriteToggle')), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'hero flight');
    await unmount(tester);
  });

  testWidgets('long press: a light gets the big slider; a switch its screen', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);
    await tester.longPress(find.text('Ambijent'));
    await settle(tester, 4);
    final slider = find.byKey(const Key('bigSlider'));
    expect(slider, findsOneWidget);
    // Tap a quarter from the top: 75 %.
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height / 4));
    await settle(tester, 6);
    final attrs =
        server.states.firstWhere(
              (s) => s['entity_id'] == 'light.living_room_ambient',
            )['attributes']!
            as Map;
    expect(((attrs['brightness']! as num) / 255 * 100).round(), 75);
    // Close it; the outlet has nothing to slide.
    await tester.tapAt(const Offset(20, 20));
    await settle(tester, 4);
    expect(slider, findsNothing);
    await tester.ensureVisible(find.text('Utičnica TV'));
    await tester.longPress(find.text('Utičnica TV'));
    await settle(tester, 6);
    expect(find.byKey(const Key('favoriteToggle')), findsOneWidget);
    await unmount(tester);
  });
}
