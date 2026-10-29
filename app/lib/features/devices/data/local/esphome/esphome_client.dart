import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_failure.dart';
import 'noise.dart';
import 'proto.dart';

/// Message types of the ESPHome native API (`api.proto`) used here.
abstract final class EsphomeMessage {
  static const helloRequest = 1;
  static const helloResponse = 2;
  static const connectRequest = 3;
  static const connectResponse = 4;
  static const disconnectRequest = 5;
  static const disconnectResponse = 6;
  static const pingRequest = 7;
  static const pingResponse = 8;
  static const deviceInfoRequest = 9;
  static const deviceInfoResponse = 10;
  static const listEntitiesRequest = 11;
  static const listBinarySensor = 12;
  static const listCover = 13;
  static const listLight = 15;
  static const listSensor = 16;
  static const listSwitch = 17;
  static const listTextSensor = 18;
  static const listEntitiesDone = 19;
  static const subscribeStates = 20;
  static const binarySensorState = 21;
  static const coverState = 22;
  static const lightState = 24;
  static const sensorState = 25;
  static const switchState = 26;
  static const textSensorState = 27;
  static const coverCommand = 30;
  static const lightCommand = 32;
  static const switchCommand = 33;
  static const listButton = 61;
  static const buttonCommand = 62;
}

/// A byte stream to a device (a TCP socket; a fake in tests).
abstract interface class EsphomeSocket {
  Stream<Uint8List> get input;
  void add(List<int> bytes);
  Future<void> close();
}

typedef EsphomeConnector = Future<EsphomeSocket> Function(
  String host,
  int port,
);

final esphomeConnectorProvider = Provider<EsphomeConnector>(
  (ref) => tcpConnector,
);

Future<EsphomeSocket> tcpConnector(String host, int port) async {
  try {
    return _TcpSocket(
      await Socket.connect(host, port, timeout: const Duration(seconds: 5)),
    );
  } on SocketException catch (e) {
    throw AppFailure(
      FailureKind.network,
      debugMessage: 'esphome: ${e.osError?.errorCode}',
    );
  }
}

class _TcpSocket implements EsphomeSocket {
  _TcpSocket(this._socket) {
    _socket.setOption(SocketOption.tcpNoDelay, true);
  }

  final Socket _socket;

  @override
  Stream<Uint8List> get input => _socket;

  @override
  void add(List<int> bytes) => _socket.add(bytes);

  @override
  Future<void> close() async {
    try {
      await _socket.close();
    } on Object {
      // Already gone.
    }
    _socket.destroy();
  }
}

/// The device wants an encryption key, has another one, or none.
class EsphomeKeyError implements Exception {
  const EsphomeKeyError(this.reason);

  /// `required`, `wrong` or `notEncrypted`.
  final String reason;

  @override
  String toString() => 'EsphomeKeyError($reason)';
}

/// What the device says about itself.
typedef EsphomeDeviceInfo = ({
  String name,
  String friendlyName,
  String mac,
  String model,
  String version,
  String manufacturer,
});

/// One connection to an ESPHome device over its native API (TCP 6053),
/// plaintext or encrypted with Noise when [psk] is given. Answers the
/// device's pings and pings it, so a device that went away is noticed.
class EsphomeClient {
  EsphomeClient._(this._socket, this._psk);

  static const port = 6053;

