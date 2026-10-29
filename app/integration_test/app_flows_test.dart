// End-to-end flows on a real device or emulator, with the real platform
// services (Android Keystore / iOS Keychain, SharedPreferences, file cache,
// wakelock). Only Home Assistant is replaced by the in-memory mock server.
//
//   flutter test integration_test -d <device-id>
//
// WARNING: these tests erase the app's data on the device (login,
// settings) — use an emulator or a spare device, never a panel in use.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/config/app_config.dart';
import 'package:open_smart_home_lite/core/storage/app_preferences.dart';
import 'package:open_smart_home_lite/core/storage/credential_store_io.dart';
import 'package:open_smart_home_lite/features/authentication/domain/stored_credential.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/cache/snapshot_cache_io.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final en = AppLocalizationsEn();
const serverId = 'http://homeassistant.local:8123';

Future<void> resetDevice() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await SecureCredentialStore().deleteAll();
  await FileSnapshotCache().clearAll();
}

Future<void> startApp(
  WidgetTester tester,
  MockHomeAssistantServer server,
) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      // New scope = same as an app restart (fresh providers, same storage).
      key: UniqueKey(),
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(mockMode: true)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        mockHomeAssistantServerProvider.overrideWithValue(server),
      ],
      retry: (_, _) => null,
      child: const SmartHomeApp(),
    ),
  );
}

/// Pumps frames in real time until [finder] matches.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(40)
      .join(' | ');
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SmartHomeApp)),
  );
  final location = container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri;
  final snapshot = container.read(homeSnapshotProvider);
  fail(
    'Timed out waiting for $finder at $location '
    '(sync: ${snapshot.status}, devices: ${snapshot.devices.length}). Visible texts: $texts',
  );
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  // A real on-screen keyboard may cover the target; close it like a user
  // would, and let the layout settle before hit-testing.
  if (FocusManager.instance.primaryFocus?.hasPrimaryFocus ?? false) {
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump(const Duration(milliseconds: 600));
  }
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> go(WidgetTester tester, String location) async {
  ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
      .read(routerProvider)
      .go(location);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> signIn(WidgetTester tester) async {
  await tap(tester, find.text(en.getStarted));
  await waitFor(tester, find.byKey(const Key('serverAddressField')));
  await tester.enterText(
    find.byKey(const Key('serverAddressField')),
    'homeassistant.local:8123',
  );
  await tap(tester, find.byKey(const Key('checkServerButton')));
  await waitFor(tester, find.byKey(const Key('tokenField')));
  await tester.enterText(
    find.byKey(const Key('tokenField')),
    'integration-token',
  );
  await tap(tester, find.byKey(const Key('connectButton')));
  await waitFor(tester, find.text('Demo dom (mock)'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetDevice);

  testWidgets(
    'onboarding → control a light → sign-out removes the token from the keystore',
    (tester) async {
      final server = MockHomeAssistantServer();
      await startApp(tester, server);
      await signIn(tester);

      expect(
        (StoredCredential.parse(
                  await SecureCredentialStore().readCredential(serverId),
                )!
                as LongLivedToken)
            .token,
        'integration-token',
      );

      await go(tester, AppRoutes.device('light.living_room_main'));
      await waitFor(tester, find.text(en.brightness));
      await tap(tester, find.byKey(const Key('powerSwitch')));
      await waitFor(tester, find.text(en.stateOff));

      await go(tester, AppRoutes.settingsSection('server'));
      await tap(tester, find.byKey(const Key('signOutButton')));
      await tap(tester, find.byKey(const Key('confirmDialogAction')));
      await waitFor(tester, find.text(en.welcomeTitle));

      expect(await SecureCredentialStore().readCredential(serverId), isNull);
      expect(await FileSnapshotCache().load(serverId), isNull);
    },
  );

  testWidgets(
    'restart without server shows cached data from disk, marked stale',
    (tester) async {
      final server = MockHomeAssistantServer();
      await startApp(tester, server);
      await signIn(tester);
      // Make sure the cache is on disk (as when the app goes to background).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartHomeApp)),
      );
      await waitFor(tester, find.text(en.summaryLights));
      await container.read(homeBackendProvider)!.flush();
      expect(await FileSnapshotCache().load(serverId), isNotNull);

      server.online = false;
      await server.dropAllConnections();
      await startApp(tester, server);

      await waitFor(tester, find.byKey(const Key('staleDataBanner')));
      expect(find.text('Demo dom (mock)'), findsOneWidget);
      expect(find.text(en.lightsOnOf(2, 3)), findsOneWidget);
    },
  );

  testWidgets('kiosk mode holds a wakelock and releases it on exit', (
    tester,
  ) async {
    final server = MockHomeAssistantServer();
    await startApp(tester, server);
    await signIn(tester);

    await go(tester, AppRoutes.settingsSection('kiosk'));
    await tap(tester, find.byKey(const Key('startKiosk')));
    await waitFor(tester, find.byKey(const Key('kioskExit')));
    expect(await WakelockPlus.enabled, isTrue);

    await tap(tester, find.byKey(const Key('kioskExit'))); // no PIN set
    await waitFor(tester, find.byType(NavigationBar));
    await tester.pump(const Duration(milliseconds: 500));
    expect(await WakelockPlus.enabled, isFalse);
  });

  testWidgets('theme and language survive a restart', (tester) async {
    final server = MockHomeAssistantServer();
    await startApp(tester, server);
    await signIn(tester);
    await go(tester, AppRoutes.settingsSection('appearance'));
    await tap(tester, find.text(en.themeDark));
    await tap(tester, find.text(en.languageSerbian));
    await tester.pump(const Duration(seconds: 1));

    await startApp(tester, server);
    await waitFor(tester, find.text('Početna'));
    final context = tester.element(find.text('Početna').first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  // Needs the notification permission granted beforehand, e.g.
  //   adb shell pm grant org.opensmarthome.open_smart_home android.permission.POST_NOTIFICATIONS
  testWidgets(
    'a critical alert becomes a system notification and clears itself',
    (tester) async {
      final server = MockHomeAssistantServer();
      await startApp(tester, server);
      await signIn(tester);
      await go(tester, AppRoutes.settingsSection('notifications'));
      await tap(tester, find.byKey(const Key('alertNotifySwitch')));
      await tester.pump(const Duration(seconds: 1));

      final android = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      Future<List<String?>> titles() async => [
        for (final n in await android.getActiveNotifications()) n.title,
      ];

      server.setStateForTest('lock.front_door', 'jammed');
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (!(await titles()).contains('Brava ulazna vrata') &&
          DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(await titles(), contains('Brava ulazna vrata'));

      server.setStateForTest('lock.front_door', 'locked');
      await tester.pump(const Duration(seconds: 2));
      expect(await titles(), isNot(contains('Brava ulazna vrata')));
    },
    skip: !Platform.isAndroid,
  );
}
