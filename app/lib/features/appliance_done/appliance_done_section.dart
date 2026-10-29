import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_groups.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/smart_home_device.dart';
import '../ha_notify/ha_push.dart';
import 'appliance_done.dart';

/// "Tell me when it's done" on the screen of an appliance with a power
/// sensor (or of its smart plug).
class ApplianceDoneSection extends ConsumerStatefulWidget {
  const ApplianceDoneSection({super.key, required this.power});

  /// The appliance's power sensor.
  final SmartHomeDevice power;

  @override
  ConsumerState<ApplianceDoneSection> createState() =>
      _ApplianceDoneSectionState();
}

class _ApplianceDoneSectionState extends ConsumerState<ApplianceDoneSection> {
  bool _busy = false;

  void _say(ScaffoldMessengerState messenger, String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String _failure(AppLocalizations l10n, AppFailure e) =>
      e.kind == FailureKind.authorization ||
          e.kind == FailureKind.authentication
      ? l10n.applianceDoneNeedsAdmin
      : failureMessage(l10n, e);

  /// The device's name without "power" ("Veš mašina").
  String _defaultName() {
    final power = widget.power;
    final physical = power.deviceId;
    if (physical == null) return power.name;
    final members = [
      for (final d in ref.read(homeSnapshotProvider).devices.values)
        if (d.deviceId == physical) d,
    ];
    return members.length > 1 ? DeviceBundle(members).name : power.name;
  }

  Future<void> _edit(bool isSet) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    final power = widget.power;
    setState(() => _busy = true);
    ApplianceDone? current;
    try {
      if (isSet) {
        current = ApplianceDone.fromAutomation(
          await api.fetchAutomation(applianceDoneId(power.id)),
        );
      }
    } on AppFailure catch (e) {
      _say(messenger, _failure(l10n, e));
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final phone = ref.read(haPushProvider).value?.notifyService;
    final start =
        current ??
        ApplianceDone(
          powerId: power.id,
          name: _defaultName(),
          notify: [?phone],
        );
    final result = await showDialog<_Result>(
      context: context,
      builder: (_) => _ApplianceDoneDialog(
        initial: start,
        phone: phone,
        watts: power.state.numericValue,
        isSet: isSet,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (result.remove) {
        await api.deleteAutomation(applianceDoneId(power.id));
        _say(messenger, l10n.applianceDoneRemoved);
      } else {
        final config = result.config!;
        await api.saveAutomation(config.id, config.automation(l10n));
        _say(messenger, l10n.applianceDoneSaved(config.name));
      }
    } on AppFailure catch (e) {
      _say(messenger, _failure(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSet = ref.watch(applianceDoneSetProvider(widget.power.id));
    if (isSet) {
      return Card(
        child: ListTile(
          key: const Key('applianceDoneSet'),
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(l10n.applianceDoneOn),
          subtitle: Text(l10n.applianceDoneOnHint),
          trailing: TextButton(
            key: const Key('applianceDoneEdit'),
            onPressed: _busy ? null : () => _edit(true),
            child: Text(l10n.applianceDoneChange),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const Key('applianceDone'),
        icon: const Icon(Icons.notifications_none_rounded),
        label: Text(l10n.applianceDoneAction),
        onPressed: _busy ? null : () => _edit(false),
      ),
    );
  }
}

class _Result {
  const _Result.save(ApplianceDone this.config) : remove = false;
  const _Result.remove() : config = null, remove = true;

  final ApplianceDone? config;
  final bool remove;
}

class _ApplianceDoneDialog extends StatefulWidget {
  const _ApplianceDoneDialog({
    required this.initial,
    required this.phone,
    required this.watts,
    required this.isSet,
  });

  final ApplianceDone initial;

  /// This phone's notify service, when it is registered with Home Assistant.
  final String? phone;
  final double? watts;
  final bool isSet;

  @override
  State<_ApplianceDoneDialog> createState() => _ApplianceDoneDialogState();
}

class _ApplianceDoneDialogState extends State<_ApplianceDoneDialog> {
  static const _thresholds = [2, 5, 10, 20, 50];
  static const _minutes = [1, 3, 5, 10];

  late final _name = TextEditingController(text: widget.initial.name);
  late ApplianceDone _config = widget.initial;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final phone = widget.phone;
    final watts = widget.watts;
    final config = _config.copyWith(name: _name.text.trim());
    final valid = config.name.isNotEmpty && config.hasRecipient;
    return AlertDialog(
      icon: const Icon(Icons.local_laundry_service_outlined),
      title: Text(l10n.applianceDoneAction),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.applianceDoneHint, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                key: const Key('applianceDoneName'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.applianceDoneName),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('applianceDoneThreshold'),
                      initialValue: _thresholds.contains(_config.thresholdWatts)
                          ? _config.thresholdWatts
                          : 5,
                      decoration: InputDecoration(
                        labelText: l10n.applianceDoneThreshold,
                      ),
                      items: [
                        for (final w in _thresholds)
                          DropdownMenuItem(value: w, child: Text('$w W')),
                      ],
                      onChanged: (v) => setState(
                        () => _config = _config.copyWith(thresholdWatts: v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('applianceDoneMinutes'),
                      initialValue: _minutes.contains(_config.doneMinutes)
                          ? _config.doneMinutes
                          : 3,
                      decoration: InputDecoration(
                        labelText: l10n.applianceDoneQuiet,
                      ),
                      items: [
                        for (final m in _minutes)
                          DropdownMenuItem(
                            value: m,
                            child: Text(l10n.applianceDoneMinutesValue(m)),
                          ),
                      ],
                      onChanged: (v) => setState(
                        () => _config = _config.copyWith(doneMinutes: v),
                      ),
                    ),
                  ),
                ],
              ),
              if (watts != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.applianceDoneNow(
                      NumberFormat.decimalPattern(l10n.localeName)
                          .format(watts.round()),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const Key('applianceDonePhone'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.applianceDoneThisPhone),
                subtitle: phone == null
                    ? Text(l10n.applianceDoneNeedsPush)
                    : null,
                value: phone != null && _config.notify.contains(phone),
                onChanged: phone == null
                    ? null
                    : (v) => setState(
                        () => _config = _config.copyWith(
                          notify: [
                            for (final s in _config.notify)
                              if (s != phone) s,
                            if (v == true) phone,
                          ],
                        ),
                      ),
              ),
              CheckboxListTile(
                key: const Key('applianceDoneHousehold'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.applianceDoneHousehold),
                subtitle: Text(l10n.applianceDoneHouseholdHint),
                value: _config.household,
                onChanged: (v) => setState(
                  () => _config = _config.copyWith(household: v == true),
                ),
              ),
              if (_config.notify.any((s) => s != phone))
                Text(
                  l10n.applianceDoneOtherPhones(
                    _config.notify.where((s) => s != phone).length,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.isSet)
          TextButton(
            key: const Key('applianceDoneRemove'),
            onPressed: () => Navigator.of(context).pop(const _Result.remove()),
            child: Text(l10n.applianceDoneRemove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('applianceDoneSave'),
          onPressed: valid
              ? () => Navigator.of(context).pop(_Result.save(config))
              : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
