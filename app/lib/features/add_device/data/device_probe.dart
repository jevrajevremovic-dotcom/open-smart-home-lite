import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';

import '../../devices/data/local/esphome/esphome_client.dart';
import '../../devices/data/local/ble/ble_advert.dart';
import '../../devices/data/local/hue_adapter.dart';
import '../../devices/data/local/dirigera_adapter.dart';
import '../../devices/data/local/govee_adapter.dart';
import '../../devices/data/local/kasa_adapter.dart';
import '../../devices/data/local/klap.dart';
import '../../devices/data/local/lan_transport.dart';
import '../../devices/data/local/lg_tv_adapter.dart';
import '../../devices/data/local/lifx_adapter.dart';
import '../../devices/data/local/wiz_adapter.dart';
import '../../devices/data/local/lan_http.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/data/local/nanoleaf_adapter.dart';
import '../../devices/data/local/roku_adapter.dart';
import '../../devices/data/local/samsung_tv_adapter.dart';
import '../../devices/data/local/sonoff_adapter.dart';
import '../../devices/data/local/sonos_adapter.dart';
import '../../devices/data/local/ssdp.dart';
import '../../devices/data/local/tapo_adapter.dart';
import '../../devices/data/local/shelly_adapter.dart';
import '../../devices/data/local/tasmota_adapter.dart';
import '../../devices/data/local/wled_adapter.dart';
import '../../devices/data/local/yeelight_adapter.dart';
import 'lan_discovery.dart';

/// A device recognised at an address, ready to be added.
@immutable
class ProbedDevice {
  const ProbedDevice({
    required this.device,
    required this.brand,
    this.name,
    this.needsPassword = false,
    this.needsAccount = false,
    this.needsKey = false,
    this.needsLink = false,
    this.detail,
  });

  final ConfiguredDevice device;

  /// `Shelly`, `WLED` or `Tasmota`.
  final String brand;

  /// The name set on the device itself, if any.
  final String? name;

  /// The device asks for a password.
  final bool needsPassword;

  /// The device checks a TP-Link account (Tapo, newer Kasa): e-mail and
  /// password ([TpLinkAccount]), checked by [DeviceProbe.checkAccount].
  final bool needsAccount;

  /// An ESPHome device that encrypts its API: the key is needed (and,
  /// when found by its address only, it tells who it is with the key).
  final bool needsKey;

  /// Paired with a button on the device (a Hue bridge, a Nanoleaf) or a
  /// prompt on its screen before it can be added ([DeviceProbe.link]).
  final bool needsLink;

  /// What it reports now (a Bluetooth thermometer's `21.4 °C · 48 %`).
  final String? detail;

  /// The device's name, else its model.
  String get title => name ?? device.model ?? brand;
}

/// Asks a device on the local network what it is: Shelly (`/shelly`),
/// WLED (`/json/info`), a Hue bridge (`/api/config`), Tasmota
/// (`Status 0`), Kasa (`get_sysinfo`) or ESPHome (its API, or what it
/// announces). Only reads; `null` for anything else.
class DeviceProbe {
  const DeviceProbe(
    this._http,
    this._esphome, {
    this.kasa,
    this.udp,
    this.requests,
    this.sockets,
    this.klap,
  });

  final LanHttp _http;
  final EsphomeConnector _esphome;
  final KasaTransport? kasa;
  final LanUdp? udp;
  final LanRequests? requests;
  final LanSockets? sockets;
  final KlapClient? klap;

  /// Devices that answer a search of their own on the network (WiZ, LIFX,
  /// Govee), as each search ends.
  Stream<List<ProbedDevice>> search() async* {
    final udp = this.udp;
    if (udp == null) return;
    final found = <ProbedDevice>[];
    Future<List<ProbedDevice>> quiet(Future<List<ProbedDevice>> f) =>
        f.catchError((Object _) => const <ProbedDevice>[]);
    final http = requests;
    final searches = [
      quiet(wizDiscover(udp).then((l) => l.map(fromWiz).toList())),
      if (http != null) ...[
        quiet(rokuDiscover(udp, http).then((l) => l.map(fromRoku).toList())),
        quiet(sonosDiscover(udp, http).then((l) => l.map(fromSonos).toList())),
        quiet(_searchSamsung(udp, http)),
        quiet(_searchLg(udp, http)),
      ],
      quiet(lifxDiscover(udp).then((l) => l.map(fromLifx).toList())),
      quiet(goveeDiscover(udp).then((l) => l.map(fromGovee).toList())),
    ];
    for (final s in searches) {
      found.addAll(await s);
      yield List.unmodifiable(found);
    }
  }

