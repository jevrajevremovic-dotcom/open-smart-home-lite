import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_command_translator.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_tv_keys.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

SmartHomeDevice _tv(String id, String integration) => SmartHomeDevice(
  id: id,
  sourceId: id,
  name: 'TV',
  kind: DeviceKind.television,
  available: true,
  capabilities: const {Capability.tvKeys},
  state: const DeviceState(raw: 'on'),
  limits: DeviceLimits(tvKeys: haTvKeyNames[integration]!.keys.toSet()),
  metadata: DeviceMetadata(integration: integration),
);

void main() {
  test('keys go out under each integration\'s own names', () {
    const t = HaCommandTranslator();
    final samsung = t.translate(
      _tv('remote.tv', 'samsungtv'),
      const PressTvKey(TvKey.back),
    );
    expect(
      (samsung.domain, samsung.service, samsung.data['command']),
      ('remote', 'send_command', 'KEY_RETURN'),
    );
    // LG: a webostv service on the media player itself.
    final lg = t.translate(
      _tv('media_player.tv', 'webostv'),
      const PressTvKey(TvKey.ok),
    );
    expect((lg.domain, lg.service), ('webostv', 'button'));
    expect(lg.data, {'entity_id': 'media_player.tv', 'button': 'ENTER'});
    // Sony documents no volume key: not sent.
    expect(
      () => t.translate(
        _tv('remote.tv', 'braviatv'),
        const PressTvKey(TvKey.volumeUp),
      ),
      throwsA(anything),
    );
    expect(haTvKeyNames['braviatv']!.containsKey(TvKey.volumeUp), isFalse);
  });

  testWidgets('TV: remote, mute and sound mode', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.device('media_player.living_room_tv'));
    await settle(tester, 6);

    // The remote works even with the TV off (it may be what wakes it).
    await tester.ensureVisible(find.byKey(const Key('tvRemote')));
    for (final k in ['up', 'ok', 'back', 'channelUp']) {
      await tester.ensureVisible(find.byKey(ValueKey('tvKey-$k')));
      await tapKey(tester, 'tvKey-$k');
      await settle(tester, 2);
    }
    expect(server.remoteCommands, [
      'DPAD_UP',
      'DPAD_CENTER',
      'BACK',
      'CHANNEL_UP',
    ]);

    server.callService('media_player', 'turn_on', {
      'entity_id': 'media_player.living_room_tv',
    });
    await settle(tester, 4);
    await tester.ensureVisible(find.byKey(const Key('mediaMute')));
    await tapKey(tester, 'mediaMute');
    await settle(tester, 4);
    expect(
      (server.states.firstWhere(
            (s) => s['entity_id'] == 'media_player.living_room_tv',
          )['attributes']!
          as Map)['is_volume_muted'],
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const Key('mediaSoundMode')));
    await tapKey(tester, 'mediaSoundMode');
    await settle(tester, 2);
    await tester.tap(find.text('Film').last);
    await settle(tester, 4);
    expect(
      (server.states.firstWhere(
            (s) => s['entity_id'] == 'media_player.living_room_tv',
          )['attributes']!
          as Map)['sound_mode'],
      'Film',
    );
    await unmount(tester);
  });
}
