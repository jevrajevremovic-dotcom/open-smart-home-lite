import 'package:flutter/material.dart';

import 'localization/l10n.dart';

/// The installer's brand, set when building (`tool/build_brand.sh` reads
/// `android/brand.properties`); without it, the app is Open Smart Home.
abstract final class Brand {
  static const _name = String.fromEnvironment('BRAND_NAME');
  static const _accent = String.fromEnvironment('BRAND_ACCENT');

  /// Who installed the system and supports it (phone, e-mail, web), shown
  /// on the service screen.
  static const support = String.fromEnvironment('BRAND_SUPPORT');

  /// A logo was bundled as `assets/brand/logo.png`.
  static const hasLogo = bool.fromEnvironment('BRAND_LOGO');
  static const logoAsset = 'assets/brand/logo.png';

  static bool get isBranded => _name.isNotEmpty;

  /// The brand's name, or the app's own.
  static String name(AppLocalizations l10n) =>
      _name.isNotEmpty ? _name : l10n.appTitle;

  /// The brand colour (`#RRGGBB`), or `null`.
  static Color? get accent {
    final hex = _accent.replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16);
    if (v == null || hex.length != 6) return null;
    return Color(0xFF000000 | v);
  }
}

/// The brand's logo, or the app's house icon.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (Brand.hasLogo) {
      return Image.asset(
        Brand.logoAsset,
        height: size,
        semanticLabel: Brand.name(l10n),
        errorBuilder: (_, _, _) => _icon(context),
      );
    }
    return _icon(context);
  }

  Widget _icon(BuildContext context) => Icon(
    Icons.home_work_outlined,
    size: size,
    color: Theme.of(context).colorScheme.primary,
    semanticLabel: Brand.name(context.l10n),
  );
}
