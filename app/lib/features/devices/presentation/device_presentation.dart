import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../domain/capability.dart';
import '../domain/device_kind.dart';
import '../../weather/domain/weather.dart';
import '../../weather/presentation/weather_labels.dart';
import '../domain/smart_home_device.dart';

/// Visual emphasis of a device's current state.
enum DeviceTone {
  /// Off / idle / closed.
  neutral,

  /// On, open, running — positive activity.
  active,

  /// Needs attention (open lock, low battery, jammed).
  warning,

  /// Danger (smoke, CO, water leak, alarm triggered).
  critical,

  /// Unavailable.
  unavailable,
}

/// Icon, tone and localized status text for a device. Pure functions of the
/// device model, so every screen describes devices the same way.
abstract final class DevicePresentation {
  /// [name] without a leading room name, as Home Assistant's own tiles do:
  /// "Dnevna soba – glavno svetlo" in "Dnevna soba" → "Glavno svetlo".
  /// Unchanged when nothing meaningful would remain.
  static String shortName(String name, String? roomName) {
    if (roomName == null || roomName.isEmpty) return name;
    if (!name.toLowerCase().startsWith(roomName.toLowerCase())) return name;
    final rest = name
        .substring(roomName.length)
        .replaceFirst(RegExp(r'^[\s\-–—:,|/]+'), '');
    // "Hodnik" in "Hodnik", or "Kuhinjski…" in "Kuhinja": keep it.
    if (rest.isEmpty || rest.length == name.length - roomName.length) {
      return name;
    }
    return rest[0].toUpperCase() + rest.substring(1);
  }

  static IconData icon(SmartHomeDevice d) {
    final on = d.state.isOn == true;
    final active = d.state.isActive == true;
    return switch (d.kind) {
      DeviceKind.light ||
      DeviceKind.dimmableLight ||
      DeviceKind.rgbLight ||
      DeviceKind.rgbwLight => on ? Icons.lightbulb : Icons.lightbulb_outline,
      DeviceKind.switchDevice =>
        on ? Icons.toggle_on : Icons.toggle_off_outlined,
      DeviceKind.outlet => on ? Icons.power : Icons.power_outlined,
      DeviceKind.temperatureSensor => Icons.thermostat,
      DeviceKind.humiditySensor => Icons.water_drop_outlined,
      DeviceKind.pressureSensor => Icons.speed,
      DeviceKind.airQualitySensor => Icons.air,
      DeviceKind.motionSensor => active ? Icons.directions_run : Icons.sensors,
      DeviceKind.occupancySensor =>
        active ? Icons.person : Icons.person_outline,
      DeviceKind.contactSensor => _contactIcon(d, active),
      DeviceKind.smokeSensor => Icons.local_fire_department_outlined,
      DeviceKind.coSensor => Icons.co2,
      DeviceKind.waterLeakSensor =>
        active ? Icons.water_damage : Icons.water_damage_outlined,
      DeviceKind.vibrationSensor => Icons.vibration,
      DeviceKind.illuminanceSensor => Icons.light_mode_outlined,
      DeviceKind.batterySensor => Icons.battery_std,
      DeviceKind.sensor => Icons.sensors,
      DeviceKind.binarySensor => Icons.radio_button_checked,
      // The icon follows what the unit is doing, not just what it is.
      DeviceKind.thermostat || DeviceKind.climate => switch (d.state.hvacMode) {
        'heat' => Icons.local_fire_department_outlined,
        'cool' => Icons.ac_unit,
        'dry' => Icons.water_drop_outlined,
        'fan_only' => Icons.air,
        'heat_cool' || 'auto' => Icons.thermostat_auto,
        _ => d.kind == DeviceKind.climate ? Icons.ac_unit : Icons.thermostat,
      },
      DeviceKind.lock => switch (d.state.lockState) {
        DoorLockState.unlocked || DoorLockState.open => Icons.lock_open,
        _ => Icons.lock_outline,
      },
      DeviceKind.garageDoor => Icons.garage_outlined,
      DeviceKind.blind || DeviceKind.curtain => Icons.blinds_outlined,
      DeviceKind.camera => Icons.videocam_outlined,
      DeviceKind.doorbell => Icons.doorbell_outlined,
      DeviceKind.mediaPlayer => Icons.play_circle_outline,
      DeviceKind.speaker => Icons.speaker,
      DeviceKind.television => Icons.tv,
      DeviceKind.remote => Icons.settings_remote_outlined,
      DeviceKind.energyMeter => Icons.electric_meter_outlined,
      DeviceKind.powerMeter => Icons.bolt,
      DeviceKind.waterMeter => Icons.water_outlined,
      DeviceKind.gasMeter => Icons.gas_meter_outlined,
      DeviceKind.vacuum => Icons.cleaning_services_outlined,
      DeviceKind.alarm => Icons.shield_outlined,
      DeviceKind.siren => Icons.campaign_outlined,
      DeviceKind.fan || DeviceKind.airPurifier => Icons.mode_fan_off_outlined,
      DeviceKind.humidifier || DeviceKind.dehumidifier => Icons.water_drop,
      DeviceKind.irrigation => Icons.water,
      DeviceKind.button => Icons.radio_button_unchecked,
      DeviceKind.scene => Icons.palette_outlined,
      DeviceKind.script => Icons.description_outlined,
      DeviceKind.automation => Icons.auto_mode,
      DeviceKind.weather => weatherIcon(
        WeatherCondition.fromHomeAssistant(d.state.raw),
      ),
      DeviceKind.person =>
        d.state.isActive == true ? Icons.person : Icons.person_outline,
      DeviceKind.select => Icons.list_alt_outlined,
      DeviceKind.number => Icons.tune,
      DeviceKind.todoList => Icons.checklist,
      DeviceKind.unknown => Icons.device_unknown_outlined,
    };
  }

