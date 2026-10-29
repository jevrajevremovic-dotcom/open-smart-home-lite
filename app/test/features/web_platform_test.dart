import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/config/platform_info.dart';
import 'package:open_smart_home_lite/core/network/server_address.dart';
import 'package:open_smart_home_lite/features/authentication/application/session_controller.dart';
import 'package:open_smart_home_lite/features/connection/application/connection_setup_controller.dart';

import '../helpers.dart';

Future<ProviderContainer> containerFor(PlatformInfo platform) async {
  final container = ProviderContainer(
    overrides: [
      ...await testOverrides(),
      platformInfoProvider.overrideWithValue(platform),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  await container.read(sessionControllerProvider.future);
  return container;
}

void main() {
  group('PlatformInfo', () {
    test('suggests the page origin when hosted by Home Assistant', () {
      final p = PlatformInfo(
        isWeb: true,
        pageUri: Uri.parse(
          'http://homeassistant.local:8123/local/osh/#/welcome',
        ),
      );
      expect(p.suggestedServerAddress, 'http://homeassistant.local:8123');
      expect(p.isSecurePage, isFalse);
    });

    test('no suggestion on mobile', () {
      const p = PlatformInfo(isWeb: false);
      expect(p.suggestedServerAddress, isNull);
      expect(p.isSecurePage, isFalse);
    });
  });

  group('mixed content on the web', () {
    final securePage = PlatformInfo(
      isWeb: true,
      pageUri: Uri.parse('https://panel.example.com/'),
    );

    test('https page cannot use an http server', () async {
      final c = await containerFor(securePage);
      final ok = await c
          .read(connectionSetupControllerProvider.notifier)
          .checkServer('http://192.168.1.10:8123');
      expect(ok, isFalse);
      expect(
        c.read(connectionSetupControllerProvider).addressError,
        ServerAddressError.blockedMixedContent,
      );
    });

    test('https page may use an https server or loopback', () async {
      final c = await containerFor(securePage);
      final setup = c.read(connectionSetupControllerProvider.notifier);
      expect(await setup.checkServer('https://ha.example.com'), isTrue);
      expect(await setup.checkServer('http://localhost:8123'), isTrue);
    });

    test('http page may use an http server', () async {
      final c = await containerFor(
        PlatformInfo(
          isWeb: true,
          pageUri: Uri.parse('http://homeassistant.local:8123/local/osh/'),
        ),
      );
      expect(
        await c
            .read(connectionSetupControllerProvider.notifier)
            .checkServer('http://homeassistant.local:8123'),
        isTrue,
      );
    });
  });
}
