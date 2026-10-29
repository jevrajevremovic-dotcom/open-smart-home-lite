import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/add_device/data/matter_pairing.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeMatterNewDevice;

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('Matter codes: QR payload, manual code with Verhoeff check digit', () {
    expect(MatterCode.normalize(' 3497-011-2332 '), '34970112332');
    expect(MatterCode.normalize('34970112333'), isNull, reason: 'bad check');
    expect(MatterCode.normalize('1234'), isNull);
    expect(
      MatterCode.normalize('mt:Y.K9042C00KA0648G00'),
      'MT:Y.K9042C00KA0648G00',
    );
    expect(MatterCode.normalize('MT:'), isNull);
    expect(MatterCode.verhoeffDigit('3497011233'), 2);
  });

  testWidgets('add a shared Matter device by its code', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.addDevice);
    await tapKey(tester, 'addMatter');
    await settle(tester, 4);

    await tester.enterText(find.byKey(const Key('matterCode')), '1234');
    await tapKey(tester, 'matterAdd');
    await settle(tester, 2);
    expect(find.text(en.matterInvalidCode), findsOneWidget);

    // Well-formed, but the demo hub can't reach it.
    final unreachable = '0000000000${MatterCode.verhoeffDigit('0000000000')}';
    await tester.enterText(find.byKey(const Key('matterCode')), unreachable);
    await tapKey(tester, 'matterAdd');
    await settle(tester, 6);
    expect(find.text(en.matterFailed), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('matterCode')),
      '3497-011-2332',
    );
    await tapKey(tester, 'matterAdd');
    await settle(tester, 8);
    expect(find.byKey(const Key('matterAdded')), findsOneWidget);
    expect(find.text('Eve Energy'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a brand-new device over Bluetooth ends up in Home Assistant', (
    tester,
  ) async {
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      matter: FakeMatterNewDevice(),
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.addDevice);
    await tapKey(tester, 'addMatter');
    await settle(tester, 4);

    await tapKey(tester, 'matterNewDevice');
    await settle(tester, 8);
    expect(find.byKey(const Key('matterAdded')), findsOneWidget);
    expect(find.text('Eve Energy'), findsOneWidget);
    expect(server.lastMatterIp, isNull, reason: 'link-local IPv6 dropped');
    await unmount(tester);
  });

  testWidgets('without Google Play services the app says so', (tester) async {
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      matter: FakeMatterNewDevice(error: 'unavailable'),
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.addDevice);
    await tapKey(tester, 'addMatter');
    await settle(tester, 4);
    await tapKey(tester, 'matterNewDevice');
    await settle(tester, 4);
    expect(find.text(en.matterNoPlayServices), findsOneWidget);
    // The shared-code way still works below.
    expect(find.byKey(const Key('matterCode')), findsOneWidget);
    await unmount(tester);
  });
}