  static IconData _contactIcon(SmartHomeDevice d, bool open) =>
      switch (d.metadata.haDeviceClass) {
        'window' => open ? Icons.window : Icons.window_outlined,
        'garage_door' => Icons.garage_outlined,
        _ => open ? Icons.door_front_door : Icons.door_front_door_outlined,
      };

  static DeviceTone tone(SmartHomeDevice d) {
    if (!d.available) return DeviceTone.unavailable;
    final s = d.state;
    final active = s.isActive == true;
    switch (d.kind) {
      case DeviceKind.smokeSensor ||
          DeviceKind.coSensor ||
          DeviceKind.waterLeakSensor:
        return active ? DeviceTone.critical : DeviceTone.neutral;
      case DeviceKind.alarm:
        return s.alarmState == AlarmState.triggered
            ? DeviceTone.critical
            : DeviceTone.neutral;
      case DeviceKind.lock:
        return switch (s.lockState) {
          DoorLockState.jammed => DeviceTone.critical,
          DoorLockState.unlocked || DoorLockState.open => DeviceTone.warning,
          _ => DeviceTone.neutral,
        };
      case DeviceKind.contactSensor ||
          DeviceKind.motionSensor ||
          DeviceKind.occupancySensor:
        return active ? DeviceTone.active : DeviceTone.neutral;
      case DeviceKind.blind || DeviceKind.curtain || DeviceKind.garageDoor:
        return s.coverState == CoverState.closed
            ? DeviceTone.neutral
            : DeviceTone.active;
      default:
        if (d.hasLowBattery) return DeviceTone.warning;
        return s.isOn == true ? DeviceTone.active : DeviceTone.neutral;
    }
  }

  /// Colour family of the tile when the device is on.
  /// Colours of [d]'s card when it is on: a light that is on glows in its
  /// own colour (or white temperature); everything else in its accent.
  static AccentSwatch swatch(DeviceAccents accents, SmartHomeDevice d) {
    final light = d.kind.isLight && d.state.isOn == true;
    final rgb = d.state.rgb;
    final kelvin = d.state.colorTemperatureKelvin;
    if (light && rgb != null) {
      return accents.tinted(Color.fromARGB(255, rgb.red, rgb.green, rgb.blue));
    }
    if (light && kelvin != null) return accents.tinted(kelvinColor(kelvin));
    return accents.of(accent(d));
  }

  /// Approximate colour of white light at [kelvin] (Tanner Helland's fit).
  static Color kelvinColor(int kelvin) {
    final t = kelvin.clamp(1000, 40000) / 100;
    int c(double v) => v.round().clamp(0, 255);
    final r = t <= 66 ? 255.0 : 329.698727446 * math.pow(t - 60, -0.1332047592);
    final g = t <= 66
        ? 99.4708025861 * math.log(t) - 161.1195681661
        : 288.1221695283 * math.pow(t - 60, -0.0755148492);
    final b = t >= 66
        ? 255.0
        : t <= 19
        ? 0.0
        : 138.5177312231 * math.log(t - 10) - 305.0447927307;
    return Color.fromARGB(255, c(r), c(g), c(b));
  }

