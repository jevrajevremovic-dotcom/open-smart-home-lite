import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../assist/application/voice_providers.dart';
import '../../dashboard/application/home_summaries.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/kiosk_controller.dart';

/// Covers the whole kiosk when something needs attention now: smoke, CO,
/// water, a triggered alarm, a jammed lock (red, also spoken), or a door
/// or window open for too long (amber). "Got it" hides an alert until it
/// clears and comes back.
class KioskAlertOverlay extends ConsumerStatefulWidget {
  const KioskAlertOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskAlertOverlay> createState() => _KioskAlertOverlayState();
}

class _KioskAlertOverlayState extends ConsumerState<KioskAlertOverlay> {
  /// Acknowledged alerts, until they clear.
  final Set<String> _seen = {};

  /// Critical alerts already spoken (once each time they start).
  final Set<String> _spoken = {};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // "Open too long" becomes true with time alone.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  List<(SmartHomeDevice, bool)> _alerts() {
    final settings = ref.watch(kioskSettingsProvider);
    if (!settings.alertOverlay || !ref.watch(kioskActiveProvider)) {
      return const [];
    }
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final now = DateTime.now();
    final limit = Duration(minutes: settings.openAlertMinutes);
    final critical = <SmartHomeDevice>[];
    final open = <SmartHomeDevice>[];
    for (final d in devices.values) {
      if (d.isAuxiliary) continue;
      if (isCriticalAlert(d)) {
        critical.add(d);
      } else if (settings.openAlertMinutes > 0 &&
          isOpening(d) &&
          d.metadata.lastChanged != null &&
          now.difference(d.metadata.lastChanged!) >= limit) {
        open.add(d);
      }
    }
    final active = {
      for (final d in [...critical, ...open]) d.id,
    };
    // Cleared alerts may come back later.
    _seen.retainWhere(active.contains);
    _spoken.retainWhere(active.contains);
    return [
      for (final d in critical)
        if (!_seen.contains(d.id)) (d, true),
      for (final d in open)
        if (!_seen.contains(d.id)) (d, false),
    ];
  }

  void _announce(List<(SmartHomeDevice, bool)> alerts) {
    final fresh = [
      for (final (d, critical) in alerts)
        if (critical && !_spoken.contains(d.id)) d,
    ];
    if (fresh.isEmpty) return;
    _spoken.addAll(fresh.map((d) => d.id));
    // Seen from across the room: wake the screen.
    if (ref.read(kioskDimmedProvider)) {
      ref.read(kioskDimmedProvider.notifier).set(false);
    }
    final speech = ref.read(speechOutputProvider);
    if (!speech.supported) return;
    final l10n = context.l10n;
    for (final d in fresh) {
      unawaited(
        speech
            .speak(
              l10n.kioskAlertSpeech(d.name, DevicePresentation.status(l10n, d)),
              languageTag: l10n.localeName,
            )
            .catchError((Object _) => false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts();
    if (alerts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _announce(alerts);
      });
      if (alerts.any((a) => !a.$2) && ref.read(kioskDimmedProvider)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(kioskDimmedProvider.notifier).set(false);
        });
      }
    }
    return Stack(
      children: [
        widget.child,
        if (alerts.isNotEmpty)
          Positioned.fill(
            child: _AlertScreen(
              device: alerts.first.$1,
              critical: alerts.first.$2,
              more: alerts.length - 1,
              onSeen: () => setState(() => _seen.add(alerts.first.$1.id)),
            ),
          ),
      ],
    );
  }
}

class _AlertScreen extends ConsumerWidget {
  const _AlertScreen({
    required this.device,
    required this.critical,
    required this.more,
    required this.onSeen,
  });

  final SmartHomeDevice device;
  final bool critical;
  final int more;
  final VoidCallback onSeen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bg = critical ? const Color(0xFFB3261E) : const Color(0xFFB86E00);
    final rooms = ref.watch(roomsProvider);
    final room = rooms
        .where((r) => r.id == device.roomId)
        .map((r) => r.name)
        .firstOrNull;
    final changed = device.metadata.lastChanged;
    final minutes = changed == null
        ? null
        : DateTime.now().difference(changed).inMinutes;
    final status = critical || minutes == null
        ? DevicePresentation.status(l10n, device)
        : l10n.kioskAlertOpenFor(minutes);
    const white = Colors.white;
    return Material(
      key: Key(critical ? 'kioskAlertCritical' : 'kioskAlertOpen'),
      color: bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      critical
                          ? Icons.warning_rounded
                          : DevicePresentation.icon(device),
                      size: 120,
                      color: white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      device.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [?room, status].join(' · '),
                      key: const Key('kioskAlertStatus'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (more > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.kioskAlertMore(more),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          key: const Key('kioskAlertSeen'),
                          style: FilledButton.styleFrom(
                            backgroundColor: white,
                            foregroundColor: bg,
                            minimumSize: const Size(220, 64),
                            textStyle: theme.textTheme.titleLarge,
                          ),
                          onPressed: onSeen,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(l10n.kioskAlertAck),
                        ),
                        OutlinedButton.icon(
                          key: const Key('kioskAlertDevice'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: white,
                            side: const BorderSide(color: white, width: 2),
                            minimumSize: const Size(220, 64),
                            textStyle: theme.textTheme.titleLarge,
                          ),
                          onPressed: () {
                            onSeen();
                            unawaited(
                              context.push(
                                AppRoutes.device(device.id, kiosk: true),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(l10n.kioskAlertShow),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
