import '../../../features/devices/domain/capability.dart';
import '../../../features/devices/domain/device_kind.dart';
import '../../../features/devices/domain/smart_home_device.dart';
import '../models/ha_models.dart';
import '../models/ha_registry.dart';
import 'ha_feature_flags.dart';
import 'ha_protocol_detector.dart';
import 'ha_tv_keys.dart';

/// Battery and signal readings shared by all entities of one physical
/// device (they come from separate diagnostic entities in Home Assistant).
class DeviceAuxiliaryInfo {
  const DeviceAuxiliaryInfo({
    this.batteryPercent,
    this.batteryLow,
    this.signal,
    this.signalUnit,
  });

  final int? batteryPercent;
  final bool? batteryLow;
  final double? signal;
  final String? signalUnit;
}

/// Translates Home Assistant entities into [SmartHomeDevice].
///
/// Decisions use the entity domain, `device_class`, `supported_color_modes`
/// and `supported_features` bit flags — never the entity id text.
class HaDeviceMapper {
  const HaDeviceMapper();

  /// Maps every state; entities that fail to map are skipped via [onError].
  Map<String, SmartHomeDevice> mapAll(
    Iterable<HaEntityState> states,
    HaRegistries registries, {
    void Function(String entityId, Object error)? onError,
  }) {
    final list = states.toList();
    final aux = collectAuxiliaryInfo(list, registries);
    final result = <String, SmartHomeDevice>{};
    for (final state in list) {
      if (registries.entities[state.entityId]?.disabled ?? false) continue;
      try {
        result[state.entityId] = map(state, registries, aux);
      } on Object catch (e) {
        onError?.call(state.entityId, e);
      }
    }
    return result;
  }

  /// Whether [state] feeds [DeviceAuxiliaryInfo] of its device. When such an
  /// entity changes, every entity of that device must be re-mapped.
  bool isAuxiliarySource(HaEntityState state) =>
      _batteryPercent(state) != null ||
      _batteryLow(state) != null ||
      _signal(state) != null;

  Map<String, DeviceAuxiliaryInfo> collectAuxiliaryInfo(
    Iterable<HaEntityState> states,
    HaRegistries registries,
  ) {
    final battery = <String, int>{};
    final batteryLow = <String, bool>{};
    final signal = <String, (double, String?)>{};
    for (final s in states) {
      final deviceId = registries.entities[s.entityId]?.deviceId;
      if (deviceId == null) continue;
      _batteryPercent(s)?.let((v) => battery[deviceId] = v);
      _batteryLow(s)?.let((v) => batteryLow[deviceId] = v);
      _signal(s)?.let((v) => signal[deviceId] = v);
    }
    return {
      for (final id in {...battery.keys, ...batteryLow.keys, ...signal.keys})
        id: DeviceAuxiliaryInfo(
          batteryPercent: battery[id],
          batteryLow: batteryLow[id],
          signal: signal[id]?.$1,
          signalUnit: signal[id]?.$2,
        ),
    };
  }

