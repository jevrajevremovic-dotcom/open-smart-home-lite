import '../../core/logging/app_logger.dart';
import '../../features/devices/data/home_state_repository.dart';
import '../../features/devices/domain/device_command.dart';
import '../../features/devices/domain/home_backend.dart';
import '../../features/devices/domain/smart_home_device.dart';
import 'api/home_assistant_api.dart';
import 'mappers/ha_command_translator.dart';

/// Commands as Home Assistant service calls.
class HaCommandSink implements DeviceCommandSink {
  HaCommandSink(this._api, {this._translator = const HaCommandTranslator()});

  final HomeAssistantApi _api;
  final HaCommandTranslator _translator;
  static final _log = AppLogger('DeviceCommand');

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async {
    final call = _translator.translate(device, command);
    _log.info('→ $call'); // entity id and service only; never the payload
    await _api.callService(call.domain, call.service, data: call.data);
  }

  /// Calls that differ only in the entity are merged into one call with a
  /// list of entities (`light.turn_off` for all lights at once).
  @override
  Future<void> sendToAll(
    List<SmartHomeDevice> devices,
    DeviceCommand command,
  ) async {
    final merged = <String, List<String>>{};
    final single = <HaServiceCall>[];
    for (final device in devices) {
      final call = _translator.translate(device, command);
      if (call.data.length == 1 && call.data['entity_id'] is String) {
        merged
            .putIfAbsent('${call.domain}.${call.service}', () => [])
            .add(call.data['entity_id']! as String);
      } else {
        single.add(call);
      }
    }
    for (final MapEntry(:key, value: ids) in merged.entries) {
      final [domain, service] = key.split('.');
      _log.info('→ $key (${ids.length})');
      await _api.callService(domain, service, data: {'entity_id': ids});
    }
    for (final call in single) {
      _log.info('→ $call');
      await _api.callService(call.domain, call.service, data: call.data);
    }
  }
}

/// A Home Assistant server: state over WebSocket, commands over REST.
class HaBackend implements HomeBackend {
  HaBackend(this._repository, this._commands);

  final HomeStateRepository _repository;
  final DeviceCommandSink _commands;

  @override
  HomeSnapshot get current => _repository.current;

  @override
  Stream<HomeSnapshot> get snapshots => _repository.snapshots;

  @override
  void start() => _repository.start();

  @override
  Future<void> flush() => _repository.flush();

  @override
  Future<void> dispose() => _repository.dispose();

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) =>
      _commands.send(device, command);

  @override
  Future<void> sendToAll(
    List<SmartHomeDevice> devices,
    DeviceCommand command,
  ) => _commands.sendToAll(devices, command);
}
