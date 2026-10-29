import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../authentication/application/session_controller.dart';
import '../../clap/clap_platform.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../application/voice_providers.dart';
import '../../timers/kiosk_timers.dart' show timerLabel;
import '../../timers/kitchen_timers.dart';
import '../data/wake_word.dart';

enum _Phase { command, answer, notUnderstood, missing }

/// Hands-free Assist on the kiosk: while the kiosk is shown (and the option
/// is on) the microphone streams to Home Assistant, whose wake word engine
/// listens. After the wake word a card shows what was heard and the answer,
/// which is also spoken.
///
/// Runs follow each other: a run ends after an answer or Home Assistant's
/// pipeline timeout and the next one starts. Without a wake word engine in
/// Home Assistant it stops and says so (until the kiosk is opened again).
class KioskWakeWordListener extends ConsumerStatefulWidget {
  const KioskWakeWordListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskWakeWordListener> createState() =>
      _KioskWakeWordListenerState();
}

class _KioskWakeWordListenerState extends ConsumerState<KioskWakeWordListener> {
  static final _log = AppLogger('WakeWord');

  /// Codes that end a run normally (no backoff before the next one).
  static const _normalEnds = {'timeout', 'wake-word-timeout'};

  StreamSubscription<Uint8List>? _mic;
  StreamSubscription<WakeRunEvent>? _run;
  Completer<void>? _runDone;
  final _audio = StreamController<Uint8List>.broadcast();
  bool _running = false;
  int _generation = 0;
  bool _missing = false;
  bool _foreground = true;

