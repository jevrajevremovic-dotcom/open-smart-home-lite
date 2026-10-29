import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/storage/app_preferences.dart';
import '../../core/utils/value_list.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';
import '../kiosk/application/kiosk_controller.dart';

/// One battery-powered device: its main entity (to open), name, level.
typedef BatteryInfo = ({
  String id,
  String name,
  int? percent,
  bool low,

  /// The battery level's own device, when there is one.
  String? sensorId,
});

/// At or below this, a battery counts as low.
const batteryLowPercent = 15;

/// Every battery-powered device once (per physical device), emptiest first.
final batteriesProvider = Provider<ValueList<BatteryInfo>>(
  (ref) =>
      batteriesOf(ref.watch(homeSnapshotProvider.select((s) => s.devices))),
);

ValueList<BatteryInfo> batteriesOf(Map<String, SmartHomeDevice> devices) {
  final groups = <String, List<SmartHomeDevice>>{};
  for (final d in devices.values) {
    groups.putIfAbsent(d.deviceId ?? d.id, () => []).add(d);
  }
  final out = <BatteryInfo>[];
  for (final group in groups.values) {
    final sensor = group
        .where((d) => d.kind == DeviceKind.batterySensor)
        .firstOrNull;
    final main =
        group
            .where((d) => !d.isAuxiliary && d.kind != DeviceKind.batterySensor)
            .firstOrNull ??
        sensor ??
        group.first;
    final percent =
        sensor?.state.numericValue?.round() ?? main.metadata.batteryPercent;
    final lowFlag = main.metadata.batteryLow;
    if (percent == null && lowFlag == null) continue;
    out.add((
      id: main.id,
      name: main.name,
      percent: percent,
      low: lowFlag == true || (percent != null && percent <= batteryLowPercent),
      sensorId: sensor?.id,
    ));
  }
  out.sort((a, b) {
    if (a.low != b.low) return a.low ? -1 : 1;
    return (a.percent ?? 101).compareTo(b.percent ?? 101);
  });
  return ValueList(out);
}

/// "Tell me when a battery runs low", on this phone (opt-in). Each
/// device is told once, until its battery is above the limit again.
class BatteryReminderController extends Notifier<bool> {
  static const _key = 'batteries.reminder';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  /// Devices already told about, kept so a restart does not tell again.
  Set<String> get told => {
    for (final id
        in (ref.read(appPreferencesProvider).readJson(_key)?['told']
                as List?) ??
            const [])
      if (id is String) id,
  };

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(
          _key,
          enabled ? {'enabled': true, 'told': <String>[]} : null,
        );
  }

  Future<void> setTold(Set<String> ids) async {
    if (!state) return;
    await ref.read(appPreferencesProvider).writeJson(_key, {
      'enabled': true,
      'told': ids.toList()..sort(),
    });
  }
}

final batteryReminderProvider =
    NotifierProvider<BatteryReminderController, bool>(
      BatteryReminderController.new,
    );

/// Which batteries just became low: ones low now and not told yet; [told]
/// is updated (a battery above the limit again can be told again).
List<BatteryInfo> newlyLow(Iterable<BatteryInfo> batteries, Set<String> told) {
  final out = <BatteryInfo>[];
  for (final b in batteries) {
    if (b.low) {
      if (told.add(b.id)) out.add(b);
    } else {
      told.remove(b.id);
    }
  }
  return out;
}

/// All batteries, emptiest first, and the reminder.
Future<void> showBatteries(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const _BatteriesSheet(),
);

class _BatteriesSheet extends ConsumerStatefulWidget {
  const _BatteriesSheet();

  @override
  ConsumerState<_BatteriesSheet> createState() => _BatteriesSheetState();
}

class _BatteriesSheetState extends ConsumerState<_BatteriesSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.statusColors;
    final batteries = ref.watch(batteriesProvider);
    final reminder = ref.watch(batteryReminderProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        key: const Key('batteriesSheet'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l10n.batteriesTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            batteries.isEmpty
                ? l10n.batteriesNone
                : l10n.batteriesSummary(
                    batteries.length,
                    batteries.where((b) => b.low).length,
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (batteries.isNotEmpty)
            SwitchListTile(
              key: const Key('batteryReminder'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.batteryReminder),
              subtitle: Text(l10n.batteryReminderHint(batteryLowPercent)),
              value: reminder,
              onChanged: (v) =>
                  ref.read(batteryReminderProvider.notifier).set(v),
            ),
          const SizedBox(height: 8),
          for (final b in batteries)
            ListTile(
              key: ValueKey('battery-${b.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                b.low
                    ? Icons.battery_alert
                    : (b.percent ?? 100) < 50
                    ? Icons.battery_3_bar
                    : Icons.battery_full,
                color: b.low ? colors.warning : null,
              ),
              title: Text(b.name),
              subtitle: b.percent == null
                  ? Text(b.low ? l10n.batteryLowShort : l10n.batteryOk)
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: b.percent! / 100,
                          minHeight: 6,
                          color: b.low ? colors.warning : null,
                        ),
                      ),
                    ),
              trailing: b.percent == null
                  ? null
                  : Text(
                      '${b.percent} %',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: b.low ? colors.warning : null,
                      ),
                    ),
              onTap: () {
                final router = GoRouter.of(context);
                final kiosk = ref.read(kioskActiveProvider);
                Navigator.of(context).pop();
                router.push(AppRoutes.device(b.id, kiosk: kiosk));
              },
            ),
        ],
      ),
    );
  }
}
