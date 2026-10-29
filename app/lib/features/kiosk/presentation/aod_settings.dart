import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/kiosk_controller.dart';
import '../data/kiosk_settings.dart';
import '../../../core/widgets/time_picker.dart';
import 'glass.dart' show kioskPhotoStoreProvider;

/// Kiosk settings: the always-on screen and the morning screen.
class AodSettings extends ConsumerWidget {
  const AodSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final s = ref.watch(kioskSettingsProvider);
    final controller = ref.read(kioskSettingsProvider.notifier);
    String time(int minutes) =>
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

    Future<int?> pick(int current, String help) async {
      final t = await showAppTimePicker(
        context: context,
        helpText: help,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      );
      return t == null ? null : t.hour * 60 + t.minute;
    }

    String focusLabel(AodFocus f) => switch (f) {
      AodFocus.none => l10n.aodFocusNone,
      AodFocus.nextEvent => l10n.aodFocusNextEvent,
      AodFocus.list => l10n.aodFocusList,
      AodFocus.device => l10n.aodFocusDevice,
      AodFocus.energy => l10n.aodFocusEnergy,
      AodFocus.media => l10n.aodFocusMedia,
      AodFocus.home => l10n.aodFocusHome,
    };
    final needsEntity =
        s.aodFocus == AodFocus.list || s.aodFocus == AodFocus.device;
    final entity = s.aodEntityId == null
        ? null
        : ref.watch(deviceProvider(s.aodEntityId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(l10n.aodTitle, style: theme.textTheme.labelLarge),
        ),
        Text(l10n.aodHint, style: theme.textTheme.bodySmall),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.aodFocus),
          // Under the title: long labels and large text fit a phone.
          subtitle: DropdownButton<AodFocus>(
            key: const Key('aodFocus'),
            value: s.aodFocus,
            isExpanded: true,
            items: [
              for (final f in AodFocus.values)
                DropdownMenuItem(value: f, child: Text(focusLabel(f))),
            ],
            onChanged: (v) => v == null
                ? null
                : controller.update(
                    (k) => k.copyWith(aodFocus: v, clearAodEntity: true),
                  ),
          ),
        ),
        if (needsEntity)
          ListTile(
            key: const Key('aodEntity'),
            contentPadding: const EdgeInsets.only(left: 16),
            title: Text(entity?.name ?? l10n.aodChoose),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final id = await showDialog<String>(
                context: context,
                builder: (_) =>
                    _DevicePickerDialog(lists: s.aodFocus == AodFocus.list),
              );
              if (id != null) {
                await controller.update((k) => k.copyWith(aodEntityId: id));
              }
            },
          ),
        SwitchListTile(
          key: const Key('morningScreen'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.morningScreen),
          subtitle: Text(
            s.morningScreen
                ? '${time(s.morningFrom)} – ${time(s.morningTo)}'
                : l10n.morningScreenHint,
          ),
          value: s.morningScreen,
          onChanged: (v) =>
              controller.update((k) => k.copyWith(morningScreen: v)),
        ),
        if (s.morningScreen)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('morningFrom'),
                  onPressed: () async {
                    final m = await pick(s.morningFrom, l10n.morningFrom);
                    if (m != null) {
                      await controller.update(
                        (k) => k.copyWith(morningFrom: m),
                      );
                    }
                  },
                  icon: const Icon(Icons.wb_twilight),
                  label: Text('${l10n.morningFrom} ${time(s.morningFrom)}'),
                ),
                OutlinedButton.icon(
                  key: const Key('morningTo'),
                  onPressed: () async {
                    final m = await pick(s.morningTo, l10n.morningTo);
                    if (m != null) {
                      await controller.update((k) => k.copyWith(morningTo: m));
                    }
                  },
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text('${l10n.morningTo} ${time(s.morningTo)}'),
                ),
              ],
            ),
          ),
        const PhotoFrameSettings(),
      ],
    );
  }
}

/// Picks several photos from the gallery (resized on the way in).
final kioskPhotosPickerProvider = Provider<Future<List<Uint8List>> Function()>(
  (ref) => () async {
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 85,
      limit: KioskSettings.maxFramePhotos,
    );
    return [for (final f in files) await f.readAsBytes()];
  },
);

