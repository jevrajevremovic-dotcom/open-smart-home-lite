import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/security/pin_hasher.dart';
import '../../devices/application/device_providers.dart';
import '../application/kiosk_controller.dart';
import '../application/kiosk_people.dart';

/// Asks for the PIN and leaves kiosk mode when it matches. Without a
/// configured PIN it exits immediately. Returns `true` on exit.
Future<bool> showKioskExitDialog(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(kioskActiveProvider.notifier);
  if (!ref.read(kioskSettingsProvider).hasPin) {
    await controller.tryExit('');
    return true;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => PinEntryDialog(
      title: context.l10n.kioskEnterPin,
      onSubmit: (pin) async {
        final l10n = context.l10n;
        return switch (await controller.tryExit(pin)) {
          PinCheck.accepted => null,
          PinCheck.wrong => l10n.kioskWrongPin,
          PinCheck.lockedOut => l10n.kioskLockedOut(
            controller.remainingLockout?.inSeconds ?? 30,
          ),
        };
      },
    ),
  );
  return ok ?? false;
}

/// Before something only grown-ups may do on the wall panel (unlocking a
/// door, disarming): asks for the panel's PIN or a household member's own
/// PIN, when any is set; does not leave kiosk mode. Members without a PIN
/// (children) cannot. Returns `true` when allowed.
Future<bool> confirmKioskPin(BuildContext context, WidgetRef ref) async {
  if (!ref.read(kioskCriticalPinRequiredProvider)) return true;
  final controller = ref.read(kioskActiveProvider.notifier);
  final user = ref.read(kioskUserProvider);
  final name = user == null ? null : ref.read(deviceProvider(user))?.name;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => PinEntryDialog(
      title: name == null
          ? context.l10n.kioskEnterPin
          : context.l10n.kioskPersonEnterPin(name),
      helper: context.l10n.kioskCriticalPinHint,
      onSubmit: (pin) async {
        final l10n = context.l10n;
        final (check, person) = await controller.verifyCriticalPin(pin);
        // A member's PIN also tells the panel who is there.
        if (person != null) {
          ref.read(kioskUserProvider.notifier).select(person);
        }
        return switch (check) {
          PinCheck.accepted => null,
          PinCheck.wrong => l10n.kioskWrongPin,
          PinCheck.lockedOut => l10n.kioskLockedOut(
            controller.remainingLockout?.inSeconds ?? 30,
          ),
        };
      },
    ),
  );
  return ok ?? false;
}

/// Asks for a new PIN twice and stores it with [save] (the panel's PIN
/// by default). Returns `true` when saved.
Future<bool> showSetPinDialog(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  Future<void> Function(String pin)? save,
}) async {
  final l10n = context.l10n;
  String? first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => PinEntryDialog(
      title: title ?? l10n.kioskSetPin,
      helper: l10n.kioskPinHint,
      onSubmit: (pin) async {
        if (!PinHasher.validPin.hasMatch(pin)) return l10n.kioskPinInvalid;
        first = pin;
        return null;
      },
    ),
  );
  if (ok != true || first == null || !context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => PinEntryDialog(
      title: l10n.kioskPinConfirm,
      onSubmit: (pin) async {
        if (pin != first) return l10n.kioskPinMismatch;
        if (save != null) {
          await save(pin);
        } else {
          await ref.read(kioskSettingsProvider.notifier).setPin(pin);
        }
        return null;
      },
    ),
  );
  return confirmed ?? false;
}

/// Digit-only, obscured PIN field. [onSubmit] returns an error message, or
/// `null` to close the dialog with `true`.
class PinEntryDialog extends StatefulWidget {
  const PinEntryDialog({
    super.key,
    required this.title,
    required this.onSubmit,
    this.helper,
  });

  final String title;
  final String? helper;
  final Future<String?> Function(String pin) onSubmit;

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    _controller.clear();
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.pin_outlined),
      title: Text(widget.title),
      content: TextField(
        key: const Key('pinField'),
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, letterSpacing: 12),
        decoration: InputDecoration(
          helperText: widget.helper,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('pinSubmit'),
          onPressed: _busy ? null : _submit,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
