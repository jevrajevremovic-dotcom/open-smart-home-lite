import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../authentication/application/session_controller.dart';
import '../../integrations/home_assistant/websocket/ha_websocket_manager.dart';
import '../ha_notify/ha_push.dart';

/// Home Assistant tag URL, the format of the official apps.
String haTagUri(String tagId) => 'https://www.home-assistant.io/tag/$tagId';

/// A random tag id (UUID v4 form, like the official apps write).
String newTagId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) =>
      [for (var i = from; i < to; i++) b[i].toRadixString(16).padLeft(2, '0')]
          .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}'
      .toUpperCase();
}

/// Why writing a tag did not work.
enum NfcWriteError {
  unavailable,
  readOnly,
  tooSmall,
  unsupported,
  failed,
  cancelled,
}

class NfcWriteException implements Exception {
  const NfcWriteException(this.error);
  final NfcWriteError error;
}

abstract interface class NfcPlatform {
  bool get supported;

  /// `(hardware, enabled)`.
  Future<(bool, bool)> availability();

  /// The tag that launched the app, once.
  Future<String?> initialTag();

  /// Tags scanned while the app runs.
  Stream<String> get scans;

  /// Waits for a tag and writes [uri] to it; throws [NfcWriteException].
  Future<void> write(String uri);

  Future<void> cancel();
}

class AndroidNfc implements NfcPlatform {
  AndroidNfc() {
    if (supported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'scanned' && call.arguments is String) {
          _scans.add(call.arguments as String);
        }
      });
    }
  }

  static const _channel = MethodChannel('org.opensmarthome/nfc');
  final _scans = StreamController<String>.broadcast();

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<(bool, bool)> availability() async {
    final m = await _channel.invokeMapMethod<String, Object?>('available');
    return (m?['hardware'] == true, m?['enabled'] == true);
  }

  @override
  Future<String?> initialTag() => _channel.invokeMethod<String>('initialTag');

  @override
  Stream<String> get scans => _scans.stream;

  @override
  Future<void> write(String uri) async {
    try {
      await _channel.invokeMethod<bool>('write', {'uri': uri});
    } on PlatformException catch (e) {
      throw NfcWriteException(switch (e.code) {
        'unavailable' => NfcWriteError.unavailable,
        'read_only' => NfcWriteError.readOnly,
        'too_small' => NfcWriteError.tooSmall,
        'unsupported' => NfcWriteError.unsupported,
        'cancelled' => NfcWriteError.cancelled,
        _ => NfcWriteError.failed,
      });
    }
  }

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}

final nfcPlatformProvider = Provider<NfcPlatform>((ref) => AndroidNfc());

/// A tag known to Home Assistant (`tag/list`).
@immutable
class HaTag {
  const HaTag({required this.id, this.name, this.lastScanned});

  final String id;
  final String? name;
  final DateTime? lastScanned;

  static HaTag? tryParse(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return HaTag(
      id: json['id'] as String,
      name: json['name'] as String?,
      lastScanned: DateTime.tryParse('${json['last_scanned']}')?.toLocal(),
    );
  }
}

final haTagsProvider = FutureProvider.autoDispose<List<HaTag>>((ref) async {
  final manager = ref.watch(webSocketManagerProvider);
  final connected = ref.watch(
    connectionStatusProvider.select((s) => s.value?.isConnected ?? false),
  );
  if (manager == null || !connected) {
    throw const AppFailure(FailureKind.webSocket);
  }
  final list = await manager.sendCommand({'type': 'tag/list'});
  return [for (final t in list is List ? list : const []) ?HaTag.tryParse(t)]
    ..sort((a, b) => (a.name ?? a.id).compareTo(b.name ?? b.id));
});

/// Tells Home Assistant a tag was scanned (Mobile App `scan_tag`): its
/// automations with a tag trigger run, and the tag's "last scanned" moves.
Future<void> reportTagScan(
  HaWebSocketManager? manager,
  MobileAppRegistration? registration,
  String tagId,
) async {
  if (registration == null || manager == null) {
    throw const AppFailure(
      FailureKind.validation,
      debugMessage: 'not registered',
    );
  }
  final answer = await manager.sendCommand({
    'type': 'webhook/handle',
    'webhook_id': registration.webhookId,
    'method': 'POST',
    'headers': {'Content-Type': 'application/json'},
    'body': jsonEncode({
      'type': 'scan_tag',
      'data': {'tag_id': tagId},
    }),
  });
  final status = answer is Map ? answer['status'] : null;
  if (status is int && status >= 300) {
    throw AppFailure(FailureKind.server, statusCode: status);
  }
}

/// The automation that runs [target] (a scene or script) when [tagId] is
/// scanned.
Map<String, Object?> tagAutomation({
  required String alias,
  required String tagId,
  required String target,
}) {
  final domain = target.split('.').first;
  return {
    'alias': alias,
    'description': 'Open Smart Home: NFC',
    'mode': 'single',
    'triggers': [
      {'trigger': 'tag', 'tag_id': tagId},
    ],
    'conditions': <Object>[],
    'actions': [
      {
        'action': '$domain.turn_on',
        'target': {'entity_id': target},
      },
    ],
  };
}
