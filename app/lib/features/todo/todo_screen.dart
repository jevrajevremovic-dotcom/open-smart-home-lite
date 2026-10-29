import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/status_widgets.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/smart_home_device.dart';
import '../devices/presentation/device_detail_screen.dart'
    show EmptyHintPlaceholder;
import '../board/board_repository.dart';
import 'todo_lists.dart';

/// Shopping and to-do lists from Home Assistant: check off, add, rename,
/// delete. Changes made elsewhere (another phone, the wall panel, HA
/// itself) show up live.
class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key, this.listId});

  /// `null`: the first list (the shopping list, if there is one).
  final String? listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lists = ref.watch(todoListsProvider);
    final current =
        lists.where((l) => l.id == listId).firstOrNull ?? lists.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todoTitle),
        actions: [
          IconButton(
            key: const Key('openBoard'),
            tooltip: l10n.boardTitle,
            onPressed: () => context.push(
              AppRoutes.boardListFor(kiosk: ref.read(kioskActiveProvider)),
            ),
            icon: const Icon(Icons.draw_outlined),
          ),
        ],
      ),
      body: MockModeBanner(
        child: current == null
            ? EmptyHintPlaceholder(text: l10n.todoNoLists)
            : ConstrainedContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lists.length > 1)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          spacing: 8,
                          children: [
                            for (final l in lists)
                              ChoiceChip(
                                key: ValueKey('todoList-${l.id}'),
                                label: Text(l.name),
                                selected: l.id == current.id,
                                onSelected: (_) => context.replace(
                                  AppRoutes.todoList(
                                    l.id,
                                    kiosk: ref.read(kioskActiveProvider),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: TodoListView(
                        key: ValueKey(current.id),
                        list: current,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// One list: an add field, open items, and done items below. Also used by
/// the kiosk panel ([compact]: fewer paddings, no done section).
class TodoListView extends ConsumerStatefulWidget {
  const TodoListView({super.key, required this.list, this.compact = false});

  final SmartHomeDevice list;
  final bool compact;

  @override
  ConsumerState<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends ConsumerState<TodoListView> {
  final _text = TextEditingController();
  bool _showDone = false;

  /// Swiped away, waiting for Home Assistant: a dismissed row must leave
  /// the tree at once.
  final Set<String> _removed = {};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _id => widget.list.id;

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      await action();
    } on AppFailure catch (e) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, e))));
    }
  }

  Future<void> _add() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    await _run(() => ref.read(todoActionsProvider).add(_id, text));
  }

  Future<void> _rename(TodoItem item) async {
    final l10n = context.l10n;
    final text = await showTodoTextDialog(
      context,
      title: l10n.todoRename,
      action: l10n.save,
      initial: item.summary,
      fieldKey: const Key('todoRenameField'),
      saveKey: const Key('todoRenameSave'),
    );
    if (text == null || text.trim().isEmpty || text.trim() == item.summary) {
      return;
    }
    await _run(() => ref.read(todoActionsProvider).rename(_id, item, text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Features can change at runtime; read them from the live device.
    final list = ref.watch(deviceProvider(_id)) ?? widget.list;
    final items = ref.watch(todoItemsProvider(_id));
    final pad = widget.compact ? 0.0 : 16.0;

    final shown =
        items.value?.where((i) => !_removed.contains(i.uid)).toList() ??
        const <TodoItem>[];
    final open = shown.where((i) => !i.completed).toList();
    final done = shown.where((i) => i.completed).toList();

    Widget tile(TodoItem item) {
      final row = CheckboxListTile(
        key: ValueKey('todoItem-${item.uid}'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.symmetric(horizontal: pad / 2),
        value: item.completed,
        onChanged: list.canUpdateItems
            ? (v) => _run(
                () => ref
                    .read(todoActionsProvider)
                    .setCompleted(_id, item, v ?? false),
              )
            : null,
        title: GestureDetector(
          onLongPress: list.canUpdateItems ? () => _rename(item) : null,
          child: Text(
            item.summary,
            style: item.completed
                ? TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
        ),
        subtitle: item.due == null || widget.compact
            ? null
            : Text(l10n.todoDue(_formatDue(l10n.localeName, item.due!))),
      );
      if (!list.canDeleteItems) return row;
      return Dismissible(
        key: ValueKey('todoDismiss-${item.uid}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: theme.colorScheme.errorContainer,
          child: Icon(
            Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        onDismissed: (_) async {
          setState(() => _removed.add(item.uid));
          await _run(() => ref.read(todoActionsProvider).remove(_id, item));
          // Shown again if Home Assistant kept it.
          if (mounted) setState(() => _removed.remove(item.uid));
        },
        child: row,
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, widget.compact ? 0 : 8, pad, pad * 2),
      children: [
        if (list.canAddItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              key: const Key('todoAddField'),
              controller: _text,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                hintText: l10n.todoAddHint,
                prefixIcon: const Icon(Icons.add),
                suffixIcon: IconButton(
                  key: const Key('todoAddButton'),
                  tooltip: l10n.todoAdd,
                  icon: const Icon(Icons.send),
                  onPressed: _add,
                ),
              ),
            ),
          )
        else if (!widget.compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.todoReadOnly, style: theme.textTheme.bodySmall),
          ),
        switch (items) {
          AsyncValue(hasValue: true) when open.isEmpty && done.isEmpty =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l10n.todoEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          AsyncValue(hasValue: true) => Column(
            children: [for (final i in open) tile(i)],
          ),
          AsyncError() => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: InlineNotice.warning(l10n.todoUnavailable),
          ),
          _ => ListSkeleton(rows: 4, label: l10n.loadingContent),
        },
        if (done.isNotEmpty && !widget.compact) ...[
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const Key('todoShowDone'),
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  onPressed: () => setState(() => _showDone = !_showDone),
                  icon: Icon(_showDone ? Icons.expand_less : Icons.expand_more),
                  label: Text(l10n.todoDone(done.length)),
                ),
              ),
              if (list.canDeleteItems)
                TextButton(
                  key: const Key('todoClearDone'),
                  onPressed: () => _run(
                    () => ref.read(todoActionsProvider).removeCompleted(_id),
                  ),
                  child: Text(l10n.todoClearDone),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _showDone
                ? Column(children: [for (final i in done) tile(i)])
                : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
  }
}

/// Asks for an item's text. The field's controller lives as long as the
/// dialog (including its closing animation).
Future<String?> showTodoTextDialog(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
  Key? fieldKey,
  Key? saveKey,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TodoTextDialog(
    title: title,
    action: action,
    initial: initial,
    fieldKey: fieldKey,
    saveKey: saveKey,
  ),
);

class _TodoTextDialog extends StatefulWidget {
  const _TodoTextDialog({
    required this.title,
    required this.action,
    required this.initial,
    this.fieldKey,
    this.saveKey,
  });

  final String title;
  final String action;
  final String initial;
  final Key? fieldKey;
  final Key? saveKey;

  @override
  State<_TodoTextDialog> createState() => _TodoTextDialogState();
}

class _TodoTextDialogState extends State<_TodoTextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: widget.fieldKey,
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: widget.saveKey,
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: Text(widget.action),
      ),
    ],
  );
}

