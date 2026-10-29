import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/backoff.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/connection_status.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/ha_socket.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/ha_websocket_manager.dart';

final _uri = Uri.parse('ws://192.168.1.10:8123/api/websocket');

ExponentialBackoff fastBackoff() => ExponentialBackoff(
  initial: const Duration(milliseconds: 10),
  max: const Duration(milliseconds: 40),
  random: Random(1),
);

Future<void> waitForState(HaWebSocketManager m, HaConnectionState state) async {
  if (m.status.state == state) return;
  await m.statusStream
      .firstWhere((s) => s.state == state)
      .timeout(const Duration(seconds: 3));
}

/// Socket that authenticates and then ignores everything (simulates a
/// half-open TCP connection where pings never get answered).
class SilentSocket implements HaSocket {
  final _out = StreamController<String>();
  final sent = <Map<String, Object?>>[];

  SilentSocket() {
    scheduleMicrotask(() => _out.add(jsonEncode({'type': 'auth_required'})));
  }

  @override
  Stream<String> get messages => _out.stream;

  @override
  void send(String message) {
    final m = jsonDecode(message) as Map<String, Object?>;
    sent.add(m);
    if (m['type'] == 'auth') {
      _out.add(jsonEncode({'type': 'auth_ok', 'ha_version': 'x'}));
    }
  }

  @override
  void sendBytes(Uint8List data) {}

  @override
  Future<void> close() => _out.close();
}

