import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint / face / device PIN check, behind an interface for tests.
abstract interface class DeviceAuth {
  /// Whether this device has a screen lock or biometrics to check against.
  Future<bool> isAvailable();

  /// Shows the system prompt; `true` when the user passed.
  Future<bool> authenticate(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // Device PIN/pattern is allowed as a fallback for biometrics.
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}

class FakeDeviceAuth implements DeviceAuth {
  FakeDeviceAuth({this.available = true, this.passes = true});

  bool available;
  bool passes;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return passes;
  }
}