/// The photo frame: on/off, photos (kept on this tablet), how often they
/// change.
class PhotoFrameSettings extends ConsumerStatefulWidget {
  const PhotoFrameSettings({super.key});

  @override
  ConsumerState<PhotoFrameSettings> createState() => _PhotoFrameSettingsState();
}

class _PhotoFrameSettingsState extends ConsumerState<PhotoFrameSettings> {
  bool _busy = false;

  Future<void> _add() async {
    final picked = await ref.read(kioskPhotosPickerProvider)();
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    final store = ref.read(kioskPhotoStoreProvider);
    final room =
        KioskSettings.maxFramePhotos -
        ref.read(kioskSettingsProvider).framePhotos.length;
    final paths = [
      for (final bytes in picked.take(room.clamp(0, picked.length)))
        await store.save(bytes),
    ];
    await ref
        .read(kioskSettingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            photoFrame: true,
            framePhotos: [...s.framePhotos, ...paths],
          ),
        );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _removeAll() async {
    final store = ref.read(kioskPhotoStoreProvider);
    final paths = ref.read(kioskSettingsProvider).framePhotos;
    await ref
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(photoFrame: false, framePhotos: const []));
    for (final p in paths) {
      await store.delete(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = ref.watch(kioskSettingsProvider);
    final controller = ref.read(kioskSettingsProvider.notifier);
    if (!ref.watch(kioskPhotoStoreProvider).supported) {
      return const SizedBox.shrink();
    }
    final count = s.framePhotos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('photoFrameSwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.photo_library_outlined),
          title: Text(l10n.photoFrame),
          subtitle: Text(
            count == 0 ? l10n.photoFrameHint : l10n.photoFrameCount(count),
          ),
          value: s.photoFrame && count > 0,
          onChanged: (v) => v && count == 0
              ? _add()
              : controller.update((k) => k.copyWith(photoFrame: v)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('photoFrameAdd'),
                onPressed: _busy || count >= KioskSettings.maxFramePhotos
                    ? null
                    : _add,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l10n.photoFrameAdd),
              ),
              if (count > 0) ...[
                TextButton(
                  key: const Key('photoFrameRemove'),
                  onPressed: _busy ? null : _removeAll,
                  child: Text(l10n.photoFrameRemove),
                ),
                DropdownButton<int>(
                  key: const Key('photoFrameSeconds'),
                  value: s.frameSeconds,
                  onChanged: (v) => v == null
                      ? null
                      : controller.update((k) => k.copyWith(frameSeconds: v)),
                  items: [
                    for (final sec in {10, 30, 60, 300, s.frameSeconds})
                      DropdownMenuItem(
                        value: sec,
                        child: Text(
                          sec < 60
                              ? l10n.photoFrameEverySeconds(sec)
                              : l10n.photoFrameEveryMinutes(sec ~/ 60),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Picks a list ([lists]) or a device for the always-on screen.
class _DevicePickerDialog extends ConsumerStatefulWidget {
  const _DevicePickerDialog({required this.lists});

  final bool lists;

  @override
  ConsumerState<_DevicePickerDialog> createState() =>
      _DevicePickerDialogState();
}

class _DevicePickerDialogState extends ConsumerState<_DevicePickerDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final list =
        devices.values
            .where(
              (d) =>
                  !d.isAuxiliary &&
                  d.kind != DeviceKind.unknown &&
                  widget.lists == (d.kind == DeviceKind.todoList) &&
                  d.name.toLowerCase().contains(_q.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return AlertDialog(
      title: Text(l10n.kioskPanelChooseDevice),
      content: SizedBox(
        width: 440,
        height: 460,
        child: Column(
          children: [
            TextField(
              key: const Key('kioskPanelSearch'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchHint,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final d in list)
                    ListTile(
                      key: ValueKey('kioskPick-${d.id}'),
                      leading: Icon(DevicePresentation.icon(d)),
                      title: Text(d.name),
                      onTap: () => Navigator.of(context).pop(d.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
