import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/l10n.dart';
import '../../core/storage/app_preferences.dart';
import '../authentication/application/session_controller.dart';
import '../dashboard/application/home_summaries.dart';
import '../devices/application/device_command_service.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';
import '../devices/presentation/device_presentation.dart';
import '../favorites/application/favorites_controller.dart';
import '../kiosk/presentation/kiosk_alarm.dart';
import 'home_screen_widget.dart';
import '../devices/data/home_state_repository.dart';

/// Which thermostat and light the home screen widgets show (this device).
@immutable
class HomeWidgetChoice {
  const HomeWidgetChoice({this.thermostat, this.light});

  factory HomeWidgetChoice.fromJson(Map<String, Object?>? json) =>
      HomeWidgetChoice(
        thermostat: json?['thermostat'] as String?,
        light: json?['light'] as String?,
      );

  final String? thermostat;
  final String? light;

  Map<String, Object?> toJson() => {'thermostat': ?thermostat, 'light': ?light};
}

class HomeWidgetChoiceController extends Notifier<HomeWidgetChoice> {
  static const _key = 'homeWidgets';

  @override
  HomeWidgetChoice build() => HomeWidgetChoice.fromJson(
    ref.watch(appPreferencesProvider).readJson(_key),
  );

  Future<void> set(HomeWidgetChoice c) async {
    state = c;
    await ref.read(appPreferencesProvider).writeJson(_key, c.toJson());
  }
}

final homeWidgetChoiceProvider =
    NotifierProvider<HomeWidgetChoiceController, HomeWidgetChoice>(
      HomeWidgetChoiceController.new,
    );

bool _isThermostat(SmartHomeDevice d) =>
    !d.isAuxiliary &&
    (d.kind == DeviceKind.climate || d.kind == DeviceKind.thermostat);

bool _isLight(SmartHomeDevice d) => !d.isAuxiliary && d.kind.isLight;

/// The thermostat on the widget: the chosen one, else the first by name.
final widgetThermostatProvider = Provider<String?>((ref) {
  final chosen = ref.watch(
    homeWidgetChoiceProvider.select((c) => c.thermostat),
  );
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  if (chosen != null && devices[chosen] != null) return chosen;
  final all = devices.values.where(_isThermostat).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return all.firstOrNull?.id;
});

/// The light on the widget: the chosen one, else the first favourite
/// light, else none.
final widgetLightProvider = Provider<String?>((ref) {
  final chosen = ref.watch(homeWidgetChoiceProvider.select((c) => c.light));
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  if (chosen != null && devices[chosen] != null) return chosen;
  for (final id in ref.watch(favoritesProvider)) {
    if (devices[id] case final d? when _isLight(d)) return id;
  }
  return null;
});

/// Thermostat step of one widget tap, in °C.
const widgetClimateStep = 0.5;

/// `opensmarthome://climate?step=±1` → ±1; `light?action=toggle` → 0;
/// anything else → null.
({String kind, int step})? homeWidgetActionFromUri(Uri? uri) {
  if (uri == null || uri.scheme != 'opensmarthome') return null;
  if (uri.host == 'climate') {
    final step = int.tryParse(uri.queryParameters['step'] ?? '');
    return step == 1 || step == -1 ? (kind: 'climate', step: step!) : null;
  }
  if (uri.host == 'light' && uri.queryParameters['action'] == 'toggle') {
    return (kind: 'light', step: 0);
  }
  return null;
}

/// Runs a widget tap on the device that is on the widget (never another:
/// any app can send these links). Returns false when it could not run.
Future<bool> runHomeWidgetAction(
  WidgetRef ref,
  ({String kind, int step}) action,
) async {
  final id = action.kind == 'climate'
      ? ref.read(widgetThermostatProvider)
      : ref.read(widgetLightProvider);
  final device = id == null ? null : ref.read(deviceProvider(id));
  final service = ref.read(deviceCommandServiceProvider);
  if (device == null || service == null) return false;
  final target = device.state.targetTemperature;
  final DeviceCommand command = action.kind == 'climate'
      ? SetTargetTemperature((target ?? 21) + action.step * widgetClimateStep)
      : const Toggle();
  try {
    await service.execute(device, command);
    return true;
  } on Object {
    return false;
  }
}

