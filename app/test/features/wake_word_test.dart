import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/features/assist/data/wake_word.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/ha_socket.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/ha_websocket_manager.dart';

import '../helpers.dart' show FakeClapPlatform, FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

/// Records frames to check the wire format.
class _RecordingSocket implements HaSocket {
  _RecordingSocket(this.inner);

  final HaSocket inner;
  final sent = <String>[];
  final binary = <Uint8List>[];

  @override
  Stream<String> get messages => inner.messages;

  @override
  void send(String message) {
    sent.add(message);
    inner.send(message);
  }

  @override
  void sendBytes(Uint8List data) {
    binary.add(data);
    inner.sendBytes(data);
  }

  @override
  Future<void> close() => inner.close();
}

Uint8List _chunk({bool loud = false}) {
  final bytes = Uint8List(3200);
  if (loud) {
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < 1600; i++) {
      view.setInt16(i * 2, i.isEven ? 30000 : -30000, Endian.little);
    }
  }
  return bytes;
}

void main() {
  group('assist_pipeline/run', () {
    late MockHomeAssistantServer server;
    late _RecordingSocket socket;
    late HaWebSocketManager ws;

    setUp(() async {
      server = MockHomeAssistantServer();
      ws = HaWebSocketManager(
        uri: Uri.parse('ws://mock/api/websocket'),
        readToken: () async => 'demo-token',
        connector: (uri) async =>
            socket = _RecordingSocket(await server.connect(uri)),
      )..connect();
      await ws.statusStream.firstWhere((s) => s.isConnected);
    });

    tearDown(() => ws.dispose());

    test('wake word, command, answer; audio as binary frames', () async {
      final audio = StreamController<Uint8List>.broadcast();
      final events = <WakeRunEvent>[];
      final done = Completer<void>();
      runWakeWordPipeline(
        ws,
        audio.stream,
      ).listen(events.add, onDone: done.complete);
      await pumpEventQueue();
      expect(events, [isA<WakeListening>()]);
      final run = socket.sent.last;
      expect(run, contains('"type":"assist_pipeline/run"'));
      expect(run, contains('"start_stage":"wake_word"'));
      expect(run, contains('"end_stage":"intent"'));
      expect(run, contains('"sample_rate":16000'));

      audio.add(_chunk());
      await pumpEventQueue();
      expect(socket.binary.single.length, 3201);
      expect(socket.binary.single.first, 1, reason: 'handler id prefix');
      expect(events, hasLength(1), reason: 'quiet: no wake word');

      audio.add(_chunk(loud: true));
      for (var i = 0; i < 5; i++) {
        audio.add(_chunk());
      }
      await done.future;
      expect(events.whereType<WakeDetected>(), hasLength(1));
      expect(events.whereType<WakeHeard>().single.text, 'turn off the lights');
      expect(
        events.whereType<WakeAnswer>().single.reply.speech,
        'Turned off the lights.',
      );
      expect(socket.binary.last.length, 1, reason: 'empty frame ends audio');
      expect(server.stateForTest('light.living_room_main'), 'off');
      final sentAfter = socket.binary.length;
      audio.add(_chunk());
      await pumpEventQueue();
      expect(socket.binary.length, sentAfter, reason: 'no audio after run');
      await audio.close();
    });

    test('no wake word engine: failure with Home Assistant\'s code', () async {
      server.wakeWordEngine = false;
      final error = Completer<Object>();
      runWakeWordPipeline(
        ws,
        const Stream.empty(),
      ).listen(null, onError: error.complete);
      final e = await error.future;
      expect(e, isA<AppFailure>());
      expect((e as AppFailure).code, 'wake-engine-missing');
      expect(wakeWordSetupErrors, contains(e.code));
    });
  });

  testWidgets('kiosk: opt in, wake word, answer spoken, light off', (
    tester,
  ) async {
    final mic = FakeClapPlatform();
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
      clap: mic,
      speech: speech,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'wakeWordSwitch');
    await settle(tester, 3);
    expect(find.text(en.wakeWordPrivacyBody), findsOneWidget);
    await tester.tap(find.byKey(const Key('wakeWordAllow')));
    await settle(tester, 3);
    expect(mic.pcmListeners, 0, reason: 'only listens inside the kiosk');

    await tapKey(tester, 'startKiosk');
    await settle(tester, 8);
    expect(mic.pcmListeners, 1);
    expect(find.byKey(const Key('wakeIndicator')), findsOneWidget);
    expect(find.byKey(const Key('wakeOverlay')), findsNothing);

    mic.emitAudio(3);
    await settle(tester, 2);
    expect(find.byKey(const Key('wakeOverlay')), findsNothing);

    mic.emitAudio(1, loud: true);
    await settle(tester, 2);
    expect(find.text(en.assistListening), findsOneWidget);

    mic.emitAudio(5);
    await settle(tester, 6);
    expect(find.text('turn off the lights'), findsOneWidget);
    expect(find.text('Turned off the lights.'), findsOneWidget);
    expect(speech.said, ['Turned off the lights.']);
    expect(server.stateForTest('light.living_room_main'), 'off');

    // Next run is listening again; the card goes away by itself.
    await tester.pump(const Duration(seconds: 9));
    await settle(tester, 4);
    expect(find.byKey(const Key('wakeOverlay')), findsNothing);
    expect(mic.pcmListeners, 1);

    // Assist sheet uses the microphone itself: wake word pauses.
    await tapKey(tester, 'kioskAssist');
    await settle(tester, 4);
    expect(mic.pcmListeners, 0);
    Navigator.of(tester.element(find.byKey(const Key('assistSheet')))).pop();
    await settle(tester, 6);
    expect(mic.pcmListeners, 1);

    await unmount(tester);
    expect(mic.pcmListeners, 0, reason: 'microphone released');
  });

  testWidgets('kiosk: Home Assistant without a wake word engine', (
    tester,
  ) async {
    final mic = FakeClapPlatform();
    final server = MockHomeAssistantServer()..wakeWordEngine = false;
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
      clap: mic,
      server: server,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'wakeWordSwitch');
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('wakeWordAllow')));
    await settle(tester, 3);
    await tapKey(tester, 'startKiosk');
    await settle(tester, 8);
    expect(find.text(en.wakeWordMissing), findsOneWidget);
    expect(mic.pcmListeners, 0, reason: 'microphone off again');
    await unmount(tester);
  });
}
