import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/session_controller.dart';

/// A Home Assistant persistent notification.
@immutable
class HaNotification {
  const HaNotification({
    required this.id,
    required this.message,
    this.title,
    this.createdAt,
  });

  final String id;
  final String? title;

  /// Markdown as HA sends it.
  final String message;
  final DateTime? createdAt;

  static HaNotification? parse(Object? json) {
    if (json is! Map || json['notification_id'] is! String) return null;
    return HaNotification(
      id: json['notification_id']! as String,
      title: json['title'] is String ? json['title']! as String : null,
      message: json['message'] is String ? json['message']! as String : '',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at']! as String)?.toLocal()
          : null,
    );
  }

  /// The message without Markdown syntax (links keep their text).
  String get plainMessage => message
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'[*_`#>]'), '')
      .trim();
}

/// Live list of persistent notifications, newest first. Uses the
/// frontend's `persistent_notification/subscribe` WebSocket command;
/// empty when it is not available.
final haNotificationsProvider = StreamProvider<List<HaNotification>>((
  ref,
) async* {
  final ws = ref.watch(webSocketManagerProvider);
  final live = ref.watch(
    connectionStatusProvider.select((s) => s.value?.isConnected ?? false),
  );
  if (ws == null || !live) {
    yield const [];
    return;
  }
  final items = <String, HaNotification>{};
  List<HaNotification> sorted() => items.values.toList()
    ..sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
  try {
    await for (final e in ws.subscribeCommand({
      'type': 'persistent_notification/subscribe',
    })) {
      final type = e['type'];
      final batch = e['notifications'];
      if (batch is! Map) continue;
      if (type == 'current') items.clear();
      for (final entry in batch.entries) {
        final key = '${entry.key}';
        if (type == 'removed') {
          items.remove(key);
        } else if (HaNotification.parse(entry.value) case final n?) {
          items[key] = n;
        }
      }
      yield sorted();
    }
  } on Object {
    yield const [];
  }
});
