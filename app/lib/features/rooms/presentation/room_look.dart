import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import 'room_card.dart';

/// A room's own icon and colour, chosen here instead of guessed from Home
/// Assistant's area icon and name. Kept on this device.
@immutable
class RoomLook {
  const RoomLook({this.icon, this.color});

  /// A Material Design Icons name, as Home Assistant areas use.
  final String? icon;
  final Color? color;

  Map<String, Object?> toJson() => {
    'icon': ?icon,
    if (color != null) 'color': color!.toARGB32(),
  };

  static RoomLook fromJson(Object? json) => json is Map
      ? RoomLook(
          icon: json['icon'] is String ? json['icon']! as String : null,
          color: json['color'] is int ? Color(json['color']! as int) : null,
        )
      : const RoomLook();
}

/// Icons offered for a room (one per kind [roomIcon] knows).
const roomIconChoices = [
  'mdi:sofa',
  'mdi:bed',
  'mdi:countertop',
  'mdi:shower',
  'mdi:desk',
  'mdi:baby-carriage',
  'mdi:door',
  'mdi:stairs',
  'mdi:washing-machine',
  'mdi:garage',
  'mdi:tree',
  'mdi:home',
];

/// Colours offered for a room.
const roomColorChoices = [
  Color(0xFFE0A030),
  Color(0xFFC9786A),
  Color(0xFFE07AA8),
  Color(0xFF9A6BD0),
  Color(0xFF6B6FD6),
  Color(0xFF3A8FD0),
  Color(0xFF4FB3BF),
  Color(0xFF3FA37A),
  Color(0xFF58A048),
  Color(0xFFB08A5A),
  Color(0xFF7A8794),
];

class RoomLooksController extends Notifier<Map<String, RoomLook>> {
  static const _key = 'room.looks';

  @override
  Map<String, RoomLook> build() => {
    for (final e
        in (ref.watch(appPreferencesProvider).readJson(_key) ?? const {})
            .entries)
      e.key: RoomLook.fromJson(e.value),
  };

  Future<void> setIcon(String roomId, String? icon) =>
      _set(roomId, RoomLook(icon: icon, color: state[roomId]?.color));

  Future<void> setColor(String roomId, Color? color) =>
      _set(roomId, RoomLook(icon: state[roomId]?.icon, color: color));

  Future<void> _set(String roomId, RoomLook look) async {
    final next = {...state, roomId: look};
    if (look.icon == null && look.color == null) next.remove(roomId);
    state = next;
    await ref
        .read(appPreferencesProvider)
        .writeJson(
          _key,
          next.isEmpty
              ? null
              : {for (final e in next.entries) e.key: e.value.toJson()},
        );
  }
}

final roomLooksProvider =
    NotifierProvider<RoomLooksController, Map<String, RoomLook>>(
      RoomLooksController.new,
    );

/// The room's icon and colour: chosen here, else from Home Assistant.
({IconData icon, Color color, String? iconName}) roomLookOf(
  WidgetRef ref,
  String? roomId,
  String? haIcon,
  String name,
) {
  final look = roomId == null
      ? null
      : ref.watch(roomLooksProvider.select((m) => m[roomId]));
  final iconName = look?.icon ?? haIcon;
  return (
    icon: roomIcon(iconName),
    color: look?.color ?? roomColor(iconName, name),
    iconName: iconName,
  );
}
