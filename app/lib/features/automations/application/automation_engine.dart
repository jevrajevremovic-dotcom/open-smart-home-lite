import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../devices/application/device_command_service.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/data/local/local_backend.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../weather/application/weather_providers.dart';
import '../data/routine_adapter.dart';
import '../domain/routines.dart';
import '../domain/sun.dart';
import 'routines_controller.dart';

/// Runs the household's automations on this phone: time and sun triggers
/// at each minute, device triggers on each change the devices report.
/// Conditions are asked at that moment; then the actions run in order.
///
/// It works while the app runs: open, on a wall panel, or kept running in
/// the background (Android foreground service).
class AutomationEngine implements RoutineRunner {
  AutomationEngine({
    required this._backend,
    required this._routines,
    required this._controller,
    required this._location,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalBackend _backend;
  final Routines Function() _routines;
  final RoutinesController _controller;
  final HomeLocation? Function() _location;
  final DateTime Function() _clock;
  static final _log = AppLogger('Automations');

  StreamSubscription<Object?>? _sub;
  Timer? _minute;
  final _minutes = StreamController<DateTime>.broadcast();

  /// Each minute, for the home's programs (sunrise, presence, timers).
  Stream<DateTime> get minutes => _minutes.stream;

  DateTime get now => _clock();

  /// When the sun rises and sets today at home; `null` without the
  /// home's location.
  ({DateTime sunrise, DateTime sunset})? sunToday() => _sunToday(_clock());
  Map<String, SmartHomeDevice> _previous = const {};

  /// What already fired, so a minute or a change counts once.
  final Map<String, String> _fired = {};

  void start() {
    _previous = _backend.current.devices;
    _sub = _backend.snapshots.listen((s) {
      final before = _previous;
      _previous = s.devices;
      _onDevices(before, s.devices);
    });
    _scheduleMinute();
  }

  void _scheduleMinute() {
    final now = _clock();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _minute = Timer(next.difference(now), () {
      tick();
      _scheduleMinute();
    });
  }

  /// Time and sun triggers for the current minute.
  void tick() {
    final now = _clock();
    if (!_minutes.isClosed) _minutes.add(now);
    final minute = ClockTime(now.hour, now.minute);
    final stamp = '${now.year}-${now.month}-${now.day} $minute';
    final sun = _sunToday(now);
    for (final a in _routines().automations) {
      if (!a.enabled) continue;
      for (final (i, t) in a.triggers.indexed) {
        final due = switch (t) {
          TimeTrigger(:final at) => at == minute,
          SunTrigger(:final sunset, :final offsetMinutes) when sun != null =>
            _sameMinute(
              (sunset ? sun.sunset : sun.sunrise).add(
                Duration(minutes: offsetMinutes),
              ),
              now,
            ),
          _ => false,
        };
        if (due && _fired['${a.id}/$i'] != stamp) {
          _fired['${a.id}/$i'] = stamp;
          unawaited(_fire(a));
        }
      }
    }
  }

  void _onDevices(
    Map<String, SmartHomeDevice> before,
    Map<String, SmartHomeDevice> after,
  ) {
    for (final a in _routines().automations) {
      if (!a.enabled) continue;
      for (final t in a.triggers) {
        final hit = switch (t) {
          DeviceTrigger(:final deviceId, :final to) =>
            // A change into the state; a device first seen does not count.
            before[deviceId] != null &&
                after[deviceId] != null &&
                before[deviceId]!.available &&
                after[deviceId]!.available &&
                !to.matches(before[deviceId]!) &&
                to.matches(after[deviceId]!),
          ValueTrigger(:final deviceId, :final above, :final threshold) =>
            _crossed(
              before[deviceId]?.state.numericValue,
              after[deviceId]?.state.numericValue,
              above,
              threshold,
            ),
          _ => false,
        };
        if (hit) {
          unawaited(_fire(a));
          break;
        }
      }
    }
  }

  static bool _crossed(double? was, double? now, bool above, double limit) {
    if (was == null || now == null) return false;
    return above ? was <= limit && now > limit : was >= limit && now < limit;
  }

  static bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  ({DateTime sunrise, DateTime sunset})? _sunToday(DateTime now) {
    final home = _location();
    return home == null ? null : sunTimes(now, home.latitude, home.longitude);
  }

  /// Dark: after sunset or before sunrise; without the home's location,
  /// 20:00 to 6:00.
  bool isDark(DateTime now) {
    final sun = _sunToday(now);
    if (sun == null) return now.hour >= 20 || now.hour < 6;
    return now.isBefore(sun.sunrise) || now.isAfter(sun.sunset);
  }

  bool conditionsHold(LocalAutomation a, DateTime now) {
    final devices = _backend.current.devices;
    for (final c in a.conditions) {
      final ok = switch (c) {
        WeekdayCondition(:final weekdays) =>
          weekdays.isEmpty || weekdays.contains(now.weekday),
        TimeWindowCondition() => c.includes(ClockTime(now.hour, now.minute)),
        StateCondition(:final deviceId, :final state) =>
          devices[deviceId] != null && state.matches(devices[deviceId]!),
        DarkCondition(:final dark) => isDark(now) == dark,
      };
      if (!ok) return false;
    }
    return true;
  }

  Future<void> _fire(LocalAutomation a) async {
    final now = _clock();
    if (!conditionsHold(a, now)) return;
    _log.info('Running "${a.name}"');
    await _run(a.actions);
    await _controller.markTriggered(a.id, now);
  }

  Future<void> _run(List<DeviceAction> actions) async {
    final service = DeviceCommandService(_backend);
    for (final action in actions) {
      final device = _backend.current.devices[action.deviceId];
      if (device == null) {
        _log.warning('${action.deviceId} is gone');
        continue;
      }
      try {
        // Set up by the household: no second confirmation.
        await service.execute(device, action.command, confirmed: true);
      } on AppFailure catch (e) {
        // One device not answering does not stop the others.
        _log.warning('${action.deviceId}: ${action.command.runtimeType}', e);
      }
    }
  }

  @override
  Future<void> runScene(String sceneId) async {
    final scene = _routines().scenes.where((s) => s.id == sceneId).firstOrNull;
    if (scene == null) {
      throw AppFailure(
        FailureKind.unavailableEntity,
        debugMessage: 'scene $sceneId',
      );
    }
    await _run(scene.actions);
  }

  @override
  Future<void> runAutomation(String automationId) async {
    final a = _routines().automations
        .where((a) => a.id == automationId)
        .firstOrNull;
    if (a == null) return;
    await _run(a.actions);
    await _controller.markTriggered(a.id, _clock());
  }

  @override
  Future<void> setEnabled(String automationId, bool enabled) =>
      _controller.setEnabled(automationId, enabled);

  void dispose() {
    _minute?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_minutes.close());
  }
}

/// The adapter that shows scenes and automations as devices.
final routineAdapterProvider = Provider<RoutineAdapter>((ref) {
  final adapter = RoutineAdapter(ref.read(routinesProvider));
  ref.listen(routinesProvider, (_, r) => adapter.setRoutines(r));
  return adapter;
});

/// Started with the app; lives as long as the home's backend.
final automationEngineProvider = Provider<AutomationEngine?>((ref) {
  final backend = ref.watch(homeBackendProvider);
  if (backend == null) return null;
  final engine = AutomationEngine(
    backend: backend,
    routines: () => ref.read(routinesProvider),
    controller: ref.read(routinesProvider.notifier),
    location: () => ref.read(homeLocationWeatherEnabledProvider),
  )..start();
  ref.watch(routineAdapterProvider).runner = engine;
  ref.onDispose(engine.dispose);
  return engine;
});
