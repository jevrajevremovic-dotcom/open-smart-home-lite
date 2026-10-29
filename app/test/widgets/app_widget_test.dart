import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/alerts/alert_notifications.dart';
import 'package:open_smart_home_lite/features/shortcuts/app_shortcuts.dart';
import 'package:open_smart_home_lite/features/add_device/data/matter_pairing.dart';
import 'package:open_smart_home_lite/features/clap/clap_platform.dart';
import 'package:open_smart_home_lite/features/kiosk/data/approach_platform.dart';
import 'package:open_smart_home_lite/features/ha_notify/ha_push.dart';
import 'package:open_smart_home_lite/features/shortcuts/home_screen_widget.dart';
import 'package:open_smart_home_lite/features/app_lock/data/device_auth.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_sr.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/authentication/domain/stored_credential.dart';
import 'package:open_smart_home_lite/features/settings/presentation/settings_screen.dart';
import 'package:open_smart_home_lite/features/device_sensors/device_sensors.dart';
import 'package:open_smart_home_lite/features/nfc_tags/nfc_tags.dart';
import 'package:open_smart_home_lite/features/shortcuts/quick_tiles.dart';
import 'package:open_smart_home_lite/features/assist/data/speech_output.dart';
import 'package:open_smart_home_lite/features/media/now_playing_notification.dart';

import '../helpers.dart';

final en = AppLocalizationsEn();
final sr = AppLocalizationsSrLatn();

const _profileJson =
    '{"url":"http://homeassistant.local:8123","pinnedCertificateSha256":null,"insecureConnectionAcknowledged":false}';

