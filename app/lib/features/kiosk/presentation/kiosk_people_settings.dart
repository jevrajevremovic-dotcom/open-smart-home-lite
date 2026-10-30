import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/data/local/local_home.dart';
import '../../household/application/household_providers.dart';
import '../../household/presentation/person_avatar.dart';
import '../application/kiosk_people.dart';
import 'pin_dialog.dart';

/// Household members on the wall panel: added here, each with a personal
/// PIN for critical actions (unlock, disarm), a birthday, quick controls.
class KioskPeopleSettings extends ConsumerWidget {
  const KioskPeopleSettings({super.key});

  /// The year is only for the picker; it is not kept.
  Future<void> _pickBirthday(
    BuildContext context,
    WidgetRef ref,
    String personId,
    (int, int)? current,
  ) async {
    final controller = ref.read(kioskPeopleProvider.notifier);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: context.l10n.birthdayPick,
      initialDate: current == null
          ? now
          : DateTime(now.year, current.$1, current.$2),
      firstDate: DateTime(now.year),
      lastDate: DateTime(now.year, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      await controller.setBirthday(personId, (picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final people = ref.watch(peopleIdsProvider);
    final settings = ref.watch(kioskPeopleProvider);
    final controller = ref.read(kioskPeopleProvider.notifier);
    // Without any PIN, anyone may unlock (after a confirmation).
    final pinRequired = ref.watch(kioskCriticalPinRequiredProvider);
    return Column(
      key: const Key('kioskPeopleSettings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(l10n.kioskPeopleTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.kioskPeopleHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final id in people)
          Builder(
            builder: (context) {
              final name = ref.watch(
                deviceProvider(id).select((d) => d?.name ?? id),
              );
              final hasPin = settings[id]?.hasPin ?? false;
              final birthday = settings[id]?.birthday;
              final local = MaterialLocalizations.of(context);
              return ListTile(
                key: ValueKey('kioskPersonSettings-$id'),
                contentPadding: EdgeInsets.zero,
                leading: PersonAvatar(personId: id, size: 36),
                title: Text(name),
                subtitle: Text(
                  [
                    if (birthday case (final m, final d))
                      '🎂 ${local.formatShortMonthDay(DateTime(2000, m, d))}',
                    if (hasPin)
                      l10n.kioskPersonPinSet
                    else if (pinRequired)
                      l10n.kioskPersonNoPinLocked
                    else
                      l10n.kioskPersonNoPin,
                  ].join(' · '),
                ),
                onTap: () => _pickBirthday(context, ref, id, birthday),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      key: ValueKey('kioskPersonSetPin-$id'),
                      onPressed: () => showSetPinDialog(
                        context,
                        ref,
                        title: l10n.kioskPersonSetPin(name),
                        save: (pin) => controller.setPin(id, pin),
                      ),
                      child: Text(
                        hasPin ? l10n.kioskChangePin : l10n.kioskSetPin,
                      ),
                    ),
                    if (hasPin)
                      TextButton(
                        key: ValueKey('kioskPersonRemovePin-$id'),
                        onPressed: () => controller.removePin(id),
                        child: Text(l10n.kioskRemovePin),
                      ),
                    if (id.startsWith('member:'))
                      IconButton(
                        key: ValueKey('householdRemove-$id'),
                        tooltip: l10n.householdRemove,
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: () => ref
                            .read(localHomeProvider.notifier)
                            .removeMember(id.substring('member:'.length)),
                      ),
                  ],
                ),
              );
            },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('householdAdd'),
            onPressed: () async {
              final name = await showDialog<String>(
                context: context,
                builder: (_) => const _MemberDialog(),
              );
              if (name != null && name.trim().isNotEmpty) {
                await ref.read(localHomeProvider.notifier).addMember(name);
              }
            },
            icon: const Icon(Icons.person_add_alt),
            label: Text(l10n.householdAdd),
          ),
        ),
      ],
    );
  }
}

class _MemberDialog extends StatefulWidget {
  const _MemberDialog();

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void done() => Navigator.of(context).pop(_name.text);
    return AlertDialog(
      title: Text(l10n.householdAdd),
      content: TextField(
        key: const Key('householdName'),
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.householdName),
        onSubmitted: (_) => done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('householdNameOk'),
          onPressed: done,
          child: Text(l10n.householdAdd),
        ),
      ],
    );
  }
}
