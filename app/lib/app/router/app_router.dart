import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/responsive.dart';
import '../../features/add_device/presentation/add_device_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/devices/presentation/device_detail_screen.dart';
import '../../features/devices/presentation/device_bundle_screen.dart';
import '../../features/dashboard/presentation/dashboard_layout_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/kiosk/application/kiosk_controller.dart';
import '../../features/restricted/application/restricted_mode.dart';
import '../../features/kiosk/presentation/kiosk_dashboard_screen.dart';
import '../../features/kiosk/presentation/kiosk_shell.dart';
import '../../features/weather/presentation/weather_screen.dart';
import '../../features/first_run/first_run_controller.dart';
import '../../features/first_run/first_run_screen.dart';
import '../../features/rooms/presentation/rooms_screen.dart';
import '../../features/scenes/presentation/scenes_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/house_check/house_check.dart';
import '../../features/presence_sim/presence_sim_screen.dart';
import '../../features/house_check/house_check_screen.dart';
import 'app_shell.dart';
import '../../features/simple_mode/simple_mode.dart';
import '../../features/floor_plan/floor_plan.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const rooms = '/rooms';
  static const allDevices = '/devices';
  static const favorites = '/favorites';
  static const scenes = '/scenes';
  static const settings = '/settings';
  static String settingsSection(String name) => '$settings/$name';
  static const weather = '/weather';
  static const houseCheck = '/check';
  static String houseCheckFor(String mode) => '$houseCheck?mode=$mode';
  static const dashboardLayout = '/home-layout';
  static const addDevice = '/add-device';
  static const presenceSim = '/presence';
  static String weatherFor({bool kiosk = false}) =>
      '${kiosk ? AppRoutes.kiosk : ''}$weather';

  /// Path segment used for "devices without a room".
  static const noRoomId = '_unassigned';

  static const kiosk = '/kiosk';
  static const firstRun = '/first-run';
  static const simple = '/simple';
  static const floorPlan = '/floor-plan';
  static String floorPlanFor({bool kiosk = false}) =>
      '${kiosk ? AppRoutes.kiosk : ''}$floorPlan';

  /// In kiosk mode links stay under [kiosk], so the router never lets the
  /// user out of the kiosk shell.
  static String room(String? id, {bool kiosk = false}) =>
      '${kiosk ? AppRoutes.kiosk : ''}$rooms/${Uri.encodeComponent(id ?? noRoomId)}';
  static String device(String id, {bool kiosk = false}) =>
      '${kiosk ? AppRoutes.kiosk : ''}/device/${Uri.encodeComponent(id)}';

  /// All parts of one physical device ([deviceId] from its adapter's
  /// device registry).
  static String deviceGroup(String deviceId, {bool kiosk = false}) =>
      '${kiosk ? AppRoutes.kiosk : ''}/device-group/${Uri.encodeComponent(deviceId)}';

  /// Destinations shown in the bottom bar / navigation rail, in order.
  static const shellDestinations = [home, rooms, favorites, scenes, settings];

  /// Which destination is highlighted for a location.
  static int shellIndexFor(String location) {
    if (location.startsWith(rooms) ||
        location.startsWith(allDevices) ||
        location.startsWith('/device/')) {
      return 1;
    }
    final index = shellDestinations.indexWhere(location.startsWith);
    return index < 0 ? 0 : index;
  }
}

