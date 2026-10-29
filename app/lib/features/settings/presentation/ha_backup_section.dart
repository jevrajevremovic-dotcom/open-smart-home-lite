import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../ha_notify/ha_push.dart';
import '../data/ha_backup.dart';
import '../data/settings_backup.dart';

final haBackupsProvider = FutureProvider.autoDispose<List<HaBackup>>((ref) {
  final service = ref.watch(haBackupServiceProvider);
  return service == null ? Future.value(const []) : service.list();
});

/// Settings saved in (and restored from) Home Assistant, by device name.
class HaBackupSection extends ConsumerStatefulWidget {
  const HaBackupSection({super.key});

  @override
  ConsumerState<HaBackupSection> createState() => _HaBackupSectionState();
}

class _HaBackupSectionState extends ConsumerState<HaBackupSection> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) {
      _name.text =
          ref.read(haPushProvider).value?.deviceName ??
          context.l10n.setupDefaultDeviceName;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _guard(Future<void> Function() action) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
    } on AppFailure catch (e) {
      _say(failureMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(haBackupsProvider);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final service = ref.read(haBackupServiceProvider);
    final name = _name.text.trim();
    if (service == null || name.isEmpty) return;
    await _guard(() async {
      final scope = await service.save(name, SettingsBackup.exportMap(ref));
      _say(
        scope == BackupScope.home
            ? l10n.haBackupSavedHome(name)
            : l10n.haBackupSavedUser(name),
      );
    });
  }

  Future<void> _restore(HaBackup b) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.haBackupRestoreTitle(b.name)),
        content: Text(l10n.haBackupRestoreBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('haBackupRestoreConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.haBackupRestore),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _guard(() async {
      final done = await restoreHaBackup(ref, b);
      _say(done ? l10n.backupImported : l10n.backupInvalid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final backups = ref.watch(haBackupsProvider);
    final date = DateFormat.yMd(l10n.localeName).add_Hm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.haBackupTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(l10n.haBackupHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('haBackupName'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.haBackupName),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: const Key('haBackupSave'),
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(l10n.haBackupSave),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...switch (backups) {
          AsyncData(:final value) when value.isEmpty => [
            Text(
              l10n.haBackupNone,
              key: const Key('haBackupNone'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          AsyncData(:final value) => [
            for (final b in value)
              ListTile(
                key: ValueKey('haBackup-${b.scope.name}-${b.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  b.scope == BackupScope.home
                      ? Icons.home_outlined
                      : Icons.person_outline,
                ),
                title: Text(b.name),
                subtitle: Text(
                  [
                    if (b.savedAt != null) date.format(b.savedAt!.toLocal()),
                    b.scope == BackupScope.home
                        ? l10n.haBackupScopeHome
                        : l10n.haBackupScopeUser,
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      key: ValueKey('haBackupRestore-${b.name}'),
                      onPressed: _busy ? null : () => _restore(b),
                      child: Text(l10n.haBackupRestore),
                    ),
                    IconButton(
                      key: ValueKey('haBackupDelete-${b.name}'),
                      tooltip: l10n.haBackupDelete,
                      onPressed: _busy
                          ? null
                          : () => _guard(
                              () async =>
                                  ref.read(haBackupServiceProvider)?.delete(b),
                            ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
          AsyncError() => [Text(l10n.haBackupUnavailable)],
          _ => [const LinearProgressIndicator()],
        },
      ],
    );
  }
}
