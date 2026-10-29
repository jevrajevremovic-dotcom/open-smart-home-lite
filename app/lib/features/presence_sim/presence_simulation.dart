import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_preferences.dart';
import '../automations/domain/routines.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/smart_home_device.dart';
import '../extras/send_command.dart';

/// Lights switched at random in the evening while it is on, so the house
/// looks lived in. Runs on this phone or wall panel (it has to stay at
/// home, running).
@immutable
class PresenceSimulation {
  const PresenceSimulation({
    this.enabled = false,
    this.lights = const [],
    this.fromSunset = true,
    this.start = const ClockTime(18, 0),
    this.end = const ClockTime(23, 30),
  });

  final bool enabled;
  final List<String> lights;

  /// Start at sunset (else at [start]).
  final bool fromSunset;
  final ClockTime start;

  /// All the chosen lights go off at [end]; nothing happens after it.
  final ClockTime end;

  bool get valid => lights.isNotEmpty;

  PresenceSimulation copyWith({
    bool? enabled,
    List<String>? lights,
    bool? fromSunset,
    ClockTime? start,
    ClockTime? end,
  }) => PresenceSimulation(
    enabled: enabled ?? this.enabled,
    lights: lights ?? this.lights,
    fromSunset: fromSunset ?? this.fromSunset,
    start: start ?? this.start,
    end: end ?? this.end,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'lights': lights,
    'fromSunset': fromSunset,
    'start': '$start',
    'end': '$end',
  };

  static PresenceSimulation fromJson(Map<String, Object?>? json) =>
      PresenceSimulation(
        enabled: json?['enabled'] == true,
        lights: [
          for (final l in (json?['lights'] as List?) ?? const [])
            if (l is String) l,
        ],
        fromSunset: json?['fromSunset'] != false,
        start: ClockTime.parse(json?['start']) ?? const ClockTime(18, 0),
        end: ClockTime.parse(json?['end']) ?? const ClockTime(23, 30),
      );
}

class PresenceSimController extends Notifier<PresenceSimulation> {
  static const _key = 'presenceSim';

  @override
  PresenceSimulation build() => PresenceSimulation.fromJson(
    ref.watch(appPreferencesProvider).readJson(_key),
  );

  Future<void> save(PresenceSimulation sim) async {
    state = sim;
    await ref.read(appPreferencesProvider).writeJson(_key, sim.toJson());
  }

  Future<void> setEnabled(bool enabled) =>
      save(state.copyWith(enabled: enabled));
}

final presenceSimProvider =
    NotifierProvider<PresenceSimController, PresenceSimulation>(
      PresenceSimController.new,
    );

/// Every quarter hour within the evening window, one random chosen light
/// changes (on → off, off → on) after a random wait of up to ten minutes;
/// at the end all go off.
class PresenceRunner {
  PresenceRunner(this._send, {Random? random}) : _random = random ?? Random();

  final SendCommand _send;
  final Random _random;
  final List<Timer> _waiting = [];

  void onMinute(
    DateTime now,
    PresenceSimulation sim,
    Map<String, SmartHomeDevice> Function() devices,
    ({DateTime sunrise, DateTime sunset})? sun,
  ) {
    if (!sim.enabled || !sim.valid) return;
    final t = ClockTime(now.hour, now.minute);
    if (t == sim.end) {
      for (final id in sim.lights) {
        unawaited(_send(id, const TurnOff()));
      }
      return;
    }
    if (now.minute % 15 != 0) return;
    // Without the home's location, "sunset" is 18:00.
    final from = sim.fromSunset
        ? (sun == null
              ? const ClockTime(18, 0)
              : ClockTime(sun.sunset.hour, sun.sunset.minute))
        : sim.start;
    if (!TimeWindowCondition(after: from, before: sim.end).includes(t)) return;
    final id = sim.lights[_random.nextInt(sim.lights.length)];
    _waiting
      ..removeWhere((t) => !t.isActive)
      ..add(
        Timer(Duration(seconds: _random.nextInt(600)), () {
          final on = devices()[id]?.state.isOn == true;
          unawaited(_send(id, on ? const TurnOff() : const TurnOn()));
        }),
      );
  }

  void dispose() {
    for (final t in _waiting) {
      t.cancel();
    }
  }
}
