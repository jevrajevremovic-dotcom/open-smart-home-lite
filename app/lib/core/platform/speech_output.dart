import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spoken announcements (the device's own text-to-speech).
abstract interface class SpeechOutput {
  bool get supported;

  /// Says [text]; completes when done (`false` if it could not be said).
  Future<bool> speak(String text, {required String languageTag});

  Future<void> stop();
}

class AndroidSpeechOutput implements SpeechOutput {
  static const _channel = MethodChannel('org.opensmarthome/tts');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> speak(String text, {required String languageTag}) async =>
      await _channel.invokeMethod<bool>('speak', {
        'text': text,
        'language': languageTag,
      }) ??
      false;

  @override
  Future<void> stop() => _channel.invokeMethod('stop');
}

final speechOutputProvider = Provider<SpeechOutput>(
  (ref) => AndroidSpeechOutput(),
);
