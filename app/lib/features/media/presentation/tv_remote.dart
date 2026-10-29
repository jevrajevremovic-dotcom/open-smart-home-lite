import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_actions.dart';

/// What takes remote keys for TV [tvId]: the TV itself (LG), or the remote
/// entity of the same physical device (Android TV, Samsung, Sony, Roku,
/// Apple TV, Philips).
final tvRemoteProvider = Provider.family<SmartHomeDevice?, String>((ref, tvId) {
  final tv = ref.watch(deviceProvider(tvId));
  if (tv == null) return null;
  if (tv.supports(Capability.tvKeys)) return tv;
  final physical = tv.deviceId;
  if (physical == null) return null;
  return ref.watch(
    homeSnapshotProvider.select((s) {
      for (final d in s.devices.values) {
        if (d.deviceId == physical && d.supports(Capability.tvKeys)) return d;
      }
      return null;
    }),
  );
});

/// A remote control under the TV's player: arrows and OK, back, home and
/// menu, volume and channels — the keys this TV's integration takes.
class TvRemotePad extends ConsumerWidget {
  const TvRemotePad({super.key, required this.tvId});

  final String tvId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(tvRemoteProvider(tvId));
    if (remote == null || remote.limits.tvKeys.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keys = remote.limits.tvKeys;
    final enabled = remote.available;

    void press(TvKey key) {
      HapticFeedback.selectionClick();
      runDeviceCommand(context, ref, remote, PressTvKey(key));
    }

    Widget key(
      TvKey k,
      IconData icon,
      String tooltip, {
      double size = 52,
      bool filled = false,
    }) {
      if (!keys.contains(k)) return SizedBox.square(dimension: size);
      return SizedBox.square(
        dimension: size,
        child: IconButton(
          key: ValueKey('tvKey-${k.name}'),
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: filled
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            foregroundColor: filled ? scheme.onPrimary : scheme.onSurface,
          ),
          onPressed: enabled ? () => press(k) : null,
          icon: Icon(icon),
        ),
      );
    }

    final hasArrows = keys.contains(TvKey.up) && keys.contains(TvKey.ok);
    final nav = [
      (TvKey.back, Icons.arrow_back_rounded, l10n.tvBack),
      (TvKey.home, Icons.home_outlined, l10n.tvHome),
      (TvKey.menu, Icons.menu_rounded, l10n.tvMenu),
      (TvKey.playPause, Icons.play_arrow_rounded, l10n.tvPlayPause),
    ].where((e) => keys.contains(e.$1));

    Widget rocker(
      TvKey up,
      TvKey down,
      String label,
      String upTip,
      String downTip,
    ) {
      if (!keys.contains(up) || !keys.contains(down)) {
        return const SizedBox.shrink();
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('tvKey-${up.name}'),
              tooltip: upTip,
              onPressed: enabled ? () => press(up) : null,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
            Text(label, style: theme.textTheme.labelMedium),
            IconButton(
              key: ValueKey('tvKey-${down.name}'),
              tooltip: downTip,
              onPressed: enabled ? () => press(down) : null,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ),
      );
    }

    return Card(
      key: const Key('tvRemote'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_remote_outlined),
                const SizedBox(width: 8),
                Text(l10n.tvRemote, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            if (hasArrows)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      key(TvKey.up, Icons.keyboard_arrow_up_rounded, l10n.tvUp),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          key(
                            TvKey.left,
                            Icons.keyboard_arrow_left_rounded,
                            l10n.tvLeft,
                          ),
                          const SizedBox(width: 8),
                          key(
                            TvKey.ok,
                            Icons.circle_outlined,
                            l10n.tvOk,
                            size: 64,
                            filled: true,
                          ),
                          const SizedBox(width: 8),
                          key(
                            TvKey.right,
                            Icons.keyboard_arrow_right_rounded,
                            l10n.tvRight,
                          ),
                        ],
                      ),
                      key(
                        TvKey.down,
                        Icons.keyboard_arrow_down_rounded,
                        l10n.tvDown,
                      ),
                    ],
                  ),
                ),
              ),
            if (nav.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [for (final (k, icon, tip) in nav) key(k, icon, tip)],
              ),
            ],
            if (keys.contains(TvKey.volumeUp) ||
                keys.contains(TvKey.channelUp)) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  rocker(
                    TvKey.volumeUp,
                    TvKey.volumeDown,
                    l10n.tvVolume,
                    l10n.mediaVolumeUp,
                    l10n.mediaVolumeDown,
                  ),
                  if (keys.contains(TvKey.mute))
                    key(TvKey.mute, Icons.volume_off_rounded, l10n.mediaMute),
                  rocker(
                    TvKey.channelUp,
                    TvKey.channelDown,
                    l10n.tvChannel,
                    l10n.tvChannelUp,
                    l10n.tvChannelDown,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
