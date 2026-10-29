import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/network/server_address.dart';
import 'package:open_smart_home_lite/features/authentication/application/session_controller.dart';
import 'package:open_smart_home_lite/features/authentication/data/server_profile.dart';
import 'package:open_smart_home_lite/features/connection/application/connection_route.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

ServerAddress addr(String s) =>
    (ServerAddress.parse(s) as ValidServerAddress).address;

void main() {
  test('profile keeps a remote address; the remote route drops the pin', () {
    final p = ServerProfile(
      address: addr('https://192.168.1.24'),
      pinnedCertificateSha256: 'ab' * 32,
      remoteAddress: addr('https://kuca.ui.nabu.casa'),
    );
    final back = ServerProfile.tryFromJson(p.toJson())!;
    expect(back, p);
    expect(back.id, 'https://192.168.1.24');
    final remote = p.via(p.remoteAddress!);
    expect(remote.address.host, 'kuca.ui.nabu.casa');
    expect(remote.pinnedCertificateSha256, isNull);
    expect(p.via(p.address), same(p));
    expect(
      ServerProfile.tryFromJson({...p.toJson(), 'remoteUrl': 'nope://'})!
          .remoteAddress,
      isNull,
    );
  });

  testWidgets('away from home the app switches to the remote address and '
      'back when home answers again', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    ProviderContainer c() =>
        ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)));
    final server = c().read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.settingsSection('server'));
    expect(find.text(en.remoteNotSet), findsOneWidget);
    await tapKey(tester, 'remoteAddressTile');
    await settle(tester, 3);

    // Plain HTTP to a public address is refused.
    await tester.enterText(
      find.byKey(const Key('remoteAddressField')),
      'http://kuca.example.com',
    );
    await tester.tap(find.byKey(const Key('remoteAddressSave')));
    await settle(tester, 2);
    expect(find.text(en.remoteNeedsHttps), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('remoteAddressField')),
      'https://kuca.ui.nabu.casa',
    );
    await tester.tap(find.byKey(const Key('remoteAddressSave')));
    await settle(tester, 6);
    expect(
      c().read(activeProfileProvider)!.remoteAddress,
      addr('https://kuca.ui.nabu.casa'),
    );
    expect(find.text('https://kuca.ui.nabu.casa'), findsOneWidget);

    // Leave home: the home address stops answering.
    server.unreachableHosts.add('homeassistant.local');
    await server.dropAllConnections();
    await settle(tester, 60);
    expect(c().read(connectionRouteProvider), ConnectionRoute.remote);
    expect(
      c().read(effectiveProfileProvider)!.address.host,
      'kuca.ui.nabu.casa',
    );
    expect(find.textContaining(en.remoteInUse), findsOneWidget);
    expect(
      c().read(connectionStatusProvider).value?.isConnected,
      isTrue,
      reason: 'connected again through the remote address',
    );

    // Home again (e.g. the app comes back to the foreground).
    server.unreachableHosts.clear();
    // Not awaited: the probes run on the test's fake clock.
    unawaited(c().read(connectionRouteProvider.notifier).reevaluate());
    await settle(tester, 20);
    expect(c().read(connectionRouteProvider), ConnectionRoute.local);
    expect(c().read(connectionStatusProvider).value?.isConnected, isTrue);
    await unmount(tester);
  });
}
