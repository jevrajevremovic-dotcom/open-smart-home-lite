import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../application/app_lock.dart';

/// Covers the whole app while it is locked. Kiosk mode has its own PIN
/// and is never locked this way.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  bool _prompting = false;

  Future<void> _unlock() async {
    if (_prompting) return;
    _prompting = true;
    await ref.read(appLockProvider.notifier).unlock(context.l10n.appLockReason);
    _prompting = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appLockSettingsProvider, (_, s) {
      ref.read(appLockProvider.notifier).settingsChanged(s);
    });
    final locked =
        ref.watch(appLockProvider) && !ref.watch(kioskActiveProvider);
    if (locked && !_prompting) {
      // Ask right away; the button stays for a second try.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(appLockProvider)) _unlock();
      });
    }
    return Stack(
      children: [
        // Hidden content stays mounted (connection, timers) but invisible
        // and unreachable while locked.
        ExcludeSemantics(
          excluding: locked,
          child: Offstage(offstage: locked, child: widget.child),
        ),
        if (locked) const Positioned.fill(child: _LockScreen()),
      ],
    );
  }
}

class _LockScreen extends ConsumerWidget {
  const _LockScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Material(
      key: const Key('appLockScreen'),
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(l10n.appLockTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('appUnlock'),
                onPressed: () => ref
                    .read(appLockProvider.notifier)
                    .unlock(l10n.appLockReason),
                icon: const Icon(Icons.fingerprint),
                label: Text(l10n.appUnlock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
