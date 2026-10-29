import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/server_address.dart';
import '../api/home_assistant_api.dart';
import '../auth/ha_auth_client.dart';
import '../models/ha_calendar.dart';
import '../models/ha_config_flow.dart';
import '../models/ha_history.dart';
import '../models/ha_conversation.dart';
import '../models/ha_models.dart';
import '../websocket/ha_socket.dart';
import 'mock_camera_image.dart';
import 'mock_fixtures.dart';

part 'mock_socket.dart';
part 'mock_api.dart';

/// Token that the mock server rejects, to exercise the auth-failure path.
const String mockInvalidToken = 'invalid';

/// An in-memory Home Assistant: entity states, a minimal service
/// implementation, and the WebSocket protocol. Both the mock REST API and
/// mock sockets talk to the same instance, so a service call made over REST
/// produces `state_changed` events on the WebSocket, as on a real server.
class MockHomeAssistantServer {
  /// [states] and [registries] replace the built-in demo home (used by
  /// performance tests with thousands of entities).
  MockHomeAssistantServer({
    DateTime Function()? clock,
    List<Map<String, Object?>>? states,
    ({
      List<Map<String, Object?>> areas,
      List<Map<String, Object?>> devices,
      List<Map<String, Object?>> entities,
    })?
    registries,
  }) : _clock = clock ?? DateTime.now,
       registries = registries ?? buildMockRegistries() {
    for (final s in states ?? buildMockStates(_clock())) {
      _states[s['entity_id']! as String] = s;
    }
    // The demo home's movie night, as a UI scene with its lights' colours.
    if (states == null) scenes.addAll(mockSceneConfigs);
  }

  static const String version = '2026.10.0-mock';

  final DateTime Function() _clock;
  final Map<String, Map<String, Object?>> _states = {};

  DateTime now() => _clock();

  /// Demo calendars (`GET /api/calendars`).
  List<Map<String, Object?>> calendars = [
    {'entity_id': 'calendar.porodica', 'name': 'Porodica'},
    {'entity_id': 'calendar.posao', 'name': 'Posao'},
  ];

