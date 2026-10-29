import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/connection/data/server_discovery.dart';
import 'package:open_smart_home_lite/features/connection/data/server_discovery_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = EventChannel('org.opensmarthome/nsd');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockStreamHandler(channel, null));

  test('Android channel events become servers; lost ones disappear', () async {
    Object? askedType;
    var cancelled = false;
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          askedType = args;
          sink
            ..success({
              'status': 'found',
              'name': 'Home',
              'port': 8123,
              'addresses': ['192.168.1.20'],
              'txt': {
                'location_name': Uint8List.fromList(utf8.encode('Kuća')),
                'uuid': Uint8List.fromList(utf8.encode('abc')),
                // A TXT record may not point the app at the internet.
                'base_url': Uint8List.fromList(
                  utf8.encode('https://evil.example'),
                ),
              },
            })
            ..success({
              'status': 'found',
              'name': 'Internet',
              'port': 8123,
              'addresses': ['8.8.8.8'],
              'txt': <String, Object?>{},
            })
            ..success({'status': 'lost', 'name': 'Home'});
        },
        onCancel: (_) => cancelled = true,
      ),
    );

    final events = await AndroidServerDiscovery().discover().take(2).toList();
    expect(askedType, homeAssistantServiceType);
    expect(events.first.single.name, 'Kuća');
    expect(events.first.single.uuid, 'abc');
    expect(events.first.single.address.host, '192.168.1.20');
    expect(events.last, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
  });

  test('a refused search just ends', () async {
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (_, sink) => sink.error(code: 'start_failed'),
      ),
    );
    expect(await AndroidServerDiscovery().discover().toList(), isEmpty);
  });
}
