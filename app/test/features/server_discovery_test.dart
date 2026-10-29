import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/network/server_address.dart';
import 'package:open_smart_home_lite/features/connection/application/discovery_controller.dart';
import 'package:open_smart_home_lite/features/connection/data/server_discovery.dart';

import '../helpers.dart';
import '../widgets/app_widget_test.dart' show en, pumpApp, settle, unmount;

DiscoveredServer? parse({
  String? name = 'Home Assistant',
  String? host = 'homeassistant.local.',
  int? port = 8123,
  List<String> ips = const ['192.168.1.20'],
  Map<String, String?> txt = const {},
}) => discoveredServerFrom(
  serviceName: name,
  host: host,
  port: port,
  ipv4Addresses: ips,
  txt: txt,
);

class ControlledDiscovery implements ServerDiscovery {
  // ignore: close_sinks – closed by the tests that need it.
  final controller = StreamController<List<DiscoveredServer>>();
  var cancelled = false;

  @override
  bool get isSupported => true;

  @override
  Stream<List<DiscoveredServer>> discover() {
    controller.onCancel = () => cancelled = true;
    return controller.stream;
  }
}

void main() {
  group('choosing the address of a discovered server', () {
    test('IPv4 is preferred over .local (works on every Android)', () {
      final s = parse(
        txt: {
          'internal_url': 'http://homeassistant.local:8123',
          'location_name': 'Kuća',
        },
      )!;
      expect(s.address.toString(), 'http://192.168.1.20:8123');
      expect(s.name, 'Kuća');
    });

    test(
      'a configured HTTPS internal URL wins (certificate matches its name)',
      () {
        final s = parse(txt: {'internal_url': 'https://ha.home.arpa:8123'})!;
        expect(s.address.toString(), 'https://ha.home.arpa:8123');
      },
    );

    test('falls back to TXT URLs, then to the host name', () {
      expect(
        parse(
          ips: [],
          txt: {'base_url': 'http://10.0.0.5:8123'},
        )!.address.toString(),
        'http://10.0.0.5:8123',
      );
      expect(
        parse(ips: [])!.address.toString(),
        'http://homeassistant.local:8123',
      );
    });

    test('TXT records cannot point the app at an internet host', () {
      final s = parse(
        ips: [],
        host: null,
        txt: {
          'internal_url': 'https://evil.example.com',
          'base_url': 'http://8.8.8.8',
        },
      );
      expect(s, isNull);
    });

    test('version and uuid come from TXT; uuid identifies the server', () {
      final s = parse(txt: {'version': '2026.10.1', 'uuid': 'abc'})!;
      expect((s.version, s.key), ('2026.10.1', 'abc'));
    });
  });

  group('DiscoveryController', () {
    late ControlledDiscovery discovery;
    late ProviderContainer c;

    setUp(() async {
      discovery = ControlledDiscovery();
      c = ProviderContainer(
        overrides: [
          ...await testOverrides(),
          serverDiscoveryProvider.overrideWithValue(discovery),
        ],
      );
      addTearDown(c.dispose);
      c.listen(discoveryControllerProvider, (_, _) {}); // keep alive
    });

    final server = DiscoveredServer(
      name: 'Kuća',
      address: (ServerAddress.parse(
        'http://192.168.1.20:8123',
      ) as ValidServerAddress).address,
    );

    test('collects results while searching', () async {
      c.read(discoveryControllerProvider.notifier).start();
      expect(c.read(discoveryControllerProvider).searching, isTrue);
      discovery.controller.add([server]);
      await pumpEventQueue();
      expect(c.read(discoveryControllerProvider).servers.single.name, 'Kuća');
    });

    test(
      'an unavailable platform ends the search instead of hanging',
      () async {
        c.read(discoveryControllerProvider.notifier).start();
        await discovery.controller.close();
        await pumpEventQueue();
        final s = c.read(discoveryControllerProvider);
        expect((s.searching, s.finished), (false, true));
      },
    );

    test('disposing the screen stops the system discovery', () async {
      c.read(discoveryControllerProvider.notifier).start();
      c.invalidate(discoveryControllerProvider);
      await pumpEventQueue();
      expect(discovery.cancelled, isTrue);
    });
  });

  testWidgets('mock mode: tap a discovered server to continue', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(en.getStarted));
    await settle(tester, 10);
    expect(find.text(en.discoveryTitle), findsOneWidget);
    expect(find.text('Demo dom (mock)'), findsOneWidget);

    await tester.tap(find.text('Demo dom (mock)'));
    await settle(tester, 6);
    expect(find.text(en.tokenTitle), findsOneWidget);

    await tester.pump(DiscoveryController.searchDuration);
    await unmount(tester);
  });
}
