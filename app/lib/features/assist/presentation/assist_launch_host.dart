import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/data/home_state_repository.dart';
import '../../restricted/application/restricted_mode.dart';
import '../application/voice_providers.dart';
import 'assist_sheet.dart';

/// Opens Assist, listening, when Android starts the app as its assistant
/// (long press of home / power, once chosen in Android's settings).
class AssistLaunchHost extends ConsumerStatefulWidget {
  const AssistLaunchHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AssistLaunchHost> createState() => _AssistLaunchHostState();
}

class _AssistLaunchHostState extends ConsumerState<AssistLaunchHost> {
  StreamSubscription<void>? _sub;

  /// Launched, but the home is not ready yet (signing in, loading).
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    final platform = ref.read(assistLaunchProvider);
    if (!platform.supported) return;
    _sub = platform.launches.listen((_) => _launched());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launched = await platform.launchedAsAssistant().catchError(
        (Object _) => false,
      );
      if (launched) _launched();
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _launched() {
    _pending = true;
    _tryOpen();
  }

  void _tryOpen() {
    if (!_pending || !mounted) return;
    if (ref.read(activeProfileProvider) == null) return;
    // Opened too early, the start-up navigation would close it again; and
    // Assist needs Home Assistant anyway.
    final status = ref.read(syncStatusProvider);
    if (status == SyncStatus.initial || status == SyncStatus.syncing) return;
    // Assist can unlock doors by voice: not in child / guest mode.
    if (ref.read(restrictedModeProvider).enabled) {
      _pending = false;
      return;
    }
    final router = ref.read(routerProvider);
    final context = router.routerDelegate.navigatorKey.currentContext;
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (context == null ||
        location == AppRoutes.splash ||
        location.startsWith(AppRoutes.welcome) ||
        location.startsWith('/connect')) {
      return;
    }
    _pending = false;
    unawaited(showAssist(context, listen: true));
  }

  @override
  Widget build(BuildContext context) {
    // Waiting for sign-in / the first screen: try again as they arrive.
    ref
      ..listen(activeProfileProvider, (_, _) => _retry())
      ..listen(syncStatusProvider, (_, _) => _retry());
    return widget.child;
  }

  void _retry() {
    if (_pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpen());
    }
  }
}
