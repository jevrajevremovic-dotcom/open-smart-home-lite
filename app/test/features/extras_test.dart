import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/appliance_done/appliance_done.dart';
import 'package:open_smart_home_lite/features/automations/domain/routines.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/extras/party.dart';
import 'package:open_smart_home_lite/features/extras/send_command.dart';
import 'package:open_smart_home_lite/features/extras/sunrise_wake.dart';
import 'package:open_smart_home_lite/features/extras/vacation.dart';
import 'package:open_smart_home_lite/features/heating_schedule/heating_schedule.dart';
import 'package:open_smart_home_lite/features/presence_sim/presence_simulation.dart';
import 'package:open_smart_home_lite/features/timers/device_timer.dart';

import '../helpers.dart';

/// Records what would be sent.
(SendCommand, List<(String, DeviceCommand)>) recorder() {
  final sent = <(String, DeviceCommand)>[];
  return ((id, c) async => sent.add((id, c)), sent);
}

SmartHomeDevice colorLight(String id, {bool on = false}) => testDevice(
  id,
  kind: DeviceKind.rgbLight,
  capabilities: {
    Capability.power,
    Capability.brightness,
    Capability.rgb,
    Capability.colorTemperature,
  },
  state: DeviceState(
    raw: on ? 'on' : 'off',
    isOn: on,
    brightnessPercent: on ? 40 : null,
    colorTemperatureKelvin: on ? 2700 : null,
  ),
);

SmartHomeDevice thermostat(double target) => testDevice(
  'heat',
  name: 'Grejanje',
  kind: DeviceKind.climate,
  capabilities: {Capability.targetTemperature},
  state: DeviceState(raw: 'heat', targetTemperature: target),
);

