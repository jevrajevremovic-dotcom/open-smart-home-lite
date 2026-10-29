import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why voice input could not start or stopped early.
enum VoiceError {
  /// No speech recogniser or no microphone permission.
  unavailable,

  /// Only on-device recognition is allowed but this phone has none for
  /// the language.
  onDeviceUnavailable,

  /// Nothing was understood.
  noMatch,

  /// Anything else (network, busy, …).
  failed,
}

/// Speech-to-text, behind an interface so tests and mock mode can fake it.
abstract interface class VoiceInput {
  /// Asks for the microphone permission on first use.
  Future<bool> initialize();

  /// Listens once. [onText] receives partial and final text; the future
  /// completes with the final text, or an error as [VoiceError].
  Future<String> listen({
    required String languageTag,
    required bool onDeviceOnly,
    required void Function(String text) onText,
  });

  Future<void> stop();
}

class SpeechToTextVoiceInput implements VoiceInput {
  final SpeechToText _stt = SpeechToText();
  Completer<String>? _pending;
  String _last = '';

  @override
  Future<bool> initialize() => _stt.initialize(
    onError: (e) => _finish(
      error:
          e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout'
          ? VoiceError.noMatch
          : e.errorMsg.contains('language') || e.errorMsg.contains('on_device')
          ? VoiceError.onDeviceUnavailable
          : VoiceError.failed,
    ),
    onStatus: (status) {
      if (status == SpeechToText.doneStatus) _finish();
    },
  );

  @override
  Future<String> listen({
    required String languageTag,
    required bool onDeviceOnly,
    required void Function(String text) onText,
  }) async {
    if (!_stt.isAvailable && !await initialize()) {
      throw VoiceError.unavailable;
    }
    final pending = _pending = Completer<String>();
    _last = '';
    final locale = await _bestLocale(languageTag);
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        _last = r.recognizedWords;
        onText(_last);
        if (r.finalResult) _finish();
      },
      listenOptions: SpeechListenOptions(
        localeId: locale,
        onDevice: onDeviceOnly,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 20),
      ),
    );
    return pending.future;
  }

  Future<String?> _bestLocale(String languageTag) async {
    final wanted = languageTag.toLowerCase().split(RegExp('[-_]')).first;
    final locales = await _stt.locales();
    String id(String s) => s.toLowerCase().replaceAll('-', '_');
    for (final preferred in ['${wanted}_rs', '${wanted}_us', wanted]) {
      for (final l in locales) {
        if (id(l.localeId).startsWith(preferred)) return l.localeId;
      }
    }
    return null; // system default
  }

  void _finish({VoiceError? error}) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    _pending = null;
    if (error != null && _last.isEmpty) {
      pending.completeError(error);
    } else if (_last.trim().isEmpty) {
      pending.completeError(VoiceError.noMatch);
    } else {
      pending.complete(_last);
    }
  }

  @override
  Future<void> stop() async {
    await _stt.stop();
    _finish();
  }
}

/// Test / demo stand-in: "hears" [phrase] word by word.
class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput(this.phrase, {this.available = true});

  final String phrase;
  final bool available;
  bool? lastOnDeviceOnly;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<String> listen({
    required String languageTag,
    required bool onDeviceOnly,
    required void Function(String text) onText,
  }) async {
    if (!available) throw VoiceError.unavailable;
    lastOnDeviceOnly = onDeviceOnly;
    final words = phrase.split(' ');
    for (var i = 1; i <= words.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      onText(words.take(i).join(' '));
    }
    return phrase;
  }

  @override
  Future<void> stop() async {}
}
