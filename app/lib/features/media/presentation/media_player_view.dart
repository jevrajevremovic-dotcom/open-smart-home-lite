import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_actions.dart';
import '../../household/application/household_providers.dart';
import 'media_artwork.dart';

/// The most colourful average of the artwork, darkened to sit behind white
/// text; `null` without artwork (the theme's colours are used then).
final artworkColorProvider = FutureProvider.family<Color?, String>((
  ref,
  path,
) async {
  final bytes = await ref.watch(entityImageProvider(path).future);
  return bytes == null ? null : artworkTint(bytes);
});

/// Averages a 16-pixel-wide copy of the image, weighting saturated pixels,
/// so a mostly grey cover with a red title still tints red.
Future<Color?> artworkTint(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 16);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData();
    frame.image.dispose();
    if (data == null) return null;
    var r = 0.0, g = 0.0, b = 0.0, w = 0.0;
    for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
      final pr = data.getUint8(i) / 255;
      final pg = data.getUint8(i + 1) / 255;
      final pb = data.getUint8(i + 2) / 255;
      final max = [pr, pg, pb].reduce((a, c) => a > c ? a : c);
      final min = [pr, pg, pb].reduce((a, c) => a < c ? a : c);
      final weight = 0.1 + (max - min);
      r += pr * weight;
      g += pg * weight;
      b += pb * weight;
      w += weight;
    }
    if (w == 0) return null;
    final hsl = HSLColor.fromColor(
      Color.from(alpha: 1, red: r / w, green: g / w, blue: b / w),
    );
    // Dark and moderately saturated: white text stays readable (≥ 7:1).
    return hsl
        .withLightness(0.2)
        .withSaturation(hsl.saturation.clamp(0.0, 0.55))
        .toColor();
  } on Object {
    return null;
  }
}

