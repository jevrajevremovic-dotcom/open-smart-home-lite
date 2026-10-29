import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/presentation/device_edit.dart';
import '../application/add_device_providers.dart';
import '../data/device_probe.dart';
import '../data/lan_discovery.dart';

/// Shelly and WLED devices on the Wi-Fi network, found by themselves or
/// by their IP address, added to the home with a room.
class AddDeviceScreen extends ConsumerWidget {
  const AddDeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final found = ref.watch(discoveredDevicesProvider).value ?? const [];
    final added = {for (final d in ref.watch(localHomeProvider).devices) d.key};
    final searching = ref.watch(lanDiscoveryProvider).isSupported;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addDeviceTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConstrainedContent(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.addDeviceLanHint, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                if (searching)
                  Row(
                    children: [
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.addDeviceSearching),
                    ],
                  ),
                const SizedBox(height: 8),
                if (found.isEmpty) InlineNotice.info(l10n.addDeviceNoneYet),
                for (final p in found)
                  Card.outlined(
                    child: ListTile(
                      key: ValueKey('found-${p.device.key}'),
                      leading: Icon(
                        p.brand == 'WLED'
                            ? Icons.light_outlined
                            : Icons.power_outlined,
                      ),
                      title: Text(p.title),
                      subtitle: Text(
                        [p.brand, ?p.device.model, p.device.host].join(' · '),
                      ),
                      trailing: added.contains(p.device.key)
                          ? Chip(label: Text(l10n.addDeviceAdded))
                          : FilledButton.tonal(
                              key: ValueKey('add-${p.device.key}'),
                              onPressed: () => _add(context, ref, p),
                              child: Text(l10n.addDeviceAdd),
                            ),
                    ),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('addDeviceManual'),
                    onPressed: () => _manual(context, ref),
                    icon: const Icon(Icons.dialpad),
                    label: Text(l10n.addDeviceManual),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manual(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final host = await showDialog<String>(
      context: context,
      builder: (_) => const _AddressDialog(),
    );
    if (host == null || host.isEmpty || !context.mounted) return;
    final found = await ref.read(deviceProbeProvider).probe(host);
    if (!context.mounted) return;
    if (found == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.addDeviceNotFound)));
      return;
    }
    await _add(context, ref, found);
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    ProbedDevice found,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final room = await showDialog<(String?,)>(
      context: context,
      builder: (_) => _RoomDialog(title: found.title),
    );
    if (room == null) return;
    await ref
        .read(localHomeProvider.notifier)
        .addDevice(found.device, roomId: room.$1);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.addDeviceDone(found.title))));
  }
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog();

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void done() => Navigator.of(context).pop(_controller.text.trim());
    return AlertDialog(
      title: Text(l10n.addDeviceManual),
      content: TextField(
        key: const Key('addDeviceAddress'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: l10n.addDeviceAddressLabel,
          hintText: '192.168.1.50',
        ),
        onSubmitted: (_) => done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('addDeviceAddressOk'),
          onPressed: done,
          child: Text(l10n.addDeviceAdd),
        ),
      ],
    );
  }
}

/// Which room the new device goes to; returns `(roomId,)` or `null`.
class _RoomDialog extends StatefulWidget {
  const _RoomDialog({required this.title});

  final String title;

  @override
  State<_RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<_RoomDialog> {
  String? _room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.addDeviceWhere),
          const SizedBox(height: 12),
          RoomPicker(value: _room, onChanged: (v) => setState(() => _room = v)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('addDeviceConfirm'),
          onPressed: () => Navigator.of(context).pop((_room,)),
          child: Text(l10n.addDeviceAdd),
        ),
      ],
    );
  }
}
