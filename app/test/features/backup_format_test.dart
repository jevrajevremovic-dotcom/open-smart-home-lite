import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/automations/application/routines_controller.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/favorites/application/favorites_controller.dart';
import 'package:open_smart_home_lite/features/settings/application/appearance_controllers.dart';
import 'package:open_smart_home_lite/features/settings/data/settings_backup.dart';
import 'package:open_smart_home_lite/features/weather/application/weather_providers.dart';

import '../widgets/app_widget_test.dart' show pumpApp, settle, unmount;

/// A backup as version 0.3 wrote it (docs/BACKUP_FORMAT.md). Every later
/// version must still read it: change this file only by adding to it.
final golden = File('test/fixtures/backup_v2.json').readAsStringSync();

void main() {
  testWidgets('the 0.3 backup (format 2) still reads, secrets and all', (
    tester,
  ) async {
    final credentials = await pumpApp(tester, size: const Size(800, 1400));
    final c = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final ref = _Ref(tester);
    expect(SettingsBackup.hasSecrets(golden), isTrue);
    expect(
      await tester.runAsync(
        () => SettingsBackup.import(ref.ref, golden, password: 'pogresna'),
      ),
      BackupImport.wrongPassword,
    );
    expect(c.read(localHomeProvider).devices, isEmpty);

    expect(
      await tester.runAsync(
        () => SettingsBackup.import(ref.ref, golden, password: 'kucna lozinka'),
      ),
      BackupImport.done,
    );
    await settle(tester, 2);
    final home = c.read(localHomeProvider);
    expect(
      [for (final d in home.devices) d.key],
      ['shelly:a8032ab12345', 'tuya:plug1', 'broadlink:665544332211'],
    );
    expect(home.devices[1].options['version'], '3.4');
    expect(home.devices[2].options['btn:Klima on'], 'JgAQIA==');
    expect(home.rooms.map((r) => r.name), ['Kuhinja', 'Dnevna soba']);
    expect(home.names['shelly:a8032ab12345:switch0'], 'Svetlo u hodniku');
    expect(home.roomOf['tuya:plug1'], 'kitchen');
    expect(home.members.single.name, 'Ana');
    expect(credentials.values['device:shelly:a8032ab12345'], 'tajna');
    expect(credentials.values['device:tuya:plug1'], '0123456789abcdef');

    final routines = c.read(routinesProvider);
    expect(routines.scenes.single.name, 'Veče');
    expect(routines.automations.single.triggers, hasLength(1));
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(c.read(accentProvider), AppAccent.teal);
    expect(c.read(favoritesProvider), ['shelly:a8032ab12345:switch0']);
    expect(c.read(homeLocationWeatherEnabledProvider)?.latitude, 44.82);

    // A later format, with something this version does not know: read.
    final later = golden
        .replaceFirst('"version": 2', '"version": 3')
        .replaceFirst('"theme": "dark"', '"theme": "light", "future": 1');
    expect(
      await tester.runAsync(
        () => SettingsBackup.import(ref.ref, later, password: 'kucna lozinka'),
      ),
      BackupImport.done,
    );
    expect(c.read(themeModeProvider), ThemeMode.light);
    await unmount(tester);
  });
}

/// A [WidgetRef] for calling the backup outside a widget's build: that of
/// the first stateful consumer on screen.
class _Ref {
  _Ref(WidgetTester tester)
    : ref = tester
          .state<ConsumerState>(
            find.byWidgetPredicate((w) => w is ConsumerStatefulWidget).first,
          )
          .ref;

  final WidgetRef ref;
}
