import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/alerts/alert_notifications.dart';
import '../features/app_lock/application/app_lock.dart';
import '../features/app_lock/presentation/app_lock_gate.dart';
import '../features/authentication/application/session_controller.dart';
import '../features/connection/application/connection_route.dart';
import '../features/ha_notify/ha_push.dart';
import '../features/authentication/data/session_repository.dart';
import '../features/devices/application/device_providers.dart';
import '../features/settings/application/appearance_controllers.dart';
import '../features/shortcuts/app_shortcuts.dart';
import '../features/device_sensors/device_sensors.dart';
import '../features/nfc_tags/nfc_tags_ui.dart';
import '../features/shortcuts/quick_tiles.dart';
import '../features/assist/presentation/assist_launch_host.dart';
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
    // Back in the foreground (or a wall panel waking up): reconnect now
    // instead of waiting for the remaining backoff delay.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(appLockProvider.notifier).onForeground();
        ref.read(webSocketManagerProvider)?.retryNow();
        // Maybe home again, or just left: pick the address that answers.
        unawaited(ref.read(connectionRouteProvider.notifier).reevaluate());
      },
      // Persist the offline cache before the OS may suspend or kill us.
      onPause: () => ref.read(homeBackendProvider)?.flush(),
      onHide: () {
        ref.read(appLockProvider.notifier).onBackground();
        ref.read(homeBackendProvider)?.flush();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remember each home's name for the home switcher.
    ref.listen(serverConfigProvider, (_, next) {
      final profile = ref.read(activeProfileProvider);
      final name = next.value?.locationName;
      if (profile == null || name == null) return;
      ref
          .read(sessionRepositoryProvider)
          .setHomeName(profile.id, name)
          .then((_) => ref.invalidate(savedHomesProvider));
    });
    // The address in use stopped answering: try the home's other one.
    ref.listen(connectionStatusProvider, (_, next) {
      final s = next.value;
      if (s != null && !s.isConnected && !s.isTerminal && s.attempt >= 1) {
        unawaited(ref.read(connectionRouteProvider.notifier).reevaluate());
      }
    });
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
      builder: (context, child) => HaPushHost(
        child: DeviceSensorsHost(
          child: NfcScanHost(
            child: AlertNotificationsHost(
              child: NowPlayingNotificationHost(
                child: HomeWidgetsSync(
                  child: ShortcutsHost(
                    child: CommandPaletteHost(
                      child: QuickTilesHost(
                        child: AssistLaunchHost(
                          child: AppLockGate(child: child ?? const SizedBox()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
