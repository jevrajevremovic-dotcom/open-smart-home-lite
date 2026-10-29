import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/weather/domain/weather.dart';
import 'package:open_smart_home_lite/features/weather/presentation/animated_weather_icon.dart';

Widget _icon(WeatherCondition c, {bool reduce = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Center(child: AnimatedWeatherIcon(condition: c, size: 48)),
  ),
);

void main() {
  testWidgets('the sun turns slowly', (tester) async {
    await tester.pumpWidget(_icon(WeatherCondition.clearDay));
    Matrix4 turn() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(AnimatedWeatherIcon),
            matching: find.byType(Transform),
          ),
        )
        .transform;
    final before = turn().clone();
    await tester.pump(const Duration(seconds: 3));
    expect(turn(), isNot(equals(before)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rain falls under a cloud', (tester) async {
    await tester.pumpWidget(_icon(WeatherCondition.rain));
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AnimatedWeatherIcon),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('still when the system asks for fewer animations', (
    tester,
  ) async {
    await tester.pumpWidget(_icon(WeatherCondition.clearDay, reduce: true));
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(
        of: find.byType(AnimatedWeatherIcon),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
}
