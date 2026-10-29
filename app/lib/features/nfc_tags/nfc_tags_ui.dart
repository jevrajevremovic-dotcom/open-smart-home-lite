import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/logging/app_logger.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../ha_notify/ha_push.dart';
import 'nfc_tags.dart';

/// Passes scanned tags to Home Assistant: the one that opened the app and
/// any scanned while it runs. Waits for the connection if needed.
class NfcScanHost extends ConsumerStatefulWidget {
  const NfcScanHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NfcScanHost> createState() => _NfcScanHostState();
}

class _NfcScanHostState extends ConsumerState<NfcScanHost> {
  static final _log = AppLogger('Nfc');

  /// Scanned tags waiting for the connection: (id, held to the phone).
  final List<(String, bool)> _pending = [];
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    final nfc = ref.read(nfcPlatformProvider);
    if (!nfc.supported) return;
    _sub = nfc.scans.listen(_scanned);
    unawaited(
      nfc.initialTag().then((id) {
        if (id != null) _scanned(id);
      }, onError: (Object e) => _log.info('no initial tag: ${e.runtimeType}')),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  /// `nfc:<id>` (a tag held to the phone) or `link:<id>` (the same
  /// address from a QR code, a web page or another app).
  void _scanned(String raw) {
    final physical = raw.startsWith('nfc:');
    final id = raw.replaceFirst(RegExp('^(nfc|link):'), '');
    _pending.add((id, physical));
    unawaited(_flush());
  }

  /// A link could come from any app or web page: run it only if the user
  /// says so.
  Future<bool> _confirmLink(BuildContext context, String? name) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) {
          final l10n = dialog.l10n;
          return AlertDialog(
            icon: const Icon(Icons.qr_code_2),
            title: Text(l10n.nfcLinkConfirmTitle),
            content: Text(
              name == null
                  ? l10n.nfcLinkConfirmUnnamed
                  : l10n.nfcLinkConfirm(name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('nfcLinkConfirm'),
                onPressed: () => Navigator.of(dialog).pop(true),
                child: Text(l10n.nfcLinkRun),
              ),
            ],
          );
        },
      ) ==
      true;

  Future<void> _flush() async {
    final connected =
        ref.read(connectionStatusProvider).value?.isConnected ?? false;
    if (!mounted || !connected) return;
    final registration = ref.read(haPushProvider).value;
    final manager = ref.read(webSocketManagerProvider);
    final navigator = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    final messenger = navigator == null
        ? null
        : ScaffoldMessenger.maybeOf(navigator);
    final l10n = navigator?.l10n;
    while (_pending.isNotEmpty) {
      final (id, physical) = _pending.removeAt(0);
      try {
        final tags = await ref
            .read(haTagsProvider.future)
            .catchError((Object _) => const <HaTag>[]);
        final name = tags.where((t) => t.id == id).firstOrNull?.name;
        if (!physical &&
            (navigator == null ||
                !navigator.mounted ||
                !await _confirmLink(navigator, name))) {
          continue;
        }
        await reportTagScan(manager, registration, id);
        if (l10n != null) {
          final text = name == null
              ? l10n.nfcScannedUnnamed
              : l10n.nfcScanned(name);
          messenger
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(text)));
        }
      } on AppFailure catch (e) {
        if (l10n == null) continue;
        final reason = registration == null
            ? l10n.nfcNeedsRegistration
            : failureMessage(l10n, e);
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.nfcScanFailed(reason))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectionStatusProvider, (_, next) {
      if (next.value?.isConnected ?? false) unawaited(_flush());
    });
    return widget.child;
  }
}

/// Settings → NFC tags: the tags Home Assistant knows and writing new ones.
class NfcTagsSection extends ConsumerStatefulWidget {
  const NfcTagsSection({super.key});

  @override
  ConsumerState<NfcTagsSection> createState() => _NfcTagsSectionState();
}

