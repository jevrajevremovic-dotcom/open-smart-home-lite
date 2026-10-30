import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/data/local/camera_adapter.dart';
import '../../devices/data/local/klap.dart';
import '../../devices/data/local/lan_transport.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/presentation/device_edit.dart';
import '../application/add_device_providers.dart';
import '../../devices/data/local/ble/ble_scanner.dart';
import '../../devices/data/local/esphome/esphome_client.dart';
import '../data/device_probe.dart';
import '../data/lan_discovery.dart';
import 'setup_tips.dart';

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
                      Expanded(child: Text(l10n.addDeviceSearching)),
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
                        'WiZ' || 'LIFX' || 'Govee' => Icons.lightbulb_outline,
                        'Nanoleaf' => Icons.hexagon_outlined,
                        'Sonoff' => Icons.toggle_on_outlined,
                        'Roku' || 'Samsung' || 'LG' => Icons.tv,
                        'Sonos' => Icons.speaker_outlined,
                        'DIRIGERA' => Icons.hub_outlined,
                        'Tapo' => Icons.outlet_outlined,
                        'Tuya' || 'Xiaomi' => Icons.devices_other_outlined,
                        'Broadlink' => Icons.settings_remote_outlined,
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('addCamera'),
                    onPressed: () => _camera(context, ref),
                    icon: const Icon(Icons.videocam_outlined),
                    label: Text(l10n.cameraAdd),
                  ),
                ),
                const SizedBox(height: 16),
                const SetupHelp(),
                const SizedBox(height: 24),
                _BleSection(added: added, onAdd: (p) => _add(context, ref, p)),
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

  Future<void> _camera(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final entered = await showDialog<(Uri, CameraLogin?)>(
      context: context,
      builder: (_) => const _CameraDialog(),
    );
    if (entered == null || !context.mounted) return;
    final (url, login) = entered;
    try {
      await cameraSnapshot(ref.read(lanRequestsProvider), url, login: login);
    } on AppFailure {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.cameraNoImage)));
      return;
    }
    if (!context.mounted) return;
    final choice = await showDialog<(String?, String?)>(
      context: context,
      builder: (_) => _RoomDialog(title: url.host),
    );
    if (choice == null || !context.mounted) return;
    await ref
        .read(localHomeProvider.notifier)
        .addDevice(
          cameraDevice(url),
          roomId: choice.$1,
          password: login?.encode(),
        );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.addDeviceDone(url.host))));
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
            : found.needsAccount
            ? _Secret.account
            : found.needsToken
            ? (found.brand == 'Xiaomi' ? _Secret.miioToken : _Secret.tuyaKey)
            : found.needsPassword
            ? _Secret.password
            : null,
      ),
    );
    if (choice == null || !context.mounted) return;
    var (roomId, secret) = choice;
    var device = found;
    if (found.needsLink) {
      final linked =
          await showDialog<({String secret, ConfiguredDevice device})>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _LinkDialog(found: found),
          );
      if (linked == null) {
        say(found.brand == 'Hue' ? l10n.hueLinkFailed : l10n.linkFailed);
        return;
      }
      secret = linked.secret;
      device = ProbedDevice(
        device: linked.device,
        brand: found.brand,
        name: found.name,
      );
    }
    if (found.needsToken) {
      try {
        device = await ref
            .read(deviceProbeProvider)
            .checkToken(found, secret ?? '');
      } on AppFailure catch (e) {
        say(
          e.kind == FailureKind.authentication ||
                  e.kind == FailureKind.validation
              ? l10n.deviceTokenWrong
              : l10n.addDeviceNotFound,
        );
        return;
      }
    }
    if (found.needsAccount) {
      final account = TpLinkAccount.decode(secret);
      ProbedDevice? checked;
      try {
        checked = account == null
            ? null
            : await ref.read(deviceProbeProvider).checkAccount(found, account);
      } on AppFailure catch (e) {
        say(
          e.kind == FailureKind.authentication
              ? l10n.tpLinkWrongAccount
              : l10n.addDeviceNotFound,
        );
        return;
      }
      if (checked == null) {
        say(l10n.addDeviceNotFound);
        return;
      }
      device = checked;
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

/// A camera's image address and, if it asks, its login.
class _CameraDialog extends StatefulWidget {
  const _CameraDialog();

  @override
  State<_CameraDialog> createState() => _CameraDialogState();
}

class _CameraDialogState extends State<_CameraDialog> {
  final _url = TextEditingController(text: 'http://');
  final _user = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.cameraAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cameraUrlHint),
            TextField(
              key: const Key('cameraUrl'),
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.cameraUrlLabel),
            ),
            TextField(
              key: const Key('cameraUser'),
              controller: _user,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.cameraUserLabel),
            ),
            TextField(
              key: const Key('cameraPassword'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.devicePasswordLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('cameraOk'),
          onPressed: () {
            final url = Uri.tryParse(_url.text.trim());
            if (url == null || !url.hasAuthority) return;
            final user = _user.text.trim();
            Navigator.of(context).pop((
              url,
              user.isEmpty ? null : CameraLogin(user, _password.text),
            ));
          },
          child: Text(l10n.addDeviceAdd),
        ),
      ],
    );
  }
}

