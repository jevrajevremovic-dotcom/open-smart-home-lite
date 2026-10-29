import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/network/server_address.dart';

ServerAddress valid(String input) {
  final result = ServerAddress.parse(input);
  expect(result, isA<ValidServerAddress>(), reason: input);
  return (result as ValidServerAddress).address;
}

ServerAddressError invalid(String input) {
  final result = ServerAddress.parse(input);
  expect(result, isA<InvalidServerAddress>(), reason: input);
  return (result as InvalidServerAddress).error;
}

void main() {
  group('ServerAddress.parse normalisation', () {
    test('adds http:// for local addresses without scheme', () {
      expect(
        valid('192.168.1.10:8123').baseUri.toString(),
        'http://192.168.1.10:8123',
      );
      expect(
        valid('homeassistant.local:8123').baseUri.toString(),
        'http://homeassistant.local:8123',
      );
      expect(
        valid('homeassistant:8123').baseUri.toString(),
        'http://homeassistant:8123',
      );
    });

    test('adds https:// for public names without scheme', () {
      expect(
        valid('ha.example.com').baseUri.toString(),
        'https://ha.example.com',
      );
    });

    test('keeps explicit scheme, lower-cases host, strips trailing slash', () {
      expect(
        valid('  HTTPS://HA.Example.com/  ').baseUri.toString(),
        'https://ha.example.com',
      );
      expect(
        valid('http://10.0.0.5:8123/').baseUri.toString(),
        'http://10.0.0.5:8123',
      );
    });

    test('supports IPv6 literals', () {
      final a = valid('http://[fd00::10]:8123');
      expect(a.isLocalNetwork, isTrue);
      expect(a.webSocketUri.toString(), 'ws://[fd00::10]:8123/api/websocket');
    });
  });

  group('ServerAddress.parse rejects', () {
    test('empty and whitespace', () {
      expect(invalid(''), ServerAddressError.empty);
      expect(invalid('   '), ServerAddressError.empty);
      expect(invalid('my server'), ServerAddressError.malformed);
    });

    test('unsupported schemes', () {
      expect(invalid('ftp://10.0.0.1'), ServerAddressError.unsupportedScheme);
      expect(invalid('ws://10.0.0.1'), ServerAddressError.unsupportedScheme);
    });

    test('credentials, paths, queries, bad ports and hosts', () {
      expect(
        invalid('http://user:pw@10.0.0.1'),
        ServerAddressError.credentialsNotAllowed,
      );
      expect(
        invalid('https://example.com/ha'),
        ServerAddressError.pathNotSupported,
      );
      expect(
        invalid('https://example.com/?a=1'),
        ServerAddressError.queryNotAllowed,
      );
      expect(
        invalid('https://example.com/#x'),
        ServerAddressError.queryNotAllowed,
      );
      expect(
        invalid('http://10.0.0.1:99999'),
        anyOf(ServerAddressError.invalidPort, ServerAddressError.malformed),
      );
      expect(invalid('http://-bad-.lan'), ServerAddressError.malformed);
    });
  });

  group('locality and risk', () {
    test('private ranges are local', () {
      for (final host in [
        '10.1.2.3',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.0.1',
        '127.0.0.1',
        '169.254.1.1',
        'fe80::1',
        'fd12::1',
        'nas.home.arpa',
        'pi.lan',
      ]) {
        expect(ServerAddress.isLocalHost(host), isTrue, reason: host);
      }
    });

    test('public addresses are not local', () {
      for (final host in [
        '8.8.8.8',
        '172.32.0.1',
        '100.64.0.1',
        'example.com',
        '2001:db8::1',
      ]) {
        expect(ServerAddress.isLocalHost(host), isFalse, reason: host);
      }
    });

    test('Tailscale addresses are a VPN, not the open internet', () {
      for (final a in [
        'http://100.101.102.103:8123',
        'http://homeassistant.tail1234.ts.net:8123',
        'http://[fd7a:115c:a1e0::1]:8123',
      ]) {
        expect(valid(a).risk, ConnectionRisk.vpnTunnel, reason: a);
      }
      // Just outside 100.64.0.0/10.
      expect(
        valid('http://100.128.0.1:8123').risk,
        ConnectionRisk.insecureRemote,
      );
      expect(
        valid('http://100.63.255.1:8123').risk,
        ConnectionRisk.insecureRemote,
      );
    });

    test('risk classification', () {
      expect(valid('http://192.168.1.2:8123').risk, ConnectionRisk.none);
      expect(
        valid('https://ha.example.com').risk,
        ConnectionRisk.remoteExposure,
      );
      expect(
        valid('http://ha.example.com').risk,
        ConnectionRisk.insecureRemote,
      );
    });
  });

  test('derives REST and WebSocket URIs', () {
    final a = valid('https://ha.example.com:8443');
    expect(
      a.restUri('/api/states').toString(),
      'https://ha.example.com:8443/api/states',
    );
    expect(
      a.webSocketUri.toString(),
      'wss://ha.example.com:8443/api/websocket',
    );
  });

  test('fromStored round-trips', () {
    final a = valid('homeassistant.local:8123');
    expect(ServerAddress.fromStored(a.baseUri.toString()), a);
  });
}
