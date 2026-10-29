part of 'mock_home_assistant.dart';

/// [HomeAssistantApi] backed by [MockHomeAssistantServer].
class MockHomeAssistantApi implements HomeAssistantApi {
  MockHomeAssistantApi({
    required this.address,
    required this.server,
    required this._readToken,
  });

  @override
  final ServerAddress address;
  final MockHomeAssistantServer server;
  final Future<String?> Function() _readToken;

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  Future<void> _requireAuth() async {
    await _latency();
    if (!server.reachable(address.host)) {
      throw const AppFailure(
        FailureKind.network,
        debugMessage: 'mock server offline',
      );
    }
    if (!server.acceptsToken(await _readToken())) {
      throw const AppFailure(FailureKind.authentication, statusCode: 401);
    }
  }

  @override
  Future<ServerProbeResult> probe() async {
    await _latency();
    if (!server.reachable(address.host)) {
      throw const AppFailure(
        FailureKind.network,
        debugMessage: 'mock server offline',
      );
    }
    return ServerProbeResult.reachableRequiresAuth;
  }

  @override
  Future<void> verifyAccessToken() => _requireAuth();

  @override
  Future<HaConfig> fetchConfig() async {
    await _requireAuth();
    return HaConfig.fromJson(server.config);
  }

  @override
  Future<List<HaEntityState>> fetchStates() async {
    await _requireAuth();
    return parseStateList(server.states);
  }

  @override
  Future<List<HaEntityState>> callService(
    String domain,
    String service, {
    Map<String, Object?> data = const {},
  }) async {
    await _requireAuth();
    return parseStateList(server.callService(domain, service, data));
  }

  @override
  Future<Object?> callServiceForResponse(
    String domain,
    String service, {
    Map<String, Object?> data = const {},
  }) async {
    await _requireAuth();
    if (domain != 'weather' || service != 'get_forecasts') {
      throw AppFailure(
        FailureKind.validation,
        debugMessage: '$domain.$service returns no response',
      );
    }
    final id = data['entity_id'];
    final hourly = data['type'] == 'hourly';
    // Shape of the documented `weather.get_forecasts` response.
    return {
      if (id is String)
        id: {
          'forecast': hourly ? server.hourlyForecast() : server.dailyForecast(),
        },
    };
  }

  @override
  Future<Map<String, Set<String>>> fetchServices() async {
    await _requireAuth();
    return parseServiceList(server.serviceList);
  }

  @override
  Future<List<HaCalendar>> fetchCalendars() async {
    await _requireAuth();
    await _latency();
    return HaCalendar.parseList(server.calendars);
  }

  @override
  Future<List<HaCalendarEvent>> fetchCalendarEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async {
    await _requireAuth();
    await _latency();
    return [
      for (final e in HaCalendarEvent.parseList(
        server.calendarEvents(calendarId),
        calendarId,
      ))
        if (e.start.isBefore(end) && e.end.isAfter(start)) e,
    ];
  }

  @override
  Future<List<HaHistoryPoint>> fetchHistory(
    String entityId,
    DateTime start,
    DateTime end,
  ) async {
    await _requireAuth();
    await _latency();
    return HaHistoryPoint.parse([server.history(entityId, start, end)]);
  }

  @override
  Future<List<HaLogbookEntry>> fetchLogbook(
    String? entityId,
    DateTime start,
    DateTime end,
  ) async {
    await _requireAuth();
    await _latency();
    // Like HA, the whole-home logbook leaves out continuous sensors.
    final ids = entityId != null ? [entityId] : server.logbookEntityIds();
    return HaLogbookEntry.parse([
      for (final id in ids)
        for (final (i, p) in server.history(id, start, end).indexed)
          if (i > 0)
            {
              'when': p['last_changed'],
              'state': p['state'],
              'entity_id': id,
              'name': server.friendlyName(id),
              if (i.isEven) 'context_user_id': 'mock-user',
            },
    ]);
  }

  @override
  Future<Map<String, Object?>> registerMobileApp(
    Map<String, Object?> body,
  ) async {
    await _requireAuth();
    return server.registerMobileApp(body);
  }

  @override
  Future<void> saveAutomation(String id, Map<String, Object?> config) async {
    await _requireAuth();
    await _latency();
    if (!server.configAdmin) {
      // Like HA: the config API needs an administrator (401).
      throw const AppFailure(FailureKind.authorization, statusCode: 401);
    }
    server.saveAutomation(id, config);
  }

  @override
  Future<void> deleteAutomation(String id) async {
    await _requireAuth();
    await _latency();
    server.deleteAutomation(id);
  }

  @override
  Future<Map<String, Object?>> fetchScene(String id) async {
    await _requireAuth();
    await _latency();
    final config = server.scenes[id];
    if (config == null) {
      throw const AppFailure(FailureKind.server, statusCode: 404);
    }
    return config;
  }

  @override
  Future<Map<String, Object?>> fetchAutomation(String id) async {
    await _requireAuth();
    await _latency();
    final config = server.automations[id];
    if (config == null) {
      throw const AppFailure(FailureKind.server, statusCode: 404);
    }
    return config;
  }