  static DeviceAccent accent(SmartHomeDevice d) => switch (d.kind) {
    DeviceKind.light ||
    DeviceKind.dimmableLight ||
    DeviceKind.rgbLight ||
    DeviceKind.rgbwLight => DeviceAccent.light,
    DeviceKind.thermostat || DeviceKind.climate =>
      d.state.hvacMode == 'heat' || d.state.hvacAction == 'heating'
          ? DeviceAccent.heat
          : DeviceAccent.cool,
    DeviceKind.airPurifier ||
    DeviceKind.humidifier ||
    DeviceKind.dehumidifier => DeviceAccent.cool,
    DeviceKind.mediaPlayer ||
    DeviceKind.speaker ||
    DeviceKind.television => DeviceAccent.media,
    DeviceKind.motionSensor ||
    DeviceKind.occupancySensor ||
    DeviceKind.contactSensor ||
    DeviceKind.blind ||
    DeviceKind.curtain ||
    DeviceKind.garageDoor ||
    DeviceKind.vacuum ||
    DeviceKind.irrigation => DeviceAccent.motion,
    _ => DeviceAccent.power,
  };

  /// One-line status, e.g. "On · 75 %", "22.4 °C", "Locked".
  static String status(AppLocalizations l10n, SmartHomeDevice d) {
    if (!d.available) return l10n.stateUnavailable;
    final s = d.state;
    final locale = l10n.localeName;
    String onOff() => switch (s.isOn) {
      true => l10n.stateOn,
      false => l10n.stateOff,
      null => l10n.stateUnknown,
    };
    String binary(String yes, String no) => switch (s.isActive) {
      true => yes,
      false => no,
      null => l10n.stateUnknown,
    };

    return switch (d.kind) {
      DeviceKind.light ||
      DeviceKind.dimmableLight ||
      DeviceKind.rgbLight ||
      DeviceKind.rgbwLight =>
        s.isOn == true && s.brightnessPercent != null
            ? l10n.stateOnBrightness(s.brightnessPercent!)
            : onOff(),
      DeviceKind.motionSensor => binary(l10n.motionDetected, l10n.motionClear),
      DeviceKind.occupancySensor => binary(
        l10n.occupancyDetected,
        l10n.occupancyClear,
      ),
      DeviceKind.contactSensor => binary(l10n.contactOpen, l10n.contactClosed),
      DeviceKind.smokeSensor => binary(l10n.smokeDetected, l10n.smokeClear),
      DeviceKind.coSensor => binary(l10n.coDetected, l10n.coClear),
      DeviceKind.waterLeakSensor => binary(l10n.leakDetected, l10n.leakClear),
      DeviceKind.vibrationSensor => binary(
        l10n.vibrationDetected,
        l10n.vibrationClear,
      ),
      DeviceKind.binarySensor => binary(l10n.binaryActive, l10n.binaryInactive),
      DeviceKind.thermostat || DeviceKind.climate => _climate(l10n, d),
      DeviceKind.blind ||
      DeviceKind.curtain ||
      DeviceKind.garageDoor => _cover(l10n, s),
      DeviceKind.irrigation => _cover(l10n, s),
      DeviceKind.lock => switch (s.lockState) {
        DoorLockState.locked => l10n.lockLocked,
        DoorLockState.unlocked => l10n.lockUnlocked,
        DoorLockState.locking => l10n.lockLocking,
        DoorLockState.unlocking => l10n.lockUnlocking,
        DoorLockState.jammed => l10n.lockJammed,
        DoorLockState.open || DoorLockState.opening => l10n.contactOpen,
        null => l10n.stateUnknown,
      },
      DeviceKind.alarm => switch (s.alarmState) {
        AlarmState.disarmed => l10n.alarmDisarmed,
        AlarmState.triggered => l10n.alarmTriggered,
        AlarmState.arming => l10n.alarmArming,
        AlarmState.pending => l10n.alarmPending,
        AlarmState.disarming => l10n.alarmDisarmed,
        AlarmState.armedHome => '${l10n.alarmArmed} · ${l10n.alarmArm_home}',
        AlarmState.armedAway => '${l10n.alarmArmed} · ${l10n.alarmArm_away}',
        AlarmState.armedNight => '${l10n.alarmArmed} · ${l10n.alarmArm_night}',
        AlarmState.armedVacation =>
          '${l10n.alarmArmed} · ${l10n.alarmArm_vacation}',
        AlarmState.armedCustomBypass =>
          '${l10n.alarmArmed} · ${l10n.alarmArm_custom_bypass}',
        null => l10n.stateUnknown,
      },
      DeviceKind.camera => switch (s.raw) {
        'streaming' => l10n.cameraStreaming,
        'recording' => l10n.cameraRecording,
        _ => l10n.cameraIdle,
      },
      DeviceKind.mediaPlayer ||
      DeviceKind.speaker ||
      DeviceKind.television => switch (s.raw) {
        'playing' => s.mediaTitle ?? l10n.mediaPlaying,
        'paused' => l10n.mediaPaused,
        _ => onOff(),
      },
      DeviceKind.doorbell =>
        s.lastTriggered == null
            ? l10n.stateUnknown
            : l10n.doorbellLast(formatDateTime(locale, s.lastTriggered!)),
      DeviceKind.scene || DeviceKind.button => l10n.routineReady,
      DeviceKind.script =>
        s.isOn == true ? l10n.scriptRunning : l10n.routineReady,
      DeviceKind.automation => onOff(),
      DeviceKind.weather => weatherConditionLabel(
        l10n,
        WeatherCondition.fromHomeAssistant(s.raw),
      ),
      DeviceKind.select => s.textValue ?? l10n.stateUnknown,
      DeviceKind.number =>
        s.numericValue == null
            ? l10n.stateUnknown
            : formatNumber(
                locale,
                s.numericValue!,
                unit: s.unit == null ? null : ' ${s.unit}',
              ),
      DeviceKind.vacuum => switch (s.raw) {
        'cleaning' => l10n.vacuumCleaning,
        'docked' => l10n.vacuumDocked,
        'returning' => l10n.vacuumReturning,
        'paused' => l10n.vacuumPaused,
        'error' => l10n.vacuumError,
        _ => l10n.vacuumIdle,
      },
      DeviceKind.fan when s.isOn == true && s.percentage != null =>
        '${l10n.stateOn} · ${s.percentage} %',
      DeviceKind.humidifier || DeviceKind.dehumidifier
          when s.isOn == true && s.targetHumidity != null =>
        '${l10n.stateOn} · ${formatNumber(locale, s.targetHumidity!, unit: ' %')}',
      DeviceKind.person => switch (s.textValue) {
        'home' => l10n.personHome,
        'not_home' => l10n.personAway,
        null => l10n.stateUnknown,
        // Any other state is the name of the zone the person is in.
        final zone => zone,
      },
      DeviceKind.todoList => l10n.todoOpenCount(s.numericValue?.toInt() ?? 0),
      DeviceKind.unknown => s.raw,
      _ when d.kind.isSensor => sensorValue(l10n, s),
      _ => onOff(),
    };
  }

