import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../integrations/home_assistant/models/ha_conversation.dart';
import '../../../integrations/home_assistant/websocket/ha_websocket_manager.dart';

/// What happens during one wake word run, in order.
@immutable
sealed class WakeRunEvent {
  const WakeRunEvent();
}

/// Home Assistant is listening for the wake word.
class WakeListening extends WakeRunEvent {
  const WakeListening();
}

/// The wake word was heard; the command follows.
class WakeDetected extends WakeRunEvent {
  const WakeDetected();
}

/// Speech-to-text result.
class WakeHeard extends WakeRunEvent {
  const WakeHeard(this.text);

  final String text;
}

/// Home Assistant's answer.
class WakeAnswer extends WakeRunEvent {
  const WakeAnswer(this.reply);

  final HaConversationReply reply;
}

/// A pipeline error event (`code` as Home Assistant sends it, e.g.
/// `wake-word-timeout`, `stt-no-text-recognized`, `timeout`).
class WakeRunError extends WakeRunEvent {
  const WakeRunError(this.code);

  final String code;
}

/// Error codes after which retrying is pointless until the user changes
/// something in Home Assistant (no wake word engine set up).
const wakeWordSetupErrors = {'wake-engine-missing', 'wake-provider-missing'};

/// Audio Assist pipelines expect: 16 kHz, 16-bit, mono.
const wakeWordSampleRate = 16000;

/// One `assist_pipeline/run` from the wake word to the answer
/// (https://developers.home-assistant.io/docs/voice/pipelines/).
///
/// Home Assistant (with a wake word engine such as openWakeWord) listens to
/// [audio]: once `run-start` names the binary handler, every chunk goes to
/// it as a binary frame. After the command was heard the audio stops (an
/// empty frame ends the stream). The answer is not synthesised by Home
/// Assistant (end stage `intent`): the tablet speaks it itself.
///
/// The stream ends with `run-end`. Validation errors (no wake word engine,
/// …) arrive as an [AppFailure] with Home Assistant's `code`. Cancelling
/// the subscription unsubscribes, which cancels the run on the server.
Stream<WakeRunEvent> runWakeWordPipeline(
  HaWebSocketManager ws,
  Stream<Uint8List> audio, {
  String? conversationId,
}) {
  // Both cancelled in finish().
  // ignore: cancel_subscriptions
  StreamSubscription<Map<String, Object?>>? events;
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? mic;
  int? handler;
  late final StreamController<WakeRunEvent> out;

  Future<void> stopAudio({bool endStream = false}) async {
    final sub = mic;
    mic = null;
    await sub?.cancel();
    if (endStream && sub != null && handler != null) {
      ws.sendBinary(handler!, const []);
    }
  }

  Future<void> finish() async {
    await stopAudio();
    final sub = events;
    events = null;
    await sub?.cancel();
    if (!out.isClosed) await out.close();
  }

  out = StreamController<WakeRunEvent>(
    onListen: () {
      events = ws
          .subscribeCommand({
            'type': 'assist_pipeline/run',
            'start_stage': 'wake_word',
            'end_stage': 'intent',
            'input': {
              'sample_rate': wakeWordSampleRate,
              // 0 = no silence timeout: listen until the wake word is heard
              // (the whole run still ends after Home Assistant's default
              // pipeline timeout, then the caller starts a new one).
              'timeout': 0,
              'noise_suppression_level': 2,
              'auto_gain_dbfs': 0,
            },
            'conversation_id': ?conversationId,
          })
          .listen(
            (event) {
              final data = event['data'];
              final map = data is Map ? data : const <String, Object?>{};
              switch (event['type']) {
                case 'run-start':
                  final runner = map['runner_data'];
                  final id = runner is Map
                      ? runner['stt_binary_handler_id']
                      : null;
                  if (id is! int) {
                    out.add(const WakeRunError('no-audio-handler'));
                    unawaited(finish());
                    return;
                  }
                  handler = id;
                  mic = audio.listen((chunk) => ws.sendBinary(id, chunk));
                  out.add(const WakeListening());
                case 'wake_word-end':
                  out.add(const WakeDetected());
                case 'stt-end':
                  unawaited(stopAudio(endStream: true));
                  final output = map['stt_output'];
                  final text = output is Map ? output['text'] : null;
                  out.add(WakeHeard(text is String ? text : ''));
                case 'intent-end':
                  out.add(
                    WakeAnswer(HaConversationReply.parse(map['intent_output'])),
                  );
                case 'error':
                  unawaited(stopAudio(endStream: true));
                  final code = map['code'];
                  out.add(WakeRunError(code is String ? code : 'unknown'));
                case 'run-end':
                  unawaited(finish());
              }
            },
            onError: (Object e) {
              if (!out.isClosed) out.addError(e);
              unawaited(finish());
            },
            onDone: () => unawaited(finish()),
          );
    },
    onCancel: finish,
  );
  return out.stream;
}
