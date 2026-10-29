import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/extras/air_advice.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../../widgets/app_widget_test.dart' show en, pumpApp, settle, unmount;

void main() {
  testWidgets('stuffy bedroom: advice on Home; aired: gone', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    expect(container.read(airAdviceProvider).single.co2, isTrue);
    expect(find.text(en.airAdviceTitle('Spavaća soba')), findsOneWidget);
    expect(find.text(en.airAdviceCo2(1350)), findsOneWidget);

    server.setStateForTest('sensor.bedroom_co2', '640');
    await settle(tester, 3);
    expect(container.read(airAdviceProvider), isEmpty);
    expect(find.byKey(const Key('airAdvice')), findsNothing);

    // Damp living room.
    server.setStateForTest('sensor.living_room_humidity', '74');
    await settle(tester, 3);
    expect(find.text(en.airAdviceHumidity(74)), findsOneWidget);
    await unmount(tester);
  });
}
