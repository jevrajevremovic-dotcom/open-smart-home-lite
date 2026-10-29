import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/clap/clap_detector.dart';

/// 20 ms frames: [ms] of background noise.
List<double> quiet(int ms, [double level = 0.02]) =>
    List.filled(ms ~/ 20, level);

/// A clap: one or two loud frames, then a fast decay.
List<double> clap([double peak = 0.7]) => [peak, peak * 0.5, 0.05, 0.03];

int detections(ClapDetector d, List<double> frames) =>
    frames.where(d.add).length;

void main() {
  test('two claps half a second apart are a double clap', () {
    final d = ClapDetector();
    expect(
      detections(d, [
        ...quiet(1000),
        ...clap(),
        ...quiet(400),
        ...clap(),
        ...quiet(1000),
      ]),
      1,
    );
  });

  test('a single clap, three claps or claps too far apart do nothing', () {
    expect(
      detections(ClapDetector(), [...quiet(1000), ...clap(), ...quiet(2000)]),
      0,
    );
    expect(
      detections(ClapDetector(), [
        ...quiet(1000),
        ...clap(),
        ...quiet(300),
        ...clap(),
        ...quiet(300),
        ...clap(),
        ...quiet(1500),
      ]),
      0,
      reason: 'three claps',
    );
    expect(
      detections(ClapDetector(), [
        ...quiet(1000),
        ...clap(),
        ...quiet(1200),
        ...clap(),
        ...quiet(1500),
      ]),
      0,
      reason: 'too far apart',
    );
  });

  test('long loud sounds (speech, music) are not claps', () {
    final loud = [for (var i = 0; i < 40; i++) i.isEven ? 0.6 : 0.45];
    expect(
      detections(ClapDetector(), [
        ...quiet(1000),
        ...loud,
        ...quiet(300),
        ...loud,
        ...quiet(1500),
      ]),
      0,
    );
  });

  test('in a loud room a clap must stand out from the background', () {
    // Music around 0.2: a 0.5 peak is only 2.5x louder.
    expect(
      detections(ClapDetector(), [
        ...quiet(2000, 0.2),
        ...clap(0.5),
        ...quiet(400, 0.2),
        ...clap(0.5),
        ...quiet(1000, 0.2),
      ]),
      0,
    );
  });

  test('sensitivity decides how loud a clap must be', () {
    List<double> soft() => [
      ...quiet(1000),
      ...clap(0.2),
      ...quiet(400),
      ...clap(0.2),
      ...quiet(1000),
    ];
    expect(
      detections(ClapDetector(sensitivity: ClapSensitivity.low), soft()),
      0,
    );
    expect(
      detections(ClapDetector(sensitivity: ClapSensitivity.high), soft()),
      1,
    );
  });

  test('after a double clap there is a short pause before the next one', () {
    final d = ClapDetector();
    final pair = [...clap(), ...quiet(400), ...clap()];
    expect(
      detections(d, [
        ...quiet(1000),
        ...pair,
        ...quiet(600),
        ...pair,
        ...quiet(1000),
      ]),
      1,
      reason: 'second pair falls in the refractory time',
    );
    expect(detections(d, [...quiet(2000), ...pair, ...quiet(1000)]), 1);
  });
}
