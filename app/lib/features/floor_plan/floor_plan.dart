import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/storage/app_preferences.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/smart_home_device.dart';
import '../devices/presentation/device_actions.dart';
import '../devices/presentation/device_presentation.dart';
import '../devices/presentation/device_sheet.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../kiosk/presentation/glass.dart' show kioskPhotoStoreProvider;
import '../kiosk/presentation/pin_dialog.dart';
import '../rooms/presentation/room_photo.dart' show roomPhotoPickerProvider;

/// A drawing or photo of the home's plan with devices placed on it.
@immutable
class FloorPlan {
  const FloorPlan({this.photo, this.aspect = 1.5, this.pins = const {}});

  factory FloorPlan.fromJson(Map<String, Object?>? json) => FloorPlan(
    photo: json?['photo'] as String?,
    aspect: (json?['aspect'] as num?)?.toDouble() ?? 1.5,
    pins: {
      if (json?['pins'] case final Map<Object?, Object?> m)
        for (final e in m.entries)
          if (e.value case [final num x, final num y])
            '${e.key}': Offset(x.toDouble(), y.toDouble()),
    },
  );

  /// Where the photo store keeps the image (on this device).
  final String? photo;

  /// Width / height of the image.
  final double aspect;

  /// Device id → position, 0…1 of the image's width and height.
  final Map<String, Offset> pins;

  Map<String, Object?> toJson() => {
    'photo': photo,
    'aspect': aspect,
    'pins': {
      for (final e in pins.entries) e.key: [e.value.dx, e.value.dy],
    },
  };
}

class FloorPlanController extends Notifier<FloorPlan> {
  static const _key = 'floorPlan';

  @override
  FloorPlan build() =>
      FloorPlan.fromJson(ref.watch(appPreferencesProvider).readJson(_key));

  Future<void> _save(FloorPlan p) async {
    state = p;
    await ref.read(appPreferencesProvider).writeJson(_key, p.toJson());
  }

  /// A new picture (its proportions are read from it); pins stay.
  Future<void> setPhoto(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final aspect = frame.image.width / frame.image.height;
    frame.image.dispose();
    final store = ref.read(kioskPhotoStoreProvider);
    final path = await store.save(bytes);
    final old = state.photo;
    await _save(FloorPlan(photo: path, aspect: aspect, pins: state.pins));
    if (old != null) await store.delete(old);
  }

  Future<void> place(String deviceId, Offset at) => _save(
    FloorPlan(
      photo: state.photo,
      aspect: state.aspect,
      pins: {
        ...state.pins,
        deviceId: Offset(at.dx.clamp(0, 1), at.dy.clamp(0, 1)),
      },
    ),
  );

  Future<void> remove(String deviceId) => _save(
    FloorPlan(
      photo: state.photo,
      aspect: state.aspect,
      pins: {...state.pins}..remove(deviceId),
    ),
  );
}

final floorPlanProvider = NotifierProvider<FloorPlanController, FloorPlan>(
  FloorPlanController.new,
);

