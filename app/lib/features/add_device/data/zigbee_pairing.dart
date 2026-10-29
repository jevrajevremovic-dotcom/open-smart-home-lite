import 'dart:convert';

import '../../../integrations/home_assistant/api/home_assistant_api.dart';
import '../../../integrations/home_assistant/websocket/ha_websocket_manager.dart';
import '../../devices/domain/smart_home_device.dart';

/// Zigbee coordinator software running next to Home Assistant.
enum ZigbeeBackend {
  /// HA's built-in integration; pairing via the documented `zha.permit`.
  zha,

  /// Zigbee2MQTT; pairing via a documented Z2M MQTT request, sent with
  /// HA's documented `mqtt.publish` service.
  zigbee2mqtt,
}

/// Which Zigbee backends this Home Assistant has.
///
/// ZHA: the `zha.permit` service exists. Zigbee2MQTT: `mqtt.publish`
/// exists and the Zigbee2MQTT bridge device is known.
Set<ZigbeeBackend> detectZigbeeBackends(
  Map<String, Set<String>> services,
  Iterable<SmartHomeDevice> devices,
) => {
  if (services['zha']?.contains('permit') ?? false) ZigbeeBackend.zha,
  if ((services['mqtt']?.contains('publish') ?? false) &&
      devices.any(
        (d) =>
            (d.manufacturer ?? '').toLowerCase() == 'zigbee2mqtt' ||
            d.id.startsWith('sensor.zigbee2mqtt_bridge'),
      ))
    ZigbeeBackend.zigbee2mqtt,
};

/// Opens and closes the Zigbee network for new devices.
class ZigbeePairing {
  ZigbeePairing(this._api, {this.z2mBaseTopic = 'zigbee2mqtt'});

  final HomeAssistantApi _api;

  /// Zigbee2MQTT `base_topic` (default `zigbee2mqtt`).
  final String z2mBaseTopic;

  static final _topic = RegExp(r'^[A-Za-z0-9_\-/]+$');

  /// Open for [duration] (at most 254 s, the protocol limit); zero closes.
  Future<void> permit(ZigbeeBackend backend, Duration duration) async {
    final seconds = duration.inSeconds.clamp(0, 254);
    switch (backend) {
      case ZigbeeBackend.zha:
        await _api.callService('zha', 'permit', data: {'duration': seconds});
      case ZigbeeBackend.zigbee2mqtt:
        if (!_topic.hasMatch(z2mBaseTopic)) {
          throw ArgumentError.value(z2mBaseTopic, 'z2mBaseTopic');
        }
        // Zigbee2MQTT request "bridge/request/permit_join": `time` in 2.x,
        // `value` + `time` in 1.x; both are sent.
        await _api.callService(
          'mqtt',
          'publish',
          data: {
            'topic': '$z2mBaseTopic/bridge/request/permit_join',
            'payload': jsonEncode({'value': seconds > 0, 'time': seconds}),
          },
        );
    }
  }
}

/// Renames a device and assigns its room in Home Assistant's device
/// registry. This uses the frontend's `config/device_registry/update`
/// WebSocket command (not in the developer docs, admin only), so callers
/// treat failure as "do it in Home Assistant".
class DeviceRegistryEditor {
  DeviceRegistryEditor(this._ws);

  final HaWebSocketManager _ws;

  Future<void> update(String deviceId, {String? name, String? areaId}) =>
      _ws.sendCommand({
        'type': 'config/device_registry/update',
        'device_id': deviceId,
        'name_by_user': ?name,
        'area_id': ?areaId,
      });
}