  SmartHomeDevice map(
    HaEntityState s,
    HaRegistries registries, [
    Map<String, DeviceAuxiliaryInfo> aux = const {},
  ]) {
    final entry = registries.entities[s.entityId];
    final device = entry?.deviceId == null
        ? null
        : registries.devices[entry!.deviceId];
    final a = s.attributes;
    final features = _int(a['supported_features']) ?? 0;
    final deviceClass = _str(a['device_class']);
    final available = s.state != 'unavailable';
    final known = available && s.state != 'unknown';

    final _Mapped m = switch (s.domain) {
      'light' => _light(s, features, known),
      'switch' || 'input_boolean' => _Mapped(
        deviceClass == 'outlet' ? DeviceKind.outlet : DeviceKind.switchDevice,
        {Capability.power},
        DeviceState(raw: s.state, isOn: _onOff(s.state, known)),
      ),
      'sensor' => _sensor(s, deviceClass, known),
      'binary_sensor' => _binarySensor(s, deviceClass, known),
      'climate' => _climate(s, features, known),
      'cover' => _cover(s, deviceClass, features, known),
      'valve' => _valve(s, deviceClass, features, known),
      'lock' => _lock(s, features, known),
      'camera' => _Mapped(DeviceKind.camera, {
        Capability.cameraSnapshot,
        if (features.has(CameraFeature.stream)) Capability.cameraStream,
      }, DeviceState(raw: s.state)),
      'media_player' => _mediaPlayer(
        s,
        deviceClass,
        features,
        known,
        entry?.platform,
      ),
      'remote' => _Mapped(
        DeviceKind.remote,
        {
          Capability.power,
          if (haTvKeyNames.containsKey(entry?.platform)) Capability.tvKeys,
        },
        DeviceState(raw: s.state, isOn: _onOff(s.state, known)),
        DeviceLimits(
          tvKeys: haTvKeyNames[entry?.platform]?.keys.toSet() ?? const {},
        ),
      ),
      'fan' => _Mapped(
        DeviceKind.fan,
        {
          Capability.power,
          if (features.has(FanFeature.presetMode)) Capability.presetMode,
          if (features.has(FanFeature.setSpeed)) Capability.fanSpeed,
          if (features.has(FanFeature.oscillate)) Capability.oscillate,
        },
        DeviceState(
          raw: s.state,
          isOn: _onOff(s.state, known),
          presetMode: _str(a['preset_mode']),
          percentage: _num(a['percentage'])?.round(),
          oscillating: a['oscillating'] is bool
              ? a['oscillating']! as bool
              : null,
        ),
        DeviceLimits(
          presetModes: _strList(a['preset_modes']),
          percentageStep: _num(a['percentage_step']),
        ),
      ),
      'select' || 'input_select' => _Mapped(
        DeviceKind.select,
        {Capability.selectOption},
        DeviceState(raw: s.state, textValue: known ? s.state : null),
        DeviceLimits(options: _strList(a['options'])),
      ),
      'number' || 'input_number' => _Mapped(
        DeviceKind.number,
        {Capability.numberValue},
        DeviceState(
          raw: s.state,
          numericValue: known ? double.tryParse(s.state) : null,
          unit: _str(a['unit_of_measurement']),
        ),
        DeviceLimits(
          minValue: _num(a['min']),
          maxValue: _num(a['max']),
          valueStep: _num(a['step']),
        ),
      ),
      'humidifier' => _humidifier(s, deviceClass, features, known),
      'alarm_control_panel' => _alarm(s, features, known),
      'siren' => _Mapped(DeviceKind.siren, {
        if (features.has(SirenFeature.turnOn) &&
            features.has(SirenFeature.turnOff))
          Capability.power,
      }, DeviceState(raw: s.state, isOn: _onOff(s.state, known))),
      'vacuum' => _Mapped(DeviceKind.vacuum, {
        if (features.has(VacuumFeature.stop)) Capability.stop,
        if (features.has(VacuumFeature.start)) Capability.vacuumStart,
        if (features.has(VacuumFeature.pause)) Capability.vacuumPause,
        if (features.has(VacuumFeature.returnHome)) Capability.vacuumReturnHome,
      }, DeviceState(raw: s.state)),
      'event' when deviceClass == 'doorbell' => _Mapped(
        DeviceKind.doorbell,
        const {},
        DeviceState(
          raw: s.state,
          lastTriggered: known ? DateTime.tryParse(s.state) : null,
        ),
      ),
      'weather' => _Mapped(
        DeviceKind.weather,
        const {},
        DeviceState(
          raw: s.state,
          textValue: known ? s.state : null,
          currentTemperature: _num(a['temperature']),
          unit: _str(a['temperature_unit']),
          currentHumidity: _num(a['humidity']),
          windSpeed: _num(a['wind_speed']),
          windSpeedUnit: _str(a['wind_speed_unit']),
        ),
      ),
      'person' => _Mapped(
        DeviceKind.person,
        const {},
        DeviceState(
          raw: s.state,
          textValue: known ? s.state : null,
          isActive: known ? s.state == 'home' : null,
        ),
      ),
      'button' || 'input_button' => _Mapped(DeviceKind.button, {
        Capability.trigger,
      }, DeviceState(raw: s.state)),
      'scene' => _Mapped(DeviceKind.scene, {
        Capability.trigger,
      }, DeviceState(raw: s.state)),
      'script' => _Mapped(
        DeviceKind.script,
        {Capability.trigger},
        DeviceState(
          raw: s.state,
          isOn: _onOff(s.state, known),
          lastTriggered: _date(a['last_triggered']),
        ),
      ),
      'automation' => _Mapped(
        DeviceKind.automation,
        {Capability.power, Capability.trigger},
        DeviceState(
          raw: s.state,
          isOn: _onOff(s.state, known),
          lastTriggered: _date(a['last_triggered']),
        ),
      ),
      'todo' => _Mapped(
        DeviceKind.todoList,
        const {},
        DeviceState(raw: s.state, numericValue: double.tryParse(s.state)),
        DeviceLimits(todoFeatures: features),
      ),
      _ => _Mapped(DeviceKind.unknown, const {}, DeviceState(raw: s.state)),
    };

    final info = entry?.deviceId == null ? null : aux[entry!.deviceId];
    return SmartHomeDevice(
      id: s.entityId,
      sourceId: s.entityId,
      deviceId: entry?.deviceId,
      name: s.friendlyName,
      roomId: entry?.areaId ?? device?.areaId,
      kind: m.kind,
      protocol: detectProtocol(s.domain, entry, device),
      manufacturer: device?.manufacturer,
      model: device?.model,
      available: available,
      capabilities: Set.unmodifiable({
        ...m.capabilities,
        if (info?.batteryPercent != null || info?.batteryLow != null)
          Capability.battery,
      }),
      state: m.state,
      limits: m.limits,
      metadata: DeviceMetadata(
        batteryPercent: info?.batteryPercent,
        batteryLow: info?.batteryLow,
        signalStrength: info?.signal,
        signalUnit: info?.signalUnit,
        haDeviceClass: deviceClass,
        lastChanged: s.lastChanged,
        lastUpdated: s.lastUpdated,
        picturePath: localPicturePath(a['entity_picture']),
        configId: s.domain == 'automation' || s.domain == 'scene'
            ? _str(a['id'])
            : null,
        integration: entry?.platform,
      ),
      isAuxiliary:
          (entry?.hidden ?? false) ||
          entry?.entityCategory != null ||
          // The app's own device-timer scripts are plumbing, not routines.
          s.entityId.startsWith('script.osh_timer_') ||
          // A TV's remote is shown on the TV itself.
          s.domain == 'remote',
    );
  }