  _Phase? _phase;
  String _heard = '';
  String _answer = '';
  Timer? _hide;

  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onShow: () => _setForeground(true),
    onHide: () => _setForeground(false),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // start observing
  }

  void _setForeground(bool v) {
    if (_foreground == v) return;
    setState(() => _foreground = v);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _hide?.cancel();
    _stop();
    unawaited(_audio.close());
    super.dispose();
  }

  void _sync(bool active) {
    if (active == _running) return;
    _running = active;
    if (!active) {
      _stop();
      return;
    }
    _missing = false;
    final generation = ++_generation;
    _mic = ref
        .read(clapPlatformProvider)
        .pcm()
        .listen(
          _audio.add,
          onError: (Object e) {
            // E.g. permission withdrawn in system settings.
            _log.warning('microphone unavailable', e.runtimeType);
            _mic = null;
          },
          cancelOnError: true,
        );
    unawaited(_loop(generation));
  }

  void _stop() {
    _generation++;
    unawaited(_mic?.cancel());
    _mic = null;
    unawaited(_run?.cancel());
    _run = null;
    if (_runDone?.isCompleted == false) _runDone!.complete();
  }

  Future<void> _loop(int generation) async {
    var failures = 0;
    while (mounted && generation == _generation) {
      final ws = ref.read(webSocketManagerProvider);
      if (ws == null) return;
      String? error;
      var woke = false;
      WakeAnswer? answer;
      Duration? timer;
      final done = _runDone = Completer<void>();
      _run = runWakeWordPipeline(ws, _audio.stream).listen(
        (event) {
          switch (event) {
            case WakeListening():
              break;
            case WakeDetected():
              woke = true;
              _show(_Phase.command);
            case WakeHeard(:final text):
              timer = parseTimerCommand(text);
              if (mounted) setState(() => _heard = text);
            case WakeAnswer():
              answer = event;
            case WakeRunError(:final code):
              error = code;
          }
        },
        onError: (Object e) {
          error = e is AppFailure && e.code != null ? e.code : 'failed';
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
      _run = null;
      if (!mounted || generation != _generation) return;

      if (wakeWordSetupErrors.contains(error)) {
        _missing = true;
        // No point keeping the microphone on.
        unawaited(_mic?.cancel());
        _mic = null;
        _show(_Phase.missing);
        return;
      }
      if (timer case final duration?) {
        // Timers run on the tablet; Home Assistant's own answer (it has no
        // timers for this device) is replaced.
        await ref.read(kitchenTimersProvider.notifier).start(duration);
        if (!mounted) return;
        await _speakText(context.l10n.timerStarted(timerLabel(duration)));
      } else if (answer case final a?) {
        await _speakAnswer(a);
      } else if (woke) {
        _show(_Phase.notUnderstood);
      }
      if (!mounted || generation != _generation) return;
      if (error != null && !woke && !_normalEnds.contains(error)) {
        // Connection trouble or a broken pipeline: retry, slower each time.
        failures++;
        _log.info('run failed: $error');
        await Future<void>.delayed(
          Duration(seconds: min(60, 1 << min(failures, 6))),
        );
      } else {
        failures = 0;
      }
    }
  }

  Future<void> _speakAnswer(WakeAnswer a) {
    final l10n = context.l10n;
    final speech = a.reply.speech;
    return _speakText(
      speech,
      shown: speech.isEmpty
          ? (a.reply.isError ? l10n.assistNotUnderstood : '✓')
          : speech,
    );
  }

  Future<void> _speakText(String speech, {String? shown}) async {
    final l10n = context.l10n;
    _answer = shown ?? speech;
    _show(_Phase.answer);
    final out = ref.read(speechOutputProvider);
    if (speech.isNotEmpty && out.supported && ref.read(assistSpeakProvider)) {
      // Not listening meanwhile: the tablet would hear itself.
      await out
          .speak(speech, languageTag: l10n.localeName)
          .catchError((Object _) => false);
    }
  }

  void _show(_Phase phase) {
    if (!mounted) return;
    _hide?.cancel();
    setState(() {
      _phase = phase;
      if (phase == _Phase.command) {
        _heard = '';
        _answer = '';
      }
    });
    // Seen from across the room, the screen must be awake.
    if (ref.read(kioskDimmedProvider)) {
      ref.read(kioskDimmedProvider.notifier).set(false);
    }
    final after = switch (phase) {
      _Phase.command => const Duration(seconds: 20),
      _Phase.answer => const Duration(seconds: 8),
      _Phase.notUnderstood => const Duration(seconds: 4),
      _Phase.missing => const Duration(seconds: 15),
    };
    _hide = Timer(after, _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted && _phase != null) setState(() => _phase = null);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(kioskSettingsProvider);
    final platform = ref.watch(clapPlatformProvider);
    final connected = ref.watch(
      connectionStatusProvider.select((s) => s.value?.isConnected ?? false),
    );
    final active =
        platform.supported &&
        settings.wakeWordEnabled &&
        ref.watch(kioskActiveProvider) &&
        connected &&
        _foreground &&
        ref.watch(assistOpenProvider) == 0;
    _sync(active);
    final l10n = context.l10n;
    final phase = _phase;
    return Stack(
      children: [
        widget.child,
        if (settings.wakeWordEnabled && platform.supported)
          Positioned(
            left: 8,
            bottom: 8,
            child: SafeArea(
              child: Material(
                type: MaterialType.transparency,
                child: Tooltip(
                  message: _missing
                      ? l10n.wakeWordMissing
                      : l10n.wakeWordActive,
                  child: InkResponse(
                    key: const Key('wakeIndicator'),
                    radius: 20,
                    onTap: _missing ? () => _show(_Phase.missing) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _missing || !active
                            ? Icons.mic_off_outlined
                            : Icons.mic_none_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (phase != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              child: Center(
                // The kiosk is dark, whatever the app theme.
                child: Theme(
                  data: AppTheme.dark(),
                  child: _WakeCard(
                    phase: phase,
                    heard: _heard,
                    answer: _answer,
                    onTap: _dismiss,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WakeCard extends StatelessWidget {
  const _WakeCard({
    required this.phase,
    required this.heard,
    required this.answer,
    required this.onTap,
  });

  final _Phase phase;
  final String heard;
  final String answer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = switch (phase) {
      _Phase.command => (Icons.graphic_eq_rounded, scheme.primary),
      _Phase.answer => (Icons.assistant_outlined, scheme.primary),
      _Phase.notUnderstood => (Icons.hearing_disabled_outlined, scheme.error),
      _Phase.missing => (Icons.mic_off_outlined, scheme.error),
    };
    final main = switch (phase) {
      _Phase.command => heard.isEmpty ? l10n.assistListening : heard,
      _Phase.answer => answer,
      _Phase.notUnderstood => l10n.voiceNoMatch,
      _Phase.missing => l10n.wakeWordMissing,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Material(
        key: const Key('wakeOverlay'),
        color: scheme.surfaceContainerHigh,
        elevation: 8,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 24, 18),
            child: Row(
              children: [
                Icon(icon, size: 36, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (phase == _Phase.answer && heard.isNotEmpty)
                        Text(
                          heard,
                          key: const Key('wakeHeard'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        main,
                        key: const Key('wakeText'),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: phase == _Phase.missing
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
