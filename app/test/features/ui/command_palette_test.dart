import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/search/command_palette.dart';

import '../../home_fixture.dart';
import '../../widgets/app_widget_test.dart' show pumpApp, settle, unmount;

void main() {
  test('diacritics do not matter', () {
    expect(searchFold('Čaša Đorđe ŠŽ'), 'casa djordje sz');
  });

  testWidgets('Ctrl+K, "kuh", Enter: the kitchen opens', (tester) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(1280, 800));
    await settle(tester, 10);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, 3);
    expect(find.byKey(const Key('commandPalette')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('paletteField')), 'kuh');
    await settle(tester);
    expect(find.byKey(const ValueKey('paletteHit-kitchen')), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 6);
    expect(find.byKey(const Key('commandPalette')), findsNothing);
    expect(find.text('Kuhinja'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('a scene by name, Enter runs it', (tester) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(1280, 800));
    await settle(tester, 10);
    final server = HomeFixture.running;
    unawaited(showCommandPalette(tester.element(find.byType(Scaffold).first)));
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('paletteField')), 'film');
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 6);
    expect(
      server.stateOf('fx:light.living_room_main'),
      'off',
      reason: 'the scene ran',
    );
    await unmount(tester);
  });
}
