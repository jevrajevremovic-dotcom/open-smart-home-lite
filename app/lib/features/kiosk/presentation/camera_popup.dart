import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/utils/value_list.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../authentication/application/session_controller.dart';
import '../../cameras/presentation/camera_view.dart';
import '../../cameras/presentation/live_camera.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/data/home_state_repository.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_actions.dart';
import '../application/kiosk_controller.dart';

/// Devices that may pop up the camera: a doorbell, or something that turns
/// "on" (motion, presence, a door or gate contact).
bool isPopupTrigger(SmartHomeDevice d) =>
    !d.isAuxiliary &&
    (d.kind == DeviceKind.doorbell ||
        const {
          DeviceKind.motionSensor,
          DeviceKind.occupancySensor,
          DeviceKind.contactSensor,
          DeviceKind.binarySensor,
          DeviceKind.vibrationSensor,
        }.contains(d.kind));

/// What "Open" on the doorbell pop-up can work: a lock, a gate or garage
/// door, or a button (e.g. a gate opener).
bool isDoorOpener(SmartHomeDevice d) =>
    (d.kind == DeviceKind.lock && d.supports(Capability.unlock)) ||
    (d.kind == DeviceKind.garageDoor && d.supports(Capability.open)) ||
    (d.kind == DeviceKind.button && d.supports(Capability.trigger));

/// The command "Open" sends to [d].
DeviceCommand doorOpenCommand(SmartHomeDevice d) => switch (d.kind) {
  DeviceKind.lock => const UnlockDevice(),
  DeviceKind.button => const Activate(),
  _ => const OpenCover(),
};

/// What counts as "it happened" for a trigger: a doorbell press (its time
/// changes) or a sensor turning on.
Object? _signal(SmartHomeDevice? d) => switch (d) {
  null => null,
  _ when !d.available => null,
  _ when d.kind == DeviceKind.doorbell => d.state.lastTriggered,
  _ => d.state.isActive == true,
};

/// Watches the chosen triggers and shows the chosen camera full screen
/// over any kiosk page; [onShow] wakes the screen.
class KioskCameraPopup extends ConsumerStatefulWidget {
  const KioskCameraPopup({
    super.key,
    required this.child,
    required this.onShow,
  });

  final Widget child;
  final VoidCallback onShow;

  @override
  ConsumerState<KioskCameraPopup> createState() => _KioskCameraPopupState();
}

class _KioskCameraPopupState extends ConsumerState<KioskCameraPopup> {
  String? _triggerName;
  Timer? _hide;

  /// Result of "Coming!" (shown under the buttons).
  String? _replyNote;
  int _left = 0;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _show(String triggerName) {
    final seconds = ref.read(kioskSettingsProvider).popupSeconds;
    widget.onShow();
    setState(() {
      _triggerName = triggerName;
      _left = seconds;
      _replyNote = null;
    });
    _hide?.cancel();
    _hide = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) _close();
    });
  }

  void _close() {
    _hide?.cancel();
    if (mounted) setState(() => _triggerName = null);
  }

  Future<void> _open(SmartHomeDevice d) async {
    // Unlocking / opening is critical: the usual confirmation applies.
    if (await runDeviceCommand(context, ref, d, doorOpenCommand(d))) _close();
  }

  /// "Coming!" through the speaker by the door, with Home Assistant's own
  /// text-to-speech (`tts.speak` on its first TTS entity).
  Future<void> _reply(String speakerId) async {
    final l10n = context.l10n;
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    void note(String text) {
      if (mounted) setState(() => _replyNote = text);
    }

    try {
      final tts = (await api.fetchStates())
          .map((s) => s.entityId)
          .where((id) => id.startsWith('tts.'))
          .firstOrNull;
      if (tts == null) {
        note(l10n.kioskIntercomNoTts);
        return;
      }
      await api.callService(
        'tts',
        'speak',
        data: {
          'entity_id': tts,
          'media_player_entity_id': speakerId,
          'message': l10n.kioskIntercomReplyText,
        },
      );
      note(l10n.kioskIntercomReplied);
    } on AppFailure catch (e) {
      note(failureMessage(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(kioskSettingsProvider);
    final cameraId = settings.popupCameraId;
    if (settings.hasPopup) {
      // Value-equal: only the triggers' own changes notify.
      ref.listen<ValueList<Object?>>(
        homeSnapshotProvider.select(
          (s) => ValueList([
            for (final id in settings.popupTriggerIds) _signal(s.devices[id]),
          ]),
        ),
        (previous, next) {
          // Only live changes: not the cached state shown at start-up.
          if (previous == null ||
              previous.length != next.length ||
              ref.read(syncStatusProvider) != SyncStatus.live) {
            return;
          }
          for (final (i, id) in settings.popupTriggerIds.indexed) {
            final before = previous[i];
            final now = next[i];
            final fired = now is DateTime
                ? before is DateTime && now.isAfter(before)
                : now == true && before == false;
            if (fired) {
              _show(ref.read(deviceProvider(id))?.name ?? id);
              return;
            }
          }
        },
      );
    }
    final l10n = context.l10n;
    final opener = settings.popupOpenId == null
        ? null
        : ref.watch(deviceProvider(settings.popupOpenId!));
    final speaker = settings.popupSpeakerId;
    return Stack(
      children: [
        widget.child,
        if (_triggerName != null && cameraId != null)
          Positioned.fill(
            child: ColoredBox(
              key: const Key('kioskCameraPopup'),
              color: Colors.black,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _triggerName!,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          Text(
                            l10n.kioskPopupClosesIn(_left),
                            style: const TextStyle(color: Colors.white54),
                          ),
                          IconButton(
                            key: const Key('kioskPopupClose'),
                            tooltip: l10n.close,
                            color: Colors.white,
                            iconSize: 32,
                            icon: const Icon(Icons.close),
                            onPressed: _close,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: settings.popupLive && liveVideoSupported
                              ? LiveCameraView(
                                  cameraId: cameraId,
                                  fallback: CameraPicture(
                                    cameraId: cameraId,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : CameraPicture(
                                  cameraId: cameraId,
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    ),
                    if (opener != null || speaker != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            if (speaker != null)
                              FilledButton.tonalIcon(
                                key: const Key('kioskIntercomReply'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(200, 64),
                                ),
                                onPressed: () => _reply(speaker),
                                icon: const Icon(Icons.record_voice_over),
                                label: Text(l10n.kioskIntercomReply),
                              ),
                            if (opener != null)
                              FilledButton.icon(
                                key: const Key('kioskIntercomOpen'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(200, 64),
                                ),
                                onPressed: () => _open(opener),
                                icon: Icon(
                                  opener.kind == DeviceKind.lock
                                      ? Icons.lock_open
                                      : Icons.door_sliding_outlined,
                                ),
                                label: Text(
                                  opener.kind == DeviceKind.lock
                                      ? l10n.kioskIntercomUnlock(opener.name)
                                      : l10n.kioskIntercomOpenDevice(
                                          opener.name,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_replyNote != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _replyNote!,
                          key: const Key('kioskIntercomNote'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
