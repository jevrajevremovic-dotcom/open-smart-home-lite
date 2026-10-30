import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/storage/credential_store.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_http.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// A camera's login, kept like a password.
@immutable
class CameraLogin {
  const CameraLogin(this.user, this.password);

  final String user;
  final String password;

  String encode() => jsonEncode({'user': user, 'password': password});

  static CameraLogin? decode(String? text) {
    if (text == null) return null;
    try {
      final j = jsonDecode(text);
      if (j is Map && j['user'] is String && j['password'] is String) {
        return CameraLogin(j['user'] as String, j['password'] as String);
      }
    } on FormatException {
      // Not one.
    }
    return null;
  }
}

/// The still image a camera serves at [url], with [login] if it asks
/// (Digest, else Basic). Throws `AppFailure` when there is no image.
Future<Uint8List> cameraSnapshot(
  LanRequests http,
  Uri url, {
  CameraLogin? login,
}) async {
  Future<LanResponse> get(LanAuth? auth) => http.send(
    'GET',
    url,
    auth: auth,
    insecure: url.scheme == 'https',
    timeout: const Duration(seconds: 6),
  );
  LanResponse r;
  try {
    r = await get(
      login == null ? null : LanAuth.digest(login.user, login.password),
    );
  } on AppFailure catch (e) {
    if (e.kind != FailureKind.authentication || login == null) rethrow;
    r = await get(LanAuth.basic(login.user, login.password));
  }
  final b = r.body;
  final jpeg = b.length > 2 && b[0] == 0xFF && b[1] == 0xD8;
  final png = b.length > 4 && b[0] == 0x89 && b[1] == 0x50;
  if (!r.ok || !(jpeg || png)) {
    throw AppFailure(
      FailureKind.server,
      debugMessage: 'camera: no image (${r.status})',
    );
  }
  return b;
}

/// Where a camera's image is: `http://<host><options['snapshot']>`.
Uri cameraUrl(ConfiguredDevice d) {
  final path = d.options['snapshot'] ?? '/';
  final scheme = d.options['scheme'] ?? 'http';
  return Uri.parse('$scheme://${d.host}$path');
}

/// The device for a camera added by [url].
ConfiguredDevice cameraDevice(Uri url, {bool secured = false}) {
  final id = hash.md5
      .convert(utf8.encode(url.toString()))
      .toString()
      .substring(0, 12);
  final hostPort = url.hasPort ? '${url.host}:${url.port}' : url.host;
  return ConfiguredDevice(
    adapter: 'camera',
    id: id,
    host: hostPort,
    label: url.host,
    secured: secured,
    options: {
      'snapshot': url.hasQuery ? '${url.path}?${url.query}' : url.path,
      if (url.scheme != 'http') 'scheme': url.scheme,
    },
  );
}

/// Cameras that serve a still image over HTTP (most do: Reolink,
/// Hikvision, Dahua, ESP32-CAM…). Checked now and then; the image itself
/// is fetched while its screen is open ([cameraFrameProvider]).
class CameraAdapter extends PolledAdapter {
  CameraAdapter(
    this._http, {
    this.logins,
    super.pollEvery = const Duration(minutes: 1),
  });

  final LanRequests _http;
  final Future<String?> Function(String key)? logins;

  @override
  String get id => 'camera';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final login = device.secured
        ? CameraLogin.decode(await logins?.call(device.key))
        : null;
    await cameraSnapshot(_http, cameraUrl(device), login: login);
    return [parseCamera(device)];
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async => throw const AppFailure(
    FailureKind.unsupportedFeature,
    debugMessage: 'a camera takes no commands',
  );
}

SmartHomeDevice parseCamera(ConfiguredDevice device) => SmartHomeDevice(
  id: '${device.key}:camera',
  sourceId: device.host,
  deviceId: device.key,
  name: device.label ?? device.host,
  kind: DeviceKind.camera,
  protocol: DeviceProtocol.wifi,
  model: device.model,
  available: true,
  capabilities: const {Capability.cameraSnapshot},
  state: const DeviceState(raw: 'idle'),
);

/// The camera's image, fetched again every 2 s while watched.
final cameraFrameProvider = StreamProvider.autoDispose
    .family<Uint8List, String>((ref, key) {
      final config = ref
          .watch(localHomeProvider)
          .devices
          .where((d) => d.key == key)
          .firstOrNull;
      final http = ref.watch(lanRequestsProvider);
      final store = ref.read(credentialStoreProvider);
      final frames = StreamController<Uint8List>();
      Timer? next;
      var gone = false;
      ref.onDispose(() {
        gone = true;
        next?.cancel();
        unawaited(frames.close());
      });
      if (config == null) return frames.stream;
      Future<void> fetch() async {
        try {
          final login = config.secured
              ? CameraLogin.decode(
                  await store.readCredential(devicePasswordId(key)),
                )
              : null;
          final image = await cameraSnapshot(
            http,
            cameraUrl(config),
            login: login,
          );
          if (!gone) frames.add(image);
        } on AppFailure catch (e) {
          // Shown, and tried again: a camera may answer the next time.
          if (!gone) frames.addError(e);
        }
        if (!gone) next = Timer(const Duration(seconds: 2), fetch);
      }

      unawaited(fetch());
      return frames.stream;
    });
