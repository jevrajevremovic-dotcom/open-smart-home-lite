import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/restricted/application/restricted_mode.dart';

import '../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('home activity lists changes and filters them', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    await tapKey(tester, 'openActivity');
    await settle(tester, 8);

    expect(find.text(en.activityTitle), findsWidgets);
    expect(find.text('Hodnik'), findsWidgets);
    expect(find.text('Brava ulazna vrata'), findsWidgets);
    expect(find.textContaining(en.activityByUser), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('activityFilter-lights')));
    await settle(tester, 2);
    expect(find.text('Hodnik'), findsWidgets);
    expect(find.text('Brava ulazna vrata'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('activityFilter-security')));
    await settle(tester, 2);
    expect(find.text('Hodnik'), findsNothing);
    expect(find.text('Brava ulazna vrata'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('activityFilter-people')));
    await settle(tester, 2);
    expect(find.byKey(const Key('activityEmpty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('children and guests do not see lock activity', (tester) async {
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      overrides: [
        restrictedModeProvider.overrideWithBuild(
          (ref, notifier) => const RestrictedSettings(enabled: true),
        ),
      ],
    );
    await settle(tester, 10);
    await tapKey(tester, 'openActivity');
    await settle(tester, 8);
    expect(find.text('Hodnik'), findsWidgets);
    expect(find.text('Brava ulazna vrata'), findsNothing);
    await unmount(tester);
  });
}
