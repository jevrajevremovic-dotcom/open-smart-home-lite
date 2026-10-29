import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/authentication/application/session_controller.dart';
import 'package:open_smart_home_lite/features/connection/application/connection_setup_controller.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/domain/home_snapshot.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../helpers.dart';

void main() {
  test(
    'repeated sign-in / sign-out leaves no sockets or subscriptions behind',
    () async {
      final server = MockHomeAssistantServer();
      final c = ProviderContainer(
        overrides: [
          ...await testOverrides(),
          mockHomeAssistantServerProvider.overrideWithValue(server),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.future);
      // Keep the snapshot provider alive like a visible screen would.
      final sub = c.listen(homeSnapshotProvider, (_, _) {});
      addTearDown(sub.close);

      for (var cycle = 0; cycle < 5; cycle++) {
        final setup = c.read(connectionSetupControllerProvider.notifier);
        await setup.checkServer('homeassistant.local:8123');
        expect(await setup.authenticate('token-$cycle'), isTrue);

        // Wait until live (one socket, subscriptions active).
        for (
          var i = 0;
          i < 100 && c.read(homeSnapshotProvider).status != SyncStatus.live;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(
          c.read(homeSnapshotProvider).status,
          SyncStatus.live,
          reason: 'cycle $cycle',
        );
        expect(
          server.openConnections,
          1,
          reason: 'exactly one socket per session',
        );
        expect(
          server.activeSubscriptions,
          5,
          reason: 'state_changed + 4 registry events, no duplicates',
        );

        await c.read(sessionControllerProvider.notifier).signOut();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          server.openConnections,
          0,
          reason: 'socket closed after sign-out (cycle $cycle)',
        );
        expect(c.read(webSocketManagerProvider), isNull);
        expect(
          c.read(homeSnapshotProvider).hasData,
          isFalse,
          reason: 'no data of the old session',
        );
      }
    },
  );
}