  static String _climate(AppLocalizations l10n, SmartHomeDevice d) {
    final s = d.state;
    final mode = hvacModeLabel(l10n, s.hvacMode);
    if (s.hvacMode == 'off' || s.targetTemperature == null) return mode;
    return l10n.climateStatus(
      mode,
      formatNumber(l10n.localeName, s.targetTemperature!, unit: '°'),
    );
  }

  static String _cover(AppLocalizations l10n, DeviceState s) =>
      switch (s.coverState) {
        CoverState.opening => l10n.coverOpening,
        CoverState.closing => l10n.coverClosing,
        CoverState.closed => l10n.contactClosed,
        CoverState.open when s.position != null && s.position! < 100 =>
          l10n.coverOpenPercent(s.position!),
        CoverState.open => l10n.contactOpen,
        null => l10n.stateUnknown,
      };

  static String sensorValue(AppLocalizations l10n, DeviceState s) {
    if (s.numericValue != null) {
      return formatNumber(l10n.localeName, s.numericValue!, unit: s.unit);
    }
    return s.textValue ?? l10n.stateUnknown;
  }

  /// "just now", "5 minutes ago", "3 hours ago", "2 days ago".
  static String relativeTime(AppLocalizations l10n, DateTime t, DateTime now) {
    final d = now.difference(t);
    if (d.inMinutes < 1) return l10n.timeJustNow;
    if (d.inHours < 1) return l10n.timeMinutesAgo(d.inMinutes);
    if (d.inDays < 1) return l10n.timeHoursAgo(d.inHours);
    return l10n.timeDaysAgo(d.inDays);
  }

