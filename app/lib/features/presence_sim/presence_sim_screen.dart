import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/widgets/time_picker.dart';
import '../automations/domain/routines.dart';
import '../devices/application/device_providers.dart';
import 'presence_simulation.dart';

/// Sets up the presence simulation (runs on this phone or wall panel).
class PresenceSimScreen extends ConsumerStatefulWidget {
  const PresenceSimScreen({super.key});

  @override
  ConsumerState<PresenceSimScreen> createState() => _PresenceSimScreenState();
}

class _PresenceSimScreenState extends ConsumerState<PresenceSimScreen> {
  late PresenceSimulation _sim = ref.read(presenceSimProvider);

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!_sim.valid) return;
    await ref.read(presenceSimProvider.notifier).save(_sim);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.presenceSaved)));
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
    final sim = _sim;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.presenceTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.presenceIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('presenceOn'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.nights_stay_outlined),
            title: Text(l10n.presenceOn),
            value: sim.enabled,
            onChanged: (v) => setState(() => _sim = _sim.copyWith(enabled: v)),
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
            trailing: Text(_hm(sim.end), style: theme.textTheme.titleMedium),
            onTap: () => _pickTime(false),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('presenceSave'),
            onPressed: sim.valid ? _save : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.presenceSave),
          ),
        ],
      ),
    );
  }
}
