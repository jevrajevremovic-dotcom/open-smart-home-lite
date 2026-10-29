import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Minimal text-frame transport. Abstracted so the manager can be tested and
/// driven by the in-memory mock server.
abstract interface class HaSocket {
  /// Incoming text frames. Completes when the connection closes.
  Stream<String> get messages;
  void send(String message);

  /// A binary frame (Assist audio).
  void sendBytes(Uint8List data);

  Future<void> close();
}

/// Opens a connected socket or throws.
typedef HaSocketConnector = Future<HaSocket> Function(Uri uri);

/// [HaSocket] over any `web_socket_channel` implementation (io or browser).
class ChannelSocket implements HaSocket {
  ChannelSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<String> get messages =>
      _channel.stream.where((m) => m is String).cast<String>();

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  void sendBytes(Uint8List data) => _channel.sink.add(data);

  @override
  Future<void> close() async => _channel.sink.close();
}