  /// Standard Home Assistant preset names; custom ones are shown as-is.
  static String presetLabel(AppLocalizations l10n, String preset) =>
      switch (preset) {
        'none' => l10n.presetNone,
        'home' => l10n.presetHome,
        'away' => l10n.presetAway,
        'sleep' => l10n.presetSleep,
        'eco' => l10n.presetEco,
        'comfort' => l10n.presetComfort,
        'boost' => l10n.presetBoost,
        'activity' => l10n.presetActivity,
        _ => preset,
      };

  /// Standard Home Assistant climate fan modes; custom ones as-is.
  static String fanModeLabel(AppLocalizations l10n, String mode) =>
      switch (mode) {
        'on' => l10n.stateOn,
        'off' => l10n.stateOff,
        'auto' => l10n.hvacAuto,
        'low' => l10n.fanLow,
        'medium' => l10n.fanMedium,
        'middle' => l10n.fanMiddle,
        'high' => l10n.fanHigh,
        'top' => l10n.fanTop,
        'focus' => l10n.fanFocus,
        'diffuse' => l10n.fanDiffuse,
        _ => mode,
      };

  static String hvacModeLabel(AppLocalizations l10n, String? mode) =>
      switch (mode) {
        'off' => l10n.hvacOff,
        'heat' => l10n.hvacHeat,
        'cool' => l10n.hvacCool,
        'heat_cool' => l10n.hvacHeatCool,
        'auto' => l10n.hvacAuto,
        'dry' => l10n.hvacDry,
        'fan_only' => l10n.hvacFanOnly,
        null => l10n.stateUnknown,
        // Unknown values come from integrations; show them as reported.
        final other => other,
      };

  static String protocolLabel(AppLocalizations l10n, DeviceProtocol p) =>
      switch (p) {
        DeviceProtocol.zigbee => 'Zigbee',
        DeviceProtocol.zwave => 'Z-Wave',
        DeviceProtocol.matter => 'Matter',
        DeviceProtocol.thread => 'Thread',
        DeviceProtocol.wifi => 'Wi-Fi',
        DeviceProtocol.ethernet => 'Ethernet',
        DeviceProtocol.mqtt => 'MQTT',
        DeviceProtocol.bluetooth => 'Bluetooth',
        DeviceProtocol.esphome => 'ESPHome',
        DeviceProtocol.knx => 'KNX',
        DeviceProtocol.modbus => 'Modbus',
        DeviceProtocol.rf433 => '433 MHz',
        DeviceProtocol.infrared => 'IR',
        DeviceProtocol.cloud => l10n.protocolCloud,
        DeviceProtocol.virtual => l10n.protocolVirtual,
        DeviceProtocol.unknown => l10n.stateUnknown,
      };

  /// Whether the tile offers a one-tap action.
  static bool hasQuickToggle(SmartHomeDevice d) =>
      d.supports(Capability.power) &&
      !d.kind.isRoutine &&
      d.kind != DeviceKind.climate &&
      d.kind != DeviceKind.thermostat;

  static bool hasQuickActivate(SmartHomeDevice d) =>
      d.kind == DeviceKind.scene ||
      d.kind == DeviceKind.script ||
      d.kind == DeviceKind.button;
}

String formatNumber(String locale, double value, {String? unit}) {
  final format = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 1;
  final number = format.format(value);
  if (unit == null || unit.isEmpty) return number;
  // Degree-like units attach directly ("22,4 °C" keeps a space, "23°" not).
  return unit == '°' ? '$number°' : '$number $unit';
}

String formatDateTime(String locale, DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return sameDay
      ? DateFormat.Hm(locale).format(local)
      : DateFormat.yMd(locale).add_Hm().format(local);
}

extension DeviceToneColors on DeviceTone {
  Color color(
    ColorScheme scheme, {
    required Color warning,
    required Color critical,
    required Color unavailable,
  }) => switch (this) {
    DeviceTone.neutral => scheme.onSurfaceVariant,
    DeviceTone.active => scheme.primary,
    DeviceTone.warning => warning,
    DeviceTone.critical => critical,
    DeviceTone.unavailable => unavailable,
  };
}
