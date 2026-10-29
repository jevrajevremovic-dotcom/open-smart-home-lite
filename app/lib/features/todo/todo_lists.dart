import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';

/// One entry of a Home Assistant to-do list (`todo` integration).
@immutable
class TodoItem {
  const TodoItem({
    required this.uid,
    required this.summary,
    required this.completed,
    this.due,
    this.description,
  });

  final String uid;
  final String summary;
  final bool completed;

  /// `YYYY-MM-DD` or an ISO date-time, as Home Assistant sends it.
  final String? due;
  final String? description;

  /// Items as `todo/item/subscribe` and `todo/item/list` send them.
  static List<TodoItem> listFrom(Object? payload) {
    final items = payload is Map ? payload['items'] : null;
    if (items is! List) return const [];
    return [
      for (final i in items)
        if (i is Map && i['uid'] is String && i['summary'] is String)
          TodoItem(
            uid: i['uid'] as String,
            summary: i['summary'] as String,
            completed: i['status'] == 'completed',
            due: i['due']?.toString(),
            description: i['description'] as String?,
          ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is TodoItem &&
      other.uid == uid &&
      other.summary == summary &&
      other.completed == completed &&
      other.due == due &&
      other.description == description;

  @override
  int get hashCode => Object.hash(uid, summary, completed, due, description);
}

/// What a list allows (Home Assistant `TodoListEntityFeature`).
extension TodoFeatures on SmartHomeDevice {
  bool get canAddItems => limits.todoFeatures & 1 != 0;
  bool get canDeleteItems => limits.todoFeatures & 2 != 0;
  bool get canUpdateItems => limits.todoFeatures & 4 != 0;
}

/// The home's to-do and shopping lists, shopping lists first.
final todoListsProvider = Provider<List<SmartHomeDevice>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  return devices.values.where((d) => d.kind == DeviceKind.todoList).toList()
    ..sort((a, b) {
      int rank(SmartHomeDevice d) => d.id == 'todo.shopping_list' ? 0 : 1;
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
});

/// Items of one list, live: `todo/item/subscribe` pushes every change. On
/// a Home Assistant without it, `todo/item/list` is read again whenever the
/// list's open-item count changes. Re-subscribes after reconnecting.
final todoItemsProvider = StreamProvider.autoDispose
    .family<List<TodoItem>, String>((ref, entityId) async* {
      final manager = ref.watch(webSocketManagerProvider);
      final connected = ref.watch(
        connectionStatusProvider.select((s) => s.value?.isConnected ?? false),
      );
      if (manager == null || !connected) {
        throw const AppFailure(FailureKind.webSocket);
      }
      try {
        yield* manager
            .subscribeCommand({
              'type': 'todo/item/subscribe',
              'entity_id': entityId,
            })
            .map(TodoItem.listFrom);
      } on AppFailure catch (e) {
        if (e.kind == FailureKind.webSocket) rethrow;
        // Older Home Assistant: no subscription, read the list instead.
        ref.watch(deviceProvider(entityId).select((d) => d?.state.raw));
        yield TodoItem.listFrom(
          await manager.sendCommand({
            'type': 'todo/item/list',
            'entity_id': entityId,
          }),
        );
      }
    });

/// Changes a list through Home Assistant's `todo` services.
class TodoActions {
  TodoActions(this._ref);

  final Ref _ref;

  Future<void> _call(String service, Map<String, Object?> data) async {
    final api = _ref.read(homeAssistantApiProvider);
    if (api == null) throw const AppFailure(FailureKind.webSocket);
    await api.callService('todo', service, data: data);
  }

  Future<void> add(String list, String text) =>
      _call('add_item', {'entity_id': list, 'item': text.trim()});

  Future<void> setCompleted(String list, TodoItem item, bool completed) =>
      _call('update_item', {
        'entity_id': list,
        'item': item.uid,
        'status': completed ? 'completed' : 'needs_action',
      });

  Future<void> rename(String list, TodoItem item, String text) => _call(
    'update_item',
    {'entity_id': list, 'item': item.uid, 'rename': text.trim()},
  );

  Future<void> remove(String list, TodoItem item) => _call('remove_item', {
    'entity_id': list,
    'item': [item.uid],
  });

  Future<void> removeCompleted(String list) =>
      _call('remove_completed_items', {'entity_id': list});
}

final todoActionsProvider = Provider<TodoActions>(TodoActions.new);
