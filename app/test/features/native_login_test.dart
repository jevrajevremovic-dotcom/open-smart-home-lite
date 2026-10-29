import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/authentication/application/native_login.dart';
import 'package:open_smart_home_lite/features/authentication/domain/stored_credential.dart';

import '../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  test('only the app redirect counts as the callback', () {
    expect(
      NativeLoginService.isCallback(
        Uri.parse('http://open-smart-home.localhost/auth-callback?code=x'),
      ),
      isTrue,
    );
    for (final other in [
      'https://open-smart-home.localhost/auth-callback',
      'http://open-smart-home.localhost/other',
      'http://evil.example/auth-callback',
      'http://homeassistant.local:8123/auth/authorize',
    ]) {
      expect(NativeLoginService.isCallback(Uri.parse(other)), isFalse);
    }
  });

  testWidgets('sign in on Home Assistant\'s page instead of a token', (
    tester,
  ) async {
    final credentials = await pumpApp(tester);
    await tester.tap(find.text(en.getStarted));
    await settle(tester, 5);
    await tester.enterText(
      find.byKey(const Key('serverAddressField')),
      'homeassistant.local:8123',
    );
    await tapKey(tester, 'checkServerButton');
    await settle(tester);

    expect(find.text(en.oauthHintNative), findsOneWidget);
    await tapKey(tester, 'oauthSignInNative');
    await settle(tester, 20);
    // The first-run wizard comes first; skip it.
    await tapKey(tester, 'firstRunSkip');
    await settle(tester, 10);

    expect(find.text('Demo dom (mock)'), findsOneWidget);
    final stored = StoredCredential.parse(credentials.values.values.single);
    expect(stored, isA<OAuthTokens>());
    expect((stored! as OAuthTokens).clientId, NativeLoginService.clientId);
    await unmount(tester);
  });
}
