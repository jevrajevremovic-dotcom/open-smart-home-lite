import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/app_theme.dart';
import '../assist/application/voice_providers.dart';
import '../kiosk/application/kiosk_controller.dart';
import 'kitchen_timers.dart';

/// "10 min", "1 h 30 min", "45 s".
String timerLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return [
    if (h > 0) '$h h',
    if (m > 0) '$m min',
    if (s > 0 && h == 0) '$s s',
  ].join(' ');
}

/// Countdowns on the kiosk: pills in the corner while running, a big card
/// (spoken, repeated) when one is done.
class KioskTimersLayer extends ConsumerStatefulWidget {
  const KioskTimersLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskTimersLayer> createState() => _KioskTimersLayerState();
}

class _KioskTimersLayerState extends ConsumerState<KioskTimersLayer> {
  Timer? _tick;

  /// Done timers already announced, with how many times.
  final Map<String, int> _announced = {};

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _sync(List<KitchenTimer> timers) {
    if (timers.isEmpty) {
      _tick?.cancel();
      _tick = null;
      _announced.clear();
      return;
    }
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _announce();
    });
    // A timer that is already done (e.g. after a restart) speaks at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _announce();
    });
  }

  /// Speaks a finished timer at once, then every 15 s, at most 6 times.
  void _announce() {
    final now = DateTime.now();
    final timers = ref.read(kitchenTimersProvider);
    _announced.removeWhere((id, _) => !timers.any((t) => t.id == id));
    for (final t in timers.where((t) => t.doneAt(now))) {
      final late = now.difference(t.endsAt).inSeconds;
      final times = _announced[t.id] ?? 0;
      if (times >= 6 || late < times * 15) continue;
      _announced[t.id] = times + 1;
      if (times == 0 && ref.read(kioskDimmedProvider)) {
        ref.read(kioskDimmedProvider.notifier).set(false);
      }
      final speech = ref.read(speechOutputProvider);
      if (!speech.supported) continue;
      final l10n = context.l10n;
      unawaited(
        speech
            .speak(
              l10n.timerDoneSpeech(timerLabel(t.duration)),
              languageTag: l10n.localeName,
            )
            .catchError((Object _) => false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timers = ref.watch(kitchenTimersProvider);
    _sync(timers);
    final now = DateTime.now();
    final done = timers.where((t) => t.doneAt(now)).toList();
    final running = timers.where((t) => !t.doneAt(now)).toList();
    return Stack(
      children: [
        widget.child,
        if (running.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Theme(
                data: AppTheme.dark(),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in running) _TimerPill(timer: t, now: now),
                  ],
                ),
              ),
            ),
          ),
        if (done.isNotEmpty)
          Positioned.fill(
            child: Theme(
              data: AppTheme.dark(),
              child: _DoneCard(timer: done.first),
            ),
          ),
      ],
    );
  }
}

class _TimerPill extends ConsumerWidget {
  const _TimerPill({required this.timer, required this.now});

  final KitchenTimer timer;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Material(
      key: ValueKey('kioskTimer-${timer.id}'),
      color: const Color(0xFFFFB74D),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.timerTitle),
            content: Text(timerLabel(timer.duration)),
            actions: [
              TextButton(
                key: const Key('timerCancel'),
                onPressed: () {
                  unawaited(
                    ref.read(kitchenTimersProvider.notifier).cancel(timer.id),
                  );
                  Navigator.of(context).pop();
                },
                child: Text(l10n.timerCancel),
              ),
              FilledButton(
                onPressed: () {
                  unawaited(
                    ref
                        .read(kitchenTimersProvider.notifier)
                        .extend(timer.id, const Duration(minutes: 1)),
                  );
                  Navigator.of(context).pop();
                },
                child: Text(l10n.timerAddMinute),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                formatCountdown(timer.remaining(now)),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneCard extends ConsumerWidget {
  const _DoneCard({required this.timer});

  final KitchenTimer timer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final timers = ref.read(kitchenTimersProvider.notifier);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Material(
          key: const Key('kioskTimerDone'),
          color: const Color(0xFFFFB74D),
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.alarm_on_rounded,
                  size: 96,
                  color: Colors.black87,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.timerDone(timerLabel(timer.duration)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const Key('timerStop'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(200, 60),
                        textStyle: theme.textTheme.titleLarge,
                      ),
                      onPressed: () {
                        unawaited(ref.read(speechOutputProvider).stop());
                        unawaited(timers.cancel(timer.id));
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.timerStop),
                    ),
                    OutlinedButton(
                      key: const Key('timerSnooze'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.black87, width: 2),
                        minimumSize: const Size(160, 60),
                        textStyle: theme.textTheme.titleLarge,
                      ),
                      onPressed: () =>
                          timers.extend(timer.id, const Duration(minutes: 1)),
                      child: Text(l10n.timerAddMinute),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks a duration and starts a timer.
Future<void> showTimerPicker(BuildContext context, WidgetRef ref) async {
  final picked = await showDialog<Duration>(
    context: context,
    builder: (_) => const _TimerPicker(),
  );
  if (picked == null || picked == Duration.zero) return;
  await ref.read(kitchenTimersProvider.notifier).start(picked);
}

class _TimerPicker extends StatefulWidget {
  const _TimerPicker();

  @override
  State<_TimerPicker> createState() => _TimerPickerState();
}

class _TimerPickerState extends State<_TimerPicker> {
  int _minutes = 10;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.timer_outlined),
      title: Text(l10n.timerNew),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final m in const [1, 3, 5, 10, 15, 30, 60])
                ActionChip(
                  key: ValueKey('timerPreset-$m'),
                  label: Text(timerLabel(Duration(minutes: m))),
                  onPressed: () =>
                      Navigator.of(context).pop(Duration(minutes: m)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                key: const Key('timerLess'),
                onPressed: _minutes > 1
                    ? () => setState(() => _minutes--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  timerLabel(Duration(minutes: _minutes)),
                  key: const Key('timerValue'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              IconButton.filledTonal(
                key: const Key('timerMore'),
                onPressed: _minutes < 600
                    ? () => setState(() => _minutes++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('timerStart'),
          onPressed: () =>
              Navigator.of(context).pop(Duration(minutes: _minutes)),
          child: Text(l10n.timerStart),
        ),
      ],
    );
  }
}