  static ProbedDevice fromRoku(
    ({String host, String serial, String? name, String? model}) r,
  ) => ProbedDevice(
    brand: 'Roku',
    name: r.name,
    device: ConfiguredDevice(
      adapter: 'roku',
      id: r.serial,
      host: r.host,
      model: r.model,
      label: r.name ?? 'Roku',
    ),
  );

  static ProbedDevice fromSonos(
    ({String host, String id, String? room, String? model}) p,
  ) => ProbedDevice(
    brand: 'Sonos',
    name: p.room,
    device: ConfiguredDevice(
      adapter: 'sonos',
      id: p.id,
      host: p.host,
      model: p.model,
      label: p.room ?? 'Sonos',
    ),
  );

  static ProbedDevice fromSamsung(
    String host,
    ({String id, String? name, String? model, String? mac}) t,
  ) => ProbedDevice(
    brand: 'Samsung',
    name: t.name,
    needsLink: true,
    device: ConfiguredDevice(
      adapter: 'samsung',
      id: t.id,
      host: host,
      model: t.model,
      label: t.name ?? 'Samsung TV',
      options: {'mac': ?t.mac},
    ),
  );

  Future<List<ProbedDevice>> _searchSamsung(
    LanUdp udp,
    LanRequests http,
  ) async {
    final out = <ProbedDevice>[];
    for (final f in await ssdpSearch(
      udp,
      'urn:samsung.com:device:RemoteControlReceiver:1',
    )) {
      final t = await samsungProbe(http, f.host);
      if (t != null) out.add(fromSamsung(f.host, t));
    }
    return out;
  }

  Future<List<ProbedDevice>> _searchLg(LanUdp udp, LanRequests http) async {
    final out = <ProbedDevice>[];
    for (final f in await ssdpSearch(
      udp,
      'urn:lge-com:service:webos-second-screen:1',
    )) {
      // `uuid:…::urn:…` → the TV's uuid.
      final id = (f.usn ?? f.host).split('::').first.replaceFirst('uuid:', '');
      String? name;
      if (f.location case final location?) {
        try {
          final r = await http.send('GET', Uri.parse(location));
          name = xmlText(r.text, 'friendlyName');
        } on AppFailure {
          // The name is a nicety.
        }
      }
      out.add(
        ProbedDevice(
          brand: 'LG',
          name: name,
          needsLink: true,
          device: ConfiguredDevice(
            adapter: 'lg',
            id: id.toLowerCase(),
            host: f.host,
            label: name ?? 'LG TV',
          ),
        ),
      );
    }
    return out;
  }

  static ProbedDevice fromWiz(WizFound w) => ProbedDevice(
    brand: 'WiZ',
    device: ConfiguredDevice(
      adapter: 'wiz',
      id: w.mac,
      host: w.host,
      model: w.module,
      label: 'WiZ',
    ),
  );

  static ProbedDevice fromLifx(({String host, String mac, String? label}) l) =>
      ProbedDevice(
        brand: 'LIFX',
        name: l.label?.isEmpty ?? true ? null : l.label,
        device: ConfiguredDevice(
          adapter: 'lifx',
          id: l.mac,
          host: l.host,
          label: l.label?.isEmpty ?? true ? 'LIFX' : l.label,
        ),
      );

  static ProbedDevice fromGovee(({String host, String id, String? sku}) g) =>
      ProbedDevice(
        brand: 'Govee',
        device: ConfiguredDevice(
          adapter: 'govee',
          id: g.id,
          host: g.host,
          model: g.sku,
          label: g.sku == null ? 'Govee' : 'Govee ${g.sku}',
        ),
      );

  /// One try at pairing with [found] (asked again until it works or the
  /// person gives up): the secret to keep, and the device as it now says
  /// it is. `null` while the button is not pressed.
  Future<({String secret, ConfiguredDevice device})?> link(
    ProbedDevice found,
  ) async {
    final d = found.device;
    ({String secret, ConfiguredDevice device})? got(String? secret) =>
        secret == null ? null : (secret: secret, device: d);
    final http = requests, ws = sockets;
    switch (d.adapter) {
      case 'hue':
        return got(await hueLink(_http, d.host));
      case 'nanoleaf' when http != null:
        return got(await nanoleafLink(http, d.host));
      case 'samsung' when ws != null:
        return got(await samsungLink(ws, d.host));
      case 'dirigera' when http != null:
        final pairing = _pairings[found] ??= DirigeraPairing(http, d.host);
        return got(await pairing.tryLink());
      case 'lg' when ws != null:
        final r = await lgLink(ws, d.host);
        if (r == null) return null;
        // Its MAC, for turning it on later.
        return (
          secret: r.key,
          device: r.mac == null
              ? d
              : d.copyWith(options: {...d.options, 'mac': r.mac!}),
        );
    }
    return null;
  }

