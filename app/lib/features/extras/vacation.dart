import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_preferences.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';
import '../devices/presentation/controls/alarm_controls.dart';
import '../devices/presentation/device_actions.dart';
import '../house_check/house_check.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../kiosk/presentation/kiosk_alarm.dart';
import '../presence_sim/presence_simulation.dart';

final _log = AppLogger('Vacation');

/// "We're away": what was started on this device, to undo on return.
@immutable
class VacationState {
  const VacationState({
    this.since,
    this.temperatures = const {},
    this.simulationWasOff = false,
  });

  factory VacationState.fromJson(Map<String, Object?>? json) => VacationState(
    since: DateTime.tryParse('${json?['since']}'),
    temperatures: {
      if (json?['temperatures'] case final Map<Object?, Object?> m)
        for (final e in m.entries)
          if (e.value case final num v) '${e.key}': v.toDouble(),
    },
    simulationWasOff: json?['simulationWasOff'] == true,
  );

  /// `null`: not on vacation.
  final DateTime? since;

  /// Each thermostat's target before, to put back.
  final Map<String, double> temperatures;

  /// The presence simulation was off before (turned off again on return).
  final bool simulationWasOff;

  bool get active => since != null;

  Map<String, Object?> toJson() => {
    'since': since?.toIso8601String(),
    'temperatures': temperatures,
    'simulationWasOff': simulationWasOff,
  };
}

/// Thermostats that take a target temperature.
List<SmartHomeDevice> vacationThermostats(Iterable<SmartHomeDevice> devices) =>
    [
      for (final d in devices)
        if (!d.isAuxiliary &&
            d.available &&
            (d.kind == DeviceKind.climate || d.kind == DeviceKind.thermostat) &&
            d.state.targetTemperature != null)
          d,
    ]..sort((a, b) => a.name.compareTo(b.name));

/// The presence simulation's automation, when it is set up.
final presenceSimEntityProvider = Provider<SmartHomeDevice?>(
  (ref) => ref.watch(
    homeSnapshotProvider.select(
      (s) => s.devices.values
          .where((d) => d.metadata.configId == presenceSimId)
          .firstOrNull,
    ),
  ),
);

class VacationController extends Notifier<VacationState> {
  static const _key = 'vacation';

  @override
  VacationState build() =>
      VacationState.fromJson(ref.watch(appPreferencesProvider).readJson(_key));

  Future<void> _save(VacationState s) async {
    state = s;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, s.active ? s.toJson() : null);
  }

  /// Turns the heating down to [temperature] and the presence simulation
  /// on, remembering what to undo.
  Future<void> start({
    required double? temperature,
    required bool simulation,
  }) async {
    final api = ref.read(homeAssistantApiProvider);
    final devices = ref.read(homeSnapshotProvider).devices.values;
    final temperatures = <String, double>{};
    if (temperature != null && api != null) {
      for (final d in vacationThermostats(devices)) {
        temperatures[d.id] = d.state.targetTemperature!;
        await _call('climate', 'set_temperature', {
          'entity_id': d.id,
          'temperature': temperature,
        });
      }
    }
    final sim = ref.read(presenceSimEntityProvider);
    final simWasOff = sim != null && sim.state.isOn != true;
    if (simulation && simWasOff) {
      await _call('automation', 'turn_on', {'entity_id': sim.id});
    }
    await _save(
      VacationState(
        since: DateTime.now(),
        temperatures: temperatures,
        simulationWasOff: simulation && simWasOff,
      ),
    );
  }

  /// Back home: the temperatures as they were, the simulation off again
  /// if it was off. The alarm is left to the household (it needs a code).
  Future<void> end() async {
    final s = state;
    for (final e in s.temperatures.entries) {
      await _call('climate', 'set_temperature', {
        'entity_id': e.key,
        'temperature': e.value,
      });
    }
    final sim = ref.read(presenceSimEntityProvider);
    if (s.simulationWasOff && sim != null) {
      await _call('automation', 'turn_off', {'entity_id': sim.id});
    }
    await _save(const VacationState());
  }

  /// One service call; one device that fails must not stop the rest.
  Future<void> _call(
    String domain,
    String service,
    Map<String, Object?> data,
  ) async {
    try {
      await ref
          .read(homeAssistantApiProvider)
          ?.callService(domain, service, data: data);
    } on Object catch (e) {
      _log.warning('$domain.$service failed', e.runtimeType);
    }
  }
}

final vacationProvider = NotifierProvider<VacationController, VacationState>(
  VacationController.new,
);

Future<void> showVacation(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const _VacationSheet(),
);

class _VacationSheet extends ConsumerStatefulWidget {
  const _VacationSheet();

