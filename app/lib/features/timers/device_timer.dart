import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/storage/app_preferences.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/capability.dart';
import '../devices/domain/smart_home_device.dart';

/// "Turn off in 30 minutes", counted by Home Assistant so it also works
/// when this phone is off: one small script per device (`mode: restart`),
/// started with the minutes and the action as variables.
String timerScriptId(String entityId) {
  final id = 'osh_timer_${entityId.replaceAll('.', '_')}';
  // Config ids are checked to [A-Za-z0-9_]{1,64}.
  return id.length <= 64 ? id : id.substring(0, 64);
}

bool supportsTimer(SmartHomeDevice d) =>
    !d.isAuxiliary && !d.kind.isRoutine && d.supports(Capability.power);

/// The script Home Assistant runs; visible and editable in HA too.
Map<String, Object?> timerScriptConfig(SmartHomeDevice d) => {
  'alias': 'Open Smart Home – tajmer: ${d.name}',
  'description': 'Napravila aplikacija Open Smart Home (tajmer uređaja).',
  'icon': 'mdi:timer-outline',
  // A new timer replaces the running one.
  'mode': 'restart',
  'sequence': [
    {
      'delay': {'minutes': '{{ minutes | int(0) }}'},
    },
    {
      'choose': [
        {
          'conditions': "{{ service == 'turn_on' }}",
          'sequence': [
            {
              'action': 'homeassistant.turn_on',
              'target': {'entity_id': d.sourceId},
            },
          ],
        },
      ],
      'default': [
        {
          'action': 'homeassistant.turn_off',
          'target': {'entity_id': d.sourceId},
        },
      ],
    },
  ],
};

/// When the app's own timers end (per device id), to show the time; Home
/// Assistant is the source of truth for whether one runs.
@immutable
class TimerEnd {
  const TimerEnd(this.at, {required this.turnOn});
  final DateTime at;
  final bool turnOn;
}

class DeviceTimersController extends Notifier<Map<String, TimerEnd>> {
  String? get _key {
    final p = ref.read(activeProfileProvider);
    return p == null ? null : 'timers::${p.id}';
  }

  @override
  Map<String, TimerEnd> build() {
    final p = ref.watch(activeProfileProvider);
    if (p == null) return const {};
    final json = ref.watch(appPreferencesProvider).readJson('timers::${p.id}');
    final now = DateTime.now();
    return {
      for (final MapEntry(:key, :value) in (json ?? const {}).entries)
        if (value case {'at': final String at, 'on': final bool on})
          if (DateTime.tryParse(at) case final DateTime t when t.isAfter(now))
            key: TimerEnd(t, turnOn: on),
    };
  }

  Future<void> _save(Map<String, TimerEnd> timers) async {
    state = timers;
    final key = _key;
    if (key == null) return;
    await ref.read(appPreferencesProvider).writeJson(key, {
      for (final MapEntry(:key, :value) in timers.entries)
        key: {'at': value.at.toIso8601String(), 'on': value.turnOn},
    });
  }

  Future<void> start(
    SmartHomeDevice d, {
    required Duration after,
    required bool turnOn,
  }) async {
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    final id = timerScriptId(d.sourceId);
    final scriptEntity = 'script.$id';
    // Created (or brought up to date) once per device.
    final existing = ref.read(deviceProvider(scriptEntity));
    if (existing == null || existing.name != timerScriptConfig(d)['alias']) {
      await api.saveScript(id, timerScriptConfig(d));
    }
    await api.callService(
      'script',
      'turn_on',
      data: {
        'entity_id': scriptEntity,
        'variables': {
          'minutes': after.inMinutes,
          'service': turnOn ? 'turn_on' : 'turn_off',
        },
      },
    );
    await _save({
      ...state,
      d.id: TimerEnd(DateTime.now().add(after), turnOn: turnOn),
    });
  }

  Future<void> cancel(SmartHomeDevice d) async {
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    await api.callService(
      'script',
      'turn_off',
      data: {'entity_id': 'script.${timerScriptId(d.sourceId)}'},
    );
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
    final script = ref.watch(
      deviceProvider('script.${timerScriptId(device.sourceId)}'),
    );
    final running = script?.state.raw == 'on';
    final end = ref.watch(deviceTimersProvider)[device.id];
    final messenger = ScaffoldMessenger.of(context);

    Future<void> guard(Future<void> Function() action) async {
      try {
        await action();
      } on AppFailure catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              // Home Assistant answers 401 to non-admins on config APIs.
              e.kind == FailureKind.authorization ||
                      e.kind == FailureKind.authentication
                  ? l10n.timerNeedsAdmin
                  : failureMessage(l10n, e),
            ),
          ),
        );
      }
    }

    if (running) {
      final when = end == null
          ? l10n.timerRunning
          : (end.turnOn ? l10n.timerTurnsOnAt : l10n.timerTurnsOffAt)(
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
