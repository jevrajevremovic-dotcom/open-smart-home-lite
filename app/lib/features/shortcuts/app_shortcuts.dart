import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../extras/coming_home.dart';
import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../assist/presentation/assist_sheet.dart';
import '../authentication/application/session_controller.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/data/home_state_repository.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/device_kind.dart';
import '../devices/application/device_command_service.dart';
import '../favorites/application/favorites_controller.dart';
import '../restricted/application/restricted_mode.dart';
import 'home_screen_widget.dart';
import 'home_widgets.dart';

/// Long-press shortcuts on the app icon (Android / iOS).
abstract interface class AppShortcutsPlatform {
  bool get supported;
  void initialize(void Function(String type) onAction);
  Future<void> setItems(List<(String type, String title, String icon)> items);
}

class QuickActionsPlatform implements AppShortcutsPlatform {
  final QuickActions _qa = const QuickActions();

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initialize(void Function(String type) onAction) =>
      _qa.initialize(onAction);

  @override
  Future<void> setItems(List<(String type, String title, String icon)> items) =>
      _qa.setShortcutItems([
        for (final (type, title, icon) in items)
          ShortcutItem(type: type, localizedTitle: title, icon: icon),
      ]);
}

final appShortcutsPlatformProvider = Provider<AppShortcutsPlatform>(
  (ref) => QuickActionsPlatform(),
);

/// A shortcut tapped before the app could act on it (e.g. still syncing).
class PendingShortcutController extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void set(String? type) => state = type;
}

final pendingShortcutProvider =
    NotifierProvider<PendingShortcutController, String?>(
      PendingShortcutController.new,
    );

/// Scenes as (id, name): favourite scenes first, then by name.
final favoriteFirstScenesProvider = Provider<List<(String, String)>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final favorites = ref.watch(favoritesProvider);
  final scenes =
      devices.values.where((d) => d.kind == DeviceKind.scene).toList()
        ..sort((a, b) {
          final fa = favorites.indexOf(a.id);
          final fb = favorites.indexOf(b.id);
          if (fa != fb) {
            if (fa == -1) return 1;
            if (fb == -1) return -1;
            return fa.compareTo(fb);
          }
          return a.name.compareTo(b.name);
        });
  return [for (final s in scenes) (s.id, s.name)];
});

/// Scenes offered as shortcuts: at most two.
final shortcutScenesProvider = Provider<List<(String, String)>>(
  (ref) => ref.watch(favoriteFirstScenesProvider).take(2).toList(),
);

/// Scenes on the Android home screen widget: at most four.
final widgetScenesProvider = Provider<List<(String, String)>>(
  (ref) => ref.watch(favoriteFirstScenesProvider).take(4).toList(),
);

/// Keeps the launcher shortcuts in sync and runs scene shortcuts once the
/// home is live. Kiosk and Assist shortcuts are handled by the screens.
class AppShortcutsBinder {
  AppShortcutsBinder(this.ref);

  final WidgetRef ref;
  bool _initialized = false;
  bool _widgetInitialized = false;

  // Last values sent, so a state change elsewhere in the home does not
  // re-send identical items over the platform channel.
  List<(String, String, String)>? _lastItems;
  (List<(String, String)>, String)? _lastWidget;

  void bind(AppLocalizations l10n) {
    _bindWidget(l10n);
    final platform = ref.read(appShortcutsPlatformProvider);
    if (!platform.supported) return;
    if (!_initialized) {
      _initialized = true;
      platform.initialize(
        (type) => ref.read(pendingShortcutProvider.notifier).set(type),
      );
    }
    final restricted = ref.read(restrictedModeProvider).enabled;
    final scenes = ref.read(shortcutScenesProvider);
    final items = [
      for (final (id, name) in scenes) ('scene:$id', name, 'ic_scene'),
      ('check', l10n.houseCheckTitle, 'ic_check'),
      if (!restricted) ('coming', l10n.comingHomeTitle, 'ic_coming_home'),
      if (!restricted) ('assist', l10n.assistTitle, 'ic_assist'),
      if (!restricted) ('kiosk', l10n.kioskStart, 'ic_kiosk'),
    ];
    if (_lastItems != null && listEquals(_lastItems, items)) return;
    _lastItems = items;
    unawaited(platform.setItems(items));
  }

  void _bindWidget(AppLocalizations l10n) {
    final widget = ref.read(homeScreenWidgetProvider);
    if (!widget.supported) return;
    if (!_widgetInitialized) {
      _widgetInitialized = true;
      void open(Uri? uri) {
        // Thermostat ± and the light: run on the widget's own device.
        if (homeWidgetActionFromUri(uri) case final a?) {
          ref
              .read(pendingShortcutProvider.notifier)
              .set('widgetAction:${a.kind}:${a.step}');
          return;
        }
        // The home widget opens the house check.
        if (uri?.scheme == 'opensmarthome' && uri?.host == 'check') {
          ref.read(pendingShortcutProvider.notifier).set('check');
          return;
        }
        final id = sceneIdFromWidgetUri(uri);
        // Checked again before it runs: only a scene on the widget.
        if (id != null) {
          ref.read(pendingShortcutProvider.notifier).set('widgetScene:$id');
        }
      }

      unawaited(widget.initialUri().then(open));
      widget.clicks.listen(open);
    }
    final signedIn = ref.read(activeProfileProvider) != null;
    final scenes = signedIn
        ? ref.read(widgetScenesProvider)
        : const <(String, String)>[];
    final empty = signedIn ? l10n.widgetNoScenes : l10n.widgetSignedOut;
    final last = _lastWidget;
    if (last != null && listEquals(last.$1, scenes) && last.$2 == empty) {
      return;
    }
    _lastWidget = (scenes, empty);
    unawaited(widget.setScenes(scenes, empty));
  }

