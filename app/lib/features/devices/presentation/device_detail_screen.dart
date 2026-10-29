import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../favorites/application/favorites_controller.dart';
import '../application/device_providers.dart';
import '../data/local/local_home.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../domain/home_snapshot.dart';
import '../domain/capability.dart';
import '../domain/device_kind.dart';
import '../domain/smart_home_device.dart';
import 'controls/alarm_controls.dart';
import 'controls/climate_controls.dart';
import 'controls/light_controls.dart';
import 'controls/more_controls.dart';
import 'controls/other_controls.dart';
import '../../restricted/application/restricted_mode.dart';
import '../../media/presentation/tv_remote.dart';
import 'device_edit.dart';
import 'device_presentation.dart';
import 'stale_data_banner.dart';
import '../../../core/widgets/skeleton.dart';

/// Details and controls of one device, generated from its capabilities.
class DeviceDetailScreen extends ConsumerWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final device = ref.watch(deviceProvider(deviceId));
    final syncStatus = ref.watch(syncStatusProvider);

    if (device == null) {
      return Scaffold(
        appBar: AppBar(),
        body:
            syncStatus == SyncStatus.initial || syncStatus == SyncStatus.syncing
            ? ListSkeleton(label: l10n.loadingContent)
            : Center(child: Text(l10n.deviceNotFound)),
      );
    }

    if (ref.watch(restrictedModeProvider).hides(device)) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyHintPlaceholder(text: l10n.restrictedHidden),
      );
    }
    final favorite = ref.watch(isFavoriteProvider(deviceId));
    return Scaffold(
      appBar: AppBar(
        title: _DeviceTitle(device: device),
        actions: [
          // Not on the wall panel or for children: organising belongs to
          // the household's phones.
          if (!ref.watch(kioskActiveProvider) &&
              !ref.watch(restrictedModeProvider).enabled) ...[
            IconButton(
              key: const Key('editDevice'),
              tooltip: l10n.editDevice,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => editDevice(context, ref, device),
            ),
            if (isAddedDevice(ref.watch(localHomeProvider), device))
              IconButton(
                key: const Key('removeDevice'),
                tooltip: l10n.deviceRemove,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  if (await removeDevice(context, ref, device) &&
                      navigator.canPop()) {
                    navigator.pop();
                  }
                },
              ),
          ],
          IconButton(
            key: const Key('favoriteToggle'),
            tooltip: favorite ? l10n.removeFavorite : l10n.addFavorite,
            isSelected: favorite,
            icon: const Icon(Icons.star_border),
            selectedIcon: const Icon(Icons.star),
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle(deviceId),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConstrainedContent(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(device: device),
                if (!device.available) ...[
                  const SizedBox(height: 12),
                  InlineNotice.warning(l10n.unavailableBanner),
                ],
                if (syncStatus != SyncStatus.live) ...[
                  const StaleDataBanner(padding: EdgeInsets.only(top: 12)),
                  const SizedBox(height: 8),
                  InlineNotice.info(l10n.controlsOffline),
                ],
                const SizedBox(height: 16),
                // Not live: show the last known values, but no controls.
                IgnorePointer(
                  ignoring: syncStatus != SyncStatus.live,
                  child: Opacity(
                    opacity: syncStatus == SyncStatus.live ? 1 : 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: deviceControlsFor(device),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _InfoSection(device: device),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero tag of a device's icon, from its card to its screen.
String deviceHeroTag(String id) => 'device-icon-$id';

/// The controls for [d] (power, then what its kind needs), as on its
/// screen; also used by the kiosk's detail column.
List<Widget> deviceControlsFor(SmartHomeDevice d) {
  final hasPower = d.supports(Capability.power) && !d.kind.isRoutine;
  return [
    if (hasPower) ...[PowerControl(device: d), const SizedBox(height: 16)],
    ...switch (d.kind) {
      _ when d.kind.isLight => [LightControls(device: d)],
      DeviceKind.thermostat ||
      DeviceKind.climate => [ClimateControls(device: d)],
      DeviceKind.blind ||
      DeviceKind.curtain ||
      DeviceKind.garageDoor ||
      DeviceKind.irrigation => [CoverControls(device: d)],
      DeviceKind.lock => [LockControls(device: d)],
      DeviceKind.alarm => [AlarmControls(device: d)],
      DeviceKind.fan || DeviceKind.airPurifier => [FanControls(device: d)],
      DeviceKind.humidifier ||
      DeviceKind.dehumidifier => [HumidifierControls(device: d)],
      DeviceKind.vacuum => [VacuumControls(device: d)],
      DeviceKind.select => [SelectControls(device: d)],
      DeviceKind.number => [NumberControls(device: d)],
      DeviceKind.mediaPlayer || DeviceKind.speaker || DeviceKind.television => [
        MediaControls(device: d),
        TvRemotePad(tvId: d.id),
      ],
      _ when d.kind.isRoutine || d.kind == DeviceKind.button => [
        RoutineControls(device: d),
      ],
      _ when d.kind.isSensor => [SensorReadout(device: d)],
      _ => const <Widget>[],
    },
  ];
}

class _Header extends StatelessWidget {
  const _Header({required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = context.statusColors;
    final color = DevicePresentation.tone(device).color(
      theme.colorScheme,
      warning: status.warning,
      critical: status.critical,
      unavailable: status.unavailable,
    );
    return Row(
      children: [
        // Flies in from the device's card.
        Hero(
          tag: deviceHeroTag(device.id),
          child: CircleAvatar(
            radius: 32,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              DevicePresentation.icon(device),
              size: 34,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DevicePresentation.status(l10n, device),
                style: theme.textTheme.headlineSmall?.copyWith(color: color),
              ),
              if (device.hasLowBattery)
                Row(
                  children: [
                    Icon(Icons.battery_alert, size: 18, color: status.warning),
                    const SizedBox(width: 4),
                    Text(
                      l10n.lowBattery,
                      style: TextStyle(color: status.warning),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends ConsumerWidget {
  const _InfoSection({required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final room = device.roomId == null
        ? null
        : ref.watch(
            homeSnapshotProvider.select((s) => s.rooms[device.roomId]?.name),
          );
    final m = device.metadata;

    final rows = <(String, String)>[
      if (room != null) (l10n.infoRoom, room),
      if (device.manufacturer != null)
        (l10n.infoManufacturer, device.manufacturer!),
      if (device.model != null) (l10n.infoModel, device.model!),
      (
        l10n.infoProtocol,
        DevicePresentation.protocolLabel(l10n, device.protocol),
      ),
      if (m.batteryPercent != null) (l10n.infoBattery, '${m.batteryPercent} %'),
      if (m.signalStrength != null)
        (
          l10n.infoSignal,
          formatNumber(locale, m.signalStrength!, unit: m.signalUnit),
        ),
      if (m.lastChanged != null)
        (l10n.infoLastChanged, formatDateTime(locale, m.lastChanged!)),
      (l10n.infoEntityId, device.sourceId),
    ];

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.detailInfo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(flex: 3, child: SelectableText(value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyHintPlaceholder extends StatelessWidget {
  const EmptyHintPlaceholder({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            key: const Key('restrictedHidden'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// The device name without a leading room name, with the room below it:
/// "Dnevna soba – ambijent" → "Ambijent" over "Dnevna soba".
class _DeviceTitle extends ConsumerWidget {
  const _DeviceTitle({required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(
      homeSnapshotProvider.select((s) => s.rooms[device.roomId]?.name),
    );
    final name = DevicePresentation.shortName(device.name, room);
    if (room == null) return Text(device.name);
    final theme = Theme.of(context);
    return Semantics(
      label: device.name,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            room,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
