import 'dart:async';

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
import '../data/zwave_inclusion.dart';
import 'qr_scan_page.dart';

final _zwaveProvider = Provider.autoDispose<ZwaveInclusion?>((ref) {
  final ws = ref.watch(webSocketManagerProvider);
  return ws == null ? null : ZwaveInclusion(ws);
});

/// Entry id of the Z-Wave JS integration; `null` when there is none.
final zwaveEntryProvider = FutureProvider.autoDispose<String?>((ref) async {
  final z = ref.watch(_zwaveProvider);
  if (z == null) return null;
  try {
    return await z.entryId();
  } on Object {
    return null;
  }
});

enum _Phase { idle, waiting, found, interview, done, failed, stopped }

/// Classic Z-Wave inclusion (with S2 security and PIN) and SmartStart.
class ZwaveInclusionScreen extends ConsumerStatefulWidget {
  const ZwaveInclusionScreen({super.key});

  @override
  ConsumerState<ZwaveInclusionScreen> createState() =>
      _ZwaveInclusionScreenState();
}

class _ZwaveInclusionScreenState extends ConsumerState<ZwaveInclusionScreen> {
  _Phase _phase = _Phase.idle;
  StreamSubscription<ZwaveInclusionEvent>? _sub;
  String? _smartStartMessage;
  bool _smartStartError = false;
  late final Set<String> _known = {
    for (final d in ref.read(homeSnapshotProvider).devices.values) d.id,
  };

