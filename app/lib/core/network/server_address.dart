import 'package:flutter/foundation.dart';

/// Why a typed server address was rejected.
enum ServerAddressError {
  empty,
  malformed,
  unsupportedScheme,
  missingHost,
  credentialsNotAllowed,
  pathNotSupported,
  queryNotAllowed,
  invalidPort,

  /// A web app served over HTTPS may not call an `http://` server; the
  /// browser blocks it as mixed content.
  blockedMixedContent,
}

/// How risky it is to send a Home Assistant token to this address.
enum ConnectionRisk {
  /// HTTPS, or HTTP inside a private network.
  none,

  /// HTTPS to a public address: fine, but the user should know the server is
  /// exposed outside the home.
  remoteExposure,

  /// HTTP to a public address: the token would travel unencrypted over the
  /// internet. Requires an explicit acknowledgement (e.g. a VPN is in use).
  insecureRemote,

  /// A Tailscale address: reachable away from home, and WireGuard encrypts
  /// the traffic even over plain HTTP.
  vpnTunnel,
}

/// Result of [ServerAddress.parse].
sealed class ServerAddressParseResult {
  const ServerAddressParseResult();
}

final class ValidServerAddress extends ServerAddressParseResult {
  const ValidServerAddress(this.address);
  final ServerAddress address;
}

final class InvalidServerAddress extends ServerAddressParseResult {
  const InvalidServerAddress(this.error);
  final ServerAddressError error;
}

/// A validated, normalised Home Assistant base URL.
///
/// Home Assistant does not support being served from a sub-path, so only
/// `scheme://host[:port]` is accepted.
@immutable
class ServerAddress {
  const ServerAddress._(this.baseUri);

  /// Rebuilds an address from a value previously produced by [baseUri].
  factory ServerAddress.fromStored(String value) {
    final result = parse(value);
    return switch (result) {
      ValidServerAddress(:final address) => address,
      InvalidServerAddress(:final error) => throw FormatException(
        'Stored server address is invalid: ${error.name}',
      ),
    };
  }

  /// Origin only, without trailing slash, e.g. `http://192.168.1.10:8123`.
  final Uri baseUri;

  bool get isSecure => baseUri.scheme == 'https';
  String get host => baseUri.host;

  /// True for loopback, RFC 1918, link-local, IPv6 ULA, mDNS `.local`,
  /// `.home.arpa`, and single-label host names.
  bool get isLocalNetwork => isLocalHost(baseUri.host);

  /// Tailscale: 100.64.0.0/10, fd7a:115c:a1e0::/48 or a `*.ts.net` name.
  bool get isTailscale => isTailscaleHost(baseUri.host);

  ConnectionRisk get risk {
    // Before the local check: Tailscale's IPv6 range sits inside fc00::/7.
    if (isTailscale) return ConnectionRisk.vpnTunnel;
    if (isLocalNetwork) return ConnectionRisk.none;
    return isSecure
        ? ConnectionRisk.remoteExposure
        : ConnectionRisk.insecureRemote;
  }

  /// REST endpoint, e.g. `restUri('/api/states')`.
  Uri restUri(String path) => baseUri.replace(path: path);

  /// `ws://host/api/websocket` or `wss://host/api/websocket`.
  Uri get webSocketUri =>
      baseUri.replace(scheme: isSecure ? 'wss' : 'ws', path: '/api/websocket');

  /// Stable identifier used as key for per-server secure storage entries.
  String get id => baseUri.toString();

  @override
  String toString() => baseUri.toString();

  @override
  bool operator ==(Object other) =>
      other is ServerAddress && other.baseUri == baseUri;

  @override
  int get hashCode => baseUri.hashCode;

  static final RegExp _schemePrefix = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