enum _Secret { password, key, account, tuyaKey, miioToken }

/// Waits for the device's button or on-screen prompt (asking every 2 s
/// for 30 s); returns what pairing gave, or `null`.
class _LinkDialog extends ConsumerStatefulWidget {
  const _LinkDialog({required this.found});

  final ProbedDevice found;

  @override
  ConsumerState<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends ConsumerState<_LinkDialog> {
  Timer? _timer;
  int _tries = 0;
  bool _asking = false;

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
    if (_asking) return; // a TV may take a while to answer
    if (++_tries > 15) {
      _timer?.cancel();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _asking = true;
    ({String secret, ConfiguredDevice device})? linked;
    try {
      linked = await ref.read(deviceProbeProvider).link(widget.found);
    } on Object {
      return; // try again
    } finally {
      _asking = false;
    }
    if (linked != null && mounted) {
      _timer?.cancel();
      Navigator.of(context).pop(linked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = widget.found.brand;
    return AlertDialog(
      key: const Key('deviceLink'),
      title: Text(brand == 'Hue' ? l10n.hueLinkTitle : l10n.linkTitle(brand)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(switch (widget.found.device.adapter) {
            'nanoleaf' => l10n.nanoleafLinkBody,
            'samsung' || 'lg' => l10n.tvLinkBody,
            'dirigera' => l10n.dirigeraLinkBody,
            _ => l10n.hueLinkBody,
          }),
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
  final _user = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _secret => switch (widget.secret) {
    null => null,
    _Secret.account => TpLinkAccount(
      _user.text.trim(),
      _password.text,
    ).encode(),
    _ => _password.text.trim(),
  };

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
            Text(switch (secret) {
              _Secret.key => l10n.deviceKeyHint,
              _Secret.account => l10n.tpLinkAccountHint,
              _Secret.tuyaKey => l10n.tuyaKeyHint,
              _Secret.miioToken => l10n.miioTokenHint,
              _Secret.password => l10n.devicePasswordHint,
            }),
            const SizedBox(height: 8),
            if (secret == _Secret.account)
              TextField(
                key: const Key('addDeviceUser'),
                controller: _user,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l10n.tpLinkUserLabel),
              ),
            TextField(
              key: const Key('addDevicePassword'),
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: switch (secret) {
                  _Secret.key => l10n.deviceKeyLabel,
                  _Secret.tuyaKey || _Secret.miioToken => l10n.deviceTokenLabel,
                  _ => l10n.devicePasswordLabel,
                },
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
          onPressed: () => Navigator.of(context).pop((_room, _secret)),
          child: Text(l10n.addDeviceAdd),
        ),
      ],
    );
  }
}

/// Bluetooth sensors heard nearby, or why there are none.
class _BleSection extends ConsumerWidget {
  const _BleSection({required this.added, required this.onAdd});

  final Set<String> added;
  final void Function(ProbedDevice) onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final nearby = ref.watch(bleNearbyProvider);
    final reason = switch (nearby.error) {
      BleScanError(:final reason) => reason,
      null => null,
      _ => 'failed',
    };
    if (reason == 'unsupported') return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.bleNearbyTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l10n.bleNearbyHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (reason == 'permission')
          Card.outlined(
            child: ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: Text(l10n.blePermissionHint),
              trailing: FilledButton.tonal(
                key: const Key('blePermission'),
                onPressed: () async {
                  final scanner = ref.read(bleScannerProvider);
                  final messenger = ScaffoldMessenger.of(context);
                  if (await scanner.requestPermission()) {
                    ref.invalidate(bleNearbyProvider);
                    return;
                  }
                  // Refused (or refused for good, when Android no longer
                  // asks): say so, and where to allow it.
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(l10n.blePermissionDenied),
                        action: SnackBarAction(
                          label: l10n.openAppSettings,
                          onPressed: scanner.openSettings,
                        ),
                      ),
                    );
                },
                child: Text(l10n.blePermission),
              ),
            ),
          )
        else if (reason == 'off')
          InlineNotice.warning(l10n.bleOff)
        else if (reason != null)
          InlineNotice.warning(l10n.bleOff)
        else if (nearby.value?.isEmpty ?? true)
          InlineNotice.info(l10n.bleNoneYet)
        else
          for (final p in nearby.value!)
            Card.outlined(
              child: ListTile(
                key: ValueKey('found-${p.device.key}'),
                leading: const Icon(Icons.bluetooth),
                title: Text(p.title),
                subtitle: Text(
                  [
                    ?p.device.model,
                    if (p.detail case final d? when d.isNotEmpty) d,
                  ].join(' · '),
                ),
                trailing: added.contains(p.device.key)
                    ? Chip(label: Text(l10n.addDeviceAdded))
                    : FilledButton.tonal(
                        key: ValueKey('add-${p.device.key}'),
                        onPressed: () => onAdd(p),
                        child: Text(l10n.addDeviceAdd),
                      ),
              ),
            ),
      ],
    );
  }
}
