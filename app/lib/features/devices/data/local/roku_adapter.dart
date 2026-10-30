import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';
import 'ssdp.dart';

/// Roku TVs and players over Roku's External Control Protocol (HTTP on
/// port 8060): the remote's keys, volume steps, power (Roku TVs) and what
/// is on. In the Roku's settings, "Control by mobile apps" must allow it.
class RokuAdapter extends PolledAdapter {
  RokuAdapter(this._http, {super.pollEvery});

  final LanRequests _http;

  static const port = 8060;

  @override
  String get id => 'roku';

  Uri _uri(ConfiguredDevice d, String path) =>
      Uri.parse('http://${d.host}:$port$path');

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final info = await _http.send('GET', _uri(device, '/query/device-info'));
    if (!info.ok) {
      throw AppFailure(FailureKind.server, debugMessage: 'roku ${info.status}');
    }
    String? app;
    String? player;
    try {
      final (a, p) = await (
        _http.send('GET', _uri(device, '/query/active-app')),
        _http.send('GET', _uri(device, '/query/media-player')),
      ).wait;
      app = xmlText(a.text, 'app');
      player = xmlAttribute(p.text, 'player', 'state');
    } on Object {
      // A TV in standby answers only device-info.
    }
    return [parseRoku(device, info.text, app: app, player: player)];
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final key = switch (command) {
      TurnOn() => 'PowerOn',
      TurnOff() => 'PowerOff',
      Toggle() => channel.state.isOn == true ? 'PowerOff' : 'PowerOn',
      StepVolume(:final up) => up ? 'VolumeUp' : 'VolumeDown',
      SetMute() => 'VolumeMute',
      MediaPlayPause() => 'Play',
      MediaNext() => 'Fwd',
      MediaPrevious() => 'Rev',
      PressTvKey(:final key) => rokuKeys[key],
      _ => null,
    };
    if (key == null) {
      throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for Roku',
      );
    }
    final r = await _http.send('POST', _uri(device, '/keypress/$key'));
    if (!r.ok) {
      throw AppFailure(FailureKind.server, debugMessage: 'roku ${r.status}');
    }
  }
}

const rokuKeys = <TvKey, String>{
  TvKey.up: 'Up',
  TvKey.down: 'Down',
  TvKey.left: 'Left',
  TvKey.right: 'Right',
  TvKey.ok: 'Select',
  TvKey.back: 'Back',
  TvKey.home: 'Home',
  TvKey.menu: 'Info',
  TvKey.volumeUp: 'VolumeUp',
  TvKey.volumeDown: 'VolumeDown',
  TvKey.mute: 'VolumeMute',
  TvKey.channelUp: 'ChannelUp',
  TvKey.channelDown: 'ChannelDown',
  TvKey.playPause: 'Play',
};

SmartHomeDevice parseRoku(
  ConfiguredDevice device,
  String info, {
  String? app,
  String? player,
}) {
  final tv = xmlText(info, 'is-tv') == 'true';
  final power = xmlText(info, 'power-mode');
  final on = power == null || power == 'PowerOn';
  final name =
      xmlText(info, 'user-device-name') ??
      xmlText(info, 'friendly-device-name') ??
      device.label ??
      'Roku';
  final playing = player == 'play';
  return SmartHomeDevice(
    id: '${device.key}:tv',
    sourceId: device.host,
    deviceId: device.key,
    name: name,
    kind: tv ? DeviceKind.television : DeviceKind.mediaPlayer,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Roku',
    model: xmlText(info, 'model-name') ?? device.model,
    available: true,
    capabilities: {
      if (tv) Capability.power,
      Capability.tvKeys,
      Capability.volumeStep,
      Capability.mute,
      Capability.mediaPlay,
      Capability.mediaPause,
      Capability.mediaNext,
      Capability.mediaPrevious,
    },
    state: DeviceState(
      raw: !on
          ? 'off'
          : playing
          ? 'playing'
          : player == 'pause'
          ? 'paused'
          : 'on',
      isOn: on,
      // The home screen is not something playing.
      mediaTitle: app != null && app != 'Roku' && app != 'Home' ? app : null,
    ),
    limits: DeviceLimits(tvKeys: rokuKeys.keys.toSet()),
  );
}

/// Roku devices on the network (SSDP `roku:ecp`): address and serial.
Future<List<({String host, String serial, String? name, String? model})>>
rokuDiscover(LanUdp udp, LanRequests http) async {
  final out = <({String host, String serial, String? name, String? model})>[];
  for (final f in await ssdpSearch(udp, 'roku:ecp')) {
    final host = Uri.tryParse(f.location ?? '')?.host ?? f.host;
    final r = await rokuProbe(http, host);
    if (r != null) out.add(r);
  }
  return out;
}

/// The Roku at [host], or `null`.
Future<({String host, String serial, String? name, String? model})?> rokuProbe(
  LanRequests http,
  String host,
) async {
  try {
    final r = await http.send(
      'GET',
      Uri.parse('http://$host:${RokuAdapter.port}/query/device-info'),
      timeout: const Duration(seconds: 3),
    );
    final serial = xmlText(r.text, 'serial-number');
    if (!r.ok || serial == null) return null;
    return (
      host: host,
      serial: serial.toLowerCase(),
      name:
          xmlText(r.text, 'user-device-name') ??
          xmlText(r.text, 'friendly-device-name'),
      model: xmlText(r.text, 'model-name'),
    );
  } on AppFailure {
    return null;
  }
}
