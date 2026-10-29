import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_preferences.dart';
import '../alerts/alert_notifications.dart';
import '../devices/application/device_command_service.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import 'application/media_providers.dart';

/// The notification-shade player (NowPlaying.kt).
abstract interface class NowPlayingPlatform {
  bool get supported;

  Future<void> show({
    required String title,
    required String text,
    required bool playing,
    required Map<String, String> labels,
  });

  Future<void> hide();

  /// `play_pause` or `next`, pressed in the notification.
  Stream<String> get presses;
}

class AndroidNowPlaying implements NowPlayingPlatform {
  static final _log = AppLogger('NowPlaying');
  static const _channel = MethodChannel('org.opensmarthome/nowplaying');
  final _presses = StreamController<String>.broadcast();
  bool _listening = false;

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> show({
    required String title,
    required String text,
    required bool playing,
    required Map<String, String> labels,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'title': title,
        'text': text,
        'playing': playing,
        ...labels,
      });
    } on Object catch (e) {
      _log.debug('show failed: ${e.runtimeType}');
    }
  }

  @override
  Future<void> hide() async {
    try {
      await _channel.invokeMethod<void>('hide');
    } on Object catch (e) {
      _log.debug('hide failed: ${e.runtimeType}');
    }
  }

  @override
  Stream<String> get presses {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'press' && call.arguments is String) {
          _presses.add(call.arguments as String);
        }
      });
    }
    return _presses.stream;
  }
}

final nowPlayingPlatformProvider = Provider<NowPlayingPlatform>(
  (ref) => AndroidNowPlaying(),
);

/// Opt-in: the player in the notification shade while music plays.
class NowPlayingNotificationController extends Notifier<bool> {
  static const _key = 'nowPlaying.notification';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  /// `false` when Android does not allow notifications.
  Future<bool> set(bool enabled) async {
    if (enabled && !await ref.read(alertNotifierProvider).requestPermission()) {
      return false;
    }
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
    if (!enabled) await ref.read(nowPlayingPlatformProvider).hide();
    return true;
  }
}

final nowPlayingNotificationProvider =
    NotifierProvider<NowPlayingNotificationController, bool>(
      NowPlayingNotificationController.new,
    );

/// Keeps the notification in step with what plays, and turns its buttons
/// into commands for that player. Sits below MaterialApp.
class NowPlayingNotificationHost extends ConsumerStatefulWidget {
  const NowPlayingNotificationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NowPlayingNotificationHost> createState() =>
      _NowPlayingNotificationHostState();
}

class _NowPlayingNotificationHostState
    extends ConsumerState<NowPlayingNotificationHost> {
  StreamSubscription<String>? _presses;
  String? _shown;

  @override
  void initState() {
    super.initState();
    final platform = ref.read(nowPlayingPlatformProvider);
    if (platform.supported) _presses = platform.presses.listen(_press);
  }

  @override
  void dispose() {
    unawaited(_presses?.cancel());
    super.dispose();
  }

  Future<void> _press(String button) async {
    final id = ref.read(nowPlayingIdProvider);
    final player = id == null ? null : ref.read(deviceProvider(id));
    final service = ref.read(deviceCommandServiceProvider);
    if (player == null || service == null) return;
    try {
      await service.execute(
        player,
        button == 'next' ? const MediaNext() : const MediaPlayPause(),
      );
    } on Object {
      // The notification keeps showing the real state.
    }
  }

  void _sync(AppLocalizations l10n) {
    final platform = ref.read(nowPlayingPlatformProvider);
    if (!platform.supported) return;
    final enabled = ref.read(nowPlayingNotificationProvider);
    final id = ref.read(nowPlayingIdProvider);
    final d = id == null ? null : ref.read(deviceProvider(id));
    if (!enabled || d == null) {
      if (_shown != null) {
        _shown = null;
        unawaited(platform.hide());
      }
      return;
    }
    final s = d.state;
    final playing = s.raw == 'playing';
    final title = s.mediaTitle ?? d.name;
    final text = [?s.mediaArtist, if (s.mediaTitle != null) d.name].join(' · ');
    final key = '$title|$text|$playing';
    if (key == _shown) return;
    _shown = key;
    unawaited(
      platform.show(
        title: title,
        text: text,
        playing: playing,
        labels: {
          'pause': l10n.nowPlayingPause,
          'play': l10n.nowPlayingPlay,
          'next': l10n.nowPlayingNext,
          'channel': l10n.nowPlayingChannel,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref
      ..listen(nowPlayingNotificationProvider, (_, _) => _sync(l10n))
      ..listen(nowPlayingIdProvider, (_, _) => _sync(l10n));
    final id = ref.watch(nowPlayingIdProvider);
    if (id != null) {
      ref.listen(deviceProvider(id), (_, _) => _sync(l10n));
    }
    return widget.child;
  }
}

/// Settings → Notifications.
class NowPlayingNotificationTile extends ConsumerWidget {
  const NowPlayingNotificationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(nowPlayingPlatformProvider).supported) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return SwitchListTile(
      key: const Key('nowPlayingNotification'),
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.queue_music),
      title: Text(l10n.nowPlayingSetting),
      subtitle: Text(l10n.nowPlayingSettingHint),
      value: ref.watch(nowPlayingNotificationProvider),
      onChanged: (v) async {
        final messenger = ScaffoldMessenger.of(context);
        if (!await ref.read(nowPlayingNotificationProvider.notifier).set(v)) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.alertsPermissionDenied)),
          );
        }
      },
    );
  }
}
