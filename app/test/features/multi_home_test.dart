import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/authentication/application/session_controller.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('adding a home keeps the connect screens reachable', () {
    String? go(String location, {bool adding = false}) => resolveRedirect(
      location: location,
      sessionLoading: false,
      signedIn: true,
      serverChosen: true,
      addingHome: adding,
    );
    expect(go(AppRoutes.connectServer), AppRoutes.home);
    expect(go(AppRoutes.connectServer, adding: true), isNull);
    expect(go(AppRoutes.welcome, adding: true), AppRoutes.home);
  });

  testWidgets('add a second home, switch between homes, sign out of one', (
    tester,
  ) async {
    final credentials = await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
    );
    await settle(tester, 10);
    ProviderContainer container() =>
        ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)));
    final first = container().read(activeProfileProvider)!;

    await goTo(tester, AppRoutes.settingsSection('server'));
    await tapKey(tester, 'addHome');
    await settle(tester, 4);
    expect(find.byKey(const Key('cancelAddHome')), findsOneWidget);
    await tapKey(tester, 'cancelAddHome');
    await settle(tester, 4);
    expect(container().read(activeProfileProvider), first);

    // Android back does the same instead of closing the app.
    await goTo(tester, AppRoutes.settingsSection('server'));
    await tapKey(tester, 'addHome');
    await settle(tester, 4);
    await tester.binding.handlePopRoute();
    await settle(tester, 4);
    expect(find.byKey(const Key('cancelAddHome')), findsNothing);
    expect(container().read(addingHomeProvider), isFalse);

    await goTo(tester, AppRoutes.settingsSection('server'));
    await tapKey(tester, 'addHome');
    await settle(tester, 4);
    await tester.enterText(
      find.byKey(const Key('serverAddressField')),
      '192.168.1.50:8123',
    );
    await tapKey(tester, 'checkServerButton');
    await settle(tester, 10);
    await tester.enterText(find.byKey(const Key('tokenField')), 'second-token');
    await tapKey(tester, 'connectButton');
    await settle(tester, 20);
    final second = container().read(activeProfileProvider)!;
    expect(second.id, isNot(first.id));
    expect(credentials.values, hasLength(2));

    // Dashboard switcher back to the first home.
    await goTo(tester, AppRoutes.home);
    await settle(tester, 6);
    await tester.tap(find.byKey(const Key('homeSwitcher')));
    await settle(tester, 4);
    await tester.tap(find.byKey(ValueKey('switchHome-${first.id}')));
    await settle(tester, 10);
    expect(container().read(activeProfileProvider)!.id, first.id);
    expect(find.text(en.statusConnected), findsWidgets);

    // Signing out of the active home moves to the other one.
    await container().read(sessionControllerProvider.notifier).signOut();
    await settle(tester, 10);
    expect(container().read(activeProfileProvider)!.id, second.id);
    expect(credentials.values, hasLength(1));
    await unmount(tester);
  });
}