  /// A hub's pairing, kept between tries.
  static final _pairings = Expando<DirigeraPairing>();

  /// Who the TP-Link device [found] is with [account] (Tapo, else Kasa over
  /// KLAP); `null` when it is neither. Throws `AppFailure(authentication)`
  /// for a wrong account.
  Future<ProbedDevice?> checkAccount(
    ProbedDevice found,
    TpLinkAccount account,
  ) async {
    final klap = this.klap;
    if (klap == null) return null;
    final host = found.device.host;
    final tapo = await tapoIdentify(klap, host, account);
    if (tapo != null) {
      return ProbedDevice(
        brand: 'Tapo',
        name: tapo.name,
        needsAccount: true,
        device: ConfiguredDevice(
          adapter: 'tapo',
          id: tapo.id,
          host: host,
          model: tapo.model,
          label: tapo.name ?? tapo.model ?? 'Tapo',
        ),
      );
    }
    final answer = await KlapKasaTransport(klap, account).send(host, {
      'system': {'get_sysinfo': <String, Object?>{}},
    });
    final sysinfo = (answer['system'] as Map?)?['get_sysinfo'];
    final kasa = sysinfo is Map
        ? fromKasa(host, sysinfo.cast<String, Object?>())
        : null;
    if (kasa == null) return null;
    return ProbedDevice(
      brand: 'Kasa',
      name: kasa.name,
      needsAccount: true,
      device: kasa.device.copyWith(options: {'protocol': 'klap'}),
    );
  }

  /// A Yeelight that answered the search.
  static ProbedDevice fromYeelight(YeelightFound bulb) => ProbedDevice(
    brand: 'Yeelight',
    name: bulb.name.isEmpty ? null : bulb.name,
    device: ConfiguredDevice(
      adapter: 'yeelight',
      id: bulb.id,
      host: bulb.host,
      model: bulb.model,
      label: bulb.name.isEmpty ? 'Yeelight' : bulb.name,
    ),
  );

  /// A Bluetooth sensor heard nearby; `null` when its format is unknown.
  static ProbedDevice? fromBle(BleAdvert advert) {
    final r = parseAdvert(advert);
    if (r == null) return null;
    String n(double v) => v.toStringAsFixed(1);
    return ProbedDevice(
      brand: 'Bluetooth',
      name: advert.name,
      detail: [
        if (r.temperature case final t?) '${n(t)} °C',
        if (r.humidity case final h?) '${h.round()} %',
        if (r.illuminance case final lx?) '${lx.round()} lx',
        if (r.battery case final b?) '🔋 $b %',
      ].join(' · '),
      device: ConfiguredDevice(
        adapter: 'ble',
        id: advert.id,
        host: advert.address,
        model: r.model,
        label: advert.name ?? r.model,
      ),
    );
  }

  /// A Kasa device by its `get_sysinfo`; `null` without a MAC.
  static ProbedDevice? fromKasa(String host, Map<String, Object?> sysinfo) {
    final mac = kasaMac(sysinfo);
    if (mac == null) return null;
    final alias = sysinfo['alias'] as String?;
    return ProbedDevice(
      brand: 'Kasa',
      name: alias,
      device: ConfiguredDevice(
        adapter: 'kasa',
        id: mac,
        host: host,
        model: sysinfo['model'] as String?,
        label: alias ?? 'Kasa',
      ),
    );
  }

