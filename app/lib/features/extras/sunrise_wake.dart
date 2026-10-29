import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../authentication/application/session_controller.dart';
import '../automations/domain/simple_automation.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/capability.dart';
import '../devices/domain/smart_home_device.dart';

/// The one sunrise alarm of the home (an automation in Home Assistant).
const sunriseWakeId = 'osh_sunrise_wake';

/// Home Assistant's weekday names, Monday first.
const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Light that slowly comes up before waking: from a dim warm glow to full
/// daylight over [minutes], fully bright at [wakeAt] on [days]. Runs in
/// Home Assistant (`time` trigger, `time` weekday condition, `light.turn_on`
/// with `transition`), so it works with the phone off.
@immutable
class SunriseWake {
  const SunriseWake({
    required this.lights,
    this.wakeAt = const ClockTime(7, 0),
    this.minutes = 15,
    this.days = const {'mon', 'tue', 'wed', 'thu', 'fri'},
  });

  /// Back from the saved automation (its `variables`), or null.
  static SunriseWake? fromAutomation(Map<String, Object?> config) {
    final v = config['variables'];
    if (v is! Map) return null;
    final wake = ClockTime.parse(v['osh_wake']);
    final lights = v['osh_lights'];
    if (wake == null || lights is! List) return null;
    return SunriseWake(
      lights: [
        for (final l in lights)
          if (l is String) l,
      ],
      wakeAt: wake,
      minutes: (v['osh_minutes'] as num?)?.toInt() ?? 15,
      days: {
        if (v['osh_days'] case final List<Object?> d)
          for (final x in d)
            if (x is String) x,
      },
    );
  }

  final List<String> lights;
  final ClockTime wakeAt;
  final int minutes;

  /// `mon` … `sun`.
  final Set<String> days;

  SunriseWake copyWith({
    List<String>? lights,
    ClockTime? wakeAt,
    int? minutes,
    Set<String>? days,
  }) => SunriseWake(
    lights: lights ?? this.lights,
    wakeAt: wakeAt ?? this.wakeAt,
    minutes: minutes ?? this.minutes,
    days: days ?? this.days,
  );

  /// When the light starts, and on which days (a start before midnight
  /// moves to the day before).
  (ClockTime, List<String>) get start {
    var total = wakeAt.hour * 60 + wakeAt.minute - minutes;
    var shift = 0;
    if (total < 0) {
      total += 24 * 60;
      shift = -1;
    }
    return (
      ClockTime(total ~/ 60, total % 60),
      [
        for (var i = 0; i < 7; i++)
          if (days.contains(_weekdays[(i - shift) % 7])) _weekdays[i],
      ],
    );
  }

  Map<String, Object?> automation(
    AppLocalizations l10n,
    Map<String, SmartHomeDevice> devices,
  ) {
    final (at, startDays) = start;
    bool warm(String id) =>
        devices[id]?.supports(Capability.colorTemperature) ?? false;
    return {
      'alias': l10n.sunriseAlias,
      'description': 'Open Smart Home',
      'mode': 'single',
      'variables': {
        'osh_wake': wakeAt.toHa(),
        'osh_lights': lights,
        'osh_minutes': minutes,
        'osh_days': [
          for (final d in _weekdays)
            if (days.contains(d)) d,
        ],
      },
      'triggers': [
        {'trigger': 'time', 'at': at.toHa()},
      ],
      'conditions': [
        if (startDays.length < 7) {'condition': 'time', 'weekday': startDays},
      ],
      'actions': [
        // A dim, warm glow first…
        for (final id in lights)
          {
            'action': 'light.turn_on',
            'continue_on_error': true,
            'target': {'entity_id': id},
            'data': {
              'brightness_pct': 1,
              if (warm(id)) 'color_temp_kelvin': 2200,
            },
          },
        {
          'delay': {'seconds': 2},
        },
        // …then up to daylight, slowly.
        for (final id in lights)
          {
            'action': 'light.turn_on',
            'continue_on_error': true,
            'target': {'entity_id': id},
            'data': {
              'brightness_pct': 100,
              if (warm(id)) 'color_temp_kelvin': 4000,
              'transition': minutes * 60,
            },
          },
      ],
    };
  }
}

/// Whether the sunrise alarm exists (its entity carries the id).
final sunriseWakeSetProvider = Provider<bool>(
  (ref) => ref.watch(
    homeSnapshotProvider.select(
      (s) => s.devices.values.any((d) => d.metadata.configId == sunriseWakeId),
    ),
  ),
);

Future<void> showSunriseWake(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _SunriseSheet(),
    );

class _SunriseSheet extends ConsumerStatefulWidget {
  const _SunriseSheet();

  @override
  ConsumerState<_SunriseSheet> createState() => _SunriseSheetState();
}

