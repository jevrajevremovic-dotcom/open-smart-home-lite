import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';
import 'ssdp.dart';

/// Sonos speakers over UPnP (SOAP on port 1400): play, pause, next,
/// previous, volume, mute and what is playing. Each speaker on its own;
/// in a group, commands go to the speaker they are sent to.
class SonosAdapter extends PolledAdapter {
  SonosAdapter(this._http, {super.pollEvery});

  final LanRequests _http;

  @override
  String get id => 'sonos';

  Future<String> _soap(
    ConfiguredDevice d,
    String service,
    String action, [
    Map<String, Object> args = const {},
  ]) => sonosSoap(_http, d.host, service, action, args);

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final (transport, position, volume, mute) = await (
      _soap(device, 'AVTransport', 'GetTransportInfo'),
      _soap(device, 'AVTransport', 'GetPositionInfo'),
      _soap(device, 'RenderingControl', 'GetVolume', {'Channel': 'Master'}),
      _soap(device, 'RenderingControl', 'GetMute', {'Channel': 'Master'}),
    ).wait;
    return [
      parseSonos(
        device,
        state: xmlText(transport, 'CurrentTransportState'),
        metadata: xmlText(position, 'TrackMetaData'),
        volume: int.tryParse(xmlText(volume, 'CurrentVolume') ?? ''),
        muted: xmlText(mute, 'CurrentMute') == '1',
      ),
    ];
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final playing = channel.state.raw == 'playing';
    final (service, action, args) = switch (command) {
      MediaPlayPause() when playing => (
        'AVTransport',
        'Pause',
        <String, Object>{},
      ),
      MediaPlayPause() || TurnOn() => ('AVTransport', 'Play', {'Speed': 1}),
      TurnOff() => ('AVTransport', 'Pause', <String, Object>{}),
      MediaNext() => ('AVTransport', 'Next', <String, Object>{}),
      MediaPrevious() => ('AVTransport', 'Previous', <String, Object>{}),
      SetVolume(:final percent) => (
        'RenderingControl',
        'SetVolume',
        {'Channel': 'Master', 'DesiredVolume': percent.clamp(0, 100)},
      ),
      StepVolume(:final up) => (
        'RenderingControl',
        'SetVolume',
        {
          'Channel': 'Master',
          'DesiredVolume': ((channel.state.volumePercent ?? 20) + (up ? 5 : -5))
              .clamp(0, 100),
        },
      ),
      SetMute(:final muted) => (
        'RenderingControl',
        'SetMute',
        {'Channel': 'Master', 'DesiredMute': muted ? 1 : 0},
      ),
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for Sonos',
      ),
    };
    await _soap(device, service, action, args);
  }
}

/// One UPnP action on the speaker; the answer's XML. Throws `AppFailure`
/// for a fault (e.g. Next with nothing queued).
Future<String> sonosSoap(
  LanRequests http,
  String host,
  String service,
  String action, [
  Map<String, Object> args = const {},
]) async {
  final urn = 'urn:schemas-upnp-org:service:$service:1';
  final body =
      '<?xml version="1.0" encoding="utf-8"?>'
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
      '<s:Body><u:$action xmlns:u="$urn"><InstanceID>0</InstanceID>'
      '${[for (final e in args.entries) '<${e.key}>${xmlEscape('${e.value}')}</${e.key}>'].join()}'
      '</u:$action></s:Body></s:Envelope>';
  final r = await http.send(
    'POST',
    Uri.parse('http://$host:1400/MediaRenderer/$service/Control'),
    headers: {
      'content-type': 'text/xml; charset="utf-8"',
      'soapaction': '"$urn#$action"',
    },
    body: utf8.encode(body),
  );
  if (!r.ok) {
    throw AppFailure(
      FailureKind.server,
      debugMessage:
          'sonos $action: ${xmlText(r.text, 'errorCode') ?? r.status}',
    );
  }
  return r.text;
}

SmartHomeDevice parseSonos(
  ConfiguredDevice device, {
  String? state,
  String? metadata,
  int? volume,
  bool muted = false,
}) {
  final raw = switch (state) {
    'PLAYING' || 'TRANSITIONING' => 'playing',
    'PAUSED_PLAYBACK' => 'paused',
    _ => 'idle',
  };
  // Track metadata is DIDL-Lite (XML inside the XML).
  final title = metadata == null ? null : xmlText(metadata, 'title');
  final artist = metadata == null ? null : xmlText(metadata, 'creator');
  final album = metadata == null ? null : xmlText(metadata, 'album');
  return SmartHomeDevice(
    id: '${device.key}:speaker',
    sourceId: device.host,
    deviceId: device.key,
    name: device.label ?? 'Sonos',
    kind: DeviceKind.speaker,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Sonos',
    model: device.model,
    available: true,
    capabilities: const {
      Capability.mediaPlay,
      Capability.mediaPause,
      Capability.mediaNext,
      Capability.mediaPrevious,
      Capability.volume,
      Capability.mute,
    },
    state: DeviceState(
      raw: raw,
      isOn: raw == 'playing',
      volumePercent: volume,
      isMuted: muted,
      mediaTitle: title?.isEmpty ?? true ? null : title,
      mediaArtist: artist?.isEmpty ?? true ? null : artist,
      mediaAlbum: album?.isEmpty ?? true ? null : album,
    ),
  );
}

/// The Sonos at [host]: its id (`RINCON_…`), room name and model.
Future<({String id, String? room, String? model})?> sonosProbe(
  LanRequests http,
  String host,
) async {
  try {
    final r = await http.send(
      'GET',
      Uri.parse('http://$host:1400/xml/device_description.xml'),
      timeout: const Duration(seconds: 3),
    );
    final udn = xmlText(r.text, 'UDN');
    if (!r.ok || udn == null || !udn.contains('RINCON')) return null;
    return (
      id: udn.replaceFirst('uuid:', '').toLowerCase(),
      room: xmlText(r.text, 'roomName'),
      model: xmlText(r.text, 'modelName'),
    );
  } on AppFailure {
    return null;
  }
}

/// Sonos speakers on the network (SSDP ZonePlayer).
Future<List<({String host, String id, String? room, String? model})>>
sonosDiscover(LanUdp udp, LanRequests http) async {
  final out = <({String host, String id, String? room, String? model})>[];
  for (final f in await ssdpSearch(
    udp,
    'urn:schemas-upnp-org:device:ZonePlayer:1',
  )) {
    final p = await sonosProbe(http, f.host);
    if (p != null) {
      out.add((host: f.host, id: p.id, room: p.room, model: p.model));
    }
  }
  return out;
}