void main() {
  test('party: colours go round, then everything as it was', () async {
    final (send, sent) = recorder();
    final party = PartyRunner(send, [
      colorLight('a', on: true),
      colorLight('b'),
    ]);
    await party.start();
    expect(sent.where((s) => s.$2 is SetRgbColor), hasLength(2));
    sent.clear();
    await party.stop();
    expect(sent.map((s) => (s.$1, s.$2.runtimeType)), [
      ('test:a', SetBrightness),
      ('test:a', SetColorTemperature),
      ('test:b', TurnOff),
    ]);
    expect((sent[0].$2 as SetBrightness).percent, 40);
  });

  test('sunrise: from a dim glow to full light by the waking time', () {
    const wake = SunriseWake(
      lights: ['test:a'],
      wakeAt: ClockTime(7, 0),
      minutes: 20,
      days: {'thu'},
    );
    final thursday = DateTime(2026, 10, 29);
    expect(
      wake.progress(thursday.add(const Duration(hours: 6, minutes: 39))),
      isNull,
    );
    expect(
      wake.progress(thursday.add(const Duration(hours: 6, minutes: 40))),
      0,
    );
    expect(
      wake.progress(thursday.add(const Duration(hours: 6, minutes: 50))),
      0.5,
    );
    expect(wake.progress(thursday.add(const Duration(hours: 7))), 1);
    expect(
      wake.progress(DateTime(2026, 10, 30, 6, 50)),
      isNull,
      reason: 'not on Friday',
    );

    final (send, sent) = recorder();
    SunriseRunner(send).onMinute(
      thursday.add(const Duration(hours: 6, minutes: 50)),
      wake,
      () => {'test:a': colorLight('a')},
    );
    expect((sent[0].$2 as SetBrightness).percent, 51);
    expect((sent[1].$2 as SetColorTemperature).kelvin, 3100);

    // Waking at 00:10 starts the evening before.
    const early = SunriseWake(
      lights: ['test:a'],
      wakeAt: ClockTime(0, 10),
      minutes: 20,
      days: {'fri'},
    );
    expect(early.progress(DateTime(2026, 10, 29, 23, 55)), 0.25);
  });

  testWidgets('presence: a light changes each quarter hour in the evening; '
      'all off at the end', (tester) async {
    {
      final (send, sent) = recorder();
      final runner = PresenceRunner(send, random: Random(1));
      const sim = PresenceSimulation(
        enabled: true,
        lights: ['test:a', 'test:b'],
        fromSunset: false,
        start: ClockTime(18, 0),
        end: ClockTime(23, 0),
      );
      Map<String, SmartHomeDevice> devices() => {
        'test:a': colorLight('a'),
        'test:b': colorLight('b', on: true),
      };
      runner
        ..onMinute(DateTime(2026, 10, 29, 17, 45), sim, devices, null)
        ..onMinute(DateTime(2026, 10, 29, 19, 7), sim, devices, null);
      await tester.pump(const Duration(minutes: 11));
      expect(sent, isEmpty, reason: 'before the window; not a quarter');

      runner.onMinute(DateTime(2026, 10, 29, 19, 15), sim, devices, null);
      await tester.pump(const Duration(minutes: 11));
      expect(sent, hasLength(1));

      runner.onMinute(DateTime(2026, 10, 29, 23, 0), sim, devices, null);
      expect(sent.skip(1).map((s) => s.$2), everyElement(isA<TurnOff>()));
      expect(sent, hasLength(3));
      runner.dispose();
    }
  });

  test('heating schedule: kept as automations, read back the same', () {
    final schedule = HeatingSchedule.suggested('test:heat');
    final automations = schedule.toAutomations('Grejanje');
    expect(automations, hasLength(6));
    final first = automations.first;
    expect(first.triggers.single, isA<TimeTrigger>());
    expect((first.conditions.single as WeekdayCondition).weekdays, {
      1,
      2,
      3,
      4,
      5,
    });
    final back = HeatingSchedule.fromAutomations('test:heat', [
      ...automations,
      const LocalAutomation(id: 'other', name: 'x'),
    ])!;
    expect(back.workdays, schedule.workdays);
    expect(back.weekend, schedule.weekend);
    expect(HeatingSchedule.fromAutomations('test:other', automations), isNull);
  });

  test('appliance done: running for a while, then quiet: once', () {
    final done = <String>[];
    final watcher = ApplianceWatcher((a) => done.add(a.name));
    const machine = ApplianceDone(
      powerId: 'test:w',
      name: 'Veš mašina',
      thresholdWatts: 5,
      doneMinutes: 3,
    );
    SmartHomeDevice power(double w) => testDevice(
      'w',
      kind: DeviceKind.powerMeter,
      capabilities: {Capability.powerConsumption},
      state: DeviceState(raw: '$w', numericValue: w, unit: 'W'),
    );
    var t = DateTime(2026, 10, 29, 10);
    void at(int minutes, double watts) {
      t = DateTime(2026, 10, 29, 10).add(Duration(minutes: minutes));
      watcher.check(t, {'test:w': machine}, {'test:w': power(watts)});
    }

    at(0, 300);
    at(1, 2); // a blip: not running yet
    at(5, 2);
    expect(done, isEmpty);
    at(10, 300);
    at(13, 450); // running now
    at(40, 1); // quiet…
    at(42, 1);
    expect(done, isEmpty);
    at(43, 1); // …for 3 minutes
    expect(done, ['Veš mašina']);
    at(50, 1);
    expect(done, hasLength(1));
  });

  testWidgets('vacation: heating down and the simulation on; back as it was', (
    tester,
  ) async {
    final adapter = TestAdapter([thermostat(21.5)]);
    final container = ProviderContainer(
      overrides: await testOverrides(adapter: adapter),
    );
    addTearDown(container.dispose);
    await container
        .read(presenceSimProvider.notifier)
        .save(const PresenceSimulation(lights: ['test:a']));

    await tester.runAsync(
      () => container
          .read(vacationProvider.notifier)
          .start(temperature: 16, simulation: true),
    );
    expect((adapter.sent.single.$2 as SetTargetTemperature).temperature, 16);
    expect(container.read(presenceSimProvider).enabled, isTrue);
    expect(container.read(vacationProvider).active, isTrue);

    await tester.runAsync(
      () => container.read(vacationProvider.notifier).end(),
    );
    expect((adapter.sent.last.$2 as SetTargetTemperature).temperature, 21.5);
    expect(container.read(presenceSimProvider).enabled, isFalse);
    expect(container.read(vacationProvider).active, isFalse);
  });

  testWidgets('a device timer turns it off when its time comes', (
    tester,
  ) async {
    final adapter = TestAdapter([colorLight('a', on: true)]);
    final container = ProviderContainer(
      overrides: await testOverrides(adapter: adapter),
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container
          .read(deviceTimersProvider.notifier)
          .start(
            colorLight('a', on: true),
            after: const Duration(milliseconds: 50),
            turnOn: false,
          );
      expect(container.read(deviceTimersProvider), contains('test:a'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    expect(adapter.sent.single.$2, isA<TurnOff>());
    expect(container.read(deviceTimersProvider), isEmpty);
  });
}
