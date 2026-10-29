import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../models/ha_models.dart';
import 'backoff.dart';
import 'connection_status.dart';
import 'ha_socket.dart';
import '../transport/transport.dart';
import '../transport/transport_error.dart';

/// A Home Assistant bus event delivered over a subscription.
@immutable
class HaEvent {
  const HaEvent({required this.eventType, required this.data, this.timeFired});

  final String eventType;
  final Object? data;
  final DateTime? timeFired;
}

/// Single owner of the Home Assistant WebSocket connection.
///
/// Implements the documented protocol
/// (https://developers.home-assistant.io/docs/api/websocket/):
/// `auth_required` → `auth` → `auth_ok` / `auth_invalid`, numbered commands
/// with `result` replies, `subscribe_events` / `unsubscribe_events`, and
/// `ping` / `pong` heartbeats.
///
/// Responsibilities:
/// * exposes connection status as a stream;
/// * one server-side subscription per event type, shared by all listeners;
/// * re-subscribes everything after a reconnect;
/// * capped exponential backoff, reset after a successful auth;
/// * stops retrying on `auth_invalid` (a bad token will not fix itself);
/// * detects dead connections with ping timeouts.
class HaWebSocketManager {
  HaWebSocketManager({
    required this.uri,
    required this._readToken,
    required this._connector,
    ExponentialBackoff? backoff,
    this.pingInterval = AppConfig.webSocketPingInterval,
    this.commandTimeout = AppConfig.webSocketCommandTimeout,
    this.unavailableAfterAttempts = 3,
  }) : _backoff = backoff ?? ExponentialBackoff();

  final Uri uri;
  final Duration pingInterval;
  final Duration commandTimeout;

  /// After this many consecutive failures the status becomes
  /// [HaConnectionState.serverUnavailable] (retries continue in background).
  final int unavailableAfterAttempts;

  final Future<String?> Function() _readToken;
  final HaSocketConnector _connector;
  final ExponentialBackoff _backoff;
  static final _log = AppLogger('HaWebSocket');

  final StreamController<HaConnectionStatus> _statusController =
      StreamController<HaConnectionStatus>.broadcast();
  HaConnectionStatus _status = HaConnectionStatus.initial;

  HaSocket? _socket;
  StreamSubscription<String>? _socketSubscription;
  int _generation = 0;
  int _nextId = 1;
  bool _wantConnected = false;
  bool _disposed = false;
  bool _hasConnectedBefore = false;
  Timer? _retryTimer;
  Timer? _pingTimer;
  Timer? _authTimer;

  final Map<int, Completer<Object?>> _pending = {};
  final Map<String, _EventSubscription> _subscriptions = {};
  final Map<int, _EventSubscription> _subscriptionsByServerId = {};

  /// Streams of commands that answer with a series of events (e.g.
  /// `zwave_js/add_node`), by message id.
  final Map<int, StreamController<Map<String, Object?>>> _commandStreams = {};

  HaConnectionStatus get status => _status;
  Stream<HaConnectionStatus> get statusStream => _statusController.stream;

  /// Number of distinct server-side event subscriptions currently held.
  @visibleForTesting
  int get activeServerSubscriptions => _subscriptionsByServerId.length;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts connecting (idempotent).
  void connect() {
    _ensureNotDisposed();
    _wantConnected = true;
    if (_socket != null || _retryTimer != null) return;
    if (_status.state == HaConnectionState.connecting ||
        _status.state == HaConnectionState.authenticating) {
      return;
    }
    unawaited(_open());
  }

  /// Skips the remaining backoff delay, e.g. when the app returns to the
  /// foreground or the network changes. Also re-enables retries after an
  /// authentication failure (for example once a new token was saved).
  void retryNow() {
    _ensureNotDisposed();
    _wantConnected = true;
    if (_status.isConnected) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _closeSocket();
    unawaited(_open());
  }

