import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/add_device/data/zwave_inclusion.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('inclusion events', () {
    expect(
      ZwaveInclusionEvent.parse({
        'event': 'grant security classes',
        'requested_grant': {
          'securityClasses': [1, 0, 99],
          'clientSideAuth': true,
        },
      }),
      isA<ZwaveGrantRequested>()
          .having((g) => g.classes, 'classes', [
            ZwaveSecurityClass.s2Authenticated,
            ZwaveSecurityClass.s2Unauthenticated,
          ])
          .having((g) => g.clientSideAuth, 'csa', isTrue),
    );
    expect(
      ZwaveInclusionEvent.parse({
        'event': 'validate dsk and enter pin',
        'dsk': 'x',
      }),
      isA<ZwaveDskRequested>(),
    );
    expect(ZwaveInclusionEvent.parse({'event': '?'}), isA<ZwaveOther>());
    expect(ZwaveInclusion.isZwaveQr('90${'1' * 60}'), isTrue);
    expect(ZwaveInclusion.isZwaveQr('MT:ABC'), isFalse);
  });

  Future<void> openZwave(WidgetTester tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.addDevice);
    await tapKey(tester, 'addZwave');
    await settle(tester, 4);
  }

  testWidgets('S2 inclusion: grant, PIN, interview, new device', (
    tester,
  ) async {
    await openZwave(tester);
    await tapKey(tester, 'zwaveStart');
    await settle(tester, 3);
    expect(find.text(en.zwaveStatusWaiting), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester, 6);
    expect(find.text(en.zwaveGrantBody), findsOneWidget);
    await tapKey(tester, 'zwaveGrant');
    await settle(tester, 8);
    expect(find.text(en.zwavePinTitle), findsOneWidget);
    await tester.enterText(find.byKey(const Key('zwavePin')), '123');
    await tapKey(tester, 'zwavePinOk');
    await settle(tester, 2);
    expect(find.text(en.zwavePinInvalid), findsOneWidget);
    await tester.enterText(find.byKey(const Key('zwavePin')), '12345');
    await tapKey(tester, 'zwavePinOk');
    await settle(tester, 6);
    expect(find.text(en.zwaveStatusInterview), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester, 8);
    expect(find.text(en.zwaveStatusDone), findsOneWidget);
    expect(find.text('Aeotec MultiSensor 7 temperatura'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('wrong PIN fails; stop ends inclusion', (tester) async {
    await openZwave(tester);
    await tapKey(tester, 'zwaveStart');
    await tester.pump(const Duration(seconds: 4));
    await settle(tester, 6);
    await tapKey(tester, 'zwaveGrant');
    await settle(tester, 8);
    await tester.enterText(find.byKey(const Key('zwavePin')), '99999');
    await tapKey(tester, 'zwavePinOk');
    await settle(tester, 8);
    expect(find.text(en.zwaveStatusFailed), findsOneWidget);

    await tapKey(tester, 'zwaveStart');
    await settle(tester, 3);
    await tapKey(tester, 'zwaveStop');
    await settle(tester, 4);
    expect(find.text(en.zwaveStatusStopped), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester, 4);
    expect(find.text(en.zwaveGrantBody), findsNothing, reason: 'stopped');
    await unmount(tester);
  });
}
