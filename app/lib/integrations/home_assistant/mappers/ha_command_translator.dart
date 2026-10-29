import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../features/devices/domain/device_command.dart';
import '../../../features/devices/domain/smart_home_device.dart';
import 'ha_tv_keys.dart';

/// A Home Assistant service call (`POST /api/services/<domain>/<service>`).
@immutable
class HaServiceCall {
  const HaServiceCall(this.domain, this.service, this.data);

  final String domain;
  final String service;
  final Map<String, Object?> data;

  @override
  String toString() => '$domain.$service(${data['entity_id']})';
}

/// Translates protocol-independent [DeviceCommand]s into documented Home
/// Assistant services. Values are clamped to the device's limits and modes
/// are validated against the options the device reports.
class HaCommandTranslator {
  const HaCommandTranslator();

  static const _toggleDomains = {
    'light',
    'switch',
    'input_boolean',
    'fan',
    'automation',
    'media_player',
    'humidifier',
    'climate',
    'siren',
  };

  HaServiceCall translate(SmartHomeDevice device, DeviceCommand command) {
    final entityId = device.sourceId;
    final domain = entityId.substring(0, entityId.indexOf('.'));
    final target = <String, Object?>{'entity_id': entityId};
    HaServiceCall call(
      String service, [
      Map<String, Object?> extra = const {},
    ]) => HaServiceCall(domain, service, {...target, ...extra});
    HaServiceCall unsupported() => throw AppFailure(
      FailureKind.unsupportedFeature,
      debugMessage: '${command.runtimeType} not supported for domain $domain',
    );

    switch (command) {
      case TurnOn():
        return call('turn_on');
      case TurnOff():
        return call('turn_off');
      case Toggle():
        if (_toggleDomains.contains(domain)) return call('toggle');
        return call(device.state.isOn == true ? 'turn_off' : 'turn_on');

      case SetBrightness(:final percent):
        if (domain != 'light') return unsupported();
        return percent == 0
            ? call('turn_off')
            : call('turn_on', {'brightness_pct': percent});
      case SetColorTemperature(:final kelvin):
        if (domain != 'light') return unsupported();
        final min = device.limits.minColorTemperatureKelvin;
        final max = device.limits.maxColorTemperatureKelvin;
        final value = (min != null && max != null)
            ? kelvin.clamp(min, max)
            : kelvin;
        return call('turn_on', {'color_temp_kelvin': value});
      case SetRgbColor(:final color):
        if (domain != 'light') return unsupported();
        int c(int v) => v.clamp(0, 255);
        return call('turn_on', {
          'rgb_color': [c(color.red), c(color.green), c(color.blue)],
        });

      case SetTargetTemperature(:final temperature):
        if (domain != 'climate') return unsupported();
        return call('set_temperature', {
          'temperature': _clampTemperature(device, temperature),
        });
      case SetHvacMode(:final mode):
        if (domain != 'climate') return unsupported();
        _requireOption(mode, device.limits.hvacModes, 'hvac_mode');
        return call('set_hvac_mode', {'hvac_mode': mode});
      case SetFanMode(:final mode):
        if (domain != 'climate') return unsupported();
        _requireOption(mode, device.limits.fanModes, 'fan_mode');
        return call('set_fan_mode', {'fan_mode': mode});
      case SetPresetMode(:final mode):
        _requireOption(mode, device.limits.presetModes, 'preset_mode');
        return switch (domain) {
          'climate' || 'fan' => call('set_preset_mode', {'preset_mode': mode}),
          'humidifier' => call('set_mode', {'mode': mode}),
          _ => unsupported(),
        };

      case SetFanSpeed(:final percent):
        if (domain != 'fan') return unsupported();
        return percent == 0
            ? call('turn_off')
            : call('set_percentage', {'percentage': percent});
      case SetOscillation(:final on):
        if (domain != 'fan') return unsupported();
        return call('oscillate', {'oscillating': on});
      case SetTargetHumidity(:final humidity):
        if (domain != 'humidifier') return unsupported();
        final min = device.limits.minHumidity ?? 0;
        final max = device.limits.maxHumidity ?? 100;
        return call('set_humidity', {
          'humidity': humidity.clamp(min, max).round(),
        });
      case VacuumStart():
        if (domain != 'vacuum') return unsupported();
        return call('start');
      case VacuumPause():
        if (domain != 'vacuum') return unsupported();
        return call('pause');
      case VacuumReturnHome():
        if (domain != 'vacuum') return unsupported();
        return call('return_to_base');
      case SelectOption(:final option):
        if (domain != 'select' && domain != 'input_select') {
          return unsupported();
        }
        _requireOption(option, device.limits.options, 'option');
        return call('select_option', {'option': option});
      case SetNumber(:final value):
        if (domain != 'number' && domain != 'input_number') {
          return unsupported();
        }
        final l = device.limits;
        final step = l.valueStep;
        var v = value.clamp(l.minValue ?? value, l.maxValue ?? value);
        if (step != null && step > 0) {
          final base = l.minValue ?? 0;
          v = base + ((v - base) / step).round() * step;
        }
        return call('set_value', {'value': double.parse(v.toStringAsFixed(6))});
      case SelectSource(:final source):
        if (domain != 'media_player') return unsupported();
        _requireOption(source, device.limits.sources, 'source');
        return call('select_source', {'source': source});
      case MediaPlayPause():
        if (domain != 'media_player') return unsupported();
        return call('media_play_pause');
      case MediaNext():
        if (domain != 'media_player') return unsupported();
        return call('media_next_track');
      case MediaPrevious():
        if (domain != 'media_player') return unsupported();
        return call('media_previous_track');
      case MediaSeek(:final position):
        if (domain != 'media_player') return unsupported();
        return call('media_seek', {
          'seek_position': position.inMilliseconds / 1000,
        });
      case SetShuffle(:final on):
        if (domain != 'media_player') return unsupported();
        return call('shuffle_set', {'shuffle': on});
      case SetRepeat(:final mode):
        if (domain != 'media_player') return unsupported();
        if (!const {'off', 'all', 'one'}.contains(mode)) {
          throw const AppFailure(
            FailureKind.validation,
            debugMessage: 'repeat must be off, all or one',
          );
        }
        return call('repeat_set', {'repeat': mode});
      case SetVolume(:final percent):
        if (domain != 'media_player') return unsupported();
        return call('volume_set', {'volume_level': percent / 100});
      case SetMute(:final muted):
        if (domain != 'media_player') return unsupported();
        return call('volume_mute', {'is_volume_muted': muted});
      case StepVolume(:final up):
        if (domain != 'media_player') return unsupported();
        return call(up ? 'volume_up' : 'volume_down');
      case SelectSoundMode(:final mode):
        if (domain != 'media_player') return unsupported();
        if (!device.limits.soundModes.contains(mode)) {
          throw const AppFailure(
            FailureKind.validation,
            debugMessage: 'unknown sound mode',
          );
        }
        return call('select_sound_mode', {'sound_mode': mode});
      case PressTvKey(:final key):
        final integration = device.metadata.integration;
        final name = haTvKeyNames[integration]?[key];
        if (name == null) return unsupported();
        if (domain == 'remote') return call('send_command', {'command': name});
        if (domain == 'media_player' && integration == 'webostv') {
          return HaServiceCall('webostv', 'button', {
            ...target,
            'button': name,
          });
        }
        return unsupported();

      case OpenCover():
        return switch (domain) {
          'cover' => call('open_cover'),
          'valve' => call('open_valve'),
          'lock' => call('open'),
          _ => unsupported(),
        };
      case CloseCover():
        return switch (domain) {
          'cover' => call('close_cover'),
          'valve' => call('close_valve'),
          _ => unsupported(),
        };
      case StopCover():
        return switch (domain) {
          'cover' => call('stop_cover'),
          'valve' => call('stop_valve'),
          'vacuum' => call('stop'),
          _ => unsupported(),
        };
      case SetCoverPosition(:final percent):
        return switch (domain) {
          'cover' => call('set_cover_position', {'position': percent}),
          'valve' => call('set_valve_position', {'position': percent}),
          _ => unsupported(),
        };

      case LockDevice():
        return domain == 'lock' ? call('lock') : unsupported();
      case UnlockDevice():
        return domain == 'lock' ? call('unlock') : unsupported();
      case ArmAlarm(:final mode, :final code):
        if (domain != 'alarm_control_panel') return unsupported();
        _requireOption(mode, device.limits.alarmArmModes, 'arm mode');
        return call('alarm_arm_$mode', {'code': ?code});
      case DisarmAlarm(:final code):
        if (domain != 'alarm_control_panel') return unsupported();
        return call('alarm_disarm', {'code': ?code});

      case Activate():
        return switch (domain) {
          'scene' || 'script' => call('turn_on'),
          'button' || 'input_button' => call('press'),
          'automation' => call('trigger'),
          _ => unsupported(),
        };
    }
  }

  double _clampTemperature(SmartHomeDevice device, double value) {
    final limits = device.limits;
    final step = limits.temperatureStep ?? 0.5;
    var v = (value / step).round() * step;
    if (limits.minTemperature != null && v < limits.minTemperature!) {
      v = limits.minTemperature!;
    }
    if (limits.maxTemperature != null && v > limits.maxTemperature!) {
      v = limits.maxTemperature!;
    }
    return double.parse(v.toStringAsFixed(2));
  }

  void _requireOption(String value, List<String> allowed, String field) {
    if (allowed.isNotEmpty && !allowed.contains(value)) {
      throw AppFailure(
        FailureKind.validation,
        debugMessage: '$field "$value" not offered by device',
      );
    }
  }
}
