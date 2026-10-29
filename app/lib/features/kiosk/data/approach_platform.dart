import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Movement in front of the tablet (front camera), for waking the idle
/// kiosk. Frames are analysed on the tablet and dropped at once
/// (MotionHandler.kt).
abstract interface class ApproachPlatform {
  bool get supported;

  /// Asks for the camera permission; `true` when granted.
  Future<bool> requestPermission();

  /// One event per movement. The camera runs only while subscribed.
  Stream<void> motion();
}

class AndroidApproachPlatform implements ApproachPlatform {
  static const _motion = EventChannel('org.opensmarthome/motion');
  static const _camera = MethodChannel('org.opensmarthome/camera');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> requestPermission() async {
    try {
      return await _camera.invokeMethod<bool>('request') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<void> motion() => _motion.receiveBroadcastStream().map((_) {});
}

final approachPlatformProvider = Provider<ApproachPlatform>(
  (ref) => AndroidApproachPlatform(),
);
