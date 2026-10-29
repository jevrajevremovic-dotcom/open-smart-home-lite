part of 'dashboard_screen.dart';

class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConnectionStatusChip(
    status:
        ref.watch(connectionStatusProvider).value ?? HaConnectionStatus.initial,
  );
}

/// Shown only when something is wrong with the connection.
class ConnectionProblemCard extends ConsumerWidget {
  const ConnectionProblemCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status =
        ref.watch(connectionStatusProvider).value ?? HaConnectionStatus.initial;
    final connecting =
        status.state == HaConnectionState.connecting ||
        status.state == HaConnectionState.authenticating;
    if (status.isConnected || connecting) return const SizedBox.shrink();

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status.failure != null)
              InlineNotice.warning(failureMessage(l10n, status.failure!)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: status.isTerminal
                  ? FilledButton.icon(
                      onPressed: () => ref
                          .read(sessionControllerProvider.notifier)
                          .signOut(),
                      icon: const Icon(Icons.login),
                      label: Text(l10n.signInAgain),
                    )
                  : OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(webSocketManagerProvider)?.retryNow(),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retryNow),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CriticalAlertsBanner extends ConsumerWidget {
  const CriticalAlertsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(
      dashboardSummaryProvider.select((s) => s.criticalIds),
    );
    if (ids.isEmpty) return const SizedBox.shrink();
    final colors = context.statusColors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card.filled(
        color: colors.critical,
        child: Column(
          children: [
            for (final id in ids)
              Consumer(
                builder: (context, ref, _) {
                  final d = ref.watch(deviceProvider(id));
                  if (d == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: Icon(
                      DevicePresentation.icon(d),
                      color: colors.onCritical,
                    ),
                    title: Text(
                      d.name,
                      style: TextStyle(
                        color: colors.onCritical,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      DevicePresentation.status(context.l10n, d),
                      style: TextStyle(color: colors.onCritical),
                    ),
                    onTap: () => context.push(
                      AppRoutes.device(
                        id,
                        kiosk: ref.read(kioskActiveProvider),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class SceneButtons extends ConsumerWidget {
  const SceneButtons({super.key, required this.sceneIds});

  final List<String> sceneIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in sceneIds)
          Consumer(
            builder: (context, ref, _) {
              final d = ref.watch(deviceProvider(id));
              if (d == null) return const SizedBox.shrink();
              return ActionChip(
                avatar: SceneSwatch(
                  sceneId: id,
                  icon: Icons.play_arrow,
                  size: 24,
                  fallback: Colors.transparent,
                ),
                label: Text(d.name),
                onPressed: d.available
                    ? () async {
                        final messenger = ScaffoldMessenger.of(context);
                        if (await runDeviceCommand(
                          context,
                          ref,
                          d,
                          const Activate(),
                        )) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(l10n.sceneActivated(d.name)),
                            ),
                          );
                        }
                      }
                    : null,
              );
            },
          ),
      ],
    );
  }
}

class AttentionSection extends ConsumerWidget {
  const AttentionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(dashboardSummaryProvider);
    if (s.lowBatteryIds.isEmpty && s.unavailableIds.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = context.statusColors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card.outlined(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Icon(Icons.build_circle_outlined, color: colors.warning),
          title: Text(l10n.dashboardAttention),
          subtitle: Text(
            [
              if (s.lowBatteryIds.isNotEmpty)
                l10n.lowBatteryCount(s.lowBatteryIds.length),
              if (s.unavailableIds.isNotEmpty)
                l10n.unavailableCount(s.unavailableIds.length),
            ].join(' · '),
          ),
          children: [
            for (final id in [...s.lowBatteryIds, ...s.unavailableIds])
              Consumer(
                builder: (context, ref, _) {
                  final d = ref.watch(deviceProvider(id));
                  if (d == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: Icon(
                      d.available ? Icons.battery_alert : Icons.cloud_off,
                      color: colors.warning,
                    ),
                    title: Text(d.name),
                    subtitle: Text(
                      d.available && d.metadata.batteryPercent != null
                          ? l10n.batteryLevel(d.metadata.batteryPercent!)
                          : DevicePresentation.status(l10n, d),
                    ),
                    onTap: () => context.push(
                      AppRoutes.device(
                        id,
                        kiosk: ref.read(kioskActiveProvider),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The media player that is playing, with play/pause.
class NowPlayingCard extends ConsumerWidget {
  const NowPlayingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final id = ref.watch(nowPlayingIdProvider);
    final hasPlayers = ref.watch(
      mediaPlayerIdsProvider.select((ids) => ids.isNotEmpty),
    );
    final d = id == null ? null : ref.watch(deviceProvider(id));
    // Always present, so it's clear where music lives; without players
    // the sheet explains what to add in Home Assistant.
    final scheme = theme.colorScheme;
    final playing = d?.state.raw == 'playing';
    final path = d?.metadata.picturePath;
    // Tinted by the artwork, like the full player.
    final tint = path == null
        ? null
        : ref.watch(artworkColorProvider(path)).value;
    final fg = tint == null ? scheme.onSurface : Colors.white;
    final muted = tint == null
        ? scheme.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.75);
    final duration = d?.state.mediaDuration;
    final position = d?.state.positionAt(DateTime.now());
    final progress =
        duration == null || position == null || duration.inSeconds == 0
        ? null
        : (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        key: const Key('nowPlayingCard'),
        color: tint,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showMediaSheet(context, playerId: d?.id),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    if (d != null)
                      MediaArtwork(deviceId: d.id, size: 56, radius: 16)
                    else
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: scheme.secondaryContainer,
                        child: Icon(
                          Icons.music_note,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d == null
                                ? l10n.mediaTitle
                                : d.state.mediaTitle ?? d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: fg,
                            ),
                          ),
                          Text(
                            d == null
                                ? (hasPlayers
                                      ? l10n.mediaIdle
                                      : l10n.mediaNoPlayersShort)
                                : [?d.state.mediaArtist, d.name].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (d != null && d.supports(Capability.mediaPause))
                      IconButton.filled(
                        tooltip: l10n.mediaPlayPause,
                        style: IconButton.styleFrom(
                          backgroundColor: tint == null
                              ? scheme.primary
                              : Colors.white,
                          foregroundColor: tint ?? scheme.onPrimary,
                        ),
                        iconSize: 30,
                        onPressed: () => runDeviceCommand(
                          context,
                          ref,
                          d,
                          const MediaPlayPause(),
                        ),
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      )
                    else
                      Icon(Icons.chevron_right, color: muted),
                  ],
                ),
              ),
              if (progress != null)
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  color: fg,
                  backgroundColor: fg.withValues(alpha: 0.15),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
