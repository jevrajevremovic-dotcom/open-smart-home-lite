import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_http.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// Shelly relays, plugs, dimmers and roller shutters, over their local
/// HTTP API: the RPC API of Gen2 and later (Plus, Pro, Gen3, Gen4) and the
/// original API of Gen1.
///
/// One physical Shelly gives one device per channel (`switch0`, `cover0`,
/// `relay1`…), plus a power meter where the channel measures power.
/// A device with a password is asked with HTTP Digest (Gen2+, user
/// `admin`) or Basic (Gen1, user `admin`); [passwords] looks it up.
class ShellyAdapter extends PolledAdapter {
  ShellyAdapter(this._http, {this.passwords, super.pollEvery});

  final LanHttp _http;

  /// The password of a device by [ConfiguredDevice.key].
  final Future<String?> Function(String key)? passwords;
  final Map<String, String?> _passwords = {};

  /// API generation by [ConfiguredDevice.key] (1, or 2 for RPC).
  final Map<String, int> _gen = {};

  /// Device configuration (names, modes), read once per device.
  final Map<String, Map<String, Object?>> _config = {};

  @override
  String get id => 'shelly';

  @override
  void configure(List<ConfiguredDevice> devices) {
    _passwords.clear(); // one may have changed
    super.configure(devices);
  }

  Future<LanAuth?> _auth(ConfiguredDevice device, int gen) async {
    if (!device.secured) return null;
    final password = _passwords[device.key] ??= await passwords?.call(
      device.key,
    );
    if (password == null) return null;
    return gen >= 2
        ? LanAuth.digest('admin', password)
        : LanAuth.basic('admin', password);
  }

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    // `/shelly` answers without a password.
    final gen = _gen[device.key] ??= shellyGeneration(
      await _http.get(device.host, '/shelly'),
    );
    final auth = await _auth(device, gen);
    Future<Map<String, Object?>> get(String path) async =>
        _map(await _http.get(device.host, path, auth: auth));
    if (gen >= 2) {
      final config = _config[device.key] ??= await get('/rpc/Shelly.GetConfig');
      return parseShellyGen2(
        device,
        config,
        await get('/rpc/Shelly.GetStatus'),
      );
    }
    final settings = _config[device.key] ??= await get('/settings');
    return parseShellyGen1(device, settings, await get('/status'));
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final (component, index) = _channelOf(channel.id);
    final gen = _gen[device.key] ?? 2;
    final (path, query) = gen >= 2
        ? _gen2Call(component, index, channel, command)
        : _gen1Call(component, index, channel, command);
    await _http.get(
      device.host,
      path,
      query: query,
      auth: await _auth(device, gen),
    );
  }

  (String, Map<String, Object?>) _gen2Call(
    String component,
    int id,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) => switch ((component, command)) {
    ('switch', TurnOn()) => ('/rpc/Switch.Set', {'id': id, 'on': true}),
    ('switch', TurnOff()) => ('/rpc/Switch.Set', {'id': id, 'on': false}),
    ('switch', Toggle()) => ('/rpc/Switch.Toggle', {'id': id}),
    ('light', TurnOn()) => ('/rpc/Light.Set', {'id': id, 'on': true}),
    ('light', TurnOff()) => ('/rpc/Light.Set', {'id': id, 'on': false}),
    ('light', Toggle()) => ('/rpc/Light.Toggle', {'id': id}),
    ('light', SetBrightness(:final percent)) => (
      '/rpc/Light.Set',
      {'id': id, 'on': percent > 0, if (percent > 0) 'brightness': percent},
    ),
    ('cover', OpenCover()) => ('/rpc/Cover.Open', {'id': id}),
    ('cover', CloseCover()) => ('/rpc/Cover.Close', {'id': id}),
    ('cover', StopCover()) => ('/rpc/Cover.Stop', {'id': id}),
    ('cover', SetCoverPosition(:final percent)) => (
      '/rpc/Cover.GoToPosition',
      {'id': id, 'pos': percent},
    ),
    _ => _unsupported(channel, command),
  };

  (String, Map<String, Object?>) _gen1Call(
    String component,
    int id,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) => switch ((component, command)) {
    ('relay' || 'light', TurnOn()) => ('/$component/$id', {'turn': 'on'}),
    ('relay' || 'light', TurnOff()) => ('/$component/$id', {'turn': 'off'}),
    ('relay' || 'light', Toggle()) => ('/$component/$id', {'turn': 'toggle'}),
    ('light', SetBrightness(:final percent)) => (
      '/light/$id',
      percent > 0 ? {'turn': 'on', 'brightness': percent} : {'turn': 'off'},
    ),
    ('roller', OpenCover()) => ('/roller/$id', {'go': 'open'}),
    ('roller', CloseCover()) => ('/roller/$id', {'go': 'close'}),
    ('roller', StopCover()) => ('/roller/$id', {'go': 'stop'}),
    ('roller', SetCoverPosition(:final percent)) => (
      '/roller/$id',
      {'go': 'to_pos', 'roller_pos': percent},
    ),
    _ => _unsupported(channel, command),
  };

  static Never _unsupported(SmartHomeDevice channel, DeviceCommand command) =>
      throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for ${channel.id}',
      );

  /// `shelly:<mac>:switch1` → (`switch`, 1).
  static (String, int) _channelOf(String deviceId) {
    final m = RegExp(r'([a-z]+)(\d+)$').firstMatch(deviceId.split(':').last);
    if (m == null) {
      throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: 'not a channel: $deviceId',
      );
    }
    return (m.group(1)!, int.parse(m.group(2)!));
  }
}