void main() {
  late MockHomeAssistantServer server;
  late List<HaWebSocketManager> managers;

  setUp(() {
    server = MockHomeAssistantServer();
    managers = [];
  });

  tearDown(() async {
    for (final m in managers) {
      await m.dispose();
    }
  });

  HaWebSocketManager create({
    String? token = 'good',
    HaSocketConnector? connector,
    Duration? ping,
  }) {
    final m = HaWebSocketManager(
      uri: _uri,
      readToken: () async => token,
      connector: connector ?? server.connect,
      backoff: fastBackoff(),
      pingInterval: ping ?? const Duration(seconds: 30),
      commandTimeout: const Duration(milliseconds: 300),
    );
    managers.add(m);
    return m;
  }

  test('connects and authenticates', () async {
    final m = create();
    final states = <HaConnectionState>[];
    m.statusStream.listen((s) => states.add(s.state));
    m.connect();
    await waitForState(m, HaConnectionState.connected);
    expect(
      states,
      containsAllInOrder([
        HaConnectionState.connecting,
        HaConnectionState.authenticating,
        HaConnectionState.connected,
      ]),
    );
    expect(m.status.haVersion, MockHomeAssistantServer.version);
  });

  test('invalid token → authenticationFailed and no retries', () async {
    var attempts = 0;
    final m = create(
      token: mockInvalidToken,
      connector: (uri) {
        attempts++;
        return server.connect(uri);
      },
    );
    m.connect();
    await waitForState(m, HaConnectionState.authenticationFailed);
    expect(m.status.failure?.kind, FailureKind.authentication);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(attempts, 1);
    expect(m.status.state, HaConnectionState.authenticationFailed);
  });

  test('server unavailable → backoff retries, then recovers', () async {
    server.online = false;
    final m = create();
    m.connect();
    await waitForState(m, HaConnectionState.serverUnavailable);
    expect(m.status.attempt, greaterThanOrEqualTo(3));
    expect(m.status.failure?.kind, FailureKind.network);

    server.online = true;
    await waitForState(m, HaConnectionState.connected);
    expect(m.status.attempt, 0, reason: 'backoff resets after success');
  });

  test('reconnects after server restart and restores subscriptions', () async {
    final m = create();
    final events = <String>[];
    final sub = m.stateChanges().listen(
      (e) => events.add('${e.entityId}=${e.newState?.state}'),
    );
    addTearDown(sub.cancel);

    m.connect();
    await waitForState(m, HaConnectionState.connected);
    await pumpEventQueue();
    server.setStateForTest('switch.coffee_machine', 'on');
    await pumpEventQueue();
    expect(events, ['switch.coffee_machine=on']);

    await server.dropAllConnections();
    await waitForState(m, HaConnectionState.reconnecting);
    await waitForState(m, HaConnectionState.connected);
    await pumpEventQueue(times: 50);

    server.setStateForTest('switch.coffee_machine', 'off');
    await pumpEventQueue();
    expect(events, ['switch.coffee_machine=on', 'switch.coffee_machine=off']);
  });

  test('multiple listeners share one server subscription', () async {
    final m = create();
    m.connect();
    await waitForState(m, HaConnectionState.connected);

    final a = m.events('state_changed').listen((_) {});
    final b = m.events('state_changed').listen((_) {});
    await pumpEventQueue(times: 50);
    expect(m.activeServerSubscriptions, 1);

    await a.cancel();
    await pumpEventQueue();
    expect(m.activeServerSubscriptions, 1);
    await b.cancel();
    await pumpEventQueue(times: 50);
    expect(m.activeServerSubscriptions, 0);
  });

  test('sendCommand returns result and maps HA errors', () async {
    final m = create();
    m.connect();
    await waitForState(m, HaConnectionState.connected);

    final states = await m.sendCommand({'type': 'get_states'});
    expect(states, isA<List<Object?>>());

    await expectLater(
      m.sendCommand({'type': 'no_such_command'}),
      throwsA(
        isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.server),
      ),
    );
  });

  test(
    'transient token error (refresh offline) retries instead of failing',
    () async {
      var calls = 0;
      final m = HaWebSocketManager(
        uri: _uri,
        readToken: () async {
          if (++calls == 1) {
            throw const AppFailure(
              FailureKind.network,
              debugMessage: 'refresh offline',
            );
          }
          return 'good';
        },
        connector: server.connect,
        backoff: fastBackoff(),
      );
      managers.add(m);
      m.connect();
      await waitForState(m, HaConnectionState.connected);
      expect(calls, 2);
    },
  );

  test('rejected credential during refresh is terminal', () async {
    final m = HaWebSocketManager(
      uri: _uri,
      readToken: () async => throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'invalid_grant',
      ),
      connector: server.connect,
      backoff: fastBackoff(),
    );
    managers.add(m);
    m.connect();
    await waitForState(m, HaConnectionState.authenticationFailed);
  });

  test('sendCommand while disconnected fails fast', () async {
    final m = create();
    await expectLater(
      m.sendCommand({'type': 'ping'}),
      throwsA(isA<AppFailure>()),
    );
  });

  test('unanswered ping triggers reconnect', () async {
    var connects = 0;
    final m = create(
      ping: const Duration(milliseconds: 50),
      connector: (_) async {
        connects++;
        return SilentSocket();
      },
    );
    m.connect();
    await waitForState(m, HaConnectionState.connected);
    await waitForState(m, HaConnectionState.reconnecting);
    expect(m.status.failure?.kind, FailureKind.timeout);
    await waitForState(m, HaConnectionState.connected);
    expect(connects, greaterThanOrEqualTo(2));
  });

  test('disconnect stops reconnecting', () async {
    server.online = false;
    var attempts = 0;
    final m = create(
      connector: (uri) {
        attempts++;
        return server.connect(uri);
      },
    );
    m.connect();
    await waitForState(m, HaConnectionState.reconnecting);
    await m.disconnect();
    final after = attempts;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(attempts, after);
    expect(m.status.state, HaConnectionState.disconnected);
  });

  group('ExponentialBackoff', () {
    test('grows, caps and resets', () {
      final b = ExponentialBackoff(
        initial: const Duration(seconds: 1),
        max: const Duration(seconds: 8),
        random: Random(0),
      );
      final delays = List.generate(6, (_) => b.next());
      for (final (i, d) in delays.indexed) {
        final ceiling = Duration(seconds: min(1 << i, 8));
        expect(d, lessThanOrEqualTo(ceiling));
        expect(d, greaterThanOrEqualTo(ceiling ~/ 2));
      }
      b.reset();
      expect(b.attempt, 0);
      expect(b.next(), lessThanOrEqualTo(const Duration(seconds: 1)));
    });
  });
}
