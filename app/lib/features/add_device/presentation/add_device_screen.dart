import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/presentation/device_edit.dart';
import '../application/add_device_providers.dart';
import '../../devices/data/local/esphome/esphome_client.dart';
import '../../devices/data/local/hue_adapter.dart';
import '../../devices/data/local/lan_http.dart';
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
                      leading: Icon(switch (p.brand) {
                        'WLED' => Icons.light_outlined,
                        'Tasmota' => Icons.outlet_outlined,
                        'ESPHome' => Icons.memory,
                        'Hue' => Icons.hub_outlined,
                        'Yeelight' => Icons.lightbulb_outline,
                        'Kasa' => Icons.outlet_outlined,
                        _ => Icons.power_outlined,
                      }),
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
    final found = await ref.read(deviceProbeProvider).probeAddress(host);
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
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    final choice = await showDialog<(String?, String?)>(
      context: context,
      builder: (_) => _RoomDialog(
        title: found.title,
        secret: found.needsKey
            ? _Secret.key
            : found.needsPassword
            ? _Secret.password
            : null,
      ),
    );
    if (choice == null || !context.mounted) return;
    var (roomId, secret) = choice;
    var device = found;
    if (found.needsLink) {
      secret = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _HueLinkDialog(host: found.device.host),
      );
      if (secret == null) {
        say(l10n.hueLinkFailed);
        return;
      }
    }
    if (found.needsKey) {
      // The key is checked (and, found by address, tells who it is).
      try {
        final checked = await ref
            .read(deviceProbeProvider)
            .probeEsphome(found.device.host, key: secret ?? '');
        if (checked == null) {
          say(l10n.addDeviceNotFound);
          return;
        }
        device = checked;
      } on EsphomeKeyError catch (e) {
        say(
          e.reason == 'notEncrypted'
              ? l10n.deviceKeyNotEncrypted
              : l10n.deviceKeyWrong,
        );
        return;
      }
    }
    await ref
        .read(localHomeProvider.notifier)
        .addDevice(device.device, roomId: roomId, password: secret);
    say(l10n.addDeviceDone(device.title));
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

enum _Secret { password, key }

/// Waits for the bridge's button (asking every 2 s for 30 s); returns the
/// app's user name, or `null`.
class _HueLinkDialog extends ConsumerStatefulWidget {
  const _HueLinkDialog({required this.host});

  final String host;

  @override
  ConsumerState<_HueLinkDialog> createState() => _HueLinkDialogState();
}

class _HueLinkDialogState extends ConsumerState<_HueLinkDialog> {
  Timer? _timer;
  int _tries = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _try());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _try() async {
    if (++_tries > 15) {
      _timer?.cancel();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    String? user;
    try {
      user = await hueLink(ref.read(lanHttpProvider), widget.host);
    } on Object {
      return; // try again
    }
    if (user != null && mounted) {
      _timer?.cancel();
      Navigator.of(context).pop(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('hueLink'),
      title: Text(l10n.hueLinkTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.hueLinkBody),
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
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

/// Which room the new device goes to, and its password or encryption key
/// if it asks for one; returns `(roomId, secret)` or `null`.
class _RoomDialog extends StatefulWidget {
  const _RoomDialog({required this.title, this.secret});

  final String title;
  final _Secret? secret;

  @override
  State<_RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<_RoomDialog> {
  String? _room;
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

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
          if (widget.secret case final secret?) ...[
            const SizedBox(height: 16),
            Text(
              secret == _Secret.key
                  ? l10n.deviceKeyHint
                  : l10n.devicePasswordHint,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('addDevicePassword'),
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: secret == _Secret.key
                    ? l10n.deviceKeyLabel
                    : l10n.devicePasswordLabel,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('addDeviceConfirm'),
          onPressed: () => Navigator.of(
            context,
          ).pop((_room, widget.secret == null ? null : _password.text.trim())),
          child: Text(l10n.addDeviceAdd),
        ),
      ],
    );
  }
}
