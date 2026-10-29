import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/storage/app_preferences.dart';
import '../devices/domain/capability.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/smart_home_device.dart';
import '../extras/send_command.dart';

bool supportsTimer(SmartHomeDevice d) =>
    !d.isAuxiliary && !d.kind.isRoutine && d.supports(Capability.power);

/// When a device's timer ends, and what it does then.
@immutable
class TimerEnd {
  const TimerEnd(this.at, {required this.turnOn});
  final DateTime at;
  final bool turnOn;
}

/// "Turn off in 30 minutes", counted on this phone or wall panel (it has
/// to keep running; with automations in the background it does). A
/// timer whose time passed while the app was not running is dropped.
class DeviceTimersController extends Notifier<Map<String, TimerEnd>> {
  static const _key = 'timers';
  final Map<String, Timer> _timers = {};

  @override
  Map<String, TimerEnd> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
    });
    final json = ref.watch(appPreferencesProvider).readJson(_key);
    final now = DateTime.now();
    final timers = {
      for (final MapEntry(:key, :value) in (json ?? const {}).entries)
        if (value case {'at': final String at, 'on': final bool on})
          if (DateTime.tryParse(at) case final DateTime t when t.isAfter(now))
            key: TimerEnd(t, turnOn: on),
    };
    timers.forEach(_arm);
    return timers;
  }

  void _arm(String deviceId, TimerEnd end) {
    _timers.remove(deviceId)?.cancel();
    _timers[deviceId] = Timer(end.at.difference(DateTime.now()), () async {
      _timers.remove(deviceId);
      await commandSender(ref)(
        deviceId,
        end.turnOn ? const TurnOn() : const TurnOff(),
      );
      if (ref.mounted) await _save({...state}..remove(deviceId));
    });
  }

  Future<void> _save(Map<String, TimerEnd> timers) async {
    state = timers;
    await ref.read(appPreferencesProvider).writeJson(_key, {
      for (final MapEntry(:key, :value) in timers.entries)
        key: {'at': value.at.toIso8601String(), 'on': value.turnOn},
    });
  }

  /// A new timer replaces the device's running one.
  Future<void> start(
    SmartHomeDevice d, {
    required Duration after,
    required bool turnOn,
  }) async {
    final end = TimerEnd(DateTime.now().add(after), turnOn: turnOn);
    _arm(d.id, end);
    await _save({...state, d.id: end});
  }

  Future<void> cancel(SmartHomeDevice d) async {
    _timers.remove(d.id)?.cancel();
    await _save({...state}..remove(d.id));
  }
}

final deviceTimersProvider =
    NotifierProvider<DeviceTimersController, Map<String, TimerEnd>>(
      DeviceTimersController.new,
    );

/// Timer row on a device's screen.
class DeviceTimerSection extends ConsumerWidget {
  const DeviceTimerSection({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final end = ref.watch(deviceTimersProvider)[device.id];
    Future<void> guard(Future<void> Function() action) => action();

    if (end != null) {
      final when = (end.turnOn ? l10n.timerTurnsOnAt : l10n.timerTurnsOffAt)(
        TimeOfDay.fromDateTime(end.at).format(context),
      );
      return Card(
        child: ListTile(
          key: const Key('deviceTimerRunning'),
          leading: const Icon(Icons.timer_outlined),
          title: Text(when),
          trailing: TextButton(
            key: const Key('deviceTimerCancel'),
            onPressed: () => guard(
              () => ref.read(deviceTimersProvider.notifier).cancel(device),
            ),
            child: Text(l10n.cancel),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const Key('deviceTimer'),
        icon: const Icon(Icons.timer_outlined),
        label: Text(l10n.timerSet),
        onPressed: () async {
          final choice = await showModalBottomSheet<(Duration, bool)>(
            useRootNavigator: true,
            context: context,
            builder: (_) => _TimerSheet(isOn: device.state.isOn == true),
          );
          if (choice == null) return;
          await guard(
            () => ref
                .read(deviceTimersProvider.notifier)
                .start(device, after: choice.$1, turnOn: choice.$2),
          );
        },
      ),
    );
  }
}

class _TimerSheet extends StatefulWidget {
  const _TimerSheet({required this.isOn});

  final bool isOn;

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  // Usually: on now → off later, and the other way round.
  late bool _turnOn = !widget.isOn;

  static const _options = [5, 15, 30, 60, 120, 240];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.timerSet, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.power_settings_new),
                  label: Text(l10n.timerTurnOff),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.power),
                  label: Text(l10n.timerTurnOn),
                ),
              ],
              selected: {_turnOn},
              onSelectionChanged: (s) => setState(() => _turnOn = s.first),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _options)
                  ActionChip(
                    key: ValueKey('timer-$m'),
                    label: Text(
                      m < 60
                          ? l10n.durationMinutes(m)
                          : l10n.timerHours(m ~/ 60),
                    ),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop((Duration(minutes: m), _turnOn)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.timerHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