  @override
  ConsumerState<_VacationSheet> createState() => _VacationSheetState();
}

class _VacationSheetState extends ConsumerState<_VacationSheet> {
  bool _tidy = true;
  bool _heating = true;
  double _temperature = 16;
  bool _simulation = true;
  bool _alarm = true;
  bool _busy = false;

  Future<void> _start() async {
    // Read now: the sheet may be closed while the house is tidied.
    final vacation = ref.read(vacationProvider.notifier);
    setState(() => _busy = true);
    // Lights, music, covers… as "Leaving" would (heating is lowered below).
    if (_tidy) {
      for (final item in ref.read(houseCheckProvider(HouseCheckMode.leaving))) {
        final fix = item.fix;
        if (fix == null || item.problem == HouseCheckProblem.climateOn) {
          continue;
        }
        if (!mounted) break;
        await runDeviceCommand(context, ref, item.device, fix);
      }
    }
    await vacation.start(
      temperature: _heating ? _temperature : null,
      simulation: _simulation,
    );
    if (!mounted) return;
    final alarm = ref.read(kioskAlarmProvider);
    if (_alarm &&
        alarm != null &&
        mounted &&
        alarm.state.alarmState == AlarmState.disarmed &&
        alarm.limits.alarmArmModes.contains('away')) {
      final needsCode =
          alarm.limits.alarmCodeFormat != null &&
          alarm.limits.alarmCodeArmRequired;
      final code = needsCode
          ? await showAlarmCodeDialog(context, alarm.limits.alarmCodeFormat!)
          : null;
      if (mounted && (!needsCode || code != null)) {
        await runDeviceCommand(
          context,
          ref,
          alarm,
          ArmAlarm('away', code: code),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _end() async {
    setState(() => _busy = true);
    await ref.read(vacationProvider.notifier).end();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final vacation = ref.watch(vacationProvider);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final thermostats = vacationThermostats(devices.values);
    final sim = ref.watch(presenceSimEntityProvider);
    final alarm = ref.watch(kioskAlarmProvider);
    final kiosk = ref.watch(kioskActiveProvider);

    final body = vacation.active
        ? <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.luggage, color: theme.colorScheme.primary),
              title: Text(l10n.vacationActive),
              subtitle: Text(
                l10n.vacationActiveSince(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(vacation.since!),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.vacationEndHint),
            if (alarm?.state.alarmState != AlarmState.disarmed &&
                alarm != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.vacationAlarmStillOn,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('vacationEnd'),
              onPressed: _busy ? null : _end,
              icon: const Icon(Icons.home_outlined),
              label: Text(l10n.vacationEnd),
            ),
          ]
        : <Widget>[
            Text(l10n.vacationHint),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _tidy,
              onChanged: (v) => setState(() => _tidy = v ?? false),
              title: Text(l10n.vacationTidy),
              subtitle: Text(l10n.vacationTidyHint),
            ),
            if (thermostats.isNotEmpty) ...[
              CheckboxListTile(
                key: const Key('vacationHeating'),
                contentPadding: EdgeInsets.zero,
                value: _heating,
                onChanged: (v) => setState(() => _heating = v ?? false),
                title: Text(
                  l10n.vacationHeating(_temperature.toStringAsFixed(0)),
                ),
                subtitle: Text(l10n.vacationHeatingHint(thermostats.length)),
              ),
              if (_heating)
                Slider(
                  value: _temperature,
                  min: 10,
                  max: 20,
                  divisions: 10,
                  label: '${_temperature.toStringAsFixed(0)} °C',
                  onChanged: (v) => setState(() => _temperature = v),
                ),
            ],
            CheckboxListTile(
              key: const Key('vacationSimulation'),
              contentPadding: EdgeInsets.zero,
              value: sim != null && _simulation,
              onChanged: sim == null
                  ? null
                  : (v) => setState(() => _simulation = v ?? false),
              title: Text(l10n.vacationSimulation),
              subtitle: Text(
                sim == null
                    ? l10n.vacationSimulationMissing
                    : l10n.vacationSimulationHint,
              ),
              secondary: sim == null && !kiosk
                  ? TextButton(
                      onPressed: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push(AppRoutes.presenceSim);
                      },
                      child: Text(l10n.vacationSimulationSetUp),
                    )
                  : null,
            ),
            if (alarm != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _alarm,
                onChanged: (v) => setState(() => _alarm = v ?? false),
                title: Text(l10n.vacationAlarm),
                subtitle: Text(alarm.name),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('vacationStart'),
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.luggage),
              label: Text(l10n.vacationStart),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.vacationLocalNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        key: const Key('vacationSheet'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l10n.vacationTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_busy) const LinearProgressIndicator(),
          ...body,
        ],
      ),
    );
  }
}
