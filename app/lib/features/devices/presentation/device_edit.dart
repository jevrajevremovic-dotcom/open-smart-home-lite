import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/errors/app_failure.dart';
import '../../add_device/data/zigbee_pairing.dart';
import '../../authentication/application/session_controller.dart';
import '../application/device_providers.dart';
import '../domain/smart_home_device.dart';

/// Renames an entity and/or moves it to a room in Home Assistant's entity
/// registry (frontend's `config/entity_registry/update`; admin), for
/// entities without a device such as helpers.
Future<void> updateEntityRegistry(
  WidgetRef ref,
  String entityId, {
  String? name,
  String? areaId,
}) async {
  final ws = ref.read(webSocketManagerProvider);
  if (ws == null) throw const AppFailure(FailureKind.webSocket);
  await ws.sendCommand({
    'type': 'config/entity_registry/update',
    'entity_id': entityId,
    'name': ?name,
    'area_id': ?areaId,
  });
}

/// Edit name and room of [device]: the HA device when there is one,
/// otherwise the entity. Shows a message when HA refuses (not admin).
Future<void> editDevice(
  BuildContext context,
  WidgetRef ref,
  SmartHomeDevice device,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<(String, String?)>(
    context: context,
    builder: (_) =>
        DeviceEditDialog(initialName: device.name, initialArea: device.roomId),
  );
  if (result == null) return;
  final (rawName, areaId) = result;
  final name = rawName.trim().isEmpty ? null : rawName.trim();
  try {
    final ws = ref.read(webSocketManagerProvider);
    if (ws == null) throw const AppFailure(FailureKind.webSocket);
    if (device.deviceId != null) {
      await DeviceRegistryEditor(ws)
          .update(device.deviceId!, name: name, areaId: areaId);
    } else {
      await updateEntityRegistry(ref, device.id, name: name, areaId: areaId);
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.setUpSaved)));
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.setUpFailed)));
  }
}

/// Name and room of a device; returns `(name, areaId)` or `null`.
class DeviceEditDialog extends ConsumerStatefulWidget {
  const DeviceEditDialog({
    super.key,
    required this.initialName,
    this.initialArea,
  });

  final String initialName;
  final String? initialArea;

  @override
  ConsumerState<DeviceEditDialog> createState() => _DeviceEditDialogState();
}

class _DeviceEditDialogState extends ConsumerState<DeviceEditDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late String? _area = widget.initialArea;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rooms = ref.watch(roomsProvider);
    return AlertDialog(
      title: Text(l10n.setUpDeviceTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('setUpName'),
            controller: _name,
            decoration: InputDecoration(labelText: l10n.deviceNameLabel),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: const Key('setUpRoom'),
            initialValue: _area,
            decoration: InputDecoration(labelText: l10n.deviceRoomLabel),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.roomNoRoom)),
              for (final r in rooms)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setState(() => _area = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('setUpSave'),
          onPressed: () => Navigator.of(context).pop((_name.text, _area)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
