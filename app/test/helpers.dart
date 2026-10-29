import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'dart:async';

import 'package:open_smart_home_lite/features/add_device/data/matter_pairing.dart';
import 'package:open_smart_home_lite/features/clap/clap_platform.dart';
import 'package:open_smart_home_lite/features/kiosk/data/approach_platform.dart';
import 'package:open_smart_home_lite/features/ha_notify/ha_push.dart';
import 'package:open_smart_home_lite/features/shortcuts/home_screen_widget.dart';
import 'package:open_smart_home_lite/features/alerts/alert_notifications.dart';
import 'package:open_smart_home_lite/features/shortcuts/app_shortcuts.dart';
import 'package:open_smart_home_lite/features/app_lock/application/app_lock.dart';
import 'package:open_smart_home_lite/features/app_lock/data/device_auth.dart';
import 'package:open_smart_home_lite/features/assist/application/voice_providers.dart';
import 'package:open_smart_home_lite/features/assist/data/voice_input.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:open_smart_home_lite/core/config/app_config.dart';
import 'package:open_smart_home_lite/core/platform/browser_port.dart';
import 'package:open_smart_home_lite/core/storage/app_preferences.dart';
import 'package:open_smart_home_lite/core/storage/credential_store.dart';
import 'package:open_smart_home_lite/features/devices/data/cache/snapshot_cache.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/device_sensors/device_sensors.dart';
import 'package:open_smart_home_lite/features/nfc_tags/nfc_tags.dart';
import 'package:open_smart_home_lite/features/shortcuts/quick_tiles.dart';
import 'package:open_smart_home_lite/features/assist/data/speech_output.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_smart_home_lite/features/media/now_playing_notification.dart';

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

/// A scriptable browser for testing the web sign-in on the VM.
class FakeBrowserPort implements BrowserPort {
  FakeBrowserPort(this.currentUrl);

  @override
  Uri currentUrl;
  final Map<String, String> session = {};
  final List<Uri> navigations = [];

  @override
  bool get isAvailable => true;

  @override
  String? sessionGet(String key) => session[key];

  @override
  void sessionSet(String key, String value) => session[key] = value;

  @override
  void sessionRemove(String key) => session.remove(key);

  @override
  void navigate(Uri url) => navigations.add(url);

