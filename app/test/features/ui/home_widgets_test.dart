import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/favorites/application/favorites_controller.dart';
import 'package:open_smart_home_lite/features/shortcuts/home_widgets.dart';

import '../../home_fixture.dart';
import '../../helpers.dart' show FakeHomeScreenWidget;
import '../../widgets/app_widget_test.dart' show en, pumpApp, settle, unmount;

void main() {
  test('only the two widget links are actions', () {
    expect(
      homeWidgetActionFromUri(Uri.parse('opensmarthome://climate?step=1')),
      (kind: 'climate', step: 1),
    );
    expect(
      homeWidgetActionFromUri(Uri.parse('opensmarthome://climate?step=-1')),
      (kind: 'climate', step: -1),
    );
    expect(
      homeWidgetActionFromUri(Uri.parse('opensmarthome://climate?step=10')),
      isNull,
    );
    expect(
      homeWidgetActionFromUri(
        Uri.parse('opensmarthome://light?action=toggle&id=lock.front_door'),
      ),
      (kind: 'light', step: 0),
    );
    expect(homeWidgetActionFromUri(Uri.parse('https://light')), isNull);
  });

  testWidgets('the widgets get the home; their taps act on their devices', (
    tester,
  ) async {
    final widget = FakeHomeScreenWidget();
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(800, 1600),
      homeWidget: widget,
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = HomeFixture.running;
    await container
        .read(favoritesProvider.notifier)
        .toggle('fx:light.living_room_main');
    await settle(tester, 3);

    final status = widget.homeWidgets['status']!;
    expect(status['title'], en.widgetHomeTitle);
    expect((status['lines']! as List).first, en.widgetLightsOn(2));
    expect(widget.homeWidgets['thermostat']!['name'], isNotEmpty);
    expect(widget.homeWidgets['light']!['on'], isTrue);

    // + on the thermostat widget: half a degree warmer.
    final id = container.read(widgetThermostatProvider)!;
    final before = container.read(deviceProvider(id))!.state.targetTemperature!;
    widget.tap(Uri.parse('opensmarthome://climate?step=1'));
    await settle(tester, 4);
    expect(
      container.read(deviceProvider(id))!.state.targetTemperature,
      before + widgetClimateStep,
    );

    // The light widget toggles its own light, whatever else the link says.
    widget.tap(
      Uri.parse('opensmarthome://light?action=toggle&id=lock.front_door'),
    );
    await settle(tester, 4);
    expect(server.stateOf('fx:light.living_room_main'), 'off');
    expect(server.stateOf('fx:lock.front_door'), 'locked');
    expect(widget.homeWidgets['light']!['on'], isFalse);
    await unmount(tester);
  });
}
