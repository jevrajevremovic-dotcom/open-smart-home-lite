import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/shortcuts/home_screen_widget.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeHomeScreenWidget;
import '../widgets/app_widget_test.dart' show en, pumpApp, settle, unmount;

Object? sceneState(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
        .read(mockHomeAssistantServerProvider)
        .states
        .firstWhere((s) => s['entity_id'] == 'scene.movie_night')['state'];

void main() {
  test('only scene links from the widget are accepted', () {
    expect(
      sceneIdFromWidgetUri(Uri.parse('opensmarthome://scene?id=scene.a_1')),
      'scene.a_1',
    );
    for (final bad in [
      'opensmarthome://scene?id=lock.front_door',
      'opensmarthome://scene?id=scene.x%2F..',
      'https://scene?id=scene.x',
      'opensmarthome://open',
    ]) {
      expect(sceneIdFromWidgetUri(Uri.parse(bad)), isNull, reason: bad);
    }
    expect(sceneIdFromWidgetUri(null), isNull);
  });

  testWidgets('widget lists scenes and a tap runs one', (tester) async {
    final widget = FakeHomeScreenWidget();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      homeWidget: widget,
    );
    await settle(tester, 10);
    expect(widget.scenes, [('scene.movie_night', 'Filmsko veče')]);
    final updates = widget.updates;
    await settle(tester, 10);
    expect(widget.updates, updates, reason: 'no resend without changes');

    final before = sceneState(tester);
    widget.tap(Uri.parse('opensmarthome://scene?id=scene.movie_night'));
    await settle(tester, 6);
    expect(sceneState(tester), isNot(before), reason: 'scene activated');
    expect(find.text(en.sceneActivated('Filmsko veče')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a widget tap that launched the app runs once data is live', (
    tester,
  ) async {
    final widget = FakeHomeScreenWidget(
      launchedWith: Uri.parse('opensmarthome://scene?id=scene.movie_night'),
    );
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      homeWidget: widget,
    );
    await settle(tester, 12);
    final state = sceneState(tester);
    expect(state, isNot('unknown'), reason: 'scene activated after sync');
    await unmount(tester);
  });

  testWidgets('a link for a scene that is not on the widget does nothing', (
    tester,
  ) async {
    // Any app can send this link; scene.other is not on the widget.
    final widget = FakeHomeScreenWidget(
      launchedWith: Uri.parse('opensmarthome://scene?id=scene.other'),
    );
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      homeWidget: widget,
    );
    await settle(tester, 12);
    expect(sceneState(tester), 'unknown');
    expect(find.textContaining('scene.other'), findsNothing);
    await unmount(tester);
  });

  testWidgets('signed out: the widget asks to sign in', (tester) async {
    final widget = FakeHomeScreenWidget();
    await pumpApp(tester, homeWidget: widget);
    await settle(tester, 4);
    expect(widget.scenes, isEmpty);
    expect(widget.emptyText, en.widgetSignedOut);
    await unmount(tester);
  });
}
