import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/media_providers.dart';
import 'media_player_view.dart';

/// Music and media: pick a player, then play/pause, skip, volume, source
/// and power – without leaving the current screen (also in kiosk mode).
Future<void> showMediaSheet(BuildContext context, {String? playerId}) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MediaSheet(initialPlayerId: playerId),
    );

class MediaSheet extends ConsumerStatefulWidget {
  const MediaSheet({super.key, this.initialPlayerId});

  final String? initialPlayerId;

  @override
  ConsumerState<MediaSheet> createState() => _MediaSheetState();
}

class _MediaSheetState extends ConsumerState<MediaSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ids = ref.watch(mediaPlayerIdsProvider);
    final fallback = widget.initialPlayerId ?? ref.watch(nowPlayingIdProvider);
    final selected = ids.contains(_selected)
        ? _selected!
        : ids.contains(fallback)
        ? fallback!
        : ids.isEmpty
        ? null
        : ids.first;
    final d = selected == null ? null : ref.watch(deviceProvider(selected));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 720,
      ),
      child: SingleChildScrollView(
        key: const Key('mediaSheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ids.isEmpty) ...[
              Text(l10n.mediaTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(l10n.mediaNoPlayers),
            ] else ...[
              // Which player, and its power, above the player itself.
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final id in ids)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Consumer(
                                builder: (context, ref, _) {
                                  final p = ref.watch(deviceProvider(id));
                                  if (p == null) return const SizedBox.shrink();
                                  return ChoiceChip(
                                    key: ValueKey('mediaPlayer-$id'),
                                    avatar: Icon(
                                      DevicePresentation.icon(p),
                                      size: 18,
                                    ),
                                    label: Text(p.name),
                                    selected: id == selected,
                                    onSelected: (_) =>
                                        setState(() => _selected = id),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (d != null && d.supports(Capability.power))
                    IconButton.filledTonal(
                      key: const Key('mediaPower'),
                      tooltip: l10n.powerToggle,
                      isSelected: d.state.isOn == true,
                      onPressed: d.available
                          ? () => runDeviceCommand(
                              context,
                              ref,
                              d,
                              d.state.isOn == true
                                  ? const TurnOff()
                                  : const TurnOn(),
                            )
                          : null,
                      icon: const Icon(Icons.power_settings_new),
                    ),
                ],
              ),
              if (d != null) ...[
                const SizedBox(height: 16),
                if (d.state.isOn == false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${DevicePresentation.status(l10n, d)} · ${l10n.mediaIdle}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                MediaPlayerView(device: d),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