  /// Demo events around "now", in the documented response format.
  List<Map<String, Object?>> calendarEvents(String calendarId) {
    final now = _clock();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
    Map<String, Object?> timed(String summary, int offset, int h1, int h2) => {
      'summary': summary,
      'start': {
        'dateTime': day(offset).add(Duration(hours: h1)).toIso8601String(),
      },
      'end': {
        'dateTime': day(offset).add(Duration(hours: h2)).toIso8601String(),
      },
    };
    Map<String, Object?> allDay(String summary, int offset, [int days = 1]) => {
      'summary': summary,
      'start': {'date': _date(day(offset))},
      'end': {'date': _date(day(offset + days))},
    };
    return switch (calendarId) {
      'calendar.porodica' => [
        timed('Vrtić', 0, 8, 16),
        allDay('Rođendan – Ana', 1),
        timed('Trening', 2, 18, 19),
        timed('Servis kotla', 3, 10, 11),
        allDay('Vikend kod bake', 9, 2),
        timed('Roditeljski sastanak', 16, 17, 18),
        timed('Zubar', 24, 9, 10),
        for (var w = 0; w < 6; w++) timed('Bazen', 7 * w + 5, 17, 18),
      ],
      'calendar.posao' => [
        timed('Sastanak tima', 0, 9, 11),
        timed('Prezentacija', 1, 13, 14),
        timed('Planiranje', 7, 10, 12),
        allDay('Konferencija', 14, 2),
      ],
      _ => const [],
    };
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Synthetic history: numeric sensors follow a daily curve around their
  /// current value; everything else toggles every few hours.
  List<Map<String, Object?>> history(
    String entityId,
    DateTime start,
    DateTime end,
  ) {
    final current = _states[entityId];
    if (current == null) return const [];
    final state = current['state']! as String;
    final value = double.tryParse(state);
    final out = <Map<String, Object?>>[];
    if (value != null) {
      for (
        var t = start;
        t.isBefore(end);
        t = t.add(const Duration(minutes: 30))
      ) {
        final h = t.hour + t.minute / 60;
        final v = value + 2 * math.sin((h - 9) / 24 * 2 * math.pi);
        out.add({
          'state': v.toStringAsFixed(1),
          'last_changed': t.toUtc().toIso8601String(),
        });
      }
      return out;
    }
    const pair = {
      'on': 'off',
      'off': 'on',
      'locked': 'unlocked',
      'unlocked': 'locked',
    };
    final other = pair[state];
    if (other == null) {
      return [
        {'state': state, 'last_changed': start.toUtc().toIso8601String()},
      ];
    }
    var s = other;
    for (var t = start; t.isBefore(end); t = t.add(const Duration(hours: 3))) {
      out.add({'state': s, 'last_changed': t.toUtc().toIso8601String()});
      s = pair[s]!;
    }
    return out;
  }

  /// Entities with on/off-like history, for the whole-home logbook.
  List<String> logbookEntityIds() => [
    for (final MapEntry(:key, :value) in _states.entries)
      if (const {
            'light',
            'switch',
            'binary_sensor',
            'lock',
            'cover',
            'fan',
          }.contains(key.split('.').first) &&
          const {'on', 'off', 'locked', 'unlocked'}.contains(value['state']))
        key,
  ];

  String? friendlyName(String entityId) => switch (_states[entityId]) {
    {'attributes': {'friendly_name': final String name}} => name,
    _ => null,
  };

  /// The last `tts.speak` call (its data), for tests.
  Map<String, Object?>? lastTtsSpeak;

  /// Keys sent to TV remotes (`remote.send_command`), oldest first.
  final List<String> remoteCommands = [];

  /// Persistent notifications (`persistent_notification/subscribe`).
  final Map<String, Map<String, Object?>> notifications = {
    'config_entry_discovery': {
      'notification_id': 'config_entry_discovery',
      'title': 'Pronađen novi uređaj',
      'message': 'Pronađeni su novi uređaji na mreži. [Proverite](/config/integrations).',
      'created_at': DateTime.now()
          .subtract(const Duration(minutes: 12))
          .toUtc()
          .toIso8601String(),
    },
    'washer_done': {
      'notification_id': 'washer_done',
      'title': 'Veš mašina',
      'message': 'Pranje je završeno. **Izvadite veš.**',
      'created_at': DateTime.now()
          .subtract(const Duration(minutes: 2))
          .toUtc()
          .toIso8601String(),
    },
  };

  void _dismissNotifications(List<String> ids) {
    final removed = <String, Map<String, Object?>>{};
    for (final id in ids) {
      final n = notifications.remove(id);
      if (n != null) removed[id] = n;
    }
    if (removed.isEmpty) return;
    for (final socket in _sockets) {
      socket._notifyNotifications('removed', removed);
    }
  }

  /// `image_upload` storage: id → (metadata, original bytes).
  final Map<String, (Map<String, Object?>, Uint8List)> images = {};
  int _imageSeq = 0;

  /// Whether the signed-in demo user is an administrator (image/delete).
  bool imageAdmin = true;

  /// Whether Assist has a wake word engine (openWakeWord). Without one,
  /// `assist_pipeline/run` from the wake word stage fails like Home
  /// Assistant does (`wake-engine-missing`).
  bool wakeWordEngine = true;

  /// Language of the demo Assist pipeline.
  String assistLanguage = 'en';

  /// What the demo pipeline "hears" after the wake word (default: turn off
  /// the lights in [assistLanguage]).
  String? assistHeard;

  String uploadImage(Uint8List bytes, String filename) {
    final id = (++_imageSeq).toRadixString(16).padLeft(32, '0');
    final item = <String, Object?>{
      'id': id,
      'filesize': bytes.length,
      'content_type': 'image/png',
      'name': filename,
      'uploaded_at': _clock().toUtc().toIso8601String(),
    };
    images[id] = (item, Uint8List.fromList(bytes));
    for (final socket in _sockets) {
      socket._notifyImages('added', id, item);
    }
    return id;
  }

  bool deleteImage(String id) {
    final removed = images.remove(id);
    if (removed == null) return false;
    for (final socket in _sockets) {
      socket._notifyImages('removed', id, removed.$1);
    }
    return true;
  }

  /// Items of the demo to-do lists (`todo` integration), by entity id.
  final Map<String, List<Map<String, Object?>>> todoItems = {
    'todo.shopping_list': [
      {'uid': 's1', 'summary': 'Mleko', 'status': 'needs_action'},
      {'uid': 's2', 'summary': 'Hleb', 'status': 'needs_action'},
      {'uid': 's3', 'summary': 'Kafa', 'status': 'needs_action'},
      {'uid': 's4', 'summary': 'Jaja', 'status': 'completed'},
    ],
    'todo.chores': [
      {
        'uid': 'c1',
        'summary': 'Zameniti filter klime',
        'status': 'needs_action',
        'due': '2026-11-01',
      },
      {
        'uid': 'c2',
        'summary': 'Izneti smeće',
        'status': 'needs_action',
        // Due today, whenever the demo runs (a morning-screen reminder).
        'due': DateTime.now().toIso8601String().substring(0, 10),
      },
    ],
  };
  int _todoUid = 100;

  void _todoChanged(String entityId) {
    final items = todoItems[entityId]!;
    final open = items.where((i) => i['status'] == 'needs_action').length;
    final current = _states[entityId];
    if (current != null) {
      _setState(
        entityId,
        '$open',
        Map.of(current['attributes']! as Map<String, Object?>),
      );
    }
    for (final socket in _sockets) {
      socket._notifyTodo(entityId, items);
    }
  }

  /// `todo.*` services, as Home Assistant's `todo` integration has them.
  void _todoService(String service, Map<String, Object?> data) {
    final id = data['entity_id'];
    final items = id is String ? todoItems[id] : null;
    if (items == null) {
      throw const AppFailure(FailureKind.validation, statusCode: 400);
    }
    Map<String, Object?>? find(Object? key) =>
        items.where((i) => i['uid'] == key || i['summary'] == key).firstOrNull;
    switch (service) {
      case 'add_item':
        final text = (data['item'] as String?)?.trim() ?? '';
        if (text.isEmpty) {
          throw const AppFailure(FailureKind.validation, statusCode: 400);
        }
        items.add({
          'uid': 'n${_todoUid++}',
          'summary': text,
          'status': 'needs_action',
        });
      case 'update_item':
        final item = find(data['item']);
        if (item == null) {
          throw const AppFailure(FailureKind.validation, statusCode: 400);
        }
        if (data['rename'] case final String name) item['summary'] = name;
        if (data['status'] case final String status) item['status'] = status;
      case 'remove_item':
        final keys = switch (data['item']) {
          final List<Object?> l => l,
          final Object? one => [one],
        };
        items.removeWhere(
          (i) => keys.contains(i['uid']) || keys.contains(i['summary']),
        );
      case 'remove_completed_items':
        items.removeWhere((i) => i['status'] == 'completed');
    }
    _todoChanged(id! as String);
  }

  /// Tags (`tag` integration), by tag id.
  final Map<String, Map<String, Object?>> tags = {};
  final List<String> scannedTags = [];

  /// Whether the demo user may change configuration (tag/create, …).
  bool configAdmin = true;

  /// `frontend/*_user_data` and `frontend/*_system_data` stores.
  final Map<String, Object?> userData = {};
  final Map<String, Object?> systemData = {};

  /// Like `tag.async_scan_tag`: an unknown tag is added, "last scanned"
  /// moves, and `tag_scanned` fires.
  void scanTag(String id) {
    scannedTags.add(id);
    final tag = tags.putIfAbsent(id, () => {'id': id});
    tag['last_scanned'] = _clock().toUtc().toIso8601String();
    firedEvents.add({
      'event_type': 'tag_scanned',
      'event_data': {'tag_id': id},
    });
  }

  /// Mobile App sensors: webhook → unique id → entity id.
  final Map<String, Map<String, String>> mobileAppSensorIds = {};

  /// `register_sensor` (201) and `update_sensor_states` (200), as in
  /// homeassistant/components/mobile_app/webhook.py: the entity is named
  /// `"<device name> <sensor name>"`; updates of unknown sensors are refused.
  int mobileAppSensors(String webhook, String type, Object? data) {
    final device = mobileApps[webhook]!['device_name']! as String;
    final ids = mobileAppSensorIds.putIfAbsent(webhook, () => {});
    Map<String, Object?> attrs(Map<Object?, Object?> s, String? name) => {
      ...?(s['attributes'] as Map?)?.cast<String, Object?>(),
      'friendly_name': ?name,
      'device_class': ?s['device_class'],
      'unit_of_measurement': ?s['unit_of_measurement'],
      'icon': ?s['icon'],
    };
    String state(Object? v) => switch (v) {
      true => 'on',
      false => 'off',
      null => 'unknown',
      final other => '$other',
    };
    if (type == 'register_sensor' && data is Map) {
      final uid = data['unique_id']! as String;
      final domain = data['type']! as String;
      final name = '$device ${data['name']}';
      final entityId = ids[uid] ??= '$domain.${_slug(name)}';
      _setState(entityId, state(data['state']), attrs(data, name));
      return 201;
    }
    if (type == 'update_sensor_states' && data is List) {
      for (final s in data.whereType<Map<Object?, Object?>>()) {
        final entityId = ids[s['unique_id']];
        if (entityId == null) continue;
        final current = _states[entityId];
        final keep = current?['attributes'] as Map<String, Object?>? ?? {};
        _setState(entityId, state(s['state']), {
          ...keep,
          ...attrs(s, keep['friendly_name'] as String?),
        });
      }
      return 200;
    }
    return 400;
  }

  /// `mobile_app` registrations by webhook id (native app API).
  final Map<String, Map<String, Object?>> mobileApps = {};

  /// Events the app fired through its webhook (`fire_event`).
  final List<Map<String, Object?>> firedEvents = [];

  /// Notifications confirmed by the app (`hass_confirm_id`s).
  final List<String> confirmedPushes = [];
  int _nextPush = 1;

  Map<String, Object?> registerMobileApp(Map<String, Object?> body) {
    final webhookId = 'mock-webhook-${mobileApps.length + 1}';
    mobileApps[webhookId] = body;
    return {'webhook_id': webhookId, 'cloudhook_url': null};
  }

  /// What `notify.mobile_app_<name>` does: delivers to the app's channel.
  void sendPush(
    String webhookId, {
    required String message,
    String? title,
    Map<String, Object?>? data,
  }) {
    for (final socket in _sockets) {
      socket._push(webhookId, {
        'message': message,
        'title': ?title,
        'data': ?data,
        'hass_confirm_id': 'push-${_nextPush++}',
      });
    }
  }

  /// UI automations saved through the app (id → config).
  final Map<String, Map<String, Object?>> automations = {};

  void saveAutomation(String id, Map<String, Object?> config) {
    if (automations.containsKey(id)) deleteAutomation(id);
    automations[id] = config;
    final alias = config['alias'] as String? ?? id;
    final slug = _slug(alias);
    final entityId = 'automation.${slug.isEmpty ? id : slug}';
    _setState(entityId, 'on', {
      'friendly_name': alias,
      'id': id,
      'last_triggered': null,
    });
  }

  /// Like HA's `slugify`: transliterate, lower-case, `_` between words.
  static String _slug(String text) {
    const map = {'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'dj'};
    final ascii = text.toLowerCase().split('').map((c) => map[c] ?? c).join();
    return ascii
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// UI scripts saved through the app (id → config), entity `script.<id>`.
  final Map<String, Map<String, Object?>> scripts = {};
  final Map<String, Timer> _scriptRuns = {};

  void saveScript(String id, Map<String, Object?> config) {
    scripts[id] = config;
    _setState('script.$id', 'off', {
      'friendly_name': config['alias'] as String? ?? id,
    });
  }

  /// Runs a timer script made by the app: `delay` of `minutes`, then
  /// `service` on its target (mode restart: a new run replaces the old).
  void _runScript(String entityId, Map<String, Object?> variables) {
    final config = scripts[entityId.substring('script.'.length)];
    if (config == null) return;
    final minutes = variables['minutes'];
    final service = variables['service'];
    final target = _firstTarget(config['sequence']);
    if (minutes is! num || service is! String || target is! String) return;
    _scriptRuns.remove(entityId)?.cancel();
    _setState(entityId, 'on', _attrs(entityId));
    _scriptRuns[entityId] = Timer(
      Duration(seconds: (minutes * 60).round()),
      () {
        _scriptRuns.remove(entityId);
        callService(target.split('.').first, service, {'entity_id': target});
        _setState(entityId, 'off', _attrs(entityId));
      },
    );
  }

  /// The first `target.entity_id` anywhere in a script sequence.
  static String? _firstTarget(Object? node) {
    if (node is Map) {
      final target = node['target'];
      if (target is Map && target['entity_id'] is String) {
        return target['entity_id']! as String;
      }
      for (final v in node.values) {
        final found = _firstTarget(v);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final v in node) {
        final found = _firstTarget(v);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _stopScript(String entityId) {
    _scriptRuns.remove(entityId)?.cancel();
    if (_states.containsKey(entityId)) {
      _setState(entityId, 'off', _attrs(entityId));
    }
  }

  Map<String, Object?> _attrs(String id) => Map<String, Object?>.of(
    (_states[id]?['attributes'] as Map<String, Object?>?) ?? const {},
  );

  /// UI scenes saved through the app (id → config).
  final Map<String, Map<String, Object?>> scenes = {};

  void saveScene(String id, Map<String, Object?> config) {
    scenes[id] = config;
    final name = config['name'] as String? ?? id;
    final slug = _slug(name);
    _setState('scene.${slug.isEmpty ? id : slug}', 'unknown', {
      'friendly_name': name,
      'id': id,
      'entity_id': [...(config['entities'] as Map? ?? const {}).keys],
    });
  }

  /// Applies a saved scene (lights, switches and covers).
  void _applyScene(String sceneEntityId) {
    final id = (_states[sceneEntityId]?['attributes'] as Map?)?['id'];
    final config = scenes[id];
    final entities = config?['entities'];
    if (entities is! Map) return;
    for (final MapEntry(:key, :value) in entities.entries) {
      final current = _states[key];
      if (current == null || value is! Map) continue;
      final attrs = {
        ...current['attributes']! as Map<String, Object?>,
        for (final e in value.entries)
          if (e.key != 'state') '${e.key}': e.value,
      };
      _setState(key as String, value['state'] as String? ?? 'on', attrs);
    }
  }

  void deleteAutomation(String id) {
    automations.remove(id);
    final entityId = _states.entries
        .where((e) => (e.value['attributes'] as Map?)?['id'] == id)
        .map((e) => e.key)
        .firstOrNull;
    if (entityId == null) return;
    final old = _states.remove(entityId);
    final event = {
      'event_type': 'state_changed',
      'data': {'entity_id': entityId, 'old_state': old, 'new_state': null},
      'origin': 'LOCAL',
      'time_fired': _clock().toUtc().toIso8601String(),
    };
    for (final socket in _sockets) {
      socket._dispatchEvent(event);
    }
  }

  /// `GET /api/services` payload (only the parts the app looks at).
  List<Map<String, Object?>> get serviceList => [
    for (final (domain, services) in [
      ('light', ['turn_on', 'turn_off', 'toggle']),
      ('switch', ['turn_on', 'turn_off', 'toggle']),
      ('climate', ['set_temperature', 'set_hvac_mode', 'set_preset_mode']),
      if (zhaAvailable) ('zha', ['permit', 'remove']),
      ('mqtt', ['publish']),
    ])
      {
        'domain': domain,
        'services': {for (final s in services) s: <String, Object?>{}},
      },
  ];

  /// Whether the demo hub runs ZHA (tests switch it off).
  bool zhaAvailable = true;

  /// Last `mqtt.publish` call (topic, payload), for tests.
  (String, String)? lastMqttPublish;

  /// Remaining permit-join time as last requested (seconds; 0 = closed).
  int permitJoinSeconds = 0;
  final List<Timer> _pairingTimers = [];

  /// Devices that "join" while pairing is open, one after another.
  static const _joiningDevices = [
    (
      deviceId: 'd_new_door',
      name: 'Aqara senzor vrata',
      manufacturer: 'LUMI',
      model: 'MCCGQ11LM',
      ieee: '00:15:8d:00:0a:bc:de:01',
      entityId: 'binary_sensor.lumi_mccgq11lm_opening',
      state: 'off',
      attributes: {
        'friendly_name': 'Aqara senzor vrata',
        'device_class': 'door',
      },
    ),
    (
      deviceId: 'd_new_bulb',
      name: 'IKEA sijalica',
      manufacturer: 'IKEA of Sweden',
      model: 'TRADFRI bulb E27 WW 806lm',
      ieee: '00:0d:6f:ff:fe:12:34:56',
      entityId: 'light.ikea_tradfri_bulb',
      state: 'on',
      attributes: {
        'friendly_name': 'IKEA sijalica',
        'supported_color_modes': ['brightness'],
        'color_mode': 'brightness',
        'brightness': 200,
        'supported_features': 32,
      },
    ),
  ];

  void _permitJoin(int seconds) {
    permitJoinSeconds = seconds;
    for (final t in _pairingTimers) {
      t.cancel();
    }
    _pairingTimers.clear();
    if (seconds <= 0) return;
    for (final (i, d) in _joiningDevices.indexed) {
      if (_states.containsKey(d.entityId)) continue;
      _pairingTimers.add(Timer(Duration(seconds: 5 + i * 6), () => _join(d)));
    }
  }

  void _join(
    ({
      String deviceId,
      String name,
      String manufacturer,
      String model,
      String ieee,
      String entityId,
      String state,
      Map<String, Object?> attributes,
    })
    d,
  ) {
    if (permitJoinSeconds <= 0 || _states.containsKey(d.entityId)) return;
    registries.devices.add({
      'id': d.deviceId,
      'name': d.name,
      'name_by_user': null,
      'manufacturer': d.manufacturer,
      'model': d.model,
      'area_id': null,
      'identifiers': [
        ['zha', d.ieee],
      ],
      'connections': [
        ['zigbee', d.ieee],
      ],
      'via_device_id': null,
      'disabled_by': null,
    });
    registries.entities.add({
      'entity_id': d.entityId,
      'platform': 'zha',
      'device_id': d.deviceId,
      'area_id': null,
      'entity_category': null,
      'hidden_by': null,
      'disabled_by': null,
    });
    fireEvent('device_registry_updated', {
      'action': 'create',
      'device_id': d.deviceId,
    });
    fireEvent('entity_registry_updated', {
      'action': 'create',
      'entity_id': d.entityId,
    });
    _setState(d.entityId, d.state, Map.of(d.attributes));
  }

  /// `config/device_registry/update` (frontend API) for name and area.
  Map<String, Object?>? updateDevice(
    String deviceId, {
    Object? nameByUser,
    Object? areaId,
    bool setName = false,
    bool setArea = false,
  }) {
    final device = registries.devices
        .where((d) => d['id'] == deviceId)
        .firstOrNull;
    if (device == null) return null;
    if (setName) device['name_by_user'] = nameByUser;
    if (setArea) device['area_id'] = areaId;
    // Entities named after their device follow the new name.
    if (setName && nameByUser is String) {
      for (final e in registries.entities) {
        if (e['device_id'] != deviceId) continue;
        final id = e['entity_id']! as String;
        final s = _states[id];
        if (s == null) continue;
        _setState(id, s['state']! as String, {
          ...s['attributes']! as Map<String, Object?>,
          'friendly_name': nameByUser,
        });
      }
    }
    fireEvent('device_registry_updated', {
      'action': 'update',
      'device_id': deviceId,
    });
    return device;
  }

  // --- Config flows: devices HA "discovered" on the network ---

  /// flow_id → (handler, name, current step id).
  final Map<String, ({String handler, String name, String step})> _flows = {
    'flowshelly01': (
      handler: 'shelly',
      name: 'shellyplug-s-c8c9a3',
      step: 'confirm_discovery',
    ),
    'flowesphome01': (
      handler: 'esphome',
      name: 'kitchen-sensor',
      step: 'discovery_confirm',
    ),
  };

  /// `config_entries/flow/progress` payload.
  List<Map<String, Object?>> flowProgress() => [
    for (final MapEntry(:key, :value) in _flows.entries)
      {
        'flow_id': key,
        'handler': value.handler,
        'step_id': value.step,
        'context': {
          'source': 'zeroconf',
          'title_placeholders': {'name': value.name},
        },
      },
  ];

  Map<String, Object?> _flowStepJson(String flowId) {
    final f = _flows[flowId];
    if (f == null) {
      return {'type': 'abort', 'flow_id': flowId, 'reason': 'unknown_flow'};
    }
    Map<String, Object?> form(
      List<Map<String, Object?>> schema, {
      Map<String, String> errors = const {},
      Map<String, String> placeholders = const {},
    }) => {
      'type': 'form',
      'flow_id': flowId,
      'handler': f.handler,
      'step_id': f.step,
      'data_schema': schema,
      'errors': errors,
      'description_placeholders': placeholders,
    };
    return switch (f.step) {
      'confirm_discovery' => form(
        const [],
        placeholders: {'model': 'Shelly Plug S', 'host': '192.168.1.42'},
      ),
      'discovery_confirm' => form(const [], placeholders: {'name': f.name}),
      'encryption_key' => form(const [
        {'name': 'noise_psk', 'type': 'string', 'required': true},
      ]),
      _ => {'type': 'abort', 'flow_id': flowId, 'reason': 'unknown'},
    };
  }

  Map<String, Object?> flowStep(String flowId) => _flowStepJson(flowId);

  Map<String, Object?> flowSubmit(String flowId, Map<String, Object?> data) {
    final f = _flows[flowId];
    if (f == null) return _flowStepJson(flowId);
    switch ((f.handler, f.step)) {
      case ('shelly', 'confirm_discovery'):
        _flows.remove(flowId);
        _addWifiDevice(
          deviceId: 'd_shelly_plug',
          name: 'Shelly Plug S',
          manufacturer: 'Shelly',
          model: 'SHPLG-S',
          platform: 'shelly',
          identifier: ['shelly', 'c8c9a3'],
          entities: [
            (
              'switch.shelly_plug_s',
              'on',
              {'friendly_name': 'Shelly Plug S', 'device_class': 'outlet'},
            ),
          ],
        );
        return {
          'type': 'create_entry',
          'flow_id': flowId,
          'handler': 'shelly',
          'title': 'Shelly Plug S',
        };
      case ('esphome', 'discovery_confirm'):
        _flows[flowId] = (
          handler: f.handler,
          name: f.name,
          step: 'encryption_key',
        );
        return _flowStepJson(flowId);
      case ('esphome', 'encryption_key'):
        final key = data['noise_psk'];
        if (key is! String || key.length < 8) {
          return {
            ..._flowStepJson(flowId),
            'errors': {'base': 'invalid_psk'},
          };
        }
        _flows.remove(flowId);
        _addWifiDevice(
          deviceId: 'd_kitchen_sensor',
          name: 'kitchen-sensor',
          manufacturer: 'Espressif',
          model: 'ESP32',
          platform: 'esphome',
          identifier: ['esphome', 'kitchen-sensor'],
          entities: [
            (
              'sensor.kitchen_sensor_temperature',
              '23.1',
              {
                'friendly_name': 'Kuhinja temperatura',
                'device_class': 'temperature',
                'unit_of_measurement': '°C',
                'state_class': 'measurement',
              },
            ),
          ],
        );
        return {
          'type': 'create_entry',
          'flow_id': flowId,
          'handler': 'esphome',
          'title': 'kitchen-sensor',
        };
    }
    return _flowStepJson(flowId);
  }

  void flowAbort(String flowId) => _flows.remove(flowId);

  /// Whether the demo hub has a Z-Wave stick (tests switch it off).
  bool zwaveAvailable = true;

  void addZwaveDevice() {
    if (_states.containsKey('sensor.aeotec_multisensor_7_temperature')) return;
    _addWifiDevice(
      deviceId: 'd_zwave_ms7',
      name: 'Aeotec MultiSensor 7',
      manufacturer: 'Aeotec Ltd.',
      model: 'ZWA024',
      platform: 'zwave_js',
      identifier: ['zwave_js', '3967189138-7'],
      entities: [
        (
          'sensor.aeotec_multisensor_7_temperature',
          '21.8',
          {
            'friendly_name': 'Aeotec MultiSensor 7 temperatura',
            'device_class': 'temperature',
            'unit_of_measurement': '°C',
            'state_class': 'measurement',
          },
        ),
        (
          'binary_sensor.aeotec_multisensor_7_motion',
          'off',
          {
            'friendly_name': 'Aeotec MultiSensor 7 pokret',
            'device_class': 'motion',
          },
        ),
      ],
    );
  }

  /// `matter/commission` for a shared device: any well-formed code works
  /// once; `00000000000`-like codes fail as if the device were unreachable.
  /// `ip_addr` of the last `matter/commission_on_network` (tests).
  String? lastMatterIp;

  bool commissionMatter(String code) {
    if (code.startsWith('0000') || _states.containsKey('switch.eve_energy')) {
      return false;
    }
    _addWifiDevice(
      deviceId: 'd_eve_energy',
      name: 'Eve Energy',
      manufacturer: 'Eve Systems',
      model: 'Eve Energy 20EBO8301',
      platform: 'matter',
      identifier: ['matter', 'deviceid_0000000000000001-0000000000000005'],
      entities: [
        (
          'switch.eve_energy',
          'off',
          {'friendly_name': 'Eve Energy', 'device_class': 'outlet'},
        ),
      ],
    );
    return true;
  }

  /// A few `frontend/get_translations` keys (category `config`).
  Map<String, String> flowTranslations(Object? language) {
    final sr = language is String && language.startsWith('sr');
    return {
      'component.shelly.config.step.confirm_discovery.description': sr
          ? 'Da li želite da podesite {model} na adresi {host}?'
          : 'Do you want to set up the {model} at {host}?',
      'component.esphome.config.step.discovery_confirm.description': sr
          ? 'Da li želite da dodate ESPHome uređaj `{name}` u Home Assistant?'
          : 'Do you want to add the ESPHome node `{name}` to Home Assistant?',
      'component.esphome.config.step.encryption_key.title': sr
          ? 'Ključ za šifrovanje'
          : 'Enter encryption key',
      'component.esphome.config.step.encryption_key.data.noise_psk': sr
          ? 'Ključ za šifrovanje'
          : 'Encryption key',
      'component.esphome.config.error.invalid_psk': sr
          ? 'Ključ nije ispravan.'
          : 'The transport encryption key is invalid.',
    };
  }

  void _addWifiDevice({
    required String deviceId,
    required String name,
    required String manufacturer,
    required String model,
    required String platform,
    required List<String> identifier,
    required List<(String, String, Map<String, Object?>)> entities,
  }) {
    registries.devices.add({
      'id': deviceId,
      'name': name,
      'name_by_user': null,
      'manufacturer': manufacturer,
      'model': model,
      'area_id': null,
      'identifiers': [identifier],
      'connections': <List<String>>[],
      'via_device_id': null,
      'disabled_by': null,
    });
    for (final (id, _, _) in entities) {
      registries.entities.add({
        'entity_id': id,
        'platform': platform,
        'device_id': deviceId,
        'area_id': null,
        'entity_category': null,
        'hidden_by': null,
        'disabled_by': null,
      });
    }
    fireEvent('device_registry_updated', {
      'action': 'create',
      'device_id': deviceId,
    });
    for (final (id, state, attrs) in entities) {
      _setState(id, state, Map.of(attrs));
    }
  }

  /// Camera snapshots served so far (lets tests check polling stops).
  int cameraRequests = 0;
  final Set<_MockSocket> _sockets = {};

  final ({
    List<Map<String, Object?>> areas,
    List<Map<String, Object?>> devices,
    List<Map<String, Object?>> entities,
  })
  registries;

  /// `energy/get_prefs` payload; `null` simulates "Energy not configured".
  Map<String, Object?>? energyPrefs = buildMockEnergyPrefs();

  /// `recorder/statistics_during_period` with `types: [change]`, generated
  /// from [mockHourlyEnergy]. Only past buckets are returned.
  Map<String, Object?> statistics({
    required DateTime start,
    required DateTime end,
    required List<String> ids,
    required String period,
  }) {
    final now = _clock();
    final result = <String, Object?>{};
    for (final id in ids) {
      final rows = <Map<String, Object?>>[];
      var t = start.toLocal();
      while (t.isBefore(end) && t.isBefore(now)) {
        final next = period == 'hour'
            ? t.add(const Duration(hours: 1))
            : DateTime(t.year, t.month, t.day + 1);
        var change = 0.0;
        for (
          var h = t;
          h.isBefore(next) && h.isBefore(now);
          h = h.add(const Duration(hours: 1))
        ) {
          change += mockHourlyEnergy(id, h);
        }
        rows.add({
          'start': t.millisecondsSinceEpoch,
          'end': next.millisecondsSinceEpoch,
          'change': double.parse(change.toStringAsFixed(3)),
        });
        t = next;
      }
      if (rows.isNotEmpty) result[id] = rows;
    }
    return result;
  }

  /// Synthetic 24 hours from the current hour (type hourly): a daily
  /// temperature curve with a rain shower in the afternoon.
  List<Map<String, Object?>> hourlyForecast() {
    final now = _clock();
    final start = DateTime(now.year, now.month, now.day, now.hour);
    return [
      for (var i = 0; i < 24; i++)
        () {
          final t = start.add(Duration(hours: i));
          final h = t.hour;
          final rain = h >= 15 && h <= 17;
          return {
            'datetime': t.toUtc().toIso8601String(),
            'condition': rain
                ? 'rainy'
                : h >= 21 || h < 6
                ? 'clear-night'
                : h < 10
                ? 'partlycloudy'
                : 'sunny',
            // Coolest around 05:00, warmest around 15:00.
            'temperature': (13.0 + 5 * math.cos((h - 15) / 24 * 2 * math.pi))
                .roundToDouble(),
            'precipitation_probability': rain ? 60.0 : 5.0,
          };
        }(),
    ];
  }

  /// Synthetic 7-day forecast (mock `weather.get_forecasts`, type daily).
  List<Map<String, Object?>> dailyForecast() {
    const conditions = [
      'partlycloudy',
      'sunny',
      'rainy',
      'cloudy',
      'sunny',
      'lightning-rainy',
      'partlycloudy',
    ];
    final today = _clock();
    return [
      for (var i = 0; i < 7; i++)
        {
          'datetime': DateTime(
            today.year,
            today.month,
            today.day + i,
            12,
          ).toUtc().toIso8601String(),
          'condition': conditions[i],
          'temperature': 18.0 + i - (i == 2 ? 4 : 0),
          'templow': 9.0 + i / 2,
          'precipitation': i == 2 ? 6.4 : 0.0,
        },
    ];
  }

  /// `GET /api/config` / WS `get_config` payload.
  final Map<String, Object?> config = {
    'location_name': 'Demo dom (mock)',
    'version': version,
    'time_zone': 'Europe/Belgrade',
    'latitude': 44.8125,
    'longitude': 20.4612,
    'unit_system': {'temperature': '°C'},
    'components': ['light', 'switch', 'sensor', 'climate', 'scene', 'matter'],
  };

  /// Artificial latency for `get_states`, to exercise events that arrive
  /// while a snapshot is loading.
  Duration getStatesDelay = Duration.zero;

  /// Sends a bare bus event (e.g. `entity_registry_updated`) to subscribers.
  void fireEvent(String eventType, [Map<String, Object?> data = const {}]) {
    final event = {
      'event_type': eventType,
      'data': data,
      'origin': 'LOCAL',
      'time_fired': _clock().toUtc().toIso8601String(),
    };
    for (final socket in _sockets) {
      socket._dispatchEvent(event);
    }
  }

  /// When false, new connections fail as if the server were down.
  bool online = true;

  /// Hosts the "phone" cannot reach, e.g. the home address while away.
  final Set<String> unreachableHosts = {};

  bool reachable(String host) => online && !unreachableHosts.contains(host);

  // --- OAuth2 (see MockHaAuthClient) ---
  // Codes and refresh tokens are recognised by their format, so they stay
  // valid across a page reload (which recreates this in-memory server in
  // the web build). Only used codes and revoked tokens are remembered.
  int _nextAuthCode = 1;
  final Set<String> _usedAuthCodes = {};

  /// Refresh tokens revoked via `/auth/revoke`.
  final Set<String> revokedRefreshTokens = {};
  Duration accessTokenLifetime = const Duration(minutes: 30);

  /// Number of refresh-token grants (tests check single-flight refresh).
  int refreshCount = 0;

  /// Currently open WebSocket connections (leak checks in tests).
  int get openConnections => _sockets.length;

  /// Event subscriptions held by open connections (leak checks in tests).
  int get activeSubscriptions =>
      _sockets.fold(0, (sum, s) => sum + s._subscriptions.length);

  bool acceptsToken(String? token) =>
      token != null && token.isNotEmpty && token != mockInvalidToken;

  List<Map<String, Object?>> get states => _states.values.toList();

  Future<HaSocket> connect(Uri uri) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!reachable(uri.host)) {
      throw const AppFailure(
        FailureKind.network,
        debugMessage: 'mock server offline',
      );
    }
    final socket = _MockSocket(this);
    _sockets.add(socket);
    scheduleMicrotask(
      () => socket._emit({'type': 'auth_required', 'ha_version': version}),
    );
    return socket;
  }

  /// Simulates a server restart: drops every open connection.
  Future<void> dropAllConnections() async {
    for (final socket in _sockets.toList()) {
      await socket._serverClose();
    }
  }

  /// `logbook.log` entries written by the app.
  final List<Map<String, Object?>> logbookMessages = [];

  /// Applies a subset of real Home Assistant services to the mock state.
  List<Map<String, Object?>> callService(
    String domain,
    String service,
    Map<String, Object?> data,
  ) {
    // notify.mobile_app_<device name>, as Home Assistant creates it.
    if (domain == 'notify' && service.startsWith('mobile_app_')) {
      for (final MapEntry(:key, :value) in mobileApps.entries) {
        if ('mobile_app_${_slug('${value['device_name']}')}' == service) {
          final message = data['message'];
          sendPush(
            key,
            message: message is String ? message : '',
            title: data['title'] is String ? data['title']! as String : null,
            data: switch (data['data']) {
              final Map<Object?, Object?> extra => {
                for (final e in extra.entries) '${e.key}': e.value,
              },
              _ => null,
            },
          );
        }
      }
      return const [];
    }
    if (domain == 'logbook' && service == 'log') {
      logbookMessages.add(Map.of(data));
      return const [];
    }
    if (domain == 'zha' && service == 'permit' && zhaAvailable) {
      final d = data['duration'];
      _permitJoin(d is num ? d.toInt() : 60);
      return const [];
    }
    if (domain == 'alarm_control_panel' &&
        service == 'alarm_disarm' &&
        data['code'] != '1234') {
      // Like HA: a wrong code is rejected (HTTP 400).
      throw const AppFailure(
        FailureKind.validation,
        statusCode: 400,
        debugMessage: 'Invalid alarm code provided',
      );
    }
    if (domain == 'todo') {
      _todoService(service, data);
      return const [];
    }
    if (domain == 'remote' && service == 'send_command') {
      final command = data['command'];
      if (command is String) remoteCommands.add(command);
      return const [];
    }
    if (domain == 'tts' && service == 'speak') {
      lastTtsSpeak = Map.of(data);
      return const [];
    }
    if (domain == 'persistent_notification') {
      if (service == 'create' && data['message'] is String) {
        final id = data['notification_id'] is String
            ? data['notification_id']! as String
            : 'mock-${notifications.length + 1}';
        final n = {
          'notification_id': id,
          'title': data['title'] is String ? data['title'] : null,
          'message': data['message'],
          'created_at': _clock().toUtc().toIso8601String(),
        };
        notifications[id] = n;
        for (final socket in _sockets) {
          socket._notifyNotifications('added', {id: n});
        }
      } else if (service == 'dismiss' && data['notification_id'] is String) {
        _dismissNotifications([data['notification_id']! as String]);
      } else if (service == 'dismiss_all') {
        _dismissNotifications(notifications.keys.toList());
      }
      return const [];
    }
    if (domain == 'script' && (service == 'turn_on' || service == 'turn_off')) {
      final id = data['entity_id'];
      if (id is String && scripts.containsKey(id.substring('script.'.length))) {
        if (service == 'turn_on') {
          _runScript(id, switch (data['variables']) {
            final Map<String, Object?> v => v,
            _ => const {},
          });
        } else {
          _stopScript(id);
        }
        return const [];
      }
    }
    if (domain == 'mqtt' && service == 'publish') {
      final topic = data['topic'];
      final payload = data['payload'];
      if (topic is String) {
        lastMqttPublish = (topic, payload is String ? payload : '');
      }
      return const [];
    }
    final ids = switch (data['entity_id']) {
      final String id => [id],
      final List<Object?> list => list.whereType<String>().toList(),
      _ => <String>[],
    };
    final changed = <Map<String, Object?>>[];
    for (final id in ids) {
      final current = _states[id];
      if (current == null || current['state'] == 'unavailable') continue;
      final attrs = Map<String, Object?>.of(
        current['attributes']! as Map<String, Object?>,
      );
      var state = current['state']! as String;

      switch ((domain, service)) {
        case ('light' || 'switch' || 'automation', 'turn_on'):
          state = 'on';
          if (domain == 'light') _applyLightData(attrs, data);
        case ('light' || 'switch' || 'automation', 'turn_off'):
          state = 'off';
          if (domain == 'light') attrs['brightness'] = null;
        case ('light' || 'switch' || 'automation', 'toggle'):
          state = state == 'on' ? 'off' : 'on';
        case ('climate', 'set_temperature'):
          final t = data['temperature'];
          if (t is num) attrs['temperature'] = t.toDouble();
        case ('climate', 'set_hvac_mode'):
          final mode = data['hvac_mode'];
          if (mode is String && (attrs['hvac_modes']! as List).contains(mode)) {
            state = mode;
          }
        case ('media_player', 'media_play_pause'):
          // Like HA: the reported position is fixed when the state changes.
          final at = DateTime.tryParse('${attrs['media_position_updated_at']}');
          final pos = attrs['media_position'];
          if (state == 'playing' && pos is num && at != null) {
            attrs['media_position'] =
                pos + _clock().difference(at).inMilliseconds / 1000;
          }
          attrs['media_position_updated_at'] = _clock()
              .toUtc()
              .toIso8601String();
          state = state == 'playing' ? 'paused' : 'playing';
        case ('media_player', 'media_next_track' || 'media_previous_track'):
          const titles = ['Kafa i kiša', 'Tiho jutro', 'Večernji šetač'];
          final i = titles.indexOf(attrs['media_title'] as String? ?? '');
          final step = service == 'media_next_track' ? 1 : titles.length - 1;
          attrs['media_title'] = titles[(i + step) % titles.length];
          // Like HA: a new track, a new artwork URL (its `cache` changes).
          final picture = attrs['entity_picture'];
          if (picture is String) {
            attrs['entity_picture'] = picture.replaceFirst(
              RegExp(r'cache=[^&]*'),
              'cache=${attrs['media_title'].hashCode}',
            );
          }
          if (attrs.containsKey('media_position')) {
            attrs['media_position'] = 0;
            attrs['media_position_updated_at'] = _clock()
                .toUtc()
                .toIso8601String();
          }
          state = 'playing';
        case ('media_player', 'media_seek'):
          final to = data['seek_position'];
          if (to is num) {
            attrs['media_position'] = to;
            attrs['media_position_updated_at'] = _clock()
                .toUtc()
                .toIso8601String();
          }
        case ('media_player', 'shuffle_set'):
          if (data['shuffle'] is bool) attrs['shuffle'] = data['shuffle'];
        case ('media_player', 'repeat_set'):
          if (data['repeat'] is String) attrs['repeat'] = data['repeat'];
        case ('media_player', 'volume_set'):
          final v = data['volume_level'];
          if (v is num) attrs['volume_level'] = v.toDouble();
        case ('media_player', 'volume_mute'):
          if (data['is_volume_muted'] is bool) {
            attrs['is_volume_muted'] = data['is_volume_muted'];
          }
        case ('media_player', 'select_sound_mode'):
          final mode = data['sound_mode'];
          if (mode is String &&
              (attrs['sound_mode_list'] as List?)?.contains(mode) == true) {
            attrs['sound_mode'] = mode;
          }
        case ('alarm_control_panel', final s) when s.startsWith('alarm_arm_'):
          state = 'armed_${s.substring('alarm_arm_'.length)}';
        case ('alarm_control_panel', 'alarm_disarm'):
          // Demo code: 1234.
          if (data['code'] == '1234') state = 'disarmed';
        case ('fan', 'set_percentage'):
          final p = data['percentage'];
          if (p is num) {
            attrs['percentage'] = p.toInt();
            state = p > 0 ? 'on' : 'off';
          }
        case ('fan', 'oscillate'):
          attrs['oscillating'] = data['oscillating'] == true;
        case ('fan', 'turn_on'):
          state = 'on';
          if ((attrs['percentage'] as num? ?? 0) == 0) attrs['percentage'] = 33;
        case ('fan', 'turn_off'):
          state = 'off';
        case ('vacuum', 'start'):
          state = 'cleaning';
        case ('vacuum', 'pause'):
          state = 'paused';
        case ('vacuum', 'return_to_base'):
          state = 'returning';
        case ('humidifier', 'turn_on'):
          state = 'on';
        case ('humidifier', 'turn_off'):
          state = 'off';
        case ('humidifier', 'set_humidity'):
          final h = data['humidity'];
          if (h is num) attrs['humidity'] = h.toInt();
        case ('humidifier', 'set_mode'):
          final m = data['mode'];
          if (m is String) attrs['mode'] = m;
        case ('input_select' || 'select', 'select_option'):
          final o = data['option'];
          if (o is String && (attrs['options'] as List).contains(o)) state = o;
        case ('input_number' || 'number', 'set_value'):
          final v = data['value'];
          if (v is num) state = v.toDouble().toString();
        case ('media_player', 'select_source'):
          final source = data['source'];
          if (source is String &&
              (attrs['source_list'] as List?)?.contains(source) == true) {
            attrs['source'] = source;
          }
        case ('media_player', 'turn_off'):
          state = 'off';
        case ('media_player', 'turn_on'):
          state = 'idle';
        case ('climate', 'turn_off'):
          attrs['last_on_mode'] = state;
          state = 'off';
        case ('climate', 'turn_on'):
          if (state == 'off') {
            state = attrs.remove('last_on_mode') as String? ?? 'heat';
          }
        case ('climate', 'set_preset_mode'):
          final mode = data['preset_mode'];
          if (mode is String &&
              (attrs['preset_modes']! as List).contains(mode)) {
            attrs['preset_mode'] = mode;
          }
        case ('cover', 'open_cover'):
          state = 'open';
          attrs['current_position'] = 100;
        case ('cover', 'close_cover'):
          state = 'closed';
          attrs['current_position'] = 0;
        case ('cover', 'set_cover_position'):
          final p = data['position'];
          if (p is int) {
            attrs['current_position'] = p.clamp(0, 100);
            state = p == 0 ? 'closed' : 'open';
          }
        case ('lock', 'lock'):
          state = 'locked';
        case ('lock', 'unlock'):
          state = 'unlocked';
        case ('scene', 'turn_on'):
          state = _clock().toUtc().toIso8601String();
          scheduleMicrotask(() => _applyScene(id));
        default:
          continue;
      }
      changed.add(_setState(id, state, attrs));
    }
    return changed;
  }

  void _applyLightData(Map<String, Object?> attrs, Map<String, Object?> data) {
    final pct = data['brightness_pct'];
    final raw = data['brightness'];
    if (pct is num) {
      attrs['brightness'] = (pct.clamp(0, 100) * 255 / 100).round();
    } else if (raw is num) {
      attrs['brightness'] = raw.clamp(0, 255).round();
    } else {
      attrs['brightness'] ??= 255;
    }
    final kelvin = data['color_temp_kelvin'];
    if (kelvin is int) attrs['color_temp_kelvin'] = kelvin;
    final rgb = data['rgb_color'];
    if (rgb is List && rgb.length == 3) {
      attrs['rgb_color'] = List<Object?>.of(rgb);
      attrs['color_mode'] = 'rgb';
    }
  }

  /// Changes a state and broadcasts `state_changed` (also used by tests).
  Map<String, Object?> _setState(
    String id,
    String state,
    Map<String, Object?> attrs,
  ) {
    final old = _states[id];
    final now = _clock().toUtc().toIso8601String();
    final next = {
      'entity_id': id,
      'state': state,
      'attributes': attrs,
      'last_changed': old?['state'] == state ? old!['last_changed'] : now,
      'last_updated': now,
    };
    _states[id] = next;
    final event = {
      'event_type': 'state_changed',
      'data': {'entity_id': id, 'old_state': old, 'new_state': next},
      'origin': 'LOCAL',
      'time_fired': now,
    };
    for (final socket in _sockets) {
      socket._dispatchEvent(event);
    }
    return next;
  }

  /// `conversation/process` result (also the `intent_output` of an Assist
  /// pipeline run): lights on/off, temperature, otherwise not understood.
  Map<String, Object?> converse(
    String text, {
    String? language,
    String? conversationId,
  }) {
    final t = text.toLowerCase();
    final sr = language?.startsWith('sr') ?? false;
    bool has(List<String> words) => words.any(t.contains);
    Map<String, Object?> reply(String speech, String type) => {
      'conversation_id': conversationId ?? 'mock-conversation',
      'response': {
        'response_type': type,
        'speech': {
          'plain': {'speech': speech},
        },
      },
    };
    final lights = [
      for (final s in states)
        if ((s['entity_id']! as String).startsWith('light.'))
          s['entity_id']! as String,
    ];
    if (has(['svetl', 'light'])) {
      final off = has(['ugasi', 'isključi', 'iskljuci', 'turn off', 'off']);
      final on = has(['upali', 'uključi', 'ukljuci', 'turn on', ' on']);
      if (off || on) {
        callService('light', off ? 'turn_off' : 'turn_on', {
          'entity_id': lights,
        });
        return reply(
          sr
              ? (off ? 'Ugasio sam svetla.' : 'Upalio sam svetla.')
              : (off ? 'Turned off the lights.' : 'Turned on the lights.'),
          'action_done',
        );
      }
    }
    if (has(['temperatur'])) {
      return reply(
        sr ? 'U dnevnoj sobi je 22,4 °C.' : 'The living room is 22.4 °C.',
        'query_answer',
      );
    }
    return reply(
      sr ? 'Izvinite, nisam razumeo.' : "Sorry, I couldn't understand that.",
      'error',
    );
  }

  String? stateForTest(String id) => _states[id]?['state'] as String?;

  void setStateForTest(String id, String state) {
    final current = _states[id];
    if (current == null) return;
    _setState(
      id,
      state,
      Map.of(current['attributes']! as Map<String, Object?>),
    );
  }
}
