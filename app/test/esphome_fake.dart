import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:open_smart_home_lite/features/devices/data/local/esphome/esphome_client.dart';
import 'package:open_smart_home_lite/features/devices/data/local/esphome/noise.dart';
import 'package:open_smart_home_lite/features/devices/data/local/esphome/proto.dart';

/// An ESPHome device on a pretend network: the device's side of the
/// native API, plaintext or with Noise (a [key], base64).
class FakeEsphomeDevice {
  FakeEsphomeDevice({
    this.key,
    this.mac = 'AA:BB:CC:DD:EE:01',
    this.name = 'kuhinja',
    this.friendlyName = 'Kuhinja',
    this.entities = const [],
    this.states = const [],
  });

  final String? key;
  final String mac;
  final String name;
  final String friendlyName;

  /// `ListEntities…Response` messages, as (type, bytes).
  final List<(int, Uint8List)> entities;

  /// State messages sent after `SubscribeStates`.
  List<(int, Uint8List)> states;

  /// Commands received, as (type, message).
  final List<(int, ProtoMessage)> commands = [];
  final List<_FakeSocket> _connections = [];

  int get connections => _connections.length;

  Future<EsphomeSocket> connect(String host, int port) async {
    final socket = _FakeSocket(this);
    _connections.add(socket);
    return socket;
  }

  /// A change on the device, to every connected app.
  void push(int type, Uint8List data) {
    for (final c in _connections) {
      if (c.subscribed) c.sendMessage(type, data);
    }
  }

  /// The device goes away (power cut).
  void drop() {
    for (final c in _connections) {
      unawaited(c.close());
    }
  }
}

/// Builds a `ListEntities…Response` or a state message.
Uint8List message(void Function(ProtoWriter w) fields) {
  final w = ProtoWriter();
  fields(w);
  return w.toBytes();
}

class _FakeSocket implements EsphomeSocket {
  _FakeSocket(this.device) {
    final key = device.key;
    if (key != null) _noise = NoiseHandshake.responder(base64.decode(key));
  }

  final FakeEsphomeDevice device;
  final _toApp = StreamController<Uint8List>();
  final _buffer = <int>[];
  NoiseHandshake? _noise;
  NoiseCipher? _send;
  NoiseCipher? _receive;
  int _frames = 0;
  bool subscribed = false;
  Future<void> _queue = Future.value();
  bool _closed = false;

  @override
  Stream<Uint8List> get input => _toApp.stream;

  @override
  void add(List<int> bytes) {
    _buffer.addAll(bytes);
    _queue = _queue.then((_) => _drain());
  }

  Future<void> _drain() async {
    while (_buffer.isNotEmpty && !_closed) {
      final indicator = _buffer[0];
      if (device.key == null) {
        if (indicator != 0) {
          _write([0, 0, 0]); // a plaintext device answers in plaintext
          return;
        }
        final data = Uint8List.fromList(_buffer);
        final (int, int) length;
        final (int, int) type;
        try {
          length = readVarint(data, 1);
          type = readVarint(data, length.$2);
        } on RangeError {
          return;
        }
        if (type.$2 + length.$1 > data.length) return;
        final payload = data.sublist(type.$2, type.$2 + length.$1);
        _buffer.removeRange(0, type.$2 + length.$1);
        _onMessage(type.$1, payload);
      } else {
        if (indicator != 1) {
          _write([1, 0, 0]); // "this device is encrypted"
          _buffer.clear();
          return;
        }
        if (_buffer.length < 3) return;
        final length = _buffer[1] << 8 | _buffer[2];
        if (_buffer.length < 3 + length) return;
        final frame = Uint8List.fromList(_buffer.sublist(3, 3 + length));
        _buffer.removeRange(0, 3 + length);
        await _onNoiseFrame(frame);
      }
    }
  }

  Future<void> _onNoiseFrame(Uint8List frame) async {
    _frames++;
    if (_frames == 1) {
      // Client hello: the server hello right away (protocol, name, MAC).
      _noiseFrame([
        1,
        ...utf8.encode(device.name),
        0,
        ...utf8.encode(device.mac),
        0,
      ]);
      return;
    }
    if (_frames == 2) {
      final Uint8List answer;
      try {
        answer = await _noise!.readFirstAndAnswer(
          Uint8List.sublistView(frame, 1),
        );
      } on NoiseAuthenticationError {
        _noiseFrame([1, ...utf8.encode('Handshake MAC failure')]);
        return;
      }
      _noiseFrame([0, ...answer]);
      final (send, receive) = _noise!.split();
      _send = send;
      _receive = receive;
      return;
    }
    final plain = await _receive!.decrypt(frame);
    final view = ByteData.sublistView(plain);
    _onMessage(
      view.getUint16(0),
      Uint8List.sublistView(plain, 4, 4 + view.getUint16(2)),
    );
  }

  void _onMessage(int type, Uint8List data) {
    switch (type) {
      case EsphomeMessage.helloRequest:
        sendMessage(
          EsphomeMessage.helloResponse,
          message(
            (w) => w
              ..uint(1, 1)
              ..uint(2, 10)
              ..string(3, 'fake')
              ..string(4, device.name),
          ),
        );
      case EsphomeMessage.connectRequest:
        sendMessage(EsphomeMessage.connectResponse, Uint8List(0));
      case EsphomeMessage.deviceInfoRequest:
        sendMessage(
          EsphomeMessage.deviceInfoResponse,
          message(
            (w) => w
              ..string(2, device.name)
              ..string(3, device.mac)
              ..string(4, '2025.10.0')
              ..string(6, 'esp32dev')
              ..string(13, device.friendlyName),
          ),
        );
      case EsphomeMessage.listEntitiesRequest:
        for (final (t, d) in device.entities) {
          sendMessage(t, d);
        }
        sendMessage(EsphomeMessage.listEntitiesDone, Uint8List(0));
      case EsphomeMessage.subscribeStates:
        subscribed = true;
        for (final (t, d) in device.states) {
          sendMessage(t, d);
        }
      case EsphomeMessage.pingRequest:
        sendMessage(EsphomeMessage.pingResponse, Uint8List(0));
      default:
        device.commands.add((type, ProtoMessage(data)));
    }
  }

  void sendMessage(int type, Uint8List data) {
    if (_closed) return;
    if (_send case final cipher?) {
      final plain = Uint8List(4 + data.length)
        ..buffer.asByteData().setUint16(0, type)
        ..buffer.asByteData().setUint16(2, data.length)
        ..setAll(4, data);
      _queue = _queue.then(
        (_) async => _noiseFrame(await cipher.encrypt(plain)),
      );
    } else {
      final out = BytesBuilder()..addByte(0);
      writeVarint(out, data.length);
      writeVarint(out, type);
      out.add(data);
      _write(out.toBytes());
    }
  }

  void _noiseFrame(List<int> payload) =>
      _write([1, payload.length >> 8, payload.length & 0xFF, ...payload]);

  void _write(List<int> bytes) {
    if (!_closed) _toApp.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _toApp.close();
  }
}
