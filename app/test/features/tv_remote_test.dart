import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/tv_key.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('TV: remote, mute and sound mode', (tester) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);
    final server = HomeFixture.running;
    await goTo(tester, AppRoutes.device('fx:media_player.living_room_tv'));
    await settle(tester, 6);

    // The remote works even with the TV off (it may be what wakes it).
    await tester.ensureVisible(find.byKey(const Key('tvRemote')));
    for (final k in ['up', 'ok', 'back', 'channelUp']) {
      await tester.ensureVisible(find.byKey(ValueKey('tvKey-$k')));
      await tapKey(tester, 'tvKey-$k');
      await settle(tester, 2);
    }
    expect(
      [
        for (final (_, c) in server.sent)
          if (c is PressTvKey) c.key,
      ],
      [TvKey.up, TvKey.ok, TvKey.back, TvKey.channelUp],
    );

    server.set(
      'media_player.living_room_tv',
      state(server['media_player.living_room_tv'].state, raw: 'on', isOn: true),
    );
    await settle(tester, 4);
    await tester.ensureVisible(find.byKey(const Key('mediaMute')));
    await tapKey(tester, 'mediaMute');
    await settle(tester, 4);
    expect(server['media_player.living_room_tv'].state.isMuted, isTrue);
    await tester.ensureVisible(find.byKey(const Key('mediaSoundMode')));
    await tapKey(tester, 'mediaSoundMode');
    await settle(tester, 2);
    await tester.tap(find.text('Film').last);
    await settle(tester, 4);
    expect(server['media_player.living_room_tv'].state.soundMode, 'Film');
    await unmount(tester);
  });
}