/// What `GET /shelly` says about a device, if it is a Shelly ([auth]: it
/// asks for a password).
typedef ShellyInfo = ({
  String mac,
  String model,
  String? name,
  int gen,
  bool auth,
});

ShellyInfo? parseShellyInfo(Object? json) {
  final j = _map(json);
  final mac = j['mac'];
  if (mac is! String || (j['gen'] == null && j['type'] == null)) return null;
  final gen = shellyGeneration(j);
  return (
    mac: normalizeMac(mac),
    model: (j['app'] ?? j['model'] ?? j['type'] ?? 'Shelly') as String,
    name: j['name'] as String?,
    gen: gen,
    auth: j['auth_en'] == true || j['auth'] == true,
  );
}

int shellyGeneration(Object? json) => switch (_map(json)['gen']) {
  final int g => g,
  _ => 1,
};

/// `A8:03:2A:B1:23:45` → `a8032ab12345`.
String normalizeMac(String mac) =>
    mac.toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');

List<SmartHomeDevice> parseShellyGen2(
  ConfiguredDevice device,
  Map<String, Object?> config,
  Map<String, Object?> status,
) {
  final deviceName =
      _map(_map(config['sys'])['device'])['name'] as String? ??
      device.label ??
      device.model ??
      'Shelly';
  final metadata = DeviceMetadata(
    signalStrength: _num(_map(status['wifi'])['rssi']),
    signalUnit: 'dBm',
    batteryPercent: _num(
      _map(_map(status['devicepower:0'])['battery'])['percent'],
    )?.round(),
  );
  final keys = status.keys.where((k) => k.contains(':')).toList()..sort();
  int countOf(String component) =>
      keys.where((k) => k.startsWith('$component:')).length;
  final out = <SmartHomeDevice>[];

  for (final key in keys) {
    final [component, indexText] = key.split(':');
    final index = int.tryParse(indexText);
    if (index == null) continue;
    final s = _map(status[key]);
    final own = _map(config[key])['name'] as String?;
    final name =
        own ??
        (countOf(component) > 1 ? '$deviceName ${index + 1}' : deviceName);
    SmartHomeDevice make(
      String suffix,
      DeviceKind kind,
      Set<Capability> capabilities,
      DeviceState state, {
      String? nameOverride,
    }) => SmartHomeDevice(
      id: '${device.key}:$suffix',
      sourceId: key,
      deviceId: device.key,
      name: nameOverride ?? name,
      kind: kind,
      protocol: DeviceProtocol.wifi,
      manufacturer: 'Shelly',
      model: device.model,
      available: true,
      capabilities: capabilities,
      state: state,
      metadata: metadata,
    );
    final power = _num(s['apower']);

    switch (component) {
      case 'switch':
        final on = s['output'] == true;
        out.add(
          make(
            'switch$index',
            (device.model ?? '').toLowerCase().contains('plug')
                ? DeviceKind.outlet
                : DeviceKind.switchDevice,
            {Capability.power},
            DeviceState(raw: on ? 'on' : 'off', isOn: on),
          ),
        );
      case 'light':
        final on = s['output'] == true;
        final brightness = _num(s['brightness'])?.round();
        out.add(
          make(
            'light$index',
            DeviceKind.dimmableLight,
            {Capability.power, Capability.brightness},
            DeviceState(
              raw: on ? 'on' : 'off',
              isOn: on,
              brightnessPercent: on ? brightness : null,
            ),
          ),
        );
      case 'cover':
        final pos = _num(s['current_pos'])?.round();
        final positioning = s['pos_control'] == true;
        out.add(
          make(
            'cover$index',
            DeviceKind.blind,
            {
              Capability.open,
              Capability.close,
              Capability.stop,
              if (positioning) Capability.position,
            },
            DeviceState(
              raw: s['state'] as String? ?? 'unknown',
              coverState: _coverState(s['state'], pos),
              position: positioning ? pos : null,
            ),
          ),
        );
      case 'temperature':
        final t = _num(s['tC']);
        out.add(
          make(
            'temperature$index',
            DeviceKind.temperatureSensor,
            {Capability.currentTemperature},
            DeviceState(
              raw: '$t',
              numericValue: t,
              currentTemperature: t,
              unit: '°C',
            ),
          ),
        );
        continue;
      case 'humidity':
        final h = _num(s['rh']);
        out.add(
          make(
            'humidity$index',
            DeviceKind.humiditySensor,
            {Capability.humidity},
            DeviceState(
              raw: '$h',
              numericValue: h,
              currentHumidity: h,
              unit: '%',
            ),
          ),
        );
        continue;
      case 'pm1':
        break;
      default:
        continue;
    }
    if (power != null) {
      out.add(
        make(
          '$component${index}_power',
          DeviceKind.powerMeter,
          {Capability.powerConsumption},
          DeviceState(raw: '$power', numericValue: power, unit: 'W'),
          nameOverride: '$name · W',
        ),
      );
    }
  }
  return out;
}

