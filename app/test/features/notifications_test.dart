import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/notifications/application/notifications_provider.dart';

import '../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  test('notification text without Markdown', () {
    final n = HaNotification.parse({
      'notification_id': 'x',
      'message': 'New devices. [Check](/config/integrations) **now**.',
    })!;
    expect(n.plainMessage, 'New devices. Check now.');
    expect(HaNotification.parse({'message': 'no id'}), isNull);
  });

  testWidgets('dashboard banner, sheet, dismiss one and all', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final banner = find.byKey(const Key('notificationsBanner'));
    expect(banner, findsOneWidget);
    expect(find.text(en.notificationsCount(2)), findsOneWidget);
    await tester.tap(banner);
    await settle(tester, 6);
    expect(find.text('Pranje je završeno. Izvadite veš.'), findsOneWidget);
    await tapKey(tester, 'dismiss-washer_done');
    await settle(tester, 4);
    expect(
      find.byKey(const ValueKey('notification-washer_done')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('notification-config_entry_discovery')),
      findsOneWidget,
    );
    await tapKey(tester, 'dismiss-config_entry_discovery');
    await settle(tester, 4);
    expect(find.text(en.notificationsEmpty), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('notificationsSheet'))))
        .pop();
    await settle(tester, 6);
    expect(banner, findsNothing);
    await unmount(tester);
  });
}