  @override
  void replaceUrl(Uri url) => currentUrl = url;
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

/// Overrides for running the app against the in-memory mock server.
Future<List<Override>> testOverrides({
  InMemoryCredentialStore? credentials,
  KioskPlatform? kioskPlatform,
  SnapshotCache? snapshotCache,
  Map<String, Object> preferences = const {},
  MockHomeAssistantServer? server,
  VoiceInput? voiceInput,
  DeviceAuth? deviceAuth,
  AppShortcutsPlatform? shortcuts,
  AlertNotifier? alerts,
  HomeScreenWidgetPlatform? homeWidget,
  NowPlayingPlatform? nowPlaying,
  ClapPlatform? clap,
  ApproachPlatform? approach,
  DeviceBatteryPlatform? battery,
  NfcPlatform? nfc,
  QuickTilesPlatform? tiles,
  SpeechOutput? speech,
  AssistLaunchPlatform? assistLaunch,
  BackgroundConnectionPlatform? background,
  MatterNewDevicePlatform? matter,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final prefs = await SharedPreferences.getInstance();
  return [
    appConfigProvider.overrideWithValue(const AppConfig(mockMode: true)),
    sharedPreferencesProvider.overrideWithValue(prefs),
    snapshotCacheProvider.overrideWithValue(
      snapshotCache ?? InMemorySnapshotCache(),
    ),
    kioskPlatformProvider.overrideWithValue(
      kioskPlatform ?? FakeKioskPlatform(),
    ),
    credentialStoreProvider.overrideWithValue(
      credentials ?? InMemoryCredentialStore(),
    ),
    if (server != null)
      mockHomeAssistantServerProvider.overrideWithValue(server),
    voiceInputProvider.overrideWithValue(
      voiceInput ?? FakeVoiceInput('turn off the lights'),
    ),
    deviceAuthProvider.overrideWithValue(deviceAuth ?? FakeDeviceAuth()),
    appShortcutsPlatformProvider.overrideWithValue(
      shortcuts ?? FakeShortcuts(supported: false),
    ),
    matterNewDeviceProvider.overrideWithValue(
      matter ?? FakeMatterNewDevice(supported: false),
    ),
    backgroundConnectionProvider.overrideWithValue(
      background ?? FakeBackgroundConnection(supported: false),
    ),
    clapPlatformProvider.overrideWithValue(
      clap ?? FakeClapPlatform(supported: false),
    ),
    approachPlatformProvider.overrideWithValue(
      approach ?? FakeApproach(supported: false),
    ),
    deviceBatteryProvider.overrideWithValue(
      battery ?? FakeDeviceBattery(supported: false),
    ),
    nfcPlatformProvider.overrideWithValue(nfc ?? FakeNfc(supported: false)),
    quickTilesPlatformProvider.overrideWithValue(
      tiles ?? FakeQuickTiles(supported: false),
    ),
    speechOutputProvider.overrideWithValue(
      speech ?? FakeSpeechOutput(supported: false),
    ),
    assistLaunchProvider.overrideWithValue(
      assistLaunch ?? FakeAssistLaunch(supported: false),
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

  // ignore: close_sinks, lives as long as the test
  final _pcm = StreamController<Uint8List>.broadcast();
  int pcmListeners = 0;

  @override
  Stream<Uint8List> pcm() {
    // ignore: close_sinks, closed by its listener's cancel
    late final StreamController<Uint8List> c;
    c = StreamController<Uint8List>(
      onListen: () {
        pcmListeners++;
        final sub = _pcm.stream.listen(c.add);
        c.onCancel = () {
          pcmListeners--;
          return sub.cancel();
        };
      },
    );
    return c.stream;
  }

  /// [chunks] of 100 ms audio; `loud` ones peak near full scale.
  void emitAudio(int chunks, {bool loud = false}) {
    for (var i = 0; i < chunks; i++) {
      final bytes = Uint8List(3200);
      if (loud) {
        final view = ByteData.sublistView(bytes);
        for (var j = 0; j < 1600; j++) {
          view.setInt16(j * 2, j.isEven ? 30000 : -30000, Endian.little);
        }
      }
      _pcm.add(bytes);
    }
  }
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

/// Records whether the connection service would run.
class FakeBackgroundConnection implements BackgroundConnectionPlatform {
  FakeBackgroundConnection({this.supported = true});

  @override
  final bool supported;
  bool running = false;
  String? text;

  @override
  Future<void> start({required String title, required String text}) async {
    running = true;
    this.text = text;
  }

  @override
  Future<void> stop() async => running = false;
}

/// Plays Google's part of adding a new Matter device: hands over [pin].
class FakeMatterNewDevice implements MatterNewDevicePlatform {
  FakeMatterNewDevice({this.supported = true, this.pin = 20202021, this.error});

  @override
  final bool supported;
  final int pin;

  /// Platform error code to throw instead (e.g. `unavailable`).
  final String? error;
  Future<void> Function(int pin, String? ip)? _handler;

  @override
  void onCommissionRequest(
    Future<void> Function(int pin, String? ip) handler,
  ) => _handler = handler;

  @override
  Future<bool> commissionNewDevice() async {
    if (error != null) throw PlatformException(code: error!);
    try {
      await _handler!(pin, 'fe80::1%wlan0');
      return true;
    } on Object {
      return false;
    }
  }
}

/// Battery readings pushed by the test.
class FakeDeviceBattery implements DeviceBatteryPlatform {
  FakeDeviceBattery({this.supported = true});

  @override
  final bool supported;

  // ignore: close_sinks, lives as long as the test
  final _readings = StreamController<BatteryReading>.broadcast();
  BatteryReading? last;

  void emit(BatteryReading r) {
    last = r;
    _readings.add(r);
  }

  @override
  Stream<BatteryReading> readings() async* {
    if (last case final r?) yield r;
    yield* _readings.stream;
  }
}

/// NFC driven by the test: [scan] a tag, finish or fail a [write].
class FakeNfc implements NfcPlatform {
  FakeNfc({this.supported = true, this.enabled = true, this.initial});

  @override
  final bool supported;
  bool enabled;
  String? initial;
  String? writing;
  Completer<void>? _write;

  // ignore: close_sinks, lives as long as the test
  final _scans = StreamController<String>.broadcast();

  void scan(String id) => _scans.add(id);

  void finishWrite([NfcWriteError? error]) {
    final w = _write!;
    _write = null;
    error == null ? w.complete() : w.completeError(NfcWriteException(error));
  }

  @override
  Future<(bool, bool)> availability() async => (true, enabled);

  @override
  Future<String?> initialTag() async {
    final i = initial;
    initial = null;
    return i;
  }

  @override
  Stream<String> get scans => _scans.stream;

  @override
  Future<void> write(String uri) {
    writing = uri;
    return (_write = Completer<void>()).future;
  }

  @override
  Future<void> cancel() async {
    if (_write != null) finishWrite(NfcWriteError.cancelled);
  }
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

/// Records what Assist would say aloud.
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

/// Launches as the phone's assistant, driven by the test.
class FakeAssistLaunch implements AssistLaunchPlatform {
  FakeAssistLaunch({this.supported = true, this.initial = false});

  @override
  final bool supported;
  bool initial;
  int settingsOpened = 0;

  // ignore: close_sinks, lives as long as the test
  final _launches = StreamController<void>.broadcast();

  void launch() => _launches.add(null);

  @override
  Future<bool> launchedAsAssistant() async {
    final i = initial;
    initial = false;
    return i;
  }

  @override
  Stream<void> get launches => _launches.stream;

  @override
  Future<void> openAssistantSettings() async => settingsOpened++;
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
