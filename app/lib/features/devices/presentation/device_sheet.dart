import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../application/device_providers.dart';
import '../data/home_state_repository.dart';
import 'device_detail_screen.dart' show deviceControlsFor;
import 'device_history.dart';
import 'device_presentation.dart';

/// A device's main controls in a sheet over the list (a tap on its card),
/// with the way to its full screen.
Future<void> showDeviceSheet(BuildContext context, String deviceId) =>
    showModalBottomSheet<void>(
      context: context,
      // Over the bottom navigation, not under it.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => _DeviceSheet(
        deviceId: deviceId,
        openFull: () {
          Navigator.of(sheet).pop();
          context.push(AppRoutes.device(deviceId));
        },
      ),
    );

class _DeviceSheet extends ConsumerWidget {
  const _DeviceSheet({required this.deviceId, required this.openFull});

  final String deviceId;
  final VoidCallback openFull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = ref.watch(deviceProvider(deviceId));
    if (d == null) return const SizedBox(height: 120);
    final live = ref.watch(syncStatusProvider) == SyncStatus.live;
    final on = DevicePresentation.tone(d) == DeviceTone.active;
    final swatch = on
        ? DevicePresentation.swatch(context.deviceAccents, d)
        : null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        key: const Key('deviceSheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: swatch?.container ?? scheme.surfaceContainer,
                child: Icon(
                  DevicePresentation.icon(d),
                  color: swatch?.onContainer ?? scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      DevicePresentation.status(l10n, d),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('deviceSheetMore'),
                onPressed: openFull,
                child: Text(l10n.deviceSheetMore),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IgnorePointer(
            ignoring: !live,
            child: Opacity(
              opacity: live ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: deviceControlsFor(d),
              ),
            ),
          ),
          // A sensor is mostly its history.
          if (d.kind.isSensor && hasHistory(d)) ...[
            const SizedBox(height: 16),
            DeviceHistorySection(device: d),
          ],
        ],
      ),
    );
  }
}
