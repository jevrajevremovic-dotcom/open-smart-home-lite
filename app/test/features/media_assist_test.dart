import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/assist/presentation/assist_sheet.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_conversation.dart';

import '../integrations/home_assistant_api_test.dart' show build;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('picture paths drop the short-lived token parameter', () {
    expect(
      localPicturePath(
        '/api/media_player_proxy/media_player.x?token=abc&cache=42',
      ),
      '/api/media_player_proxy/media_player.x?cache=42',
    );
    expect(
      localPicturePath('/api/media_player_proxy/media_player.x?token=abc'),
      '/api/media_player_proxy/media_player.x',
    );
  });

  test('Serbian goes to HA as sr (Cyrillic) or sr-Latn (Latin)', () {
    expect(assistLanguage('sr', 'ugasi svetla'), 'sr-Latn');
    expect(assistLanguage('sr', 'угаси светла'), 'sr');
    expect(assistLanguage('en', 'turn off the lights'), 'en');
  });

  test('conversation reply parsing', () {
    final r = HaConversationReply.parse({
      'conversation_id': 'c1',
      'response': {
        'response_type': 'action_done',
        'speech': {
          'plain': {'speech': 'Done'},
        },
      },
    });
    expect((r.speech, r.isError, r.conversationId), ('Done', false, 'c1'));
    expect(HaConversationReply.parse('garbage').isError, isTrue);
  });

  test('REST: POST /api/conversation/process with text and language', () async {
    final (api, adapter) = build(
      (_) => (
        200,
        {
          'response': {
            'response_type': 'query_answer',
            'speech': {
              'plain': {'speech': '21 °C'},
            },
          },
        },
      ),
    );
    final reply = await api.processConversation('temperature?', language: 'en');
    expect(reply.speech, '21 °C');
    final r = adapter.requests.single;
    expect((r.method, r.path), ('POST', '/api/conversation/process'));
    expect(r.data, {'text': 'temperature?', 'language': 'en'});
  });

  testWidgets('now playing: card, play/pause and next track', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final card = find.byKey(const Key('nowPlayingCard'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Kafa i kiša')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip(en.mediaPlayPause)),
    );
    await settle(tester, 4);
    expect(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsOneWidget,
      reason: 'paused now',
    );

    await goTo(tester, AppRoutes.device('media_player.living_room_speaker'));
    await tapKey(tester, 'mediaNext');
    await settle(tester, 4);
    expect(
      tester.widget<Text>(find.byKey(const Key('mediaTitle'))).data,
      'Tiho jutro',
    );
    await unmount(tester);
  });

  testWidgets('Assist turns off the lights and answers', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    expect(find.text(en.lightsOnOf(2, 3)), findsOneWidget);
    await tapKey(tester, 'openAssist');
    await settle(tester, 2);
    expect(find.byKey(const Key('assistSheet')), findsOneWidget);
    await tester.tap(find.text(en.assistSuggestionLightsOff));
    await settle(tester, 6);
    expect(find.text('Turned off the lights.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('assistInput')), 'sing a song');
    await tapKey(tester, 'assistSend');
    await settle(tester, 4);
    expect(find.text("Sorry, I couldn't understand that."), findsOneWidget);

    Navigator.of(tester.element(find.byKey(const Key('assistSheet')))).pop();
    await settle(tester, 4);
    expect(find.text(en.lightsOnOf(0, 3)), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('kiosk: Assist from the sidebar', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(1280, 800));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);
    await tapKey(tester, 'kioskAssist');
    await settle(tester, 2);
    expect(find.byKey(const Key('assistSheet')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('voice: privacy choice once, then speech becomes a command', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    await tapKey(tester, 'openAssist');
    await settle(tester, 6); // sheet slide-in
    await tapKey(tester, 'assistMic');
    await settle(tester, 2);
    expect(find.text(en.voicePrivacyBody), findsOneWidget);
    await tapKey(tester, 'voiceOnDeviceOnly');
    await settle(tester, 10);
    expect(find.text('turn off the lights'), findsOneWidget);
    expect(find.text('Turned off the lights.'), findsOneWidget);

    // Second time: no question.
    await tapKey(tester, 'assistMic');
    await settle(tester, 2);
    expect(find.text(en.voicePrivacyBody), findsNothing);
    await settle(tester, 10);
    await unmount(tester);
  });
}
