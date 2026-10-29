import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/brand.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/features/settings/application/appearance_controllers.dart';

void main() {
  test('without a brand the app is Open Smart Home, warm default', () {
    final l10n = AppLocalizationsEn();
    expect(Brand.isBranded, isFalse);
    expect(Brand.name(l10n), l10n.appTitle);
    expect(Brand.accent, isNull);
    expect(accentColor(AppAccent.terracotta), isNull);
    expect(Brand.hasLogo, isFalse);
  });
}