  // ---------------------------------------------------------------------------

  _Mapped _light(HaEntityState s, int features, bool known) {
    final a = s.attributes;
    final modes = _strList(a['supported_color_modes']).toSet();
    // Lights without color-mode information (very old integrations):
    // infer brightness support from the attribute being present.
    final legacyBrightness = a['brightness'];
    final legacyDimmable =
        modes.isEmpty &&
        a.containsKey('brightness') &&
        (legacyBrightness == null || legacyBrightness is num);
    final colorModes = modes.intersection(const {
      'hs',
      'xy',
      'rgb',
      'rgbw',
      'rgbww',
    });
    final dimmable =
        legacyDimmable || modes.any((m) => m != 'onoff' && m != 'unknown');
    final rgbw = modes.contains('rgbw') || modes.contains('rgbww');

    final kind = rgbw
        ? DeviceKind.rgbwLight
        : colorModes.isNotEmpty
        ? DeviceKind.rgbLight
        : dimmable
        ? DeviceKind.dimmableLight
        : DeviceKind.light;

    final brightness = _num(a['brightness']);
    final rgb = _strOrNumList(a['rgb_color']);
    return _Mapped(
      kind,
      {
        Capability.power,
        if (dimmable) Capability.brightness,
        if (modes.contains('color_temp')) Capability.colorTemperature,
        if (colorModes.isNotEmpty) Capability.rgb,
        if (rgbw) Capability.rgbw,
        if (modes.contains('hs')) Capability.hsColor,
        if (modes.contains('xy')) Capability.xyColor,
        if (features.has(LightFeature.transition)) Capability.transition,
      },
      DeviceState(
        raw: s.state,
        isOn: _onOff(s.state, known),
        brightnessPercent: brightness == null
            ? null
            : (brightness / 255 * 100).round().clamp(0, 100),
        colorTemperatureKelvin: _int(a['color_temp_kelvin']),
        rgb: rgb != null && rgb.length >= 3
            ? RgbColor(rgb[0], rgb[1], rgb[2])
            : null,
      ),
      DeviceLimits(
        minColorTemperatureKelvin: _int(a['min_color_temp_kelvin']),
        maxColorTemperatureKelvin: _int(a['max_color_temp_kelvin']),
      ),
    );
  }

