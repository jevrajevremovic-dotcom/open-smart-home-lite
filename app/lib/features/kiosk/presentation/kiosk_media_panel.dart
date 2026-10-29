import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/presentation/device_actions.dart';
import '../../media/application/media_providers.dart';
import '../../media/presentation/media_artwork.dart';
import '../../media/presentation/media_player_view.dart';
import '../../media/presentation/media_sheet.dart';
import 'glass.dart';
import 'kiosk_motion.dart';

/// The music player as a kiosk panel: artwork, what plays, a live
/// position bar, transport and volume, tinted by the artwork. Follows the
/// chosen player, or whatever plays now. Tap the artwork for the full
/// player (other players, source, shuffle, repeat).
class KioskMediaPanel extends ConsumerStatefulWidget {
  const KioskMediaPanel({super.key, this.playerId});

  final String? playerId;

  @override
  ConsumerState<KioskMediaPanel> createState() => _KioskMediaPanelState();
}

class _KioskMediaPanelState extends ConsumerState<KioskMediaPanel> {
  Timer? _tick;
  double? _volume;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Moves the position bar once a second while something plays.
  void _ticker(bool playing) {
    if (playing && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!playing) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ids = ref.watch(mediaPlayerIdsProvider);
    final id =
        widget.playerId ?? ref.watch(nowPlayingIdProvider) ?? ids.firstOrNull;
    final d = id == null ? null : ref.watch(deviceProvider(id));
    if (d == null) {
      return GlassPanel(
        key: const Key('kioskMediaPanel'),
        child: Center(
          child: Text(
            ids.isEmpty ? l10n.mediaNoPlayersShort : l10n.mediaIdle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: GlassColors.muted),
          ),
        ),
      );
    }
    final s = d.state;
    final playing = s.raw == 'playing';
    _ticker(playing && s.mediaDuration != null);
    final on = d.available && s.isOn != false;
    final path = d.metadata.picturePath;
    final tint = path == null
        ? null
        : ref.watch(artworkColorProvider(path)).value;
    const fg = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.75);
    final duration = s.mediaDuration;
    final position = s.positionAt(DateTime.now());
    Future<bool> run(DeviceCommand c) => runDeviceCommand(context, ref, d, c);

    Widget art(double size) => GestureDetector(
      key: const Key('kioskMediaOpen'),
      onTap: () => showMediaSheet(context, playerId: d.id),
      child: MediaArtwork(
        deviceId: d.id,
        size: size,
        radius: 20,
        background: Colors.white.withValues(alpha: 0.12),
        iconColor: Colors.white,
      ),
    );

    final info = <Widget>[
      Row(
        children: [
          if (playing) ...[
            const EqualizerBars(color: fg, height: 16),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              s.mediaTitle ?? d.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      Text(
        s.mediaTitle == null
            ? (playing ? d.name : l10n.mediaIdle)
            : [?s.mediaArtist, d.name].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      ),
      if (duration != null && duration > Duration.zero) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: const Key('kioskMediaProgress'),
            value: ((position ?? Duration.zero).inSeconds / duration.inSeconds)
                .clamp(0.0, 1.0),
            minHeight: 5,
            color: fg,
            backgroundColor: fg.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              formatMediaTime(position ?? Duration.zero),
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
            const Spacer(),
            Text(
              formatMediaTime(duration),
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
      ],
    ];

    final controls = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (d.supports(Capability.mediaPrevious))
          IconButton(
            key: const Key('kioskMediaPrevious'),
            tooltip: l10n.mediaPrevious,
            iconSize: 36,
            color: fg,
            onPressed: on ? () => run(const MediaPrevious()) : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
        if (d.supports(Capability.mediaPause) ||
            d.supports(Capability.mediaPlay))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox.square(
              dimension: 64,
              child: IconButton.filled(
                key: const Key('kioskMediaPlayPause'),
                tooltip: l10n.mediaPlayPause,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: tint ?? BubbleColors.card,
                ),
                iconSize: 38,
                onPressed: on ? () => run(const MediaPlayPause()) : null,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
            ),
          ),
        if (d.supports(Capability.mediaNext))
          IconButton(
            key: const Key('kioskMediaNext'),
            tooltip: l10n.mediaNext,
            iconSize: 36,
            color: fg,
            onPressed: on ? () => run(const MediaNext()) : null,
            icon: const Icon(Icons.skip_next_rounded),
          ),
      ],
    );

    final volume = d.supports(Capability.volume)
        ? Row(
            children: [
              Icon(Icons.volume_mute_rounded, color: muted, size: 20),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: fg,
                    inactiveTrackColor: fg.withValues(alpha: 0.2),
                    thumbColor: fg,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    key: const Key('kioskMediaVolume'),
                    semanticFormatterCallback: (v) =>
                        '${l10n.volume} ${v.round()} %',
                    value: (_volume ?? (s.volumePercent ?? 0).toDouble()).clamp(
                      0,
                      100,
                    ),
                    max: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onChanged: on ? (v) => setState(() => _volume = v) : null,
                    onChangeEnd: on
                        ? (v) async {
                            await run(SetVolume(v.round()));
                            if (mounted) setState(() => _volume = null);
                          }
                        : null,
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded, color: muted, size: 20),
            ],
          )
        : null;

    return GlassPanel(
      key: const Key('kioskMediaPanel'),
      color: tint ?? _defaultTint,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, c) {
          // Wide: artwork on the left. Narrow: artwork above, if room.
          final wide = c.maxWidth > c.maxHeight * 1.25 && c.maxWidth > 360;
          if (wide) {
            final size = (c.maxHeight).clamp(80.0, c.maxWidth * 0.42);
            return Row(
              children: [
                art(size),
                const SizedBox(width: 20),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: c.maxWidth - size - 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...info, controls, ?volume],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          final artSize = (c.maxHeight - 230).clamp(0.0, c.maxWidth);
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: c.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (artSize >= 72) ...[
                    Center(child: art(artSize)),
                    const SizedBox(height: 14),
                  ],
                  ...info,
                  controls,
                  ?volume,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Behind a player without artwork: a deep violet, the media accent.
const Color _defaultTint = Color(0xFF2E2752);
