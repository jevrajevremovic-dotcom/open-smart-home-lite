import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/server_address.dart';
import 'server_discovery_io.dart'
    if (dart.library.js_interop) 'server_discovery_web.dart';

/// Home Assistant announces itself via zeroconf as `_home-assistant._tcp`.
const String homeAssistantServiceType = '_home-assistant._tcp';

@immutable
class DiscoveredServer {
  const DiscoveredServer({
    required this.name,
    required this.address,
    this.version,
    this.uuid,
  });

  final String name;
  final ServerAddress address;
  final String? version;

  /// Instance id from the TXT record; identifies a server across addresses.
  final String? uuid;

  String get key => uuid ?? address.id;
}

/// Finds Home Assistant servers on the local network.
abstract interface class ServerDiscovery {
  /// `false` where mDNS is impossible (web browsers) or not implemented.
  bool get isSupported;

  /// Emits the growing list of servers found; cancel to stop searching.
  Stream<List<DiscoveredServer>> discover();
}

/// Builds a [DiscoveredServer] from one resolved zeroconf service.
///
/// Address preference:
/// 1. an HTTPS `internal_url` the user configured (its certificate is
///    issued for that name, so an IP would fail TLS);
/// 2. `http://<IPv4>:<port>` from the resolved service – IPs work on every
///    phone, while `.local` names are not resolvable by plain sockets on
///    Android before version 12;
/// 3. `internal_url` / `base_url` from the TXT record;
/// 4. `http://<host>:<port>`.
/// Only addresses inside the local network are accepted: a TXT record must
/// not be able to point the app at an arbitrary internet host.
DiscoveredServer? discoveredServerFrom({
  required String? serviceName,
  required String? host,
  required int? port,
  required List<String> ipv4Addresses,
  required Map<String, String?> txt,
}) {
  ServerAddress? local(String? candidate) {
    if (candidate == null || candidate.isEmpty) return null;
    final parsed = ServerAddress.parse(candidate);
    return parsed is ValidServerAddress && parsed.address.isLocalNetwork
        ? parsed.address
        : null;
  }

  final internal = txt['internal_url'];
  final hostName = host?.endsWith('.') ?? false
      ? host!.substring(0, host.length - 1)
      : host;
  final address =
      (internal != null && internal.startsWith('https://')
          ? local(internal)
          : null) ??
      (port == null
          ? null
          : ipv4Addresses
                .map((ip) => local('http://$ip:$port'))
                .nonNulls
                .firstOrNull) ??
      local(internal) ??
      local(txt['base_url']) ??
      (hostName == null || port == null
          ? null
          : local('http://$hostName:$port'));
  if (address == null) return null;

  final name = txt['location_name'];
  return DiscoveredServer(
    name: name != null && name.isNotEmpty
        ? name
        : (serviceName ?? address.host),
    address: address,
    version: txt['version'],
    uuid: txt['uuid'],
  );
}

/// Mock mode: one demo server appears after a short "search".
class MockServerDiscovery implements ServerDiscovery {
  @override
  bool get isSupported => true;

  @override
  Stream<List<DiscoveredServer>> discover() async* {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    yield [
      DiscoveredServer(
        name: 'Demo dom (mock)',
        address: (ServerAddress.parse(
          'http://homeassistant.local:8123',
        ) as ValidServerAddress).address,
        version: '2026.10.0-mock',
        uuid: 'mock-uuid',
      ),
    ];
  }
}

final serverDiscoveryProvider = Provider<ServerDiscovery>((ref) {
  if (ref.watch(appConfigProvider).mockMode) return MockServerDiscovery();
  return createPlatformServerDiscovery();
});
