import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/presentation/device_presentation.dart';
import '../data/matter_pairing.dart';
import 'qr_scan_page.dart';

/// Whether Home Assistant has the Matter integration.
final matterAvailableProvider = Provider.autoDispose<bool?>((ref) {
  final config = ref.watch(serverConfigProvider);
  return config.value?.components.contains('matter');
});

/// Adds a Matter device shared from another app, by QR code or the
/// 11-digit manual code.
class MatterPairingScreen extends ConsumerStatefulWidget {
  const MatterPairingScreen({super.key});

  @override
  ConsumerState<MatterPairingScreen> createState() =>
      _MatterPairingScreenState();
}

enum _Phase { input, adding, done, failed }

class _MatterPairingScreenState extends ConsumerState<MatterPairingScreen> {
  final _code = TextEditingController();
  String? _codeError;
  String? _newError;
  _Phase _phase = _Phase.input;
  late final Set<String> _known = {
    for (final d in ref.read(homeSnapshotProvider).devices.values) d.id,
  };

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => QrScanPage(
          hint: context.l10n.scanPointCamera,
          accept: (v) => v.toUpperCase().startsWith('MT:'),
        ),
      ),
    );
    if (scanned != null && mounted) {
      _code.text = scanned;
      await _add();
    }
  }

  Future<void> _addNew() async {
    final l10n = context.l10n;
    final ws = ref.read(webSocketManagerProvider);
    if (ws == null) return;
    final platform = ref.read(matterNewDeviceProvider);
    platform.onCommissionRequest(
      (pin, ip) => MatterCommissioner(ws).commissionOnNetwork(pin, ip),
    );
    setState(() {
      _newError = null;
      _phase = _Phase.adding;
    });
    try {
      final added = await platform.commissionNewDevice();
      if (mounted) setState(() => _phase = added ? _Phase.done : _Phase.input);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.input;
        _newError = e.code == 'unavailable'
            ? l10n.matterNoPlayServices
            : l10n.matterNewFailed;
      });
    }
  }

  Future<void> _add() async {
    final l10n = context.l10n;
    final code = MatterCode.normalize(_code.text);
    if (code == null) {
      setState(() => _codeError = l10n.matterInvalidCode);
      return;
    }
    final ws = ref.read(webSocketManagerProvider);
    if (ws == null) return;
    setState(() {
      _codeError = null;
      _phase = _Phase.adding;
    });
    try {
      await MatterCommissioner(ws).commission(code);
      if (mounted) setState(() => _phase = _Phase.done);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final available = ref.watch(matterAvailableProvider);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final added = [
      for (final d in devices.values)
        if (!_known.contains(d.id) && !d.isAuxiliary) d,
    ];
    final steps = [l10n.matterStep1, l10n.matterStep2, l10n.matterStep3];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.matterTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (available == false)
            InlineNotice.warning(l10n.matterNotAvailable)
          else ...[
            if (ref.watch(matterNewDeviceProvider).supported &&
                _phase != _Phase.done) ...[
              Text(l10n.matterNewTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(l10n.matterNewHint),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('matterNewDevice'),
                onPressed: _phase == _Phase.adding ? null : _addNew,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(l10n.matterNewButton),
              ),
              if (_newError != null) ...[
                const SizedBox(height: 12),
                InlineNotice.error(_newError!),
              ],
              const Divider(height: 40),
              Text(l10n.matterSharedTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
            ],
            Text(l10n.matterIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            for (final (i, s) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (_phase == _Phase.done) ...[
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              Text(
                l10n.matterAdded,
                key: const Key('matterAdded'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              for (final d in added)
                ListTile(
                  leading: Icon(DevicePresentation.icon(d)),
                  title: Text(d.name),
                  subtitle: Text([?d.manufacturer, ?d.model].join(' · ')),
                  onTap: () => context.push(AppRoutes.device(d.id)),
                ),
            ] else ...[
              if (!kIsWeb)
                FilledButton.tonalIcon(
                  key: const Key('matterScan'),
                  onPressed: _phase == _Phase.adding ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.matterScan),
                ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('matterCode'),
                controller: _code,
                enabled: _phase != _Phase.adding,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.matterCodeLabel,
                  hintText: l10n.matterCodeHint,
                  errorText: _codeError,
                ),
                onChanged: (_) {
                  if (_codeError != null) setState(() => _codeError = null);
                },
                onSubmitted: (_) => _add(),
              ),
              const SizedBox(height: 16),
              if (_phase == _Phase.failed) ...[
                InlineNotice.error(l10n.matterFailed),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                key: const Key('matterAdd'),
                onPressed: _phase == _Phase.adding ? null : _add,
                icon: _phase == _Phase.adding
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _phase == _Phase.adding ? l10n.matterAdding : l10n.flowAdd,
                ),
              ),
            ],
            if (!ref.watch(matterNewDeviceProvider).supported) ...[
              const SizedBox(height: 24),
              Text(
                l10n.matterNewDeviceNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
