import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../ha_notify/ha_push.dart';
import '../application/energy_providers.dart';
import '../application/low_tariff_reminder.dart';

/// Whether this phone's lower-rate reminder automation exists in Home
/// Assistant (its entity carries the config id).
final lowTariffReminderSetProvider = Provider<bool>((ref) {
  final registration = ref.watch(haPushProvider).value;
  if (registration == null) return false;
  final id = lowTariffReminderId(registration);
  return ref.watch(
    homeSnapshotProvider.select(
      (s) => s.devices.values.any((d) => d.metadata.configId == id),
    ),
  );
});

/// Saves (or replaces) the reminder for the current tariff. Throws
/// [AppFailure] (e.g. not an administrator).
Future<void> saveLowTariffReminder(WidgetRef ref, AppLocalizations l10n) async {
  final api = ref.read(homeAssistantApiProvider);
  final registration = ref.read(haPushProvider).value;
  final tariff = ref.read(tariffProvider);
  final low = tariff?.low;
  if (api == null || registration == null || tariff == null || low == null) {
    return;
  }
  await api.saveAutomation(
    lowTariffReminderId(registration),
    lowTariffAutomation(
      l10n: l10n,
      registration: registration,
      low: low,
      currency: tariff.currency,
    ),
  );
}

/// Bell next to "lower rate until …": turns the reminder on or off.
class LowTariffReminderButton extends ConsumerStatefulWidget {
  const LowTariffReminderButton({super.key, required this.startsAt});

  /// Start of the low rate, for the explanation ("23:00").
  final String startsAt;

  @override
  ConsumerState<LowTariffReminderButton> createState() =>
      _LowTariffReminderButtonState();
}

class _LowTariffReminderButtonState
    extends ConsumerState<LowTariffReminderButton> {
  bool _busy = false;

  Future<void> _tap(bool isSet) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final registration = ref.read(haPushProvider).value;
    if (registration == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.lowTariffNeedsPush)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: Text(l10n.lowTariffRemind),
        content: Text(l10n.lowTariffDialogBody(widget.startsAt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('lowTariffConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isSet ? l10n.lowTariffRemove : l10n.lowTariffCreate),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (isSet) {
        await ref
            .read(homeAssistantApiProvider)
            ?.deleteAutomation(lowTariffReminderId(registration));
      } else {
        await saveLowTariffReminder(ref, l10n);
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isSet ? l10n.lowTariffRemoved : l10n.lowTariffCreated,
            ),
          ),
        );
    } on AppFailure catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.kind == FailureKind.authorization
                  ? l10n.presenceNeedsAdmin
                  : failureMessage(l10n, e),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSet = ref.watch(lowTariffReminderSetProvider);
    return IconButton(
      key: const Key('lowTariffReminder'),
      tooltip: isSet ? l10n.lowTariffRemindOn : l10n.lowTariffRemind,
      isSelected: isSet,
      onPressed: _busy ? null : () => _tap(isSet),
      icon: const Icon(Icons.notifications_none_rounded),
      selectedIcon: const Icon(Icons.notifications_active),
    );
  }
}
