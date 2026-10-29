import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../household/application/household_providers.dart';
import '../../household/presentation/person_avatar.dart';
import '../application/kiosk_people.dart';
import 'pin_dialog.dart';

/// Household members on the wall panel: who gets a personal PIN for
/// critical actions (unlock, disarm). Members are Home Assistant's people.
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
    if (people.isEmpty) return const SizedBox.shrink();
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
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
