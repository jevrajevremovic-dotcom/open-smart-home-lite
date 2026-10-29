import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/brand.dart';
import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/security/pin_hasher.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../ha_notify/ha_push.dart';
import '../kiosk/application/device_admin.dart';
import '../kiosk/application/kiosk_controller.dart';

/// The installer's checklist for a new panel or phone, in order: the
/// connection, rooms, messages, the kiosk with its PIN, the panel's owner
/// rights; then straight into the kiosk.
class InstallerSetupScreen extends ConsumerStatefulWidget {
  const InstallerSetupScreen({super.key});

  @override
  ConsumerState<InstallerSetupScreen> createState() =>
      _InstallerSetupScreenState();
}

class _InstallerSetupScreenState extends ConsumerState<InstallerSetupScreen> {
  int _step = 0;
  final _deviceName = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _pinError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deviceName.text.isEmpty) {
      _deviceName.text = context.l10n.setupDefaultDeviceName;
    }
  }

  @override
  void dispose() {
    _deviceName.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _register() async {
    final l10n = context.l10n;
    final name = _deviceName.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(haPushProvider.notifier).register(name);
    } on AppFailure catch (e) {
      _say(failureMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePin() async {
    final l10n = context.l10n;
    final pin = _pin.text.trim();
    if (!PinHasher.validPin.hasMatch(pin)) {
      setState(() => _pinError = l10n.kioskPinInvalid);
      return;
    }
    await ref.read(kioskSettingsProvider.notifier).setPin(pin);
    _pin.clear();
    setState(() => _pinError = null);
    _say(l10n.setupPinSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ref.watch(connectionStatusProvider).value;
    final host = ref.watch(activeProfileProvider)?.address.baseUri.host;
    final rooms = ref.watch(roomsProvider);
    final noRoom = ref.watch(
      deviceIdsByRoomProvider.select((m) => (m[null] ?? const []).length),
    );
    final push = ref.watch(haPushProvider).value;
    final kiosk = ref.watch(kioskSettingsProvider);
    final device = ref.watch(deviceInfoProvider).value ?? const DeviceInfo();

    Widget done(bool ok, String text) => Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          color: ok ? Colors.green.shade600 : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );

    final steps = <Step>[
      Step(
        title: Text(l10n.setupConnection),
        isActive: _step >= 0,
        state: status?.isConnected == true
            ? StepState.complete
            : StepState.indexed,
        content: done(
          status?.isConnected == true,
          status?.isConnected == true
              ? l10n.setupConnectionOk(host ?? '?', status?.haVersion ?? '?')
              : l10n.setupConnectionMissing,
        ),
      ),
      Step(
        title: Text(l10n.setupRooms),
        isActive: _step >= 1,
        state: rooms.isNotEmpty && noRoom == 0
            ? StepState.complete
            : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            done(rooms.isNotEmpty, l10n.setupRoomsCount(rooms.length)),
            const SizedBox(height: 6),
            done(noRoom == 0, l10n.setupNoRoom(noRoom)),
            const SizedBox(height: 6),
            Text(l10n.setupRoomsHint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      Step(
        title: Text(l10n.setupMessages),
        isActive: _step >= 2,
        state: push != null ? StepState.complete : StepState.indexed,
        content: push != null
            ? done(true, l10n.setupMessagesOk(push.deviceName))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.setupMessagesHint),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('setupDeviceName'),
                    controller: _deviceName,
                    decoration: InputDecoration(
                      labelText: l10n.setupDeviceName,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      key: const Key('setupRegister'),
                      onPressed: _busy ? null : _register,
                      child: Text(l10n.setupRegister),
                    ),
                  ),
                ],
              ),
      ),
      Step(
        title: Text(l10n.setupKiosk),
        isActive: _step >= 3,
        state: kiosk.hasPin && kiosk.startInKiosk
            ? StepState.complete
            : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const Key('setupStartInKiosk'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.kioskStartOnLaunch),
              value: kiosk.startInKiosk,
              onChanged: (v) => ref
                  .read(kioskSettingsProvider.notifier)
                  .update((s) => s.copyWith(startInKiosk: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.kioskKeepAwake),
              value: kiosk.keepScreenOn,
              onChanged: (v) => ref
                  .read(kioskSettingsProvider.notifier)
                  .update((s) => s.copyWith(keepScreenOn: v)),
            ),
            const SizedBox(height: 8),
            done(
              kiosk.hasPin,
              kiosk.hasPin ? l10n.kioskPinSet : l10n.setupPinHint,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('setupPin'),
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: kiosk.hasPin
                          ? l10n.kioskChangePin
                          : l10n.kioskSetPin,
                      errorText: _pinError,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  key: const Key('setupPinSave'),
                  onPressed: _savePin,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
      Step(
        title: Text(l10n.setupPanel),
        isActive: _step >= 4,
        state: device.deviceOwner ? StepState.complete : StepState.indexed,
        content: device.deviceOwner
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  done(true, l10n.servicePanelManaged),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      key: const Key('setupPanelApply'),
                      onPressed: () async {
                        final ok = await ref
                            .read(deviceAdminProvider)
                            .applyPolicies();
                        _say(
                          ok
                              ? l10n.servicePanelApplied
                              : l10n.servicePanelFailed,
                        );
                      },
                      child: Text(l10n.servicePanelApply),
                    ),
                  ),
                ],
              )
            : Text(l10n.setupPanelHint),
      ),
      Step(
        title: Text(l10n.setupDone),
        isActive: _step >= 5,
        content: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('setupStartKiosk'),
            onPressed: () {
              ref.read(kioskActiveProvider.notifier).enter();
              context.go(AppRoutes.kiosk);
            },
            icon: const Icon(Icons.tablet_outlined),
            label: Text(l10n.kioskStart),
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                const BrandLogo(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.setupIntro(Brand.name(l10n)),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stepper(
              key: const Key('setupStepper'),
              currentStep: _step,
              onStepTapped: (i) => setState(() => _step = i),
              onStepContinue: _step < steps.length - 1
                  ? () => setState(() => _step++)
                  : null,
              onStepCancel: _step > 0 ? () => setState(() => _step--) : null,
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (details.onStepContinue != null)
                      FilledButton(
                        key: ValueKey('setupNext-${details.stepIndex}'),
                        onPressed: details.onStepContinue,
                        child: Text(l10n.setupNext),
                      ),
                    const SizedBox(width: 8),
                    if (details.onStepCancel != null)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: Text(l10n.setupBack),
                      ),
                  ],
                ),
              ),
              steps: steps,
            ),
          ),
        ],
      ),
    );
  }
}
