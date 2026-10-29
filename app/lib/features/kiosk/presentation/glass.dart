import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kiosk_photo.dart';

final kioskPhotoStoreProvider = Provider<KioskPhotoStore>(
  (ref) => PlatformKioskPhotoStore(),
);

/// Surfaces of the dark kiosk cards.
abstract final class BubbleColors {
  static const Color background = Color(0xFF0E0E10);
  static const Color card = Color(0xFF1C1C1F);

  /// Buttons and chips on a card.
  static const Color raised = Color(0xFF2C2C30);
}

/// Text and icon colours on the dark kiosk cards.
abstract final class GlassColors {
  static const Color text = Colors.white;
  // Measured against the brightest glow under the darkened glass:
  // white ≥ 6.5:1, muted ≥ 5:1, faint ≥ 4.3:1 (WCAG contrast).
  static const Color muted = Color(0xD9FFFFFF); // 85 %
  static const Color faint = Color(0xB8FFFFFF); // 72 %
  static const Color fill = Color(0x1AFFFFFF);
  static const Color fillStrong = Color(0x2EFFFFFF);
  static const Color border = Color(0x29FFFFFF);
}

/// A dark kiosk card (music, thermostat): solid, no border, no blur,
/// readable at any distance.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: color ?? BubbleColors.card,
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Heading on a dark kiosk card.
class GlassTitle extends StatelessWidget {
  const GlassTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: GlassColors.text),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
