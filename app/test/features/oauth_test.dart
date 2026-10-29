import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/core/network/server_address.dart';
import 'package:open_smart_home_lite/core/platform/browser_port.dart';
import 'package:open_smart_home_lite/features/authentication/application/access_token_manager.dart';
import 'package:open_smart_home_lite/features/authentication/application/session_controller.dart';
import 'package:open_smart_home_lite/features/authentication/application/web_login.dart';
import 'package:open_smart_home_lite/features/authentication/domain/stored_credential.dart';
import 'package:open_smart_home_lite/features/connection/application/connection_setup_controller.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/auth/ha_auth_client.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../helpers.dart';
import '../integrations/home_assistant_api_test.dart' show FakeAdapter;

const serverId = 'http://homeassistant.local:8123';
final appUrl = Uri.parse(
  'http://homeassistant.local:8123/local/opensmarthome/',
);

class FailingAuthClient extends MockHaAuthClient {
  FailingAuthClient(super.server);

  @override
  Future<OAuthTokenResponse> refresh({
    required String refreshToken,
    required String clientId,
  }) => Future.error(
    const AppFailure(FailureKind.network, debugMessage: 'offline'),
  );
}

void main() {
  group('StoredCredential', () {
    test('plain text from 0.1.0 is read as a long-lived token', () {
      expect(
        StoredCredential.parse('abc.def'),
        isA<LongLivedToken>().having((t) => t.token, 'token', 'abc.def'),
      );
    });

    test('round-trips and rejects garbage', () {
      final t = OAuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        clientId: 'http://x/',
        expiresAt: DateTime.utc(2026, 10, 13, 12),
        persistent: false,
      );
      final back = StoredCredential.parse(t.serialize())! as OAuthTokens;
      expect(
        (back.accessToken, back.refreshToken, back.clientId, back.persistent),
        ('a', 'r', 'http://x/', false),
      );
      expect(back.expiresAt, DateTime.utc(2026, 10, 13, 12));
      expect(StoredCredential.parse('{"type":"oauth"}'), isNull);
      expect(StoredCredential.parse('{nope'), isNull);
      expect(StoredCredential.parse(''), isNull);
    });

    test('refreshes one minute before expiry', () {
      final t = OAuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        clientId: 'c',
        expiresAt: DateTime(2026, 1, 1, 12),
      );
      expect(t.needsRefresh(DateTime(2026, 1, 1, 11, 58)), isFalse);
      expect(t.needsRefresh(DateTime(2026, 1, 1, 11, 59, 30)), isTrue);
    });
  });

  group('DioHaAuthClient (documented Auth API)', () {
    final address = (ServerAddress.parse(
      'http://192.168.1.10:8123',
    ) as ValidServerAddress).address;

    (DioHaAuthClient, FakeAdapter) build(
      (int, Object?) Function(RequestOptions) handler,
    ) {
      final adapter = FakeAdapter(handler);
      return (
        DioHaAuthClient(
          address: address,
          dio: Dio()..httpClientAdapter = adapter,
        ),
        adapter,
      );
    }

    test('authorize URL', () {
      final (client, _) = build((_) => (200, {}));
      final url = client.authorizeUrl(
        clientId: 'http://app/',
        redirectUri: Uri.parse('http://app/cb'),
        state: 's1',
      );
      expect(url.path, '/auth/authorize');
      expect(url.queryParameters, {
        'response_type': 'code',
        'client_id': 'http://app/',
        'redirect_uri': 'http://app/cb',
        'state': 's1',
      });
    });

    test('code exchange posts a form to /auth/token', () async {
      final (client, adapter) = build(
        (_) => (
          200,
          {
            'access_token': 'A',
            'expires_in': 1800,
            'refresh_token': 'R',
            'token_type': 'Bearer',
          },
        ),
      );
      final r = await client.exchangeCode(code: 'C', clientId: 'http://app/');
      expect(
        (r.accessToken, r.refreshToken, r.expiresIn),
        ('A', 'R', const Duration(minutes: 30)),
      );
      final req = adapter.requests.single;
      expect(req.path, '/auth/token');
      expect(req.contentType, Headers.formUrlEncodedContentType);
      expect(req.data, {
        'grant_type': 'authorization_code',
        'code': 'C',
        'client_id': 'http://app/',
      });
      expect(req.headers.containsKey('Authorization'), isFalse);
    });

    test('invalid_grant (400) means: sign in again', () async {
      final (client, _) = build((_) => (400, {'error': 'invalid_grant'}));
      await expectLater(
        client.refresh(refreshToken: 'R', clientId: 'c'),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.kind,
            'kind',
            FailureKind.authentication,
          ),
        ),
      );
    });

    test('revoke posts the token and never throws', () async {
      final (client, adapter) = build((_) => (500, 'boom'));
      await client.revoke('R');
      expect(adapter.requests.single.path, '/auth/revoke');
      expect(adapter.requests.single.data, {'token': 'R'});
    });
  });

  group('AccessTokenManager', () {
    late MockHomeAssistantServer server;
    late InMemoryCredentialStore store;
    var now = DateTime(2026, 10, 13, 12);

    Future<OAuthTokens> issue() async {
      final client = MockHaAuthClient(server);
      final code = client
          .authorizeUrl(clientId: 'c', redirectUri: appUrl, state: 's')
          .queryParameters['code']!;
      final r = await client.exchangeCode(code: code, clientId: 'c');
      final tokens = OAuthTokens(
        accessToken: r.accessToken,
        refreshToken: r.refreshToken!,
        clientId: 'c',
        expiresAt: now.add(r.expiresIn),
      );
      await store.writeCredential(serverId, tokens.serialize());
      return tokens;
    }

    AccessTokenManager manager([MockHaAuthClient? client]) =>
        AccessTokenManager(
          serverId: serverId,
          store: store,
          authClient: () => client ?? MockHaAuthClient(server),
          now: () => now,
        );

    setUp(() {
      server = MockHomeAssistantServer();
      store = InMemoryCredentialStore();
      now = DateTime(2026, 10, 13, 12);
    });

    test('long-lived token is returned as stored', () async {
      await store.writeCredential(
        serverId,
        const LongLivedToken('llat').serialize(),
      );
      expect(await manager().accessToken(), 'llat');
    });

    test('valid access token is used without refreshing', () async {
      final t = await issue();
      expect(await manager().accessToken(), t.accessToken);
      expect(server.refreshCount, 0);
    });

    test(
      'expired token: one refresh for many parallel callers, persisted',
      () async {
        final t = await issue();
        now = now.add(const Duration(minutes: 31));
        final m = manager();
        final tokens = await Future.wait([
          for (var i = 0; i < 5; i++) m.accessToken(),
        ]);
        expect(tokens.toSet(), hasLength(1));
        expect(tokens.first, isNot(t.accessToken));
        expect(server.refreshCount, 1);
        final saved =
            StoredCredential.parse(store.values[serverId])! as OAuthTokens;
        expect(saved.accessToken, tokens.first);
        expect(
          saved.refreshToken,
          t.refreshToken,
          reason: 'refresh token is kept',
        );
      },
    );

    test('revoked refresh token → authentication failure', () async {
      final t = await issue();
      server.revokedRefreshTokens.add(t.refreshToken);
      now = now.add(const Duration(hours: 1));
      await expectLater(
        manager().accessToken(),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.kind,
            'kind',
            FailureKind.authentication,
          ),
        ),
      );
    });

    test('network failure during refresh stays transient', () async {
      await issue();
      now = now.add(const Duration(hours: 1));
      await expectLater(
        manager(FailingAuthClient(server)).accessToken(),
        throwsA(
          isA<AppFailure>().having((f) => f.isTransient, 'transient', isTrue),
        ),
      );
    });
  });

  group('web sign-in (OAuth2 authorization code)', () {
    late MockHomeAssistantServer server;
    late FakeBrowserPort browser;
    late InMemoryCredentialStore credentials;

    Future<ProviderContainer> container() async {
      final c = ProviderContainer(
        overrides: [
          ...await testOverrides(credentials: credentials),
          mockHomeAssistantServerProvider.overrideWithValue(server),
          browserPortProvider.overrideWithValue(browser),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      server = MockHomeAssistantServer();
      browser = FakeBrowserPort(appUrl.replace(fragment: '/connect/token'));
      credentials = InMemoryCredentialStore();
    });

    /// Starts sign-in in one "page load", returns the redirect URL.
    Future<Uri> startLogin({required bool remember}) async {
      final c = await container();
      await c.read(sessionControllerProvider.future);
      final setup = c.read(connectionSetupControllerProvider.notifier);
      await setup.checkServer('homeassistant.local:8123');
      setup.startWebSignIn(remember: remember);
      return browser.navigations.single;
    }

    test(
      'client_id is the app origin, redirect_uri the app page (same host)',
      () async {
        final r = Uri.parse(
          'http://homeassistant.local:8123/auth/authorize?client_id=x',
        );
        expect(r.host, appUrl.host); // sanity of the fixture
        final redirect = await startLogin(remember: false);
        // Mock HA redirects straight back to the app page with a code.
        expect(redirect.path, appUrl.path);
        expect(redirect.queryParameters.keys, containsAll(['code', 'state']));
        expect(browser.session.keys, contains('oauth_pending_login'));
        expect(
          browser.session.values.single,
          isNot(contains('token')),
          reason: 'nothing secret is stored',
        );
      },
    );

    test('callback completes the sign-in and cleans the address bar', () async {
      browser.currentUrl = await startLogin(remember: true);

      final c = await container(); // the page reloads after the redirect
      final session = await c.read(sessionControllerProvider.future);
      expect(session?.profile.id, serverId);
      final stored =
          StoredCredential.parse(credentials.values[serverId])! as OAuthTokens;
      expect(stored.persistent, isTrue, reason: '"remember me" was ticked');
      expect(stored.clientId, 'http://homeassistant.local:8123/');
      expect(browser.currentUrl.queryParameters, isEmpty);
      expect(browser.session, isEmpty);
    });

    test('a callback with a foreign state is rejected (login CSRF)', () async {
      final redirect = await startLogin(remember: false);
      browser.currentUrl = redirect.replace(
        queryParameters: {...redirect.queryParameters, 'state': 'attacker'},
      );
      final c = await container();
      expect(await c.read(sessionControllerProvider.future), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(loginErrorProvider)?.kind, FailureKind.validation);
      expect(credentials.values, isEmpty);
    });

    test(
      'a code works across a page reload (new mock server instance)',
      () async {
        final redirect = await startLogin(remember: false);
        server = MockHomeAssistantServer(); // the web page reloaded
        browser.currentUrl = redirect;
        final c = await container();
        expect(await c.read(sessionControllerProvider.future), isNotNull);
      },
    );

    test('a callback URL cannot be replayed', () async {
      final redirect = await startLogin(remember: false);
      browser.currentUrl = redirect;
      await (await container()).read(sessionControllerProvider.future);
      await (await container())
          .read(sessionControllerProvider.notifier)
          .signOut();

      browser.currentUrl = redirect; // same URL again (e.g. from history)
      final c = await container();
      expect(await c.read(sessionControllerProvider.future), isNull);
    });

    test('sign-out revokes the refresh token on the server', () async {
      browser.currentUrl = await startLogin(remember: false);
      final c = await container();
      await c.read(sessionControllerProvider.future);
      final refresh =
          (StoredCredential.parse(credentials.values[serverId])! as OAuthTokens)
              .refreshToken;
      expect(server.revokedRefreshTokens, isEmpty);

      await c.read(sessionControllerProvider.notifier).signOut();
      expect(server.revokedRefreshTokens, {refresh});
      expect(credentials.values, isEmpty);
    });

    test('OAuth button is offered only where a browser exists', () async {
      final c = await container();
      expect(c.read(webLoginServiceProvider).isSupported, isTrue);
      final mobile = ProviderContainer(
        overrides: await testOverrides(),
        retry: (_, _) => null,
      );
      addTearDown(mobile.dispose);
      expect(mobile.read(webLoginServiceProvider).isSupported, isFalse);
    });
  });
}
