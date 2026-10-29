import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/theme/app_theme.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/devices/presentation/device_presentation.dart';

SmartHomeDevice _light({RgbColor? rgb, int? kelvin, bool on = true}) =>
    SmartHomeDevice(
      id: 'light.x',
      sourceId: 'light.x',
      name: 'X',
      kind: DeviceKind.rgbLight,
      available: true,
      capabilities: const <Capability>{},
      state: DeviceState(
        raw: on ? 'on' : 'off',
        isOn: on,
        rgb: rgb,
        colorTemperatureKelvin: kelvin,
      ),
    );

void main() {
  final tints = [
    for (var h = 0; h < 360; h += 15)
      HSLColor.fromAHSL(1, h.toDouble(), 1, 0.5).toColor(),
    for (final k in [1800, 2200, 2700, 3000, 4000])
      DevicePresentation.kelvinColor(k),
  ];

  for (final (name, accents) in [
    ('light', DeviceAccents.light),
    ('dark', DeviceAccents.dark),
  ]) {
    test('$name theme: every light colour stays readable', () {
      for (final t in tints) {
        final s = accents.tinted(t);
        final disc = Color.alphaBlend(accents.iconDisc, s.container);
        expect(
          DeviceAccents.contrastRatio(s.onContainer, s.container),
          greaterThanOrEqualTo(4.5),
          reason: 'text on $t',
        );
        expect(
          DeviceAccents.contrastRatio(s.icon, disc),
          greaterThanOrEqualTo(3),
          reason: 'icon on $t',
        );
      }
    });
  }

  test('a light that is on takes its colour; white and off keep amber', () {
    const a = DeviceAccents.light;
    final amber = a.of(DeviceAccent.light);
    final red = DevicePresentation.swatch(
      a,
      _light(rgb: const RgbColor(255, 0, 0)),
    );
    expect(HSLColor.fromColor(red.container).hue, closeTo(0, 1));
    final blue = DevicePresentation.swatch(
      a,
      _light(rgb: const RgbColor(0, 80, 255)),
    );
    expect(HSLColor.fromColor(blue.container).hue, inInclusiveRange(200, 240));
    // Pure white: nothing to tint with.
    expect(
      DevicePresentation.swatch(a, _light(rgb: const RgbColor(255, 255, 255))),
      same(amber),
    );
    // Warm white by temperature: an orange hue.
    final warm = DevicePresentation.swatch(a, _light(kelvin: 2200));
    expect(HSLColor.fromColor(warm.container).hue, inInclusiveRange(20, 45));
    expect(
      DevicePresentation.swatch(
        a,
        _light(rgb: const RgbColor(255, 0, 0), on: false),
      ),
      same(amber),
    );
  });
}
