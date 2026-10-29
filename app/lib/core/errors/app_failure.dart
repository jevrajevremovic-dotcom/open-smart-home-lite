import 'package:flutter/foundation.dart';

/// Categories of failures the app distinguishes. UI messages are chosen
/// per category; technical details stay in [AppFailure.debugMessage].
enum FailureKind {
  network,
  timeout,
  authentication,
  authorization,
  validation,
  parsing,
  server,
  certificate,
  unavailableEntity,
  unsupportedFeature,
  webSocket,
  storage,

  /// A critical command (unlock, disarm, open garage) was not confirmed.
  confirmationRequired,
  unknown,
}

/// Details of a TLS certificate the platform refused to trust.
///
/// Shown to the user so they can decide whether to pin it explicitly.
@immutable
class CertificateInfo {
  const CertificateInfo({
    required this.sha256Fingerprint,
    required this.subject,
    required this.issuer,
    required this.validFrom,
    required this.validUntil,
  });

  /// Upper-case hex SHA-256 of the DER-encoded certificate, colon separated.
  final String sha256Fingerprint;
  final String subject;
  final String issuer;
  final DateTime validFrom;
  final DateTime validUntil;

  bool isExpiredAt(DateTime now) => now.isAfter(validUntil);
}

/// The single error type that crosses layer boundaries.
///
/// [debugMessage] must never contain tokens, passwords or authorization
/// headers. It is logged through the redacting logger anyway, as a second
/// line of defence.
@immutable
class AppFailure implements Exception {
  const AppFailure(
    this.kind, {
    this.debugMessage,
    this.statusCode,
    this.certificate,
    this.code,
  });

  final FailureKind kind;
  final String? debugMessage;
  final int? statusCode;

  /// Error code from Home Assistant's WebSocket reply (e.g.
  /// `wake-engine-missing`), when there was one.
  final String? code;

  /// Present when [kind] is [FailureKind.certificate] and the certificate
  /// could be captured during the TLS handshake.
  final CertificateInfo? certificate;

  /// Whether retrying the same operation later can reasonably succeed.
  bool get isTransient => switch (kind) {
    FailureKind.network ||
    FailureKind.timeout ||
    FailureKind.server ||
    FailureKind.webSocket => true,
    _ => false,
  };

  @override
  String toString() {
    final status = statusCode == null ? '' : ' [$statusCode]';
    final message = debugMessage == null ? '' : ': $debugMessage';
    return 'AppFailure(${kind.name}$status)$message';
  }
}
