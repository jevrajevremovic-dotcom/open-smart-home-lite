import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/errors/app_failure.dart';
import '../data/lan_transfer.dart';
import '../data/settings_backup.dart';

/// Keep the home in a file, send it to another device over Wi-Fi, or copy
/// it as text; and the way back.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _withSecrets = false;
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  bool get _passwordOk => !_withSecrets || _password.text.length >= 6;

  Future<String> _export() => _withSecrets
      ? SettingsBackup.exportWithSecrets(ref, _password.text)
      : Future.value(SettingsBackup.export(ref));

  // ---------------------------------------------------------------------
  // Out

  Future<void> _saveFile() async {
    final text = await _export();
    final dir = await getTemporaryDirectory();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/open-smart-home-$day.json');
    await file.writeAsString(text);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
    );
  }

  Future<void> _send() async {
    final l10n = context.l10n;
    final text = await _export();
    final LanTransferServer server;
    try {
      server = await LanTransferServer.start(text);
    } on AppFailure {
      _say(l10n.backupNoWifi);
      return;
    }
    if (!mounted) return;
    final dialog = showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('backupSendDialog'),
        title: Text(l10n.backupSend),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.backupSendTitle),
            const SizedBox(height: 12),
            Text(l10n.backupAddress),
            SelectableText(
              server.address,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(l10n.backupCode),
            SelectableText(
              server.code,
              key: const Key('backupSendCode'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.backupSendWaiting,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    final navigator = Navigator.of(context);
    final sent = await Future.any([server.done, dialog.then((_) => false)]);
    await server.stop();
    if (sent) {
      if (navigator.canPop()) navigator.pop();
      _say(l10n.backupSent);
    }
  }

  // ---------------------------------------------------------------------
  // In

  Future<void> _openFile() async {
    final picked = await FilePicker.pickFiles();
    final path = picked.singleOrNull?.path;
    if (path == null) return;
    await _import(
      utf8.decode(await File(path).readAsBytes(), allowMalformed: true),
    );
  }

  Future<void> _receive() async {
    final l10n = context.l10n;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _ReceiveDialog(),
    );
    if (result == null) return;
    try {
      await _import(await receiveBackup(result.$1, result.$2));
    } on LanTransferError catch (e) {
      _say(
        e == LanTransferError.wrongCode
            ? l10n.backupWrongCode
            : l10n.backupUnreachable,
      );
    }
  }

  Future<void> _paste() async {
    final l10n = context.l10n;
    final text = (await Clipboard.getData('text/plain'))?.text;
    if (text == null) {
      _say(l10n.backupInvalid);
      return;
    }
    await _import(text);
  }

  /// The password if it has secrets, replace or add, then in.
  Future<void> _import(String text) async {
    final l10n = context.l10n;
    String? password;
    if (SettingsBackup.hasSecrets(text)) {
      password = await showDialog<String>(
        context: context,
        builder: (_) => const _PasswordDialog(),
      );
      if (password == null) return;
    }
    if (!mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.backupHowTitle),
        children: [
          ListTile(
            key: const Key('backupReplace'),
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.backupReplace),
            subtitle: Text(l10n.backupReplaceHint),
            onTap: () => Navigator.of(context).pop(true),
          ),
          ListTile(
            key: const Key('backupMerge'),
            leading: const Icon(Icons.playlist_add),
            title: Text(l10n.backupMerge),
            subtitle: Text(l10n.backupMergeHint),
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (replace == null) return;
    final result = await SettingsBackup.import(
      ref,
      text,
      password: password,
      replace: replace,
    );
    _say(switch (result) {
      BackupImport.done => l10n.backupImported,
      BackupImport.notBackup => l10n.backupInvalid,
      BackupImport.needsPassword ||
      BackupImport.wrongPassword => l10n.backupWrongPassword,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.backupHint, style: textTheme.bodyMedium),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const Key('backupWithSecrets'),
          contentPadding: EdgeInsets.zero,
          value: _withSecrets,
          onChanged: (v) => setState(() => _withSecrets = v ?? false),
          title: Text(l10n.backupWithSecrets),
          subtitle: Text(l10n.backupWithSecretsHint),
        ),
        if (_withSecrets)
          TextField(
            key: const Key('backupPassword'),
            controller: _password,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.backupPassword,
              helperText: l10n.backupPasswordShort,
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: const Key('backupSaveFile'),
              onPressed: _passwordOk ? _saveFile : null,
              icon: const Icon(Icons.save_alt),
              label: Text(l10n.backupSaveFile),
            ),
            FilledButton.tonalIcon(
              key: const Key('backupSend'),
              onPressed: _passwordOk ? _send : null,
              icon: const Icon(Icons.send_to_mobile),
              label: Text(l10n.backupSend),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('backupOpenFile'),
              onPressed: _openFile,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(l10n.backupOpenFile),
            ),
            OutlinedButton.icon(
              key: const Key('backupReceive'),
              onPressed: _receive,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(l10n.backupReceive),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.backupFileTitle, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('backupCopy'),
              onPressed: _passwordOk
                  ? () async {
                      final text = await _export();
                      await Clipboard.setData(ClipboardData(text: text));
                      _say(l10n.backupCopied);
                    }
                  : null,
              icon: const Icon(Icons.copy),
              label: Text(l10n.backupCopy),
            ),
            OutlinedButton.icon(
              key: const Key('backupPaste'),
              onPressed: _paste,
              icon: const Icon(Icons.paste),
              label: Text(l10n.backupPaste),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog();

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  final _address = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.backupReceive),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('backupReceiveAddress'),
            controller: _address,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.backupAddress,
              hintText: '192.168.1.23:48721',
            ),
          ),
          TextField(
            key: const Key('backupReceiveCode'),
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.backupCode),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('backupReceiveOk'),
          onPressed: () =>
              Navigator.of(context).pop((_address.text, _code.text)),
          child: Text(l10n.backupReceive),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
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
      title: Text(l10n.backupPassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.backupAskPassword),
          TextField(
            key: const Key('backupImportPassword'),
            controller: _password,
            obscureText: true,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('backupImportPasswordOk'),
          onPressed: () => Navigator.of(context).pop(_password.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