class _NfcTagsSectionState extends ConsumerState<NfcTagsSection> {
  (bool, bool)? _availability;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final a = await ref.read(nfcPlatformProvider).availability();
      if (mounted) setState(() => _availability = a);
    } on Object {
      if (mounted) setState(() => _availability = (false, false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tags = ref.watch(haTagsProvider);
    final registered = ref.watch(haPushProvider).value != null;
    final (hardware, enabled) = _availability ?? (true, true);
    Widget notice(String text, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: context.statusColors.warning,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.nfcHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (!hardware)
          notice(l10n.nfcMissing, key: const Key('nfcMissing'))
        else if (!enabled)
          notice(l10n.nfcOff, key: const Key('nfcOff')),
        if (!registered)
          notice(
            l10n.nfcNeedsRegistration,
            key: const Key('nfcNeedsRegistration'),
          ),
        if (hardware)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('nfcNew'),
              onPressed: enabled ? () => _newTag(context) : null,
              icon: const Icon(Icons.nfc),
              label: Text(l10n.nfcNew),
            ),
          ),
        const SizedBox(height: 16),
        switch (tags) {
          AsyncData(:final value) when value.isEmpty => Text(
            l10n.nfcEmpty,
            style: theme.textTheme.bodyMedium,
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final t in value)
                ListTile(
                  key: ValueKey('nfcTag-${t.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.nfc),
                  title: Text(t.name ?? t.id),
                  subtitle: Text(
                    t.lastScanned == null
                        ? l10n.nfcNeverScanned
                        : l10n.nfcLastScanned(
                            DateFormat.MMMd(l10n.localeName)
                                .add_Hm()
                                .format(t.lastScanned!),
                          ),
                  ),
                ),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  Future<void> _newTag(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _NewTagDialog(),
    );
    if (choice == null || !context.mounted) return;
    final (name, target) = choice;
    final nfc = ref.read(nfcPlatformProvider);
    final id = newTagId();

    // Wait for the tag; the user can cancel.
    final written = Completer<NfcWriteError?>();
    unawaited(
      nfc
          .write(haTagUri(id))
          .then(
            (_) => written.complete(null),
            onError: (Object e) => written.complete(
              e is NfcWriteException ? e.error : NfcWriteError.failed,
            ),
          ),
    );
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => AlertDialog(
          key: const Key('nfcHoldDialog'),
          icon: const Icon(Icons.nfc, size: 40),
          content: Text(l10n.nfcHold, textAlign: TextAlign.center),
          actions: [
            TextButton(
              key: const Key('nfcCancel'),
              onPressed: () => unawaited(nfc.cancel()),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
    final error = await written.future;
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (error != null) {
      if (error == NfcWriteError.cancelled) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (error) {
            NfcWriteError.readOnly => l10n.nfcErrorReadOnly,
            NfcWriteError.tooSmall => l10n.nfcErrorTooSmall,
            NfcWriteError.unsupported => l10n.nfcErrorUnsupported,
            NfcWriteError.unavailable => l10n.nfcOff,
            _ => l10n.nfcErrorFailed,
          }),
        ),
      );
      return;
    }

    // Written: name it in Home Assistant and make it run the choice.
    try {
      final manager = ref.read(webSocketManagerProvider);
      final api = ref.read(homeAssistantApiProvider);
      if (manager == null || api == null) {
        throw const AppFailure(FailureKind.webSocket);
      }
      await manager.sendCommand({
        'type': 'tag/create',
        'tag_id': id,
        'name': name,
      });
      await api.saveAutomation(
        'osh_tag_${id.toLowerCase().replaceAll('-', '')}',
        tagAutomation(alias: 'NFC: $name', tagId: id, target: target),
      );
      ref.invalidate(haTagsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.nfcWritten(name))));
    } on AppFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.nfcWrittenNoAdmin)));
    }
  }
}

class _NewTagDialog extends ConsumerStatefulWidget {
  const _NewTagDialog();

  @override
  ConsumerState<_NewTagDialog> createState() => _NewTagDialogState();
}

class _NewTagDialogState extends ConsumerState<_NewTagDialog> {
  final _name = TextEditingController();
  String? _target;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final routines =
        devices.values
            .where(
              (d) => d.kind == DeviceKind.scene || d.kind == DeviceKind.script,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final ready = _name.text.trim().isNotEmpty && _target != null;
    return AlertDialog(
      title: Text(l10n.nfcNew),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('nfcName'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.nfcName),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('nfcTarget'),
            initialValue: _target,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.nfcRuns),
            items: [
              for (final r in routines)
                DropdownMenuItem(
                  value: r.id,
                  child: Text(r.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _target = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('nfcWrite'),
          onPressed: ready
              ? () => Navigator.of(context).pop((_name.text.trim(), _target!))
              : null,
          child: Text(l10n.nfcWrite),
        ),
      ],
    );
  }
}
