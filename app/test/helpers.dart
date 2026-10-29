import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:open_smart_home_lite/core/config/app_config.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/features/add_device/data/lan_discovery.dart';
import 'package:open_smart_home_lite/features/devices/data/local/esphome/esphome_client.dart';
import 'package:open_smart_home_lite/features/devices/data/local/kasa_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_http.dart';
import 'package:open_smart_home_lite/features/devices/data/local/yeelight_adapter.dart';
import 'package:open_smart_home_lite/core/platform/speech_output.dart';
import 'package:open_smart_home_lite/core/storage/app_preferences.dart';
import 'package:open_smart_home_lite/core/storage/credential_store.dart';
import 'package:open_smart_home_lite/features/alerts/alert_notifications.dart';
import 'package:open_smart_home_lite/features/automations/application/automation_engine.dart';
import 'package:open_smart_home_lite/features/automations/application/background_run.dart';
import 'package:open_smart_home_lite/features/app_lock/application/app_lock.dart';
import 'package:open_smart_home_lite/features/app_lock/data/device_auth.dart';
import 'package:open_smart_home_lite/features/clap/clap_platform.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/ble/ble_advert.dart';
import 'package:open_smart_home_lite/features/devices/data/local/ble/ble_scanner.dart';
import 'package:open_smart_home_lite/features/devices/data/local/demo_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/device_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/data/approach_platform.dart';
import 'package:open_smart_home_lite/features/media/now_playing_notification.dart';
import 'package:open_smart_home_lite/features/shortcuts/app_shortcuts.dart';
import 'package:open_smart_home_lite/features/shortcuts/home_screen_widget.dart';
import 'package:open_smart_home_lite/features/shortcuts/quick_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Devices of a test home. Commands are recorded in [sent]; [onCommand]
/// may return the device's new state (else nothing changes).
class TestAdapter extends DeviceAdapter {
  TestAdapter(List<SmartHomeDevice> devices, {this.onCommand})
    : _devices = {for (final d in devices) d.id: d};

  final Map<String, SmartHomeDevice> _devices;
  final SmartHomeDevice? Function(SmartHomeDevice, DeviceCommand)? onCommand;
  final List<(String, DeviceCommand)> sent = [];
  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();

  @override
  String get id => 'test';

  @override
  Stream<List<SmartHomeDevice>> get devices => _controller.stream;

  @override
  List<SmartHomeDevice> get current => List.unmodifiable(_devices.values);

  @override
  Future<void> start() async {}

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async {
    sent.add((device.id, command));
    final next = onCommand?.call(device, command);
    if (next != null) update(next);
  }

  /// A device changed (or appeared) by itself.
  void update(SmartHomeDevice device) {
    _devices[device.id] = device;
    _controller.add(current);
  }

  @override
  Future<void> dispose() => _controller.close();
}

/// Devices on a pretend local network: answers by `host` and `path`
/// (a value, or a function of the query/body); records every request.
/// A host that is not in [answers] does not answer; one in [passwords]
/// answers 401 without that password (except `/shelly`, as real ones).
class FakeLanHttp implements LanHttp {
  FakeLanHttp(this.answers, {this.passwords = const {}});

  final Map<String, Map<String, Object? Function(Map<String, Object?>)>>
  answers;
  final Map<String, String> passwords;
  final List<(String host, String path, Object? data)> requests = [];

  Object? _answer(
    String host,
    String path,
    Map<String, Object?> data,
    LanAuth? auth,
  ) {
    requests.add((host, path, data));
    final password = passwords[host];
    if (password != null && path != '/shelly' && auth?.password != password) {
      throw const AppFailure(FailureKind.authentication, debugMessage: '401');
    }
    final answer = answers[host]?[path];
    if (answer == null) {
      throw const AppFailure(FailureKind.network, debugMessage: 'no answer');
    }
    return answer(data);
  }

  @override
  Future<Object?> get(
    String host,
    String path, {
    Map<String, Object?> query = const {},
    LanAuth? auth,
  }) async => _answer(host, path, query, auth);

  @override
  Future<Object?> post(
    String host,
    String path,
    Object? body, {
    LanAuth? auth,
  }) async => _answer(host, path, {'body': body}, auth);

  @override
  Future<Object?> put(String host, String path, Object? body) async =>
      _answer(host, 'PUT $path', {'body': body}, null);
}

/// Yeelight bulbs on a pretend network: [bulbs] answer the search, and
/// [answer] the commands (method, params → result).
class FakeYeelight implements YeelightTransport {
  FakeYeelight({this.bulbs = const [], this.answer});

  final List<YeelightFound> bulbs;
  final List<Object?> Function(String host, String method, List<Object?> p)?
  answer;
  final List<(String, String, List<Object?>)> calls = [];

