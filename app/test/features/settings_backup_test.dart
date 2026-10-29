import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/security/backup_crypto.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/favorites/application/favorites_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/settings/application/appearance_controllers.dart';
import 'package:open_smart_home_lite/features/settings/data/lan_transfer.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('copy settings, change them, paste them back; no secrets', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboard};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpApp(tester, size: const Size(800, 1600));
    await settle(tester, 10);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await c.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await c.read(favoritesProvider.notifier).toggle('light.hallway');
    await c
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(quickControls: ['light.hallway']));
    await c.read(kioskSettingsProvider.notifier).setPin('1234');

    await goTo(tester, AppRoutes.settingsSection('backup'));
    await tapKey(tester, 'backupCopy');
    await settle(tester, 2);
    expect(clipboard, contains('"quickControls"'));
    expect(clipboard, isNot(contains('pinHash')));
    expect(clipboard, isNot(contains('token')));

    await c.read(themeModeProvider.notifier).set(ThemeMode.light);
    await c.read(favoritesProvider.notifier).toggle('light.hallway');
    await c
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(quickControls: []));
    await settle(tester, 2);

    await tapKey(tester, 'backupPaste');
    await settle(tester, 2);
    await tapKey(tester, 'backupReplace');
    await settle(tester, 4);
    expect(find.text(en.backupImported), findsOneWidget);
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(c.read(favoritesProvider), contains('light.hallway'));
    expect(c.read(kioskSettingsProvider).quickControls, ['light.hallway']);
    expect(c.read(kioskSettingsProvider).hasPin, isTrue, reason: 'PIN kept');

    clipboard = 'hello';
    await tapKey(tester, 'backupPaste');
    await settle(tester, 2);
    await tapKey(tester, 'backupMerge');
    await settle(tester, 4);
    expect(find.text(en.backupInvalid), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a device password goes along only sealed with a password', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboard};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final credentials = await pumpApp(tester, size: const Size(800, 1600));
    await settle(tester, 10);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await c
        .read(localHomeProvider.notifier)
        .addDevice(
          const ConfiguredDevice(adapter: 'shelly', id: 'abc', host: 'plug'),
          password: 'tajna',
        );

    await goTo(tester, AppRoutes.settingsSection('backup'));
    await tapKey(tester, 'backupWithSecrets');
    await settle(tester);
    await tester.enterText(find.byKey(const Key('backupPassword')), '123');
    await settle(tester);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('backupCopy')))
          .onPressed,
      isNull,
      reason: 'too short',
    );
    await tester.enterText(
      find.byKey(const Key('backupPassword')),
      'kucna lozinka',
    );
    await settle(tester);
    await tester.runAsync(() => tapKey(tester, 'backupCopy'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await settle(tester, 2);
    expect(clipboard, contains('"secrets"'));
    expect(clipboard, isNot(contains('tajna')));

    // A new phone: nothing there.
    await c.read(localHomeProvider.notifier).removeDevice('shelly:abc');
    expect(credentials.values, isNot(contains('device:shelly:abc')));

    Future<void> paste(String password) async {
      await tapKey(tester, 'backupPaste');
      await settle(tester, 2);
      await tester.enterText(
        find.byKey(const Key('backupImportPassword')),
        password,
      );
      await tapKey(tester, 'backupImportPasswordOk');
      await settle(tester, 2);
      await tapKey(tester, 'backupMerge');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await settle(tester, 4);
    }

    await paste('pogresna');
    expect(find.text(en.backupWrongPassword), findsOneWidget);
    expect(c.read(localHomeProvider).devices, isEmpty);

    await paste('kucna lozinka');
    expect(find.text(en.backupImported), findsOneWidget);
    expect(c.read(localHomeProvider).devices.single.secured, isTrue);
    expect(credentials.values['device:shelly:abc'], 'tajna');
    await unmount(tester);
  });

  test(
    'sealed secrets: the right password opens, a wrong one does not',
    () async {
      final sealed = await BackupCrypto.seal(
        {'device:x': 'p'},
        'lozinka',
        iterations: 1000,
      );
      expect(await BackupCrypto.open(sealed, 'lozinka'), {'device:x': 'p'});
      expect(await BackupCrypto.open(sealed, 'Lozinka'), isNull);
      expect(
        await BackupCrypto.open({...sealed, 'data': 'AA=='}, 'lozinka'),
        isNull,
      );
    },
  );

  test('sent over Wi-Fi once, with its code', () async {
    // flutter_test answers every HTTP request with 400; this one is real.
    HttpOverrides.global = null;
    final server = await LanTransferServer.start('{"x":1}', host: '127.0.0.1');
    await expectLater(
      receiveBackup(
        server.address,
        '000000' == server.code ? '111111' : '000000',
      ),
      throwsA(LanTransferError.wrongCode),
    );
    // The wrong try took it: the server is gone.
    expect(await server.done, isTrue);
    await expectLater(
      receiveBackup(server.address, server.code),
      throwsA(LanTransferError.unreachable),
    );

    final again = await LanTransferServer.start('{"x":1}', host: '127.0.0.1');
    expect(await receiveBackup(again.address, again.code), '{"x":1}');
    expect(await again.done, isTrue);
  });
}
