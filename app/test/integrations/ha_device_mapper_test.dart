import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_fixtures.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';

const mapper = HaDeviceMapper();

HaEntityState entity(
  String id,
  String state, [
  Map<String, Object?> attrs = const {},
]) => HaEntityState(entityId: id, state: state, attributes: attrs);

SmartHomeDevice one(
  String id,
  String state, [
  Map<String, Object?> attrs = const {},
]) => mapper.map(entity(id, state, attrs), HaRegistries.empty);

void main() {
  group('fixtures (realistic HA data)', () {
    late Map<String, SmartHomeDevice> devices;

    setUpAll(() {
      final reg = buildMockRegistries();
      devices = mapper.mapAll(
        parseStateList(buildMockStates(DateTime(2026, 10, 13))),
        HaRegistries.parse(
          areas: reg.areas,
          devices: reg.devices,
          entities: reg.entities,
        ),
      );
    });

    test('every fixture maps to a known kind', () {
      // sun.sun is read for the theme only, never shown as a device.
      final unknown = devices.values.where(
        (d) => d.kind == DeviceKind.unknown && d.id != 'sun.sun',
      );
      expect(unknown, isEmpty);
    });

    test('lights are classified by color modes, not by name', () {
      expect(devices['light.hallway']!.kind, DeviceKind.light);
      expect(
        devices['light.hallway']!.supports(Capability.brightness),
        isFalse,
      );
      expect(devices['light.living_room_main']!.kind, DeviceKind.dimmableLight);
      expect(
        devices['light.living_room_main']!.supports(
          Capability.colorTemperature,
        ),
        isTrue,
      );
      expect(
        devices['light.living_room_main']!.supports(Capability.transition),
        isTrue,
      );
      expect(devices['light.living_room_ambient']!.kind, DeviceKind.rgbLight);
    });

    test('light state is normalised to percent and Kelvin', () {
      final main = devices['light.living_room_main']!;
      expect(main.state.isOn, isTrue);
      expect(main.state.brightnessPercent, 75); // 191/255
      expect(main.state.colorTemperatureKelvin, 3200);
      expect(main.limits.minColorTemperatureKelvin, 2200);
      expect(
        devices['light.living_room_ambient']!.state.rgb,
        const RgbColor(255, 140, 40),
      );
    });

    test('protocol comes from the integration and device identifiers', () {
      expect(
        devices['light.hallway']!.protocol,
        DeviceProtocol.zigbee,
      ); // zigbee2mqtt
      expect(
        devices['light.living_room_main']!.protocol,
        DeviceProtocol.zigbee,
      ); // hue
      expect(
        devices['light.living_room_ambient']!.protocol,
        DeviceProtocol.matter,
      );
      expect(devices['lock.front_door']!.protocol, DeviceProtocol.zwave);
      expect(
        devices['switch.tv_outlet']!.protocol,
        DeviceProtocol.mqtt,
      ); // tasmota
      expect(devices['scene.movie_night']!.protocol, DeviceProtocol.virtual);
    });

    test('room comes from the device, overridable per entity', () {
      expect(devices['lock.front_door']!.roomId, 'hallway');
      expect(
        devices['scene.movie_night']!.roomId,
        'living_room',
      ); // entity-level area
      expect(devices['sensor.house_power']!.roomId, isNull);
    });

    test('manufacturer and model come from the device registry', () {
      expect(devices['cover.living_room_blinds']!.manufacturer, 'Fibaro');
      expect(devices['cover.living_room_blinds']!.model, 'FGR-223');
    });

    test('battery of a diagnostic sensor is attached to its device', () {
      final window = devices['binary_sensor.bedroom_window']!;
      expect(window.kind, DeviceKind.contactSensor);
      expect(window.metadata.batteryPercent, 8);
      expect(window.hasLowBattery, isTrue);
      expect(window.supports(Capability.battery), isTrue);
      expect(devices['sensor.bedroom_window_battery']!.isAuxiliary, isTrue);
    });

    test('unavailable entity', () {
      final heater = devices['switch.garage_heater']!;
      expect(heater.available, isFalse);
      expect(heater.state.isOn, isNull);
    });

    test('climate with cooling modes is an AC with declared features', () {
      final ac = devices['climate.living_room']!;
      expect(ac.kind, DeviceKind.climate);
      expect(
        ac.capabilities,
        containsAll([
          Capability.targetTemperature,
          Capability.fanMode,
          Capability.power,
          Capability.hvacMode,
          Capability.heating,
          Capability.cooling,
        ]),
      );
      expect(ac.supports(Capability.swingMode), isFalse);
      expect(ac.state.targetTemperature, 23);
      expect(ac.limits.temperatureStep, 0.5);
      expect(ac.limits.hvacModes, contains('cool'));
    });

    test('sensors and meters', () {
      expect(
        devices['sensor.living_room_temperature']!.kind,
        DeviceKind.temperatureSensor,
      );
      expect(
        devices['sensor.living_room_temperature']!.state.currentTemperature,
        22.4,
      );
      expect(
        devices['sensor.living_room_humidity']!.kind,
        DeviceKind.humiditySensor,
      );
      expect(devices['sensor.house_power']!.kind, DeviceKind.powerMeter);
      expect(devices['sensor.house_energy']!.kind, DeviceKind.energyMeter);
      expect(
        devices['binary_sensor.hallway_motion']!.kind,
        DeviceKind.motionSensor,
      );
      expect(devices['binary_sensor.front_door']!.state.isActive, isFalse);
    });

    test('cover, lock, switch variants, routines', () {
      final blinds = devices['cover.living_room_blinds']!;
      expect(blinds.kind, DeviceKind.blind);
      expect(blinds.state.position, 100);
      expect(blinds.supports(Capability.tilt), isFalse);
      expect(devices['lock.front_door']!.state.lockState, DoorLockState.locked);
      expect(devices['switch.tv_outlet']!.kind, DeviceKind.outlet);
      expect(
        devices['scene.movie_night']!.supports(Capability.trigger),
        isTrue,
      );
      expect(devices['automation.hallway_night_light']!.state.isOn, isTrue);
    });
  });

  test('person: home / away / zone; only local pictures are kept', () {
    SmartHomeDevice person(String state, [Object? picture]) =>
        const HaDeviceMapper().map(
          HaEntityState(
            entityId: 'person.a',
            state: state,
            attributes: {'friendly_name': 'A', 'entity_picture': ?picture},
          ),
          HaRegistries.empty,
        );
    expect(person('home').kind, DeviceKind.person);
    expect(person('home').state.isActive, isTrue);
    expect(person('not_home').state.isActive, isFalse);
    expect(person('Posao').state.textValue, 'Posao');
    expect(
      person('home', '/api/image/serve/abc/512x512').metadata.picturePath,
      '/api/image/serve/abc/512x512',
    );
    for (final bad in [
      'https://example.com/a.png',
      '//example.com/a.png',
      '/local/a.png',
      '/api/../secret',
      42,
    ]) {
      expect(person('home', bad).metadata.picturePath, isNull, reason: '$bad');
    }
  });

  group('edge cases', () {
    test(
      'legacy light without color modes is dimmable when brightness exists',
      () {
        expect(
          one('light.old', 'on', {'brightness': 10}).kind,
          DeviceKind.dimmableLight,
        );
        expect(one('light.old', 'on').kind, DeviceKind.light);
      },
    );

    test('rgbw/rgbww lights', () {
      final d = one('light.strip', 'off', {
        'supported_color_modes': ['rgbww', 'color_temp'],
      });
      expect(d.kind, DeviceKind.rgbwLight);
      expect(
        d.capabilities,
        containsAll([
          Capability.rgb,
          Capability.rgbw,
          Capability.colorTemperature,
        ]),
      );
      expect(
        d.state.brightnessPercent,
        isNull,
        reason: 'off lights report no brightness',
      );
    });

    test('heat-only climate is a thermostat', () {
      final d = one('climate.radiator', 'heat', {
        'hvac_modes': ['off', 'heat'],
        'supported_features': 1,
      });
      expect(d.kind, DeviceKind.thermostat);
      expect(d.supports(Capability.cooling), isFalse);
      expect(d.supports(Capability.power), isFalse);
    });

    test('cover features and classes', () {
      final garage = one('cover.garage', 'closed', {
        'device_class': 'garage',
        'supported_features': 3,
      });
      expect(garage.kind, DeviceKind.garageDoor);
      expect(garage.capabilities, {Capability.open, Capability.close});
      expect(garage.state.coverState, CoverState.closed);

      final tilt = one('cover.venetian', 'open', {
        'supported_features': 15 | 16 | 32,
      });
      expect(tilt.supports(Capability.tilt), isTrue);
      expect(
        one('cover.c', 'open', {'device_class': 'curtain'}).kind,
        DeviceKind.curtain,
      );
    });

    test('alarm panel states and features', () {
      final d = one('alarm_control_panel.home', 'armed_away', {
        'supported_features': 3,
      });
      expect(d.state.alarmState, AlarmState.armedAway);
      expect(d.capabilities, {Capability.arm, Capability.disarm});
    });

    test('non-numeric sensor keeps text, unknown has no value', () {
      final text = one('sensor.washer', 'running');
      expect(text.state.numericValue, isNull);
      expect(text.state.textValue, 'running');
      final unknown = one('sensor.t', 'unknown', {
        'device_class': 'temperature',
      });
      expect(unknown.available, isTrue);
      expect(unknown.state.numericValue, isNull);
      expect(unknown.state.textValue, isNull);
    });

    test('media player kinds and features', () {
      final tv = one('media_player.tv', 'on', {
        'device_class': 'tv',
        'supported_features': 128 | 256 | 4 | 2048,
        'volume_level': 0.35,
        'source_list': ['HDMI 1', 'TV'],
      });
      expect(tv.kind, DeviceKind.television);
      expect(tv.capabilities, {
        Capability.power,
        Capability.volume,
        Capability.sourceSelection,
      });
      expect(tv.state.volumePercent, 35);
      expect(tv.limits.sources, ['HDMI 1', 'TV']);
    });

    test('doorbell event entity and buttons', () {
      expect(
        one('event.door', '2026-10-13T10:00:00+00:00', {
          'device_class': 'doorbell',
        }).kind,
        DeviceKind.doorbell,
      );
      expect(
        one('button.restart', 'unknown').supports(Capability.trigger),
        isTrue,
      );
    });

    test('unsupported domains map to unknown without capabilities', () {
      final d = one('update.home_assistant_core', 'off');
      expect(d.kind, DeviceKind.unknown);
      expect(d.capabilities, isEmpty);
    });

    test('garbage attribute types do not crash the mapper', () {
      final d = one('light.weird', 'on', {
        'supported_color_modes': 'not-a-list',
        'brightness': 'abc',
        'supported_features': 'x',
        'rgb_color': ['a', 1],
      });
      expect(d.kind, DeviceKind.light);
      expect(d.state.brightnessPercent, isNull);
      expect(d.state.rgb, isNull);
    });

    test('zigbee2mqtt link quality becomes signal strength', () {
      final registries = HaRegistries.parse(
        areas: const [],
        devices: [
          {
            'id': 'd1',
            'identifiers': [
              ['mqtt', 'zigbee2mqtt_0x1'],
            ],
          },
        ],
        entities: [
          {'entity_id': 'switch.plug', 'device_id': 'd1', 'platform': 'mqtt'},
          {
            'entity_id': 'sensor.plug_linkquality',
            'device_id': 'd1',
            'platform': 'mqtt',
            'entity_category': 'diagnostic',
          },
        ],
      );
      final devices = mapper.mapAll([
        entity('switch.plug', 'on'),
        entity('sensor.plug_linkquality', '120', {
          'unit_of_measurement': 'lqi',
        }),
      ], registries);
      expect(devices['switch.plug']!.metadata.signalStrength, 120);
      expect(devices['switch.plug']!.metadata.signalUnit, 'lqi');
      expect(devices['switch.plug']!.protocol, DeviceProtocol.zigbee);
    });

    test('disabled entities are skipped', () {
      final registries = HaRegistries.parse(
        areas: const [],
        devices: const [],
        entities: [
          {'entity_id': 'switch.a', 'disabled_by': 'user'},
        ],
      );
      expect(mapper.mapAll([entity('switch.a', 'on')], registries), isEmpty);
    });
  });
}
