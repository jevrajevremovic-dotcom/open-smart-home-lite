import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../notifications/application/notifications_provider.dart';
import 'application/household_providers.dart';
import 'presentation/person_avatar.dart';

/// Messages for the household, kept in Home Assistant as persistent
/// notifications (`osh_msg_<who>_<millis>`), so every phone and wall tablet
/// sees them — and Home Assistant itself shows them too. "Read" dismisses
/// the notification.
@immutable
class FamilyMessage {
  const FamilyMessage({
    required this.id,
    required this.to,
    required this.text,
    this.createdAt,
  });

  static const prefix = 'osh_msg_';
  static const everyone = 'all';

  final String id;

  /// Person entity id without `person.`, or [everyone].
  final String to;
  final String text;
  final DateTime? createdAt;

  bool isFor(String personId) => to == everyone || 'person.$to' == personId;

  static FamilyMessage? from(HaNotification n) {
    if (!n.id.startsWith(prefix)) return null;
    final rest = n.id.substring(prefix.length);
    final cut = rest.lastIndexOf('_');
    if (cut <= 0) return null;
    return FamilyMessage(
      id: n.id,
      to: rest.substring(0, cut),
      text: n.plainMessage,
      createdAt: n.createdAt,
    );
  }
}

/// Household messages, newest first.
final familyMessagesProvider = Provider<List<FamilyMessage>>(
  (ref) => [
    for (final n
        in ref.watch(haNotificationsProvider).value ?? const <HaNotification>[])
      ?FamilyMessage.from(n),
  ],
);

/// Leaves [text] for [personId] (`null` = everyone).
Future<void> sendFamilyMessage(
  WidgetRef ref,
  AppLocalizations l10n, {
  required String? personId,
  required String text,
}) async {
  final api = ref.read(homeAssistantApiProvider);
  if (api == null) {
    throw const AppFailure(FailureKind.network, debugMessage: 'no server');
  }
  final to = personId == null
      ? FamilyMessage.everyone
      : personId.substring('person.'.length);
  final name = personId == null
      ? null
      : ref.read(deviceProvider(personId))?.name;
  await api.callService(
    'persistent_notification',
    'create',
    data: {
      'notification_id':
          '${FamilyMessage.prefix}${to}_${DateTime.now().millisecondsSinceEpoch}',
      'title': name == null
          ? l10n.familyMessageForAll
          : l10n.familyMessageFor(name),
      'message': text,
    },
  );
}

Future<void> markFamilyMessageRead(WidgetRef ref, String id) async {
  await ref
      .read(homeAssistantApiProvider)
      ?.callService(
        'persistent_notification',
        'dismiss',
        data: {'notification_id': id},
      );
}

/// The household's messages, with "read" and a new message.
Future<void> showFamilyMessages(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _MessagesDialog());

class _MessagesDialog extends ConsumerWidget {
  const _MessagesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final messages = ref.watch(familyMessagesProvider);
    return AlertDialog(
      key: const Key('familyMessages'),
      icon: const Icon(Icons.forum_outlined),
      title: Text(l10n.familyMessages),
      content: SizedBox(
        width: 520,
        child: messages.isEmpty
            ? Text(l10n.familyMessagesNone)
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final m in messages)
                    FamilyMessageTile(key: ValueKey(m.id), message: m),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        FilledButton.icon(
          key: const Key('familyMessageNew'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _ComposeDialog(),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.familyMessageNew),
          style: FilledButton.styleFrom(textStyle: theme.textTheme.labelLarge),
        ),
      ],
    );
  }
}

/// One message: for whom, the text, when; "read" removes it everywhere.
class FamilyMessageTile extends ConsumerWidget {
  const FamilyMessageTile({
    super.key,
    required this.message,
    this.dark = false,
  });

  final FamilyMessage message;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final personId = message.to == FamilyMessage.everyone
        ? null
        : 'person.${message.to}';
    final name = personId == null
        ? l10n.familyMessageEveryone
        : ref.watch(deviceProvider(personId))?.name ?? message.to;
    final when = message.createdAt == null
        ? ''
        : ' · ${DateFormat.MMMd(l10n.localeName).add_Hm().format(message.createdAt!)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: personId == null
          ? const CircleAvatar(child: Icon(Icons.groups_outlined))
          : PersonAvatar(personId: personId, size: 40),
      title: Text(message.text),
      subtitle: Text('$name$when'),
      trailing: IconButton(
        key: ValueKey('familyMessageRead-${message.id}'),
        tooltip: l10n.familyMessageRead,
        icon: const Icon(Icons.done_rounded),
        onPressed: () => markFamilyMessageRead(ref, message.id),
      ),
    );
  }
}

class _ComposeDialog extends ConsumerStatefulWidget {
  const _ComposeDialog();

  @override
  ConsumerState<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends ConsumerState<_ComposeDialog> {
  final _text = TextEditingController();
  String? _to;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = context.l10n;
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await sendFamilyMessage(ref, l10n, personId: _to, text: text);
      navigator.pop();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger?.showSnackBar(SnackBar(content: Text(failureMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final people = ref.watch(peopleIdsProvider);
    return AlertDialog(
      title: Text(l10n.familyMessageNew),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('familyTo-all'),
                  label: Text(l10n.familyMessageEveryone),
                  selected: _to == null,
                  onSelected: (_) => setState(() => _to = null),
                ),
                for (final id in people)
                  ChoiceChip(
                    key: ValueKey('familyTo-$id'),
                    label: Text(ref.watch(deviceProvider(id))?.name ?? id),
                    selected: _to == id,
                    onSelected: (_) => setState(() => _to = id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('familyMessageText'),
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: 300,
              decoration: InputDecoration(hintText: l10n.familyMessageHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('familyMessageSend'),
          onPressed: _busy ? null : _send,
          child: Text(l10n.familyMessageSend),
        ),
      ],
    );
  }
}