Future<InMemoryCredentialStore> pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  Size size = const Size(400, 860),
  MockHomeAssistantServer? server,
  DeviceAuth? deviceAuth,
  AppShortcutsPlatform? shortcuts,
  AlertNotifier? alerts,
  HomeScreenWidgetPlatform? homeWidget,
  NowPlayingPlatform? nowPlaying,
  ClapPlatform? clap,
  ApproachPlatform? approach,
  DeviceBatteryPlatform? battery,
  NfcPlatform? nfc,
  QuickTilesPlatform? tiles,
  SpeechOutput? speech,
  AssistLaunchPlatform? assistLaunch,
  BackgroundConnectionPlatform? background,
  MatterNewDevicePlatform? matter,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final credentials = InMemoryCredentialStore();
  if (signedIn) credentials.values['http://homeassistant.local:8123'] = 'token';
  final all = await testOverrides(
    credentials: credentials,
    preferences: signedIn
        ? {'connection.activeServerProfile': _profileJson}
        : const {},
    server: server,
    deviceAuth: deviceAuth,
    shortcuts: shortcuts,
    alerts: alerts,
    homeWidget: homeWidget,
    nowPlaying: nowPlaying,
    clap: clap,
    approach: approach,
    battery: battery,
    nfc: nfc,
    tiles: tiles,
    speech: speech,
    assistLaunch: assistLaunch,
    background: background,
    matter: matter,
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

/// Advances time for mock latency without waiting on endless spinners.
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

/// Unmounts the app so the WebSocket manager cancels its timers.
/// Navigates with the app's router, as a deep link would.
Future<void> goTo(WidgetTester tester, String location) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SmartHomeApp)),
  );
  container.read(routerProvider).go(location);
  await settle(tester, 4);
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('welcome screen is shown first, in English by default', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text(en.welcomeTitle), findsOneWidget);
    expect(
      find.text(en.mockModeBanner),
      findsNothing,
      reason: 'banner only on connection screens',
    );
    await unmount(tester);
  });

  testWidgets('switching language to Serbian updates the UI', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(en.languageSerbian));
    await settle(tester, 3);
    expect(find.text(sr.welcomeTitle), findsOneWidget);
    expect(find.text(sr.getStarted), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('server address validation shows an inline error', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text(en.getStarted));
    await settle(tester, 5);
    expect(find.text(en.mockModeBanner), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('serverAddressField')),
      'https://example.com/ha',
    );
    await tapKey(tester, 'checkServerButton');
    await settle(tester, 3);
    expect(find.text(en.addressErrorPath), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'full onboarding against the mock server reaches a live home screen',
    (tester) async {
      final credentials = await pumpApp(tester);
      await tester.tap(find.text(en.getStarted));
      await settle(tester, 5);

      await tester.enterText(
        find.byKey(const Key('serverAddressField')),
        'homeassistant.local:8123',
      );
      await tapKey(tester, 'checkServerButton');
      await settle(tester);

      expect(find.text(en.tokenTitle), findsOneWidget);
      await tester.enterText(find.byKey(const Key('tokenField')), 'invalid');
      await tapKey(tester, 'connectButton');
      await settle(tester);
      expect(find.text(en.failureAuthentication), findsOneWidget);

      await tester.enterText(find.byKey(const Key('tokenField')), 'demo-token');
      await tapKey(tester, 'connectButton');
      await settle(tester, 20);

      // First run: a personal phone, a favourite, then through to the end.
      expect(find.text(en.firstRunWelcomeTitle), findsOneWidget);
      await tapKey(tester, 'firstRunRolePhone');
      await settle(tester);
      for (var i = 0; i < 8; i++) {
        if (find.text(en.firstRunFavoritesTitle).evaluate().isNotEmpty) break;
        await tapKey(tester, 'firstRunNext');
        await settle(tester, 5);
      }
      final chip = find.byWidgetPredicate(
        (w) => w is FilterChip && '${w.key}'.contains('firstRunFav-'),
      );
      await tester.tap(chip.first);
      await settle(tester);
      expect(find.text(en.firstRunFavoritesCount(1)), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        if (find.text(en.firstRunStart).evaluate().isNotEmpty) break;
        await tapKey(tester, 'firstRunNext');
        await settle(tester, 5);
      }
      expect(find.text(en.firstRunDoneTitle), findsOneWidget);
      await tapKey(tester, 'firstRunNext');
      await settle(tester, 20);

      expect(find.text('Demo dom (mock)'), findsOneWidget);
      expect(find.text(en.statusConnected), findsOneWidget);
      expect(find.text(en.summaryLights), findsOneWidget);
      expect(
        (StoredCredential.parse(credentials.values.values.single)!
                as LongLivedToken)
            .token,
        'demo-token',
      );
      await unmount(tester);
    },
  );

  testWidgets('first run as a wall tablet continues in the panel setup', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text(en.getStarted));
    await settle(tester, 5);
    await tester.enterText(
      find.byKey(const Key('serverAddressField')),
      'homeassistant.local:8123',
    );
    await tapKey(tester, 'checkServerButton');
    await settle(tester);
    await tester.enterText(find.byKey(const Key('tokenField')), 'demo-token');
    await tapKey(tester, 'connectButton');
    await settle(tester, 20);

    await tapKey(tester, 'firstRunRoleWall');
    await settle(tester);
    for (var i = 0; i < 4; i++) {
      if (find.text(en.firstRunWallNext).evaluate().isNotEmpty) break;
      await tapKey(tester, 'firstRunNext');
      await settle(tester, 5);
    }
    await tapKey(tester, 'firstRunNext');
    await settle(tester, 10);
    expect(find.byKey(const Key('setupStepper')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('phone layout uses a bottom NavigationBar', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await unmount(tester);
  });

  testWidgets('tablet landscape layout uses a NavigationRail', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await unmount(tester);
  });

  testWidgets('theme can be switched to dark in settings', (tester) async {
    await pumpApp(tester, signedIn: true);
    await tester.tap(find.text(en.navSettings));
    await settle(tester, 3);
    await tapKey(tester, 'settingsSection-appearance');
    await settle(tester, 3);
    await tester.tap(find.text(en.themeDark));
    await settle(tester, 3);

    final context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    await unmount(tester);
  });

  testWidgets('sign-out after confirmation deletes the token', (tester) async {
    final credentials = await pumpApp(tester, signedIn: true);
    await tester.tap(find.text(en.navSettings));
    await settle(tester, 3);
    await tapKey(tester, 'settingsSection-server');
    await settle(tester, 3);

    await tapKey(tester, 'signOutButton');
    await settle(tester, 3);
    await tapKey(tester, 'confirmDialogAction');
    await settle(tester, 5);

    expect(credentials.values, isEmpty);
    expect(find.text(en.welcomeTitle), findsOneWidget);
    await unmount(tester);
  });
}