/// `m:ss`, or `h:mm:ss` from an hour on.
String formatMediaTime(Duration d) {
  final s = d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

/// A modern player: large artwork on a background tinted by it, title and
/// artist, a seek bar, big round transport buttons, shuffle and repeat,
/// volume and source.
class MediaPlayerView extends ConsumerStatefulWidget {
  const MediaPlayerView({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  ConsumerState<MediaPlayerView> createState() => _MediaPlayerViewState();
}

class _MediaPlayerViewState extends ConsumerState<MediaPlayerView> {
  Timer? _tick;
  double? _seeking;
  double? _volume;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(MediaPlayerView old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  /// Moves the position bar once a second, only while playing.
  void _syncTicker() {
    final playing =
        widget.device.state.raw == 'playing' &&
        widget.device.state.mediaDuration != null;
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
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<bool> _run(DeviceCommand c) =>
      runDeviceCommand(context, ref, widget.device, c);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = widget.device;
    final s = d.state;
    final on = d.available && s.isOn != false;
    final playing = s.raw == 'playing';
    final path = d.metadata.picturePath;
    final tint = path == null
        ? null
        : ref.watch(artworkColorProvider(path)).value;
    // On the tint everything is white; without artwork the theme decides.
    final fg = tint == null ? theme.colorScheme.onSurface : Colors.white;
    final muted = tint == null
        ? theme.colorScheme.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.75);
    final accent = tint == null ? theme.colorScheme.primary : Colors.white;
    final onAccent = tint ?? theme.colorScheme.onPrimary;

    final duration = s.mediaDuration;
    final position = s.positionAt(DateTime.now());
    final canSeek = d.supports(Capability.mediaSeek) && on;
    final subtitle = [
      ?s.mediaArtist,
      ?s.mediaAlbum,
    ].where((t) => t.isNotEmpty).toSet().join(' · ');

    Widget round(
      String key,
      IconData icon,
      String tip,
      VoidCallback? onPressed, {
      double size = 30,
      bool selected = false,
    }) => IconButton(
      key: Key(key),
      tooltip: tip,
      iconSize: size,
      isSelected: selected,
      color: selected ? accent : fg,
      disabledColor: muted.withValues(alpha: 0.4),
      onPressed: onPressed,
      icon: Icon(icon),
    );

    final repeat = s.repeat ?? 'off';
    // A choice (source, sound mode) in the player's colours.
    Widget choice({
      required Key key,
      required String label,
      required IconData icon,
      required String? value,
      required List<String> options,
      required void Function(String) onChanged,
    }) => Theme(
      data: tint == null
          ? theme
          : theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                onSurface: Colors.white,
                onSurfaceVariant: muted,
              ),
              canvasColor: Color.lerp(tint, Colors.black, 0.2),
            ),
      child: DropdownButtonFormField<String>(
        key: key,
        initialValue: options.contains(value) ? value : null,
        iconEnabledColor: fg,
        style: theme.textTheme.bodyLarge?.copyWith(color: fg),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: muted),
          prefixIcon: Icon(icon, color: muted),
          filled: true,
          fillColor: fg.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: fg.withValues(alpha: 0.5)),
          ),
        ),
        items: [
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: on ? (v) => v == null ? null : onChanged(v) : null,
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final size = (c.maxWidth * 0.8).clamp(160.0, 320.0);
            return Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: MediaArtwork(
                  deviceId: d.id,
                  size: size,
                  radius: 28,
                  background: tint == null
                      ? theme.colorScheme.secondaryContainer
                      : Colors.white.withValues(alpha: 0.12),
                  iconColor: tint == null
                      ? theme.colorScheme.onSecondaryContainer
                      : Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          s.mediaTitle ?? d.name,
          key: const Key('mediaTitle'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: muted,
              fontWeight: FontWeight.w400,
            ),
          ),
        if (duration != null && duration > Duration.zero) ...[
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: accent,
              inactiveTrackColor: fg.withValues(alpha: 0.2),
              disabledActiveTrackColor: accent,
              disabledInactiveTrackColor: fg.withValues(alpha: 0.2),
              thumbColor: accent,
              disabledThumbColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              key: const Key('mediaSeek'),
              semanticFormatterCallback: (v) =>
                  '${l10n.mediaSeek} ${formatMediaTime(Duration(seconds: v.round()))}',
              value:
                  (_seeking ?? (position ?? Duration.zero).inSeconds.toDouble())
                      .clamp(0, duration.inSeconds.toDouble()),
              max: duration.inSeconds.toDouble(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              onChanged: canSeek ? (v) => setState(() => _seeking = v) : null,
              onChangeEnd: canSeek
                  ? (v) async {
                      await _run(MediaSeek(Duration(seconds: v.round())));
                      if (mounted) setState(() => _seeking = null);
                    }
                  : null,
            ),
          ),
          Row(
            children: [
              Text(
                formatMediaTime(
                  Duration(
                    seconds: (_seeking ?? (position ?? Duration.zero).inSeconds)
                        .round(),
                  ),
                ),
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
              const Spacer(),
              Text(
                '-${formatMediaTime(duration - Duration(seconds: (_seeking ?? (position ?? Duration.zero).inSeconds).round()))}',
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (d.supports(Capability.shuffle))
              round(
                'mediaShuffle',
                Icons.shuffle_rounded,
                l10n.mediaShuffle,
                on ? () => _run(SetShuffle(!(s.shuffle ?? false))) : null,
                size: 24,
                selected: s.shuffle == true,
              ),
            if (d.supports(Capability.mediaPrevious))
              round(
                'mediaPrevious',
                Icons.skip_previous_rounded,
                l10n.mediaPrevious,
                on ? () => _run(const MediaPrevious()) : null,
                size: 40,
              ),
            if (d.supports(Capability.mediaPause) ||
                d.supports(Capability.mediaPlay))
              SizedBox.square(
                dimension: 76,
                child: IconButton.filled(
                  key: const Key('mediaPlayPause'),
                  tooltip: l10n.mediaPlayPause,
                  style: IconButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                  ),
                  iconSize: 44,
                  onPressed: on ? () => _run(const MediaPlayPause()) : null,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
              ),
            if (d.supports(Capability.mediaNext))
              round(
                'mediaNext',
                Icons.skip_next_rounded,
                l10n.mediaNext,
                on ? () => _run(const MediaNext()) : null,
                size: 40,
              ),
            if (d.supports(Capability.repeat))
              round(
                'mediaRepeat',
                repeat == 'one'
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                switch (repeat) {
                  'all' => l10n.mediaRepeatAll,
                  'one' => l10n.mediaRepeatOne,
                  _ => l10n.mediaRepeatOff,
                },
                on
                    ? () => _run(
                        SetRepeat(switch (repeat) {
                          'off' => 'all',
                          'all' => 'one',
                          _ => 'off',
                        }),
                      )
                    : null,
                size: 24,
                selected: repeat != 'off',
              ),
          ],
        ),
        if (d.supports(Capability.volume) ||
            d.supports(Capability.volumeStep) ||
            d.supports(Capability.mute)) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (d.supports(Capability.mute))
                IconButton(
                  key: const Key('mediaMute'),
                  tooltip: s.isMuted == true
                      ? l10n.mediaUnmute
                      : l10n.mediaMute,
                  color: s.isMuted == true ? fg : muted,
                  isSelected: s.isMuted == true,
                  icon: const Icon(Icons.volume_up_rounded),
                  selectedIcon: const Icon(Icons.volume_off_rounded),
                  onPressed: on ? () => _run(SetMute(s.isMuted != true)) : null,
                )
              else if (d.supports(Capability.volume))
                Icon(Icons.volume_mute_rounded, color: muted),
              if (d.supports(Capability.volume))
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: fg,
                      inactiveTrackColor: fg.withValues(alpha: 0.2),
                      thumbColor: fg,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      key: const Key('mediaVolume'),
                      semanticFormatterCallback: (v) =>
                          '${l10n.volume} ${v.round()} %',
                      value: (_volume ?? (s.volumePercent ?? 0).toDouble())
                          .clamp(0, 100),
                      max: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onChanged: on ? (v) => setState(() => _volume = v) : null,
                      onChangeEnd: on
                          ? (v) async {
                              await _run(SetVolume(v.round()));
                              if (mounted) setState(() => _volume = null);
                            }
                          : null,
                    ),
                  ),
                )
              else
                const Spacer(),
              // Without a level (many TVs): one step at a time.
              if (d.supports(Capability.volumeStep) &&
                  !d.supports(Capability.volume)) ...[
                Text(
                  l10n.volume,
                  style: theme.textTheme.labelLarge?.copyWith(color: muted),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('mediaVolumeDown'),
                  tooltip: l10n.mediaVolumeDown,
                  onPressed: on
                      ? () => _run(const StepVolume(up: false))
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton.filledTonal(
                  key: const Key('mediaVolumeUp'),
                  tooltip: l10n.mediaVolumeUp,
                  onPressed: on ? () => _run(const StepVolume(up: true)) : null,
                  icon: const Icon(Icons.add),
                ),
              ] else if (d.supports(Capability.volume))
                Icon(Icons.volume_up_rounded, color: muted),
            ],
          ),
        ],
        if (d.supports(Capability.sourceSelection) &&
            d.limits.sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          choice(
            key: const Key('mediaSource'),
            label: l10n.mediaSource,
            icon: Icons.input_rounded,
            value: s.source,
            options: d.limits.sources,
            onChanged: (v) => _run(SelectSource(v)),
          ),
        ],
        if (d.supports(Capability.soundMode) &&
            d.limits.soundModes.isNotEmpty) ...[
          const SizedBox(height: 12),
          choice(
            key: const Key('mediaSoundMode'),
            label: l10n.mediaSoundMode,
            icon: Icons.graphic_eq_rounded,
            value: s.soundMode,
            options: d.limits.soundModes,
            onChanged: (v) => _run(SelectSoundMode(v)),
          ),
        ],
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(tint, Colors.white, 0.08)!,
                  Color.lerp(tint, Colors.black, 0.35)!,
                ],
              ),
      ),
      padding: tint == null
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: content,
    );
  }
}
