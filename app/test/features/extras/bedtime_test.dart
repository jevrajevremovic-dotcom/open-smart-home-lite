import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/extras/bedtime_stories.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../../helpers.dart' show FakeSpeechOutput;
import '../../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  test('every story in both languages, with a title and paragraphs', () {
    final sr = bedtimeStories('sr');
    final enStories = bedtimeStories('en');
    expect(sr.length, enStories.length);
    for (final s in [...sr, ...enStories]) {
      expect(s.title, isNotEmpty);
      expect(s.paragraphs.length, greaterThanOrEqualTo(3));
    }
  });

  testWidgets('read aloud while the room\'s lights go down, then out', (
    tester,
  ) async {
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      speech: speech,
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);

    await tapKey(tester, 'openExtras');
    await settle(tester, 5);
    await tapKey(tester, 'extraBedtime');
    await settle(tester, 5);
    await tapKey(tester, 'bedtimeRoom');
    await settle(tester, 2);
    await tester.tap(find.text('Dnevna soba').last);
    await settle(tester, 2);
    await tapKey(tester, 'bedtimeStory-0');
    await settle(tester, 10);

    final story = bedtimeStories('en').first;
    expect(speech.said.first, story.title);
    expect(speech.said, containsAll(story.paragraphs));
    expect(find.text(en.bedtimeGoodNight), findsOneWidget);
    // The living room's lights are out.
    expect(server.stateForTest('light.living_room_ambient'), 'off');
    await unmount(tester);
  });
}