  static const _airQualityClasses = {
    'aqi',
    'pm1',
    'pm25',
    'pm10',
    'carbon_dioxide',
    'carbon_monoxide',
    'volatile_organic_compounds',
    'volatile_organic_compounds_parts',
    'nitrogen_dioxide',
    'nitrogen_monoxide',
    'ozone',
    'sulphur_dioxide',
  };

  _Mapped _sensor(HaEntityState s, String? deviceClass, bool known) {
    final value = known ? double.tryParse(s.state) : null;
    final unit = _str(s.attributes['unit_of_measurement']);
    final (DeviceKind kind, Capability? cap) = switch (deviceClass) {
      'temperature' => (
        DeviceKind.temperatureSensor,
        Capability.currentTemperature,
      ),
      'humidity' => (DeviceKind.humiditySensor, Capability.humidity),
      'pressure' || 'atmospheric_pressure' => (DeviceKind.pressureSensor, null),
      'illuminance' => (DeviceKind.illuminanceSensor, null),
      'battery' => (DeviceKind.batterySensor, Capability.battery),
      'power' => (DeviceKind.powerMeter, Capability.powerConsumption),
      'energy' => (DeviceKind.energyMeter, Capability.energyConsumption),
      'voltage' => (DeviceKind.sensor, Capability.voltage),
      'current' => (DeviceKind.sensor, Capability.current),
      'frequency' => (DeviceKind.sensor, Capability.frequency),
      'water' => (DeviceKind.waterMeter, null),
      'gas' => (DeviceKind.gasMeter, null),
      final c? when _airQualityClasses.contains(c) => (
        DeviceKind.airQualitySensor,
        null,
      ),
      _ => (DeviceKind.sensor, null),
    };
    return _Mapped(
      kind,
      {?cap},
      DeviceState(
        raw: s.state,
        numericValue: value,
        textValue: known && value == null ? s.state : null,
        unit: unit,
        currentTemperature: kind == DeviceKind.temperatureSensor ? value : null,
        currentHumidity: kind == DeviceKind.humiditySensor ? value : null,
      ),
    );
  }

  _Mapped _binarySensor(HaEntityState s, String? deviceClass, bool known) {
    final kind = switch (deviceClass) {
      'motion' || 'moving' => DeviceKind.motionSensor,
      'occupancy' || 'presence' => DeviceKind.occupancySensor,
      'door' ||
      'window' ||
      'garage_door' ||
      'opening' => DeviceKind.contactSensor,
      'smoke' => DeviceKind.smokeSensor,
      'carbon_monoxide' => DeviceKind.coSensor,
      'moisture' => DeviceKind.waterLeakSensor,
      'vibration' => DeviceKind.vibrationSensor,
      _ => DeviceKind.binarySensor,
    };
    return _Mapped(
      kind,
      const {},
      DeviceState(raw: s.state, isActive: _onOff(s.state, known)),
    );
  }

