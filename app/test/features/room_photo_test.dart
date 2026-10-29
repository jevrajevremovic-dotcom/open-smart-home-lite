import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_photo.dart';
import 'package:open_smart_home_lite/features/kiosk/presentation/glass.dart';
import 'package:open_smart_home_lite/features/rooms/presentation/room_look.dart';
import 'package:open_smart_home_lite/features/rooms/presentation/room_photo.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_camera_image.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

class _Store implements KioskPhotoStore {
  final files = <String, Uint8List>{};
  var _n = 0;

  @override
  bool get supported => true;

  @override
  Future<String> save(Uint8List bytes) async {
    final path = 'p${_n++}';
    files[path] = bytes;
    return path;
  }

  @override
  Future<void> delete(String path) async => files.remove(path);

  @override
  ImageProvider? image(String path) =>
      files[path] == null ? null : MemoryImage(files[path]!);
}

void main() {
  testWidgets('room photo: chosen on the room, shown there and on the kiosk', (
    tester,
  ) async {
    final store = _Store();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1600, 1000),
      overrides: [
        kioskPhotoStoreProvider.overrideWithValue(store),
        roomPhotoPickerProvider.overrideWithValue(
          () async => mockCameraFrame(0, DateTime(2026)),
        ),
      ],
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.room('kitchen'));
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('roomPhoto-kitchen')), findsNothing);
    await tapKey(tester, 'roomPhoto');
    await settle(tester, 4);
    await tapKey(tester, 'roomPhotoChange');
    await settle(tester, 4);
    // Own icon and colour, in the same sheet.
    await tapKey(tester, 'roomIcon-mdi:shower');
    await tapKey(tester, 'roomColor-3');
    await settle(tester, 2);
    expect(container.read(roomLooksProvider)['kitchen']?.icon, 'mdi:shower');
    expect(
      container.read(roomLooksProvider)['kitchen']?.color,
      roomColorChoices[3],
    );
    Navigator.of(tester.element(find.byKey(const Key('roomPhotoChange'))))
        .pop();
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('roomPhoto-kitchen')), findsOneWidget);
    expect(container.read(roomPhotosProvider), {'kitchen': 'p0'});

    // The rooms list: the photo fills the kitchen's card.
    await goTo(tester, AppRoutes.rooms);
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('roomCardPhoto-kitchen')), findsOneWidget);

    // The kiosk shows it above the room.
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 6);
    await tester.tap(find.byKey(const ValueKey('kioskColumnsRoom-kitchen')));
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('roomPhoto-kitchen')), findsOneWidget);
    await container.read(kioskActiveProvider.notifier).tryExit('');
    await settle(tester, 2);

    // Remove: the file goes too.
    await goTo(tester, AppRoutes.room('kitchen'));
    await settle(tester, 4);
    await tapKey(tester, 'roomPhoto');
    await settle(tester, 2);
    await tapKey(tester, 'roomPhotoRemove');
    await settle(tester, 2);
    await tapKey(tester, 'roomLookReset');
    await settle(tester, 2);
    expect(container.read(roomLooksProvider), isEmpty);
    Navigator.of(tester.element(find.byKey(const Key('roomPhotoChange'))))
        .pop();
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('roomPhoto-kitchen')), findsNothing);
    expect(store.files, isEmpty);
    await unmount(tester);
  });
}
