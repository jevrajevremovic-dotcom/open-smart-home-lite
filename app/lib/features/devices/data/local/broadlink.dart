import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'aes.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

// Broadlink RM infrared (and RF) blasters over their local protocol (UDP
// port 80, AES-128-CBC): the remote's buttons are learned once from the
// original remote, kept with the device (`options['btn:<name>']`, base64),
// and each becomes a button of its own. The device must be "unlocked" in
// the Broadlink app.

const _initialKey = [
  0x09, 0x76, 0x28, 0x34, 0x3f, 0xe9, 0x9e, 0x23, //
  0x76, 0x5c, 0x15, 0x13, 0xac, 0xcf, 0x8b, 0x02,
];
const _iv = [
  0x56, 0x2e, 0x17, 0x99, 0x6d, 0x09, 0x3d, 0x28, //
  0xdd, 0xb3, 0xba, 0x69, 0x5a, 0x2e, 0x6f, 0x58,
];

int _checksum(List<int> bytes) =>
    bytes.fold<int>(0xBEAF, (a, b) => a + b) & 0xFFFF;

/// The discovery packet (0x30 bytes): asks every device to say who it is.
Uint8List broadlinkHello() {
  final p = Uint8List(0x30);
  final now = DateTime.now();
  final b = ByteData.sublistView(p)
    ..setUint16(0x0C, now.year, Endian.little)
    ..setUint8(0x0E, now.minute)
    ..setUint8(0x0F, now.hour)
    ..setUint8(0x10, now.year % 100)
    ..setUint8(0x11, now.weekday)
    ..setUint8(0x12, now.day)
    ..setUint8(0x13, now.month)
    ..setUint8(0x26, 0x06);
  b.setUint16(0x20, _checksum(p), Endian.little);
  return p;
}

/// A device that answered the hello.
typedef BroadlinkFound = ({
  String host,
  int devtype,
  Uint8List mac,
  String name,
  bool locked,
});

BroadlinkFound? parseBroadlinkHello(String host, Uint8List r) {
  if (r.length < 0x40) return null;
  final b = ByteData.sublistView(r);
  final nameEnd = r.indexOf(0, 0x40);
  return (
    host: host,
    devtype: b.getUint16(0x34, Endian.little),
    // As the device sends it (reversed); packets use it so.
    mac: Uint8List.fromList(r.sublist(0x3A, 0x40)),
    name: utf8.decode(
      r.sublist(0x40, nameEnd < 0 ? r.length : nameEnd),
      allowMalformed: true,
    ),
    locked: r.length > 0x7F && r[0x7F] != 0,
  );
}

/// `aabbccddeeff`, the MAC as printed on the device.
String broadlinkMacText(List<int> packetMac) =>
    [for (final b in packetMac.reversed) b.toRadixString(16).padLeft(2, '0')]
        .join();

Uint8List broadlinkMacFrom(String text) => Uint8List.fromList([
  for (var i = 10; i >= 0; i -= 2)
    int.parse(text.substring(i, i + 2), radix: 16),
]);

/// A command packet: header, payload checksum, payload encrypted.
Uint8List broadlinkPacket({
  required int devtype,
  required int type,
  required int count,
  required List<int> mac,
  required int id,
  required List<int> key,
  required List<int> payload,
}) {
  final p = Uint8List(0x38);
  p.setRange(0, 8, const [0x5a, 0xa5, 0xaa, 0x55, 0x5a, 0xa5, 0xaa, 0x55]);
  ByteData.sublistView(p)
    ..setUint16(0x24, devtype, Endian.little)
    ..setUint16(0x26, type, Endian.little)
    ..setUint16(0x28, count & 0xFFFF, Endian.little)
    ..setUint32(0x30, id, Endian.little)
    ..setUint16(0x34, _checksum(payload), Endian.little);
  p.setRange(0x2A, 0x30, mac);
  final padded = [
    ...payload,
    ...List.filled((16 - payload.length % 16) % 16, 0),
  ];
  final encrypted = _cbc(true, key, padded);
  final out = Uint8List.fromList([...p, ...encrypted]);
  ByteData.sublistView(out).setUint16(0x20, _checksum(out), Endian.little);
  return out;
}

/// Broadlink pads with zeros itself: no padding here.
Uint8List _cbc(bool encrypt, List<int> key, List<int> data) =>
    aesCbcRaw(encrypt, key, _iv, data);

/// The error code and decrypted payload of a device's answer.
({int error, Uint8List payload})? broadlinkAnswer(Uint8List r, List<int> key) {
  if (r.length < 0x38) return null;
  final error = ByteData.sublistView(r).getInt16(0x22, Endian.little);
  final body = r.sublist(0x38);
  if (body.isEmpty || body.length % 16 != 0) {
    return (error: error, payload: Uint8List(0));
  }
  return (error: error, payload: _cbc(false, key, body));
}

/// A session with one device (after authentication: its id and key).
class BroadlinkSession {
  BroadlinkSession(this._udp, this.host, this.devtype, this.mac);

  final LanUdp _udp;
  final String host;
  final int devtype;
  final Uint8List mac;
  int _id = 0;
  List<int> _key = _initialKey;
  int _count = 0;
  bool _authed = false;

  /// RM4 and newer frame their commands with a length.
  bool get rm4 => devtype >= 0x5000;

  Future<({int error, Uint8List payload})> _send(
    int type,
    List<int> payload,
  ) async {
    final answers = await _udp.ask(
      host,
      80,
      broadlinkPacket(
        devtype: devtype,
        type: type,
        count: ++_count,
        mac: mac,
        id: _id,
        key: _key,
        payload: payload,
      ),
      wait: const Duration(seconds: 3),
    );
    final a = answers.isEmpty
        ? null
        : broadlinkAnswer(answers.first.data, _key);
    if (a == null) {
      throw const AppFailure(FailureKind.timeout, debugMessage: 'broadlink');
    }
    return a;
  }

