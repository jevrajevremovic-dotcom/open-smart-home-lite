part of 'mock_home_assistant.dart';

class _MockSocket implements HaSocket {
  _MockSocket(this._server);

  final MockHomeAssistantServer _server;
  final StreamController<String> _out = StreamController<String>();
  final Map<int, String?> _subscriptions = {};
  bool _authenticated = false;

  @override
  Stream<String> get messages => _out.stream;

  void _emit(Map<String, Object?> message) {
    if (!_out.isClosed) _out.add(jsonEncode(message));
  }

  void _dispatchEvent(Map<String, Object?> event) {
    if (!_authenticated) return;
    _subscriptions.forEach((id, type) {
      if (type == null || type == event['event_type']) {
        _emit({'id': id, 'type': 'event', 'event': event});
      }
    });
  }

  @override
  void send(String message) {
    final msg = jsonDecode(message) as Map<String, Object?>;
    final id = msg['id'] as int?;
    final type = msg['type'];
    if (!_authenticated) {
      if (type != 'auth') return;
      if (_server.acceptsToken(msg['access_token'] as String?)) {
        _authenticated = true;
        _emit({
          'type': 'auth_ok',
          'ha_version': MockHomeAssistantServer.version,
        });
      } else {
        _emit({
          'type': 'auth_invalid',
          'message': 'Invalid access token or password',
        });
        unawaited(_serverClose());
      }
      return;
    }
    Map<String, Object?> ok([Object? result]) => {
      'id': id,
      'type': 'result',
      'success': true,
      'result': result,
    };

    switch (type) {
      case 'ping':
        _emit({'id': id, 'type': 'pong'});
      case 'subscribe_events':
        _subscriptions[id!] = msg['event_type'] as String?;
        _emit(ok());
      case 'unsubscribe_events'
          when _pushSubs.containsValue(msg['subscription']):
        _pushSubs.removeWhere((_, v) => v == msg['subscription']);
        _emit(ok());
      case 'unsubscribe_events' when msg['subscription'] == _notificationSub:
        _notificationSub = null;
        _emit(ok());
      case 'unsubscribe_events' when _todoSubs.containsKey(msg['subscription']):
        _todoSubs.remove(msg['subscription']);
        _emit(ok());
      case 'unsubscribe_events' when msg['subscription'] == _assistRun:
        _assistRun = null;
        _emit(ok());
      case 'unsubscribe_events' when msg['subscription'] == _zwaveSub:
        _stopZwave();
        _emit(ok());
      case 'unsubscribe_events':
        final known = _subscriptions.containsKey(msg['subscription']);
        _subscriptions.remove(msg['subscription']);
        _emit(
          known
              ? ok()
              : {
                  'id': id,
                  'type': 'result',
                  'success': false,
                  'error': {
                    'code': 'not_found',
                    'message': 'Subscription not found.',
                  },
                },
        );
      case 'get_states':
        // Snapshot is taken now; delivery may be delayed.
        final snapshot = _server.states;
        if (_server.getStatesDelay == Duration.zero) {
          _emit(ok(snapshot));
        } else {
          Future<void>.delayed(
            _server.getStatesDelay,
            () => _emit(ok(snapshot)),
          );
        }
      case 'get_config':
        _emit(ok(_server.config));
      case 'energy/get_prefs':
        final prefs = _server.energyPrefs;
        _emit(
          prefs == null
              ? {
                  'id': id,
                  'type': 'result',
                  'success': false,
                  'error': {'code': 'not_found', 'message': 'No prefs'},
                }
              : ok(prefs),
        );
      case 'recorder/statistics_during_period':
        _emit(
          ok(
            _server.statistics(
              start: DateTime.parse(msg['start_time']! as String),
              end: DateTime.parse(msg['end_time']! as String),
              ids: (msg['statistic_ids']! as List).cast<String>(),
              period: msg['period']! as String,
            ),
          ),
        );
      case 'config/area_registry/list':
        _emit(ok(_server.registries.areas));
      case 'config/device_registry/list':
        _emit(ok(_server.registries.devices));
      case 'config_entries/get':
        _emit(
          ok([
            if (msg['domain'] == 'zwave_js' && _server.zwaveAvailable)
              {
                'entry_id': 'zwavejs01',
                'domain': 'zwave_js',
                'title': 'Z-Wave JS',
                'state': 'loaded',
              },
          ]),
        );
      case 'camera/stream':
        _emit({
          'id': id,
          'type': 'result',
          'success': false,
          'error': {
            'code': 'start_stream_failed',
            'message': 'Demo cameras have no live stream',
          },
        });
      case 'mobile_app/push_notification_channel':
        final webhook = msg['webhook_id'];
        if (webhook is! String || !_server.mobileApps.containsKey(webhook)) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'not_found', 'message': 'Webhook ID not found'},
          });
        } else {
          _pushSubs[webhook] = id!;
          _emit(ok());
        }
      case 'webhook/handle':
        final webhook = msg['webhook_id'];
        final body = msg['body'];
        if (webhook is! String || !_server.mobileApps.containsKey(webhook)) {
          _emit({
            'id': id,
            'type': 'result',
            'success': true,
            'result': {'status': 410, 'body': null},
          });
        } else {
          final json = body is String ? jsonDecode(body) : null;
          var status = 200;
          if (json is Map && json['type'] == 'fire_event') {
            _server.firedEvents.add(
              Map<String, Object?>.from(json['data'] as Map),
            );
          } else if (json is Map && json['type'] == 'scan_tag') {
            _server.scanTag((json['data']! as Map)['tag_id']! as String);
          } else if (json is Map &&
              (json['type'] == 'register_sensor' ||
                  json['type'] == 'update_sensor_states')) {
            status = _server.mobileAppSensors(
              webhook,
              json['type']! as String,
              json['data'],
            );
          }
          _emit({
            'id': id,
            'type': 'result',
            'success': true,
            'result': {'status': status, 'body': '{}'},
          });
        }
      case 'mobile_app/push_notification_confirm':
        final confirmId = msg['confirm_id'];
        if (confirmId is String) _server.confirmedPushes.add(confirmId);
        _emit(ok());
      // Frontend storage (homeassistant/components/frontend/storage.py):
      // per-user data, and system data that only an admin may write.
      case 'frontend/get_user_data':
        _emit(ok({'value': _server.userData[msg['key']]}));
      case 'frontend/set_user_data':
        _server.userData[msg['key']! as String] = msg['value'];
        _emit(ok());
      case 'frontend/get_system_data':
        _emit(ok({'value': _server.systemData[msg['key']]}));
      case 'frontend/set_system_data':
        if (!_server.configAdmin) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'unauthorized', 'message': 'Unauthorized'},
          });
        } else {
          _server.systemData[msg['key']! as String] = msg['value'];
          _emit(ok());
        }
      case 'tag/list':
        _emit(ok([for (final t in _server.tags.values) Map.of(t)]));
      case 'tag/create':
        if (!_server.configAdmin) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'unauthorized', 'message': 'Unauthorized'},
          });
        } else {
          final tagId = msg['tag_id']! as String;
          _server.tags[tagId] = {
            'id': tagId,
            if (msg['name'] case final String name) 'name': name,
          };
          _emit(ok(_server.tags[tagId]));
        }
      case 'assist_pipeline/run':
        final input = msg['input'];
        if (msg['start_stage'] != 'wake_word' ||
            input is! Map ||
            input['sample_rate'] is! int) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'invalid_format', 'message': 'bad run'},
          });
        } else if (!_server.wakeWordEngine) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {
              'code': 'wake-engine-missing',
              'message': 'No wake word engine',
            },
          });
        } else {
          _assistRun = id;
          _assistStage = 0;
          _assistConversation = msg['conversation_id'] as String?;
          _emit(ok());
          _assistEvent('run-start', {
            'pipeline': 'mock-pipeline',
            'language': _server.assistLanguage,
            'conversation_id': _assistConversation ?? 'mock-conversation',
            'runner_data': {
              'stt_binary_handler_id': _assistHandler,
              'timeout': msg['timeout'] ?? 300,
            },
          });
          _assistEvent('wake_word-start', {
            'entity_id': 'wake_word.openwakeword',
            'metadata': {'format': 'wav', 'codec': 'pcm'},
            'timeout': input['timeout'] ?? 3,
          });
        }
      case 'image/list':
        _emit(ok([for (final (item, _) in _server.images.values) item]));
      case 'image/subscribe':
        _imageSub = id;
        _emit(ok());
        // Like Home Assistant: one first event with every item as "added".
        final all = [
          for (final (item, _) in _server.images.values)
            {'change_type': 'added', 'image_id': item['id'], 'item': item},
        ];
        scheduleMicrotask(
          () => _emit({'id': id, 'type': 'event', 'event': all}),
        );
      case 'image/delete':
        if (!_server.imageAdmin) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'unauthorized', 'message': 'Unauthorized'},
          });
        } else if (_server.deleteImage(msg['image_id']! as String)) {
          _emit(ok());
        } else {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'not_found', 'message': 'Unable to find image'},
          });
        }
      case 'todo/item/subscribe' || 'todo/item/list':
        final entity = msg['entity_id'];
        final items = entity is String ? _server.todoItems[entity] : null;
        if (items == null) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {
              'code': 'invalid_entity_id',
              'message': 'To-do list entity not found: $entity',
            },
          });
        } else if (type == 'todo/item/list') {
          _emit(ok({'items': items}));
        } else {
          _todoSubs[id!] = entity! as String;
          _emit(ok());
          _notifyTodo(entity as String, items);
        }
      case 'persistent_notification/subscribe':
        _notificationSub = id;
        _emit(ok());
        _notifyNotifications('current', _server.notifications);
      case 'zwave_js/add_node':
        _stopZwave();
        _zwaveSub = id;
        _emit(ok());
        _zwaveAfter(100, {'event': 'inclusion started', 'secure': true});
        _zwaveAfter(3000, {
          'event': 'node found',
          'node': {'node_id': 7},
        });
        _zwaveAfter(3500, {
          'event': 'grant security classes',
          'requested_grant': {
            'securityClasses': [1, 0],
            'clientSideAuth': false,
          },
        });
      case 'zwave_js/grant_security_classes':
        _emit(ok());
        final classes = msg['security_classes'];
        if (classes is List && classes.contains(1)) {
          _zwaveAfter(500, {
            'event': 'validate dsk and enter pin',
            'dsk': '12345-23456-34567-45678-56789-01234-12345-23456',
          });
        } else {
          _zwaveInterview();
        }
      case 'zwave_js/validate_dsk_and_enter_pin':
        _emit(ok());
        if (msg['pin'] == '12345') {
          _zwaveInterview();
        } else {
          _zwaveAfter(300, {'event': 'inclusion failed'});
        }
      case 'zwave_js/provision_smart_start_node':
        final qr = msg['qr_code_string'];
        if (qr is String && RegExp(r'^90\d{50,}$').hasMatch(qr)) {
          _emit(ok());
        } else {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'invalid_format', 'message': 'Invalid QR code'},
          });
        }
      case 'matter/commission':
        final code = msg['code'];
        if (code is String && _server.commissionMatter(code)) {
          _emit(ok(null));
        } else {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {
              'code': 'unknown_error',
              'message': 'Commissioning failed',
            },
          });
        }
      case 'matter/commission_on_network':
        final pin = msg['pin'];
        _server.lastMatterIp = msg['ip_addr'] as String?;
        if (pin is int && _server.commissionMatter('$pin')) {
          _emit(ok(null));
        } else {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {
              'code': 'unknown_error',
              'message': 'Commissioning failed',
            },
          });
        }
      case 'config_entries/flow/progress':
        _emit(ok(_server.flowProgress()));
      case 'frontend/get_translations':
        _emit(ok({'resources': _server.flowTranslations(msg['language'])}));
      case 'config/entity_registry/update':
        final entityId = msg['entity_id'] as String? ?? '';
        final entry = _server.registries.entities
            .where((e) => e['entity_id'] == entityId)
            .firstOrNull;
        final state = _server._states[entityId];
        if (state == null) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'not_found', 'message': 'Entity not found'},
          });
          break;
        }
        if (msg.containsKey('area_id') && entry != null) {
          entry['area_id'] = msg['area_id'];
        }
        if (msg['name'] case final String name) {
          _server._setState(entityId, state['state']! as String, {
            ...state['attributes']! as Map<String, Object?>,
            'friendly_name': name,
          });
        }
        _server.fireEvent('entity_registry_updated', {
          'action': 'update',
          'entity_id': entityId,
        });
        _emit(ok({'entity_entry': entry}));
      case 'config/device_registry/update':
        final device = _server.updateDevice(
          msg['device_id'] as String? ?? '',
          nameByUser: msg['name_by_user'],
          areaId: msg['area_id'],
          setName: msg.containsKey('name_by_user'),
          setArea: msg.containsKey('area_id'),
        );
        if (device == null) {
          _emit({
            'id': id,
            'type': 'result',
            'success': false,
            'error': {'code': 'not_found', 'message': 'Device not found'},
          });
        } else {
          _emit(ok(device));
        }
      case 'config/floor_registry/list':
        _emit(ok(buildMockFloors()));
      case 'config/entity_registry/list':
        _emit(ok(_server.registries.entities));
      case 'call_service':
        _server.callService(
          msg['domain']! as String,
          msg['service']! as String,
          {
            ...?msg['service_data'] as Map<String, Object?>?,
            ...?msg['target'] as Map<String, Object?>?,
          },
        );
        _emit(
          ok({
            'context': {'id': 'mock'},
          }),
        );
      default:
        _emit({
          'id': id,
          'type': 'result',
          'success': false,
          'error': {'code': 'unknown_command', 'message': 'Unknown command.'},
        });
    }
  }

  int? _notificationSub;

  /// Push channels by webhook id → subscription id.
  final Map<String, int> _pushSubs = {};

  void _push(String webhookId, Map<String, Object?> event) {
    final sub = _pushSubs[webhookId];
    if (sub == null) return;
    scheduleMicrotask(
      () => _emit({'id': sub, 'type': 'event', 'event': event}),
    );
  }

  int? _imageSub;

  /// `image/subscribe` events: a list of changes, as Home Assistant's
  /// storage collections send them.
  void _notifyImages(String change, String imageId, Map<String, Object?> item) {
    final sub = _imageSub;
    if (sub == null) return;
    scheduleMicrotask(
      () => _emit({
        'id': sub,
        'type': 'event',
        'event': [
          {'change_type': change, 'image_id': imageId, 'item': item},
        ],
      }),
    );
  }

  /// Open `todo/item/subscribe` subscriptions: id → entity id.
  final Map<int, String> _todoSubs = {};

  void _notifyTodo(String entityId, List<Map<String, Object?>> items) {
    final copy = [for (final i in items) Map.of(i)];
    _todoSubs.forEach((sub, entity) {
      if (entity != entityId) return;
      scheduleMicrotask(
        () => _emit({
          'id': sub,
          'type': 'event',
          'event': {'items': copy},
        }),
      );
    });
  }

  void _notifyNotifications(
    String type,
    Map<String, Map<String, Object?>> items,
  ) {
    final sub = _notificationSub;
    if (sub == null) return;
    scheduleMicrotask(
      () => _emit({
        'id': sub,
        'type': 'event',
        'event': {'type': type, 'notifications': items},
      }),
    );
  }

  // --- Z-Wave inclusion simulation ---
  int? _zwaveSub;

  /// Demo Assist pipeline run (`assist_pipeline/run`): any loud sound counts
  /// as the wake word, then half a second of audio is "heard" as a command
  /// to turn off the lights.
  int? _assistRun;
  int _assistStage = 0;
  int _assistBytes = 0;
  String? _assistConversation;

  static const _assistHandler = 1;

  void _assistEvent(String type, [Map<String, Object?>? data]) {
    final id = _assistRun;
    if (id == null) return;
    _emit({
      'id': id,
      'type': 'event',
      'event': {'type': type, 'data': data},
    });
  }

  @override
  void sendBytes(Uint8List data) {
    if (_assistRun == null || data.isEmpty || data[0] != _assistHandler) {
      return;
    }
    final audio = data.sublist(1);
    if (audio.isEmpty) {
      _assistStage = 2; // stream ended
      return;
    }
    switch (_assistStage) {
      case 0:
        var peak = 0;
        final view = ByteData.sublistView(audio);
        for (var i = 0; i + 1 < audio.length; i += 2) {
          peak = math.max(peak, view.getInt16(i, Endian.little).abs());
        }
        if (peak < 16000) return;
        _assistStage = 1;
        _assistBytes = 0;
        _assistEvent('wake_word-end', {
          'wake_word_output': {
            'wake_word_id': 'ok_nabu',
            'wake_word_phrase': 'Okay Nabu',
            'timestamp': 0,
          },
        });
        _assistEvent('stt-start', {
          'engine': 'stt.mock',
          'metadata': {'language': _server.assistLanguage},
        });
      case 1:
        _assistBytes += audio.length;
        if (_assistBytes < 16000) return; // half a second
        _assistStage = 2;
        final sr = _server.assistLanguage.startsWith('sr');
        final text =
            _server.assistHeard ??
            (sr ? 'ugasi svetla' : 'turn off the lights');
        _assistEvent('stt-vad-end', {'timestamp': 500});
        _assistEvent('stt-end', {
          'stt_output': {'text': text},
        });
        _assistEvent('intent-start', {
          'engine': 'conversation.home_assistant',
          'language': _server.assistLanguage,
          'intent_input': text,
        });
        _assistEvent('intent-end', {
          'processed_locally': true,
          'intent_output': _server.converse(
            text,
            language: _server.assistLanguage,
            conversationId: _assistConversation,
          ),
        });
        _assistEvent('run-end');
    }
  }

  final List<Timer> _zwaveTimers = [];

  void _zwaveAfter(int ms, Map<String, Object?> event) {
    final sub = _zwaveSub;
    _zwaveTimers.add(
      Timer(Duration(milliseconds: ms), () {
        if (_zwaveSub == sub && sub != null) {
          _emit({'id': sub, 'type': 'event', 'event': event});
        }
      }),
    );
  }

  void _zwaveInterview() {
    _zwaveAfter(300, {'event': 'interview started'});
    _zwaveTimers.add(
      Timer(const Duration(milliseconds: 1800), () {
        if (_zwaveSub == null) return;
        _server.addZwaveDevice();
      }),
    );
    _zwaveAfter(2000, {
      'event': 'device registered',
      'device': {'name': 'Aeotec MultiSensor 7', 'id': 'd_zwave_ms7'},
    });
    _zwaveAfter(2500, {'event': 'interview completed'});
  }

  void _stopZwave() {
    for (final t in _zwaveTimers) {
      t.cancel();
    }
    _zwaveTimers.clear();
    _zwaveSub = null;
  }

  Future<void> _serverClose() async {
    _stopZwave();
    _server._sockets.remove(this);
    await _out.close();
  }

  @override
  Future<void> close() => _serverClose();
}
