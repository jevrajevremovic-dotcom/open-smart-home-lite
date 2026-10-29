import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/server_address.dart';
import '../../../core/network/tls_trust.dart';
import '../models/ha_calendar.dart';
import '../models/ha_config_flow.dart';
import '../models/ha_history.dart';
import '../models/ha_conversation.dart';
import '../models/ha_models.dart';
import '../transport/transport.dart';
import 'dio_error_mapper.dart';
import '../mappers/ha_device_mapper.dart' show localPicturePath;
import 'home_assistant_api.dart';

typedef AccessTokenReader = Future<String?> Function();

class DioHomeAssistantApi implements HomeAssistantApi {
  DioHomeAssistantApi({
    required this.address,
    required this._readToken,
    TlsTrust trust = TlsTrust.system,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = address.baseUri.toString()
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      // Browsers cannot enforce a send timeout on body-less requests.
      ..sendTimeout = kIsWeb ? null : AppConfig.sendTimeout
      ..responseType = ResponseType.json
      ..followRedirects = false
      // Status handling is done in one place, see mapStatusCode.
      ..validateStatus = (status) =>
          status != null && status >= 200 && status < 300;

    final adapter = dio == null
        ? createPlatformHttpAdapter(
            trust,
            onRejected: (cert) => _lastRejectedCertificate = cert,
          )
        : null;
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  @override
  final ServerAddress address;

  final AccessTokenReader _readToken;
  final Dio _dio;
  CertificateInfo? _lastRejectedCertificate;

  static final _log = AppLogger('HomeAssistantApi');
  static final RegExp _slug = RegExp(r'^[a-z0-9_]+$');

  @override
  Future<ServerProbeResult> probe() async {
    try {
      await _dio.get<Object?>('/api/');
      // 2xx without a token should not happen on Home Assistant.
      return ServerProbeResult.unexpectedResponse;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) {
        return e.response?.statusCode == 401
            ? ServerProbeResult.reachableRequiresAuth
            : ServerProbeResult.unexpectedResponse;
      }
      throw _map(e);
    }
  }

  @override
  Future<void> verifyAccessToken() async {
    final body = await _authorized('GET', '/api/');
    // Documented response: {"message": "API running."}
    if (body is! Map || body['message'] is! String) {
      throw const AppFailure(
        FailureKind.parsing,
        debugMessage: 'unexpected /api/ body',
      );
    }
  }

  @override
  Future<HaConfig> fetchConfig() async =>
      HaConfig.fromJson(await _authorized('GET', '/api/config'));

  @override
  Future<List<HaEntityState>> fetchStates() async => parseStateList(
    await _authorized('GET', '/api/states'),
    onSkipped: (e) => _log.warning('Skipped malformed state', e),
  );

  @override
  Future<List<HaEntityState>> callService(
    String domain,
    String service, {
    Map<String, Object?> data = const {},
  }) async {
    if (!_slug.hasMatch(domain) || !_slug.hasMatch(service)) {
      throw AppFailure(
        FailureKind.validation,
        debugMessage: 'invalid service name $domain.$service',
      );
    }
    final body = await _authorized(
      'POST',
      '/api/services/$domain/$service',
      data: data,
    );
    return body is List ? parseStateList(body) : const [];
  }

  @override
  Future<Object?> callServiceForResponse(
    String domain,
    String service, {
    Map<String, Object?> data = const {},
  }) async {
    if (!_slug.hasMatch(domain) || !_slug.hasMatch(service)) {
      throw AppFailure(
        FailureKind.validation,
        debugMessage: 'invalid service name $domain.$service',
      );
    }
    final body = await _authorized(
      'POST',
      '/api/services/$domain/$service?return_response',
      data: data,
    );
    return body is Map ? body['service_response'] : null;
  }

  @override
  Future<Map<String, Set<String>>> fetchServices() async =>
      parseServiceList(await _authorized('GET', '/api/services'));

  static final _flowId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  String _flowPath(String flowId) {
    if (!_flowId.hasMatch(flowId)) {
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'invalid flow id',
      );
    }
    return '/api/config/config_entries/flow/$flowId';
  }

  @override
  Future<HaFlowStep> configFlowStep(String flowId) async =>
      HaFlowStep.parse(await _authorized('GET', _flowPath(flowId)));

  @override
  Future<HaFlowStep> configFlowSubmit(
    String flowId,
    Map<String, Object?> data,
  ) async => HaFlowStep.parse(
    await _authorized('POST', _flowPath(flowId), data: data),
  );

  @override
  Future<void> configFlowAbort(String flowId) async {
    await _authorized('DELETE', _flowPath(flowId));
  }

  static final _entityId = RegExp(r'^[a-z_]+\.[a-z0-9_]+$');

