// Collects the frame timings of integration_test/perf_test.dart.
//
//   flutter drive --profile -d <device> \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart
//
// WARNING: only on an emulator or a spare device. `flutter drive`
// uninstalls the app when it ends, which deletes its data (login,
// settings) on a real wall panel.
//
// Results land in build/perf/*.json.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final MapEntry(:key, :value) in data.entries) {
      await writeResponseData(
        value as Map<String, dynamic>,
        testOutputFilename: key,
        destinationDirectory: 'build/perf',
      );
    }
  },
);
