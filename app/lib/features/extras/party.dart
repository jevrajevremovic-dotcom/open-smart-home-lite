import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/app_theme.dart';
import '../../core/logging/app_logger.dart';
import '../../integrations/home_assistant/api/home_assistant_api.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/capability.dart';
import '../devices/domain/smart_home_device.dart';
import '../kiosk/presentation/kiosk_motion.dart';
import '../media/application/media_providers.dart';

final _log = AppLogger('Party');

/// Lights that take a colour.
List<SmartHomeDevice> partyLights(Iterable<SmartHomeDevice> devices) => [
  for (final d in devices)
    if (d.kind.isLight &&
        d.available &&
        !d.isAuxiliary &&
        (d.supports(Capability.rgb) ||
            d.supports(Capability.rgbw) ||
            d.supports(Capability.hsColor)))
      d,
]..sort((a, b) => a.name.compareTo(b.name));

/// What one light looked like before the party, to put back.
typedef _Before = ({bool on, int? brightness, int? kelvin, RgbColor? rgb});

/// Colour lights change colour every [step], each a little behind the one
/// before, while the party screen is open; music plays if chosen. On stop
/// every light goes back to how it was.
class PartyRunner {
  /// [api] is taken once: the screen that starts the party is gone by
  /// the time it ends.
  PartyRunner(this._api, this.lights, {this.playerId});

  static const step = Duration(milliseconds: 2500);

  final HomeAssistantApi? _api;
  final List<SmartHomeDevice> lights;
  final String? playerId;
  final _before = <String, _Before>{};
  Timer? _timer;
  int _tick = 0;

  /// The last round of colours, still on its way.
  Future<void> _inFlight = Future.value();

  Future<void> start() async {
    for (final l in lights) {
      final s = l.state;
      _before[l.id] = (
        on: s.isOn == true,
        brightness: s.brightnessPercent,
        kelvin: s.colorTemperatureKelvin,
        rgb: s.rgb,
      );
    }
    if (playerId != null) {
      await _call('media_player', 'media_play', {'entity_id': playerId});
    }
    await _colour();
    _timer = Timer.periodic(step, (_) => _colour());
  }

  /// Hue around the circle; lights spread around it.
  Future<void> _colour() async {
    _tick++;
    final calls = <Future<void>>[];
    for (var i = 0; i < lights.length; i++) {
      final hue = ((_tick * 47) + i * (360 / lights.length)) % 360;
      final c = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
      calls.add(
        _call('light', 'turn_on', {
          'entity_id': lights[i].id,
          'rgb_color': [
            (c.r * 255).round(),
            (c.g * 255).round(),
            (c.b * 255).round(),
          ],
          'brightness_pct': 100,
          'transition': 1,
        }),
      );
    }
    _inFlight = Future.wait(calls);
    await _inFlight;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    // Colours still on their way must not land after the restore.
    await _inFlight;
    for (final e in _before.entries) {
      final b = e.value;
      if (!b.on) {
        await _call('light', 'turn_off', {'entity_id': e.key});
        continue;
      }
      await _call('light', 'turn_on', {
        'entity_id': e.key,
        'brightness_pct': ?b.brightness,
        if (b.kelvin != null)
          'color_temp_kelvin': b.kelvin
        else if (b.rgb != null)
          'rgb_color': [b.rgb!.red, b.rgb!.green, b.rgb!.blue],
      });
    }
    _before.clear();
  }

  Future<void> _call(
    String domain,
    String service,
    Map<String, Object?> data,
  ) async {
    try {
      await _api?.callService(domain, service, data: data);
    } on Object catch (e) {
      _log.warning('$domain.$service failed', e.runtimeType);
    }
  }
}

/// Chooses the lights and the music, then the party screen.
Future<void> showParty(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const _PartySetup(),
);

class _PartySetup extends ConsumerStatefulWidget {
  const _PartySetup();

  @override
  ConsumerState<_PartySetup> createState() => _PartySetupState();
}

class _PartySetupState extends ConsumerState<_PartySetup> {
  Set<String>? _chosen;
  String? _player;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final lights = partyLights(devices.values);
    final chosen = _chosen ??= {for (final l in lights) l.id};
    final players = [
      for (final id in ref.watch(mediaPlayerIdsProvider)) ?devices[id],
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        key: const Key('partySetup'),
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l10n.partyTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(lights.isEmpty ? l10n.partyNoLights : l10n.partyHint),
          for (final l in lights)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: chosen.contains(l.id),
              title: Text(l.name),
              onChanged: (v) => setState(
                () => v == true ? chosen.add(l.id) : chosen.remove(l.id),
              ),
            ),
          if (players.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _player,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.partyMusic),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.partyNoMusic)),
                for (final p in players)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _player = v),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('partyStart'),
            onPressed: chosen.isEmpty
                ? null
                : () {
                    final navigator = Navigator.of(context);
                    final runner = PartyRunner(
                      ref.read(homeAssistantApiProvider),
                      [
                        for (final l in lights)
                          if (chosen.contains(l.id)) l,
                      ],
                      playerId: _player,
                    );
                    navigator.pop();
                    unawaited(
                      showDialog<void>(
                        context: navigator.context,
                        barrierDismissible: false,
                        useSafeArea: false,
                        builder: (_) => Theme(
                          data: AppTheme.dark(),
                          child: _PartyScreen(runner: runner),
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.celebration_outlined),
            label: Text(l10n.partyStart),
          ),
        ],
      ),
    );
  }
}

/// Full screen while the party runs: colours and dancing bars, one big
/// button to stop (everything goes back as it was).
class _PartyScreen extends ConsumerStatefulWidget {
  const _PartyScreen({required this.runner});

  final PartyRunner runner;

  @override
  ConsumerState<_PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends ConsumerState<_PartyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hue = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.runner.start());
    _hue.repeat();
  }

  @override
  void dispose() {
    // Closed some other way (the wall panel going back to its start):
    // the lights must not keep dancing.
    if (!_stopping) unawaited(widget.runner.stop());
    _hue.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    final navigator = Navigator.of(context);
    await widget.runner.stop();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final moving = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_stop());
      },
      child: Material(
        key: const Key('partyScreen'),
        child: AnimatedBuilder(
          animation: _hue,
          builder: (context, child) {
            final h = moving ? _hue.value * 360 : 300.0;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HSVColor.fromAHSV(1, h, 0.7, 0.35).toColor(),
                    HSVColor.fromAHSV(1, (h + 120) % 360, 0.7, 0.25).toColor(),
                    HSVColor.fromAHSV(1, (h + 240) % 360, 0.7, 0.35).toColor(),
                  ],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EqualizerBars(color: Colors.white, height: 120),
                  const SizedBox(height: 32),
                  Text(
                    l10n.partyOn,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.partyLights(widget.runner.lights.length),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    key: const Key('partyStop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                    ),
                    onPressed: _stopping ? null : _stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(l10n.partyStop),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
