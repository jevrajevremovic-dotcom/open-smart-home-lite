import 'dart:typed_data';

import '../../../core/network/server_address.dart';
import '../models/ha_calendar.dart';
import '../models/ha_config_flow.dart';
import '../models/ha_history.dart';
import '../models/ha_conversation.dart';
import '../models/ha_models.dart';

/// Outcome of probing a server before the user has a token.
enum ServerProbeResult {
  /// `GET /api/` answered `401` — a Home Assistant API that requires auth.
  reachableRequiresAuth,

  /// Something answered, but not like the Home Assistant REST API.
  unexpectedResponse,
}

/// Documented Home Assistant REST API (https://developers.home-assistant.io/docs/api/rest/).
///
/// Only endpoints from the official documentation are used here.
abstract interface class HomeAssistantApi {
  ServerAddress get address;

  /// Unauthenticated reachability check. Throws `AppFailure` for network,
  /// timeout and TLS problems.
  Future<ServerProbeResult> probe();

  /// `GET /api/` with the token. Completes normally only for a valid token;
  /// throws `AppFailure` (authentication/authorization/…) otherwise.
  Future<void> verifyAccessToken();

  /// `GET /api/config`.
  Future<HaConfig> fetchConfig();

  /// `GET /api/states`.
  Future<List<HaEntityState>> fetchStates();

  /// `POST /api/services/<domain>/<service>`. Returns states changed while
  /// the service executed.
  Future<List<HaEntityState>> callService(
    String domain,
    String service, {
    Map<String, Object?> data = const {},
  });

  /// `POST /api/services/<domain>/<service>?return_response` – for services
  /// that return data (e.g. `weather.get_forecasts`). Returns the
  /// `service_response` object.
  Future<Object?> callServiceForResponse(
    String domain,
    String service, {
    Map<String, Object?> data = const {},
  });

  /// `GET /api/services` – available services per domain
  /// (`{"zha": {"permit", …}, "mqtt": {"publish", …}}`).
  Future<Map<String, Set<String>>> fetchServices();

  /// `GET /api/history/period/<start>` for one entity (documented),
  /// minimal response without attributes.
  Future<List<HaHistoryPoint>> fetchHistory(
    String entityId,
    DateTime start,
    DateTime end,
  );

  /// `GET /api/logbook/<start>` for one entity, or the whole home when
  /// [entityId] is null (documented).
  Future<List<HaLogbookEntry>> fetchLogbook(
    String? entityId,
    DateTime start,
    DateTime end,
  );

  /// `GET /api/calendars` – calendar entities.
  Future<List<HaCalendar>> fetchCalendars();

  /// `GET /api/calendars/<entity_id>?start=&end=` – events overlapping the
  /// range (expanded recurring events included).
  Future<List<HaCalendarEvent>> fetchCalendarEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  );

  /// `POST /api/conversation/process` – sends a sentence to Assist, which
  /// may control devices with the user's permissions and answers in text.
  Future<HaConversationReply> processConversation(
    String text, {
    String? language,
    String? conversationId,
  });

  /// Config flows (adding an integration / discovered device), REST API of
  /// the HA frontend (`/api/config/config_entries/flow/<flow_id>`; not in
  /// the developer docs, admin only).
  Future<HaFlowStep> configFlowStep(String flowId);
  Future<HaFlowStep> configFlowSubmit(String flowId, Map<String, Object?> data);
  Future<void> configFlowAbort(String flowId);

  /// `POST /api/mobile_app/registrations` (documented native app API):
  /// registers this app; the answer holds `webhook_id`, a secret.
  Future<Map<String, Object?>> registerMobileApp(Map<String, Object?> body);

  /// Creates or replaces a UI automation (frontend REST API
  /// `/api/config/automation/config/<id>`; admin only).
  Future<void> saveAutomation(String id, Map<String, Object?> config);
  Future<void> deleteAutomation(String id);
  Future<Map<String, Object?>> fetchAutomation(String id);

  /// Creates or replaces a UI script (`/api/config/script/config/<id>`,
  /// frontend API, admin only); its entity is `script.<id>`.
  Future<void> saveScript(String id, Map<String, Object?> config);

  /// Creates / deletes a UI scene (`/api/config/scene/config/<id>`).
  Future<void> saveScene(String id, Map<String, Object?> config);

  /// A UI scene's config (`GET /api/config/scene/config/<id>`): its
  /// `entities` with the states the scene sets.
  Future<Map<String, Object?>> fetchScene(String id);
  Future<void> deleteScene(String id);

  /// `GET` of an image served by Home Assistant itself (e.g. a person's
  /// `entity_picture`, `/api/image/serve/...`). Only server-relative
  /// `/api/` paths are accepted, so the token never goes to another host.
  Future<Uint8List> fetchImage(String path);

  /// `POST /api/image/upload` (Home Assistant's `image_upload`, multipart
  /// field `file`; PNG, JPEG or GIF up to 10 MB). Returns the new image's
  /// id; the file is served unchanged at `/api/image/serve/<id>/original`.
  Future<String> uploadImage(Uint8List bytes, String filename);

  void close();
}

/// Parses the `GET /api/services` response.
Map<String, Set<String>> parseServiceList(Object? json) => {
  if (json is List)
    for (final d in json)
      if (d is Map && d['domain'] is String)
        d['domain']! as String: {
          if (d['services'] case final Map<Object?, Object?> services)
            ...services.keys.whereType<String>(),
        },
};
