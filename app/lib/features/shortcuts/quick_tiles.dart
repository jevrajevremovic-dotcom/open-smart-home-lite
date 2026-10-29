import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../core/storage/app_preferences.dart';
import '../authentication/application/session_controller.dart';
import '../clap/clap_listener.dart';
import '../devices/application/device_command_service.dart';
import '../devices/application/device_providers.dart';
import '../devices/data/home_state_repository.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';

/// What a Quick Settings tile shows.
@immutable
class QuickTileState {
  const QuickTileState({required this.label, this.active});

  final String label;

  /// `null` for scenes (nothing stays on).
  final bool? active;

  Map<String, Object?> toJson() => {'label': label, 'active': active};

  @override
  bool operator ==(Object other) =>
      other is QuickTileState && other.label == label && other.active == active;

  @override
  int get hashCode => Object.hash(label, active);
}

abstract interface class QuickTilesPlatform {
  bool get supported;

  /// Labels and on/off of the three tiles (`null` = not set up).
  Future<void> update(List<QuickTileState?> tiles);

  /// Taps queued while the app was not listening (or just now).
  Future<List<int>> takePending();

  /// A tile was tapped: call [takePending].
  Stream<void> get clicks;

  /// Android 13+: asks the system to add tile [index]; `false` when the
  /// user has to add it by hand.
  Future<bool> requestAdd(int index, String label);
}

class AndroidQuickTiles implements QuickTilesPlatform {
  AndroidQuickTiles() {
    if (supported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'clicked') _clicks.add(null);
      });
    }
  }

  static const _channel = MethodChannel('org.opensmarthome/tiles');
  final _clicks = StreamController<void>.broadcast();

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> update(List<QuickTileState?> tiles) =>
      _channel.invokeMethod('update', {
        'tiles': jsonEncode([for (final t in tiles) t?.toJson()]),
      });

  @override
  Future<List<int>> takePending() async {
    final json = await _channel.invokeMethod<String>('takePending');
    final list = json == null ? null : jsonDecode(json);
    return [
      if (list is List)
        for (final i in list)
          if (i is int) i,
    ];
  }

  @override
  Stream<void> get clicks => _clicks.stream;

  @override
  Future<bool> requestAdd(int index, String label) async =>
      await _channel.invokeMethod<bool>('requestAdd', {
        'index': index,
        'label': label,
      }) ??
      false;
}

final quickTilesPlatformProvider = Provider<QuickTilesPlatform>(
  (ref) => AndroidQuickTiles(),
);

const quickTileCount = 3;

/// What a tile may do: switch a device or run a scene/script. Nothing that
/// opens a door, a garage or the alarm (a tap in a menu is no
/// confirmation).
DeviceCommand? quickTileCommand(SmartHomeDevice d) {
  if (const {
    DeviceKind.lock,
    DeviceKind.garageDoor,
    DeviceKind.alarm,
  }.contains(d.kind)) {
    return null;
  }
  final command = clapCommandFor(d);
  if (command == null || command.isCritical(d)) return null;
  return command;
}

/// The device of each tile, per home.
class QuickTilesController extends Notifier<List<String?>> {
  String? get _key {
    final p = ref.read(activeProfileProvider);
    return p == null ? null : 'quickTiles::${p.id}';
  }

  @override
  List<String?> build() {
    final p = ref.watch(activeProfileProvider);
    if (p == null) return List.filled(quickTileCount, null);
    final json = ref
        .watch(appPreferencesProvider)
        .readJson('quickTiles::${p.id}');
    final ids = json?['ids'];
    return [
      for (var i = 0; i < quickTileCount; i++)
        ids is List && i < ids.length && ids[i] is String
            ? ids[i] as String
            : null,
    ];
  }

  Future<void> set(int index, String? deviceId) async {
    final next = [...state]..[index] = deviceId;
    state = next;
    final key = _key;
    if (key != null) {
      await ref.read(appPreferencesProvider).writeJson(key, {'ids': next});
    }
  }
}

final quickTilesProvider =
    NotifierProvider<QuickTilesController, List<String?>>(
      QuickTilesController.new,
    );

/// The tiles as the menu shows them, from live device state.
final quickTileStatesProvider = Provider<List<QuickTileState?>>((ref) {
  final ids = ref.watch(quickTilesProvider);
  return [
    for (final id in ids)
      if (id == null)
        null
      else if (ref.watch(deviceProvider(id)) case final d?)
        QuickTileState(
          label: d.name,
          active: d.kind.isRoutine ? null : d.state.isOn ?? d.state.isActive,
        )
      else
        null,
  ];
});

/// Keeps the tiles current and runs their taps once Home Assistant is live
/// (the app may just have been started in the background by the tap).
class QuickTilesHost extends ConsumerStatefulWidget {
  const QuickTilesHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<QuickTilesHost> createState() => _QuickTilesHostState();
}

class _QuickTilesHostState extends ConsumerState<QuickTilesHost> {
  static final _log = AppLogger('QuickTiles');
  StreamSubscription<void>? _sub;
  final List<int> _queue = [];
  List<QuickTileState?>? _sent;

  @override
  void initState() {
    super.initState();
    final platform = ref.read(quickTilesPlatformProvider);
    if (!platform.supported) return;
    _sub = platform.clicks.listen((_) => unawaited(_takePending()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_takePending());
      _push();
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _push() {
    final platform = ref.read(quickTilesPlatformProvider);
    if (!platform.supported) return;
    final tiles = ref.read(quickTileStatesProvider);
    if (_sent != null && listEquals(_sent, tiles)) return;
    _sent = tiles;
    unawaited(
      platform.update(tiles).catchError((Object e) {
        _log.info('tiles not updated: ${e.runtimeType}');
      }),
    );
  }

  Future<void> _takePending() async {
    try {
      _queue.addAll(await ref.read(quickTilesPlatformProvider).takePending());
    } on Object catch (e) {
      _log.info('no pending taps: ${e.runtimeType}');
    }
    await _run();
  }

  /// Runs queued taps when the home is live; otherwise they wait.
  Future<void> _run() async {
    if (_queue.isEmpty || !mounted) return;
    if (ref.read(syncStatusProvider) != SyncStatus.live) return;
    final service = ref.read(deviceCommandServiceProvider);
    final ids = ref.read(quickTilesProvider);
    while (_queue.isNotEmpty && service != null) {
      final index = _queue.removeAt(0);
      final id = index < ids.length ? ids[index] : null;
      final device = id == null ? null : ref.read(deviceProvider(id));
      final command = device == null ? null : quickTileCommand(device);
      if (device == null || command == null) continue;
      try {
        await service.execute(device, command);
      } on Object catch (e) {
        _log.warning('tile command failed', e.runtimeType);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(quickTileStatesProvider, (_, _) => _push())
      ..listen(syncStatusProvider, (_, next) {
        if (next == SyncStatus.live) unawaited(_run());
      });
    return widget.child;
  }
}
