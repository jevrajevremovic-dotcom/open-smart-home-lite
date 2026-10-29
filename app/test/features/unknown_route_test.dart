import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, unmount;

void main() {
  testWidgets('an unknown location goes home, no error page', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(400, 860));
    await settle(tester, 6);
    await goTo(tester, '/does-not-exist?x=1');
    await settle(tester, 4);
    expect(find.textContaining('GoException'), findsNothing);
    expect(find.text(en.navHome), findsWidgets);
    await unmount(tester);
  });
}