  @override
  void dispose() {
    // Cancelling stops inclusion on the controller.
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _start(String entryId) async {
    final z = ref.read(_zwaveProvider);
    if (z == null) return;
    await _sub?.cancel();
    setState(() => _phase = _Phase.waiting);
    _sub = z
        .include(entryId)
        .listen(
          (e) => _onEvent(z, entryId, e),
          onError: (_) {
            if (mounted) setState(() => _phase = _Phase.failed);
          },
        );
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    if (mounted) setState(() => _phase = _Phase.stopped);
  }

  Future<void> _onEvent(
    ZwaveInclusion z,
    String entryId,
    ZwaveInclusionEvent e,
  ) async {
    if (!mounted) return;
    switch (e) {
      case ZwaveNodeFound():
        setState(() => _phase = _Phase.found);
      case ZwaveGrantRequested(:final classes, :final clientSideAuth):
        final granted = await _askGrant(classes);
        await z.grant(
          entryId,
          granted ?? const [],
          clientSideAuth: clientSideAuth,
        );
      case ZwaveDskRequested(:final dsk):
        final pin = await _askPin(dsk);
        // An empty PIN makes the controller abort; that is what cancel means.
        await z.enterPin(entryId, pin ?? '');
      case ZwaveInterviewStarted():
        setState(() => _phase = _Phase.interview);
      case ZwaveInterviewCompleted():
        setState(() => _phase = _Phase.done);
        await _sub?.cancel();
        _sub = null;
      case ZwaveFailed():
        setState(() => _phase = _Phase.failed);
      case ZwaveStopped():
        if (_phase != _Phase.done) setState(() => _phase = _Phase.stopped);
      case ZwaveInclusionStarted() || ZwaveDeviceRegistered() || ZwaveOther():
        break;
    }
  }

  Future<List<ZwaveSecurityClass>?> _askGrant(
    List<ZwaveSecurityClass> requested,
  ) {
    final selected = {...requested};
    return showDialog<List<ZwaveSecurityClass>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = context.l10n;
        String label(ZwaveSecurityClass c) => switch (c) {
          ZwaveSecurityClass.s2Unauthenticated => l10n.zwaveS2Unauth,
          ZwaveSecurityClass.s2Authenticated => l10n.zwaveS2Auth,
          ZwaveSecurityClass.s2AccessControl => l10n.zwaveS2Access,
          ZwaveSecurityClass.s0Legacy => l10n.zwaveS0,
        };
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(l10n.zwaveGrantTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.zwaveGrantBody),
                for (final c in requested)
                  CheckboxListTile(
                    key: ValueKey('zwaveClass-${c.name}'),
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(c),
                    title: Text(label(c)),
                    onChanged: (v) => setState(
                      () => v == true ? selected.add(c) : selected.remove(c),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('zwaveGrant'),
                onPressed: () => Navigator.of(context).pop(selected.toList()),
                child: Text(l10n.zwaveGrant),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _askPin(String dsk) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(dsk: dsk),
  );

  Future<void> _smartStart(String entryId) async {
    final l10n = context.l10n;
    final z = ref.read(_zwaveProvider);
    if (z == null) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => QrScanPage(
          hint: context.l10n.scanPointCameraZwave,
          accept: ZwaveInclusion.isZwaveQr,
        ),
      ),
    );
    if (code == null || !mounted) return;
    try {
      await z.provisionSmartStart(entryId, code);
      setState(() {
        _smartStartMessage = l10n.zwaveSmartStartDone;
        _smartStartError = false;
      });
    } on Object {
      setState(() {
        _smartStartMessage = l10n.zwaveSmartStartInvalid;
        _smartStartError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entry = ref.watch(zwaveEntryProvider);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final added = [
      for (final d in devices.values)
        if (!_known.contains(d.id) && !d.isAuxiliary) d,
    ];
    final active =
        _phase == _Phase.waiting ||
        _phase == _Phase.found ||
        _phase == _Phase.interview;
    final status = switch (_phase) {
      _Phase.idle => null,
      _Phase.waiting => l10n.zwaveStatusWaiting,
      _Phase.found => l10n.zwaveStatusFound,
      _Phase.interview => l10n.zwaveStatusInterview,
      _Phase.done => l10n.zwaveStatusDone,
      _Phase.failed => l10n.zwaveStatusFailed,
      _Phase.stopped => l10n.zwaveStatusStopped,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.zwaveTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: switch (entry) {
          AsyncData(value: null) => [
            InlineNotice.warning(l10n.zwaveNotAvailable),
          ],
          AsyncData(value: final String id) => [
            Text(l10n.zwaveIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (active)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: CircularProgressIndicator(),
                      )
                    else if (_phase == _Phase.done)
                      Icon(
                        Icons.check_circle_outline,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                    if (status != null)
                      Text(
                        status,
                        key: const Key('zwaveStatus'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    const SizedBox(height: 16),
                    if (active)
                      OutlinedButton.icon(
                        key: const Key('zwaveStop'),
                        onPressed: _stop,
                        icon: const Icon(Icons.stop),
                        label: Text(l10n.zwaveStop),
                      )
                    else
                      FilledButton.icon(
                        key: const Key('zwaveStart'),
                        onPressed: () => _start(id),
                        icon: const Icon(Icons.add_link),
                        label: Text(l10n.zwaveStart),
                      ),
                  ],
                ),
              ),
            ),
            for (final d in added)
              ListTile(
                leading: Icon(DevicePresentation.icon(d)),
                title: Text(d.name),
                subtitle: Text(DevicePresentation.status(l10n, d)),
                onTap: () => context.push(AppRoutes.device(d.id)),
              ),
            if (!kIsWeb) ...[
              const SizedBox(height: 24),
              Text(l10n.zwaveSmartStartHint),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('zwaveSmartStart'),
                onPressed: active ? null : () => _smartStart(id),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l10n.zwaveSmartStart),
              ),
              if (_smartStartMessage != null) ...[
                const SizedBox(height: 12),
                _smartStartError
                    ? InlineNotice.error(_smartStartMessage!)
                    : InlineNotice.success(_smartStartMessage!),
              ],
            ],
          ],
          _ => [
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ),
    );
  }
}

/// Asks for the first 5 digits of the device's DSK.
class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.dsk});

  final String dsk;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dsk = widget.dsk;
    // The first group is what the user types; show the rest for comparison.
    final rest = dsk.contains('-') ? dsk.substring(dsk.indexOf('-') + 1) : '';
    return AlertDialog(
      title: Text(l10n.zwavePinTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.zwavePinBody('xxxxx-$rest')),
          const SizedBox(height: 12),
          TextField(
            key: const Key('zwavePin'),
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.zwavePinLabel,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('zwavePinOk'),
          onPressed: () {
            if (_controller.text.length != 5) {
              setState(() => _error = l10n.zwavePinInvalid);
              return;
            }
            Navigator.of(context).pop(_controller.text);
          },
          child: Text(l10n.flowNext),
        ),
      ],
    );
  }
}
