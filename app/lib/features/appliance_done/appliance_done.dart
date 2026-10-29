import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_preferences.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';

/// Power above the threshold this long counts as "running".
const applianceStartMinutes = 2;

/// "The washing machine is done": when the appliance's power has been
/// above [thresholdWatts] and then stays below it for [doneMinutes], this
/// phone (or wall panel) says so with a notification.
@immutable
class ApplianceDone {
  const ApplianceDone({
    required this.powerId,
    required this.name,
    this.thresholdWatts = 5,
    this.doneMinutes = 3,
  });

  final String powerId;
  final String name;
  final int thresholdWatts;
  final int doneMinutes;

  ApplianceDone copyWith({
    String? name,
    int? thresholdWatts,
    int? doneMinutes,
  }) => ApplianceDone(
    powerId: powerId,
    name: name ?? this.name,
    thresholdWatts: thresholdWatts ?? this.thresholdWatts,
    doneMinutes: doneMinutes ?? this.doneMinutes,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'threshold': thresholdWatts,
    'minutes': doneMinutes,
  };

  static ApplianceDone? fromJson(String powerId, Object? json) {
    if (json is! Map || json['name'] is! String) return null;
    final threshold = json['threshold'];
    final minutes = json['minutes'];
    return ApplianceDone(
      powerId: powerId,
      name: json['name'] as String,
      thresholdWatts: threshold is num ? threshold.toInt() : 5,
      doneMinutes: minutes is num ? minutes.toInt() : 3,
    );
  }
}

/// The appliances watched, by power sensor id.
class ApplianceDoneController extends Notifier<Map<String, ApplianceDone>> {
  static const _key = 'applianceDone';

  @override
  Map<String, ApplianceDone> build() {
    final json = ref.watch(appPreferencesProvider).readJson(_key) ?? const {};
    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: ?ApplianceDone.fromJson(key, value),
    };
  }

  Future<void> _save(Map<String, ApplianceDone> all) async {
    state = all;
    await ref.read(appPreferencesProvider).writeJson(_key, {
      for (final MapEntry(:key, :value) in all.entries) key: value.toJson(),
    });
  }

  Future<void> save(ApplianceDone config) =>
      _save({...state, config.powerId: config});

  Future<void> remove(String powerId) => _save({...state}..remove(powerId));

  Map<String, Object?> toJson() => {
    for (final MapEntry(:key, :value) in state.entries) key: value.toJson(),
  };

  /// From a backup.
  Future<void> importJson(Map<Object?, Object?> json, {required bool replace}) {
    final other = {
      for (final MapEntry(:key, :value) in json.entries)
        if (key is String) key: ?ApplianceDone.fromJson(key, value),
    };
    return _save(replace ? other : {...other, ...state});
  }
}

final applianceDoneProvider =
    NotifierProvider<ApplianceDoneController, Map<String, ApplianceDone>>(
      ApplianceDoneController.new,
    );

/// Whether the appliance is watched.
final applianceDoneSetProvider = Provider.family<bool, String>(
  (ref, powerId) => ref.watch(applianceDoneProvider).containsKey(powerId),
);

/// Follows each watched appliance's power: running after
/// [applianceStartMinutes] above the threshold, done after its minutes
/// below it — then [onDone] once.
class ApplianceWatcher {
  ApplianceWatcher(this.onDone);

  final void Function(ApplianceDone appliance) onDone;
  final Map<String, DateTime> _aboveSince = {};
  final Map<String, DateTime> _belowSince = {};
  final Set<String> _running = {};

  void check(
    DateTime now,
    Map<String, ApplianceDone> watched,
    Map<String, SmartHomeDevice> devices,
  ) {
    for (final a in watched.values) {
      final watts = devices[a.powerId]?.state.numericValue;
      if (watts == null) continue;
      if (watts > a.thresholdWatts) {
        _belowSince.remove(a.powerId);
        final since = _aboveSince.putIfAbsent(a.powerId, () => now);
        if (now.difference(since) >=
            const Duration(minutes: applianceStartMinutes)) {
          _running.add(a.powerId);
        }
      } else {
        _aboveSince.remove(a.powerId);
        if (!_running.contains(a.powerId)) continue;
        final since = _belowSince.putIfAbsent(a.powerId, () => now);
        if (now.difference(since) >= Duration(minutes: a.doneMinutes)) {
          _running.remove(a.powerId);
          _belowSince.remove(a.powerId);
          onDone(a);
        }
      }
    }
  }
}

/// The power sensor that tells whether [device] runs: itself, or the
/// power sensor of the same physical device (a smart plug's).
final appliancePowerProvider = Provider.family<SmartHomeDevice?, String>((
  ref,
  deviceId,
) {
  final device = ref.watch(deviceProvider(deviceId));
  if (device == null) return null;
  if (device.kind == DeviceKind.powerMeter) return device;
  final physical = device.deviceId;
  if (physical == null) return null;
  return ref.watch(
    homeSnapshotProvider.select((s) {
      for (final d in s.devices.values) {
        if (d.deviceId == physical && d.kind == DeviceKind.powerMeter) {
          return d;
        }
      }
      return null;
    }),
  );
});
