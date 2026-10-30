import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_http.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_transport.dart';

/// Devices answering UDP on a pretend network: by `host:port`, the
/// answers to what was sent (`255.255.255.255:port` and multicast are
/// answered by every device listed for them). Records every datagram.
class FakeLanUdp implements LanUdp {
  FakeLanUdp(this.devices);

  /// `host:port` → the answers (each from a host) to a datagram.
  final Map<String, List<UdpPacket> Function(Uint8List data)> devices;
  final List<(String host, int port, Uint8List data)> sent = [];
  final _broadcasts = <int, StreamController<UdpPacket>>{};

  @override
  Future<List<UdpPacket>> ask(
    String host,
    int port,
    List<int> data, {
    Duration wait = const Duration(seconds: 2),
    bool first = true,
    int listenPort = 0,
  }) async {
    final bytes = Uint8List.fromList(data);
    sent.add((host, port, bytes));
    final answer = devices['$host:$port'];
    if (answer == null) return const [];
    final all = answer(bytes);
    return first ? all.take(1).toList() : all;
  }

  /// A device broadcasts [data] to [port].
  void broadcast(int port, String host, List<int> data) =>
      _broadcasts[port]?.add(UdpPacket(host, Uint8List.fromList(data)));

  @override
  Stream<UdpPacket> listen(int port, {required Duration duration}) =>
      (_broadcasts[port] ??= StreamController<UdpPacket>.broadcast()).stream;

  /// Sent to `host:port`, as text.
  List<String> textsTo(String hostPort) => [
    for (final (h, p, d) in sent)
      if ('$h:$p' == hostPort) utf8.decode(d, allowMalformed: true),
  ];
}

/// One UDP answer from [host].
List<UdpPacket> udpAnswer(String host, Object json) => [
  UdpPacket(host, Uint8List.fromList(utf8.encode(jsonEncode(json)))),
];

/// HTTP devices: by `METHOD host:port/path` (`GET 10.0.0.5:8060/query/x`),
/// a function of the request giving the answer. Records requests.
class FakeLanRequests implements LanRequests {
  FakeLanRequests(this.routes);

  final Map<String, FutureOr<LanResponse> Function(FakeRequest request)> routes;
  final List<FakeRequest> requests = [];

  @override
  Future<LanResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
    bool insecure = false,
    LanAuth? auth,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final request = FakeRequest(method, uri, headers, body ?? const [], auth);
    requests.add(request);
    final hostPort = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    final route = routes['$method $hostPort${uri.path}'];
    if (route == null) {
      throw AppFailure(
        FailureKind.network,
        debugMessage: '$hostPort no answer',
      );
    }
    return route(request);
  }

  List<String> pathsTo(String method) => [
    for (final r in requests)
      if (r.method == method) r.uri.path,
  ];
}

class FakeRequest {
  FakeRequest(this.method, this.uri, this.headers, this.body, this.auth);

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int> body;
  final LanAuth? auth;

  String get text => utf8.decode(body, allowMalformed: true);
  Object? get json => body.isEmpty ? null : jsonDecode(text);
}

LanResponse jsonResponse(Object? json, {int status = 200}) =>
    LanResponse(status, Uint8List.fromList(utf8.encode(jsonEncode(json))));

LanResponse textResponse(String text, {int status = 200}) =>
    LanResponse(status, Uint8List.fromList(utf8.encode(text)));

/// A TCP device: a function from what it gets to what it sends back.
class FakeLanTcp implements LanTcp {
  FakeLanTcp(this.devices);

  /// `host:port` → a new conversation (one per connection).
  final Map<String, FakeConversation Function()> devices;
  int connections = 0;

  @override
  Future<LanLink> connect(String host, int port) async {
    final make = devices['$host:$port'];
    if (make == null) {
      throw AppFailure(FailureKind.network, debugMessage: '$host:$port');
    }
    connections++;
    return _FakeLink(make());
  }
}

/// Answers each chunk the app sends with zero or more chunks.
typedef FakeConversation = List<List<int>> Function(Uint8List received);

class _FakeLink implements LanLink {
  _FakeLink(this._answer);

  final FakeConversation _answer;
  final _out = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get data => _out.stream;

  @override
  void add(List<int> bytes) {
    final answers = _answer(Uint8List.fromList(bytes));
    scheduleMicrotask(() {
      for (final a in answers) {
        if (!_out.isClosed) _out.add(Uint8List.fromList(a));
      }
    });
  }

  @override
  // Not awaited: a broadcast stream's close waits for its listeners.
  Future<void> close() async => unawaited(_out.close());
}

/// WebSocket devices (TVs): by URI without query, a conversation.
class FakeLanSockets implements LanSockets {
  FakeLanSockets(this.devices);

  /// `scheme://host:port/path` → each message's answers.
  final Map<String, List<String> Function(String message, Uri uri)> devices;
  final List<Uri> opened = [];
  final List<String> sent = [];

  @override
  Future<LanWebSocket> connect(Uri uri, {bool insecure = false}) async {
    final key = '${uri.scheme}://${uri.host}:${uri.port}${uri.path}';
    final answer = devices[key];
    if (answer == null) {
      throw AppFailure(FailureKind.network, debugMessage: key);
    }
    opened.add(uri);
    return _FakeSocket(uri, answer, sent);
  }
}

class _FakeSocket implements LanWebSocket {
  _FakeSocket(this._uri, this._answer, this._sent) {
    // A greeting, as some TVs send on connect (once listened to).
    Timer.run(() {
      for (final m in _answer('', _uri)) {
        if (!_out.isClosed) _out.add(m);
      }
    });
  }

  final Uri _uri;
  final List<String> Function(String, Uri) _answer;
  final List<String> _sent;
  final _out = StreamController<String>.broadcast();

  @override
  Stream<String> get messages => _out.stream;

  @override
  void send(String text) {
    _sent.add(text);
    final answers = _answer(text, _uri);
    scheduleMicrotask(() {
      for (final a in answers) {
        if (!_out.isClosed) _out.add(a);
      }
    });
  }

  @override
  // Not awaited: a broadcast stream's close waits for its listeners.
  Future<void> close() async => unawaited(_out.close());
}