String _formatDue(String locale, String due) {
  final parsed = DateTime.tryParse(due);
  if (parsed == null) return due;
  return due.length <= 10
      ? DateFormat.yMMMd(locale).format(parsed)
      : DateFormat.yMMMd(locale).add_Hm().format(parsed.toLocal());
}

/// Home screen card: each list with its first open items.
class TodoListsCard extends ConsumerWidget {
  const TodoListsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lists = ref.watch(todoListsProvider);
    final pages = ref.watch(boardPagesProvider).value?.length;
    return Card(
      child: Column(
        children: [
          for (final l in lists.take(3)) _ListSummary(list: l),
          ListTile(
            key: const Key('openBoardCard'),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              foregroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.draw_outlined),
            ),
            title: Text(l10n.boardTitle),
            subtitle: pages == null ? null : Text(l10n.boardPageCount(pages)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              AppRoutes.boardListFor(kiosk: ref.read(kioskActiveProvider)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSummary extends ConsumerWidget {
  const _ListSummary({required this.list});

  final SmartHomeDevice list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final open =
        ref
            .watch(todoItemsProvider(list.id))
            .value
            ?.where((i) => !i.completed)
            .map((i) => i.summary)
            .toList() ??
        const <String>[];
    final count = list.state.numericValue?.toInt() ?? open.length;
    return ListTile(
      key: ValueKey('todoCard-${list.id}'),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        foregroundColor: theme.colorScheme.primary,
        child: Icon(
          list.id == 'todo.shopping_list'
              ? Icons.shopping_cart_outlined
              : Icons.checklist,
        ),
      ),
      title: Text(list.name),
      subtitle: Text(
        open.isEmpty ? l10n.todoOpenCount(count) : open.take(4).join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: count == 0
          ? null
          : Badge.count(
              count: count,
              backgroundColor: theme.colorScheme.primary,
              textColor: theme.colorScheme.onPrimary,
            ),
      onTap: () => context.push(
        AppRoutes.todoList(list.id, kiosk: ref.read(kioskActiveProvider)),
      ),
    );
  }
}