  @override
  Future<List<Object?>> call(
    String host,
    String method,
    List<Object?> params,
  ) async {
    calls.add((host, method, params));
    final a = answer;
    if (a == null) {
      throw const AppFailure(FailureKind.network, debugMessage: 'no bulb');
    }
    return a(host, method, params);
  }

  @override
  Stream<List<YeelightFound>> discover() =>
      bulbs.isEmpty ? const Stream.empty() : Stream.value(bulbs);
}

/// Kasa devices on a pretend network.
class FakeKasa implements KasaTransport {
  FakeKasa({this.found = const [], this.answer});

  final List<KasaFound> found;
  final Map<String, Object?> Function(String host, Map<String, Object?> r)?
  answer;
  final List<(String, Map<String, Object?>)> requests = [];

  @override
  Future<Map<String, Object?>> send(
    String host,
    Map<String, Object?> request,
  ) async {
    requests.add((host, request));
    final a = answer;
    if (a == null) {
      throw const AppFailure(FailureKind.network, debugMessage: 'no kasa');
    }
    return a(host, request);
  }

  @override
  Stream<List<KasaFound>> discover() =>
      found.isEmpty ? const Stream.empty() : Stream.value(found);
}

/// Bluetooth advertisements the test sends with [hear].
class FakeBleScanner implements BleScanner {
  FakeBleScanner({this.supported = true, this.permitted = true});

  @override
  final bool supported;
  bool permitted;
  int asked = 0;
  final _adverts = StreamController<BleAdvert>.broadcast();

  void hear(BleAdvert advert) => _adverts.add(advert);

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return permitted = true;
  }

  @override
  Stream<BleAdvert> scan() => _adverts.stream;
}

/// Records the background service being started and stopped.
class FakeBackground implements BackgroundPlatform {
  FakeBackground({this.supported = true});

  @override
  final bool supported;
  bool running = false;

  @override
  Future<void> start({required String title, required String text}) async =>
      running = true;

  @override
  Future<void> stop() async => running = false;
}

/// No ESPHome device anywhere.
Future<EsphomeSocket> noEsphome(String host, int port) async =>
    throw const AppFailure(FailureKind.network, debugMessage: 'refused');

/// Finds the given services, as mDNS would.
class FakeLanDiscovery implements LanDiscovery {
  FakeLanDiscovery(this.services);

  final List<LanService> services;

  @override
  bool get isSupported => true;

  @override
  Stream<List<LanService>> browse() => Stream.value(services);
}

/// A device for [TestAdapter] (id `test:<id>`).
SmartHomeDevice testDevice(
  String id, {
  String? name,
  DeviceKind kind = DeviceKind.switchDevice,
  Set<Capability> capabilities = const {Capability.power},
  DeviceState state = const DeviceState(raw: 'off', isOn: false),
  String? roomId,
  bool available = true,
  DeviceLimits limits = DeviceLimits.none,
}) => SmartHomeDevice(
  id: 'test:$id',
  sourceId: 'test:$id',
  name: name ?? id,
  kind: kind,
  available: available,
  capabilities: capabilities,
  state: state,
  roomId: roomId,
  limits: limits,
);

/// In-memory replacement for the platform keychain/keystore.
class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> values = {};

  @override
  Future<String?> readCredential(String serverId) async => values[serverId];

  @override
  Future<void> writeCredential(
    String serverId,
    String value, {
    bool persistent = false,
  }) async => values[serverId] = value;

  @override
  Future<void> deleteCredential(String serverId) async =>
      values.remove(serverId);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// Records kiosk platform calls instead of touching platform channels.
class FakeKioskPlatform implements KioskPlatform {
  bool fullscreen = false;
  bool screenOn = false;

  @override
  Future<void> enterFullscreen() async => fullscreen = true;

  @override
  Future<void> exitFullscreen() async => fullscreen = false;

  @override
  Future<void> keepScreenOn(bool on) async => screenOn = on;

  /// `null` = system brightness.
  double? brightness;

  @override
  Future<void> setBrightness(double? level) async => brightness = level;
}