  final EsphomeSocket _socket;
  final Uint8List? _psk;
  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);
  final _messages = StreamController<(int, ProtoMessage)>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  NoiseCipher? _send;
  NoiseCipher? _receive;
  Future<void> _decrypting = Future.value();
  Timer? _keepAlive;
  DateTime _lastHeard = DateTime.now();
  bool _closed = false;
  late EsphomeDeviceInfo info;

  /// Everything the device sends after the handshake.
  Stream<(int, ProtoMessage)> get messages => _messages.stream;

  bool get isClosed => _closed;

  static Future<EsphomeClient> connect(
    EsphomeConnector connector,
    String host, {
    Uint8List? psk,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final socket = await connector(host, port);
    final client = EsphomeClient._(socket, psk);
    try {
      await client._start().timeout(timeout);
      return client;
    } on TimeoutException {
      await client.close();
      throw const AppFailure(FailureKind.timeout, debugMessage: 'esphome');
    } on Object {
      await client.close();
      rethrow;
    }
  }

  Future<void> _start() async {
    final handshake = Completer<void>();
    _sub = _socket.input.listen(
      (bytes) => _onBytes(bytes, handshake),
      onError: (Object e) => _fail(e, handshake),
      onDone: () => _fail(
        const AppFailure(FailureKind.network, debugMessage: 'closed'),
        handshake,
      ),
    );
    if (_psk != null) {
      _noise = NoiseHandshake.initiator(_psk);
      final first = await _noise!.writeFirst();
      _socket.add([1, 0, 0]); // hello frame
      _writeNoiseFrame([0, ...first]);
    } else {
      handshake.complete();
    }
    await handshake.future;

    final hello = expect(EsphomeMessage.helloResponse);
    send(
      EsphomeMessage.helloRequest,
      (ProtoWriter()
            ..string(1, 'Open Smart Home Lite')
            ..uint(2, 1)
            ..uint(3, 10))
          .toBytes(),
    );
    await hello;
    final connected = expect(EsphomeMessage.connectResponse);
    send(EsphomeMessage.connectRequest, Uint8List(0));
    if ((await connected).boolean(1)) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'esphome password',
      );
    }
    final infoReply = expect(EsphomeMessage.deviceInfoResponse);
    send(EsphomeMessage.deviceInfoRequest, Uint8List(0));
    final i = await infoReply;
    info = (
      name: i.string(2),
      friendlyName: i.string(13),
      mac: i.string(3),
      model: i.string(6),
      version: i.string(4),
      manufacturer: i.string(12),
    );
    _keepAlive = Timer.periodic(const Duration(seconds: 20), (_) {
      if (DateTime.now().difference(_lastHeard) > const Duration(seconds: 50)) {
        unawaited(close());
      } else {
        send(EsphomeMessage.pingRequest, Uint8List(0));
      }
    });
  }

  NoiseHandshake? _noise;
  int _handshakeFrames = 0;

  /// The next message of [type].
  Future<ProtoMessage> expect(int type) =>
      messages.firstWhere((m) => m.$1 == type).then((m) => m.$2);

  void send(int type, Uint8List data) {
    if (_closed) {
      throw const AppFailure(FailureKind.network, debugMessage: 'closed');
    }
    if (_send case final cipher?) {
      final plain = Uint8List(4 + data.length)
        ..buffer.asByteData().setUint16(0, type)
        ..buffer.asByteData().setUint16(2, data.length)
        ..setAll(4, data);
      // In order: encryption counts its nonces.
      _sendQueue = _sendQueue.then((_) async {
        final c = await cipher.encrypt(plain);
        if (!_closed) _writeNoiseFrame(c);
      });
    } else {
      final out = BytesBuilder(copy: false)..addByte(0);
      writeVarint(out, data.length);
      writeVarint(out, type);
      out.add(data);
      _socket.add(out.toBytes());
    }
  }

  Future<void> _sendQueue = Future.value();

  void _writeNoiseFrame(List<int> payload) {
    _socket.add([1, payload.length >> 8 & 0xFF, payload.length & 0xFF]);
    _socket.add(payload);
  }

  void _onBytes(Uint8List bytes, Completer<void> handshake) {
    _lastHeard = DateTime.now();
    _buffer
      ..add(_pending)
      ..add(bytes);
    var data = _buffer.takeBytes();
    var i = 0;
    try {
      while (i < data.length) {
        final indicator = data[i];
        if (_psk == null) {
          if (indicator == 1) throw const EsphomeKeyError('required');
          if (indicator != 0) throw const FormatException('bad frame');
          final (length, a) = readVarint(data, i + 1);
          final (type, b) = readVarint(data, a);
          if (b + length > data.length) break;
          _onMessage(type, Uint8List.sublistView(data, b, b + length));
          i = b + length;
        } else {
          if (indicator == 0) throw const EsphomeKeyError('notEncrypted');
          if (indicator != 1) throw const FormatException('bad frame');
          if (i + 3 > data.length) break;
          final length = data[i + 1] << 8 | data[i + 2];
          if (i + 3 + length > data.length) break;
          final frame = Uint8List.fromList(data.sublist(i + 3, i + 3 + length));
          i += 3 + length;
          _onNoiseFrame(frame, handshake);
        }
      }
    } on RangeError {
      // A frame cut off: wait for the rest.
    } on Object catch (e) {
      _fail(e, handshake);
      return;
    }
    _pending = Uint8List.fromList(data.sublist(i));
    data = Uint8List(0);
  }

  void _onNoiseFrame(Uint8List frame, Completer<void> handshake) {
    if (handshake.isCompleted) {
      final cipher = _receive!;
      _decrypting = _decrypting.then((_) async {
        if (_closed) return;
        try {
          final plain = await cipher.decrypt(frame);
          if (plain.length < 4) return;
          final view = ByteData.sublistView(plain);
          final type = view.getUint16(0);
          final length = view.getUint16(2);
          _onMessage(type, Uint8List.sublistView(plain, 4, 4 + length));
        } on Object catch (e) {
          _fail(e, handshake);
        }
      });
      return;
    }
    _handshakeFrames++;
    if (_handshakeFrames == 1) {
      // Server hello: the chosen protocol, then name and MAC.
      if (frame.isEmpty || frame[0] != 1) {
        throw const FormatException('unknown noise protocol');
      }
      return;
    }
    if (frame.isEmpty || frame[0] != 0) {
      // "Handshake MAC failure" and the like: another key.
      throw const EsphomeKeyError('wrong');
    }
    final noise = _noise!;
    _decrypting = _decrypting.then((_) async {
      try {
        await noise.readAnswer(Uint8List.sublistView(frame, 1));
        final (send, receive) = noise.split();
        _send = send;
        _receive = receive;
        if (!handshake.isCompleted) handshake.complete();
      } on NoiseAuthenticationError {
        _fail(const EsphomeKeyError('wrong'), handshake);
      } on Object catch (e) {
        _fail(e, handshake);
      }
    });
  }

  void _onMessage(int type, Uint8List data) {
    switch (type) {
      case EsphomeMessage.pingRequest:
        send(EsphomeMessage.pingResponse, Uint8List(0));
        return;
      case EsphomeMessage.disconnectRequest:
        send(EsphomeMessage.disconnectResponse, Uint8List(0));
        unawaited(close());
        return;
    }
    if (!_messages.isClosed) _messages.add((type, ProtoMessage(data)));
  }

  void _fail(Object error, Completer<void> handshake) {
    if (!handshake.isCompleted) {
      handshake.completeError(error);
    } else if (!_messages.isClosed) {
      _messages.addError(error);
    }
    unawaited(close());
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _keepAlive?.cancel();
    await _sub?.cancel();
    await _socket.close();
    await _messages.close();
  }
}
