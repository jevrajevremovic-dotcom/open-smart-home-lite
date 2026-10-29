import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/add_device/application/address_keeper.dart';
import '../features/alerts/alert_notifications.dart';
import '../features/automations/application/automation_engine.dart';
import '../features/automations/application/background_run.dart';
import '../features/extras/home_programs.dart';
import '../features/timers/device_timer.dart';
import '../features/app_lock/application/app_lock.dart';
import '../features/app_lock/presentation/app_lock_gate.dart';
import '../features/devices/application/device_providers.dart';
import '../features/kiosk/application/kiosk_controller.dart';
import '../features/settings/application/appearance_controllers.dart';
import '../features/shortcuts/app_shortcuts.dart';
import '../features/shortcuts/quick_tiles.dart';
import 'localization/app_locales.dart';
import 'localization/l10n.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'brand.dart';
import '../features/search/command_palette.dart';
import '../features/shortcuts/home_widgets.dart';
import '../features/media/now_playing_notification.dart';

class SmartHomeApp extends ConsumerStatefulWidget {
  const SmartHomeApp({super.key});

  @override
  ConsumerState<SmartHomeApp> createState() => _SmartHomeAppState();
}

class _SmartHomeAppState extends ConsumerState<SmartHomeApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(appLockProvider.notifier).onForeground();
        ref.read(homeBackendProvider)?.setActive(true);
        ref.read(addressKeeperProvider).check();
      },
      // Save before the OS may suspend or kill us.
      onPause: () => ref.read(homeBackendProvider)?.flush(),
      onHide: () {
        ref.read(appLockProvider.notifier).onBackground();
        ref.read(homeBackendProvider)?.flush();
        // A wall panel stays in front, and with automations in the
        // background the devices are followed; else the phone rests.
        if (!ref.read(kioskActiveProvider) &&
            !ref.read(backgroundAutomationsProvider)) {
          ref.read(homeBackendProvider)?.setActive(false);
        }
      },
    );
    // Devices that got a new address while the app was closed; the
    // automations start with the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addressKeeperProvider).check();
      ref
        ..read(automationEngineProvider)
        ..read(homeProgramsProvider)
        ..read(deviceTimersProvider);
      AppLocalizations l10n;
      try {
        l10n = lookupAppLocalizations(
          ref.read(localeProvider) ??
              WidgetsBinding.instance.platformDispatcher.locale,
        );
      } on FlutterError {
        l10n = lookupAppLocalizations(const Locale('en'));
      }
      ref
          .read(backgroundAutomationsProvider.notifier)
          .apply(title: l10n.appTitle, text: l10n.backgroundNotificationText);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => Brand.name(context.l10n),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: accentColor(ref.watch(accentProvider))),
      darkTheme: AppTheme.dark(
        accent: accentColor(ref.watch(accentProvider)),
        oled: ref.watch(oledProvider),
      ),
      themeMode: ref.watch(effectiveThemeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: AppLocales.resolve,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AlertNotificationsHost(
        child: NowPlayingNotificationHost(
          child: HomeWidgetsSync(
            child: ShortcutsHost(
              child: CommandPaletteHost(
                child: QuickTilesHost(
                  child: AppLockGate(child: child ?? const SizedBox()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
