import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/household_providers.dart';

/// Round photo (or initials) of a household member with a home badge.
/// Members who are away are shown dimmed.
class PersonAvatar extends ConsumerWidget {
  const PersonAvatar({super.key, required this.personId, this.size = 52});

  final String personId;
  final double size;

  static const _palette = [
    Color(0xFF3D7BFF),
    Color(0xFFB065E8),
    Color(0xFF2DBE6C),
    Color(0xFFFF7A45),
    Color(0xFF1FB5C9),
    Color(0xFFE5487D),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(deviceProvider(personId));
    if (person == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final home = person.state.isActive == true;
    final path = person.metadata.picturePath;
    final bytes = path == null
        ? null
        : ref.watch(entityImageProvider(path)).value;
    final initials = person.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    final color = _palette[person.id.hashCode.abs() % _palette.length];
    final status = DevicePresentation.status(l10n, person);
    final badge = size * 0.38;

    return Tooltip(
      message: '${person.name}: $status',
      child: Semantics(
        label: '${person.name}, $status',
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size + 4,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: home ? 1 : 0.55,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(color: Colors.white, width: 2),
                      image: bytes == null
                          ? null
                          : DecorationImage(
                              image: MemoryImage(bytes),
                              fit: BoxFit.cover,
                            ),
                    ),
                    alignment: Alignment.center,
                    child: bytes != null
                        ? null
                        : Text(
                            initials,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: size * 0.36,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Fixed colours: white icon must stay readable in
                    // both themes and on glass.
                    color: home
                        ? const Color(0xFF1B8A45)
                        : const Color(0xFF6F7975),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(
                    home ? Icons.home_rounded : Icons.near_me_outlined,
                    size: badge * 0.62,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
