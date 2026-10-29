// Smoothness on a real device: frame build/raster times while scrolling the
// home screen, swiping kiosk pages and opening kiosk windows. Run in profile
// mode with test_driver/perf_driver.dart.
//
// WARNING: only on an emulator or a spare device. `flutter drive`
// uninstalls the app when it ends, which deletes its data (login,
// settings) on a real wall panel.
//
// Everything stays in memory (demo server, preferences, credentials): the
// app data already on the device is not touched.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';

import '../test/helpers.dart';

const _profile =
    '{"url":"http://homeassistant.local:8123","pinnedCertificateSha256":null,"insecureConnectionAcknowledged":false}';

Future<void> wait(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('performance', (tester) async {
    final credentials = InMemoryCredentialStore();
    credentials.values['http://homeassistant.local:8123'] = 'token';
    await tester.pumpWidget(
      ProviderScope(
        overrides: await testOverrides(
          credentials: credentials,
          preferences: {'connection.activeServerProfile': _profile},
          speech: FakeSpeechOutput(supported: false),
        ),
        retry: (_, _) => null,
        child: const SmartHomeApp(),
      ),
    );
    await wait(tester, 4000);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );

    await binding.watchPerformance(() async {
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 3; i++) {
        await tester.fling(list, const Offset(0, -900), 2500);
        await wait(tester, 900);
        await tester.fling(list, const Offset(0, 900), 2500);
        await wait(tester, 900);
      }
    }, reportKey: 'home_scroll');

    container.read(kioskActiveProvider.notifier).enter();
    container.read(routerProvider).go(AppRoutes.kiosk);
    await wait(tester, 4000);

    await binding.watchPerformance(() async {
      // Swipe through the rooms and back.
      final middle = find.byKey(const Key('kioskColumnsSwipe'));
      for (var i = 0; i < 2; i++) {
        await tester.fling(middle, const Offset(-900, 0), 2500);
        await wait(tester, 1200);
        await tester.fling(middle, const Offset(-900, 0), 2500);
        await wait(tester, 1200);
        await tester.fling(middle, const Offset(900, 0), 2500);
        await wait(tester, 1200);
        await tester.fling(middle, const Offset(900, 0), 2500);
        await wait(tester, 1200);
      }
    }, reportKey: 'kiosk_rooms');

    await binding.watchPerformance(() async {
      for (final key in ['kioskTimer', 'kioskLeaving', 'kioskAlarm']) {
        await tester.tap(find.byKey(Key(key)));
        await wait(tester, 1200);
        await tester.tapAt(const Offset(8, 8)); // outside: closes
        await wait(tester, 1000);
      }
    }, reportKey: 'kiosk_dialogs');

    // Idle cost per panel: integration_test/idle_probe_test.dart (this
    // file's `wait` pumps frames itself, so it cannot measure idle).
  });
}
