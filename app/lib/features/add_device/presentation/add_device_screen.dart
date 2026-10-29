import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../authentication/application/session_controller.dart';
import '../application/add_device_providers.dart';
import '../../devices/presentation/device_edit.dart';
import '../data/zigbee_pairing.dart';
import 'discovered_devices_screen.dart';
import 'matter_screen.dart';
import 'zwave_screen.dart';

/// Step 1: what kind of device. Zigbee works today; the others follow.
class AddDeviceScreen extends ConsumerWidget {
  const AddDeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final backends = ref.watch(zigbeeBackendsProvider);

    Widget option({
      required Key key,
      required IconData icon,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
      bool loading = false,
      bool soon = false,
    }) => Card(
      key: key,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        enabled: onTap != null,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : soon
            ? Chip(label: Text(l10n.addDeviceSoon))
            : onTap == null
            ? null
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );

    final zigbee = backends.value ?? const {};
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addDeviceTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.addDeviceIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          option(
            key: const Key('addZigbee'),
            icon: Icons.hub_outlined,
            title: l10n.addDeviceZigbee,
            subtitle: switch (backends) {
              AsyncData() when zigbee.isEmpty => l10n.zigbeeNotFound,
              AsyncData() => [
                l10n.addDeviceZigbeeSubtitle,
                for (final b in zigbee) _backendLabel(context, b),
              ].join(' · '),
              AsyncError(:final error) =>
                error is AppFailure
                    ? failureMessage(l10n, error)
                    : l10n.zigbeeNotFound,
              _ => l10n.addDeviceZigbeeSubtitle,
            },
            loading: backends.isLoading,
            onTap: zigbee.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ZigbeePairingScreen(backends: zigbee),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          option(
            key: const Key('addWifi'),
            icon: Icons.wifi,
            title: l10n.addDeviceWifi,
            subtitle:
                '${l10n.addDeviceWifiSubtitle} · Shelly, ESPHome, Hue, Cast…',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DiscoveredDevicesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          option(
            key: const Key('addMatter'),
            icon: Icons.qr_code_2,
            title: l10n.addDeviceMatter,
            subtitle: l10n.matterIntro,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MatterPairingScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          option(
            key: const Key('addZwave'),
            icon: Icons.settings_input_antenna,
            title: l10n.addDeviceZwave,
            subtitle: '${l10n.zwaveIntro} · S2 / SmartStart',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ZwaveInclusionScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _backendLabel(BuildContext context, ZigbeeBackend b) => switch (b) {
  ZigbeeBackend.zha => context.l10n.zigbeeViaZha,
  ZigbeeBackend.zigbee2mqtt => context.l10n.zigbeeViaZ2m,
};

/// Step 2: open the network, show a countdown and the devices that join.
class ZigbeePairingScreen extends ConsumerStatefulWidget {
  const ZigbeePairingScreen({super.key, required this.backends});

  final Set<ZigbeeBackend> backends;

  @override
  ConsumerState<ZigbeePairingScreen> createState() =>
      _ZigbeePairingScreenState();
}

class _ZigbeePairingScreenState extends ConsumerState<ZigbeePairingScreen> {
  late ZigbeeBackend _backend = widget.backends.first;
  late final PairingController _controller = ref.read(
    pairingControllerProvider.notifier,
  );
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _controller; // created now, so dispose() can still reach it
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(pairingControllerProvider).open) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    // Never leave the network open behind the user's back.
    unawaited(_controller.closeIfOpen());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(pairingControllerProvider);
    final controller = ref.read(pairingControllerProvider.notifier);
    final found = ref.watch(newDevicesProvider);
    final remaining = state.open
        ? state.endsAt!.difference(DateTime.now())
        : Duration.zero;
    final fraction = remaining.inMilliseconds / pairingWindow.inMilliseconds;
    String mmss(Duration d) =>
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

    final steps = [l10n.zigbeeStep1, l10n.zigbeeStep2, l10n.zigbeeStep3];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addDeviceZigbee)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.backends.length > 1) ...[
            SegmentedButton<ZigbeeBackend>(
              segments: [
                for (final b in widget.backends)
                  ButtonSegment(
                    value: b,
                    label: Text(_backendLabel(context, b)),
                  ),
              ],
              selected: {_backend},
              onSelectionChanged: state.open
                  ? null
                  : (s) => setState(() => _backend = s.first),
            ),
            const SizedBox(height: 16),
          ],
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 140,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: state.open ? fraction : 0,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                        Center(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              state.open ? mmss(remaining) : '—',
                              key: const Key('pairingCountdown'),
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.open
                        ? '${l10n.pairingOpen} · ${l10n.pairingRemaining(mmss(remaining))}'
                        : l10n.pairingClosed,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (state.failure != null) ...[
                    const SizedBox(height: 12),
                    InlineNotice.error(
                      l10n.pairingFailed(failureMessage(l10n, state.failure!)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        key: const Key('pairingStart'),
                        onPressed: state.busy
                            ? null
                            : () => controller.start(_backend),
                        icon: state.busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: Text(
                          state.open ? l10n.pairingExtend : l10n.pairingStart,
                        ),
                      ),
                      if (state.open)
                        OutlinedButton.icon(
                          key: const Key('pairingStop'),
                          onPressed: controller.stop,
                          icon: const Icon(Icons.stop),
                          label: Text(l10n.pairingStop),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (state.started) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                l10n.pairingFound,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (found.isEmpty)
              ListTile(
                leading: state.open
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_off),
                title: Text(l10n.pairingWaiting),
              ),
            for (final d in found)
              Card(
                key: ValueKey('newDevice-${d.key}'),
                child: ListTile(
                  leading: Icon(DevicePresentation.icon(d.primary)),
                  title: Text(d.primary.name),
                  subtitle: Text(
                    [
                      ?d.primary.manufacturer,
                      ?d.primary.model,
                      DevicePresentation.status(l10n, d.primary),
                    ].join(' · '),
                  ),
                  onTap: () => context.push(AppRoutes.device(d.primary.id)),
                  trailing: d.haDeviceId == null
                      ? null
                      : TextButton(
                          key: ValueKey('setUp-${d.key}'),
                          onPressed: () => _setUp(d),
                          child: Text(l10n.newDeviceSetUp),
                        ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _setUp(NewDevice d) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => DeviceEditDialog(initialName: d.primary.name),
    );
    if (result == null || !mounted) return;
    final ws = ref.read(webSocketManagerProvider);
    final (name, areaId) = result;
    try {
      if (ws == null) {
        throw const AppFailure(FailureKind.webSocket);
      }
      await DeviceRegistryEditor(ws).update(
        d.haDeviceId!,
        name: name.trim().isEmpty ? null : name.trim(),
        areaId: areaId,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.setUpSaved)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.setUpFailed)));
    }
  }
}
