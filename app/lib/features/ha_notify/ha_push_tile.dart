import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../alerts/alert_notifications.dart';
import '../authentication/application/session_controller.dart';
import 'ha_push.dart';
import '../device_sensors/device_sensors.dart';
import '../device_sensors/smart_charge_tile.dart';

/// Settings row: let Home Assistant automations send messages here.
class HaPushTile extends ConsumerWidget {
  const HaPushTile({super.key});

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    if (!await ref.read(alertNotifierProvider).requestPermission()) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.alertsPermissionDenied)),
      );
      return;
    }
    try {
      await ref.read(haPushProvider.notifier).register(name.trim());
    } on AppFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(alertNotifierProvider).supported) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final registration = ref.watch(haPushProvider).value;
    if (registration == null) {
      return ListTile(
        key: const Key('haPushTile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.campaign_outlined),
        title: Text(l10n.haPushTitle),
        subtitle: Text(
          ref.watch(haPushRemovedProvider)
              ? l10n.haPushRemovedInHa
              : l10n.haPushHint,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _register(context, ref),
      );
    }
    final service = registration.notifyService;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('haPushTile'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.campaign_outlined),
          title: Text(l10n.haPushTitle),
          subtitle: Text(l10n.haPushReady(service)),
          trailing: IconButton(
            key: const Key('haPushCopy'),
            tooltip: l10n.haPushCopy,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: service));
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.haPushCopied)));
            },
          ),
        ),
        if (ref.watch(backgroundConnectionProvider).supported)
          SwitchListTile(
            key: const Key('haPushBackground'),
            contentPadding: const EdgeInsets.only(left: 40),
            title: Text(l10n.haPushBackground),
            subtitle: Text(l10n.haPushBackgroundHint),
            value: ref.watch(haPushBackgroundProvider),
            onChanged: (v) =>
                ref.read(haPushBackgroundProvider.notifier).set(v),
          ),
        if (ref.watch(deviceBatteryProvider).supported) ...[
          SwitchListTile(
            key: const Key('deviceSensorsSwitch'),
            contentPadding: const EdgeInsets.only(left: 40),
            title: Text(l10n.deviceSensorsSwitch),
            subtitle: Text(l10n.deviceSensorsHint),
            value: ref.watch(deviceSensorsProvider),
            onChanged: (v) => ref.read(deviceSensorsProvider.notifier).set(v),
          ),
          if (ref.watch(deviceSensorsProvider)) const SmartChargeTile(),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('haPushTest'),
              onPressed: () async {
                final api = ref.read(homeAssistantApiProvider);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await api?.callService(
                    'notify',
                    service.substring('notify.'.length),
                    data: {
                      'title': 'Open Smart Home',
                      'message': l10n.haPushTestMessage,
                    },
                  );
                } on AppFailure catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(failureMessage(l10n, e))),
                  );
                }
              },
              icon: const Icon(Icons.send_outlined),
              label: Text(l10n.haPushTest),
            ),
            TextButton(
              key: const Key('haPushForget'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.haPushForget),
                    content: Text(l10n.haPushForgetHint),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        key: const Key('haPushForgetConfirm'),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.haPushForget),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(haPushProvider.notifier).forget();
                }
              },
              child: Text(l10n.haPushForget),
            ),
          ],
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _name = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) _name.text = context.l10n.haPushDefaultName;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.haPushTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.haPushExplain),
          const SizedBox(height: 16),
          TextField(
            key: const Key('haPushName'),
            controller: _name,
            decoration: InputDecoration(labelText: l10n.haPushName),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('haPushRegister'),
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.haPushRegister),
        ),
      ],
    );
  }
}
