import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/kiosk/presentation/kiosk_motion.dart';

SmartHomeDevice _d(DeviceKind kind, DeviceState state) => SmartHomeDevice(
  id: 'x.y',
  sourceId: 'x.y',
  name: 'X',
  kind: kind,
  available: true,
  capabilities: const <Capability>{},
  state: state,
);

Widget _app(Widget child, {bool reduce = false}) => ProviderScope(
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Center(child: child),
    ),
  ),
);

double _angle(WidgetTester tester) {
  final t = find.descendant(
    of: find.byType(LiveDeviceIcon),
    matching: find.byType(Transform),
  );
  if (t.evaluate().isEmpty) return 0;
  return tester.widget<Transform>(t.first).transform.getRotation().entry(1, 0);
}

void main() {
  testWidgets('cards rise in one after another', (tester) async {
    await tester.pumpWidget(
      _app(const StaggeredEntrance(index: 2, child: Text('card'))),
    );
    Opacity op() => tester.widget<Opacity>(
      find.ancestor(of: find.text('card'), matching: find.byType(Opacity)),
    );
    expect(op().opacity, 0);
    await tester.pump(const Duration(milliseconds: 80)); // its delay
    await tester.pump(const Duration(milliseconds: 500));
    expect(op().opacity, 1);
  });

  testWidgets('a fan that is on turns; off it stands still', (tester) async {
    await tester.pumpWidget(
      _app(
        LiveDeviceIcon(
          device: _d(DeviceKind.fan, const DeviceState(raw: 'on', isOn: true)),
          color: Colors.black,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_angle(tester), isNot(0));
    await tester.pumpWidget(
      _app(
        LiveDeviceIcon(
          device: _d(
            DeviceKind.fan,
            const DeviceState(raw: 'off', isOn: false),
          ),
          color: Colors.black,
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('heating shows a flame; nothing moves with fewer animations', (
    tester,
  ) async {
    final heating = _d(
      DeviceKind.climate,
      const DeviceState(raw: 'heat', hvacAction: 'heating'),
    );
    await tester.pumpWidget(
      _app(LiveDeviceIcon(device: heating, color: Colors.black)),
    );
    expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    await tester.pumpWidget(
      _app(LiveDeviceIcon(device: heating, color: Colors.black), reduce: true),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('numbers count to their new value', (tester) async {
    String f(double v) => v.toStringAsFixed(1);
    await tester.pumpWidget(_app(CountUpText(value: 20, format: f)));
    expect(find.text('20.0'), findsOneWidget);
    await tester.pumpWidget(_app(CountUpText(value: 22, format: f)));
    await tester.pump(const Duration(milliseconds: 150));
    final mid = double.parse(tester.widget<Text>(find.byType(Text)).data!);
    expect(mid, inExclusiveRange(20, 22));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('22.0'), findsOneWidget);
  });
}