  /// Activates a pending scene shortcut once data is live.
  /// Returns the scene's name when it ran, so the caller can confirm it
  /// (a scene has no visible state of its own).
  Future<String?> runPendingScene() async {
    final type = ref.read(pendingShortcutProvider);
    if (type == null) return null;
    final fromWidget = type.startsWith('widgetScene:');
    if (!fromWidget && !type.startsWith('scene:')) return null;
    if (ref.read(syncStatusProvider) != SyncStatus.live) return null;
    ref.read(pendingShortcutProvider.notifier).set(null);
    final id = type.substring(type.indexOf(':') + 1);
    // Any app can send the widget's link, or start this app with a
    // launcher shortcut's extra: only a scene that is on the widget, or
    // on the launcher shortcuts, may run from them.
    final allowed = fromWidget
        ? ref.read(widgetScenesProvider)
        : ref.read(shortcutScenesProvider);
    if (!allowed.any((s) => s.$1 == id)) return null;
    final device = ref.read(deviceProvider(id));
    final service = ref.read(deviceCommandServiceProvider);
    if (device == null || service == null) return null;
    try {
      await service.execute(device, const Activate());
      return device.name;
    } on Object {
      // Shown nowhere: the user sees the result in the home itself.
      return null;
    }
  }
}

/// Sits below MaterialApp: keeps shortcuts current and acts on them.
class ShortcutsHost extends ConsumerStatefulWidget {
  const ShortcutsHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShortcutsHost> createState() => _ShortcutsHostState();
}

class _ShortcutsHostState extends ConsumerState<ShortcutsHost> {
  late final AppShortcutsBinder _binder = AppShortcutsBinder(ref);

  Future<void> _runScene() async {
    final name = await _binder.runPendingScene();
    if (name == null || !mounted) return;
    final ctx = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.maybeOf(ctx)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(ctx.l10n.sceneActivated(name))));
  }

  /// A thermostat or light widget tap, once the home is live.
  Future<void> _runWidgetAction() async {
    final type = ref.read(pendingShortcutProvider);
    if (type == null || !type.startsWith('widgetAction:')) return;
    if (ref.read(syncStatusProvider) != SyncStatus.live) return;
    ref.read(pendingShortcutProvider.notifier).set(null);
    final parts = type.split(':');
    final step = int.tryParse(parts.last) ?? 0;
    await runHomeWidgetAction(ref, (kind: parts[1], step: step));
  }

  void _handle(String? type) {
    if (type == null) return;
    final router = ref.read(routerProvider);
    final signedIn = ref.read(activeProfileProvider) != null;
    if (!signedIn) return;
    switch (type) {
      case 'kiosk':
        ref.read(pendingShortcutProvider.notifier).set(null);
        ref.read(kioskActiveProvider.notifier).enter();
        router.go(AppRoutes.kiosk);
      case 'check':
        ref.read(pendingShortcutProvider.notifier).set(null);
        router
          ..go(AppRoutes.home)
          ..push(AppRoutes.houseCheck);
      case 'coming':
        ref.read(pendingShortcutProvider.notifier).set(null);
        router.go(AppRoutes.home);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = router.routerDelegate.navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) unawaited(runComingHome(ctx, ref));
        });
      case 'assist':
        ref.read(pendingShortcutProvider.notifier).set(null);
        router.go(AppRoutes.home);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = router.routerDelegate.navigatorKey.currentContext;
          if (ctx != null) showAssist(ctx);
        });
      default:
        if (type.startsWith('widgetAction:')) {
          unawaited(_runWidgetAction());
        } else {
          unawaited(_runScene());
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref
      ..listen(shortcutScenesProvider, (_, _) => _binder.bind(l10n))
      ..listen(widgetScenesProvider, (_, _) => _binder.bind(l10n))
      ..listen(activeProfileProvider, (_, _) => _binder.bind(l10n))
      ..listen(
        restrictedModeProvider.select((s) => s.enabled),
        (_, _) => _binder.bind(l10n),
      )
      ..listen(pendingShortcutProvider, (_, next) => _handle(next))
      ..listen(syncStatusProvider, (_, s) {
        if (s == SyncStatus.live) {
          unawaited(_runScene());
          unawaited(_runWidgetAction());
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _binder.bind(l10n);
    });
    return widget.child;
  }
}
