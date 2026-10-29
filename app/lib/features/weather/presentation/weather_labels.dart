import 'package:flutter/material.dart';

import '../../../app/localization/l10n.dart';
import '../domain/weather.dart';

IconData weatherIcon(WeatherCondition c) => switch (c) {
  WeatherCondition.clearDay => Icons.wb_sunny_outlined,
  WeatherCondition.clearNight => Icons.nightlight_outlined,
  WeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
  WeatherCondition.cloudy => Icons.cloud_outlined,
  WeatherCondition.fog => Icons.foggy,
  WeatherCondition.rain ||
  WeatherCondition.heavyRain => Icons.water_drop_outlined,
  WeatherCondition.snow ||
  WeatherCondition.sleet ||
  WeatherCondition.hail => Icons.ac_unit,
  WeatherCondition.thunderstorm => Icons.thunderstorm_outlined,
  WeatherCondition.windy => Icons.air,
  WeatherCondition.exceptional => Icons.warning_amber_rounded,
  WeatherCondition.unknown => Icons.help_outline,
};

String weatherConditionLabel(AppLocalizations l10n, WeatherCondition c) =>
    switch (c) {
      WeatherCondition.clearDay => l10n.weatherClear,
      WeatherCondition.clearNight => l10n.weatherClearNight,
      WeatherCondition.partlyCloudy => l10n.weatherPartlyCloudy,
      WeatherCondition.cloudy => l10n.weatherCloudy,
      WeatherCondition.fog => l10n.weatherFog,
      WeatherCondition.rain => l10n.weatherRain,
      WeatherCondition.heavyRain => l10n.weatherHeavyRain,
      WeatherCondition.snow => l10n.weatherSnow,
      WeatherCondition.sleet => l10n.weatherSleet,
      WeatherCondition.hail => l10n.weatherHail,
      WeatherCondition.thunderstorm => l10n.weatherThunderstorm,
      WeatherCondition.windy => l10n.weatherWindy,
      WeatherCondition.exceptional => l10n.weatherExceptional,
      WeatherCondition.unknown => l10n.stateUnknown,
    };
