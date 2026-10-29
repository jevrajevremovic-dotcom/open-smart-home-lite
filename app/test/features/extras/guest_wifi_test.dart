import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/extras/guest_wifi.dart';

import '../../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  test('the WIFI: text phones understand, with escapes', () {
    expect(
      const GuestWifi(ssid: 'Gosti', password: 'tajna123').qrText,
      'WIFI:T:WPA;S:Gosti;P:tajna123;;',
    );
    expect(
      const GuestWifi(ssid: r'Kuća;1', password: r'a:b,c\d"e').qrText,
      r'WIFI:T:WPA;S:Kuća\;1;P:a\:b\,c\\d\"e;;',
    );
    expect(
      const GuestWifi(ssid: 'Open', open: true, hidden: true).qrText,
      'WIFI:T:nopass;S:Open;H:true;;',
    );
  });

  testWidgets('set up once: a QR code; the password in secret storage', (
    tester,
  ) async {
    final credentials = await pumpApp(tester, size: const Size(800, 1600));
    await settle(tester, 10);
    await tapKey(tester, 'openExtras');
    await settle(tester, 5); // the sheet comes up
    await tapKey(tester, 'extraGuestWifi');
    await settle(tester, 2);
    expect(find.text(en.guestWifiNotSet), findsOneWidget);

    await tapKey(tester, 'guestWifiEdit');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('guestWifiSsid')), 'Gosti');
    await tester.enterText(
      find.byKey(const Key('guestWifiPassword')),
      'dobrodosli',
    );
    await tapKey(tester, 'guestWifiSave');
    await settle(tester, 3);

    expect(find.byKey(const Key('guestWifiQr')), findsOneWidget);
    expect(find.text('dobrodosli'), findsOneWidget);
    expect(credentials.values['osh.guest_wifi'], 'dobrodosli');
    await unmount(tester);
  });
}
