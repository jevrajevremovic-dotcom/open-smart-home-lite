import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble_advert.dart';

/// Why there are no advertisements.
class BleScanError implements Exception {
  const BleScanError(this.reason);

  /// `permission`, `off` (Bluetooth off), `unsupported` or `failed`.
  final String reason;

  @override
  String toString() => 'BleScanError($reason)';
}

/// Bluetooth LE advertisements of the sensors the app reads.
abstract interface class BleScanner {
  bool get supported;
  Future<bool> hasPermission();

  /// Asks the person (Android's dialog); `true` when allowed.
  Future<bool> requestPermission();

  /// Every advertisement while listened to; one scan shared by all
  /// listeners. Fails with [BleScanError].
  Stream<BleAdvert> scan();
}

class AndroidBleScanner implements BleScanner {
  static const _events = EventChannel('org.opensmarthome/ble');
  static const _permission = MethodChannel('org.opensmarthome/ble_permission');

  // Android takes one listener per channel: the scan is shared.
  late final StreamController<BleAdvert> _shared =
      StreamController<BleAdvert>.broadcast(
        onListen: _start,
        onCancel: () => unawaited(_platform?.cancel()),
      );
  StreamSubscription<Object?>? _platform;

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _permission.invokeMethod<bool>('granted') ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _permission.invokeMethod<bool>('request') ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Stream<BleAdvert> scan() => _shared.stream;

  void _start() {
    _platform = _events.receiveBroadcastStream().listen(
      (event) {
        final advert = advertFromPlatform(event);
        if (advert != null) _shared.add(advert);
      },
      onError: (Object e) => _shared.addError(
        BleScanError(e is PlatformException ? e.code : 'failed'),
      ),
    );
  }
}

/// The map BleScanHandler.kt sends.
@visibleForTesting
BleAdvert? advertFromPlatform(Object? event) {
  if (event is! Map || event['address'] is! String) return null;
  // `0000fcd2-0000-1000-8000-00805f9b34fb` → 0xFCD2.
  int? short(Object? uuid) => uuid is String && uuid.length >= 8
      ? int.tryParse(uuid.substring(4, 8), radix: 16)
      : null;
  return BleAdvert(
    address: event['address'] as String,
    name: event['name'] as String?,
    rssi: event['rssi'] as int?,
    serviceData: {
      for (final e in ((event['serviceData'] as Map?) ?? const {}).entries)
        if ((short(e.key), e.value) case (final int id, final Uint8List data))
          id: data,
    },
    manufacturerData: {
      for (final e in ((event['manufacturerData'] as Map?) ?? const {}).entries)
        if ((e.key, e.value) case (final int id, final Uint8List data))
          id: data,
    },
  );
}

final bleScannerProvider = Provider<BleScanner>((ref) => AndroidBleScanner());
