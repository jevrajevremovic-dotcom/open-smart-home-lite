import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/widgets/time_picker.dart';
import '../authentication/application/session_controller.dart';
import '../automations/domain/simple_automation.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';
import '../devices/presentation/device_actions.dart';
import 'presence_simulation.dart';

/// Sets up the presence simulation automation in Home Assistant.
class PresenceSimScreen extends ConsumerStatefulWidget {
  const PresenceSimScreen({super.key});

  @override
  ConsumerState<PresenceSimScreen> createState() => _PresenceSimScreenState();
}

class _PresenceSimScreenState extends ConsumerState<PresenceSimScreen> {
  PresenceSimulation _sim = const PresenceSimulation(lights: []);
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// The saved automation's settings, if there is one.
  Future<void> _load() async {
    final api = ref.read(homeAssistantApiProvider);
    PresenceSimulation? saved;
    try {
      final config = await api?.fetchAutomation(presenceSimId);
      if (config != null) saved = PresenceSimulation.fromAutomation(config);
    } on AppFailure {
      // Not saved yet (404), or not readable: start from defaults.
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (saved != null) _sim = saved;
    });
  }

  SmartHomeDevice? _entity(Map<String, SmartHomeDevice> devices) => devices
      .values
      .where((d) => d.metadata.configId == presenceSimId)
      .firstOrNull;

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(homeAssistantApiProvider);
    if (api == null || !_sim.valid) return;
    setState(() => _busy = true);
    try {
      await api.saveAutomation(
        presenceSimId,
        _sim.toAutomation(
          alias: l10n.presenceTitle,
          description: 'Open Smart Home: ${l10n.presenceHint}',
        ),
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.presenceSaved)));
    } on AppFailure catch (e) {
      _fail(messenger, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    setState(() => _busy = true);
    try {
      await api.deleteAutomation(presenceSimId);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.presenceRemoved)));
    } on AppFailure catch (e) {
      _fail(messenger, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(ScaffoldMessengerState messenger, AppFailure e) {
    final l10n = context.l10n;
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
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _sim.start : _sim.end;
    final picked = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    final time = ClockTime(picked.hour, picked.minute);
    setState(
      () =>
          _sim = start ? _sim.copyWith(start: time) : _sim.copyWith(end: time),
    );
  }

  String _hm(ClockTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final lights = devices.values.where((d) => d.kind.isLight).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final alarms =
        devices.values.where((d) => d.kind == DeviceKind.alarm).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final entity = _entity(devices);
    final sim = _sim;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.presenceTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(l10n.presenceIntro, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                if (entity == null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: Text(l10n.presenceNotSaved),
                  )
                else
                  SwitchListTile(
                    key: const Key('presenceOn'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.nights_stay_outlined),
                    title: Text(l10n.presenceOn),
                    value: entity.state.isOn ?? false,
                    onChanged: (v) => runDeviceCommand(
                      context,
                      ref,
                      entity,
                      v ? const TurnOn() : const TurnOff(),
                    ),
                  ),
                const Divider(height: 24),
                Text(l10n.presenceLights, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (lights.isEmpty)
                  Text(l10n.presenceNoLights)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in lights)
                        FilterChip(
                          key: ValueKey('presenceLight-${d.id}'),
                          label: Text(d.name),
                          selected: sim.lights.contains(d.id),
                          onSelected: (on) => setState(
                            () => _sim = _sim.copyWith(
                              lights: on
                                  ? [..._sim.lights, d.id]
                                  : [
                                      for (final l in _sim.lights)
                                        if (l != d.id) l,
                                    ],
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(l10n.presenceWhen, style: theme.textTheme.titleMedium),
                RadioGroup<PresenceWhen>(
                  groupValue: sim.when,
                  onChanged: (w) => w == null
                      ? null
                      : setState(
                          () => _sim = _sim.copyWith(
                            when: w,
                            alarmId: w == PresenceWhen.alarm
                                ? (_sim.alarmId ?? alarms.firstOrNull?.id)
                                : null,
                          ),
                        ),
                  child: Column(
                    children: [
                      RadioListTile(
                        key: const Key('presenceAway'),
                        contentPadding: EdgeInsets.zero,
                        value: PresenceWhen.away,
                        title: Text(l10n.presenceWhenAway),
                        subtitle: Text(l10n.presenceWhenAwayHint),
                      ),
                      if (alarms.isNotEmpty)
                        RadioListTile(
                          key: const Key('presenceAlarm'),
                          contentPadding: EdgeInsets.zero,
                          value: PresenceWhen.alarm,
                          title: Text(l10n.presenceWhenAlarm),
                          subtitle: alarms.length > 1 && sim.alarmId != null
                              ? Text(
                                  alarms
                                      .firstWhere(
                                        (a) => a.id == sim.alarmId,
                                        orElse: () => alarms.first,
                                      )
                                      .name,
                                )
                              : null,
                        ),
                      RadioListTile(
                        key: const Key('presenceAlways'),
                        contentPadding: EdgeInsets.zero,
                        value: PresenceWhen.always,
                        title: Text(l10n.presenceWhenAlways),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  key: const Key('presenceFromSunset'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.wb_twilight_outlined),
                  title: Text(l10n.presenceFromSunset),
                  value: sim.fromSunset,
                  onChanged: (v) =>
                      setState(() => _sim = _sim.copyWith(fromSunset: v)),
                ),
                if (!sim.fromSunset)
                  ListTile(
                    key: const Key('presenceStart'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(l10n.presenceStart),
                    trailing: Text(
                      _hm(sim.start),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: () => _pickTime(true),
                  ),
                ListTile(
                  key: const Key('presenceEnd'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text(l10n.presenceEnd),
                  trailing: Text(
                    _hm(sim.end),
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: () => _pickTime(false),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('presenceSave'),
                  onPressed: _busy || !sim.valid ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.presenceSave),
                ),
                if (entity != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('presenceRemove'),
                    onPressed: _busy ? null : _remove,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.presenceRemove),
                  ),
                ],
              ],
            ),
    );
  }
}
