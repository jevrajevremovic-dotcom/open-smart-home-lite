import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_sr.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/platform/speech_output.dart';
import 'package:open_smart_home_lite/features/add_device/data/lan_discovery.dart';
import 'package:open_smart_home_lite/features/alerts/alert_notifications.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_http.dart';
import 'package:open_smart_home_lite/features/app_lock/data/device_auth.dart';
import 'package:open_smart_home_lite/features/clap/clap_platform.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/kiosk/data/approach_platform.dart';
import 'package:open_smart_home_lite/features/media/now_playing_notification.dart';
import 'package:open_smart_home_lite/features/shortcuts/app_shortcuts.dart';
import 'package:open_smart_home_lite/features/shortcuts/home_screen_widget.dart';
import 'package:open_smart_home_lite/features/shortcuts/quick_tiles.dart';

import '../helpers.dart';

final en = AppLocalizationsEn();
final sr = AppLocalizationsSrLatn();

/// The app with the demo home (or [adapter]'s devices), the first-run
/// wizard done unless [firstRun].
Future<InMemoryCredentialStore> pumpApp(
  WidgetTester tester, {
  Size size = const Size(400, 860),
  bool firstRun = false,
  TestAdapter? adapter,
  Map<String, Object> preferences = const {},
  DeviceAuth? deviceAuth,
  AppShortcutsPlatform? shortcuts,
  AlertNotifier? alerts,
  HomeScreenWidgetPlatform? homeWidget,
  NowPlayingPlatform? nowPlaying,
  ClapPlatform? clap,
  ApproachPlatform? approach,
  QuickTilesPlatform? tiles,
  SpeechOutput? speech,
  LanHttp? http,
  LanDiscovery? discovery,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final credentials = InMemoryCredentialStore();
  final all = await testOverrides(
    credentials: credentials,
    preferences: preferences,
    firstRun: firstRun,
    adapter: adapter,
    deviceAuth: deviceAuth,
    shortcuts: shortcuts,
    alerts: alerts,
    homeWidget: homeWidget,
    nowPlaying: nowPlaying,
    clap: clap,
    approach: approach,
    tiles: tiles,
    speech: speech,
    http: http,
    discovery: discovery,
    overrides: overrides,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: all,
      retry: (_, _) => null,
      child: const SmartHomeApp(),
    ),
  );
  await settle(tester);
  return credentials;
}

/// Advances time for animations without waiting on endless spinners.
Future<void> settle(WidgetTester tester, [int steps = 10]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump(); // apply the scroll before hit-testing
  await tester.tap(finder);
}

/// Navigates with the app's router, as a deep link would.
Future<void> goTo(WidgetTester tester, String location) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SmartHomeApp)),
  );
  container.read(routerProvider).go(location);
  await settle(tester, 4);
}

/// Unmounts the app so its timers are cancelled.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('first start: the wizard, then the home, without signing in', (
    tester,
  ) async {
    await pumpApp(tester, firstRun: true);
    expect(find.text(en.firstRunWelcomeBodyLite), findsOneWidget);

    await tapKey(tester, 'firstRunSkip');
    await settle(tester);
    expect(find.text('Utičnica TV'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a light is switched from its screen', (tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    const id = 'demo:bedroom_lamp';
    expect(container.read(deviceProvider(id))!.state.isOn, isFalse);

    await goTo(tester, AppRoutes.device(id));
    await tapKey(tester, 'powerSwitch');
    await settle(tester, 3);
    expect(container.read(deviceProvider(id))!.state.isOn, isTrue);
    await unmount(tester);
  });

  testWidgets('Settings: the home section tells it is the demo home', (
    tester,
  ) async {
    await pumpApp(tester);
    await goTo(tester, AppRoutes.settingsSection('home'));
    expect(find.text(en.demoHomeNotice), findsOneWidget);
    await unmount(tester);
  });
}