  /// A service found by mDNS: ESPHome tells who it is in its announcement.
  Future<ProbedDevice?> probeService(LanService service) async {
    if (service.type == LanService.nanoleafType) {
      final id = service.txt['id'] ?? service.host;
      return ProbedDevice(
        brand: 'Nanoleaf',
        name: service.name,
        needsLink: true,
        device: ConfiguredDevice(
          adapter: 'nanoleaf',
          id: id.toLowerCase().replaceAll(RegExp('[^0-9a-z]'), ''),
          host: service.host,
          model: service.txt['md'],
          label: service.name,
        ),
      );
    }
    if (service.type == LanService.dirigeraType) {
      return _dirigera(service.host, service.txt['uuid'] ?? service.name, null);
    }
    if (service.type == LanService.sonoffType) {
      final id = service.txt['id'];
      if (id == null || id.isEmpty) return _probeSonoff(service.host);
      return ProbedDevice(
        brand: 'Sonoff',
        device: ConfiguredDevice(
          adapter: 'sonoff',
          id: id,
          host: service.host,
          model: service.txt['type'],
          label: 'Sonoff',
        ),
      );
    }
    if (!service.isEsphome) return probe(service.host);
    final mac = service.txt['mac'];
    if (mac == null || mac.isEmpty) return probeEsphome(service.host);
    final name = service.txt['friendly_name'] ?? service.name;
    return ProbedDevice(
      brand: 'ESPHome',
      name: name,
      needsKey: (service.txt['api_encryption'] ?? '').isNotEmpty,
      device: ConfiguredDevice(
        adapter: 'esphome',
        id: normalizeMac(mac),
        host: service.host,
        model: service.txt['board'],
        label: name,
      ),
    );
  }

  /// Connects to the ESPHome API at [host] (with [key], base64): who it is.
  /// Without a key, a device that wants one comes back with [needsKey] and
  /// no id yet. Throws [EsphomeKeyError] for a wrong key.
  Future<ProbedDevice?> probeEsphome(String host, {String? key}) async {
    final Uint8List? psk;
    try {
      psk = key == null ? null : base64.decode(key.trim());
    } on FormatException {
      throw const EsphomeKeyError('wrong'); // not base64
    }
    if (psk != null && psk.length != 32) throw const EsphomeKeyError('wrong');
    final EsphomeClient client;
    try {
      client = await EsphomeClient.connect(_esphome, host, psk: psk);
    } on EsphomeKeyError catch (e) {
      if (e.reason == 'required' && key == null) {
        return ProbedDevice(
          brand: 'ESPHome',
          needsKey: true,
          device: ConfiguredDevice(adapter: 'esphome', id: '', host: host),
        );
      }
      rethrow;
    } on Object {
      return null;
    }
    final info = client.info;
    await client.close();
    final name = info.friendlyName.isNotEmpty ? info.friendlyName : info.name;
    return ProbedDevice(
      brand: 'ESPHome',
      name: name,
      needsKey: key != null,
      device: ConfiguredDevice(
        adapter: 'esphome',
        id: normalizeMac(info.mac),
        host: host,
        model: info.model.isEmpty ? null : info.model,
        label: name,
      ),
    );
  }

  Future<ProbedDevice?> probe(String host) async {
    final shelly = parseShellyInfo(await _quiet(host, '/shelly'));
    if (shelly != null) {
      return ProbedDevice(
        brand: 'Shelly',
        name: shelly.name,
        needsPassword: shelly.auth,
        device: ConfiguredDevice(
          adapter: 'shelly',
          id: shelly.mac,
          host: host,
          model: shelly.model,
          label: shelly.name ?? shelly.model,
        ),
      );
    }
    final wled = parseWledInfo(await _quiet(host, '/json/info'));
    if (wled != null) {
      return ProbedDevice(
        brand: 'WLED',
        name: wled.name,
        device: ConfiguredDevice(
          adapter: 'wled',
          id: wled.mac,
          host: host,
          model: 'WLED ${wled.version}'.trim(),
          label: wled.name ?? 'WLED',
        ),
      );
    }
    final hue = parseHueInfo(await _quiet(host, '/api/config'));
    if (hue != null) {
      return ProbedDevice(
        brand: 'Hue',
        name: hue.name,
        needsLink: true,
        device: ConfiguredDevice(
          adapter: 'hue',
          id: hue.id,
          host: host,
          model: hue.model,
          label: hue.name,
        ),
      );
    }
    final tasmota = parseTasmotaInfo(
      await _quiet(host, '/cm', {'cmnd': 'Status 0'}),
    );
    if (tasmota != null) {
      return ProbedDevice(
        brand: 'Tasmota',
        name: tasmota.name,
        device: ConfiguredDevice(
          adapter: 'tasmota',
          id: tasmota.mac,
          host: host,
          model: tasmota.module,
          label: tasmota.name ?? 'Tasmota',
        ),
      );
    }
    return null;
  }

