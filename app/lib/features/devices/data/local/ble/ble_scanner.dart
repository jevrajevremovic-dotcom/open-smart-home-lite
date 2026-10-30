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

  /// The app's settings, where a permission refused for good is allowed.
  Future<void> openSettings();

  /// Every advertisement while listened to; one scan shared by all
  /// listeners. Fails with [BleScanError].
  Stream<BleAdvert> scan();

  /// Connects to [address] for a moment and writes [value] to its
  /// [characteristic] (UUIDs as text). Throws [BleScanError].
  Future<void> write(
    String address,
    String service,
    String characteristic,
    List<int> value,
  );
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
  Future<void> openSettings() async {
    try {
      await _permission.invokeMethod<void>('openSettings');
    } on Object {
      // Nothing more to do.
    }
  }

  @override
  Stream<BleAdvert> scan() => _shared.stream;

  static const _gatt = MethodChannel('org.opensmarthome/ble_gatt');

  @override
  Future<void> write(
    String address,
    String service,
    String characteristic,
    List<int> value,
  ) async {
    try {
      await _gatt.invokeMethod<bool>('write', {
        'address': address,
        'service': service,
        'characteristic': characteristic,
        'value': Uint8List.fromList(value),
      });
    } on PlatformException catch (e) {
      throw BleScanError(e.code);
    } on MissingPluginException {
      throw const BleScanError('unsupported');
    }
  }

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
