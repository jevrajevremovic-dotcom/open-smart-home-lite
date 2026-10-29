import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/widgets/skeleton.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 780),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('placeholders fit a phone and announce loading', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_app(const DashboardSkeleton(label: 'Loading')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_app(const ListSkeleton(label: 'Loading')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('no shimmer when the system asks for less motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const DashboardSkeleton(), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