  _Mapped _climate(HaEntityState s, int features, bool known) {
    final a = s.attributes;
    final modes = _strList(a['hvac_modes']);
    final cools = modes.any(
      const {'cool', 'heat_cool', 'dry', 'fan_only'}.contains,
    );
    final heats = modes.any(const {'heat', 'heat_cool', 'auto'}.contains);
    return _Mapped(
      cools ? DeviceKind.climate : DeviceKind.thermostat,
      {
        if (a.containsKey('current_temperature')) Capability.currentTemperature,
        if (features.has(ClimateFeature.targetTemperature))
          Capability.targetTemperature,
        if (features.has(ClimateFeature.targetTemperatureRange))
          Capability.targetTemperatureRange,
        if (features.has(ClimateFeature.targetHumidity))
          Capability.targetHumidity,
        if (a.containsKey('current_humidity')) Capability.humidity,
        if (features.has(ClimateFeature.fanMode)) Capability.fanMode,
        if (features.has(ClimateFeature.swingMode)) Capability.swingMode,
        if (features.has(ClimateFeature.presetMode)) Capability.presetMode,
        if (features.has(ClimateFeature.turnOn) &&
            features.has(ClimateFeature.turnOff))
          Capability.power,
        if (modes.isNotEmpty) Capability.hvacMode,
        if (heats) Capability.heating,
        if (cools) Capability.cooling,
      },
      DeviceState(
        raw: s.state,
        isOn: known ? s.state != 'off' : null,
        hvacMode: known ? s.state : null,
        hvacAction: _str(a['hvac_action']),
        currentTemperature: _num(a['current_temperature']),
        targetTemperature: _num(a['temperature']),
        targetTemperatureLow: _num(a['target_temp_low']),
        targetTemperatureHigh: _num(a['target_temp_high']),
        currentHumidity: _num(a['current_humidity']),
        targetHumidity: _num(a['humidity']),
        fanMode: _str(a['fan_mode']),
        swingMode: _str(a['swing_mode']),
        presetMode: _str(a['preset_mode']),
      ),
      DeviceLimits(
        minTemperature: _num(a['min_temp']),
        maxTemperature: _num(a['max_temp']),
        temperatureStep: _num(a['target_temp_step']),
        minHumidity: _num(a['min_humidity']),
        maxHumidity: _num(a['max_humidity']),
        hvacModes: modes,
        fanModes: _strList(a['fan_modes']),
        swingModes: _strList(a['swing_modes']),
        presetModes: _strList(a['preset_modes']),
      ),
    );
  }

  _Mapped _cover(
    HaEntityState s,
    String? deviceClass,
    int features,
    bool known,
  ) {
    final kind = switch (deviceClass) {
      'curtain' => DeviceKind.curtain,
      'garage' || 'gate' => DeviceKind.garageDoor,
      _ => DeviceKind.blind,
    };
    final a = s.attributes;
    return _Mapped(
      kind,
      {
        if (features.has(CoverFeature.open)) Capability.open,
        if (features.has(CoverFeature.close)) Capability.close,
        if (features.has(CoverFeature.stop)) Capability.stop,
        if (features.has(CoverFeature.setPosition)) Capability.position,
        if (features.hasAny(
          CoverFeature.openTilt |
              CoverFeature.closeTilt |
              CoverFeature.setTiltPosition,
        ))
          Capability.tilt,
      },
      DeviceState(
        raw: s.state,
        coverState: known ? _enumByName(CoverState.values, s.state) : null,
        position: _int(a['current_position']),
        tiltPosition: _int(a['current_tilt_position']),
      ),
    );
  }

  _Mapped _valve(
    HaEntityState s,
    String? deviceClass,
    int features,
    bool known,
  ) => _Mapped(
    deviceClass == 'water' ? DeviceKind.irrigation : DeviceKind.unknown,
    {
      if (features.has(ValveFeature.open)) Capability.open,
      if (features.has(ValveFeature.close)) Capability.close,
      if (features.has(ValveFeature.stop)) Capability.stop,
      if (features.has(ValveFeature.setPosition)) Capability.position,
    },
    DeviceState(
      raw: s.state,
      coverState: known ? _enumByName(CoverState.values, s.state) : null,
      position: _int(s.attributes['current_position']),
    ),
  );

  _Mapped _lock(HaEntityState s, int features, bool known) => _Mapped(
    DeviceKind.lock,
    {
      Capability.lock,
      Capability.unlock,
      if (features.has(LockFeature.open)) Capability.open,
    },
    DeviceState(
      raw: s.state,
      lockState: known ? _enumByName(DoorLockState.values, s.state) : null,
    ),
  );

