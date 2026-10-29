import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/automations/application/automation_engine.dart';
import 'package:open_smart_home_lite/features/automations/application/routines_controller.dart';
import 'package:open_smart_home_lite/features/automations/data/routine_adapter.dart';
import 'package:open_smart_home_lite/features/automations/domain/routines.dart';
import 'package:open_smart_home_lite/features/automations/domain/sun.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/weather/application/weather_providers.dart';

import '../helpers.dart';

SmartHomeDevice door({required bool open}) => testDevice(
  'door',
  name: 'Ulazna vrata',
  kind: DeviceKind.contactSensor,
  capabilities: const {},
  state: DeviceState(raw: open ? 'on' : 'off', isActive: open),
);

final light = testDevice(
  'hall',
  name: 'Hodnik',
  kind: DeviceKind.dimmableLight,
  capabilities: {Capability.power, Capability.brightness},
);

SmartHomeDevice temperature(double t) => testDevice(
  'temp',
  kind: DeviceKind.temperatureSensor,
  capabilities: const {},
  state: DeviceState(raw: '$t', numericValue: t, unit: '°C'),
);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('everything survives JSON', () {
    final a = LocalAutomation(
      id: 'a1',
      name: 'Noćno svetlo',
      enabled: false,
      triggers: const [
        TimeTrigger(ClockTime(7, 30)),
        SunTrigger(sunset: true, offsetMinutes: -15),
        DeviceTrigger('test:door', DeviceStateTarget.open),
        ValueTrigger('test:temp', above: false, threshold: 18.5),
      ],
      conditions: const [
        WeekdayCondition({1, 2, 3, 4, 5}),
        TimeWindowCondition(after: ClockTime(22, 0), before: ClockTime(6, 0)),
        StateCondition('test:hall', DeviceStateTarget.off),
        DarkCondition(dark: true),
      ],
      actions: const [
        DeviceAction('test:hall', SetBrightness(30)),
        DeviceAction('test:strip', SetRgbColor(RgbColor(1, 2, 3))),
        DeviceAction('routine:scene_x', Activate()),
      ],
      lastTriggered: DateTime.utc(2026, 10, 29, 20),
    );
    final back = LocalAutomation.fromJson(a.toJson())!;
    expect(back.toJson(), a.toJson());
    expect(back.enabled, isFalse);
    expect(
      LocalAutomation.fromJson({
        'id': 'b',
        'name': 'B',
        'triggers': [
          {'type': 'nonsense'},
          {'type': 'time', 'at': '25:00'},
        ],
      })!.triggers,
      isEmpty,
      reason: 'broken parts are skipped',
    );
  });

  test('sunrise and sunset in Belgrade on the longest day', () {
    final sun = sunTimes(DateTime(2026, 6, 21), 44.82, 20.46)!;
    final rise = sun.sunrise.toUtc(), set = sun.sunset.toUtc();
    // 04:51 and 20:29 local (UTC+2), within a few minutes.
    expect(
      rise.difference(DateTime.utc(2026, 6, 21, 2, 51)).inMinutes.abs(),
      lessThanOrEqualTo(4),
    );
    expect(
      set.difference(DateTime.utc(2026, 6, 21, 18, 29)).inMinutes.abs(),
      lessThanOrEqualTo(4),
    );
    expect(
      sunTimes(DateTime(2026, 6, 21), 78.2, 15.6),
      isNull,
      reason: 'polar day',
    );
  });

  test('a time window over midnight', () {
    const w = TimeWindowCondition(
      after: ClockTime(22, 0),
      before: ClockTime(6, 0),
    );
    expect(w.includes(const ClockTime(23, 30)), isTrue);
    expect(w.includes(const ClockTime(5, 59)), isTrue);
    expect(w.includes(const ClockTime(12, 0)), isFalse);
  });

  group('engine', () {
    late ProviderContainer container;
    late TestAdapter adapter;
    late AutomationEngine engine;
    var now = DateTime(2026, 10, 29, 21, 15); // a Thursday evening

    Future<void> start(
      List<LocalAutomation> automations, {
      List<LocalScene> scenes = const [],
    }) async {
      adapter = TestAdapter([door(open: false), light, temperature(21)]);
      container = ProviderContainer(
        overrides: await testOverrides(adapter: adapter),
      );
      final controller = container.read(routinesProvider.notifier);
      for (final s in scenes) {
        await controller.saveScene(s);
      }
      for (final a in automations) {
        await controller.saveAutomation(a);
      }
      final backend = container.read(homeBackendProvider)!;
      engine = AutomationEngine(
        backend: backend,
        routines: () => container.read(routinesProvider),
        controller: controller,
        location: () => null,
        clock: () => now,
      )..start();
      container.read(routineAdapterProvider).runner = engine;
    }

    tearDown(() {
      engine.dispose();
      container.dispose();
    });

    test('a door opens in the dark: the hall light comes on', () async {
      await start([
        const LocalAutomation(
          id: 'a',
          name: 'Vrata',
          triggers: [DeviceTrigger('test:door', DeviceStateTarget.open)],
          conditions: [DarkCondition(dark: true)],
          actions: [DeviceAction('test:hall', SetBrightness(40))],
        ),
      ]);
      adapter.update(door(open: true));
      await settle();
      expect(adapter.sent.single.$1, 'test:hall');
      expect((adapter.sent.single.$2 as SetBrightness).percent, 40);
      final a = container.read(routinesProvider).automations.single;
      expect(a.lastTriggered, now);

      // Open again without closing: no new change, nothing more.
      adapter.update(door(open: true));
      await settle();
      expect(adapter.sent, hasLength(1));

      // By day, the condition says no.
      now = DateTime(2026, 10, 29, 12);
      adapter
        ..update(door(open: false))
        ..update(door(open: true));
      await settle();
      expect(adapter.sent, hasLength(1));
      now = DateTime(2026, 10, 29, 21, 15);
    });

    test('at a time, on the chosen days only, once a minute', () async {
      await start([
        const LocalAutomation(
          id: 't',
          name: 'Jutro',
          triggers: [TimeTrigger(ClockTime(7, 0))],
          conditions: [
            WeekdayCondition({1, 2, 3, 4, 5}),
          ],
          actions: [DeviceAction('test:hall', TurnOn())],
        ),
      ]);
      now = DateTime(2026, 10, 29, 7); // Thursday
      engine
        ..tick()
        ..tick();
      await settle();
      expect(adapter.sent, hasLength(1));
      now = DateTime(2026, 10, 31, 7); // Saturday
      engine.tick();
      await settle();
      expect(adapter.sent, hasLength(1));
      now = DateTime(2026, 10, 29, 21, 15);
    });

    test('a reading falls below a limit', () async {
      await start([
        const LocalAutomation(
          id: 'v',
          name: 'Hladno',
          triggers: [ValueTrigger('test:temp', above: false, threshold: 19)],
          actions: [DeviceAction('test:hall', TurnOn())],
        ),
      ]);
      adapter.update(temperature(19.5));
      await settle();
      expect(adapter.sent, isEmpty);
      adapter.update(temperature(18.9));
      await settle();
      expect(adapter.sent, hasLength(1));
    });

    test('a disabled automation does nothing; "run now" runs it', () async {
      await start([
        const LocalAutomation(
          id: 'off',
          name: 'Isključena',
          enabled: false,
          triggers: [DeviceTrigger('test:door', DeviceStateTarget.open)],
          actions: [DeviceAction('test:hall', TurnOn())],
        ),
      ]);
      adapter.update(door(open: true));
      await settle();
      expect(adapter.sent, isEmpty);

      final device = container
          .read(homeSnapshotProvider)
          .devices[RoutineAdapter.automationDevice('off')]!;
      expect((device.kind, device.state.isOn), (DeviceKind.automation, false));
      await container.read(homeBackendProvider)!.send(device, const Activate());
      expect(adapter.sent, hasLength(1));
      await container.read(homeBackendProvider)!.send(device, const TurnOn());
      expect(
        container.read(routinesProvider).automations.single.enabled,
        isTrue,
      );
    });

    test('a scene is a device; running it sets the devices', () async {
      await start(
        const [],
        scenes: [
          LocalScene(
            id: 's',
            name: 'Veče',
            actions: actionsForState(
              testDevice(
                'hall',
                kind: DeviceKind.dimmableLight,
                capabilities: {Capability.power, Capability.brightness},
                state: const DeviceState(
                  raw: 'on',
                  isOn: true,
                  brightnessPercent: 25,
                ),
              ),
            ),
          ),
        ],
      );
      final scene = container
          .read(homeSnapshotProvider)
          .devices[RoutineAdapter.sceneDevice('s')]!;
      expect((scene.name, scene.kind), ('Veče', DeviceKind.scene));
      await container.read(homeBackendProvider)!.send(scene, const Activate());
      expect((adapter.sent.single.$2 as SetBrightness).percent, 25);
    });

    test('sun triggers need the home location', () async {
      await start([
        const LocalAutomation(
          id: 'sun',
          name: 'Zalazak',
          triggers: [SunTrigger(sunset: true)],
          actions: [DeviceAction('test:hall', TurnOn())],
        ),
      ]);
      final sunset = sunTimes(DateTime(2026, 10, 29), 44.82, 20.46)!.sunset;
      now = DateTime(
        sunset.year,
        sunset.month,
        sunset.day,
        sunset.hour,
        sunset.minute,
      );
      engine.tick();
      await settle();
      expect(adapter.sent, isEmpty, reason: 'no location: no sun');

      engine.dispose();
      engine = AutomationEngine(
        backend: container.read(homeBackendProvider)!,
        routines: () => container.read(routinesProvider),
        controller: container.read(routinesProvider.notifier),
        location: () => (latitude: 44.82, longitude: 20.46),
        clock: () => now,
      )..start();
      engine.tick();
      await settle();
      expect(adapter.sent, hasLength(1));
      now = DateTime(2026, 10, 29, 21, 15);
      expect(container.read(homeLocationWeatherEnabledProvider), isNull);
    });
  });
}
