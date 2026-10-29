import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/core/network/server_address.dart';
import 'package:open_smart_home_lite/core/storage/app_preferences.dart';
import 'package:open_smart_home_lite/features/authentication/application/session_controller.dart';
import 'package:open_smart_home_lite/features/authentication/domain/stored_credential.dart';
import 'package:open_smart_home_lite/features/connection/application/connection_setup_controller.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../helpers.dart';

void main() {
  late InMemoryCredentialStore credentials;
  late ProviderContainer container;

  Future<void> init({Map<String, Object> prefs = const {}}) async {
    credentials = InMemoryCredentialStore();
    container = ProviderContainer(
      overrides: await testOverrides(
        credentials: credentials,
        preferences: prefs,
      ),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);
  }

  ConnectionSetupController setup() =>
      container.read(connectionSetupControllerProvider.notifier);

  test('starts signed out', () async {
    await init();
    expect(container.read(sessionControllerProvider).value, isNull);
  });

  test('invalid address is reported without network access', () async {
    await init();
    expect(await setup().checkServer('ftp://x'), isFalse);
    expect(
      container.read(connectionSetupControllerProvider).addressError,
      ServerAddressError.unsupportedScheme,
    );
  });

  test('insecure public address requires acknowledgement', () async {
    await init();
    expect(await setup().checkServer('http://ha.example.com'), isFalse);
    expect(
      container
          .read(connectionSetupControllerProvider)
          .needsInsecureAcknowledgement,
      isTrue,
    );

    setup().setInsecureAcknowledged(true);
    expect(await setup().checkServer('http://ha.example.com'), isTrue);
  });

  test('wrong token is rejected and nothing is stored', () async {
    await init();
    expect(await setup().checkServer('homeassistant.local:8123'), isTrue);
    expect(await setup().authenticate(mockInvalidToken), isFalse);
    expect(
      container.read(connectionSetupControllerProvider).authFailure?.kind,
      FailureKind.authentication,
    );
    expect(credentials.values, isEmpty);
    expect(container.read(sessionControllerProvider).value, isNull);
  });

  test(
    'successful sign-in stores token securely, not in preferences',
    () async {
      await init();
      await setup().checkServer('homeassistant.local:8123');
      expect(await setup().authenticate('  secret-token-123  '), isTrue);

      final session = container.read(sessionControllerProvider).value;
      expect(session, isNotNull);
      final stored = StoredCredential.parse(credentials.values.values.single);
      expect(
        stored,
        isA<LongLivedToken>().having(
          (c) => c.token,
          'token',
          'secret-token-123',
        ),
      );

      final prefsJson = container
          .read(appPreferencesProvider)
          .serverProfileJson
          .toString();
      expect(prefsJson, contains('homeassistant.local'));
      expect(prefsJson, isNot(contains('secret-token-123')));
    },
  );

  test('session is restored on restart', () async {
    await init();
    await setup().checkServer('homeassistant.local:8123');
    await setup().authenticate('token-abc');
    final storedPrefs = {
      'connection.activeServerProfile': '{"url":"http://homeassistant.local:8123","pinnedCertificateSha256":null,"insecureConnectionAcknowledged":false}',
    };
    final restored = ProviderContainer(
      overrides: await testOverrides(
        credentials: credentials,
        preferences: storedPrefs,
      ),
    );
    addTearDown(restored.dispose);
    final session = await restored.read(sessionControllerProvider.future);
    expect(session?.profile.address.host, 'homeassistant.local');
  });

  test('profile without token counts as signed out', () async {
    await init(
      prefs: {
        'connection.activeServerProfile':
            '{"url":"http://homeassistant.local:8123"}',
      },
    );
    expect(container.read(sessionControllerProvider).value, isNull);
  });

  test('sign-out deletes the token and the profile', () async {
    await init();
    await setup().checkServer('homeassistant.local:8123');
    await setup().authenticate('token-abc');
    expect(container.read(webSocketManagerProvider), isNotNull);

    await container.read(sessionControllerProvider.notifier).signOut();
    expect(credentials.values, isEmpty);
    expect(container.read(appPreferencesProvider).serverProfileJson, isNull);
    expect(container.read(webSocketManagerProvider), isNull);
  });

  test('delete all local data wipes preferences and secrets', () async {
    await init(prefs: {'settings.themeMode': 'dark'});
    await setup().checkServer('homeassistant.local:8123');
    await setup().authenticate('token-abc');

    await container
        .read(sessionControllerProvider.notifier)
        .deleteAllLocalData();
    expect(credentials.values, isEmpty);
    expect(container.read(sharedPreferencesProvider).getKeys(), isEmpty);
  });

  group('router redirects', () {
    test('first-run wizard is shown until finished, not over the kiosk', () {
      String? go(String location, {bool kiosk = false}) => resolveRedirect(
        location: location,
        sessionLoading: false,
        signedIn: true,
        serverChosen: true,
        kioskActive: kiosk,
        firstRun: true,
      );
      expect(go(AppRoutes.home), AppRoutes.firstRun);
      expect(go(AppRoutes.connectToken), AppRoutes.firstRun);
      expect(go(AppRoutes.firstRun), isNull);
      expect(go(AppRoutes.home, kiosk: true), AppRoutes.kiosk);
    });

    test('loading goes to splash', () {
      expect(
        resolveRedirect(
          location: AppRoutes.home,
          sessionLoading: true,
          signedIn: false,
          serverChosen: false,
        ),
        AppRoutes.splash,
      );
    });

    test('signed out is kept in onboarding', () {
      expect(
        resolveRedirect(
          location: AppRoutes.home,
          sessionLoading: false,
          signedIn: false,
          serverChosen: false,
        ),
        AppRoutes.welcome,
      );
      expect(
        resolveRedirect(
          location: AppRoutes.connectServer,
          sessionLoading: false,
          signedIn: false,
          serverChosen: false,
        ),
        isNull,
      );
      expect(
        resolveRedirect(
          location: AppRoutes.connectToken,
          sessionLoading: false,
          signedIn: false,
          serverChosen: false,
        ),
        AppRoutes.connectServer,
      );
    });

    test('signed in leaves onboarding', () {
      expect(
        resolveRedirect(
          location: AppRoutes.welcome,
          sessionLoading: false,
          signedIn: true,
          serverChosen: false,
        ),
        AppRoutes.home,
      );
      expect(
        resolveRedirect(
          location: AppRoutes.settings,
          sessionLoading: false,
          signedIn: true,
          serverChosen: false,
        ),
        isNull,
      );
    });
  });
}
