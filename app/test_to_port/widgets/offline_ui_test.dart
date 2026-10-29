import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/data/cache/snapshot_cache.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../features/offline_cache_test.dart' show cachedFrom, serverId;
import '../helpers.dart';
import 'app_widget_test.dart' show en, goTo, settle, unmount;

void main() {
  testWidgets(
    'offline start shows cached data, clearly marked, controls disabled',
    (tester) async {
      tester.view
        ..physicalSize = const Size(800, 1300)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final server = MockHomeAssistantServer()..online = false;
      final cache = InMemorySnapshotCache();
      await cache.save(
        serverId,
        cachedFrom(server, DateTime.now().subtract(const Duration(hours: 2))),
      );
      final credentials = InMemoryCredentialStore()..values[serverId] = 'token';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await testOverrides(
              credentials: credentials,
              snapshotCache: cache,
              preferences: {
                'connection.activeServerProfile':
                    '{"url":"$serverId","pinnedCertificateSha256":null,"insecureConnectionAcknowledged":false}',
              },
            ),
            mockHomeAssistantServerProvider.overrideWithValue(server),
          ],
          retry: (_, _) => null,
          child: const SmartHomeApp(),
        ),
      );
      await settle(tester, 10);

      expect(
        find.text('Demo dom (mock)'),
        findsOneWidget,
        reason: 'home name from cache',
      );
      expect(find.byKey(const Key('staleDataBanner')), findsOneWidget);
      expect(
        find.text(en.lightsOnOf(2, 3)),
        findsOneWidget,
        reason: 'last known values',
      );

      await goTo(tester, AppRoutes.device('switch.coffee_machine'));
      expect(find.byKey(const Key('staleDataBanner')), findsOneWidget);
      expect(find.text(en.controlsOffline), findsOneWidget);
      final ignore = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byKey(const Key('powerSwitch')),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignore.ignoring, isTrue);

      // Server comes back: banner disappears, controls work again.
      server.online = true;
      await tester.pump(const Duration(minutes: 2)); // let the backoff retry
      await settle(tester, 10);
      expect(find.byKey(const Key('staleDataBanner')), findsNothing);
      await unmount(tester);
    },
  );
}
