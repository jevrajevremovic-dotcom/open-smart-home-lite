import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/dashboard/presentation/weather_sky.dart';
import 'package:open_smart_home_lite/features/weather/domain/weather.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart' show pumpApp, settle, unmount;

void main() {
  test('sky: warm in sun, grey-blue in rain, deep blue at night', () {
    expect(
      skyColor(WeatherCondition.clearDay, night: false),
      const Color(0xFFFFB74D),
    );
    expect(
      skyColor(WeatherCondition.rain, night: false),
      const Color(0xFF5B8DB8),
    );
    expect(
      skyColor(WeatherCondition.clearDay, night: true),
      const Color(0xFF2B3A67),
    );
    expect(skyColor(null, night: false).a, 0);
  });

  testWidgets('on now: lights and devices that are on; long press offs', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);
    final server = HomeFixture.running;
    expect(find.byKey(const Key('onNowStrip')), findsOneWidget);
    expect(find.byKey(const Key('onNowLights')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onNow-fx:switch.tv_outlet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('weatherSky')), findsOneWidget);

    final tv = find.byKey(const ValueKey('onNow-fx:switch.tv_outlet'));
    await tester.ensureVisible(tv);
    await settle(tester, 1);
    await tester.longPress(tv);
    await settle(tester, 4);
    expect(server.stateOf('fx:switch.tv_outlet'), 'off');
    expect(
      find.byKey(const ValueKey('onNow-fx:switch.tv_outlet')),
      findsNothing,
    );

    await tester.ensureVisible(find.byKey(const Key('onNowLights')));
    await settle(tester, 1);
    await tester.longPress(find.byKey(const Key('onNowLights')));
    await settle(tester, 6);
    expect(server.stateOf('fx:light.living_room_main'), 'off');
    expect(find.byKey(const Key('onNowLights')), findsNothing);
    await unmount(tester);
  });
}
