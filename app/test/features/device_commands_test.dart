import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/features/devices/application/device_command_service.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../helpers.dart';

final dimmable = testDevice(
  'desk',
  kind: DeviceKind.dimmableLight,
  capabilities: {Capability.power, Capability.brightness},
  state: const DeviceState(raw: 'on', isOn: true, brightnessPercent: 50),
);
final onOffLight = testDevice('hall', kind: DeviceKind.light);
final ac = testDevice(
  'ac',
  kind: DeviceKind.climate,
  capabilities: {Capability.power, Capability.targetTemperature},
);
final lock = testDevice(
  'door',
  kind: DeviceKind.lock,
  capabilities: {Capability.lock, Capability.unlock},
  state: const DeviceState(raw: 'locked', lockState: DoorLockState.locked),
);
final garage = testDevice(
  'garage',
  kind: DeviceKind.garageDoor,
  capabilities: {Capability.open, Capability.close},
);
SmartHomeDevice cover(String id, DeviceKind kind) => testDevice(
  id,
  kind: kind,
  capabilities: {Capability.open, Capability.close},
);

void main() {
  late TestAdapter adapter;
  late LocalBackend backend;
  late DeviceCommandService service;

  setUp(() {
    adapter = TestAdapter([dimmable, onOffLight, ac, lock, garage]);
    backend = LocalBackend([adapter])..start();
    service = DeviceCommandService(backend);
  });
  tearDown(() => backend.dispose());

  Future<void> expectKind(Future<void> f, FailureKind kind) => expectLater(
    f,
    throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', kind)),
  );

  test('sends supported commands to the device\'s adapter', () async {
    await service.execute(dimmable, const SetBrightness(30));
    expect(adapter.sent.single.$1, 'test:desk');
    expect(adapter.sent.single.$2, isA<SetBrightness>());
  });

  test('refuses unsupported capabilities without sending', () async {
    await expectKind(
      service.execute(onOffLight, const SetBrightness(30)),
      FailureKind.unsupportedFeature,
    );
    expect(adapter.sent, isEmpty);
  });

  test('refuses unavailable devices', () async {
    final gone = testDevice('gone', available: false);
    await expectKind(
      service.execute(gone, const TurnOn()),
      FailureKind.unavailableEntity,
    );
    expect(adapter.sent, isEmpty);
  });

  test('critical commands need confirmation', () async {
    await expectKind(
      service.execute(lock, const UnlockDevice()),
      FailureKind.confirmationRequired,
    );
    await expectKind(
      service.execute(garage, const OpenCover()),
      FailureKind.confirmationRequired,
    );
    await service.execute(lock, const LockDevice()); // locking is not critical
    await service.execute(lock, const UnlockDevice(), confirmed: true);
    expect(
      [for (final (_, c) in adapter.sent) c.runtimeType],
      [LockDevice, UnlockDevice],
    );
  });

  test('a device of no adapter is reported unavailable', () async {
    const stranger = SmartHomeDevice(
      id: 'shelly:1',
      sourceId: 'shelly:1',
      name: 'Shelly',
      kind: DeviceKind.switchDevice,
      available: true,
      capabilities: {Capability.power},
      state: DeviceState(raw: 'off'),
    );
    await expectKind(
      service.execute(stranger, const TurnOn()),
      FailureKind.unavailableEntity,
    );
  });

  test('all lights: available lights only', () async {
    final gone = testDevice('gone', kind: DeviceKind.light, available: false);
    await service.setLights([dimmable, onOffLight, gone, ac], on: false);
    expect(
      [for (final (id, _) in adapter.sent) id],
      ['test:desk', 'test:hall'],
    );
    expect(adapter.sent.every((s) => s.$2 is TurnOff), isTrue);
  });

  test('all blinds: garage doors are left out', () async {
    await service.setCovers([
      cover('blind', DeviceKind.blind),
      cover('curtain', DeviceKind.curtain),
      garage,
    ], open: true);
    expect(
      [for (final (id, _) in adapter.sent) id],
      ['test:blind', 'test:curtain'],
    );
    expect(adapter.sent.every((s) => s.$2 is OpenCover), isTrue);
  });

  test('one device failing does not stop the others', () async {
    final failing = TestAdapter(
      [dimmable, onOffLight],
      onCommand: (d, _) => d.id == 'test:desk'
          ? throw const AppFailure(FailureKind.network, debugMessage: 'x')
          : null,
    );
    final b = LocalBackend([failing])..start();
    addTearDown(b.dispose);
    await expectKind(
      DeviceCommandService(b).setLights([dimmable, onOffLight], on: true),
      FailureKind.network,
    );
    expect(failing.sent, hasLength(2));
  });
}
