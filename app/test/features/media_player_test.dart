import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_command_translator.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  final at = DateTime.utc(2026, 10, 17, 12);
  final speaker = const HaDeviceMapper().map(
    HaEntityState(
      entityId: 'media_player.speaker',
      state: 'playing',
      attributes: {
        'media_title': 'Song',
        'media_duration': 200,
        'media_position': 50.5,
        'media_position_updated_at': at.toIso8601String(),
        'shuffle': true,
        'repeat': 'all',
        // PAUSE | SEEK | SHUFFLE_SET | REPEAT_SET
        'supported_features': 1 | 2 | 32768 | 262144,
      },
    ),
    HaRegistries.empty,
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

  test('seek, shuffle and repeat map to Home Assistant services', () {
    const t = HaCommandTranslator();
    final seek = t.translate(speaker, const MediaSeek(Duration(seconds: 95)));
    expect((seek.service, seek.data['seek_position']), ('media_seek', 95.0));
    final shuffle = t.translate(speaker, const SetShuffle(false));
    expect((shuffle.service, shuffle.data['shuffle']), ('shuffle_set', false));
    final repeat = t.translate(speaker, const SetRepeat('one'));
    expect((repeat.service, repeat.data['repeat']), ('repeat_set', 'one'));
    expect(
      () => t.translate(speaker, const SetRepeat('twice')),
      throwsA(anything),
    );
  });

  testWidgets('the player: shuffle, repeat cycles, seek bar', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    Map<Object?, Object?> attrs() =>
        server.states.firstWhere(
              (s) => s['entity_id'] == 'media_player.living_room_speaker',
            )['attributes']!
            as Map;

    await goTo(tester, AppRoutes.device('media_player.living_room_speaker'));
    await settle(tester, 4);
    expect(find.byKey(const Key('mediaSeek')), findsOneWidget);

    await tapKey(tester, 'mediaShuffle');
    await settle(tester, 4);
    expect(attrs()['shuffle'], isTrue);

    await tapKey(tester, 'mediaRepeat');
    await settle(tester, 4);
    expect(attrs()['repeat'], 'all');
    await tapKey(tester, 'mediaRepeat');
    await settle(tester, 4);
    expect(attrs()['repeat'], 'one');

    await tester.drag(
      find.byKey(const Key('mediaSeek')),
      const Offset(-1000, 0),
    );
    await settle(tester, 4);
    expect(attrs()['media_position'], lessThan(10));
    await unmount(tester);
  });
}
