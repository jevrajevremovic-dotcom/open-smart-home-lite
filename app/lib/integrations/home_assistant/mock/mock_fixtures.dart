/// Mock entities in Home Assistant's wire format (`GET /api/states`).
///
/// Attribute names and `supported_features` bit values follow Home
/// Assistant's entity documentation so the mappers built later see realistic
/// input. Used only when mock mode is enabled in a non-release build.
List<Map<String, Object?>> buildMockStates(DateTime now) {
  final ts = now.toUtc().toIso8601String();
  String ago(Duration d) => now.subtract(d).toUtc().toIso8601String();
  Map<String, Object?> e(String id, String state, Map<String, Object?> attrs) =>
      {
        'entity_id': id,
        'state': state,
        'attributes': attrs,
        'last_changed': ts,
        'last_updated': ts,
      };

  return [
    e('light.hallway', 'off', {
      'friendly_name': 'Hodnik',
      'supported_color_modes': ['onoff'],
      'color_mode': null,
      'supported_features': 0,
    }),
    e('light.living_room_main', 'on', {
      'friendly_name': 'Dnevna soba – glavno svetlo',
      'supported_color_modes': ['color_temp'],
      'color_mode': 'color_temp',
      'brightness': 191,
      'color_temp_kelvin': 3200,
      'min_color_temp_kelvin': 2200,
      'max_color_temp_kelvin': 6500,
      'supported_features': 32, // TRANSITION
    }),
    e('light.living_room_ambient', 'on', {
      'friendly_name': 'Dnevna soba – ambijent',
      'supported_color_modes': ['rgb'],
      'color_mode': 'rgb',
      'brightness': 128,
      'rgb_color': [255, 140, 40],
      'supported_features': 44, // EFFECT | FLASH | TRANSITION
    }),
    e('switch.coffee_machine', 'off', {'friendly_name': 'Aparat za kafu'}),
    e('switch.washer_plug', 'on', {
      'friendly_name': 'Veš mašina utičnica',
      'device_class': 'outlet',
    }),
    e('sensor.washer_plug_power', '420', {
      'friendly_name': 'Veš mašina snaga',
      'device_class': 'power',
      'state_class': 'measurement',
      'unit_of_measurement': 'W',
    }),
    e('switch.tv_outlet', 'on', {
      'friendly_name': 'Utičnica TV',
      'device_class': 'outlet',
    }),
    e('sensor.living_room_temperature', '22.4', {
      'friendly_name': 'Temperatura dnevna soba',
      'device_class': 'temperature',
      'state_class': 'measurement',
      'unit_of_measurement': '°C',
    }),
    e('sensor.living_room_humidity', '48', {
      'friendly_name': 'Vlažnost dnevna soba',
      'device_class': 'humidity',
      'state_class': 'measurement',
      'unit_of_measurement': '%',
    }),
    e('binary_sensor.hallway_motion', 'off', {
      'friendly_name': 'Pokret hodnik',
      'device_class': 'motion',
    }),
    e('binary_sensor.front_door', 'off', {
      'friendly_name': 'Ulazna vrata',
      'device_class': 'door',
    }),
    e('climate.living_room', 'heat', {
      'friendly_name': 'Klima dnevna soba',
      'hvac_modes': ['off', 'heat', 'cool', 'auto'],
      'current_temperature': 22.4,
      'temperature': 23.0,
      'min_temp': 16.0,
      'max_temp': 30.0,
      'target_temp_step': 0.5,
      'fan_modes': ['auto', 'low', 'high'],
      'fan_mode': 'auto',
      'preset_modes': ['none', 'home', 'sleep', 'away', 'eco'],
      'preset_mode': 'home',
      'hvac_action': 'heating',
      'supported_features': 409, // TARGET_TEMPERATURE | PRESET_MODE | FAN_MODE | TURN_OFF | TURN_ON
    }),
    e('cover.living_room_blinds', 'open', {
      'friendly_name': 'Roletne dnevna soba',
      'device_class': 'blind',
      'current_position': 100,
      'supported_features': 15, // OPEN | CLOSE | SET_POSITION | STOP
    }),
    e('fan.bedroom_fan', 'off', {
      'friendly_name': 'Ventilator spavaća soba',
      'percentage': 0,
      'percentage_step': 33.333333333333336,
      'oscillating': false,
      'supported_features': 1 | 2 | 16 | 32, // SPEED | OSCILLATE | OFF | ON
    }),
    e('vacuum.robot', 'docked', {
      'friendly_name': 'Robot usisivač',
      'battery_level': 100,
      // PAUSE | STOP | RETURN_HOME | START
      'supported_features': 4 | 8 | 16 | 8192,
    }),
    e('humidifier.bedroom', 'on', {
      'friendly_name': 'Ovlaživač',
      'humidity': 50,
      'current_humidity': 42,
      'min_humidity': 30,
      'max_humidity': 80,
      'mode': 'normal',
      'available_modes': ['normal', 'eco', 'sleep'],
      'supported_features': 1,
    }),
    e('input_select.house_mode', 'Kod kuće', {
      'friendly_name': 'Režim kuće',
      'options': ['Kod kuće', 'Odsutni', 'Noć'],
    }),
    e('input_number.night_temperature', '19.0', {
      'friendly_name': 'Noćna temperatura',
      'min': 15.0,
      'max': 25.0,
      'step': 0.5,
      'unit_of_measurement': '°C',
      'mode': 'slider',
    }),
    e('alarm_control_panel.home_alarm', 'disarmed', {
      'friendly_name': 'Alarm',
      'code_format': 'number',
      'code_arm_required': false,
      'supported_features': 1 | 2 | 4, // ARM_HOME | ARM_AWAY | ARM_NIGHT
    }),
    e('lock.front_door', 'locked', {
      'friendly_name': 'Brava ulazna vrata',
      'supported_features': 0,
    }),
    e('media_player.living_room_speaker', 'playing', {
      'friendly_name': 'Zvučnik dnevna soba',
      'device_class': 'speaker',
      'media_title': 'Kafa i kiša',
      'media_artist': 'Demo bend',
      'volume_level': 0.35,
      'is_volume_muted': false,
      'source': 'Radio',
      'source_list': ['Radio', 'Bluetooth', 'AirPlay'],
      'media_album_name': 'Jesenje jutro',
      // As Home Assistant serves artwork: through its own proxy.
      'entity_picture': '/api/media_player_proxy/media_player.living_room_speaker?token=demo&cache=1',
      'media_duration': 215,
      'media_position': 62,
      'media_position_updated_at': ts,
      'shuffle': false,
      'repeat': 'off',
      // PAUSE | SEEK | VOLUME_SET | PREVIOUS | NEXT | TURN_ON | TURN_OFF |
      // SELECT_SOURCE | STOP | PLAY | SHUFFLE_SET | REPEAT_SET
      'supported_features': 22965 | 2 | 32768 | 262144,
    }),
    e('media_player.living_room_tv', 'off', {
      'friendly_name': 'Televizor',
      'device_class': 'tv',
      'source_list': ['TV', 'HDMI 1', 'HDMI 2'],
      'sound_mode_list': ['Standard', 'Film', 'Muzika'],
      'sound_mode': 'Standard',
      'is_volume_muted': false,
      // PAUSE | VOLUME_SET | VOLUME_MUTE | TURN_ON | TURN_OFF |
      // SELECT_SOURCE | PLAY | SELECT_SOUND_MODE
      'supported_features': 84365,
    }),
    // Its remote (Android TV Remote integration).
    e('remote.living_room_tv', 'on', {'friendly_name': 'Televizor'}),
    e('camera.front_yard', 'idle', {
      'friendly_name': 'Kamera dvorište',
      'supported_features': 0,
    }),
    e('camera.driveway', 'streaming', {
      'friendly_name': 'Kamera prilaz',
      'supported_features': 2, // STREAM
    }),
    e('camera.backyard', 'idle', {
      'friendly_name': 'Kamera bašta',
      'supported_features': 0,
    }),
    e('sensor.house_power', '742', {
      'friendly_name': 'Trenutna snaga',
      'device_class': 'power',
      'state_class': 'measurement',
      'unit_of_measurement': 'W',
    }),
    e('sensor.house_energy', '15234.7', {
      'friendly_name': 'Ukupna potrošnja',
      'device_class': 'energy',
      'state_class': 'total_increasing',
      'unit_of_measurement': 'kWh',
    }),
    e('scene.movie_night', 'unknown', {
      'friendly_name': 'Filmsko veče',
      'id': 'movie_night',
      'entity_id': ['light.living_room_ambient', 'light.living_room_main'],
    }),
    e('automation.hallway_night_light', 'on', {
      'friendly_name': 'Noćno svetlo u hodniku',
      'last_triggered': null,
      'id': '1700000000000',
    }),
    e('switch.garage_heater', 'unavailable', {
      'friendly_name': 'Grejalica garaža',
      'restored': true,
    }),
    e('sun.sun', 'above_horizon', {'friendly_name': 'Sun'}),
    e('person.marko', 'home', {'friendly_name': 'Marko'}),
    e('person.ana', 'not_home', {'friendly_name': 'Ana'}),
    e('person.jelena', 'Posao', {'friendly_name': 'Jelena'}),
    {
      ...e('sensor.washing_machine_status', 'Završeno', {
        'friendly_name': 'Veš mašina',
      }),
      'last_changed': ago(const Duration(minutes: 2)),
    },
    e('sensor.printer_progress', '72', {
      'friendly_name': 'Štampač',
      'unit_of_measurement': '%',
      'state_class': 'measurement',
    }),
    e('todo.shopping_list', '3', {
      'friendly_name': 'Spisak za kupovinu',
      // CREATE | DELETE | UPDATE | MOVE
      'supported_features': 15,
    }),
    e('todo.chores', '2', {
      'friendly_name': 'Kućni poslovi',
      'supported_features': 15 | 16,
    }),
    e('weather.forecast_home', 'partlycloudy', {
      'friendly_name': 'Forecast Home',
      'temperature': 17.5,
      'temperature_unit': '°C',
      'humidity': 62,
      'wind_speed': 11.2,
      'wind_speed_unit': 'km/h',
      'pressure': 1016,
      'pressure_unit': 'hPa',
      'attribution': 'Weather forecast from met.no, delivered by the Norwegian Meteorological Institute.',
      'supported_features': 3, // FORECAST_DAILY | FORECAST_HOURLY
    }),
    e('binary_sensor.bedroom_window', 'off', {
      'friendly_name': 'Prozor spavaća soba',
      'device_class': 'window',
    }),
    e('sensor.bedroom_co2', '1350', {
      'friendly_name': 'CO2 spavaća soba',
      'device_class': 'carbon_dioxide',
      'state_class': 'measurement',
      'unit_of_measurement': 'ppm',
    }),
    e('sensor.bedroom_window_battery', '8', {
      'friendly_name': 'Senzor prozora spavaća soba – baterija',
      'device_class': 'battery',
      'state_class': 'measurement',
      'unit_of_measurement': '%',
    }),
  ];
}

