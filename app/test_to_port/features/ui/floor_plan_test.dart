import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/floor_plan/floor_plan.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_photo.dart';
import 'package:open_smart_home_lite/features/kiosk/presentation/glass.dart';
import 'package:open_smart_home_lite/features/rooms/presentation/room_photo.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_camera_image.dart';

import '../../widgets/app_widget_test.dart'
    show pumpApp, settle, tapKey, unmount;

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
  test('positions are kept relative, round trip', () {
    const p = FloorPlan(
      photo: 'x',
      aspect: 2,
      pins: {'light.a': Offset(0.25, 0.75)},
    );
    final back = FloorPlan.fromJson(p.toJson());
    expect(back.pins, p.pins);
    expect(back.aspect, 2);
  });

  testWidgets('a plan, a light placed on it, a tap switches it', (
    tester,
  ) async {
    final store = _Store();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
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
    final server = container.read(mockHomeAssistantServerProvider);

    await tapKey(tester, 'openExtras');
    await settle(tester, 5);
    await tapKey(tester, 'extraFloorPlan');
    await settle(tester, 4);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('floorPlanPick')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester, 4);
    expect(container.read(floorPlanProvider).photo, isNotNull);

    await tapKey(tester, 'floorPlanEdit');
    await settle(tester, 2);
    await tapKey(tester, 'floorPlanAdd');
    await settle(tester, 4);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('floorAdd-light.living_room_main')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tapKey(tester, 'floorAdd-light.living_room_main');
    await settle(tester, 4);
    expect(
      container.read(floorPlanProvider).pins['light.living_room_main'],
      const Offset(0.5, 0.5),
    );
    // Drag it a little to the left.
    await tester.drag(
      find.byKey(const ValueKey('floorPin-light.living_room_main')),
      const Offset(-60, 0),
    );
    await settle(tester, 3);
    expect(
      container.read(floorPlanProvider).pins['light.living_room_main']!.dx,
      lessThan(0.5),
    );
    await tapKey(tester, 'floorPlanDone');
    await settle(tester, 2);

    await tester.tap(
      find.byKey(const ValueKey('floorPin-light.living_room_main')),
    );
    await settle(tester, 3);
    expect(server.stateForTest('light.living_room_main'), 'off');
    await unmount(tester);
  });
}
