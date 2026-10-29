import '../../automations/presentation/automation_editor_screen.dart';
import '../../automations/presentation/scene_editor_screen.dart';
import '../../restricted/application/restricted_mode.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/utils/value_list.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_grid.dart';
import '../../devices/presentation/device_presentation.dart';
import 'scene_colors.dart';

/// Ids of routines of one kind, sorted by name.
final routineIdsProvider = Provider.family<ValueList<String>, DeviceKind>((
  ref,
  kind,
) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final list =
      devices.values.where((d) => d.kind == kind && !d.isAuxiliary).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList([for (final d in list) d.id]);
});

class ScenesScreen extends ConsumerWidget {
  const ScenesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scenes = ref.watch(routineIdsProvider(DeviceKind.scene));
    final scripts = ref.watch(routineIdsProvider(DeviceKind.script));
    final automations = ref.watch(routineIdsProvider(DeviceKind.automation));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navScenes)),
      body: MockModeBanner(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ConstrainedContent(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    l10n.scenesTitle,
                    trailing: ref.watch(restrictedModeProvider).enabled
                        ? null
                        : IconButton.filledTonal(
                            key: const Key('newScene'),
                            tooltip: l10n.sceneNew,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SceneEditorScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                          ),
                  ),
                  if (scenes.isEmpty)
                    EmptyHint(
                      icon: Icons.palette_outlined,
                      text: l10n.noScenes,
                    ),
                  for (final id in scenes) _RoutineTile(deviceId: id),
                  if (scripts.isNotEmpty) ...[
                    SectionHeader(l10n.scriptsTitle),
                    for (final id in scripts) _RoutineTile(deviceId: id),
                  ],
                  SectionHeader(
                    l10n.automationsTitle,
                    // Not for children / guests.
                    trailing: ref.watch(restrictedModeProvider).enabled
                        ? null
                        : IconButton.filledTonal(
                            key: const Key('newAutomation'),
                            tooltip: l10n.autoNew,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AutomationEditorScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                          ),
                  ),
                  for (final id in automations) _AutomationTile(deviceId: id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = ref.watch(deviceProvider(deviceId));
    if (d == null) return const SizedBox.shrink();
    return Card.outlined(
      child: ListTile(
        leading: SceneSwatch(
          sceneId: d.id,
          icon: DevicePresentation.icon(d),
          size: 40,
        ),
        title: Text(d.name),
        subtitle: Text(DevicePresentation.status(l10n, d)),
        onTap: () => context.push(AppRoutes.device(d.id)),
        trailing: FilledButton.tonalIcon(
          onPressed: d.available
              ? () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (await runDeviceCommand(
                    context,
                    ref,
                    d,
                    const Activate(),
                  )) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.sceneActivated(d.name))),
                    );
                  }
                }
              : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.activate),
        ),
      ),
    );
  }
}

class _AutomationTile extends ConsumerWidget {
  const _AutomationTile({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = ref.watch(deviceProvider(deviceId));
    if (d == null) return const SizedBox.shrink();
    final last = d.state.lastTriggered;
    return Card.outlined(
      child: ListTile(
        leading: Icon(DevicePresentation.icon(d)),
        title: Text(d.name),
        subtitle: Text(
          last == null
              ? l10n.neverTriggered
              : l10n.lastTriggered(formatDateTime(l10n.localeName, last)),
        ),
        onTap: () => context.push(AppRoutes.device(d.id)),
        trailing: Switch(
          value: d.state.isOn ?? false,
          onChanged: d.available
              ? (v) => runDeviceCommand(
                  context,
                  ref,
                  d,
                  v ? const TurnOn() : const TurnOff(),
                )
              : null,
        ),
      ),
    );
  }
}
