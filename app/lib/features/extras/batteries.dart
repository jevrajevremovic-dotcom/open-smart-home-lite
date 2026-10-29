import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/utils/value_list.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';
import '../ha_notify/ha_push.dart';
import '../household/family_messages.dart';
import '../kiosk/application/kiosk_controller.dart';

/// One battery-powered device: its main entity (to open), name, level.
typedef BatteryInfo = ({
  String id,
  String name,
  int? percent,
  bool low,

  /// The `sensor.…_battery` entity, when there is one (for the reminder).
  String? sensorId,
});

/// At or below this, a battery counts as low.
const batteryLowPercent = 15;

/// Every battery-powered device once (per physical device), emptiest first.
final batteriesProvider = Provider<ValueList<BatteryInfo>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
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
});

/// The Home Assistant automation that warns about a battery running low.
const batteryReminderId = 'osh_battery_low';

final batteryReminderSetProvider = Provider<bool>(
  (ref) => ref.watch(
    homeSnapshotProvider.select(
      (s) =>
          s.devices.values.any((d) => d.metadata.configId == batteryReminderId),
    ),
  ),
);

/// When any battery sensor drops below [batteryLowPercent], Home Assistant
/// leaves a household message (the app and the wall panel show it) and
/// tells [notify] phones. `numeric_state` with a list of entities and
/// `trigger.to_state` are documented automation features.
Map<String, Object?> batteryReminderAutomation(
  AppLocalizations l10n, {
  required List<String> sensorIds,
  required List<String> notify,
}) {
  final message = l10n.batteryReminderMessage(
    '{{ trigger.to_state.name }}',
    '{{ trigger.to_state.state | int(0) }}',
  );
  return {
    'alias': l10n.batteryReminderAlias,
    'description': 'Open Smart Home',
    'mode': 'queued',
    'triggers': [
      {
        'trigger': 'numeric_state',
        'entity_id': sensorIds,
        'below': batteryLowPercent + 1,
      },
    ],
    'conditions': <Object>[],
    'actions': [
      for (final service in notify)
        {
          'action': service,
          'continue_on_error': true,
          'data': {'title': l10n.batteriesTitle, 'message': message},
        },
      {
        'action': 'persistent_notification.create',
        'data': {
          'notification_id':
              '${FamilyMessage.prefix}${FamilyMessage.everyone}_'
              '{{ now().timestamp() | int }}',
          'message': message,
        },
      },
    ],
  };
}

/// All batteries, emptiest first, and the reminder in Home Assistant.
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: it needs the localizations.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshReminder());
    });
  }

  /// Sensors added since the reminder was saved join it (and removed ones
  /// leave), without asking.
  Future<void> _refreshReminder() async {
    final api = ref.read(homeAssistantApiProvider);
    if (api == null || !ref.read(batteryReminderSetProvider)) return;
    final l10n = context.l10n;
    final sensors = {
      for (final b in ref.read(batteriesProvider))
        if (b.sensorId != null) b.sensorId!,
    };
    try {
      final saved = await api.fetchAutomation(batteryReminderId);
      final triggers = saved['triggers'];
      final ids = triggers is List && triggers.isNotEmpty
          ? (triggers.first as Map)['entity_id']
          : null;
      final old = {if (ids is List) ...ids.whereType<String>()};
      if (sensors.isEmpty || setEquals(old, sensors)) return;
      final notify = [
        for (final a in (saved['actions'] as List?) ?? const [])
          if (a is Map && '${a['action']}'.startsWith('notify.'))
            '${a['action']}',
      ];
      await api.saveAutomation(
        batteryReminderId,
        batteryReminderAutomation(
          l10n,
          sensorIds: sensors.toList()..sort(),
          notify: notify,
        ),
      );
    } on Object {
      // Next time; the old reminder keeps working meanwhile.
    }
  }

  Future<void> _toggleReminder(bool on, List<String> sensors) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    setState(() => _busy = true);
    try {
      if (on) {
        final phone = ref.read(haPushProvider).value?.notifyService;
        await api.saveAutomation(
          batteryReminderId,
          batteryReminderAutomation(l10n, sensorIds: sensors, notify: [?phone]),
        );
      } else {
        await api.deleteAutomation(batteryReminderId);
      }
    } on AppFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.statusColors;
    final batteries = ref.watch(batteriesProvider);
    final sensors = [
      for (final b in batteries)
        if (b.sensorId != null) b.sensorId!,
    ];
    final reminder = ref.watch(batteryReminderSetProvider);
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
          if (sensors.isNotEmpty)
            SwitchListTile(
              key: const Key('batteryReminder'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.batteryReminder),
              subtitle: Text(l10n.batteryReminderHint(batteryLowPercent)),
              value: reminder,
              onChanged: _busy ? null : (v) => _toggleReminder(v, sensors),
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