  /// Parses user input such as `homeassistant.local:8123`,
  /// `192.168.1.10:8123` or `https://ha.example.com`.
  ///
  /// When no scheme is given, `http` is assumed for local addresses (Home
  /// Assistant's default) and `https` for everything else.
  static ServerAddressParseResult parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const InvalidServerAddress(ServerAddressError.empty);
    }
    if (trimmed.contains(RegExp(r'\s'))) {
      return const InvalidServerAddress(ServerAddressError.malformed);
    }

    final hasScheme = _schemePrefix.hasMatch(trimmed);
    Uri uri;
    try {
      uri = Uri.parse(hasScheme ? trimmed : 'http://$trimmed');
    } on FormatException {
      return const InvalidServerAddress(ServerAddressError.malformed);
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return const InvalidServerAddress(ServerAddressError.unsupportedScheme);
    }
    if (uri.host.isEmpty) {
      return const InvalidServerAddress(ServerAddressError.missingHost);
    }
    if (uri.userInfo.isNotEmpty) {
      return const InvalidServerAddress(
        ServerAddressError.credentialsNotAllowed,
      );
    }
    if (uri.hasQuery || uri.hasFragment) {
      return const InvalidServerAddress(ServerAddressError.queryNotAllowed);
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      return const InvalidServerAddress(ServerAddressError.pathNotSupported);
    }
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return const InvalidServerAddress(ServerAddressError.invalidPort);
    }
    final host = uri.host.toLowerCase();
    if (!_isValidHost(host)) {
      return const InvalidServerAddress(ServerAddressError.malformed);
    }

    final effectiveScheme = hasScheme
        ? scheme
        : (isLocalHost(host) ? 'http' : 'https');

    final normalised = Uri(
      scheme: effectiveScheme,
      host: host,
      port: uri.hasPort ? uri.port : null,
    );
    return ValidServerAddress(ServerAddress._(normalised));
  }

  static bool _isValidHost(String host) {
    if (_parseIp(host) != null) return true;
    final label = RegExp(r'^(?!-)[a-z0-9-]{1,63}(?<!-)$');
    final labels = host.endsWith('.')
        ? host.substring(0, host.length - 1).split('.')
        : host.split('.');
    return host.length <= 253 && labels.every(label.hasMatch);
  }

  static const List<String> _localSuffixes = [
    '.local',
    '.lan',
    '.home',
    '.home.arpa',
    '.internal',
    '.localdomain',
    '.localhost',
  ];

  /// Whether [host] is a Tailscale (VPN) address.
  @visibleForTesting
  static bool isTailscaleHost(String host) {
    final lower = host.toLowerCase();
    if (lower.endsWith('.ts.net')) return true;
    final ip = _parseIp(lower);
    if (ip == null) return false;
    if (ip.length == 4) return ip[0] == 100 && (ip[1] & 0xc0) == 64;
    return ip[0] == 0xfd &&
        ip[1] == 0x7a &&
        ip[2] == 0x11 &&
        ip[3] == 0x5c &&
        ip[4] == 0xa1 &&
        ip[5] == 0xe0;
  }

  /// Whether [host] is very likely only reachable inside the local network.
  @visibleForTesting
  static bool isLocalHost(String host) {
    final lower = host.toLowerCase();
    final ip = _parseIp(lower);
    if (ip != null) return _isPrivateIp(ip);
    if (lower == 'localhost') return true;
    if (!lower.contains('.')) return true; // single-label LAN name
    return _localSuffixes.any(lower.endsWith);
  }

  /// Raw bytes of an IPv4 (4 bytes) or IPv6 (16 bytes) literal, else `null`.
  /// Pure Dart (no `dart:io`) so it also works on the web.
  static List<int>? _parseIp(String host) {
    try {
      return host.contains(':')
          ? Uri.parseIPv6Address(host)
          : (RegExp(r'^[0-9.]+$').hasMatch(host)
                ? Uri.parseIPv4Address(host)
                : null);
    } on FormatException {
      return null;
    }
  }

  static bool _isPrivateIp(List<int> b) {
    if (b.length == 4) {
      return b[0] == 10 ||
          b[0] == 127 || // loopback
          (b[0] == 169 && b[1] == 254) || // link-local
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168);
    }
    final isLoopback = b.take(15).every((x) => x == 0) && b[15] == 1; // ::1
    final isLinkLocal = b[0] == 0xfe && (b[1] & 0xc0) == 0x80; // fe80::/10
    final isUniqueLocal = (b[0] & 0xfe) == 0xfc; // fc00::/7
    return isLoopback || isLinkLocal || isUniqueLocal;
  }
}
