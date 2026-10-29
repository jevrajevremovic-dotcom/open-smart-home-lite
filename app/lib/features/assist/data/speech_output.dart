import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Assist's spoken answers (the device's own text-to-speech).
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

/// The app was opened as the phone's assistant (long press of home or
/// power): Assist opens, listening.
abstract interface class AssistLaunchPlatform {
  bool get supported;

  /// Whether this start of the app was such a launch (asked once).
  Future<bool> launchedAsAssistant();

  /// Later launches while the app runs.
  Stream<void> get launches;

  /// Android's screen for choosing the digital assistant app.
  Future<void> openAssistantSettings();
}

class AndroidAssistLaunch implements AssistLaunchPlatform {
  AndroidAssistLaunch() {
    if (supported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'open') _launches.add(null);
      });
    }
  }

  static const _channel = MethodChannel('org.opensmarthome/assist');
  final _launches = StreamController<void>.broadcast();

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> launchedAsAssistant() async =>
      await _channel.invokeMethod<bool>('initial') ?? false;

  @override
  Stream<void> get launches => _launches.stream;

  @override
  Future<void> openAssistantSettings() => _channel.invokeMethod('openSettings');
}
