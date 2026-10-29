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

/// "postavi tajmer 10 minuta", "tajmer na pola sata", "set a timer for 5
/// minutes", "timer 90 seconds" → the duration; anything else → `null`
/// (then the text goes to Home Assistant as usual).
Duration? parseTimerCommand(String text) {
  final t = text.toLowerCase().trim();
  if (!RegExp(r'\b(tajmer\w*|timer\w*|odbrojavanje)\b').hasMatch(t)) {
    return null;
  }
  if (RegExp(r'pola sata|half an hour').hasMatch(t)) {
    return const Duration(minutes: 30);
  }
  if (RegExp(r'(jedan |1 )?sat\b|an hour|one hour').hasMatch(t) &&
      !RegExp(r'\d+\s*(sat|h|hour)').hasMatch(t)) {
    return const Duration(hours: 1);
  }
  var total = Duration.zero;
  final parts = RegExp(
    r'(\d+)\s*(sat[ai]?|h\b|hours?|minut[aie]?|min\b|minutes?|sekund[aie]?|sec\b|s\b|seconds?)',
  ).allMatches(t);
  for (final m in parts) {
    final n = int.parse(m[1]!);
    final unit = m[2]!;
    total += switch (unit[0]) {
      's' when unit.startsWith('sat') => Duration(hours: n),
      's' => Duration(seconds: n),
      'h' => Duration(hours: n),
      _ => Duration(minutes: n),
    };
  }
  if (total > Duration.zero) return total;
  // "tajmer 10" — minutes.
  final bare = RegExp(r'\b(\d+)\b').firstMatch(t);
  return bare == null ? null : Duration(minutes: int.parse(bare[1]!));
}

/// "1:05:00", "4:30", "0:09" for countdowns.
String formatCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
