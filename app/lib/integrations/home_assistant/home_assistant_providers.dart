import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/tls_trust.dart';
import '../../features/authentication/data/server_profile.dart';
import 'api/dio_home_assistant_api.dart';
import 'api/home_assistant_api.dart';
import 'auth/ha_auth_client.dart';
import 'mock/mock_home_assistant.dart';
import 'transport/transport.dart';
import 'websocket/ha_socket.dart';

/// Single in-memory server shared by the mock REST API and mock sockets.
final mockHomeAssistantServerProvider = Provider<MockHomeAssistantServer>(
  (ref) => MockHomeAssistantServer(),
);

typedef HomeAssistantApiFactory = HomeAssistantApi Function(
  ServerProfile profile,
  AccessTokenReader readToken,
);

/// Creates REST clients — real ones, or mock ones in mock mode.
final homeAssistantApiFactoryProvider = Provider<HomeAssistantApiFactory>((
  ref,
) {
  if (ref.watch(appConfigProvider).mockMode) {
    final server = ref.watch(mockHomeAssistantServerProvider);
    return (profile, readToken) => MockHomeAssistantApi(
      address: profile.address,
      server: server,
      readToken: readToken,
    );
  }
  return (profile, readToken) => DioHomeAssistantApi(
    address: profile.address,
    readToken: readToken,
    trust: profile.tlsTrust,
  );
});

/// Creates OAuth2 clients for a server — real ones, or mock ones in mock mode.
final haAuthClientFactoryProvider =
    Provider<HaAuthClient Function(ServerProfile profile)>((ref) {
      if (ref.watch(appConfigProvider).mockMode) {
        final server = ref.watch(mockHomeAssistantServerProvider);
        return (_) => MockHaAuthClient(server);
      }
      return (profile) =>
          DioHaAuthClient(address: profile.address, trust: profile.tlsTrust);
    });

/// Creates WebSocket connectors — real ones, or mock ones in mock mode.
final haSocketConnectorFactoryProvider =
    Provider<HaSocketConnector Function(TlsTrust trust)>((ref) {
      if (ref.watch(appConfigProvider).mockMode) {
        final server = ref.watch(mockHomeAssistantServerProvider);
        return (_) => server.connect;
      }
      return platformSocketConnector;
    });
