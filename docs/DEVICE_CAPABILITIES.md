# Model uređaja i mogućnosti

UI nikada ne vidi Home Assistant atribute. Svaki entitet se prevodi u `SmartHomeDevice` (`features/devices/domain/`), a kontrole se generišu iz skupa `Capability`. Kontrola se prikazuje samo ako je uređaj prijavio mogućnost, pa se nepodržane komande ne nude.

```dart
SmartHomeDevice(
  id: 'light.living_room_main',      // = HA entity_id
  deviceId: '…',                     // HA device registry id (zajednički za entitete jednog uređaja)
  name: 'Glavno svetlo',
  roomId: 'living_room',             // entity.area_id ?? device.area_id
  kind: DeviceKind.dimmableLight,
  protocol: DeviceProtocol.zigbee,   // informativno
  manufacturer: 'Signify', model: 'LCA001',
  available: true,                   // false kada je HA stanje "unavailable"
  capabilities: {power, brightness, colorTemperature, transition},
  state: DeviceState(isOn: true, brightnessPercent: 75, colorTemperatureKelvin: 3200),
  limits: DeviceLimits(minColorTemperatureKelvin: 2200, maxColorTemperatureKelvin: 6500),
  metadata: DeviceMetadata(batteryPercent: null, signalStrength: null, lastChanged: …, lastUpdated: …),
  isAuxiliary: false,                // hidden/config/diagnostic entiteti
)
```

Jedinice su normalizovane: svetlina i položaj u procentima (0–100), temperatura boje u Kelvinima, jačina zvuka u procentima. `null` znači „nije prijavljeno” i UI ga prikazuje kao nepoznato, nikad kao nulu.

## Ventilator, ovlaživač, usisivač, izbor, broj

| Vrsta | Mogućnosti | Servisi |
|---|---|---|
| `fan` | `fanSpeed` (SET_SPEED 1, `percentage_step`), `oscillate` (2), `presetMode` (8) | `set_percentage` (0 → `turn_off`), `oscillate`, `set_preset_mode` |
| `humidifier` | `targetHumidity` (min/max), `presetMode` (MODES 1) | `set_humidity` (ograničeno na opseg), `set_mode` |
| `vacuum` | `vacuumStart` (8192), `vacuumPause` (4), `vacuumReturnHome` (16), `stop` (8) | `start`, `pause`, `return_to_base` |
| `select`, `input_select` | `selectOption` (`options`) | `select_option` (samo ponuđene vrednosti) |
| `number`, `input_number` | `numberValue` (`min`, `max`, `step`) | `set_value` (ograničeno i zaokruženo na korak) |

## Alarm (`alarm_control_panel`)

- Režimi uključivanja iz `supported_features` (ARM_HOME 1, ARM_AWAY 2, ARM_NIGHT 4, ARM_CUSTOM_BYPASS 16, ARM_VACATION 32) → `alarm_arm_<mode>`; isključivanje `alarm_disarm`.
- `code_format` (`number` → tastatura, `text` → skriveno polje) i `code_arm_required`; pogrešan kod HA odbija i aplikacija prikazuje grešku.

## Mapiranje (HA → aplikacija)

Odluke se donose na osnovu **domena, `device_class`, `supported_color_modes` i `supported_features` bitova** (`ha_feature_flags.dart`, preuzeto iz HA `*EntityFeature` enum-a), a nikad na osnovu teksta `entity_id`-a.