/// What the three widgets show now, as display text.
Map<String, Map<String, Object?>?> homeWidgetPayloads(
  AppLocalizations l10n, {
  required DashboardSummary summary,
  required SmartHomeDevice? alarm,
  required Iterable<SmartHomeDevice> devices,
  required SmartHomeDevice? thermostat,
  required SmartHomeDevice? light,
  required DateTime now,
}) {
  final unlocked = devices
      .where(
        (d) =>
            d.kind == DeviceKind.lock &&
            !d.isAuxiliary &&
            d.state.lockState == DoorLockState.unlocked,
      )
      .length;
  final updated = l10n.widgetUpdated(
    DateFormat.Hm(l10n.localeName).format(now),
  );
  String deg(double v) => formatNumber(l10n.localeName, v, unit: '°');
  return {
    'status': {
      'title': l10n.widgetHomeTitle,
      'lines': [
        summary.lightsOn == 0
            ? l10n.widgetLightsOff
            : l10n.widgetLightsOn(summary.lightsOn),
        summary.openingIds.isEmpty
            ? l10n.widgetAllClosed
            : l10n.widgetOpen(summary.openingIds.length),
        if (unlocked > 0) l10n.widgetUnlocked(unlocked) else l10n.widgetLocked,
        if (alarm != null)
          '🛡 ${DevicePresentation.status(l10n, alarm)}'
        else if (summary.averageTemperature != null)
          '🌡 ${deg(summary.averageTemperature!)}',
      ],
      'updated': updated,
    },
    'thermostat': thermostat == null
        ? null
        : {
            'name': thermostat.name,
            'target': thermostat.state.targetTemperature == null
                ? '—'
                : deg(thermostat.state.targetTemperature!),
            'current': thermostat.state.currentTemperature == null
                ? updated
                : l10n.widgetNow(deg(thermostat.state.currentTemperature!)),
          },
    'light': light == null
        ? null
        : {
            'name': light.name,
            'on': light.state.isOn == true,
            'state': DevicePresentation.status(l10n, light),
          },
  };
}

/// Keeps the three widgets current while the app runs (they say when they
/// were last updated). Sits below MaterialApp.
class HomeWidgetsSync extends ConsumerStatefulWidget {
  const HomeWidgetsSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeWidgetsSync> createState() => _HomeWidgetsSyncState();
}

class _HomeWidgetsSyncState extends ConsumerState<HomeWidgetsSync> {
  final _sent = <String, String>{};
  bool _scheduled = false;

  void _push(AppLocalizations l10n) {
    final platform = ref.read(homeScreenWidgetProvider);
    if (!platform.supported) return;
    final signedIn = ref.read(activeProfileProvider) != null;
    final live = ref.read(syncStatusProvider) == SyncStatus.live;
    if (!signedIn || !live) return;
    final devices = ref.read(homeSnapshotProvider).devices;
    final thermostat = ref.read(widgetThermostatProvider);
    final light = ref.read(widgetLightProvider);
    final payloads = homeWidgetPayloads(
      l10n,
      summary: ref.read(dashboardSummaryProvider),
      alarm: ref.read(kioskAlarmProvider),
      devices: devices.values,
      thermostat: thermostat == null ? null : devices[thermostat],
      light: light == null ? null : devices[light],
      now: DateTime.now(),
    );
    for (final e in payloads.entries) {
      // Only what changed (the time alone does not count).
      final key = jsonEncode({...?e.value}..remove('updated'));
      if (_sent[e.key] == key) continue;
      _sent[e.key] = key;
      unawaited(platform.setHomeWidget(e.key, e.value));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched so a change re-renders; the push runs after the frame.
    ref
      ..watch(dashboardSummaryProvider)
      ..watch(syncStatusProvider)
      ..watch(widgetThermostatProvider)
      ..watch(widgetLightProvider)
      ..watch(kioskAlarmProvider);
    final thermostat = ref.watch(widgetThermostatProvider);
    final light = ref.watch(widgetLightProvider);
    if (thermostat != null) ref.watch(deviceProvider(thermostat));
    if (light != null) ref.watch(deviceProvider(light));
    final l10n = context.l10n;
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) _push(l10n);
      });
    }
    return widget.child;
  }
}

/// Settings: which thermostat and light the widgets show.
class HomeWidgetSettings extends ConsumerWidget {
  const HomeWidgetSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeScreenWidgetProvider).supported) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final choice = ref.watch(homeWidgetChoiceProvider);
    final controller = ref.read(homeWidgetChoiceProvider.notifier);
    List<SmartHomeDevice> sorted(bool Function(SmartHomeDevice) test) =>
        devices.values.where(test).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.widgetSettingsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          l10n.widgetSettingsHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          key: const Key('widgetThermostat'),
          initialValue: ref.watch(widgetThermostatProvider),
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.widgetThermostat),
          items: [
            for (final d in sorted(_isThermostat))
              DropdownMenuItem(value: d.id, child: Text(d.name)),
          ],
          onChanged: (v) => controller.set(
            HomeWidgetChoice(thermostat: v, light: choice.light),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          key: const Key('widgetLight'),
          initialValue: ref.watch(widgetLightProvider),
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.widgetLight),
          items: [
            for (final d in sorted(_isLight))
              DropdownMenuItem(value: d.id, child: Text(d.name)),
          ],
          onChanged: (v) => controller.set(
            HomeWidgetChoice(thermostat: choice.thermostat, light: v),
          ),
        ),
      ],
    );
  }
}
