import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  final at = DateTime.utc(2026, 10, 17, 12);
  final speaker = fixtureDevice(
    'media_player.speaker',
    name: 'Speaker',
    kind: DeviceKind.speaker,
    capabilities: const {
      Capability.mediaPause,
      Capability.mediaSeek,
      Capability.shuffle,
      Capability.repeat,
    },
    state: DeviceState(
      raw: 'playing',
      mediaTitle: 'Song',
      mediaDuration: const Duration(seconds: 200),
      mediaPosition: const Duration(milliseconds: 50500),
      mediaPositionUpdatedAt: at,
      shuffle: true,
      repeat: 'all',
    ),
  );

  test('position moves on while playing, stops at the end', () {
    final s = speaker.state;
    expect(s.mediaDuration, const Duration(seconds: 200));
    expect(s.positionAt(at.add(const Duration(seconds: 10)))!.inSeconds, 60);
    expect(s.positionAt(at.add(const Duration(hours: 1))), s.mediaDuration);
    expect(s.shuffle, isTrue);
    expect(s.repeat, 'all');
    const paused = DeviceState(
      raw: 'paused',
      mediaPosition: Duration(seconds: 30),
    );
    expect(paused.positionAt(DateTime.now()), const Duration(seconds: 30));
  });

  testWidgets('the player: shuffle, repeat cycles, seek bar', (tester) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);
    final server = HomeFixture.running;
    DeviceState player() => server['media_player.living_room_speaker'].state;

    await goTo(tester, AppRoutes.device('fx:media_player.living_room_speaker'));
    await settle(tester, 4);
    expect(find.byKey(const Key('mediaSeek')), findsOneWidget);

    await tapKey(tester, 'mediaShuffle');
    await settle(tester, 4);
    expect(player().shuffle, isTrue);

    await tapKey(tester, 'mediaRepeat');
    await settle(tester, 4);
    expect(player().repeat, 'all');
    await tapKey(tester, 'mediaRepeat');
    await settle(tester, 4);
    expect(player().repeat, 'one');

    await tester.drag(
      find.byKey(const Key('mediaSeek')),
      const Offset(-1000, 0),
    );
    await settle(tester, 4);
    expect(player().mediaPosition!.inSeconds, lessThan(10));
    await unmount(tester);
  });
}
