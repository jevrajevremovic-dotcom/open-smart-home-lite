import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../kiosk/application/kiosk_now.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/domain/weather.dart';
import '../../weather/presentation/weather_labels.dart';
import 'home_summaries.dart';

/// One sentence about the home, like a person would say it: time, weather,
/// lights, what is open or unlocked, the alarm, alerts. Only facts Home
/// Assistant reports; a part with no data is left out.
String homeSentence(
  AppLocalizations l10n, {
  required DateTime now,
  required DashboardSummary summary,
  WeatherNow? weather,
  List<String> unlocked = const [],
  String? alarm,
}) {
  final locale = l10n.localeName;
  String lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
  final parts = <String>[
    l10n.homeSayTime(DateFormat.Hm(locale).format(now)),
    if (weather?.temperature case final t?)
      l10n.homeSayWeather(
        lower(weatherConditionLabel(l10n, weather!.condition)),
        formatNumber(locale, t, unit: '°'),
      ),
    if (summary.lightsTotal > 0)
      '${summary.lightsOn > 0 ? l10n.homeSayLights(summary.lightsOn) : l10n.homeSayLightsOff}, '
          '${summary.openingIds.isEmpty ? l10n.homeSayClosed : l10n.homeSayOpen(summary.openingIds.length)}',
    if (unlocked.isNotEmpty) l10n.homeSayUnlocked(unlocked.join(', ')),
    ?(alarm == null ? null : l10n.homeSayAlarm(lower(alarm))),
    if (summary.criticalIds.isNotEmpty)
      l10n.homeSayAlerts(summary.criticalIds.length),
  ];
  return parts.join(' ');
}

/// [homeSentence] for the current home, refreshed every minute.
final homeSentenceProvider = Provider.family<String, AppLocalizations>((
  ref,
  l10n,
) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final alarm = devices.values
      .where((d) => d.kind == DeviceKind.alarm && d.available)
      .firstOrNull;
  return homeSentence(
    l10n,
    now: ref.watch(kioskNowProvider),
    summary: ref.watch(dashboardSummaryProvider),
    weather: ref.watch(homeWeatherProvider)?.now,
    unlocked: [
      for (final d in devices.values)
        if (d.kind == DeviceKind.lock &&
            d.available &&
            d.state.lockState == DoorLockState.unlocked)
          d.name,
    ],
    alarm: alarm == null ? null : DevicePresentation.status(l10n, alarm),
  );
});
