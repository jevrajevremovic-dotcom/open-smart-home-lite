import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_locales.dart';
import '../../../app/localization/l10n.dart';
import '../application/appearance_controllers.dart';
import '../../../app/brand.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const _system = 'system';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(localeProvider);
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: _system, label: Text(l10n.languageSystem)),
        ButtonSegment(
          value: AppLocales.toTag(AppLocales.serbianLatin),
          label: Text(l10n.languageSerbian),
        ),
        ButtonSegment(
          value: AppLocales.toTag(AppLocales.english),
          label: Text(l10n.languageEnglish),
        ),
      ],
      selected: {current == null ? _system : AppLocales.toTag(current)},
      onSelectionChanged: (selection) {
        final tag = selection.single;
        ref
            .read(localeProvider.notifier)
            .set(tag == _system ? null : AppLocales.fromTag(tag));
      },
    );
  }
}

class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          icon: const Icon(Icons.brightness_auto_outlined),
          label: Text(l10n.themeSystem),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_outlined),
          label: Text(l10n.themeLight),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_outlined),
          label: Text(l10n.themeDark),
        ),
      ],
      selected: {ref.watch(themeModeProvider)},
      // Following the sun decides by itself.
      onSelectionChanged: ref.watch(autoDarkProvider)
          ? null
          : (s) => ref.read(themeModeProvider.notifier).set(s.single),
    );
  }
}

/// "Dark after sunset" switch, under the theme choice.
class AutoDarkTile extends ConsumerWidget {
  const AutoDarkTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SwitchListTile(
      key: const Key('themeAutoDark'),
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.wb_twilight_outlined),
      title: Text(l10n.themeAutoDark),
      subtitle: Text(l10n.themeAutoDarkHint),
      value: ref.watch(autoDarkProvider),
      onChanged: (v) => ref.read(autoDarkProvider.notifier).set(v),
    );
  }
}

/// Pure black dark theme, under the theme choice.
class OledTile extends ConsumerWidget {
  const OledTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SwitchListTile(
      key: const Key('themeOled'),
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.contrast),
      title: Text(l10n.themeOled),
      subtitle: Text(l10n.themeOledHint),
      value: ref.watch(oledProvider),
      onChanged: (v) => ref.read(oledProvider.notifier).set(v),
    );
  }
}

/// The app's accent colour, as a row of swatches.
class AccentSelector extends ConsumerWidget {
  const AccentSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(accentProvider);
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final a in AppAccent.values)
          Tooltip(
            message: accentLabel(l10n, a),
            child: Semantics(
              selected: a == current,
              button: true,
              label: accentLabel(l10n, a),
              child: InkResponse(
                key: ValueKey('accent-${a.name}'),
                radius: 28,
                onTap: () => ref.read(accentProvider.notifier).set(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor(a) ?? const Color(0xFFB5521B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: a == current
                          ? scheme.onSurface
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: a == current
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String accentLabel(AppLocalizations l10n, AppAccent a) => switch (a) {
  AppAccent.terracotta =>
    Brand.accent != null ? Brand.name(l10n) : l10n.accentTerracotta,
  AppAccent.blue => l10n.accentBlue,
  AppAccent.green => l10n.accentGreen,
  AppAccent.purple => l10n.accentPurple,
  AppAccent.rose => l10n.accentRose,
  AppAccent.teal => l10n.accentTeal,
};
