import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/app_theme.dart';
import '../../core/logging/app_logger.dart';
import '../../integrations/home_assistant/api/home_assistant_api.dart';
import '../assist/application/voice_providers.dart';
import '../assist/data/speech_output.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/capability.dart';
import '../devices/domain/smart_home_device.dart';
import 'bedtime_stories.dart';

final _log = AppLogger('Bedtime');

/// Lights of [roomId] that are on or can be dimmed.
List<SmartHomeDevice> bedtimeLights(
  Iterable<SmartHomeDevice> devices,
  String roomId,
) => [
  for (final d in devices)
    if (d.kind.isLight && !d.isAuxiliary && d.available && d.roomId == roomId)
      d,
];

/// Roughly how long [story] takes to read aloud.
Duration readingTime(BedtimeStory story) {
  final words = story.paragraphs.expand((p) => p.split(RegExp(r'\s+'))).length;
  return Duration(milliseconds: words * 450);
}

Future<void> showBedtime(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const _BedtimeSetup(),
);

class _BedtimeSetup extends ConsumerStatefulWidget {
  const _BedtimeSetup();

  @override
  ConsumerState<_BedtimeSetup> createState() => _BedtimeSetupState();
}

class _BedtimeSetupState extends ConsumerState<_BedtimeSetup> {
  String? _room;
  bool _aloud = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final stories = bedtimeStories(
      Localizations.localeOf(context).languageCode,
    );
    final snapshot = ref.watch(homeSnapshotProvider);
    final rooms = [
      for (final r in snapshot.rooms.values)
        if (bedtimeLights(snapshot.devices.values, r.id).isNotEmpty) r,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final speech = ref.watch(speechOutputProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        key: const Key('bedtimeSetup'),
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l10n.bedtimeTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l10n.bedtimeHint),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: const Key('bedtimeRoom'),
            initialValue: _room,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.bedtimeLights),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.bedtimeNoLights)),
              for (final r in rooms)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setState(() => _room = v),
          ),
          if (speech.supported)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.bedtimeAloud),
              value: _aloud,
              onChanged: (v) => setState(() => _aloud = v),
            ),
          const SizedBox(height: 8),
          for (final (i, story) in stories.indexed)
            Card(
              child: ListTile(
                key: ValueKey('bedtimeStory-$i'),
                leading: const Text('🌙', style: TextStyle(fontSize: 28)),
                title: Text(story.title),
                subtitle: Text(
                  l10n.bedtimeMinutes(
                    (readingTime(story).inSeconds / 60).ceil(),
                  ),
                ),
                onTap: () {
                  final navigator = Navigator.of(context);
                  final room = _room;
                  final lights = room == null
                      ? const <SmartHomeDevice>[]
                      : bedtimeLights(snapshot.devices.values, room);
                  final session = _BedtimeSession(
                    story: story,
                    api: ref.read(homeAssistantApiProvider),
                    lights: lights,
                    speech: speech.supported && _aloud ? speech : null,
                    languageTag: l10n.localeName,
                  );
                  navigator.pop();
                  unawaited(
                    showDialog<void>(
                      context: navigator.context,
                      useSafeArea: false,
                      builder: (_) => Theme(
                        data: AppTheme.dark(),
                        child: _BedtimeScreen(session: session),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// What the story screen needs, taken once (the setup sheet is gone by
/// the time the story ends).
class _BedtimeSession {
  _BedtimeSession({
    required this.story,
    required this.api,
    required this.lights,
    required this.speech,
    required this.languageTag,
  });

  final BedtimeStory story;
  final HomeAssistantApi? api;
  final List<SmartHomeDevice> lights;

  /// `null`: read by a grown-up from the screen.
  final SpeechOutput? speech;
  final String languageTag;

  Future<void> _call(String service, Map<String, Object?> data) async {
    try {
      await api?.callService('light', service, data: data);
    } on Object catch (e) {
      _log.warning('light.$service failed', e.runtimeType);
    }
  }

  Future<void> _dimming = Future.value();

  /// A warm, low glow, then slowly down for as long as the story lasts.
  Future<void> dimLights() => _dimming = _dim();

  Future<void> _dim() async {
    for (final l in lights) {
      await _call('turn_on', {
        'entity_id': l.id,
        'brightness_pct': 30,
        if (l.supports(Capability.colorTemperature)) 'color_temp_kelvin': 2200,
      });
    }
    for (final l in lights) {
      await _call('turn_on', {
        'entity_id': l.id,
        'brightness_pct': 1,
        'transition': readingTime(story).inSeconds,
      });
    }
  }

  /// The end: the lights fade out over half a minute.
  Future<void> lightsOut() async {
    // A short story may end before the dimming is sent.
    await _dimming;
    for (final l in lights) {
      await _call('turn_off', {'entity_id': l.id, 'transition': 30});
    }
  }
}

class _BedtimeScreen extends StatefulWidget {
  const _BedtimeScreen({required this.session});

  final _BedtimeSession session;

  @override
  State<_BedtimeScreen> createState() => _BedtimeScreenState();
}

class _BedtimeScreenState extends State<_BedtimeScreen> {
  int _paragraph = 0;
  bool _done = false;
  bool _stopped = false;

  BedtimeStory get _story => widget.session.story;

  @override
  void initState() {
    super.initState();
    unawaited(widget.session.dimLights());
    if (widget.session.speech != null) unawaited(_readAloud());
  }

  @override
  void dispose() {
    _stopped = true;
    unawaited(widget.session.speech?.stop());
    super.dispose();
  }

  Future<void> _readAloud() async {
    final speech = widget.session.speech!;
    await speech
        .speak(_story.title, languageTag: widget.session.languageTag)
        .catchError((Object _) => false);
    for (var i = 0; i < _story.paragraphs.length; i++) {
      if (_stopped || !mounted) return;
      setState(() => _paragraph = i);
      await speech
          .speak(_story.paragraphs[i], languageTag: widget.session.languageTag)
          .catchError((Object _) => false);
    }
    if (mounted && !_stopped) _end();
  }

  void _next() {
    if (_paragraph < _story.paragraphs.length - 1) {
      setState(() => _paragraph++);
    } else {
      _end();
    }
  }

  void _end() {
    setState(() => _done = true);
    unawaited(widget.session.lightsOut());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    const warm = Color(0xFFFFD9A8);
    return Material(
      key: const Key('bedtimeScreen'),
      color: const Color(0xFF0B0B1A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('bedtimeClose'),
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ),
              Text(
                _story.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: warm),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      child: Text(
                        _done
                            ? l10n.bedtimeGoodNight
                            : _story.paragraphs[_paragraph],
                        key: ValueKey(_done ? -1 : _paragraph),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_done && widget.session.speech == null)
                FilledButton.tonal(
                  key: const Key('bedtimeNext'),
                  onPressed: _next,
                  child: Text(
                    _paragraph < _story.paragraphs.length - 1
                        ? l10n.bedtimeNext
                        : l10n.bedtimeEnd,
                  ),
                ),
              if (_done)
                FilledButton.tonal(
                  key: const Key('bedtimeDone'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
