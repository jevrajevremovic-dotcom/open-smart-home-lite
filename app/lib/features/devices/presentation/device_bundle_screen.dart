import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/widgets/responsive.dart';
import 'device_detail_screen.dart' show EmptyHintPlaceholder;
import '../../appliance_done/appliance_done_section.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../../kiosk/presentation/kiosk_bundle_detail.dart';
import '../application/device_groups.dart';
import '../application/device_providers.dart';
import '../data/home_state_repository.dart';
import '../domain/device_kind.dart';
import 'stale_data_banner.dart';

/// One physical device with all its parts (an air fryer: its main switch,
/// buttons, modes and sensors), as one screen.
class DeviceBundleScreen extends ConsumerWidget {
  const DeviceBundleScreen({super.key, required this.deviceId});

  /// Home Assistant device registry id.
  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visible = ref.watch(visibleDeviceIdsProvider).toSet();
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final members = [
      for (final d in devices.values)
        if (d.deviceId == deviceId && visible.contains(d.id)) d,
    ];
    if (members.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyHintPlaceholder(text: l10n.deviceNotFound),
      );
    }
    final bundle = DeviceBundle(members);
    final kiosk = ref.watch(kioskActiveProvider);
    return Scaffold(
      // The name is in the header below.
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConstrainedContent(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ref.watch(syncStatusProvider) != SyncStatus.live)
                  const StaleDataBanner(padding: EdgeInsets.only(bottom: 12)),
                KioskBundleDetail(
                  bundle: bundle,
                  onOpen: (d) =>
                      context.push(AppRoutes.device(d.id, kiosk: kiosk)),
                ),
                if (members
                        .where((d) => d.kind == DeviceKind.powerMeter)
                        .firstOrNull
                    case final power? when !kiosk) ...[
                  const SizedBox(height: 24),
                  ApplianceDoneSection(power: power),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
