import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../integrations/home_assistant/models/ha_calendar.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../dashboard/application/home_sentence.dart';
import '../../dashboard/application/home_summaries.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../media/application/media_providers.dart';
import '../../todo/todo_lists.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/presentation/weather_labels.dart';
import '../application/kiosk_controller.dart';
import '../data/kiosk_settings.dart';
import 'glass.dart' show kioskPhotoStoreProvider;
import '../application/kiosk_now.dart';

/// Text on black, readable across a room (the screen itself is dimmed by
/// the always-on brightness, so the text stays near white).
const _bright = Colors.white;
const _dim = Color(0xE6FFFFFF);
const _faint = Color(0xB3FFFFFF);

/// The always-on screen: black, a large thin clock, the weather and one
/// chosen thing — or, in the morning, the day ahead. Everything moves a
/// few pixels every minute so the panel does not burn in. A tap wakes the
/// kiosk (and does not press anything underneath).
class KioskAmbient extends ConsumerWidget {
  const KioskAmbient({super.key, required this.onWake});

  final VoidCallback onWake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(kioskNowProvider);
    final settings = ref.watch(kioskSettingsProvider);
    final morning = settings.isMorning(now);
    final night = settings.nightClock && settings.isNight(now);
    final frame =
        !night && settings.photoFrame && settings.framePhotos.isNotEmpty;
    final lightId = settings.nightLightId;
    final light = night && lightId != null
        ? ref.watch(deviceProvider(lightId))
        : null;
    // Burn-in protection: a slow walk within ±20 px, new spot each minute.
    final m = now.hour * 60 + now.minute;
    final shift = Offset(((m * 7) % 41) - 20.0, ((m * 13) % 31) - 15.0);
    return GestureDetector(
      key: const Key('kioskScreensaver'),
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        // At night the first tap is a night light, not a bright screen.
        if (light != null && light.available && light.state.isOn != true) {
          final ok = await runDeviceCommand(
            context,
            ref,
            light,
            light.supports(Capability.brightness)
                ? const SetBrightness(10)
                : const TurnOn(),
          );
          if (ok) return;
        }
        onWake();
      },
      child: frame
          ? _PhotoFrame(
              photos: settings.framePhotos,
              seconds: settings.frameSeconds,
              shift: shift,
            )
          : ColoredBox(
              color: Colors.black,
              child: SafeArea(
                child: Center(
                  child: Transform.translate(
                    offset: shift,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: night
                            ? _NightClock(light: light)
                            : morning
                            ? const _Morning()
                            : _Ambient(focus: settings.aodFocus),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Photos from this tablet, one after another with a soft cross-fade, and
/// a small clock and temperature in a corner (which wanders a little
/// against burn-in).
class _PhotoFrame extends ConsumerStatefulWidget {
  const _PhotoFrame({
    required this.photos,
    required this.seconds,
    required this.shift,
  });

  final List<String> photos;
  final int seconds;
  final Offset shift;

  @override
  ConsumerState<_PhotoFrame> createState() => _PhotoFrameState();
}

class _PhotoFrameState extends ConsumerState<_PhotoFrame> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: widget.seconds), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(kioskPhotoStoreProvider);
    final path = widget.photos[_index % widget.photos.length];
    final image = store.image(path);
    final now = ref.watch(kioskNowProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final temp = ref.watch(
      homeWeatherProvider.select((w) => w?.now.temperature),
    );
    const shadow = [Shadow(blurRadius: 12, color: Colors.black87)];
    return ColoredBox(
      key: const Key('aodPhotoFrame'),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1500),
            child: image == null
                ? const SizedBox.expand()
                : Image(
                    key: ValueKey(path),
                    image: image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
          ),
          Positioned(
            left: 40 + widget.shift.dx,
            bottom: 36 + widget.shift.dy,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.Hm(l10n.localeName).format(now),
                    key: const Key('aodClock'),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: _bright,
                      fontWeight: FontWeight.w300,
                      height: 1,
                      shadows: shadow,
                    ),
                  ),
                  Text(
                    [
                      DateFormat.MMMMEEEEd(l10n.localeName).format(now),
                      if (temp != null)
                        formatNumber(l10n.localeName, temp, unit: '°'),
                    ].join(' · '),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: _dim,
                      shadows: shadow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Night: only the time, in dim red (keeps the eyes used to the dark).
class _NightClock extends ConsumerWidget {
  const _NightClock({this.light});

  /// The night light, if one is chosen.
  final SmartHomeDevice? light;

  static const red = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(kioskNowProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final light = this.light;
    return Column(
      key: const Key('aodNight'),
      children: [
        Text(
          DateFormat.Hm(l10n.localeName).format(now),
          key: const Key('aodClock'),
          style: theme.textTheme.displayLarge?.copyWith(
            color: red,
            fontSize: 132,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
        if (light != null) ...[
          const SizedBox(height: 16),
          Text(
            light.state.isOn == true
                ? l10n.kioskNightLightOn(light.name)
                : l10n.kioskNightLightHint(light.name),
            style: theme.textTheme.titleMedium?.copyWith(
              color: red.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }
}

class _Clock extends ConsumerWidget {
  const _Clock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(kioskNowProvider);
    final locale = context.l10n.localeName;
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          DateFormat.Hm(locale).format(now),
          key: const Key('aodClock'),
          style: theme.textTheme.displayLarge?.copyWith(
            color: _bright,
            fontSize: 132,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat.MMMMEEEEd(locale).format(now),
          style: theme.textTheme.titleLarge?.copyWith(
            color: _dim,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

class _Weather extends ConsumerWidget {
  const _Weather({this.withRange = false});

  final bool withRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final report = ref.watch(homeWeatherProvider);
    final now = report?.now;
    if (now?.temperature == null) return const SizedBox.shrink();
    final today = report!.daily.firstOrNull;
    String t(double v) => formatNumber(l10n.localeName, v, unit: '°');
    return Row(
      key: const Key('aodWeather'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(weatherIcon(now!.condition), color: _dim, size: 34),
        const SizedBox(width: 12),
        Text(
          [
            t(now.temperature!),
            weatherConditionLabel(l10n, now.condition),
            if (withRange && today?.high != null && today?.low != null)
              l10n.morningHighLow(t(today!.high!), t(today.low!)),
          ].join(' · '),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: _dim, fontWeight: FontWeight.w300),
        ),
      ],
    );
  }
}

class _Ambient extends ConsumerWidget {
  const _Ambient({required this.focus});

  final AodFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusWidget = switch (focus) {
      AodFocus.none => null,
      AodFocus.nextEvent => const _NextEvent(),
      AodFocus.list => const _ListFocus(),
      AodFocus.device => const _DeviceFocus(),
      AodFocus.energy => const _EnergyFocus(),
      AodFocus.media => const _MediaFocus(),
      AodFocus.home => const _HomeFocus(),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Clock(),
          const SizedBox(height: 24),
          const _Weather(),
          if (focusWidget != null) ...[
            const SizedBox(height: 36),
            KeyedSubtree(key: const Key('aodFocus'), child: focusWidget),
          ],
        ],
      ),
    );
  }
}

TextStyle? _focusStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall
        ?.copyWith(color: _dim, fontWeight: FontWeight.w300);

/// Events of all calendars from today on (this month and the next).
List<HaCalendarEvent> _upcoming(WidgetRef ref, DateTime now) {
  final month = DateTime(now.year, now.month);
  return [...?ref.watch(calendarMonthEventsProvider(month)).value]
      .where((e) => e.end.isAfter(now))
      .toList();
}

String _when(AppLocalizations l10n, HaCalendarEvent e, DateTime now) {
  final day = DateUtils.dateOnly(e.start);
  final today = DateUtils.dateOnly(now);
  final dayText = day == today
      ? l10n.aodToday
      : day == today.add(const Duration(days: 1))
      ? l10n.aodTomorrow
      : DateFormat.EEEE(l10n.localeName).format(e.start);
  return e.allDay
      ? dayText
      : '$dayText ${DateFormat.Hm(l10n.localeName).format(e.start)}';
}

class _NextEvent extends ConsumerWidget {
  const _NextEvent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(kioskNowProvider);
    final events = _upcoming(
      ref,
      now,
    ).where((e) => e.start.isBefore(now.add(const Duration(days: 7))));
    // What starts next; if nothing does, what is going on right now.
    final next = events.where((e) => e.start.isAfter(now)).firstOrNull;
    final ongoing = events.where((e) => !e.allDay).firstOrNull;
    final shown = next ?? ongoing;
    final when = shown == null
        ? ''
        : next == null
        ? l10n.aodNowUntil(DateFormat.Hm(l10n.localeName).format(shown.end))
        : _when(l10n, shown, now);
    return Text(
      shown == null
          ? l10n.aodNoEvents
          : '${l10n.aodNextEvent}: ${shown.summary} · $when',
      textAlign: TextAlign.center,
      style: _focusStyle(context),
    );
  }
}

class _ListFocus extends ConsumerWidget {
  const _ListFocus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(
      kioskSettingsProvider.select((s) => s.aodEntityId),
    );
    final lists = ref.watch(todoListsProvider);
    final list =
        lists.where((l) => l.id == chosen).firstOrNull ?? lists.firstOrNull;
    if (list == null) return const SizedBox.shrink();
    final open = [
      for (final i
          in ref.watch(todoItemsProvider(list.id)).value ?? const <TodoItem>[])
        if (!i.completed) i.summary,
    ];
    return Text(
      open.isEmpty
          ? '${list.name}: ${context.l10n.todoOpenCount(0)}'
          : '${list.name}: ${open.take(5).join(', ')}',
      textAlign: TextAlign.center,
      style: _focusStyle(context),
    );
  }
}

class _DeviceFocus extends ConsumerWidget {
  const _DeviceFocus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(kioskSettingsProvider.select((s) => s.aodEntityId));
    final d = id == null ? null : ref.watch(deviceProvider(id));
    if (d == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(DevicePresentation.icon(d), color: _dim, size: 30),
        const SizedBox(width: 12),
        Text(
          '${d.name} · ${DevicePresentation.status(context.l10n, d)}',
          style: _focusStyle(context),
        ),
      ],
    );
  }
}

class _EnergyFocus extends ConsumerWidget {
  const _EnergyFocus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(
      dashboardSummaryProvider.select((s) => s.powerDeviceId),
    );
    final d = id == null ? null : ref.watch(deviceProvider(id));
    if (d == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt, color: _dim, size: 30),
        const SizedBox(width: 8),
        Text(
          DevicePresentation.sensorValue(context.l10n, d.state),
          style: _focusStyle(context),
        ),
      ],
    );
  }
}

class _MediaFocus extends ConsumerWidget {
  const _MediaFocus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(nowPlayingIdProvider);
    final d = id == null ? null : ref.watch(deviceProvider(id));
    final title = d?.state.mediaTitle;
    if (d == null || title == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.music_note, color: _dim, size: 30),
        const SizedBox(width: 8),
        Text(
          [title, ?d.state.mediaArtist].join(' · '),
          style: _focusStyle(context),
        ),
      ],
    );
  }
}