/// The plan with its devices; in [editing] the pins move by dragging and
/// show a remove button.
class FloorPlanView extends ConsumerWidget {
  const FloorPlanView({super.key, this.editing = false});

  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(floorPlanProvider);
    final image = plan.photo == null
        ? null
        : ref.watch(kioskPhotoStoreProvider).image(plan.photo!);
    if (image == null) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: plan.aspect,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(image: image, fit: BoxFit.fill),
              ),
            ),
            for (final e in plan.pins.entries)
              _Pin(
                key: ValueKey('floorPin-${e.key}'),
                deviceId: e.key,
                at: e.value,
                size: c.biggest,
                editing: editing,
              ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends ConsumerStatefulWidget {
  const _Pin({
    super.key,
    required this.deviceId,
    required this.at,
    required this.size,
    required this.editing,
  });

  final String deviceId;
  final Offset at;
  final Size size;
  final bool editing;

  @override
  ConsumerState<_Pin> createState() => _PinState();
}

class _PinState extends ConsumerState<_Pin> {
  static const _diameter = 40.0;

  /// While dragging (relative), else where it is saved.
  Offset? _moving;

  void _tap(SmartHomeDevice d) {
    final kiosk = ref.read(kioskActiveProvider);
    // A light or socket switches right here; anything else opens.
    if (DevicePresentation.hasQuickToggle(d) && d.available) {
      unawaited(runDeviceCommand(context, ref, d, const Toggle()));
    } else if (kiosk) {
      unawaited(context.push(AppRoutes.device(d.id, kiosk: true)));
    } else {
      unawaited(showDeviceSheet(context, d.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(deviceProvider(widget.deviceId));
    if (d == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final tone = DevicePresentation.tone(d);
    final accent = context.deviceAccents.of(DevicePresentation.accent(d));
    final on = d.state.isOn == true || tone == DeviceTone.active;
    final ring = switch (tone) {
      DeviceTone.critical || DeviceTone.warning => scheme.error,
      _ => Colors.white,
    };
    final at = _moving ?? widget.at;
    final pin = Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? accent.container : scheme.surfaceContainerHigh,
        border: Border.all(color: ring, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
      ),
      child: Icon(
        DevicePresentation.icon(d),
        size: 20,
        color: on ? accent.onContainer : scheme.onSurface,
      ),
    );
    return Positioned(
      left: at.dx * widget.size.width - _diameter / 2,
      top: at.dy * widget.size.height - _diameter / 2,
      child: Tooltip(
        message: '${d.name}: ${DevicePresentation.status(context.l10n, d)}',
        child: widget.editing
            ? GestureDetector(
                onPanUpdate: (u) => setState(() {
                  final p =
                      (_moving ?? widget.at) +
                      Offset(
                        u.delta.dx / widget.size.width,
                        u.delta.dy / widget.size.height,
                      );
                  _moving = Offset(p.dx.clamp(0, 1), p.dy.clamp(0, 1));
                }),
                onPanEnd: (_) async {
                  final to = _moving;
                  if (to != null) {
                    await ref
                        .read(floorPlanProvider.notifier)
                        .place(widget.deviceId, to);
                  }
                  if (mounted) setState(() => _moving = null);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    pin,
                    Positioned(
                      right: -10,
                      top: -10,
                      child: GestureDetector(
                        key: ValueKey('floorPinRemove-${widget.deviceId}'),
                        onTap: () => ref
                            .read(floorPlanProvider.notifier)
                            .remove(widget.deviceId),
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: scheme.error,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: scheme.onError,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : InkResponse(
                onTap: () => _tap(d),
                onLongPress: () => context.push(
                  AppRoutes.device(d.id, kiosk: ref.read(kioskActiveProvider)),
                ),
                child: pin,
              ),
      ),
    );
  }
}

/// The plan on its own screen (a page, so a device opened from it comes
/// on top): zoom with two fingers, tap to switch, "Edit" to place devices
/// (on the wall panel only with the PIN).
Future<void> showFloorPlan(BuildContext context) => context.push(
  AppRoutes.floorPlanFor(
    kiosk: ProviderScope.containerOf(context).read(kioskActiveProvider),
  ),
);

class FloorPlanScreen extends ConsumerStatefulWidget {
  const FloorPlanScreen({super.key});

  @override
  ConsumerState<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends ConsumerState<FloorPlanScreen> {
  bool _editing = false;

  Future<void> _pickPhoto() async {
    final bytes = await ref.read(roomPhotoPickerProvider)();
    if (bytes != null) {
      await ref.read(floorPlanProvider.notifier).setPhoto(bytes);
    }
  }

  Future<void> _startEditing() async {
    if (ref.read(kioskActiveProvider) && !await confirmKioskPin(context, ref)) {
      return;
    }
    if (mounted) setState(() => _editing = true);
  }

  Future<void> _addDevice() async {
    final plan = ref.read(floorPlanProvider);
    final devices = ref.read(homeSnapshotProvider).devices.values;
    final candidates = [
      for (final d in devices)
        if (!d.isAuxiliary && !d.kind.isRoutine && !plan.pins.containsKey(d.id))
          d,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            for (final d in candidates)
              ListTile(
                key: ValueKey('floorAdd-${d.id}'),
                leading: Icon(DevicePresentation.icon(d)),
                title: Text(d.name),
                onTap: () => Navigator.of(sheet).pop(d.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) {
      // In the middle; drag it to its place.
      await ref
          .read(floorPlanProvider.notifier)
          .place(id, const Offset(0.5, 0.5));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = ref.watch(floorPlanProvider);
    final store = ref.watch(kioskPhotoStoreProvider);
    final hasPlan = plan.photo != null && store.image(plan.photo!) != null;
    return Scaffold(
      key: const Key('floorPlanScreen'),
      appBar: AppBar(
        title: Text(l10n.floorPlanTitle),
        actions: [
          if (hasPlan && !_editing)
            TextButton.icon(
              key: const Key('floorPlanEdit'),
              onPressed: _startEditing,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(l10n.floorPlanEdit),
            ),
          if (_editing)
            FilledButton(
              key: const Key('floorPlanDone'),
              onPressed: () => setState(() => _editing = false),
              child: Text(l10n.done),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: !store.supported
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.floorPlanUnsupported),
              ),
            )
          : !hasPlan
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(l10n.floorPlanEmpty, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('floorPlanPick'),
                      onPressed: () async {
                        if (ref.read(kioskActiveProvider) &&
                            !await confirmKioskPin(context, ref)) {
                          return;
                        }
                        await _pickPhoto();
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: Text(l10n.floorPlanPick),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('floorPlanAdd'),
                          onPressed: _addDevice,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(l10n.floorPlanAdd),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(l10n.floorPlanChangePhoto),
                        ),
                        Text(l10n.floorPlanEditHint),
                      ],
                    ),
                  ),
                Expanded(
                  child: _editing
                      // No zoom while editing: it would take the drags.
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: FloorPlanView(editing: true),
                          ),
                        )
                      : InteractiveViewer(
                          maxScale: 4,
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: FloorPlanView(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// On the wall panel's home: the plan, small; a tap on the title opens it.
class FloorPlanCard extends ConsumerWidget {
  const FloorPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      key: const Key('floorPlanCard'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.floorPlanTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('floorPlanOpen'),
                  tooltip: l10n.floorPlanTitle,
                  onPressed: () => showFloorPlan(context),
                  icon: const Icon(Icons.open_in_full),
                ),
              ],
            ),
            const FloorPlanView(),
          ],
        ),
      ),
    );
  }
}

/// Whether there is a plan to show on this device.
final hasFloorPlanProvider = Provider<bool>((ref) {
  final photo = ref.watch(floorPlanProvider.select((p) => p.photo));
  return photo != null &&
      ref.watch(kioskPhotoStoreProvider).image(photo) != null;
});
