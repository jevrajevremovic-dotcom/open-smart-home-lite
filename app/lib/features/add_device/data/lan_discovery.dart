import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';

/// A service announced on the local network: a web server (`_http._tcp`)
/// or an ESPHome device (`_esphomelib._tcp`).
@immutable
class LanService {
  const LanService({
    required this.name,
    required this.host,
    this.port = 80,
    this.type = httpType,
    this.txt = const {},
  });

  static const httpType = '_http._tcp';
  static const esphomeType = '_esphomelib._tcp';
  static const hueType = '_hue._tcp';

  final String name;

  /// IPv4 address.
  final String host;
  final int port;
  final String type;

  /// TXT records (ESPHome: `mac`, `friendly_name`, `api_encryption`…).
  final Map<String, String> txt;

  bool get isEsphome => type.contains('_esphomelib');

  @override
  bool operator ==(Object other) =>
      other is LanService &&
      other.name == name &&
      other.host == host &&
      other.port == port &&
      other.type == type &&
      mapEquals(other.txt, txt);

  @override
  int get hashCode => Object.hash(name, host, port, type);
}

/// Finds services on the local network. Shelly and WLED announce web
/// servers, ESPHome devices their API; what each one is, the probe tells.
abstract interface class LanDiscovery {
  bool get isSupported;

  /// All services found so far, after each change. Ends (without error)
  /// when discovery is not possible; manual entry always works.
  Stream<List<LanService>> browse();
}

/// Android's NsdManager, through the app's channel (NsdDiscoveryHandler.kt).
class AndroidLanDiscovery implements LanDiscovery {
  static const _channel = EventChannel('org.opensmarthome/nsd');
  static const serviceTypes = [
    LanService.httpType,
    LanService.esphomeType,
    LanService.hueType,
  ];
  static final _log = AppLogger('Discovery');

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<List<LanService>> browse() {
    final found = <String, LanService>{};
    late final StreamController<List<LanService>> controller;
    StreamSubscription<Object?>? sub;

    void onEvent(Object? event) {
      if (event is! Map) return;
      final name = event['name'];
      if (name is! String) return;
      final type = event['type'] as String? ?? LanService.httpType;
      final id = '$type/$name';
      if (event['status'] == 'lost') {
        if (found.remove(id) != null) {
          controller.add(List.unmodifiable(found.values));
        }
        return;
      }
      final addresses = event['addresses'];
      final host = addresses is List
          ? addresses.whereType<String>().firstOrNull
          : null;
      if (host == null) return;
      found[id] = LanService(
        name: name,
        host: host,
        port: event['port'] as int? ?? 80,
        type: type,
        txt: {
          for (final e in ((event['txt'] as Map?) ?? const {}).entries)
            if (e.key is String)
              e.key as String: switch (e.value) {
                final Uint8List b => utf8.decode(b, allowMalformed: true),
                _ => '',
              },
        },
      );
      controller.add(List.unmodifiable(found.values));
    }

    controller = StreamController<List<LanService>>(
      onListen: () {
        sub = _channel
            .receiveBroadcastStream(serviceTypes)
            .listen(
              onEvent,
              onError: (Object e) {
                _log.warning('mDNS discovery unavailable', e.runtimeType);
                if (!controller.isClosed) unawaited(controller.close());
              },
            );
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}

final lanDiscoveryProvider = Provider<LanDiscovery>(
  (ref) => AndroidLanDiscovery(),
);