  _Mapped _mediaPlayer(
    HaEntityState s,
    String? deviceClass,
    int features,
    bool known,
    String? platform,
  ) {
    final a = s.attributes;
    final volume = _num(a['volume_level']);
    // LG takes remote keys on the media player itself (webostv.button).
    final keys = platform == 'webostv'
        ? haTvKeyNames['webostv']!.keys.toSet()
        : const <TvKey>{};
    return _Mapped(
      switch (deviceClass) {
        'tv' => DeviceKind.television,
        'speaker' || 'receiver' => DeviceKind.speaker,
        _ => DeviceKind.mediaPlayer,
      },
      {
        // Some TVs only turn off (turning on needs Wake-on-LAN or an
        // automation): the power switch is still useful.
        if (features.has(MediaPlayerFeature.turnOn) ||
            features.has(MediaPlayerFeature.turnOff))
          Capability.power,
        if (features.has(MediaPlayerFeature.play)) Capability.mediaPlay,
        if (features.has(MediaPlayerFeature.pause)) Capability.mediaPause,
        if (features.has(MediaPlayerFeature.stop)) Capability.mediaStop,
        if (features.has(MediaPlayerFeature.nextTrack)) Capability.mediaNext,
        if (features.has(MediaPlayerFeature.previousTrack))
          Capability.mediaPrevious,
        if (features.has(MediaPlayerFeature.volumeSet)) Capability.volume,
        if (features.has(MediaPlayerFeature.volumeMute)) Capability.mute,
        if (features.has(MediaPlayerFeature.volumeStep)) Capability.volumeStep,
        if (features.has(MediaPlayerFeature.selectSoundMode))
          Capability.soundMode,
        if (keys.isNotEmpty) Capability.tvKeys,
        if (features.has(MediaPlayerFeature.selectSource))
          Capability.sourceSelection,
        if (features.has(MediaPlayerFeature.seek)) Capability.mediaSeek,
        if (features.has(MediaPlayerFeature.shuffleSet)) Capability.shuffle,
        if (features.has(MediaPlayerFeature.repeatSet)) Capability.repeat,
      },
      DeviceState(
        raw: s.state,
        isOn: known ? s.state != 'off' && s.state != 'standby' : null,
        volumePercent: volume == null
            ? null
            : (volume * 100).round().clamp(0, 100),
        isMuted: a['is_volume_muted'] is bool
            ? a['is_volume_muted']! as bool
            : null,
        source: _str(a['source']),
        mediaTitle: _str(a['media_title']),
        mediaArtist:
            _str(a['media_artist']) ??
            _str(a['media_album_name']) ??
            _str(a['media_channel']) ??
            _str(a['app_name']),
        mediaAlbum: _str(a['media_album_name']),
        mediaDuration: _seconds(a['media_duration']),
        mediaPosition: _seconds(a['media_position']),
        mediaPositionUpdatedAt: _date(a['media_position_updated_at']),
        shuffle: a['shuffle'] is bool ? a['shuffle']! as bool : null,
        repeat: _str(a['repeat']),
        soundMode: _str(a['sound_mode']),
      ),
      DeviceLimits(
        sources: _strList(a['source_list']),
        soundModes: _strList(a['sound_mode_list']),
        tvKeys: keys,
      ),
    );
  }

  _Mapped _humidifier(
    HaEntityState s,
    String? deviceClass,
    int features,
    bool known,
  ) {
    final a = s.attributes;
    return _Mapped(
      deviceClass == 'dehumidifier'
          ? DeviceKind.dehumidifier
          : DeviceKind.humidifier,
      {
        Capability.power,
        Capability.targetHumidity,
        if (a.containsKey('current_humidity')) Capability.humidity,
        if (features.has(HumidifierFeature.modes)) Capability.presetMode,
      },
      DeviceState(
        raw: s.state,
        isOn: _onOff(s.state, known),
        targetHumidity: _num(a['humidity']),
        currentHumidity: _num(a['current_humidity']),
        presetMode: _str(a['mode']),
      ),
      DeviceLimits(
        minHumidity: _num(a['min_humidity']),
        maxHumidity: _num(a['max_humidity']),
        presetModes: _strList(a['available_modes']),
      ),
    );
  }

