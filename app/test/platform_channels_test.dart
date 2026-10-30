import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every channel the Dart side talks to must be registered on Android:
/// a missing one fails silently on the phone (a button that does nothing).
void main() {
  test('every platform channel used in lib/ is registered in Kotlin', () {
    final dart = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart')) f.readAsStringSync(),
    ].join('\n');
    final kotlin = [
      for (final f in Directory(
        'android/app/src/main/kotlin',
      ).listSync(recursive: true))
        if (f is File && f.path.endsWith('.kt')) f.readAsStringSync(),
    ].join('\n');
    final used = {
      for (final m in RegExp(
        r"""(?:Method|Event)Channel\(\s*'(org\.opensmarthome/[a-z_]+)'""",
      ).allMatches(dart))
        m.group(1)!,
    };
    expect(used, isNotEmpty);
    final missing = [
      for (final c in used)
        if (!kotlin.contains('"$c"')) c,
    ];
    expect(missing, isEmpty, reason: 'not registered on Android');
  });
}