/// Mock `config/*_registry/list` results (subset of the real fields).
({
  List<Map<String, Object?>> areas,
  List<Map<String, Object?>> devices,
  List<Map<String, Object?>> entities,
})
buildMockRegistries() {
  Map<String, Object?> area(
    String id,
    String name,
    String icon, [
    String? floor,
  ]) => {
    'area_id': id,
    'name': name,
    'icon': icon,
    'picture': null,
    'floor_id': floor,
    'aliases': <String>[],
  };
  Map<String, Object?> device(
    String id,
    String name,
    String manufacturer,
    String model,
    String? areaId,
    List<List<String>> identifiers,
  ) => {
    'id': id,
    'name': name,
    'name_by_user': null,
    'manufacturer': manufacturer,
    'model': model,
    'area_id': areaId,
    'identifiers': identifiers,
    'connections': <List<String>>[],
    'via_device_id': null,
    'disabled_by': null,
  };
  Map<String, Object?> entity(
    String entityId,
    String platform, {
    String? deviceId,
    String? areaId,
    String? category,
  }) => {
    'entity_id': entityId,
    'platform': platform,
    'device_id': deviceId,
    'area_id': areaId,
    'entity_category': category,
    'hidden_by': null,
    'disabled_by': null,
  };

  return (
    areas: [
      area('living_room', 'Dnevna soba', 'mdi:sofa', 'ground'),
      area('bedroom', 'Spavaća soba', 'mdi:bed', 'first'),
      area('hallway', 'Hodnik', 'mdi:door', 'ground'),
      area('kitchen', 'Kuhinja', 'mdi:countertop', 'ground'),
      area('garage', 'Garaža', 'mdi:garage', 'ground'),
      area('yard', 'Dvorište', 'mdi:tree'),
    ],
    devices: [
      device('d_hall_light', 'Hodnik svetlo', 'IKEA', 'LED2101G4', 'hallway', [
        ['mqtt', 'zigbee2mqtt_0x0017880101aa0001'],
      ]),
      device(
        'd_living_main',
        'Glavno svetlo',
        'Signify',
        'LCA001',
        'living_room',
        [
          ['hue', '00:17:88:01:0b:aa:bb:cc-0b'],
        ],
      ),
      device(
        'd_living_ambient',
        'Ambijent',
        'Nanoleaf',
        'Essentials A19',
        'living_room',
        [
          ['matter', 'deviceid_1-0000000000000004-MatterNodeDevice'],
        ],
      ),
      device('d_coffee', 'Aparat za kafu', 'Shelly', 'Plus 1PM', 'kitchen', [
        ['shelly', 'c4:5b:be:00:11:22'],
      ]),
      device('d_washer', 'Veš mašina', 'Shelly', 'Plus Plug S', 'kitchen', [
        ['shelly', 'c4:5b:be:00:33:44'],
      ]),
      device('d_tv', 'Televizor', 'Sony', 'Bravia KD-55X85', 'living_room', [
        ['androidtv_remote', 'aa:bb:cc:dd:ee:ff'],
      ]),
      device('d_tv_outlet', 'TV utičnica', 'Nous', 'A1T', 'living_room', [
        ['tasmota', '3C71BF000001'],
      ]),
      device(
        'd_living_climate_sensor',
        'Senzor dnevna soba',
        'Aqara',
        'WSDCGQ11LM',
        'living_room',
        [
          ['zha', '00:15:8d:00:01:02:03:04'],
        ],
      ),
      device(
        'd_hall_motion',
        'Pokret hodnik',
        'Aqara',
        'RTCGQ11LM',
        'hallway',
        [
          ['zha', '00:15:8d:00:05:06:07:08'],
        ],
      ),
      device(
        'd_front_door_contact',
        'Kontakt ulazna vrata',
        'Aqara',
        'MCCGQ11LM',
        'hallway',
        [
          ['mqtt', 'zigbee2mqtt_0x00158d0001020304'],
        ],
      ),
      device('d_living_ac', 'Klima', 'ESPHome', 'esp32-ac', 'living_room', [
        ['esphome', 'ac-living'],
      ]),
      device('d_blinds', 'Roletne', 'Fibaro', 'FGR-223', 'living_room', [
        ['zwave_js', '3967352045-12'],
      ]),
      device('d_front_lock', 'Brava', 'Yale', 'Assure Lock 2', 'hallway', [
        ['zwave_js', '3967352045-21'],
      ]),
      device('d_camera', 'Kamera', 'Reolink', 'RLC-810A', 'yard', [
        ['onvif', 'ec:71:db:00:00:01'],
      ]),
      device('d_energy', 'Kućni merač', 'ESPHome', 'esp32-meter', null, [
        ['esphome', 'house-meter'],
      ]),
      device('d_garage_heater', 'Grejalica', 'Shelly', 'Plug S', 'garage', [
        ['shelly', 'c4:5b:be:00:33:44'],
      ]),
      device('d_bedroom_air', 'Senzor vazduha', 'Aqara', 'TVOC', 'bedroom', [
        ['zha', '00:15:8d:00:0a:0b:0c:0d'],
      ]),
      device(
        'd_bedroom_window',
        'Senzor prozora',
        'Aqara',
        'MCCGQ11LM',
        'bedroom',
        [
          ['mqtt', 'zigbee2mqtt_0x00158d0009080706'],
        ],
      ),
    ],
    entities: [
      entity('light.hallway', 'mqtt', deviceId: 'd_hall_light'),
      entity('light.living_room_main', 'hue', deviceId: 'd_living_main'),
      entity(
        'light.living_room_ambient',
        'matter',
        deviceId: 'd_living_ambient',
      ),
      entity('switch.coffee_machine', 'shelly', deviceId: 'd_coffee'),
      entity('switch.tv_outlet', 'tasmota', deviceId: 'd_tv_outlet'),
      entity(
        'media_player.living_room_tv',
        'androidtv_remote',
        deviceId: 'd_tv',
      ),
      entity('remote.living_room_tv', 'androidtv_remote', deviceId: 'd_tv'),
      entity('switch.washer_plug', 'shelly', deviceId: 'd_washer'),
      entity('sensor.washer_plug_power', 'shelly', deviceId: 'd_washer'),
      entity(
        'sensor.living_room_temperature',
        'zha',
        deviceId: 'd_living_climate_sensor',
      ),
      entity(
        'sensor.living_room_humidity',
        'zha',
        deviceId: 'd_living_climate_sensor',
      ),
      entity('binary_sensor.hallway_motion', 'zha', deviceId: 'd_hall_motion'),
      entity(
        'binary_sensor.front_door',
        'mqtt',
        deviceId: 'd_front_door_contact',
      ),
      entity('climate.living_room', 'esphome', deviceId: 'd_living_ac'),
      entity('cover.living_room_blinds', 'zwave_js', deviceId: 'd_blinds'),
      entity('lock.front_door', 'zwave_js', deviceId: 'd_front_lock'),
      entity('camera.front_yard', 'onvif', deviceId: 'd_camera'),
      entity('sensor.house_power', 'esphome', deviceId: 'd_energy'),
      entity('sensor.house_energy', 'esphome', deviceId: 'd_energy'),
      entity('scene.movie_night', 'homeassistant', areaId: 'living_room'),
      entity('automation.hallway_night_light', 'automation', areaId: 'hallway'),
      entity('switch.garage_heater', 'shelly', deviceId: 'd_garage_heater'),
      entity('weather.forecast_home', 'met'),
      entity('sensor.bedroom_co2', 'zha', deviceId: 'd_bedroom_air'),
      entity(
        'binary_sensor.bedroom_window',
        'mqtt',
        deviceId: 'd_bedroom_window',
      ),
      entity(
        'sensor.bedroom_window_battery',
        'mqtt',
        deviceId: 'd_bedroom_window',
        category: 'diagnostic',
      ),
    ],
  );
}

