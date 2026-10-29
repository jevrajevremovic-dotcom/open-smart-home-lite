import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/devices/data/local/demo_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/home_snapshot.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../helpers.dart';

void main() {
  test('merges the adapters\' devices and is live at once', () async {
    final a = TestAdapter([testDevice('a')]);
    final demo = DemoAdapter(latency: Duration.zero);
    final backend = LocalBackend([a, demo], rooms: demoRooms)..start();
    addTearDown(backend.dispose);

    final snapshot = backend.current;
    expect(snapshot.status, SyncStatus.live);
    expect(snapshot.devices, contains('test:a'));
    expect(snapshot.devices, contains('demo:living_ceiling'));
    expect(snapshot.rooms.keys, containsAll(demoRooms.keys));
  });

  test('a device that changes by itself reaches the snapshot', () async {
    final a = TestAdapter([testDevice('a')]);
    final backend = LocalBackend([a])..start();
    addTearDown(backend.dispose);

    final next = backend.snapshots.first;
    a.update(testDevice('a', state: const DeviceState(raw: 'on', isOn: true)));
    expect((await next).devices['test:a']!.state.isOn, isTrue);
  });

  test('the demo home obeys its commands', () async {
    final backend = LocalBackend([DemoAdapter(latency: Duration.zero)])
      ..start();
    addTearDown(backend.dispose);
    final strip = backend.current.devices['demo:living_strip']!;
    expect(strip.state.isOn, isFalse);

    var next = backend.snapshots.first;
    await backend.send(strip, const SetRgbColor(RgbColor(0, 0, 255)));
    final after = (await next).devices['demo:living_strip']!;
    expect(after.state.isOn, isTrue);
    expect(after.state.rgb, const RgbColor(0, 0, 255));

    final blind = backend.current.devices['demo:living_blind']!;
    next = backend.snapshots.first;
    await backend.send(blind, const SetCoverPosition(30));
    expect((await next).devices['demo:living_blind']!.state.position, 30);
  });
}