  /// Closes the connection and stops reconnecting. Registered subscriptions
  /// are kept and restored by the next [connect].
  Future<void> disconnect() async {
    _wantConnected = false;
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _closeSocket();
    _setStatus(
      _status.copyWith(state: HaConnectionState.disconnected, clearRetry: true),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    for (final sub in _subscriptions.values.toList()) {
      await sub.controller.close();
    }
    _subscriptions.clear();
    await _statusController.close();
  }

  // ---------------------------------------------------------------------------
  // Commands & subscriptions
  // ---------------------------------------------------------------------------

  /// Sends a command (without `id`) and returns its `result` payload.
  Future<Object?> sendCommand(Map<String, Object?> command) {
    if (!_status.isConnected) {
      return Future.error(
        const AppFailure(FailureKind.webSocket, debugMessage: 'not connected'),
      );
    }
    return _send(command);
  }

  /// Bus events of [eventType] (`null` = all events). Every listener shares
  /// one server subscription; it is released when the last listener cancels.
  Stream<HaEvent> events([String? eventType]) {
    _ensureNotDisposed();
    final key = eventType ?? '*';
    final existing = _subscriptions[key];
    if (existing != null) return existing.controller.stream;

    late final _EventSubscription sub;
    final controller = StreamController<HaEvent>.broadcast(
      onListen: () {
        _subscriptions[key] = sub;
        if (_status.isConnected) unawaited(_subscribe(sub));
      },
      onCancel: () {
        _subscriptions.remove(key);
        unawaited(_unsubscribe(sub));
        unawaited(sub.controller.close());
      },
    );
    sub = _EventSubscription(eventType, controller);
    _subscriptions[key] = sub;
    return controller.stream;
  }

  /// Sends a command that answers with a stream of events and yields each
  /// event payload (a list payload as `{"changes": [...]}`). Cancelling the
  /// stream unsubscribes on the server (which for most such commands also
  /// stops what they started). The stream ends
  /// with an error if the command fails or the connection drops.
  Stream<Map<String, Object?>> subscribeCommand(Map<String, Object?> command) {
    _ensureNotDisposed();
    late final StreamController<Map<String, Object?>> controller;
    int? id;
    controller = StreamController<Map<String, Object?>>(
      onListen: () async {
        if (!_status.isConnected) {
          controller.addError(
            const AppFailure(
              FailureKind.webSocket,
              debugMessage: 'not connected',
            ),
          );
          await controller.close();
          return;
        }
        id = _nextId; // _send assigns this id
        _commandStreams[id!] = controller;
        try {
          await _send(command);
        } on AppFailure catch (e) {
          _commandStreams.remove(id);
          if (!controller.isClosed) {
            controller.addError(e);
            await controller.close();
          }
        }
      },
      onCancel: () async {
        final subId = id;
        if (subId == null || _commandStreams.remove(subId) == null) return;
        if (!_status.isConnected) return;
        try {
          await _send({'type': 'unsubscribe_events', 'subscription': subId});
        } on AppFailure catch (e) {
          _log.debug('unsubscribe($subId) failed: $e');
        }
      },
    );
    return controller.stream;
  }

  /// Sends [data] as a binary frame to the server-side binary handler
  /// [handlerId] (first byte), as Assist audio streaming expects. An empty
  /// [data] ends that audio stream. Dropped while disconnected.
  void sendBinary(int handlerId, List<int> data) {
    final socket = _socket;
    if (socket == null || !_status.isConnected) return;
    socket.sendBytes(
      Uint8List(data.length + 1)
        ..[0] = handlerId
        ..setRange(1, data.length + 1, data),
    );
  }

  /// Typed `state_changed` events. Malformed events are logged and skipped.
  Stream<HaStateChangedEvent> stateChanges() =>
      events('state_changed').expand((event) {
        try {
          return [HaStateChangedEvent.fromEventData(event.data)];
        } on AppFailure catch (e) {
          _log.warning('Ignoring malformed state_changed event', e);
          return const <HaStateChangedEvent>[];
        }
      });

  Future<void> _subscribe(_EventSubscription sub) async {
    if (sub.serverId != null) return; // duplicate guard
    final id = _nextId; // _send assigns this id
    sub.serverId = id;
    _subscriptionsByServerId[id] = sub;
    try {
      await _send({
        'type': 'subscribe_events',
        if (sub.eventType != null) 'event_type': sub.eventType,
      });
    } on AppFailure catch (e) {
      _subscriptionsByServerId.remove(id);
      sub.serverId = null;
      _log.warning('subscribe_events(${sub.eventType}) failed', e);
    }
  }

  Future<void> _unsubscribe(_EventSubscription sub) async {
    final id = sub.serverId;
    sub.serverId = null;
    if (id == null) return;
    _subscriptionsByServerId.remove(id);
    if (!_status.isConnected) return;
    try {
      await _send({'type': 'unsubscribe_events', 'subscription': id});
    } on AppFailure catch (e) {
      _log.debug('unsubscribe_events($id) failed: $e');
    }
  }

  Future<Object?> _send(Map<String, Object?> command) async {
    final socket = _socket;
    if (socket == null) {
      throw const AppFailure(FailureKind.webSocket, debugMessage: 'no socket');
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    socket.send(jsonEncode({'id': id, ...command}));
    try {
      return await completer.future.timeout(commandTimeout);
    } on TimeoutException {
      throw AppFailure(
        FailureKind.timeout,
        debugMessage: '${command['type']} (#$id) timed out',
      );
    } finally {
      _pending.remove(id);
    }
  }

  // ---------------------------------------------------------------------------
  // Connection handling
  // ---------------------------------------------------------------------------

  Future<void> _open() async {
    if (_disposed || !_wantConnected) return;
    final generation = ++_generation;
    _retryTimer = null;
    _setStatus(
      _status.copyWith(
        state: _hasConnectedBefore || _backoff.attempt > 0
            ? HaConnectionState.reconnecting
            : HaConnectionState.connecting,
        clearRetry: true,
      ),
    );

    final HaSocket socket;
    try {
      socket = await _connector(uri);
    } on Object catch (e) {
      if (generation != _generation) return;
      _log.info('WebSocket connect failed: ${e.runtimeType}');
      _scheduleReconnect(_failureFromConnectError(e));
      return;
    }
    if (generation != _generation || !_wantConnected) {
      await socket.close();
      return;
    }

    _socket = socket;
    _nextId = 1;
    _setStatus(_status.copyWith(state: HaConnectionState.authenticating));
    _authTimer = Timer(commandTimeout, () {
      if (generation != _generation) return;
      _handleDrop(
        generation,
        const AppFailure(
          FailureKind.timeout,
          debugMessage: 'auth handshake timed out',
        ),
      );
    });
    _socketSubscription = socket.messages.listen(
      (message) => _onMessage(generation, message),
      onError: (Object e) => _handleDrop(
        generation,
        AppFailure(
          FailureKind.webSocket,
          debugMessage: 'socket error: ${e.runtimeType}',
        ),
      ),
      onDone: () => _handleDrop(
        generation,
        const AppFailure(FailureKind.webSocket, debugMessage: 'socket closed'),
      ),
      cancelOnError: true,
    );
  }

  void _onMessage(int generation, String raw) {
    if (generation != _generation) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      _log.warning('Ignoring non-JSON WebSocket frame');
      return;
    }
    // HA may batch messages into a JSON array when coalescing is enabled.
    final messages = decoded is List ? decoded : [decoded];
    for (final message in messages) {
      if (message is Map<String, Object?>) _handleMessage(generation, message);
    }
  }

  void _handleMessage(int generation, Map<String, Object?> message) {
    switch (message['type']) {
      case 'auth_required':
        unawaited(_authenticate(generation));
      case 'auth_ok':
        _onAuthenticated(message['ha_version'] as String?);
      case 'auth_invalid':
        _onAuthInvalid();
      case 'result':
        _onResult(message);
      case 'pong':
        final id = message['id'];
        if (id is int) _pending[id]?.complete(null);
      case 'event':
        final id = message['id'];
        // Owned and closed by subscribeCommand / _closeSocket.
        // ignore: close_sinks
        final stream = id is int ? _commandStreams[id] : null;
        if (stream != null) {
          final payload = message['event'];
          if (stream.isClosed) return;
          if (payload is Map<String, Object?>) {
            stream.add(payload);
          } else if (payload is List) {
            // Storage collections (`image/subscribe`, …) send a list of
            // changes; it arrives as {"changes": [...]}.
            stream.add({'changes': payload});
          }
          return;
        }
        final sub = id is int ? _subscriptionsByServerId[id] : null;
        final event = message['event'];
        if (sub == null || event is! Map<String, Object?>) return;
        final eventType = event['event_type'];
        if (sub.controller.isClosed) return;
        sub.controller.add(
          HaEvent(
            eventType: eventType is String
                ? eventType
                : (sub.eventType ?? 'unknown'),
            data: event['data'],
            timeFired: event['time_fired'] is String
                ? DateTime.tryParse(event['time_fired']! as String)
                : null,
          ),
        );
      default:
        _log.debug('Unhandled message type ${message['type']}');
    }
  }

  Future<void> _authenticate(int generation) async {
    final String? token;
    try {
      token = await _readToken();
    } on AppFailure catch (e) {
      // A token refresh that failed for network reasons is worth retrying;
      // a rejected credential is not.
      if (e.isTransient) {
        _handleDrop(generation, e);
      } else {
        _failTerminal(e);
      }
      return;
    }
    if (generation != _generation) return;
    if (token == null || token.isEmpty) {
      _failTerminal(
        const AppFailure(
          FailureKind.authentication,
          debugMessage: 'no token stored',
        ),
      );
      return;
    }
    _socket?.send(jsonEncode({'type': 'auth', 'access_token': token}));
  }

  void _onAuthenticated(String? haVersion) {
    _authTimer?.cancel();
    _backoff.reset();
    _hasConnectedBefore = true;
    _setStatus(
      HaConnectionStatus(
        state: HaConnectionState.connected,
        lastConnectedAt: DateTime.now(),
        haVersion: haVersion,
      ),
    );
    _log.info('Connected to Home Assistant $haVersion');

    // Server-side subscriptions do not survive a new connection.
    _subscriptionsByServerId.clear();
    for (final stream in _commandStreams.values) {
      if (!stream.isClosed) {
        stream.addError(
          const AppFailure(
            FailureKind.webSocket,
            debugMessage: 'connection closed',
          ),
        );
        unawaited(stream.close());
      }
    }
    _commandStreams.clear();
    for (final sub in _subscriptions.values) {
      sub.serverId = null;
      if (sub.controller.hasListener) unawaited(_subscribe(sub));
    }
    _startHeartbeat();
  }

  void _onAuthInvalid() {
    _failTerminal(
      const AppFailure(
        FailureKind.authentication,
        debugMessage: 'auth_invalid',
      ),
    );
  }

  void _failTerminal(AppFailure failure) {
    _log.warning('WebSocket authentication failed', failure);
    _wantConnected = false;
    _generation++;
    _closeSocket();
    _setStatus(
      _status.copyWith(
        state: HaConnectionState.authenticationFailed,
        failure: failure,
        clearRetry: true,
      ),
    );
  }

  void _onResult(Map<String, Object?> message) {
    final id = message['id'];
    if (id is! int) return;
    final completer = _pending[id];
    if (completer == null || completer.isCompleted) return;
    if (message['success'] == true) {
      completer.complete(message['result']);
      return;
    }
    final error = message['error'];
    final code = error is Map ? error['code'] : null;
    completer.completeError(
      AppFailure(
        switch (code) {
          'unauthorized' => FailureKind.authorization,
          'invalid_format' => FailureKind.validation,
          'not_found' => FailureKind.unavailableEntity,
          'not_supported' => FailureKind.unsupportedFeature,
          _ => FailureKind.server,
        },
        debugMessage: 'command #$id failed: $code',
        code: code is String ? code : null,
      ),
    );
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    final generation = _generation;
    _pingTimer = Timer.periodic(pingInterval, (_) async {
      if (generation != _generation || !_status.isConnected) return;
      try {
        await _send({'type': 'ping'});
      } on AppFailure catch (e) {
        _handleDrop(generation, e);
      }
    });
  }

  void _handleDrop(int generation, AppFailure failure) {
    if (generation != _generation) return;
    _generation++;
    _closeSocket();
    if (_wantConnected && !_disposed) {
      _log.info('Connection lost: ${failure.debugMessage}');
      _scheduleReconnect(failure);
    } else {
      _setStatus(_status.copyWith(state: HaConnectionState.disconnected));
    }
  }

  void _scheduleReconnect(AppFailure failure) {
    if (_disposed || !_wantConnected) return;
    final delay = _backoff.next();
    final attempt = _backoff.attempt;
    _setStatus(
      _status.copyWith(
        state: attempt >= unavailableAfterAttempts
            ? HaConnectionState.serverUnavailable
            : HaConnectionState.reconnecting,
        attempt: attempt,
        nextRetryIn: delay,
        failure: failure,
      ),
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_open()));
  }

