import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/app_theme.dart';
import '../../integrations/home_assistant/websocket/connection_status.dart';
import '../config/app_config.dart';

/// Inline message with icon + text (never colour alone).
class InlineNotice extends StatelessWidget {
  const InlineNotice.error(this.message, {super.key})
    : _severity = _Severity.critical;
  const InlineNotice.warning(this.message, {super.key})
    : _severity = _Severity.warning;
  const InlineNotice.info(this.message, {super.key})
    : _severity = _Severity.info;
  const InlineNotice.success(this.message, {super.key})
    : _severity = _Severity.ok;

  final String message;
  final _Severity _severity;

  @override
  Widget build(BuildContext context) {
    final status = context.statusColors;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (_severity) {
      _Severity.critical => (Icons.error_outline, status.critical),
      _Severity.warning => (Icons.warning_amber_rounded, status.warning),
      _Severity.info => (Icons.info_outline, scheme.onSurfaceVariant),
      _Severity.ok => (Icons.check_circle_outline, status.ok),
    };
    return Semantics(
      liveRegion: _severity == _Severity.critical,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

enum _Severity { critical, warning, info, ok }

/// Compact connection indicator: icon + label, colour as a secondary cue.
class ConnectionStatusChip extends StatelessWidget {
  const ConnectionStatusChip({super.key, required this.status});

  final HaConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.statusColors;
    final (IconData icon, Color color, String label) = switch (status.state) {
      HaConnectionState.connected => (
        Icons.cloud_done_outlined,
        colors.ok,
        l10n.statusConnected,
      ),
      HaConnectionState.connecting => (
        Icons.sync,
        colors.warning,
        l10n.statusConnecting,
      ),
      HaConnectionState.authenticating => (
        Icons.key,
        colors.warning,
        l10n.statusAuthenticating,
      ),
      HaConnectionState.reconnecting => (
        Icons.sync_problem,
        colors.warning,
        status.nextRetryIn == null
            ? l10n.statusReconnecting
            : l10n.statusReconnectingIn(
                status.nextRetryIn!.inSeconds.clamp(1, 999),
              ),
      ),
      HaConnectionState.serverUnavailable => (
        Icons.cloud_off,
        colors.critical,
        l10n.statusServerUnavailable,
      ),
      HaConnectionState.authenticationFailed => (
        Icons.lock_outline,
        colors.critical,
        l10n.statusAuthFailed,
      ),
      HaConnectionState.error => (
        Icons.error_outline,
        colors.critical,
        l10n.statusError,
      ),
      HaConnectionState.disconnected => (
        Icons.link_off,
        colors.unavailable,
        l10n.statusDisconnected,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(icon, color: color, size: 20),
        label: Text(label),
        side: BorderSide(color: color),
      ),
    );
  }
}

/// Visible on every screen while mock mode is active.
class MockModeBanner extends ConsumerWidget {
  const MockModeBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).mockMode) return child;
    final colors = context.statusColors;
    return Column(
      children: [
        Material(
          color: colors.warning,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 18,
                    color: colors.onWarning,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.l10n.mockModeBanner,
                      style: TextStyle(
                        color: colors.onWarning,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