/// Overrides for running the app in tests: the demo home (answering at
/// once), [adapter]'s devices in [rooms], or the real adapters on the
/// pretend network [http]. The first-run wizard is done
/// unless [firstRun].
Future<List<Override>> testOverrides({
  InMemoryCredentialStore? credentials,
  KioskPlatform? kioskPlatform,
  Map<String, Object> preferences = const {},
  TestAdapter? adapter,
  Map<String, Room> rooms = const {},
  bool firstRun = false,
  DeviceAuth? deviceAuth,
  AppShortcutsPlatform? shortcuts,
  AlertNotifier? alerts,
  HomeScreenWidgetPlatform? homeWidget,
  NowPlayingPlatform? nowPlaying,
  ClapPlatform? clap,
  ApproachPlatform? approach,
  QuickTilesPlatform? tiles,
  SpeechOutput? speech,
  LanHttp? http,
  LanDiscovery? discovery,
  EsphomeConnector? esphome,
  YeelightTransport? yeelight,
  KasaTransport? kasa,
  BackgroundPlatform? background,
  BleScanner? ble,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    if (!firstRun) 'firstRun': '{"done":true}',
    ...preferences,
  });
  final prefs = await SharedPreferences.getInstance();
  return [
    appConfigProvider.overrideWithValue(const AppConfig(mockMode: true)),
    sharedPreferencesProvider.overrideWithValue(prefs),
    // With [http] the app's own backend runs (demo, Shelly, WLED) against
    // the pretend network.
    if (adapter != null || http == null)
      homeBackendProvider.overrideWith((ref) {
        final home = ref.read(localHomeProvider);
        final routines = ref.watch(routineAdapterProvider);
        final backend = adapter == null
            ? LocalBackend(
                [DemoAdapter(latency: Duration.zero), routines],
                rooms: demoRooms,
                home: home,
              )
            : LocalBackend([adapter, routines], rooms: rooms, home: home);
        ref.listen(localHomeProvider, (_, h) => backend.configure(h));
        backend.start();
        ref.onDispose(backend.dispose);
        return backend;
      }),
    lanHttpProvider.overrideWithValue(http ?? FakeLanHttp(const {})),
    esphomeConnectorProvider.overrideWithValue(esphome ?? noEsphome),
    yeelightTransportProvider.overrideWithValue(yeelight ?? FakeYeelight()),
    kasaTransportProvider.overrideWithValue(kasa ?? FakeKasa()),
    bleScannerProvider.overrideWithValue(
      ble ?? FakeBleScanner(supported: false),
    ),
    backgroundPlatformProvider.overrideWithValue(
      background ?? FakeBackground(supported: false),
    ),
    lanDiscoveryProvider.overrideWithValue(
      discovery ?? FakeLanDiscovery(const []),
    ),
    kioskPlatformProvider.overrideWithValue(
      kioskPlatform ?? FakeKioskPlatform(),
    ),
    credentialStoreProvider.overrideWithValue(
      credentials ?? InMemoryCredentialStore(),
    ),
    deviceAuthProvider.overrideWithValue(deviceAuth ?? FakeDeviceAuth()),
    appShortcutsPlatformProvider.overrideWithValue(
      shortcuts ?? FakeShortcuts(supported: false),
    ),
    clapPlatformProvider.overrideWithValue(
      clap ?? FakeClapPlatform(supported: false),
    ),
    approachPlatformProvider.overrideWithValue(
      approach ?? FakeApproach(supported: false),
    ),
    quickTilesPlatformProvider.overrideWithValue(
      tiles ?? FakeQuickTiles(supported: false),
    ),
    speechOutputProvider.overrideWithValue(
      speech ?? FakeSpeechOutput(supported: false),
    ),
    nowPlayingPlatformProvider.overrideWithValue(
      nowPlaying ?? FakeNowPlaying(supported: false),
    ),
    homeScreenWidgetProvider.overrideWithValue(
      homeWidget ?? FakeHomeScreenWidget(supported: false),
    ),
    alertNotifierProvider.overrideWithValue(
      alerts ?? FakeAlertNotifier(supported: false),
    ),
    ...overrides,
  ];
}

/// Records alert notifications instead of showing them.
class FakeAlertNotifier implements AlertNotifier {
  FakeAlertNotifier({this.supported = true, this.permission = true});

  @override
  final bool supported;
  bool permission;
  final Map<String, (String, String)> shown = {};
  final _taps = StreamController<NotificationTap>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> show(String deviceId, String title, String body) async =>
      shown[deviceId] = (title, body);

  /// Keys of removed notifications, in order.
  final List<String> cancelled = [];

  @override
  Future<void> cancel(String deviceId) async {
    cancelled.add(deviceId);
    shown.remove(deviceId);
  }

  void tap(String deviceId) => _taps.add(NotificationTap(deviceId));

  /// Shown messages as (title, body); details in [messageDetails].
  final List<(String?, String)> messages = [];
  final List<({String key, List<(String, String)> actions, String? payload})>
  messageDetails = [];

  @override
  Future<void> showMessage(
    String key,
    String? title,
    String body, {
    List<(String, String)> actions = const [],
    String? payload,
  }) async {
    messages.add((title, body));
    messageDetails.add((key: key, actions: actions, payload: payload));
  }

  /// Taps the last message, or one of its buttons.
  void tapMessage([String? actionId]) =>
      _taps.add(NotificationTap(messageDetails.last.payload!, actionId));
}

/// Records launcher shortcuts and lets tests "tap" one.
class FakeShortcuts implements AppShortcutsPlatform {
  FakeShortcuts({this.supported = true});

