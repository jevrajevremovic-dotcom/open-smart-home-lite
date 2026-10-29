import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';

/// A web server announced on the local network (mDNS `_http._tcp`).
@immutable
class LanService {
  const LanService({required this.name, required this.host, this.port = 80});

  final String name;

  /// IPv4 address.
  final String host;
  final int port;

  @override
  bool operator ==(Object other) =>
      other is LanService &&
      other.name == name &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(name, host, port);
}

/// Finds web servers on the local network. Shelly and WLED announce
/// themselves this way; what each one is, the probe tells.
abstract interface class LanDiscovery {
  bool get isSupported;

  /// All services found so far, after each change. Ends (without error)
  /// when discovery is not possible; manual entry always works.
  Stream<List<LanService>> browse();
}

/// Android's NsdManager, through the app's channel (NsdDiscoveryHandler.kt).
class AndroidLanDiscovery implements LanDiscovery {
  static const _channel = EventChannel('org.opensmarthome/nsd');
  static const serviceType = '_http._tcp';
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
      if (event['status'] == 'lost') {
        if (found.remove(name) != null) {
          controller.add(List.unmodifiable(found.values));
        }
        return;
      }
      final addresses = event['addresses'];
      final host = addresses is List
          ? addresses.whereType<String>().firstOrNull
          : null;
      if (host == null) return;
      found[name] = LanService(
        name: name,
        host: host,
        port: event['port'] as int? ?? 80,
      );
      controller.add(List.unmodifiable(found.values));
    }

    controller = StreamController<List<LanService>>(
      onListen: () {
        sub = _channel
            .receiveBroadcastStream(serviceType)
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
