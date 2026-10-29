import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/storage/app_preferences.dart';
import '../automations/domain/routines.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/capability.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/smart_home_device.dart';
import 'send_command.dart';

/// Weekday names as stored, Monday first.
const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Light that slowly comes up before waking: from a dim warm glow to full
/// daylight over [minutes], fully bright at [wakeAt] on [days]. Runs on
/// this phone or wall panel, a step each minute.
@immutable
class SunriseWake {
  const SunriseWake({
    required this.lights,
    this.wakeAt = const ClockTime(7, 0),
    this.minutes = 15,
    this.days = const {'mon', 'tue', 'wed', 'thu', 'fri'},
  });

  final List<String> lights;
  final ClockTime wakeAt;
  final int minutes;

  /// `mon` … `sun`: the days of waking.
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

  Map<String, Object?> toJson() => {
    'lights': lights,
    'wakeAt': '$wakeAt',
    'minutes': minutes,
    'days': [
      for (final d in _weekdays)
        if (days.contains(d)) d,
    ],
  };

  static SunriseWake? fromJson(Map<String, Object?>? json) {
    final wake = ClockTime.parse(json?['wakeAt']);
    final lights = json?['lights'];
    if (wake == null || lights is! List) return null;
    return SunriseWake(
      lights: [
        for (final l in lights)
          if (l is String) l,
      ],
      wakeAt: wake,
      minutes: (json?['minutes'] as num?)?.toInt() ?? 15,
      days: {
        if (json?['days'] case final List<Object?> d)
          for (final x in d)
            if (x is String) x,
      },
    );
  }

  /// How far the sunrise is at [now], 0…1, or `null` outside it.
  double? progress(DateTime now) {
    // Today's waking, or tomorrow's (a sunrise that starts before
    // midnight).
    for (final day in [now, now.add(const Duration(days: 1))]) {
      final wake = DateTime(
        day.year,
        day.month,
        day.day,
        wakeAt.hour,
        wakeAt.minute,
      );
      if (!days.contains(_weekdays[wake.weekday - 1])) continue;
      final start = wake.subtract(Duration(minutes: minutes));
      if (!now.isBefore(start) && !now.isAfter(wake)) {
        return minutes == 0
            ? 1
            : now.difference(start).inSeconds / (minutes * 60);
      }
    }
    return null;
  }
}

class SunriseWakeController extends Notifier<SunriseWake?> {
  static const _key = 'sunriseWake';

  @override
  SunriseWake? build() =>
      SunriseWake.fromJson(ref.watch(appPreferencesProvider).readJson(_key));

  /// [wake] set, or (`null`) off.
  Future<void> save(SunriseWake? wake) async {
    state = wake;
    await ref.read(appPreferencesProvider).writeJson(_key, wake?.toJson());
  }
}

final sunriseWakeProvider =
    NotifierProvider<SunriseWakeController, SunriseWake?>(
      SunriseWakeController.new,
    );

/// Whether the sunrise alarm is set.
final sunriseWakeSetProvider = Provider<bool>(
  (ref) => ref.watch(sunriseWakeProvider) != null,
);

/// Each minute of a sunrise: the lights a step brighter and cooler.
class SunriseRunner {
  SunriseRunner(this._send);

  final SendCommand _send;

  void onMinute(
    DateTime now,
    SunriseWake? wake,
    Map<String, SmartHomeDevice> Function() devices,
  ) {
    final p = wake?.progress(now);
    if (wake == null || p == null) return;
    final brightness = (1 + 99 * p).round().clamp(1, 100);
    final kelvin = (2200 + (4000 - 2200) * p).round();
    for (final id in wake.lights) {
      unawaited(_send(id, SetBrightness(brightness)));
      if (devices()[id]?.supports(Capability.colorTemperature) ?? false) {
        unawaited(_send(id, SetColorTemperature(kelvin)));
      }
    }
  }
}

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

  void _load() {
    _wake =
        ref.read(sunriseWakeProvider) ?? SunriseWake(lights: _defaultLights());
    _busy = false;
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
    final wake = _wake;
    if (wake == null) return;
    await ref.read(sunriseWakeProvider.notifier).save(remove ? null : wake);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          remove
              ? l10n.sunriseRemoved
              : l10n.sunriseSaved(
                  local.formatTimeOfDay(
                    TimeOfDay(
                      hour: wake.wakeAt.hour,
                      minute: wake.wakeAt.minute,
                    ),
                    alwaysUse24HourFormat: true,
                  ),
                ),
        ),
      ),
    );
    navigator.pop();
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