  @override
  Future<void> saveScript(String id, Map<String, Object?> config) async {
    await _requireAuth();
    await _latency();
    server.saveScript(id, config);
  }

  @override
  Future<void> saveScene(String id, Map<String, Object?> config) async {
    await _requireAuth();
    await _latency();
    server.saveScene(id, config);
  }

  @override
  Future<void> deleteScene(String id) async {
    await _requireAuth();
    await _latency();
    server.deleteAutomation(id); // removes the entity with this config id
    server.scenes.remove(id);
  }

  @override
  Future<HaFlowStep> configFlowStep(String flowId) async {
    await _requireAuth();
    await _latency();
    return HaFlowStep.parse(server.flowStep(flowId));
  }

  @override
  Future<HaFlowStep> configFlowSubmit(
    String flowId,
    Map<String, Object?> data,
  ) async {
    await _requireAuth();
    await _latency();
    return HaFlowStep.parse(server.flowSubmit(flowId, data));
  }

  @override
  Future<void> configFlowAbort(String flowId) async {
    await _requireAuth();
    server.flowAbort(flowId);
  }

  @override
  Future<HaConversationReply> processConversation(
    String text, {
    String? language,
    String? conversationId,
  }) async {
    await _requireAuth();
    await _latency();
    return HaConversationReply.parse(
      server.converse(text, language: language, conversationId: conversationId),
    );
  }

  @override
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    await _requireAuth();
    await _latency();
    return server.uploadImage(bytes, filename);
  }

  @override
  Future<Uint8List> fetchImage(String path) async {
    await _requireAuth();
    final served = RegExp(r'^/api/image/serve/([0-9a-f]+)/original$');
    if (served.firstMatch(path)?.group(1) case final id?) {
      final bytes = server.images[id]?.$2;
      if (bytes == null) {
        throw const AppFailure(FailureKind.server, statusCode: 404);
      }
      await _latency();
      return bytes;
    }
    const mediaProxy = '/api/media_player_proxy/';
    if (path.startsWith(mediaProxy)) {
      final id = Uri.parse(path).pathSegments.last;
      final title = server.states
          .where((s) => s['entity_id'] == id)
          .map((s) => (s['attributes']! as Map)['media_title'])
          .firstOrNull;
      if (title is String) {
        await _latency();
        return mockAlbumArt(title);
      }
    }
    const proxy = '/api/camera_proxy/';
    if (path.startsWith(proxy)) {
      final id = Uri.decodeComponent(path.substring(proxy.length));
      final cameras = [
        for (final s in server.states)
          if ((s['entity_id']! as String).startsWith('camera.'))
            s['entity_id']! as String,
      ];
      final index = cameras.indexOf(id);
      if (index >= 0) {
        server.cameraRequests++;
        await _latency();
        return mockCameraFrame(index, server.now());
      }
    }
    // Demo people have no pictures; the UI shows their initials.
    throw const AppFailure(FailureKind.server, debugMessage: 'no image');
  }

  @override
  void close() {}
}

/// [HaAuthClient] for mock mode: "logging in" redirects straight back with
/// a code, so the whole OAuth2 flow can be exercised without a server.
class MockHaAuthClient implements HaAuthClient {
  MockHaAuthClient(this.server);

  final MockHomeAssistantServer server;

  @override
  Uri authorizeUrl({
    required String clientId,
    required Uri redirectUri,
    required String state,
  }) {
    final code =
        'mock-code-${DateTime.now().microsecondsSinceEpoch}-${server._nextAuthCode++}';
    return redirectUri.replace(queryParameters: {'code': code, 'state': state});
  }

  @override
  Future<OAuthTokenResponse> exchangeCode({
    required String code,
    required String clientId,
  }) async {
    if (!code.startsWith('mock-code-') || !server._usedAuthCodes.add(code)) {
      throw const AppFailure(
        FailureKind.authentication,
        statusCode: 400,
        debugMessage: 'invalid_grant',
      );
    }
    final refresh =
        'mock-refresh-${DateTime.now().microsecondsSinceEpoch}-${server._nextAuthCode++}';
    return OAuthTokenResponse(
      accessToken: 'mock-access-${server._nextAuthCode++}',
      expiresIn: server.accessTokenLifetime,
      refreshToken: refresh,
    );
  }

  @override
  Future<OAuthTokenResponse> refresh({
    required String refreshToken,
    required String clientId,
  }) async {
    server.refreshCount++;
    if (!refreshToken.startsWith('mock-refresh-') ||
        server.revokedRefreshTokens.contains(refreshToken)) {
      throw const AppFailure(
        FailureKind.authentication,
        statusCode: 400,
        debugMessage: 'invalid_grant',
      );
    }
    return OAuthTokenResponse(
      accessToken: 'mock-access-${server._nextAuthCode++}',
      expiresIn: server.accessTokenLifetime,
    );
  }

  @override
  Future<void> revoke(String refreshToken) async =>
      server.revokedRefreshTokens.add(refreshToken);
}