  @override
  final bool supported;
  void Function(String)? _onAction;
  List<(String, String, String)> items = const [];

  @override
  void initialize(void Function(String type) onAction) => _onAction = onAction;

  @override
  Future<void> setItems(List<(String, String, String)> items) async =>
      this.items = items;

  void tap(String type) => _onAction?.call(type);
}

/// Records what the home screen widget would show; lets tests tap it.
class FakeHomeScreenWidget implements HomeScreenWidgetPlatform {
  FakeHomeScreenWidget({this.supported = true, this.launchedWith});

  @override
  final bool supported;
  final Uri? launchedWith;
  final _clicks = StreamController<Uri?>.broadcast();
  List<(String, String)> scenes = const [];
  String emptyText = '';
  int updates = 0;

  @override
  Future<void> setScenes(
    List<(String, String)> scenes,
    String emptyText,
  ) async {
    this.scenes = scenes;
    this.emptyText = emptyText;
    updates++;
  }

  /// What each home widget kind shows (`status`, `thermostat`, `light`).
  final homeWidgets = <String, Map<String, Object?>?>{};

  @override
  Future<void> setHomeWidget(String kind, Map<String, Object?>? data) async =>
      homeWidgets[kind] = data;

  @override
  Future<Uri?> initialUri() async => launchedWith;

  @override
  Stream<Uri?> get clicks => _clicks.stream;

  void tap(Uri uri) => _clicks.add(uri);
}

/// Microphone levels driven by the test.
class FakeClapPlatform implements ClapPlatform {
  FakeClapPlatform({this.supported = true, this.permission = true});

  @override
  final bool supported;
  bool permission;
  // ignore: close_sinks, lives as long as the test
  final _levels = StreamController<double>.broadcast();
  int listeners = 0;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Stream<double> levels() {
    // ignore: close_sinks, closed by its listener's cancel
    late final StreamController<double> c;
    c = StreamController<double>(
      onListen: () {
        listeners++;
        final sub = _levels.stream.listen(c.add);
        c.onCancel = () {
          listeners--;
          return sub.cancel();
        };
      },
    );
    return c.stream;
  }

  void emit(Iterable<double> levels) => levels.forEach(_levels.add);
}

/// Front-camera movement driven by the test.
class FakeApproach implements ApproachPlatform {
  FakeApproach({this.supported = true, this.permission = true});

  @override
  final bool supported;
  bool permission;
  int listeners = 0;
  // ignore: close_sinks, lives as long as the test
  final _motion = StreamController<void>.broadcast();

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Stream<void> motion() {
    // ignore: close_sinks, closed by its listener's cancel
    late final StreamController<void> c;
    c = StreamController<void>(
      onListen: () {
        listeners++;
        final sub = _motion.stream.listen(c.add);
        c.onCancel = () {
          listeners--;
          return sub.cancel();
        };
      },
    );
    return c.stream;
  }

  void move() => _motion.add(null);
}

/// Quick Settings tiles: records what the menu would show, fakes taps.
class FakeQuickTiles implements QuickTilesPlatform {
  FakeQuickTiles({this.supported = true});

  @override
  final bool supported;
  List<QuickTileState?> shown = const [];
  final List<int> _pending = [];
  int addRequests = 0;

  // ignore: close_sinks, lives as long as the test
  final _clicks = StreamController<void>.broadcast();

  void tap(int index) {
    _pending.add(index);
    _clicks.add(null);
  }

  @override
  Future<void> update(List<QuickTileState?> tiles) async => shown = tiles;

  @override
  Future<List<int>> takePending() async {
    final p = [..._pending];
    _pending.clear();
    return p;
  }

  @override
  Stream<void> get clicks => _clicks.stream;

  @override
  Future<bool> requestAdd(int index, String label) async {
    addRequests++;
    return true;
  }
}

/// Records what would be said aloud.
class FakeSpeechOutput implements SpeechOutput {
  FakeSpeechOutput({this.supported = true});

  @override
  final bool supported;
  final List<String> said = [];

  @override
  Future<bool> speak(String text, {required String languageTag}) async {
    said.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}
}

class FakeNowPlaying implements NowPlayingPlatform {
  FakeNowPlaying({this.supported = true});

  @override
  final bool supported;
  final _presses = StreamController<String>.broadcast();

  /// What the notification shows; `null` = hidden.
  ({String title, String text, bool playing})? shown;

  @override
  Future<void> show({
    required String title,
    required String text,
    required bool playing,
    required Map<String, String> labels,
  }) async => shown = (title: title, text: text, playing: playing);

  @override
  Future<void> hide() async => shown = null;

  @override
  Stream<String> get presses => _presses.stream;

  void press(String button) => _presses.add(button);
}
