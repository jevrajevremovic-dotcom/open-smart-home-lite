import '../../../features/devices/domain/device_kind.dart';
import '../models/ha_registry.dart';

/// Helper domains that never represent physical hardware.
const _virtualDomains = {
  'automation',
  'scene',
  'script',
  'input_boolean',
  'input_button',
  'input_number',
  'input_select',
  'input_text',
  'input_datetime',
  'timer',
  'counter',
  'zone',
  'person',
  'sun',
};

/// Integration (entity registry `platform`) → transport. Only integrations
/// whose transport is unambiguous are listed; everything else is `unknown`.
const _platformProtocol = <String, DeviceProtocol>{
  'zha': DeviceProtocol.zigbee,
  'deconz': DeviceProtocol.zigbee,
  'hue': DeviceProtocol.zigbee,
  'tradfri': DeviceProtocol.zigbee,
  'zwave_js': DeviceProtocol.zwave,
  'matter': DeviceProtocol.matter,
  'thread': DeviceProtocol.thread,
  'otbr': DeviceProtocol.thread,
  'esphome': DeviceProtocol.esphome,
  'tasmota': DeviceProtocol.mqtt,
  'shelly': DeviceProtocol.wifi,
  'wled': DeviceProtocol.wifi,
  'xiaomi_miio': DeviceProtocol.wifi,
  'tplink': DeviceProtocol.wifi,
  'yeelight': DeviceProtocol.wifi,
  'bluetooth': DeviceProtocol.bluetooth,
  'bthome': DeviceProtocol.bluetooth,
  'xiaomi_ble': DeviceProtocol.bluetooth,
  'switchbot': DeviceProtocol.bluetooth,
  'knx': DeviceProtocol.knx,
  'modbus': DeviceProtocol.modbus,
  'rfxtrx': DeviceProtocol.rf433,
  'broadlink': DeviceProtocol.infrared,
  'onvif': DeviceProtocol.ethernet,
  'tuya': DeviceProtocol.cloud,
  'smartthings': DeviceProtocol.cloud,
  'template': DeviceProtocol.virtual,
  'group': DeviceProtocol.virtual,
  'demo': DeviceProtocol.virtual,
};

/// Best-effort transport of an entity. Informational only (badges,
/// diagnostics); never used to decide how to control a device.
DeviceProtocol detectProtocol(
  String domain,
  HaEntityEntry? entity,
  HaDeviceEntry? device,
) {
  if (_virtualDomains.contains(domain)) return DeviceProtocol.virtual;
  final platform = entity?.platform;
  if (platform == 'mqtt') {
    // Zigbee2MQTT devices are published with identifiers `zigbee2mqtt_<ieee>`.
    final z2m =
        device?.identifiers.any((i) => i.$2.startsWith('zigbee2mqtt_')) ??
        false;
    return z2m ? DeviceProtocol.zigbee : DeviceProtocol.mqtt;
  }
  return _platformProtocol[platform] ?? DeviceProtocol.unknown;
}
