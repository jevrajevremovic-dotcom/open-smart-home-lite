import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The kiosk microphone: loudness levels for clap detection and audio for
/// the wake word. One recorder serves both (MainActivity's
/// AudioLevelHandler.kt).
abstract interface class ClapPlatform {
  bool get supported;

  /// Asks for the microphone permission; `true` when granted.
  Future<bool> requestPermission();

  /// Loudness, one per 20 ms frame (0…1). No audio is recorded or leaves
  /// the device. Listening starts with the subscription and stops when it is
  /// cancelled.
  Stream<double> levels();

  /// Raw 16 kHz 16-bit mono PCM in 100 ms chunks, for the wake word (sent to
  /// the user's own Home Assistant only). Same lifetime as [levels].
  Stream<Uint8List> pcm();
}

/// MainActivity's `audio_level` stream (AudioLevelHandler.kt).
class AndroidClapPlatform implements ClapPlatform {
  static const _levels = EventChannel('org.opensmarthome/audio_level');
  static const _pcm = EventChannel('org.opensmarthome/audio_pcm');
  static const _microphone = MethodChannel('org.opensmarthome/microphone');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> requestPermission() async {
    try {
      return await _microphone.invokeMethod<bool>('request') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<double> levels() =>
      _levels.receiveBroadcastStream().map((e) => e is num ? e.toDouble() : 0);

  @override
  Stream<Uint8List> pcm() => _pcm.receiveBroadcastStream().map(
    (e) => e is Uint8List ? e : Uint8List(0),
  );
}

final clapPlatformProvider = Provider<ClapPlatform>(
  (ref) => AndroidClapPlatform(),
);