  _Mapped _alarm(HaEntityState s, int features, bool known) => _Mapped(
    DeviceKind.alarm,
    {
      Capability.disarm,
      if (features.hasAny(
        AlarmFeature.armHome |
            AlarmFeature.armAway |
            AlarmFeature.armNight |
            AlarmFeature.armCustomBypass |
            AlarmFeature.armVacation,
      ))
        Capability.arm,
      if (features.has(AlarmFeature.trigger)) Capability.trigger,
    },
    DeviceState(
      raw: s.state,
      alarmState: known
          ? _enumByName(AlarmState.values, _snakeToCamel(s.state))
          : null,
    ),
    DeviceLimits(
      alarmArmModes: [
        if (features.has(AlarmFeature.armHome)) 'home',
        if (features.has(AlarmFeature.armAway)) 'away',
        if (features.has(AlarmFeature.armNight)) 'night',
        if (features.has(AlarmFeature.armVacation)) 'vacation',
        if (features.has(AlarmFeature.armCustomBypass)) 'custom_bypass',
      ],
      alarmCodeFormat: _str(s.attributes['code_format']),
      alarmCodeArmRequired: s.attributes['code_arm_required'] == true,
    ),
  );

  // ---------------------------------------------------------------------------
  // Auxiliary readings

  int? _batteryPercent(HaEntityState s) {
    if (s.domain != 'sensor' || s.attributes['device_class'] != 'battery') {
      return null;
    }
    return double.tryParse(s.state)?.round().clamp(0, 100);
  }

  bool? _batteryLow(HaEntityState s) {
    if (s.domain != 'binary_sensor' ||
        s.attributes['device_class'] != 'battery') {
      return null;
    }
    return _onOff(s.state, true);
  }

  (double, String?)? _signal(HaEntityState s) {
    if (s.domain != 'sensor') return null;
    final unit = _str(s.attributes['unit_of_measurement']);
    // Zigbee2MQTT link quality has no device class but a dedicated unit.
    if (s.attributes['device_class'] != 'signal_strength' && unit != 'lqi') {
      return null;
    }
    final value = double.tryParse(s.state);
    return value == null ? null : (value, unit);
  }
}

class _Mapped {
  const _Mapped(
    this.kind,
    this.capabilities,
    this.state, [
    this.limits = DeviceLimits.none,
  ]);

  final DeviceKind kind;
  final Set<Capability> capabilities;
  final DeviceState state;
  final DeviceLimits limits;
}

bool? _onOff(String state, bool known) => !known
    ? null
    : switch (state) {
        'on' => true,
        'off' => false,
        _ => null,
      };

double? _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

int? _int(Object? v) => _num(v)?.round();

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<String> _strList(Object? v) =>
    v is List ? List.unmodifiable(v.whereType<String>()) : const [];

List<int>? _strOrNumList(Object? v) => v is List && v.every((e) => e is num)
    ? [for (final e in v) (e as num).round()]
    : null;

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

String _snakeToCamel(String s) =>
    s.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m[1]!.toUpperCase());

extension<T extends Object> on T {
  void let(void Function(T value) action) => action(this);
}

/// Keeps only server-relative API paths such as `/api/image/serve/…`.
String? localPicturePath(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (!value.startsWith('/api/') || value.contains('..')) return null;
  // Some pictures (media players, cameras) carry a short-lived
  // `token` parameter; the app authenticates with its header instead.
  if (!uri.queryParameters.containsKey('token')) return value;
  final rest = Map.of(uri.queryParameters)..remove('token');
  return Uri(
    path: uri.path,
    queryParameters: rest.isEmpty ? null : rest,
  ).toString();
}

/// Seconds (int or float) as a [Duration]; `null` when missing or negative.
Duration? _seconds(Object? value) => value is num && value >= 0
    ? Duration(milliseconds: (value * 1000).round())
    : null;