class _SunriseSheetState extends ConsumerState<_SunriseSheet> {
  SunriseWake? _wake;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(homeAssistantApiProvider);
    SunriseWake? saved;
    if (api != null && ref.read(sunriseWakeSetProvider)) {
      try {
        saved = SunriseWake.fromAutomation(
          await api.fetchAutomation(sunriseWakeId),
        );
      } on AppFailure {
        saved = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _wake = saved ?? SunriseWake(lights: _defaultLights());
      _busy = false;
    });
  }

  /// The bedroom's lights, if the home has a room that sounds like one.
  List<String> _defaultLights() {
    final snapshot = ref.read(homeSnapshotProvider);
    final bedroom = snapshot.rooms.values
        .where(
          (r) => RegExp('spava|bed', caseSensitive: false).hasMatch(r.name),
        )
        .firstOrNull;
    return [
      for (final d in snapshot.devices.values)
        if (d.kind.isLight && bedroom != null && d.roomId == bedroom.id) d.id,
    ];
  }

  Future<void> _save({bool remove = false}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final local = MaterialLocalizations.of(context);
    final api = ref.read(homeAssistantApiProvider);
    final wake = _wake;
    if (api == null || wake == null) return;
    setState(() => _busy = true);
    try {
      if (remove) {
        await api.deleteAutomation(sunriseWakeId);
        messenger.showSnackBar(SnackBar(content: Text(l10n.sunriseRemoved)));
      } else {
        await api.saveAutomation(
          sunriseWakeId,
          wake.automation(l10n, ref.read(homeSnapshotProvider).devices),
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.sunriseSaved(
                local.formatTimeOfDay(
                  TimeOfDay(hour: wake.wakeAt.hour, minute: wake.wakeAt.minute),
                  alwaysUse24HourFormat: true,
                ),
              ),
            ),
          ),
        );
      }
      navigator.pop();
    } on AppFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage(l10n, e))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final wake = _wake;
    final isSet = ref.watch(sunriseWakeSetProvider);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final lights = [
      for (final d in devices.values)
        if (d.kind.isLight && !d.isAuxiliary) d,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final local = MaterialLocalizations.of(context);
    final dayNames = [
      for (var i = 0; i < 7; i++)
        // Material's list starts on Sunday; ours on Monday.
        local.narrowWeekdays[(i + 1) % 7],
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        key: const Key('sunriseSheet'),
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l10n.sunriseTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l10n.sunriseHint),
          if (_busy) const LinearProgressIndicator(),
          if (wake != null) ...[
            const SizedBox(height: 12),
            ListTile(
              key: const Key('sunriseTime'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm),
              title: Text(l10n.sunriseWakeAt),
              trailing: Text(
                local.formatTimeOfDay(
                  TimeOfDay(hour: wake.wakeAt.hour, minute: wake.wakeAt.minute),
                  alwaysUse24HourFormat: true,
                ),
                style: theme.textTheme.headlineSmall,
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: wake.wakeAt.hour,
                    minute: wake.wakeAt.minute,
                  ),
                );
                if (t != null) {
                  setState(
                    () => _wake = wake.copyWith(
                      wakeAt: ClockTime(t.hour, t.minute),
                    ),
                  );
                }
              },
            ),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(dayNames[i]),
                    selected: wake.days.contains(_weekdays[i]),
                    onSelected: (v) => setState(
                      () => _wake = wake.copyWith(
                        days: v
                            ? {...wake.days, _weekdays[i]}
                            : ({...wake.days}..remove(_weekdays[i])),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.sunriseMinutes(wake.minutes)),
            Slider(
              value: wake.minutes.toDouble(),
              min: 5,
              max: 40,
              divisions: 7,
              label: '${wake.minutes}',
              onChanged: (v) =>
                  setState(() => _wake = wake.copyWith(minutes: v.round())),
            ),
            Text(l10n.sunriseLights, style: theme.textTheme.titleSmall),
            for (final l in lights)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: wake.lights.contains(l.id),
                title: Text(l.name),
                onChanged: (v) => setState(
                  () => _wake = wake.copyWith(
                    lights: v == true
                        ? [...wake.lights, l.id]
                        : [...wake.lights.where((x) => x != l.id)],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('sunriseSave'),
              onPressed: _busy || wake.lights.isEmpty || wake.days.isEmpty
                  ? null
                  : _save,
              icon: const Icon(Icons.wb_twilight),
              label: Text(isSet ? l10n.sunriseUpdate : l10n.sunriseSave),
            ),
            if (isSet)
              TextButton(
                key: const Key('sunriseRemove'),
                onPressed: _busy ? null : () => _save(remove: true),
                child: Text(l10n.sunriseRemove),
              ),
          ],
        ],
      ),
    );
  }
}
