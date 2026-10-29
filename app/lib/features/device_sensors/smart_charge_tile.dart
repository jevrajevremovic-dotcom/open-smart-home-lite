import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../ha_notify/ha_push.dart';
import 'device_sensors.dart';

/// Creates the "keep the battery between 40 and 80 %" automation in Home
/// Assistant for this device's charger plug.
class SmartChargeTile extends ConsumerStatefulWidget {
  const SmartChargeTile({super.key});

  @override
  ConsumerState<SmartChargeTile> createState() => _SmartChargeTileState();
}

class _SmartChargeTileState extends ConsumerState<SmartChargeTile> {
  static const _low = 40;
  static const _high = 80;
  String? _plug;
  bool _busy = false;

  Future<void> _create(String battery, String deviceName) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(homeAssistantApiProvider);
    final plug = _plug;
    if (api == null || plug == null) return;
    setState(() => _busy = true);
    final alias = l10n.smartChargeAlias(deviceName);
    try {
      await api.saveAutomation(
        'osh_charge_${haSlug(deviceName)}',
        chargeAutomation(
          alias: alias,
          battery: battery,
          plug: plug,
          low: _low,
          high: _high,
        ),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.smartChargeDone(alias))),
      );
    } on AppFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.kind == FailureKind.authorization
                ? l10n.smartChargeNeedsAdmin
                : failureMessage(l10n, e),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final battery = ref.watch(deviceBatteryEntityProvider);
    final registration = ref.watch(haPushProvider).value;
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final plugs =
        devices.values
            .where(
              (d) =>
                  d.kind == DeviceKind.outlet ||
                  d.kind == DeviceKind.switchDevice,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.smartChargeTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.smartChargeHint(_low, _high),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (battery == null || registration == null)
            Text(
              l10n.smartChargeWaiting,
              key: const Key('smartChargeWaiting'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              key: const Key('smartChargePlug'),
              initialValue: _plug,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.smartChargePlug),
              items: [
                for (final p in plugs)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _plug = v),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: const Key('smartChargeCreate'),
                onPressed: _plug == null || _busy
                    ? null
                    : () => _create(battery, registration.deviceName),
                icon: const Icon(Icons.battery_charging_full),
                label: Text(l10n.smartChargeCreate),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