List<SmartHomeDevice> parseShellyGen1(
  ConfiguredDevice device,
  Map<String, Object?> settings,
  Map<String, Object?> status,
) {
  final deviceName =
      settings['name'] as String? ?? device.label ?? device.model ?? 'Shelly';
  final roller = settings['mode'] == 'roller';
  final metadata = DeviceMetadata(
    signalStrength: _num(_map(status['wifi_sta'])['rssi']),
    signalUnit: 'dBm',
    batteryPercent: _num(_map(status['bat'])['value'])?.round(),
  );
  final out = <SmartHomeDevice>[];
  List<Map<String, Object?>> list(Object? l) => [
    for (final e in (l is List ? l : const <Object?>[])) _map(e),
  ];
  final meters = list(status['meters']);

  void add(
    String suffix,
    String name,
    DeviceKind kind,
    Set<Capability> capabilities,
    DeviceState state,
  ) => out.add(
    SmartHomeDevice(
      id: '${device.key}:$suffix',
      sourceId: suffix,
      deviceId: device.key,
      name: name,
      kind: kind,
      protocol: DeviceProtocol.wifi,
      manufacturer: 'Shelly',
      model: device.model,
      available: true,
      capabilities: capabilities,
      state: state,
      metadata: metadata,
    ),
  );
  String nameOf(String listKey, int i, int count) =>
      list(settings[listKey]).elementAtOrNull(i)?['name'] as String? ??
      (count > 1 ? '$deviceName ${i + 1}' : deviceName);
  void addPower(int i, String name) {
    final power = _num(meters.elementAtOrNull(i)?['power']);
    if (power == null) return;
    add('meter${i}_power', '$name · W', DeviceKind.powerMeter, {
      Capability.powerConsumption,
    }, DeviceState(raw: '$power', numericValue: power, unit: 'W'));
  }

  if (roller) {
    final rollers = list(status['rollers']);
    final rollerSettings = list(settings['rollers']);
    for (final (i, r) in rollers.indexed) {
      final positioning =
          rollerSettings.elementAtOrNull(i)?['positioning'] == true;
      final pos = _num(r['current_pos'])?.round();
      final name = nameOf('rollers', i, rollers.length);
      add(
        'roller$i',
        name,
        DeviceKind.blind,
        {
          Capability.open,
          Capability.close,
          Capability.stop,
          if (positioning) Capability.position,
        },
        DeviceState(
          raw: r['state'] as String? ?? 'unknown',
          coverState: _coverState(r['state'], pos),
          position: positioning ? pos : null,
        ),
      );
      addPower(i, name);
    }
    return out;
  }

  final relays = list(status['relays']);
  for (final (i, r) in relays.indexed) {
    final on = r['ison'] == true;
    final name = nameOf('relays', i, relays.length);
    add(
      'relay$i',
      name,
      (device.model ?? '').toUpperCase().startsWith('SHPLG')
          ? DeviceKind.outlet
          : DeviceKind.switchDevice,
      {Capability.power},
      DeviceState(raw: on ? 'on' : 'off', isOn: on),
    );
    addPower(i, name);
  }
  final lights = list(status['lights']);
  for (final (i, l) in lights.indexed) {
    final on = l['ison'] == true;
    final brightness = _num(l['brightness'] ?? l['gain'])?.round();
    final name = nameOf('lights', i, lights.length);
    add(
      'light$i',
      name,
      DeviceKind.dimmableLight,
      {Capability.power, Capability.brightness},
      DeviceState(
        raw: on ? 'on' : 'off',
        isOn: on,
        brightnessPercent: on ? brightness : null,
      ),
    );
    addPower(i, name);
  }
  return out;
}

CoverState? _coverState(Object? state, int? pos) => switch (state) {
  'opening' => CoverState.opening,
  'closing' => CoverState.closing,
  'open' => CoverState.open,
  'closed' || 'close' => CoverState.closed,
  _ when pos != null => pos > 0 ? CoverState.open : CoverState.closed,
  _ => null,
};

Map<String, Object?> _map(Object? json) => json is Map
    ? {
        for (final e in json.entries)
          if (e.key is String) e.key as String: e.value,
      }
    : const {};

double? _num(Object? v) => v is num ? v.toDouble() : null;
