import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../application/device_providers.dart';
import '../data/local/local_home.dart';
import '../domain/smart_home_device.dart';

/// Name and room of [device], kept on this phone.
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
        DeviceEditDialog(initialName: device.name, initialRoom: device.roomId),
  );
  if (result == null) return;
  final (name, roomId) = result;
  await ref
      .read(localHomeProvider.notifier)
      .setNameAndRoom(device.id, name == device.name ? null : name, roomId);
  messenger.showSnackBar(SnackBar(content: Text(l10n.setUpSaved)));
}

/// Removes the physical device of [device] from the app (after asking).
/// Returns whether it was removed.
Future<bool> removeDevice(
  BuildContext context,
  WidgetRef ref,
  SmartHomeDevice device,
) async {
  final key = device.deviceId;
  if (key == null) return false;
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deviceRemove),
      content: Text(l10n.deviceRemoveConfirm(device.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirmRemoveDevice'),
          style: FilledButton.styleFrom(
            backgroundColor: context.statusColors.critical,
            foregroundColor: context.statusColors.onCritical,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.deviceRemove),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(localHomeProvider.notifier).removeDevice(key);
  return true;
}

/// Asks for a room's name and creates it; returns its id.
Future<String?> createRoom(BuildContext context, WidgetRef ref) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _RoomNameDialog(),
  );
  if (name == null || name.trim().isEmpty) return null;
  return ref.read(localHomeProvider.notifier).addRoom(name);
}

class _RoomNameDialog extends StatefulWidget {
  const _RoomNameDialog();

  @override
  State<_RoomNameDialog> createState() => _RoomNameDialogState();
}

class _RoomNameDialogState extends State<_RoomNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.roomNew.replaceAll('…', '')),
      content: TextField(
        key: const Key('roomName'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.roomNameLabel),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('roomNameSave'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// The rooms to choose from, "no room" and "new room…".
class RoomPicker extends ConsumerWidget {
  const RoomPicker({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _new = '__new__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rooms = ref.watch(roomsProvider);
    return InputDecorator(
      decoration: InputDecoration(labelText: l10n.deviceRoomLabel),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: const Key('setUpRoom'),
          value: rooms.any((r) => r.id == value) ? value : null,
          isExpanded: true,
          isDense: true,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.roomNoRoom)),
            for (final r in rooms)
              DropdownMenuItem(value: r.id, child: Text(r.name)),
            DropdownMenuItem(
              key: const Key('setUpRoomNew'),
              value: _new,
              child: Text(l10n.roomNew),
            ),
          ],
          onChanged: (v) async {
            if (v != _new) return onChanged(v);
            final id = await createRoom(context, ref);
            if (id != null) onChanged(id);
          },
        ),
      ),
    );
  }
}

/// Name and room of a device; returns `(name, roomId)` or `null`.
class DeviceEditDialog extends ConsumerStatefulWidget {
  const DeviceEditDialog({
    super.key,
    required this.initialName,
    this.initialRoom,
  });

  final String initialName;
  final String? initialRoom;

  @override
  ConsumerState<DeviceEditDialog> createState() => _DeviceEditDialogState();
}

class _DeviceEditDialogState extends ConsumerState<DeviceEditDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late String? _room = widget.initialRoom;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          RoomPicker(value: _room, onChanged: (v) => setState(() => _room = v)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('setUpSave'),
          onPressed: () => Navigator.of(context).pop((_name.text, _room)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Whether [device] belongs to a device the household added (not the demo).
bool isAddedDevice(LocalHome home, SmartHomeDevice device) =>
    home.devices.any((d) => d.key == device.deviceId);

/// Sets (or, left empty, removes) a device's password, or an ESPHome
/// device's encryption key ([isKey]).
class DevicePasswordDialog extends ConsumerStatefulWidget {
  const DevicePasswordDialog({
    super.key,
    required this.deviceKey,
    this.isKey = false,
  });

  final String deviceKey;
  final bool isKey;

  @override
  ConsumerState<DevicePasswordDialog> createState() =>
      _DevicePasswordDialogState();
}

class _DevicePasswordDialogState extends ConsumerState<DevicePasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = widget.isKey ? l10n.deviceKeyLabel : l10n.devicePasswordLabel;
    return AlertDialog(
      title: Text(label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isKey ? l10n.deviceKeyHint : l10n.devicePasswordHint),
          const SizedBox(height: 8),
          TextField(
            key: const Key('devicePassword'),
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: label),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('devicePasswordSave'),
          onPressed: () async {
            final navigator = Navigator.of(context);
            await ref
                .read(localHomeProvider.notifier)
                .setPassword(widget.deviceKey, _password.text.trim());
            navigator.pop();
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
