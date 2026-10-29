import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nsd_platform_interface/nsd_platform_interface.dart' as nsd;

import '../../../core/logging/app_logger.dart';
import 'server_discovery.dart';

ServerDiscovery createPlatformServerDiscovery() =>
    Platform.isAndroid ? AndroidServerDiscovery() : NsdServerDiscovery();

final _log = AppLogger('Discovery');

String? _text(Uint8List? bytes) =>
    bytes == null ? null : utf8.decode(bytes, allowMalformed: true);

/// Android: the app's own NsdManager channel (see NsdDiscoveryHandler.kt).
class AndroidServerDiscovery implements ServerDiscovery {
  static const _channel = EventChannel('org.opensmarthome/nsd');

  @override
  bool get isSupported => true;

  @override
  Stream<List<DiscoveredServer>> discover() {
    final found = <String, DiscoveredServer>{};
    final keyByName = <String, String>{};
    late final StreamController<List<DiscoveredServer>> controller;
    StreamSubscription<Object?>? sub;

    void onEvent(Object? event) {
      if (event is! Map) return;
      final name = event['name'] as String?;
      if (event['status'] == 'lost') {
        final key = keyByName.remove(name);
        if (key != null && found.remove(key) != null) {
          controller.add(List.unmodifiable(found.values));
        }
        return;
      }
      final server = discoveredServerFrom(
        serviceName: name,
        host: null,
        port: event['port'] as int?,
        ipv4Addresses: [
          for (final a in (event['addresses'] as List?) ?? const [])
            if (a is String) a,
        ],
        txt: {
          for (final e in ((event['txt'] as Map?) ?? const {}).entries)
            if (e.key is String)
              e.key as String: _text(switch (e.value) {
                final Uint8List b => b,
                _ => null,
              }),
        },
      );
      if (server == null) return;
      if (name != null) keyByName[name] = server.key;
      found[server.key] = server;
      controller.add(List.unmodifiable(found.values));
    }

    controller = StreamController<List<DiscoveredServer>>(
      onListen: () {
        sub = _channel
            .receiveBroadcastStream(homeAssistantServiceType)
            .listen(
              onEvent,
              onError: (Object e) {
                // Discovery is a convenience, manual entry always works.
                _log.warning('mDNS discovery unavailable', e.runtimeType);
                if (!controller.isClosed) controller.close();
              },
            );
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}

/// Apple Bonjour and Windows, through the `nsd` platform plugins.
class NsdServerDiscovery implements ServerDiscovery {
  @override
  bool get isSupported =>
      Platform.isIOS || Platform.isMacOS || Platform.isWindows;

  @override
  Stream<List<DiscoveredServer>> discover() {
    nsd.Discovery? discovery;
    final found = <String, DiscoveredServer>{};
    late final StreamController<List<DiscoveredServer>> controller;

    void onService(nsd.Service service, nsd.ServiceStatus status) {
      final server = discoveredServerFrom(
        serviceName: service.name,
        host: service.host,
        port: service.port,
        ipv4Addresses: [
          for (final a in service.addresses ?? const <InternetAddress>[])
            if (a.type == InternetAddressType.IPv4) a.address,
        ],
        txt: {
          for (final e in (service.txt ?? const {}).entries)
            e.key: _text(e.value),
        },
      );
      if (server == null) return;
      if (status == nsd.ServiceStatus.found) {
        found[server.key] = server;
      } else {
        found.remove(server.key);
      }
      if (!controller.isClosed) controller.add(List.unmodifiable(found.values));
    }

    controller = StreamController<List<DiscoveredServer>>(
      onListen: () async {
        try {
          discovery = await nsd.NsdPlatformInterface.instance.startDiscovery(
            homeAssistantServiceType,
            ipLookupType: nsd.IpLookupType.v4,
          );
          discovery!.addServiceListener(onService);
        } on Object catch (e) {
          // Missing plugin (desktop/tests) or OS refusal: discovery is a
          // convenience, manual entry always works.
          _log.warning('mDNS discovery unavailable', e.runtimeType);
          if (!controller.isClosed) await controller.close();
        }
      },
      onCancel: () async {
        final d = discovery;
        discovery = null;
        if (d != null) {
          try {
            await nsd.NsdPlatformInterface.instance.stopDiscovery(d);
          } on Object catch (e) {
            _log.debug('stopDiscovery failed: ${e.runtimeType}');
          }
        }
      },
    );
    return controller.stream;
  }
}