  /// An address typed in: a web device, a Kasa, a WiZ, else an ESPHome
  /// device.
  Future<ProbedDevice?> probeAddress(String host) async =>
      await probe(host) ??
      await _probeKasa(host) ??
      await _probeWiz(host) ??
      await _probeSonoff(host) ??
      await _probeNanoleaf(host) ??
      await _probeMedia(host) ??
      await _probeHub(host) ??
      await probeEsphome(host);

  /// A DIRIGERA hub, or a TP-Link device on KLAP (Tapo, newer Kasa: who it
  /// is shows once the account is given).
  Future<ProbedDevice?> _probeHub(String host) async {
    final http = requests;
    if (http == null) return null;
    if (await dirigeraProbe(http, host)) return _dirigera(host, host, null);
    if (await klapProbe(http, host)) {
      return ProbedDevice(
        brand: 'Tapo',
        needsAccount: true,
        device: ConfiguredDevice(
          adapter: 'tapo',
          id: host.replaceAll('.', ''),
          host: host,
          label: 'Tapo',
        ),
      );
    }
    return null;
  }

  static ProbedDevice _dirigera(String host, String id, String? name) =>
      ProbedDevice(
        brand: 'DIRIGERA',
        name: name,
        needsLink: true,
        device: ConfiguredDevice(
          adapter: 'dirigera',
          id: id.toLowerCase().replaceAll(RegExp('[^0-9a-z]'), ''),
          host: host,
          label: name ?? 'DIRIGERA',
        ),
      );

  /// A Roku, a Samsung TV or a Sonos at [host].
  Future<ProbedDevice?> _probeMedia(String host) async {
    final http = requests;
    if (http == null) return null;
    if (await rokuProbe(http, host) case final r?) return fromRoku(r);
    if (await samsungProbe(http, host) case final t?) {
      return fromSamsung(host, t);
    }
    if (await sonosProbe(http, host) case final p?) {
      return fromSonos((host: host, id: p.id, room: p.room, model: p.model));
    }
    return null;
  }

  Future<ProbedDevice?> _probeSonoff(String host) async {
    final http = requests;
    final s = http == null ? null : await sonoffProbe(http, host);
    if (s == null) return null;
    return ProbedDevice(
      brand: 'Sonoff',
      device: ConfiguredDevice(
        adapter: 'sonoff',
        id: s.id,
        host: host,
        model: s.firmware == null ? null : 'DIY ${s.firmware}',
        label: 'Sonoff',
      ),
    );
  }

  Future<ProbedDevice?> _probeNanoleaf(String host) async {
    final http = requests;
    if (http == null || !await nanoleafProbe(http, host)) return null;
    return ProbedDevice(
      brand: 'Nanoleaf',
      needsLink: true,
      device: ConfiguredDevice(
        adapter: 'nanoleaf',
        id: host.replaceAll('.', ''),
        host: host,
        label: 'Nanoleaf',
      ),
    );
  }

  Future<ProbedDevice?> _probeWiz(String host) async {
    final udp = this.udp;
    if (udp == null) return null;
    final w = await wizProbe(udp, host);
    return w == null ? null : fromWiz(w);
  }

  Future<ProbedDevice?> _probeKasa(String host) async {
    final kasa = this.kasa;
    if (kasa == null) return null;
    try {
      final answer = await kasa.send(host, {
        'system': {'get_sysinfo': <String, Object?>{}},
      });
      final sysinfo = answer['system'];
      return sysinfo is Map
          ? DeviceProbe.fromKasa(host, {
              for (final e in (sysinfo['get_sysinfo'] as Map? ?? {}).entries)
                '${e.key}': e.value,
            })
          : null;
    } on Object {
      return null;
    }
  }

  Future<Object?> _quiet(
    String host,
    String path, [
    Map<String, Object?> query = const {},
  ]) async {
    try {
      return await _http.get(host, path, query: query);
    } on Object {
      return null;
    }
  }
}

final deviceProbeProvider = Provider<DeviceProbe>(
  (ref) => DeviceProbe(
    ref.watch(lanHttpProvider),
    ref.watch(esphomeConnectorProvider),
    kasa: ref.watch(kasaTransportProvider),
    udp: ref.watch(lanUdpProvider),
    requests: ref.watch(lanRequestsProvider),
    sockets: ref.watch(lanSocketsProvider),
    klap: ref.watch(klapClientProvider),
  ),
);
