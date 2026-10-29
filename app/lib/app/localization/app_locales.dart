import 'package:flutter/widgets.dart';

/// Languages the app offers. Serbian is always Latin script.
abstract final class AppLocales {
  static const Locale english = Locale('en');
  static const Locale serbianLatin = Locale.fromSubtags(
    languageCode: 'sr',
    scriptCode: 'Latn',
  );

  static const List<Locale> selectable = [serbianLatin, english];

  static String toTag(Locale locale) => locale.toLanguageTag();

  static Locale? fromTag(String? tag) {
    if (tag == null) return null;
    for (final locale in selectable) {
      if (locale.toLanguageTag() == tag) return locale;
    }
    return null;
  }

  /// Maps any Serbian system locale (incl. Cyrillic `sr`, `sr-RS`) to the
  /// Latin translation, so Material widgets also use Latin script.
  static Locale resolve(List<Locale>? preferred, Iterable<Locale> supported) {
    for (final locale in preferred ?? const <Locale>[]) {
      if (locale.languageCode == 'sr') return serbianLatin;
      if (locale.languageCode == 'en') return english;
    }
    return english;
  }
}
