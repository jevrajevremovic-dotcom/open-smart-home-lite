import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../alerts/alert_notifications.dart';
import '../appliance_done/appliance_done.dart';
import '../automations/application/automation_engine.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/smart_home_device.dart';
import '../presence_sim/presence_simulation.dart';
import '../settings/application/appearance_controllers.dart';
import 'batteries.dart';
import 'send_command.dart';
import 'sunrise_wake.dart';

/// The home's programs that run on this phone besides the automations:
/// the sunrise alarm, the presence simulation, "tell me when it's done"
/// and the battery reminder. They follow the automation engine's minutes (and, for the
/// appliances, every change of power).
class HomePrograms {
  HomePrograms(this._ref) {
    final send = commandSender(_ref);
    _sunrise = SunriseRunner(send);
    _presence = PresenceRunner(send);
  }

  final Ref _ref;
  late final SunriseRunner _sunrise;
  late final PresenceRunner _presence;
  late final _appliances = ApplianceWatcher(_done);
  final List<StreamSubscription<Object?>> _subs = [];

  void start(AutomationEngine engine) {
    final backend = _ref.read(homeBackendProvider);
    Map<String, SmartHomeDevice> devices() =>
        backend?.current.devices ?? const {};
    _subs.add(
      engine.minutes.listen((now) {
        _sunrise.onMinute(now, _ref.read(sunriseWakeProvider), devices);
        _presence.onMinute(
          now,
          _ref.read(presenceSimProvider),
          devices,
          engine.sunToday(),
        );
        _appliances.check(now, _ref.read(applianceDoneProvider), devices());
      }),
    );
    if (backend != null) {
      _subs.add(
        backend.snapshots.listen((s) {
          _appliances.check(
            engine.now,
            _ref.read(applianceDoneProvider),
            s.devices,
          );
          _checkBatteries(s.devices);
        }),
      );
    }
  }

  /// A battery that just became low, told once (until it is fine again).
  void _checkBatteries(Map<String, SmartHomeDevice> devices) {
    final reminder = _ref.read(batteryReminderProvider.notifier);
    if (!_ref.read(batteryReminderProvider)) return;
    final told = reminder.told;
    final before = {...told};
    final low = newlyLow(batteriesOf(devices), told);
    if (setEquals(before, told)) return;
    unawaited(reminder.setTold(told));
    final notifier = _ref.read(alertNotifierProvider);
    if (!notifier.supported) return;
    final l10n = _l10n();
    for (final b in low) {
      unawaited(
        notifier.showMessage(
          'battery:${b.id}',
          l10n.batteriesTitle,
          l10n.batteryReminderMessage(b.name, '${b.percent ?? '?'}'),
        ),
      );
    }
  }

  AppLocalizations _l10n() {
    try {
      return lookupAppLocalizations(
        _ref.read(localeProvider) ??
            WidgetsBinding.instance.platformDispatcher.locale,
      );
    } on FlutterError {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  void _done(ApplianceDone appliance) {
    final notifier = _ref.read(alertNotifierProvider);
    if (!notifier.supported) return;
    final l10n = _l10n();
    unawaited(
      notifier.showMessage(
        'done:${appliance.powerId}',
        l10n.applianceDoneTitle,
        l10n.applianceDoneMessage(appliance.name),
      ),
    );
  }

  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _presence.dispose();
  }
}

/// Started with the app, after the automation engine.
final homeProgramsProvider = Provider<HomePrograms?>((ref) {
  final engine = ref.watch(automationEngineProvider);
  if (engine == null) return null;
  final programs = HomePrograms(ref)..start(engine);
  ref.onDispose(programs.dispose);
  return programs;
});