class _HomeFocus extends ConsumerWidget {
  const _HomeFocus();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    width: 760,
    child: Text(
      ref.watch(homeSentenceProvider(context.l10n)),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(color: _dim, fontWeight: FontWeight.w300, height: 1.4),
    ),
  );
}

/// Mornings: the day ahead — weather with today's range, events, and
/// reminders (to-do items due today, from every list).
class _Morning extends ConsumerWidget {
  const _Morning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(kioskNowProvider);
    final today = DateUtils.dateOnly(now);
    final events = [
      for (final e in _upcoming(ref, now))
        if (!DateUtils.dateOnly(e.start).isAfter(today)) e,
    ];
    final reminders = <String>[
      for (final list in ref.watch(todoListsProvider))
        for (final i
            in ref.watch(todoItemsProvider(list.id)).value ??
                const <TodoItem>[])
          if (!i.completed &&
              i.due != null &&
              DateTime.tryParse(i.due!) != null &&
              !DateUtils.dateOnly(DateTime.parse(i.due!).toLocal())
                  .isAfter(today))
            i.summary,
    ];
    final heading = theme.textTheme.titleMedium?.copyWith(
      color: _faint,
      letterSpacing: 1.2,
    );
    final line = theme.textTheme.headlineSmall?.copyWith(
      color: _bright,
      fontWeight: FontWeight.w300,
    );
    // No width limit: the FittedBox around scales the whole day down.
    return KeyedSubtree(
      key: const Key('aodMorning'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.greetingMorning,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: _dim,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 4),
              const _Clock(),
              const SizedBox(height: 20),
              const _Weather(withRange: true),
            ],
          ),
          const SizedBox(width: 72),
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (events.isEmpty && reminders.isEmpty)
                  Text(l10n.morningNothing, style: line),
                if (events.isNotEmpty) ...[
                  Text(l10n.morningToday.toUpperCase(), style: heading),
                  const SizedBox(height: 8),
                  for (final e in events.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        e.allDay
                            ? e.summary
                            : '${DateFormat.Hm(l10n.localeName).format(e.start)}  ${e.summary}',
                        key: ValueKey('aodEvent-${e.summary}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: line,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (reminders.isNotEmpty) ...[
                  Text(l10n.morningReminders.toUpperCase(), style: heading),
                  const SizedBox(height: 8),
                  for (final r in reminders.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radio_button_unchecked,
                            color: _dim,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r,
                              key: ValueKey('aodReminder-$r'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: line,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
