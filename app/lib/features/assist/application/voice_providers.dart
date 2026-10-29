import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../data/speech_output.dart';
import '../data/voice_input.dart';

final voiceInputProvider = Provider<VoiceInput>(
  (ref) => SpeechToTextVoiceInput(),
);

/// Voice privacy choice, asked once before the first recording:
/// `null` = not asked yet, `false` = on-device recognition only,
/// `true` = the phone's online recogniser is allowed too.
class VoiceCloudController extends Notifier<bool?> {
  static const _key = 'assist.voice';

  @override
  bool? build() {
    final json = ref.watch(appPreferencesProvider).readJson(_key);
    return json?['cloudAllowed'] as bool?;
  }

  Future<void> set(bool? cloudAllowed) async {
    state = cloudAllowed;
    await ref
        .read(appPreferencesProvider)
        .writeJson(
          _key,
          cloudAllowed == null ? null : {'cloudAllowed': cloudAllowed},
        );
  }
}

final voiceCloudAllowedProvider = NotifierProvider<VoiceCloudController, bool?>(
  VoiceCloudController.new,
);

final speechOutputProvider = Provider<SpeechOutput>(
  (ref) => AndroidSpeechOutput(),
);

final assistLaunchProvider = Provider<AssistLaunchPlatform>(
  (ref) => AndroidAssistLaunch(),
);

/// Answers to spoken questions are spoken too (on by default).
class AssistSpeakController extends Notifier<bool> {
  static const _key = 'assist.speak';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] != false;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? null : {'enabled': false});
  }
}

final assistSpeakProvider = NotifierProvider<AssistSpeakController, bool>(
  AssistSpeakController.new,
);

/// Number of Assist sheets on screen (they may use the microphone, so the
/// kiosk wake word pauses meanwhile).
class AssistOpenController extends Notifier<int> {
  @override
  int build() => 0;

  void opened() {
    if (ref.mounted) state++;
  }

  void closed() {
    if (ref.mounted && state > 0) state--;
  }
}

final assistOpenProvider = NotifierProvider<AssistOpenController, int>(
  AssistOpenController.new,
);
