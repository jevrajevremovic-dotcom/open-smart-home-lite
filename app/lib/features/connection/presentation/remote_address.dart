import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/network/server_address.dart';
import '../../authentication/application/session_controller.dart';
import '../application/connection_route.dart';
import 'server_address_screen.dart' show RiskNotice, addressErrorMessage;

/// Settings row for the active home's address away from home.
class RemoteAddressTile extends ConsumerWidget {
  const RemoteAddressTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) return const SizedBox.shrink();
    final remote = profile.remoteAddress;
    final inUse =
        remote != null &&
        ref.watch(connectionRouteProvider) == ConnectionRoute.remote;
    return ListTile(
      key: const Key('remoteAddressTile'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public),
      title: Text(l10n.remoteTitle),
      subtitle: Text(
        remote == null
            ? l10n.remoteNotSet
            : [remote.toString(), if (inUse) l10n.remoteInUse].join('\n'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _RemoteAddressDialog(),
      ),
    );
  }
}

class _RemoteAddressDialog extends ConsumerStatefulWidget {
  const _RemoteAddressDialog();

  @override
  ConsumerState<_RemoteAddressDialog> createState() =>
      _RemoteAddressDialogState();
}

class _RemoteAddressDialogState extends ConsumerState<_RemoteAddressDialog> {
  late final TextEditingController _field = TextEditingController(
    text: ref.read(activeProfileProvider)?.remoteAddress?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  ServerAddress? get _parsed => switch (ServerAddress.parse(_field.text)) {
    ValidServerAddress(:final address) => address,
    _ => null,
  };

  Future<void> _save() async {
    final l10n = context.l10n;
    final profile = ref.read(activeProfileProvider);
    if (profile == null) return;
    final parsed = ServerAddress.parse(_field.text);
    final String? error = switch (parsed) {
      InvalidServerAddress(:final error) => addressErrorMessage(l10n, error),
      ValidServerAddress(:final address) when address == profile.address =>
        l10n.remoteSameAsLocal,
      // Away from home the token would cross the internet unencrypted.
      ValidServerAddress(:final address)
          when address.risk == ConnectionRisk.insecureRemote =>
        l10n.remoteNeedsHttps,
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final navigator = Navigator.of(context);
    await ref
        .read(sessionControllerProvider.notifier)
        .setRemoteAddress((parsed as ValidServerAddress).address);
    navigator.pop();
  }

  Future<void> _remove() async {
    final navigator = Navigator.of(context);
    await ref.read(sessionControllerProvider.notifier).setRemoteAddress(null);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hasRemote = ref.watch(activeProfileProvider)?.remoteAddress != null;
    final shown = _parsed;
    return AlertDialog(
      title: Text(l10n.remoteTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.remoteHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(
                key: const Key('remoteAddressField'),
                controller: _field,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.remoteTitle,
                  hintText: 'https://….ui.nabu.casa',
                  errorText: _error,
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
              ),
              if (shown != null && _error == null) ...[
                const SizedBox(height: 12),
                RiskNotice(address: shown),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (hasRemote)
          TextButton(
            key: const Key('remoteAddressRemove'),
            onPressed: _remove,
            child: Text(l10n.remoteRemove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('remoteAddressSave'),
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