| HA domen | Uslov | `DeviceKind` | Mogućnosti |
|---|---|---|---|
| `light` | color modes ⊇ rgbw/rgbww | `rgbwLight` | power, brightness, rgb, rgbw, (+colorTemperature, hs/xy) |
| | color modes ⊇ hs/xy/rgb | `rgbLight` | power, brightness, rgb, … |
| | bilo koji mod osim `onoff` | `dimmableLight` | power, brightness, (colorTemperature) |
| | samo `onoff` | `light` | power |
| | `supported_features & 32` | | + transition |
| `switch`, `input_boolean` | `device_class: outlet` | `outlet` | power |
| | inače | `switchDevice` | power |
| `sensor` | temperature / humidity / pressure / illuminance / battery | odgovarajući senzor | currentTemperature / humidity / – / – / battery |
| | power / energy | `powerMeter` / `energyMeter` | powerConsumption / energyConsumption |
| | water / gas | `waterMeter` / `gasMeter` | |
| | aqi, pm*, CO₂, VOC, NO₂, O₃, SO₂, CO | `airQualitySensor` | |
| | voltage / current / frequency | `sensor` | voltage / current / frequency |
| `binary_sensor` | motion, moving / occupancy, presence | `motionSensor` / `occupancySensor` | |
| | door, window, garage_door, opening | `contactSensor` | |
| | smoke / carbon_monoxide / moisture / vibration | `smokeSensor` / `coSensor` / `waterLeakSensor` / `vibrationSensor` | |
| `climate` | `hvac_modes` sadrži cool/heat_cool/dry/fan_only | `climate` | po bitovima: targetTemperature(1), targetTemperatureRange(2), targetHumidity(4), fanMode(8), presetMode(16), swingMode(32), power(128+256); hvacMode, heating, cooling |
| | inače | `thermostat` | isto |
| `cover` | garage, gate / curtain / ostalo | `garageDoor` / `curtain` / `blind` | open(1), close(2), position(4), stop(8), tilt(16/32/128) |
| `valve` | `device_class: water` | `irrigation` | open, close, position, stop |
| `lock` | | `lock` | lock, unlock, open(1) |
| `camera` | | `camera` | cameraSnapshot, cameraStream(2) |
| `media_player` | tv / speaker, receiver / ostalo | `television` / `speaker` / `mediaPlayer` | power, play, pause, stop, next, previous, volume, mute, sourceSelection |
| `fan` | | `fan` | power, presetMode(8) |
| `humidifier` | dehumidifier / ostalo | `dehumidifier` / `humidifier` | power, targetHumidity, presetMode(1) |
| `alarm_control_panel` | | `alarm` | disarm, arm (bilo koji arm bit), trigger(8) |
| `siren` | | `siren` | power (1+2) |
| `vacuum` | | `vacuum` | stop(8) |
| `event` | `device_class: doorbell` | `doorbell` | |
| `button`, `input_button` / `scene` / `script` / `automation` | | `button` / `scene` / `script` / `automation` | trigger (+power za automatizacije) |
| ostalo | | `unknown` | – |

**Baterija i signal** dolaze iz posebnih dijagnostičkih entiteta istog fizičkog uređaja i pridružuju se svim njegovim entitetima: `sensor` sa `device_class: battery`, `binary_sensor` sa `device_class: battery` (slaba baterija), i `sensor` sa `device_class: signal_strength` ili jedinicom `lqi` (Zigbee2MQTT).

**Protokol** se određuje iz integracije (`platform` u entity registry-ju): `zha`/`deconz`/`hue`/`tradfri` → Zigbee, `mqtt` sa identifikatorom `zigbee2mqtt_*` → Zigbee, ostali `mqtt` → MQTT, `zwave_js` → Z-Wave, `matter` → Matter, `esphome` → ESPHome, `shelly` → Wi-Fi, `knx`, `modbus`, `rfxtrx` (433 MHz), `broadlink` (IR)… Nepoznato → `unknown`. Protokol je samo informativan.

## Komande

`DeviceCommand` (sealed) → `HaCommandTranslator` → dokumentovani HA servis. `DeviceCommandService` pre slanja proverava, redom:

1. da je uređaj dostupan (`unavailableEntity`);
2. da uređaj ima potrebnu mogućnost (`unsupportedFeature`);
3. da je kritična komanda potvrđena (`confirmationRequired`): `UnlockDevice`, `DisarmAlarm`, otvaranje garaže.

| Komanda | HA servis |
|---|---|
| `TurnOn` / `TurnOff` / `Toggle` | `<domain>.turn_on` / `turn_off` / `toggle` |
| `SetBrightness(p)` | `light.turn_on {brightness_pct}`; `0` → `light.turn_off` |
| `SetColorTemperature(k)` | `light.turn_on {color_temp_kelvin}` (ograničeno na min/max) |
| `SetRgbColor` | `light.turn_on {rgb_color}` |
| `SetTargetTemperature(t)` | `climate.set_temperature {temperature}` (zaokruženo na korak, ograničeno na min/max) |
| `SetHvacMode` / `SetFanMode` | `climate.set_hvac_mode` / `set_fan_mode` (samo ponuđene vrednosti) |
| `OpenCover` / `CloseCover` / `StopCover` / `SetCoverPosition` | `cover.*` ili `valve.*` |
| `LockDevice` / `UnlockDevice` | `lock.lock` / `lock.unlock` |
| `DisarmAlarm(code)` | `alarm_control_panel.alarm_disarm` |
| `Activate` | `scene.turn_on`, `script.turn_on`, `button.press`, `automation.trigger` |

Interfejs se ne ažurira optimistički; novo stanje stiže kroz `state_changed` događaj.

## Dodavanje novog domena
1. Dodajte granu u `HaDeviceMapper.map` (i bitove u `ha_feature_flags.dart` ako treba).
2. Po potrebi dodajte `DeviceKind`/`Capability`.
3. Dodajte prevod komandi u `HaCommandTranslator`.
4. Dodajte test u `test/integrations/ha_device_mapper_test.dart` sa stvarnim HA atributima.
