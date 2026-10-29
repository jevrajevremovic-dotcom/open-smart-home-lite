import 'server_discovery.dart';

/// Browsers cannot send or receive mDNS; the web build instead suggests the
/// page's own origin when Home Assistant hosts the app.
ServerDiscovery createPlatformServerDiscovery() => const _NoDiscovery();

class _NoDiscovery implements ServerDiscovery {
  const _NoDiscovery();

  @override
  bool get isSupported => false;

  @override
  Stream<List<DiscoveredServer>> discover() => const Stream.empty();
}
