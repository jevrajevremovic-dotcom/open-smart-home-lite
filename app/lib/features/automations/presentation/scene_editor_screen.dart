import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/presentation/device_presentation.dart';
import '../domain/scene_snapshot.dart';

/// Captures the current state of chosen devices as a new HA scene.
class SceneEditorScreen extends ConsumerStatefulWidget {
  const SceneEditorScreen({super.key});

  @override
  ConsumerState<SceneEditorScreen> createState() => _SceneEditorScreenState();
}

class _SceneEditorScreenState extends ConsumerState<SceneEditorScreen> {
  final _name = TextEditingController();
  late final Set<String> _selected = {
    // Start with what is switched on: usually the mood to keep.
    for (final d in ref.read(homeSnapshotProvider).devices.values)
      if (canStoreInScene(d) && d.state.isOn == true) d.id,
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_selected.isEmpty) {
      setState(() => _error = l10n.sceneNeedDevice);
      return;
    }
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    final devices = ref.read(homeSnapshotProvider).devices;
    final name = _name.text.trim().isEmpty
        ? l10n.sceneDefaultName(
            DateFormat.Hm(l10n.localeName).format(DateTime.now()),
          )
        : _name.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await api.saveScene(
        id,
        sceneConfig(id, name, [for (final s in _selected) ?devices[s]]),
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.sceneSaved)));
      navigator.pop();
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.autoSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final rooms = ref.watch(homeSnapshotProvider.select((s) => s.rooms));
    final eligible = devices.values.where(canStoreInScene).toList()
      ..sort((a, b) {
        final ra = rooms[a.roomId]?.name ?? '~';
        final rb = rooms[b.roomId]?.name ?? '~';
        return ra != rb ? ra.compareTo(rb) : a.name.compareTo(b.name);
      });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sceneNew)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.sceneHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            key: const Key('sceneName'),
            controller: _name,
            decoration: InputDecoration(labelText: l10n.sceneName),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(l10n.sceneDevices, style: theme.textTheme.titleMedium),
          ),
          for (final d in eligible)
            CheckboxListTile(
              key: ValueKey('sceneDevice-${d.id}'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(DevicePresentation.icon(d)),
              title: Text(d.name),
              subtitle: Text(
                [
                  ?rooms[d.roomId]?.name,
                  DevicePresentation.status(l10n, d),
                ].join(' · '),
              ),
              value: _selected.contains(d.id),
              onChanged: (v) => setState(
                () => v == true ? _selected.add(d.id) : _selected.remove(d.id),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            InlineNotice.error(_error!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('sceneSave'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.sceneSave),
          ),
        ],
      ),
    );
  }
}
