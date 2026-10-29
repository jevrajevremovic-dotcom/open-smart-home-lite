import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/media/application/media_providers.dart';
import 'package:open_smart_home_lite/features/media/now_playing_notification.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../../helpers.dart' show FakeAlertNotifier, FakeNowPlaying;
import '../../widgets/app_widget_test.dart' show pumpApp, settle, unmount;

void main() {
  testWidgets('music in the notification: shown, pause from there, hidden', (
    tester,
  ) async {
    final shade = FakeNowPlaying();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      nowPlaying: shade,
      alerts: FakeAlertNotifier(),
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    final player = container.read(nowPlayingIdProvider)!;
    expect(shade.shown, isNull, reason: 'opt-in');

    expect(
      await container.read(nowPlayingNotificationProvider.notifier).set(true),
      isTrue,
    );
    await settle(tester, 2);
    expect(shade.shown?.playing, isTrue);
    expect(shade.shown?.title, isNotEmpty);

    shade.press('play_pause');
    await settle(tester, 4);
    expect(server.stateForTest(player), 'paused');
    expect(shade.shown?.playing, isFalse);

    await container.read(nowPlayingNotificationProvider.notifier).set(false);
    await settle(tester, 2);
    expect(shade.shown, isNull);
    await unmount(tester);
  });
}
