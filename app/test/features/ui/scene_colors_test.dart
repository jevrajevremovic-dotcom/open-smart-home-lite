import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/scenes/presentation/scene_colors.dart';

import '../../widgets/app_widget_test.dart' show goTo, pumpApp, settle, unmount;

void main() {
  test('a light\'s colour from any of the ways a scene stores it', () {
    expect(
      sceneLightColor({
        'rgb_color': [255, 0, 0],
      }),
      const Color(0xFFFF0000),
    );
    expect(
      sceneLightColor({
        'hs_color': [240, 100],
      }),
      const Color(0xFF0000FF),
    );
    expect(sceneLightColor({'color_temp_kelvin': 2700}), isA<Color>());
    expect(sceneLightColor({'state': 'on'}), const Color(0xFFFFD08A));
  });

  testWidgets('the movie night scene shows its purple light', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.scenes);
    await settle(tester, 6);
    final colors = await container.read(
      sceneColorsProvider('scene.movie_night').future,
    );
    // Only the lights the scene turns on.
    expect(colors, [const Color.fromARGB(255, 120, 60, 255)]);
    await settle(tester, 2);
    expect(
      find.byKey(const ValueKey('sceneSwatch-scene.movie_night-1')),
      findsWidgets,
    );
    await unmount(tester);
  });
}
