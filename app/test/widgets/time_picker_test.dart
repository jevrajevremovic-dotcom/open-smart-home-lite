import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/widgets/time_picker.dart';

void main() {
  testWidgets('Serbian on a 12-hour phone: 22:00 can be typed', (tester) async {
    TimeOfDay? picked;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sr'),
        supportedLocales: const [Locale('sr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showAppTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 6, minute: 0),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Text entry mode, hour 22.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '22');
    await tester.pumpAndSettle();
    final ok = MaterialLocalizations.of(
      tester.element(find.byType(TextField).first),
    ).okButtonLabel;
    await tester.tap(find.text(ok));
    await tester.pumpAndSettle();
    expect(picked, const TimeOfDay(hour: 22, minute: 0));
  });
}
