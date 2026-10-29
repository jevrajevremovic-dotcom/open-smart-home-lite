import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_preferences.dart';
import '../authentication/application/session_controller.dart';
import '../dashboard/application/home_summaries.dart';
import '../devices/application/device_providers.dart';
import '../devices/data/home_state_repository.dart';
import '../devices/presentation/device_presentation.dart';
import '../kiosk/application/kiosk_controller.dart';

/// A tapped notification or one of its buttons ([actionId]).
@immutable
class NotificationTap {
  const NotificationTap(this.payload, [this.actionId]);

  /// A device id (alerts) or a JSON object (messages from Home Assistant).
  final String payload;
  final String? actionId;
}

/// System notifications for critical alerts, shown by the phone itself.
abstract interface class AlertNotifier {
  bool get supported;

  Future<void> initialize();

  /// Taps on notifications and their buttons, also the one that opened
  /// the app.
  Stream<NotificationTap> get taps;

  /// Asks the OS for permission; `true` when notifications may be shown.
  Future<bool> requestPermission();

  Future<void> show(String deviceId, String title, String body);

  /// A message sent by a Home Assistant automation (`notify.mobile_app_…`),
  /// on its own, less intrusive channel; [actions] become buttons
  /// (id, label). [key] replaces an earlier message with the same key.
  Future<void> showMessage(
    String key,
    String? title,
    String body, {
    List<(String, String)> actions = const [],
    String? payload,
  });

  Future<void> cancel(String deviceId);
}

class LocalAlertNotifier implements AlertNotifier {
  static final _log = AppLogger('Alerts');
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Stable per device, so an alert is replaced rather than repeated.
  static int _id(String deviceId) => deviceId.hashCode & 0x7fffffff;

  bool _initialized = false;
  final _taps = StreamController<NotificationTap>.broadcast();

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  void _respond(NotificationResponse r) {
    final payload = r.payload;
    if (payload != null && payload.isNotEmpty) {
      _taps.add(NotificationTap(payload, r.actionId));
    }
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_home'),
          // Permission is asked only when the user turns alerts on.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _respond,
      );
      // A tap that started the app (after it had been closed).
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        // After the listeners are attached.
        Timer.run(() => _respond(response));
      }
    } on Object catch (e) {
      _log.warning('notifications unavailable', e.runtimeType);
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } on Object catch (e) {
      _log.warning('permission request failed', e.runtimeType);
      return false;
    }
  }

  @override
  Future<void> show(String deviceId, String title, String body) async {
    try {
      await _plugin.show(
        id: _id(deviceId),
        title: title,
        body: body,
        payload: deviceId,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'critical_alerts',
            'Critical alerts',
            channelDescription: 'Smoke, CO, water leak, alarm, jammed lock',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            // Lock screen shows only that there is an alert.
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
      );
    } on Object catch (e) {
      _log.warning('show failed', e.runtimeType);
    }
  }

  @override
  Future<void> showMessage(
    String key,
    String? title,
    String body, {
    List<(String, String)> actions = const [],
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: _id(key),
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'ha_messages',
            'Home Assistant',
            channelDescription: 'Messages from Home Assistant automations',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
            styleInformation: BigTextStyleInformation(body),
            actions: [
              for (final (id, label) in actions.take(3))
                // Opens the app, whose main code answers Home Assistant.
                AndroidNotificationAction(id, label, showsUserInterface: true),
            ],
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } on Object catch (e) {
      _log.warning('message failed', e.runtimeType);
    }
  }

  @override
  Future<void> cancel(String deviceId) async {
    try {
      await _plugin.cancel(id: _id(deviceId));
    } on Object catch (e) {
      _log.debug('cancel failed: ${e.runtimeType}');
    }
  }
}

final alertNotifierProvider = Provider<AlertNotifier>(
  (ref) => LocalAlertNotifier(),
);

/// Opt-in: critical alerts as system notifications while the app runs.
class AlertNotificationsController extends Notifier<bool> {
  static const _key = 'alerts.notifications';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  /// Turns alerts on if the OS allows it; returns whether they are on.
  Future<bool> enable() async {
    final granted = await ref.read(alertNotifierProvider).requestPermission();
    if (granted) await _save(true);
    return granted;
  }

  Future<void> disable() => _save(false);

  Future<void> _save(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
  }
}

final alertNotificationsProvider =
    NotifierProvider<AlertNotificationsController, bool>(
      AlertNotificationsController.new,
    );

/// Sits below MaterialApp: notifies about new critical alerts (only from
/// live data, never from the offline cache) and clears resolved ones.
class AlertNotificationsHost extends ConsumerStatefulWidget {
  const AlertNotificationsHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AlertNotificationsHost> createState() =>
      _AlertNotificationsHostState();
}

class _AlertNotificationsHostState
    extends ConsumerState<AlertNotificationsHost> {
  final Set<String> _shown = {};
  bool _initialized = false;
  StreamSubscription<NotificationTap>? _tapSub;

  AlertNotifier get _notifier => ref.read(alertNotifierProvider);

  @override
  void dispose() {
    unawaited(_tapSub?.cancel());
    super.dispose();
  }

  void _onTap(NotificationTap tap) {
    // Messages from Home Assistant carry JSON; alerts a device id.
    if (tap.payload.startsWith('{')) return;
    final deviceId = tap.payload;
    if (ref.read(activeProfileProvider) == null) return;
    if (ref.read(deviceProvider(deviceId)) == null) return;
    ref
        .read(routerProvider)
        .push(AppRoutes.device(deviceId, kiosk: ref.read(kioskActiveProvider)));
  }

  void _sync() {
    final notifier = _notifier;
    if (!notifier.supported) return;
    final enabled = ref.read(alertNotificationsProvider);
    if (enabled && !_initialized) {
      _initialized = true;
      _tapSub = notifier.taps.listen(_onTap);
      unawaited(notifier.initialize());
    }
    final live = ref.read(syncStatusProvider) == SyncStatus.live;
    final ids = ref.read(dashboardSummaryProvider).criticalIds.toSet();
    if (!enabled || ref.read(activeProfileProvider) == null) {
      for (final id in _shown) {
        unawaited(notifier.cancel(id));
      }
      _shown.clear();
      return;
    }
    for (final id in _shown.difference(ids).toList()) {
      _shown.remove(id);
      unawaited(notifier.cancel(id));
    }
    if (!live) return;
    final l10n = context.l10n;
    for (final id in ids.difference(_shown)) {
      final d = ref.read(deviceProvider(id));
      if (d == null) continue;
      _shown.add(id);
      unawaited(notifier.show(id, d.name, DevicePresentation.status(l10n, d)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(
        dashboardSummaryProvider.select((s) => s.criticalIds),
        (_, _) => _sync(),
      )
      ..listen(syncStatusProvider, (_, _) => _sync())
      ..listen(alertNotificationsProvider, (_, _) => _sync())
      ..listen(activeProfileProvider, (_, _) => _sync());
    return widget.child;
  }
}
