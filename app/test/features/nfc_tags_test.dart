import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/nfc_tags/nfc_tags.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../helpers.dart' show FakeAlertNotifier, FakeNfc;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('tag ids and URLs like the official apps', () {
    final id = newTagId(Random(1));
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$',
        ),
      ),
    );
    expect(haTagUri('X1'), 'https://www.home-assistant.io/tag/X1');
    final a = tagAutomation(alias: 'NFC', tagId: 'X1', target: 'scene.away');
    expect((a['triggers']! as List).single, {'trigger': 'tag', 'tag_id': 'X1'});
    expect(((a['actions']! as List).single as Map)['action'], 'scene.turn_on');
  });

  MockHomeAssistantServer serverOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
          .read(mockHomeAssistantServerProvider);

  Future<void> register(WidgetTester tester) async {
    await goTo(tester, AppRoutes.settingsSection('notifications'));
    await tapKey(tester, 'haPushTile');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('haPushName')), 'Telefon');
    await tester.tap(find.byKey(const Key('haPushRegister')));
    await settle(tester, 8);
  }

  Future<void> writeTag(WidgetTester tester, FakeNfc nfc, String name) async {
    await goTo(tester, AppRoutes.settingsSection('nfc'));
    await settle(tester, 4);
    await tapKey(tester, 'nfcNew');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('nfcName')), name);
    await tapKey(tester, 'nfcTarget');
    await settle(tester, 3);
    await tester.tap(find.text('Filmsko veče').last);
    await settle(tester, 3);
    await tapKey(tester, 'nfcWrite');
    await settle(tester, 3);
    expect(find.byKey(const Key('nfcHoldDialog')), findsOneWidget);
    nfc.finishWrite();
    await settle(tester, 8);
  }

  testWidgets('write a tag, name it in HA, scanning runs the scene', (
    tester,
  ) async {
    final nfc = FakeNfc();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      alerts: FakeAlertNotifier(),
      nfc: nfc,
    );
    await settle(tester, 10);
    final server = serverOf(tester);
    await register(tester);
    await writeTag(tester, nfc, 'Ulaz');

    final id = nfc.writing!.split('/tag/').last;
    expect(nfc.writing, haTagUri(id));
    expect(server.tags[id]?['name'], 'Ulaz');
    final automation = server.automations.values.single;
    expect((automation['triggers']! as List).single, {
      'trigger': 'tag',
      'tag_id': id,
    });
    expect(find.text(en.nfcWritten('Ulaz')), findsOneWidget);
    expect(find.byKey(ValueKey('nfcTag-$id')), findsOneWidget);

    nfc.scan('nfc:$id');
    await settle(tester, 6);
    expect(server.scannedTags, [id]);
    expect(server.firedEvents.last['event_type'], 'tag_scanned');
    expect(find.text(en.nfcScanned('Ulaz')), findsOneWidget);

    // The same address from a QR code, the web or another app: asked
    // first; cancelled, nothing reaches Home Assistant.
    nfc.scan('link:$id');
    await settle(tester, 4);
    expect(find.text(en.nfcLinkConfirm('Ulaz')), findsOneWidget);
    await tester.tap(find.text(en.cancel));
    await settle(tester, 4);
    expect(server.scannedTags, [id]);
    nfc.scan('link:$id');
    await settle(tester, 4);
    await tapKey(tester, 'nfcLinkConfirm');
    await settle(tester, 6);
    expect(server.scannedTags, [id, id]);
    await unmount(tester);
  });

  testWidgets('without a Mobile App registration a scan explains why', (
    tester,
  ) async {
    final nfc = FakeNfc();
    await pumpApp(tester, signedIn: true, nfc: nfc);
    await settle(tester, 10);
    nfc.scan('nfc:ABC');
    await settle(tester, 4);
    expect(
      find.text(en.nfcScanFailed(en.nfcNeedsRegistration)),
      findsOneWidget,
    );
    expect(serverOf(tester).scannedTags, isEmpty);
    await unmount(tester);
  });

  testWidgets('not an administrator: written, but HA setup explained', (
    tester,
  ) async {
    final nfc = FakeNfc();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      alerts: FakeAlertNotifier(),
      nfc: nfc,
    );
    await settle(tester, 10);
    serverOf(tester).configAdmin = false;
    await register(tester);
    await writeTag(tester, nfc, 'Garaža');
    expect(find.text(en.nfcWrittenNoAdmin), findsOneWidget);
    await unmount(tester);
  });
}