  Future<void> auth() async {
    if (_authed) return;
    final p = Uint8List(0x50);
    for (var i = 0x04; i <= 0x12; i++) {
      p[i] = 0x31;
    }
    p[0x1E] = 0x01;
    p[0x2D] = 0x01;
    p.setRange(0x30, 0x36, ascii.encode('Test 1'));
    final a = await _send(0x65, p);
    if (a.error != 0 || a.payload.length < 0x14) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'broadlink: locked? (unlock it in the Broadlink app)',
      );
    }
    _id = ByteData.sublistView(a.payload).getUint32(0, Endian.little);
    _key = a.payload.sublist(4, 0x14);
    _authed = true;
  }

  /// An RM command ([cmd]: 2 send, 3 learn, 4 check) and its data.
  Future<({int error, Uint8List data})> command(
    int cmd, [
    List<int> data = const [],
  ]) async {
    await auth();
    final head = rm4
        ? (ByteData(6)
                ..setUint16(0, data.length + 4, Endian.little)
                ..setUint32(2, cmd, Endian.little))
              .buffer
              .asUint8List()
        : (ByteData(4)..setUint32(0, cmd, Endian.little)).buffer.asUint8List();
    final a = await _send(0x6A, [...head, ...data]);
    final skip = rm4 ? 6 : 4;
    return (
      error: a.error,
      data: a.payload.length > skip ? a.payload.sublist(skip) : Uint8List(0),
    );
  }

  Future<void> sendCode(List<int> code) async {
    final r = await command(0x02, code);
    if (r.error != 0) {
      throw AppFailure(
        FailureKind.server,
        debugMessage: 'broadlink ${r.error}',
      );
    }
  }

  /// Waits (up to [wait]) for a button pressed at the device; its code.
  Future<Uint8List?> learn({
    Duration wait = const Duration(seconds: 20),
  }) async {
    await command(0x03);
    final until = DateTime.now().add(wait);
    while (DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final r = await command(0x04);
      // Until a button is pressed, the device answers with an error.
      if (r.error == 0 && r.data.isNotEmpty) return _trim(r.data);
    }
    return null;
  }

  /// The code without the zeros it was padded with.
  static Uint8List _trim(Uint8List d) {
    var end = d.length;
    while (end > 0 && d[end - 1] == 0) {
      end--;
    }
    return d.sublist(0, end);
  }
}

class BroadlinkClient {
  BroadlinkClient(this._udp);

  final LanUdp _udp;
  final Map<String, BroadlinkSession> _sessions = {};

  BroadlinkSession session(ConfiguredDevice d) => _sessions.putIfAbsent(
    '${d.key}@${d.host}',
    () => BroadlinkSession(
      _udp,
      d.host,
      int.parse(d.options['devtype'] ?? '0', radix: 16),
      broadlinkMacFrom(d.id),
    ),
  );

  void forget(ConfiguredDevice d) => _sessions.remove('${d.key}@${d.host}');

  Future<List<BroadlinkFound>> discover() async {
    final answers = await _udp.ask(
      '255.255.255.255',
      80,
      broadlinkHello(),
      wait: const Duration(seconds: 3),
      first: false,
    );
    return [for (final a in answers) ?parseBroadlinkHello(a.host, a.data)];
  }
}

final broadlinkClientProvider = Provider<BroadlinkClient>(
  (ref) => BroadlinkClient(ref.watch(lanUdpProvider)),
);

/// The learned buttons of [d] by name.
Map<String, Uint8List> broadlinkButtons(ConfiguredDevice d) => {
  for (final e in d.options.entries)
    if (e.key.startsWith('btn:')) e.key.substring(4): base64.decode(e.value),
};

/// Broadlink RM: the blaster itself (where buttons are learned) and one
/// button per learned code. Checked now and then (IR has no state).
class BroadlinkAdapter extends PolledAdapter {
  BroadlinkAdapter(
    this._client, {
    super.pollEvery = const Duration(minutes: 1),
  });

  final BroadlinkClient _client;

  @override
  String get id => 'broadlink';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    try {
      await _client.session(device).auth();
    } on AppFailure {
      _client.forget(device);
      rethrow;
    }
    return parseBroadlink(device);
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final part = channel.id.split(':').last;
    final code = part.startsWith('btn_')
        ? broadlinkButtons(device)[channel.sourceId]
        : null;
    if (command is! Activate || code == null) {
      throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for ${channel.id}',
      );
    }
    await _client.session(device).sendCode(code);
  }
}

List<SmartHomeDevice> parseBroadlink(ConfiguredDevice device) {
  final name = device.label ?? 'Broadlink';
  SmartHomeDevice make(
    String part,
    String sourceId,
    String label,
    DeviceKind kind,
    Set<Capability> caps,
  ) => SmartHomeDevice(
    id: '${device.key}:$part',
    sourceId: sourceId,
    deviceId: device.key,
    name: label,
    kind: kind,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Broadlink',
    model: device.model,
    available: true,
    capabilities: caps,
    state: const DeviceState(raw: 'idle'),
  );
  final buttons = broadlinkButtons(device).keys.toList()..sort();
  return [
    make('remote', device.host, name, DeviceKind.remote, const {}),
    for (final b in buttons)
      make(
        'btn_${b.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_')}',
        b,
        '$name · $b',
        DeviceKind.button,
        const {Capability.trigger},
      ),
  ];
}