  void _closeSocket() {
    _authTimer?.cancel();
    _pingTimer?.cancel();
    _authTimer = null;
    _pingTimer = null;
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close());
    _subscriptionsByServerId.clear();
    for (final sub in _subscriptions.values) {
      sub.serverId = null;
    }
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const AppFailure(
            FailureKind.webSocket,
            debugMessage: 'connection closed',
          ),
        );
      }
    }
    _pending.clear();
  }

  AppFailure _failureFromConnectError(Object error) {
    if (error is AppFailure) return error;
    if (classifyTransportError(error) == TransportErrorKind.tls) {
      return const AppFailure(
        FailureKind.certificate,
        debugMessage: 'TLS handshake failed',
      );
    }
    if (error is TimeoutException) {
      return const AppFailure(
        FailureKind.timeout,
        debugMessage: 'connect timeout',
      );
    }
    return AppFailure(
      FailureKind.network,
      debugMessage: 'connect failed: ${error.runtimeType}',
    );
  }

  void _setStatus(HaConnectionStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('HaWebSocketManager was disposed');
  }
}

class _EventSubscription {
  _EventSubscription(this.eventType, this.controller);

  final String? eventType;
  final StreamController<HaEvent> controller;

  /// Id of the `subscribe_events` command on the current connection.
  int? serverId;
}
