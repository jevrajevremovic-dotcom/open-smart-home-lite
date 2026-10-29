import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_sr.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/devices/presentation/device_presentation.dart';

SmartHomeDevice climate(String? mode) => SmartHomeDevice(
  id: 'climate.x',
  sourceId: 'climate.x',
  name: 'x',
  kind: DeviceKind.climate,
  protocol: DeviceProtocol.unknown,
  available: true,
  capabilities: const {},
  state: DeviceState(raw: mode ?? 'off', hvacMode: mode),
);

void main() {
  test('climate icon follows what the unit is doing', () {
    expect(
      DevicePresentation.icon(climate('heat')),
      Icons.local_fire_department_outlined,
    );
    expect(DevicePresentation.icon(climate('cool')), Icons.ac_unit);
    expect(DevicePresentation.icon(climate('auto')), Icons.thermostat_auto);
    expect(DevicePresentation.icon(climate(null)), Icons.ac_unit);
  });

  test('standard fan modes are translated, custom ones kept', () {
    final l10n = AppLocalizationsSrLatn();
    expect(DevicePresentation.fanModeLabel(l10n, 'low'), 'Slabo');
    expect(DevicePresentation.fanModeLabel(l10n, 'auto'), l10n.hvacAuto);
    expect(DevicePresentation.fanModeLabel(l10n, 'Turbo 3'), 'Turbo 3');
  });

  test('room name in front of a device name is dropped in its room', () {
    expect(
      DevicePresentation.shortName(
        'Dnevna soba – glavno svetlo',
        'Dnevna soba',
      ),
      'Glavno svetlo',
    );
    expect(DevicePresentation.shortName('Hodnik svetlo', 'Hodnik'), 'Svetlo');
    expect(DevicePresentation.shortName('Hodnik', 'Hodnik'), 'Hodnik');
    expect(
      DevicePresentation.shortName('Hodnikovo svetlo', 'Hodnik'),
      'Hodnikovo svetlo',
    );
    expect(DevicePresentation.shortName('Lampa', 'Hodnik'), 'Lampa');
    expect(DevicePresentation.shortName('Lampa', null), 'Lampa');
  });
}
