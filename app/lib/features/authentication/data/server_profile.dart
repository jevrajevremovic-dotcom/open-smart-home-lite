import 'package:flutter/foundation.dart';

import '../../../core/network/server_address.dart';
import '../../../core/network/tls_trust.dart';

/// Non-secret description of the connected server. Persisted in
/// preferences; the access token is stored separately in secure storage.
@immutable
class ServerProfile {
  const ServerProfile({
    required this.address,
    this.pinnedCertificateSha256,
    this.insecureConnectionAcknowledged = false,
    this.remoteAddress,
  });

  /// Returns `null` for missing or invalid stored data.
  static ServerProfile? tryFromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final url = json['url'];
    if (url is! String) return null;
    final parsed = ServerAddress.parse(url);
    if (parsed is! ValidServerAddress) return null;
    final pin = json['pinnedCertificateSha256'];
    final remote = switch (json['remoteUrl']) {
      final String r => switch (ServerAddress.parse(r)) {
        ValidServerAddress(:final address) => address,
        _ => null,
      },
      _ => null,
    };
    return ServerProfile(
      remoteAddress: remote,
      address: parsed.address,
      pinnedCertificateSha256: pin is String ? pin : null,
      insecureConnectionAcknowledged:
          json['insecureConnectionAcknowledged'] == true,
    );
  }

  final ServerAddress address;

  /// Fingerprint of a self-signed certificate the user explicitly trusted.
  final String? pinnedCertificateSha256;

  /// The user confirmed they understand the risk of plain HTTP to a
  /// non-local address (e.g. because traffic runs through a VPN).
  final bool insecureConnectionAcknowledged;

  /// Optional second address of the same Home Assistant for use away
  /// from home (Nabu Casa, a domain with HTTPS, Tailscale). The token and
  /// the profile id stay those of [address].
  final ServerAddress? remoteAddress;

  String get id => address.id;

  ServerProfile withRemoteAddress(ServerAddress? remote) => ServerProfile(
    address: address,
    pinnedCertificateSha256: pinnedCertificateSha256,
    insecureConnectionAcknowledged: insecureConnectionAcknowledged,
    remoteAddress: remote,
  );

  /// This profile reached through [other]: a pinned certificate belongs
  /// to the home address only, the remote one needs a valid certificate.
  ServerProfile via(ServerAddress other) => other == address
      ? this
      : ServerProfile(
          address: other,
          insecureConnectionAcknowledged: insecureConnectionAcknowledged,
        );

  TlsTrust get tlsTrust => TlsTrust(pinnedSha256: pinnedCertificateSha256);

  Map<String, Object?> toJson() => {
    'url': address.baseUri.toString(),
    'pinnedCertificateSha256': pinnedCertificateSha256,
    'insecureConnectionAcknowledged': insecureConnectionAcknowledged,
    if (remoteAddress != null) 'remoteUrl': remoteAddress!.baseUri.toString(),
  };

  @override
  bool operator ==(Object other) =>
      other is ServerProfile &&
      other.address == address &&
      other.pinnedCertificateSha256 == pinnedCertificateSha256 &&
      other.insecureConnectionAcknowledged == insecureConnectionAcknowledged &&
      other.remoteAddress == remoteAddress;

  @override
  int get hashCode => Object.hash(
    address,
    pinnedCertificateSha256,
    insecureConnectionAcknowledged,
    remoteAddress,
  );
}
