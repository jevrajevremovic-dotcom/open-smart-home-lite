// Frames drawn while the kiosk is left alone, per panel type (emulator
// only: `flutter drive` uninstalls the app at the end).
import 'dart:ui' show FrameTiming;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/presentation/kiosk_columns.dart';

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
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;

  testWidgets('idle frames per panel', (tester) async {
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
    container.read(kioskActiveProvider.notifier).enter();
    container.read(routerProvider).go(AppRoutes.kiosk);
    // The home overview, then each room of the mock home.
    for (final room in [null, 'living_room', 'kitchen', 'bedroom']) {
      container.read(kioskColumnsRoomProvider.notifier).select(room);
      await wait(tester, 2500);
      // Count frames the app itself asks for (not our pumps).
      var frames = 0;
      void count(List<FrameTiming> t) => frames += t.length;
      binding.addTimingsCallback(count);
      final end = DateTime.now().add(const Duration(seconds: 4));
      while (DateTime.now().isBefore(end)) {
        if (binding.hasScheduledFrame) {
          await tester.pump();
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      }
      binding.removeTimingsCallback(count);
      binding.reportData ??= {};
      binding.reportData![room ?? 'home'] = frames;
      // ignore: avoid_print
      print('IDLE ${room ?? 'home'}: $frames frames / 4 s');
    }
  });
}
