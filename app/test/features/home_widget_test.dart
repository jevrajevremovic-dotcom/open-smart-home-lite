import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/shortcuts/home_screen_widget.dart';

import '../home_fixture.dart';
import '../helpers.dart' show FakeHomeScreenWidget;
import '../widgets/app_widget_test.dart' show en, pumpApp, settle, unmount;

/// The movie night scene turns the main light off.
bool sceneRan() =>
    HomeFixture.running.stateOf('light.living_room_main') == 'off';

Uri sceneLink(String id) =>
    Uri(scheme: 'opensmarthome', host: 'scene', queryParameters: {'id': id});

void main() {
  test('only scene links from the widget are accepted', () {
    expect(
      sceneIdFromWidgetUri(sceneLink('routine:scene_a_1')),
      'routine:scene_a_1',
    );
    for (final bad in [
      'opensmarthome://scene?id=fx:lock.front_door',
      'opensmarthome://scene?id=routine:auto_a',
      'opensmarthome://scene?id=routine:scene_x%2F..',
      'https://scene?id=routine:scene_x',
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
      adapter: HomeFixture(),
      size: const Size(800, 1400),
      homeWidget: widget,
    );
    await settle(tester, 10);
    expect(widget.scenes, [('routine:scene_movie_night', 'Filmsko veče')]);
    final updates = widget.updates;
    await settle(tester, 10);
    expect(widget.updates, updates, reason: 'no resend without changes');

    expect(sceneRan(), isFalse);
    widget.tap(sceneLink('routine:scene_movie_night'));
    await settle(tester, 6);
    expect(sceneRan(), isTrue, reason: 'scene activated');
    expect(find.text(en.sceneActivated('Filmsko veče')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a widget tap that launched the app runs once data is live', (
    tester,
  ) async {
    final widget = FakeHomeScreenWidget(
      launchedWith: sceneLink('routine:scene_movie_night'),
    );
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(800, 1400),
      homeWidget: widget,
    );
    await settle(tester, 12);
    expect(sceneRan(), isTrue, reason: 'scene activated after sync');
    await unmount(tester);
  });

  testWidgets('a link for a scene that is not on the widget does nothing', (
    tester,
  ) async {
    // Any app can send this link; this scene is not on the widget.
    final widget = FakeHomeScreenWidget(
      launchedWith: sceneLink('routine:scene_other'),
    );
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(800, 1400),
      homeWidget: widget,
    );
    await settle(tester, 12);
    expect(sceneRan(), isFalse);
    expect(find.textContaining('routine:scene_other'), findsNothing);
    await unmount(tester);
  });
}
