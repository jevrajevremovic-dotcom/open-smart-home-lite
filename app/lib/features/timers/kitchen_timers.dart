import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_preferences.dart';

/// A countdown on this device (kitchen timer). Kept in preferences, so it
/// survives a restart of the app.
@immutable
class KitchenTimer {
  const KitchenTimer({
    required this.id,
    required this.duration,
    required this.endsAt,
  });

  final String id;
  final Duration duration;
  final DateTime endsAt;

  Duration remaining(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool doneAt(DateTime now) => !now.isBefore(endsAt);

  KitchenTimer extendedBy(Duration more, DateTime now) => KitchenTimer(
    id: id,
    duration: duration + more,
    endsAt: (doneAt(now) ? now : endsAt).add(more),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'seconds': duration.inSeconds,
    'endsAt': endsAt.toUtc().toIso8601String(),
  };

  static KitchenTimer? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final seconds = json['seconds'];
    final endsAt = DateTime.tryParse('${json['endsAt']}');
    if (id is! String || seconds is! int || endsAt == null) return null;
    return KitchenTimer(
      id: id,
      duration: Duration(seconds: seconds),
      endsAt: endsAt.toLocal(),
    );
  }
}

/// Running (and finished, not yet dismissed) timers, soonest first.
class KitchenTimersController extends Notifier<List<KitchenTimer>> {
  static const _key = 'timers.kitchen';

  @override
  List<KitchenTimer> build() {
    final json = ref.watch(appPreferencesProvider).readJson(_key);
    final list = json?['timers'];
    return [
      if (list is List)
        for (final t in list) ?KitchenTimer.tryFromJson(t),
    ]..sort((a, b) => a.endsAt.compareTo(b.endsAt));
  }

  Future<void> _save(List<KitchenTimer> timers) async {
    state = [...timers]..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    await ref
        .read(appPreferencesProvider)
        .writeJson(
          _key,
          timers.isEmpty
              ? null
              : {'timers': state.map((t) => t.toJson()).toList()},
        );
  }

  Future<KitchenTimer> start(Duration duration, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final timer = KitchenTimer(
      id: '${at.microsecondsSinceEpoch}',
      duration: duration,
      endsAt: at.add(duration),
    );
    await _save([...state, timer]);
    return timer;
  }

  Future<void> cancel(String id) => _save([
    for (final t in state)
      if (t.id != id) t,
  ]);

  Future<void> extend(String id, Duration more) {
    final now = DateTime.now();
    return _save([
      for (final t in state) t.id == id ? t.extendedBy(more, now) : t,
    ]);
  }
}

final kitchenTimersProvider =
    NotifierProvider<KitchenTimersController, List<KitchenTimer>>(
      KitchenTimersController.new,
    );

/// "1:05:00", "4:30", "0:09" for countdowns.
String formatCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