  String _periodPath(
    String base,
    String? entityId,
    DateTime start,
    DateTime end, {
    bool history = false,
  }) {
    if (entityId != null && !_entityId.hasMatch(entityId)) {
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'invalid entity id',
      );
    }
    final query = Uri(
      queryParameters: {
        if (entityId != null)
          if (history) 'filter_entity_id': entityId else 'entity': entityId,
        'end_time': end.toUtc().toIso8601String(),
      },
    ).query;
    final flags = history ? '&minimal_response&no_attributes' : '';
    // An ISO timestamp is path-safe (digits, '-', ':', '.', 'Z').
    return '$base/${start.toUtc().toIso8601String()}'
        '?$query$flags';
  }

  @override
  Future<List<HaHistoryPoint>> fetchHistory(
    String entityId,
    DateTime start,
    DateTime end,
  ) async => HaHistoryPoint.parse(
    await _authorized(
      'GET',
      _periodPath('/api/history/period', entityId, start, end, history: true),
    ),
  );

  @override
  Future<List<HaLogbookEntry>> fetchLogbook(
    String? entityId,
    DateTime start,
    DateTime end,
  ) async => HaLogbookEntry.parse(
    await _authorized('GET', _periodPath('/api/logbook', entityId, start, end)),
  );

  static final _automationId = RegExp(r'^[A-Za-z0-9_]{1,64}$');

  String _automationPath(String id) {
    if (!_automationId.hasMatch(id)) {
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'invalid automation id',
      );
    }
    return '/api/config/automation/config/$id';
  }

  @override
  Future<Map<String, Object?>> registerMobileApp(
    Map<String, Object?> body,
  ) async {
    final response = await _authorized(
      'POST',
      '/api/mobile_app/registrations',
      data: body,
    );
    if (response is! Map<String, Object?> ||
        response['webhook_id'] is! String) {
      throw const AppFailure(
        FailureKind.parsing,
        debugMessage: 'registration answer without webhook_id',
      );
    }
    return response;
  }

  @override
  Future<void> saveAutomation(String id, Map<String, Object?> config) async {
    await _authorized('POST', _automationPath(id), data: config);
  }

  @override
  Future<void> deleteAutomation(String id) async {
    await _authorized('DELETE', _automationPath(id));
  }

  @override
  Future<Map<String, Object?>> fetchAutomation(String id) async {
    final body = await _authorized('GET', _automationPath(id));
    return body is Map<String, Object?> ? body : const {};
  }

  @override
  Future<void> saveScript(String id, Map<String, Object?> config) async {
    _automationPath(id); // same id rules
    await _authorized('POST', '/api/config/script/config/$id', data: config);
  }

  @override
  Future<void> saveScene(String id, Map<String, Object?> config) async {
    _automationPath(id); // same id rules
    await _authorized('POST', '/api/config/scene/config/$id', data: config);
  }

  @override
  Future<Map<String, Object?>> fetchScene(String id) async {
    _automationPath(id); // same id rules
    final body = await _authorized('GET', '/api/config/scene/config/$id');
    return body is Map<String, Object?> ? body : const {};
  }

  @override
  Future<void> deleteScene(String id) async {
    _automationPath(id);
    await _authorized('DELETE', '/api/config/scene/config/$id');
  }

  static final _calendarId = RegExp(r'^calendar\.[a-z0-9_]+$');

  @override
  Future<List<HaCalendar>> fetchCalendars() async =>
      HaCalendar.parseList(await _authorized('GET', '/api/calendars'));

  @override
  Future<List<HaCalendarEvent>> fetchCalendarEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async {
    if (!_calendarId.hasMatch(calendarId)) {
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'invalid calendar entity id',
      );
    }
    final query = Uri(
      queryParameters: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      },
    ).query;
    return HaCalendarEvent.parseList(
      await _authorized('GET', '/api/calendars/$calendarId?$query'),
      calendarId,
    );
  }

  @override
  Future<HaConversationReply> processConversation(
    String text, {
    String? language,
    String? conversationId,
  }) async => HaConversationReply.parse(
    await _authorized(
      'POST',
      '/api/conversation/process',
      data: {
        'text': text,
        'language': ?language,
        'conversation_id': ?conversationId,
      },
    ),
  );

  /// Pictures larger than this are refused (a profile picture is ~50 kB).
  static const _maxImageBytes = 5 * 1024 * 1024;

  @override
  Future<Uint8List> fetchImage(String path) async {
    if (localPicturePath(path) == null) {
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'refusing non-local image path',
      );
    }
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'no token stored',
      );
    }
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      final bytes = response.data ?? const <int>[];
      if (bytes.isEmpty || bytes.length > _maxImageBytes) {
        throw const AppFailure(
          FailureKind.server,
          debugMessage: 'image empty or too large',
        );
      }
      return Uint8List.fromList(bytes);
    } on DioException catch (e) {
      final failure = _map(e);
      _log.warning('GET image failed', failure);
      throw failure;
    }
  }

  @override
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final type = switch (filename.split('.').last.toLowerCase()) {
      'png' => 'png',
      'jpg' || 'jpeg' => 'jpeg',
      'gif' => 'gif',
      _ => throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'only png, jpeg and gif can be uploaded',
      ),
    };
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType('image', type),
      ),
    });
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'no token stored',
      );
    }
    try {
      final response = await _dio.post<Object?>(
        '/api/image/upload',
        data: form,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final id = switch (response.data) {
        {'id': final String id} => id,
        _ => null,
      };
      if (id == null) {
        throw const AppFailure(
          FailureKind.server,
          debugMessage: 'upload answered without an id',
        );
      }
      return id;
    } on DioException catch (e) {
      final failure = _map(e);
      _log.warning('POST image upload failed', failure);
      throw failure;
    }
  }

  Future<Object?> _authorized(
    String method,
    String path, {
    Object? data,
  }) async {
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'no token stored',
      );
    }
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
          contentType: data == null ? null : Headers.jsonContentType,
        ),
      );
      _log.debug('$method $path → ${response.statusCode}');
      return response.data;
    } on DioException catch (e) {
      final failure = _map(e);
      _log.warning('$method $path failed', failure);
      throw failure;
    }
  }

  AppFailure _map(DioException e) {
    final cert = _lastRejectedCertificate;
    _lastRejectedCertificate = null;
    return mapDioException(e, rejectedCertificate: cert);
  }

  @override
  void close() => _dio.close(force: true);
}
