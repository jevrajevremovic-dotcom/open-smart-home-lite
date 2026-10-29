import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/routines_controller.dart';
import '../domain/routines.dart';

/// A scene from how the chosen devices are now; [scene] to change one.
class SceneEditorScreen extends ConsumerStatefulWidget {
  const SceneEditorScreen({super.key, this.scene});

  final LocalScene? scene;

  @override
  ConsumerState<SceneEditorScreen> createState() => _SceneEditorScreenState();
}

class _SceneEditorScreenState extends ConsumerState<SceneEditorScreen> {
  late final _name = TextEditingController(text: widget.scene?.name);
  late final Set<String> _chosen = {
    for (final a in widget.scene?.actions ?? const <DeviceAction>[]) a.deviceId,
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_chosen.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sceneNeedDevice)));
      return;
    }
    final devices = ref.read(homeSnapshotProvider).devices;
    final name = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : l10n.sceneDefaultName(
            DateFormat.Hm(l10n.localeName).format(DateTime.now()),
          );
    await ref
        .read(routinesProvider.notifier)
        .saveScene(
          LocalScene(
            id: widget.scene?.id ?? RoutinesController.newId(),
            name: name,
            actions: [
              for (final id in _chosen)
                if (devices[id] case final d?) ...actionsForState(d),
            ],
          ),
        );
    messenger.showSnackBar(SnackBar(content: Text(l10n.sceneSavedLocal)));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices =
        ref
            .watch(homeSnapshotProvider.select((s) => s.devices))
            .values
            .where(canStoreInScene)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final rooms = {for (final r in ref.watch(roomsProvider)) r.id: r.name};
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scene == null ? l10n.sceneNew : widget.scene!.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConstrainedContent(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InlineNotice.info(l10n.sceneHintLocal),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('sceneName'),
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.sceneName),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.sceneDevices,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                for (final d in devices)
                  CheckboxListTile(
                    key: ValueKey('sceneDevice-${d.id}'),
                    contentPadding: EdgeInsets.zero,
                    value: _chosen.contains(d.id),
                    onChanged: (v) => setState(
                      () =>
                          v == true ? _chosen.add(d.id) : _chosen.remove(d.id),
                    ),
                    secondary: Icon(DevicePresentation.icon(d)),
                    title: Text(d.name),
                    subtitle: Text(
                      [
                        ?rooms[d.roomId],
                        DevicePresentation.status(l10n, d),
                      ].join(' · '),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('sceneSave'),
                  onPressed: _save,
                  child: Text(l10n.sceneSave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks a device (matching [where]); returns its id.
Future<String?> pickDevice(
  BuildContext context, {
  required bool Function(SmartHomeDevice d) where,
}) => showDialog<String>(
  context: context,
  builder: (_) => _DevicePickerDialog(where: where),
);

class _DevicePickerDialog extends ConsumerStatefulWidget {
  const _DevicePickerDialog({required this.where});

  final bool Function(SmartHomeDevice d) where;

  @override
  ConsumerState<_DevicePickerDialog> createState() =>
      _DevicePickerDialogState();
}

class _DevicePickerDialogState extends ConsumerState<_DevicePickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.toLowerCase();
    final devices =
        ref
            .watch(homeSnapshotProvider.select((s) => s.devices))
            .values
            .where(widget.where)
            .where((d) => q.isEmpty || d.name.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return AlertDialog(
      title: Text(l10n.autoPickDevice),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final d in devices)
                    ListTile(
                      key: ValueKey('pick-${d.id}'),
                      leading: Icon(DevicePresentation.icon(d)),
                      title: Text(d.name),
                      subtitle: Text(DevicePresentation.status(l10n, d)),
                      onTap: () => Navigator.of(context).pop(d.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
