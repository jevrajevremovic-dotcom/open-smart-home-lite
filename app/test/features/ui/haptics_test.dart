import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/presentation/device_tile.dart';

import '../../widgets/app_widget_test.dart' show goTo, pumpApp, settle, unmount;

void main() {
  testWidgets('a command from the UI is felt (one light tap)', (tester) async {
    final vibrations = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          vibrations.add(call.arguments);
        }
        return null;
      },
    );
    await pumpApp(tester, size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.room('living'));
    await settle(tester, 4);
    vibrations.clear();
    await tester.tap(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Plafonjera'),
              matching: find.byType(DeviceTile),
            ),
            matching: find.byType(Switch),
          )
          .first,
    );
    await settle(tester, 3);
    expect(vibrations, ['HapticFeedbackType.lightImpact']);
    await unmount(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}