/// Mock `energy/get_prefs` (Home Assistant Energy configuration).
Map<String, Object?> buildMockEnergyPrefs() => {
  'energy_sources': [
    {
      'type': 'grid',
      'flow_from': [
        {'stat_energy_from': 'sensor.house_energy'},
      ],
      'flow_to': [
        {'stat_energy_to': 'sensor.grid_export_energy'},
      ],
      'cost_adjustment_day': 0,
    },
    {'type': 'solar', 'stat_energy_from': 'sensor.solar_energy'},
  ],
  'device_consumption': [
    {'stat_consumption': 'sensor.ac_energy', 'name': 'Klima dnevna soba'},
    {'stat_consumption': 'sensor.coffee_energy', 'name': 'Aparat za kafu'},
    {'stat_consumption': 'sensor.tv_energy', 'name': 'Televizor'},
  ],
};

/// Synthetic, deterministic kWh for one hour of a mock statistic: a daily
/// load profile with morning/evening peaks and a bell-shaped solar curve.
double mockHourlyEnergy(String statisticId, DateTime hour) {
  final h = hour.hour;
  final dayFactor =
      1 + 0.15 * ((hour.day * 7919) % 11 - 5) / 5; // varies by day
  final load =
      (0.25 + ((h >= 6 && h <= 8) || (h >= 18 && h <= 22) ? 0.45 : 0)) *
      dayFactor;
  final solar = h >= 6 && h <= 19 ? 1.4 * _bell((h - 6) / 13) / dayFactor : 0.0;
  final export = solar > load ? (solar - load) * 0.7 : 0.0;
  return switch (statisticId) {
    'sensor.house_energy' => (load - solar + export).clamp(0.05, 10),
    'sensor.solar_energy' => solar,
    'sensor.grid_export_energy' => export,
    'sensor.ac_energy' =>
      (h >= 13 && h <= 17) || (h >= 19 && h <= 22) ? 0.18 * dayFactor : 0.0,
    'sensor.coffee_energy' => h == 7 || h == 8 ? 0.12 : 0.0,
    'sensor.tv_energy' => h >= 19 && h <= 23 ? 0.07 : 0.0,
    _ => 0.0,
  };
}

double _bell(double x) => x <= 0 || x >= 1 ? 0 : 4 * x * (1 - x);

/// `config/floor_registry/list` payload of the demo home.
List<Map<String, Object?>> buildMockFloors() => [
  {'floor_id': 'ground', 'name': 'Prizemlje', 'level': 0, 'icon': null},
  {'floor_id': 'first', 'name': 'Sprat', 'level': 1, 'icon': null},
];

/// UI scene configs of the demo home (`/api/config/scene/config/<id>`).
const mockSceneConfigs = <String, Map<String, Object?>>{
  'movie_night': {
    'id': 'movie_night',
    'name': 'Filmsko veče',
    'entities': {
      'light.living_room_ambient': {
        'state': 'on',
        'brightness': 90,
        'rgb_color': [120, 60, 255],
      },
      'light.living_room_main': {'state': 'off'},
    },
  },
};
