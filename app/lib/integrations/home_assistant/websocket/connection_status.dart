import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';

enum HaConnectionState {
  disconnected,
  connecting,
  authenticating,
  connected,
  reconnecting,
  authenticationFailed,
  serverUnavailable,
  error,
}

@immutable
class HaConnectionStatus {
  const HaConnectionStatus({
    required this.state,
    this.attempt = 0,
    this.nextRetryIn,
    this.failure,
    this.lastConnectedAt,
    this.haVersion,
  });

  static const HaConnectionStatus initial = HaConnectionStatus(
    state: HaConnectionState.disconnected,
  );

  final HaConnectionState state;

  /// Consecutive failed connection attempts since the last success.
  final int attempt;
  final Duration? nextRetryIn;
  final AppFailure? failure;
  final DateTime? lastConnectedAt;
  final String? haVersion;

  bool get isConnected => state == HaConnectionState.connected;

  /// The app will not retry on its own; user action is required.
  bool get isTerminal => state == HaConnectionState.authenticationFailed;

  HaConnectionStatus copyWith({
    HaConnectionState? state,
    int? attempt,
    Duration? nextRetryIn,
    AppFailure? failure,
    DateTime? lastConnectedAt,
    String? haVersion,
    bool clearRetry = false,
    bool clearFailure = false,
  }) => HaConnectionStatus(
    state: state ?? this.state,
    attempt: attempt ?? this.attempt,
    nextRetryIn: clearRetry ? null : (nextRetryIn ?? this.nextRetryIn),
    failure: clearFailure ? null : (failure ?? this.failure),
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    haVersion: haVersion ?? this.haVersion,
  );

  @override
  String toString() => 'HaConnectionStatus(${state.name}, attempt: $attempt)';
}
