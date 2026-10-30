import 'dart:math';

import '../../domain/smart_home_device.dart';

/// [c] as hue (degrees), saturation and value (0–1).
({double hue, double saturation, double value}) rgbToHsv(RgbColor c) {
  final r = c.red / 255, g = c.green / 255, b = c.blue / 255;
  final mx = max(r, max(g, b)), mn = min(r, min(g, b));
  final d = mx - mn;
  var h = 0.0;
  if (d > 0) {
    h = mx == r
        ? 60 * (((g - b) / d) % 6)
        : mx == g
        ? 60 * ((b - r) / d + 2)
        : 60 * ((r - g) / d + 4);
  }
  return (
    hue: h < 0 ? h + 360 : h,
    saturation: mx == 0 ? 0 : d / mx,
    value: mx,
  );
}

/// The colour of [hue] (degrees) and [saturation] (0–1) at full value, as
/// the screen shows a lamp's colour.
RgbColor hsvToRgb(double hue, double saturation) {
  final h = (hue % 360) / 60, c = saturation.clamp(0.0, 1.0);
  final x = c * (1 - (h % 2 - 1).abs());
  final (r, g, b) = switch (h.floor() % 6) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  final m = 1 - c;
  int v(double f) => ((f + m) * 255).round().clamp(0, 255);
  return RgbColor(v(r), v(g), v(b));
}
