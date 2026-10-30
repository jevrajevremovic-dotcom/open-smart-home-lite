import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_locales.dart';
import '../../../core/storage/app_preferences.dart';
import '../../automations/domain/sun.dart';
import '../../weather/application/weather_providers.dart';
import '../../../app/brand.dart';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(appPreferencesProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(appPreferencesProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Selected app language; `null` follows the system language.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() =>
      AppLocales.fromTag(ref.watch(appPreferencesProvider).localeTag);

  Future<void> set(Locale? locale) async {
    state = locale;
    await ref
        .read(appPreferencesProvider)
        .setLocaleTag(locale == null ? null : AppLocales.toTag(locale));
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

/// Dark after sunset, light after sunrise (Home Assistant's `sun.sun`, or
/// 20:00–7:00 without it). Overrides [themeModeProvider] while on.
class AutoDarkController extends Notifier<bool> {
  static const _key = 'theme.sun';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
  }
}

final autoDarkProvider = NotifierProvider<AutoDarkController, bool>(
  AutoDarkController.new,
);

/// Pure black dark theme (AMOLED screens).
class OledController extends Notifier<bool> {
  static const _key = 'theme.oled';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
  }
}

final oledProvider = NotifierProvider<OledController, bool>(OledController.new);

/// Minute clock for the fallback without `sun.sun`.
/// The time, renewed every minute.
final minuteClockProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  final timer = Timer(Duration(seconds: 60 - now.second), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return now;
});

/// Whether the sun is down at the home's location; `null` without it.
final sunDownProvider = Provider<bool?>((ref) {
  final now = ref.watch(minuteClockProvider);
  final home = ref.watch(homeLocationWeatherEnabledProvider);
  final sun = home == null
      ? null
      : sunTimes(now, home.latitude, home.longitude);
  return sun == null
      ? null
      : now.isBefore(sun.sunrise) || now.isAfter(sun.sunset);
});

/// The theme mode the app uses.
final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  if (!ref.watch(autoDarkProvider)) return ref.watch(themeModeProvider);
  // After sunset at home; without the home's location, 20:00 to 7:00.
  final hour = ref.watch(minuteClockProvider).hour;
  final dark = ref.watch(sunDownProvider) ?? (hour >= 20 || hour < 7);
  return dark ? ThemeMode.dark : ThemeMode.light;
});

/// The app's accent colour.
enum AppAccent { terracotta, blue, green, purple, rose, teal }

class AccentController extends Notifier<AppAccent> {
  static const _key = 'theme.accent';

  @override
  AppAccent build() {
    final name = ref.watch(appPreferencesProvider).readJson(_key)?['name'];
    return AppAccent.values.where((a) => a.name == name).firstOrNull ??
        AppAccent.terracotta;
  }

  Future<void> set(AppAccent accent) async {
    state = accent;
    await ref
        .read(appPreferencesProvider)
        .writeJson(
          _key,
          accent == AppAccent.terracotta ? null : {'name': accent.name},
        );
  }
}

final accentProvider = NotifierProvider<AccentController, AppAccent>(
  AccentController.new,
);

/// The seed of [accent]; `null` keeps the hand-tuned warm default.
Color? accentColor(AppAccent accent) => switch (accent) {
  // The installer's colour, when the app carries a brand.
  AppAccent.terracotta => Brand.accent,
  AppAccent.blue => const Color(0xFF2F6FDB),
  AppAccent.green => const Color(0xFF2E8B57),
  AppAccent.purple => const Color(0xFF7B4FD6),
  AppAccent.rose => const Color(0xFFD0457A),
  AppAccent.teal => const Color(0xFF14858A),
};
