import 'package:flutter/foundation.dart';

/// TLS trust decision for one server.
///
/// By default only certificates trusted by the operating system are
/// accepted. A self-signed certificate is accepted **only** if the user
/// explicitly pinned its exact SHA-256 fingerprint after seeing it. There is
/// deliberately no "accept all certificates" option.
///
/// On the web the browser owns TLS; pinning is not possible there and
/// [pinnedSha256] is ignored (see `supportsCertificatePinning`).
@immutable
class TlsTrust {
  const TlsTrust({this.pinnedSha256});

  static const TlsTrust system = TlsTrust();

  final String? pinnedSha256;
}

/// Colon-separated upper-case hex, e.g. `0A:FF:…`.
String formatFingerprint(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(':');