/// Pure redirect rules, separated for unit testing.
String? resolveRedirect({
  required String location,
  bool kioskActive = false,
  bool firstRun = false,
  bool simple = false,
  bool restricted = false,
}) {
  final inKiosk =
      location == AppRoutes.kiosk || location.startsWith('${AppRoutes.kiosk}/');
  // While kiosk mode is active nothing outside the kiosk routes is reachable
  // (deep links, back navigation, …); leaving requires the PIN.
  if (kioskActive) return inKiosk ? null : AppRoutes.kiosk;
  if (inKiosk) return AppRoutes.home;
  // Simple mode: the big buttons only; leaving needs the PIN.
  if (simple) return location == AppRoutes.simple ? null : AppRoutes.simple;
  if (location == AppRoutes.simple) return AppRoutes.home;
  // The first start: the wizard, until finished or skipped.
  if (firstRun) {
    return location == AppRoutes.firstRun ? null : AppRoutes.firstRun;
  }
  // Restricted mode: no adding devices, even through a link.
  if (restricted && location == AppRoutes.addDevice) return AppRoutes.home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(kioskActiveProvider, (_, _) => refresh.value++)
    ..listen(firstRunProvider, (_, _) => refresh.value++)
    ..listen(simpleModeActiveProvider, (_, _) => refresh.value++)
    ..listen(restrictedModeProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    // An unknown location (old link, typo) goes home instead of showing
    // an error page with router internals.
    onException: (_, _, router) => router.go(AppRoutes.home),
    redirect: (context, state) => resolveRedirect(
      location: state.matchedLocation,
      kioskActive: ref.read(kioskActiveProvider),
      firstRun: ref.read(firstRunProvider),
      simple: ref.read(simpleModeActiveProvider),
      restricted: ref.read(restrictedModeProvider).enabled,
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            KioskShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.kiosk,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: KioskDashboardScreen()),
            routes: [
              GoRoute(
                path: 'device/:deviceId',
                builder: (_, state) => KioskScale(
                  child: DeviceDetailScreen(
                    deviceId: state.pathParameters['deviceId']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'device-group/:deviceId',
                builder: (_, state) => KioskScale(
                  child: DeviceBundleScreen(
                    deviceId: state.pathParameters['deviceId']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'weather',
                builder: (_, _) => const KioskScale(child: WeatherScreen()),
              ),
              GoRoute(
                path: 'floor-plan',
                builder: (_, _) => const FloorPlanScreen(),
              ),
              GoRoute(
                path: 'rooms/:roomId',
                builder: (_, state) {
                  final id = state.pathParameters['roomId']!;
                  return KioskScale(
                    child: RoomDetailScreen(
                      roomId: id == AppRoutes.noRoomId ? null : id,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.simple,
        builder: (_, _) => const SimpleModeScreen(),
      ),
      GoRoute(
        path: AppRoutes.firstRun,
        builder: (_, _) => const FirstRunScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.rooms,
            pageBuilder: (_, _) => const NoTransitionPage(child: RoomsScreen()),
            routes: [
              GoRoute(
                path: ':roomId',
                builder: (_, state) {
                  final id = state.pathParameters['roomId']!;
                  return RoomDetailScreen(
                    roomId: id == AppRoutes.noRoomId ? null : id,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.weather,
            builder: (_, _) => const WeatherScreen(),
          ),
          GoRoute(
            path: AppRoutes.floorPlan,
            builder: (_, _) => const FloorPlanScreen(),
          ),
          GoRoute(
            path: AppRoutes.houseCheck,
            builder: (_, state) => HouseCheckScreen(
              mode: HouseCheckMode.tryParse(state.uri.queryParameters['mode']),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardLayout,
            builder: (_, _) => const DashboardLayoutScreen(),
          ),
          GoRoute(
            path: AppRoutes.presenceSim,
            builder: (_, _) => const PresenceSimScreen(),
          ),
          GoRoute(
            path: AppRoutes.addDevice,
            builder: (_, _) => const AddDeviceScreen(),
          ),
          GoRoute(
            path: AppRoutes.allDevices,
            builder: (_, _) => const AllDevicesScreen(),
          ),
          GoRoute(
            path: '/device/:deviceId',
            builder: (_, state) =>
                DeviceDetailScreen(deviceId: state.pathParameters['deviceId']!),
          ),
          GoRoute(
            path: '/device-group/:deviceId',
            builder: (_, state) =>
                DeviceBundleScreen(deviceId: state.pathParameters['deviceId']!),
          ),
          GoRoute(
            path: AppRoutes.favorites,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: FavoritesScreen()),
          ),
          GoRoute(
            path: AppRoutes.scenes,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ScenesScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SettingsScreen()),
            routes: [
              GoRoute(
                path: ':section',
                pageBuilder: (context, state) {
                  final screen = SettingsScreen(
                    section: SettingsSection.tryParse(
                      state.pathParameters['section'],
                    ),
                  );
                  // Tablets switch the right pane in place; phones slide in.
                  return MediaQuery.sizeOf(context).width >=
                          Breakpoints.expanded
                      ? NoTransitionPage(key: state.pageKey, child: screen)
                      : MaterialPage(key: state.pageKey, child: screen);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
