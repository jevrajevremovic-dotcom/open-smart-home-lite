/// `supported_features` bit values, copied from the Home Assistant core
/// `*EntityFeature` IntFlag enums (`homeassistant/components/<domain>/const.py`).
/// Values are part of HA's public entity model and do not change.
library;

abstract final class LightFeature {
  static const effect = 4;
  static const flash = 8;
  static const transition = 32;
}

abstract final class ClimateFeature {
  static const targetTemperature = 1;
  static const targetTemperatureRange = 2;
  static const targetHumidity = 4;
  static const fanMode = 8;
  static const presetMode = 16;
  static const swingMode = 32;
  static const turnOff = 128;
  static const turnOn = 256;
}

abstract final class CoverFeature {
  static const open = 1;
  static const close = 2;
  static const setPosition = 4;
  static const stop = 8;
  static const openTilt = 16;
  static const closeTilt = 32;
  static const stopTilt = 64;
  static const setTiltPosition = 128;
}

abstract final class ValveFeature {
  static const open = 1;
  static const close = 2;
  static const setPosition = 4;
  static const stop = 8;
}

abstract final class LockFeature {
  static const open = 1;
}

abstract final class CameraFeature {
  static const onOff = 1;
  static const stream = 2;
}

abstract final class MediaPlayerFeature {
  static const pause = 1;
  static const seek = 2;
  static const volumeSet = 4;
  static const volumeMute = 8;
  static const previousTrack = 16;
  static const nextTrack = 32;
  static const turnOn = 128;
  static const turnOff = 256;
  static const playMedia = 512;
  static const volumeStep = 1024;
  static const selectSource = 2048;
  static const stop = 4096;
  static const play = 16384;
  static const shuffleSet = 32768;
  static const selectSoundMode = 65536;
  static const repeatSet = 262144;
}

abstract final class FanFeature {
  static const setSpeed = 1;
  static const oscillate = 2;
  static const direction = 4;
  static const presetMode = 8;
  static const turnOff = 16;
  static const turnOn = 32;
}

abstract final class HumidifierFeature {
  static const modes = 1;
}

abstract final class AlarmFeature {
  static const armHome = 1;
  static const armAway = 2;
  static const armNight = 4;
  static const trigger = 8;
  static const armCustomBypass = 16;
  static const armVacation = 32;
}

abstract final class SirenFeature {
  static const turnOn = 1;
  static const turnOff = 2;
}

abstract final class VacuumFeature {
  static const pause = 4;
  static const stop = 8;
  static const returnHome = 16;
  static const start = 8192;
}

extension FeatureBits on int {
  bool has(int flag) => this & flag == flag;
  bool hasAny(int flags) => this & flags != 0;
}
