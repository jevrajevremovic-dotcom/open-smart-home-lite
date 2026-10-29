import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/kiosk_controller.dart';
import '../data/approach_platform.dart';
import '../data/kiosk_settings.dart';

/// "Wake the screen when someone comes near" in the kiosk settings.
class ApproachSettings extends ConsumerWidget {
  const ApproachSettings({super.key});

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    ApproachWake value,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(kioskSettingsProvider.notifier);
    if (value == ApproachWake.camera) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.videocam_outlined),
          title: Text(l10n.approachCameraTitle),
          content: SingleChildScrollView(child: Text(l10n.approachCameraBody)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('approachCameraAllow'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.approachCameraAllow),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (!await ref.read(approachPlatformProvider).requestPermission()) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.approachCameraDenied)));
        return;
      }
    }
    await controller.update((s) => s.copyWith(approachWake: value));
    if (value == ApproachWake.sensor &&
        ref.read(kioskSettingsProvider).approachSensorId == null &&
        context.mounted) {
      await _pickSensor(context, ref);
    }
  }

  Future<void> _pickSensor(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final sensors =
        ref
            .read(homeSnapshotProvider)
            .devices
            .values
            .where(
              (d) =>
                  d.kind == DeviceKind.motionSensor ||
                  d.kind == DeviceKind.occupancySensor,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.approachSensorPick),
        children: [
          if (sensors.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(l10n.approachNoSensors),
            ),
          for (final d in sensors)
            SimpleDialogOption(
              key: ValueKey('approachPick-${d.id}'),
              onPressed: () => Navigator.of(context).pop(d.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(DevicePresentation.icon(d)),
                title: Text(d.name),
              ),
            ),
        ],
      ),
    );
    if (id == null) return;
    await ref
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(approachSensorId: id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(kioskSettingsProvider);
    final camera = ref.watch(approachPlatformProvider).supported;
    final sensorId = settings.approachSensorId;
    final sensor = sensorId == null
        ? null
        : ref.watch(deviceProvider(sensorId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.directions_walk_rounded),
          title: Text(l10n.approachWake),
          subtitle: Text(l10n.approachWakeHint),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: DropdownButton<ApproachWake>(
            key: const Key('approachWake'),
            isExpanded: true,
            value: settings.approachWake == ApproachWake.camera && !camera
                ? ApproachWake.off
                : settings.approachWake,
            onChanged: (v) => v == null ? null : _choose(context, ref, v),
            items: [
              DropdownMenuItem(
                value: ApproachWake.off,
                child: Text(l10n.approachOff),
              ),
              DropdownMenuItem(
                value: ApproachWake.sensor,
                child: Text(l10n.approachSensor),
              ),
              if (camera)
                DropdownMenuItem(
                  value: ApproachWake.camera,
                  child: Text(l10n.approachCamera),
                ),
            ],
          ),
        ),
        if (settings.approachWake == ApproachWake.sensor)
          ListTile(
            key: const Key('approachSensor'),
            contentPadding: const EdgeInsets.only(left: 40),
            leading: Icon(
              sensor == null
                  ? Icons.sensors_outlined
                  : DevicePresentation.icon(sensor),
            ),
            title: Text(l10n.approachSensorPick),
            subtitle: Text(sensor?.name ?? l10n.clapTargetNone),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickSensor(context, ref),
          ),
      ],
    );
  }
}
