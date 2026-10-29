import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/storage/app_preferences.dart';
import '../../kiosk/presentation/glass.dart' show kioskPhotoStoreProvider;
import 'room_card.dart' show roomIcon;
import 'room_look.dart';

/// A photo per room (room id → file on this device). Kept only here:
/// never sent to Home Assistant, not in the settings backup.
class RoomPhotosController extends Notifier<Map<String, String>> {
  static const _key = 'room.photos';

  @override
  Map<String, String> build() => {
    for (final e
        in (ref.watch(appPreferencesProvider).readJson(_key) ?? const {})
            .entries)
      if (e.value is String) e.key: e.value! as String,
  };

  Future<void> set(String roomId, Uint8List bytes) async {
    final store = ref.read(kioskPhotoStoreProvider);
    final path = await store.save(bytes);
    final old = state[roomId];
    state = {...state, roomId: path};
    await _save();
    if (old != null) await store.delete(old);
  }

  Future<void> remove(String roomId) async {
    final old = state[roomId];
    if (old == null) return;
    state = {...state}..remove(roomId);
    await _save();
    await ref.read(kioskPhotoStoreProvider).delete(old);
  }

  Future<void> _save() => ref
      .read(appPreferencesProvider)
      .writeJson(_key, state.isEmpty ? null : state);
}

final roomPhotosProvider =
    NotifierProvider<RoomPhotosController, Map<String, String>>(
      RoomPhotosController.new,
    );

/// One photo from the gallery, resized on the way in (tests replace it).
final roomPhotoPickerProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => () async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  },
);

/// The room's photo as a wide header, or nothing.
class RoomPhotoHeader extends ConsumerWidget {
  const RoomPhotoHeader({
    super.key,
    required this.roomId,
    this.height = 180,
    this.radius = 24,
  });

  final String roomId;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(roomPhotosProvider.select((m) => m[roomId]));
    final image = path == null
        ? null
        : ref.watch(kioskPhotoStoreProvider).image(path);
    if (image == null) return const SizedBox.shrink();
    return ClipRRect(
      key: ValueKey('roomPhoto-$roomId'),
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Image(
          // Decoded no larger than a tablet needs, not at camera size.
          image: ResizeImage.resizeIfNeeded(1600, null, image),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// App bar button: the room's look — photo, icon and colour.
class RoomPhotoButton extends ConsumerWidget {
  const RoomPhotoButton({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const Key('roomPhoto'),
    tooltip: context.l10n.roomLook,
    icon: const Icon(Icons.palette_outlined),
    onPressed: () => showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RoomLookSheet(roomId: roomId),
    ),
  );
}

class _RoomLookSheet extends ConsumerWidget {
  const _RoomLookSheet({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final photos = ref.watch(kioskPhotoStoreProvider).supported;
    final hasPhoto = ref.watch(
      roomPhotosProvider.select((m) => m[roomId] != null),
    );
    final look = ref.watch(roomLooksProvider.select((m) => m[roomId]));
    final looks = ref.read(roomLooksProvider.notifier);

    Future<void> choose() async {
      final bytes = await ref.read(roomPhotoPickerProvider)();
      if (bytes == null) return;
      await ref.read(roomPhotosProvider.notifier).set(roomId, bytes);
    }

    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.roomLook, style: theme.textTheme.titleLarge),
            if (photos) ...[
              title(l10n.roomPhoto),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('roomPhotoChange'),
                    onPressed: choose,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      hasPhoto ? l10n.roomPhotoChange : l10n.roomPhotoChoose,
                    ),
                  ),
                  if (hasPhoto)
                    OutlinedButton.icon(
                      key: const Key('roomPhotoRemove'),
                      onPressed: () =>
                          ref.read(roomPhotosProvider.notifier).remove(roomId),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.roomPhotoRemove),
                    ),
                ],
              ),
            ],
            title(l10n.roomIconTitle),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in roomIconChoices)
                  IconButton.filledTonal(
                    key: ValueKey('roomIcon-$name'),
                    isSelected: look?.icon == name,
                    style: IconButton.styleFrom(
                      backgroundColor: look?.icon == name
                          ? scheme.primaryContainer
                          : null,
                    ),
                    onPressed: () => looks.setIcon(roomId, name),
                    icon: Icon(roomIcon(name)),
                  ),
              ],
            ),
            title(l10n.roomColorTitle),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (i, c) in roomColorChoices.indexed)
                  InkResponse(
                    key: ValueKey('roomColor-$i'),
                    radius: 24,
                    onTap: () => looks.setColor(roomId, c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: look?.color == c
                              ? scheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (look != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('roomLookReset'),
                  onPressed: () async {
                    await looks.setIcon(roomId, null);
                    await looks.setColor(roomId, null);
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.roomLookReset),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.roomPhotoHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
