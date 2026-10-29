import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../restricted/application/restricted_mode.dart';
import 'bedtime.dart';
import 'guest_wifi.dart';
import 'party.dart';
import 'sunrise_wake.dart';
import 'vacation.dart';
import '../floor_plan/floor_plan.dart';

/// One tool in "More".
typedef _Extra = ({
  Key key,
  IconData icon,
  String label,
  Future<void> Function(BuildContext context) open,
});

/// "More": the smaller tools, on the phone's Home and the wall panel.
Future<void> showExtras(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _ExtrasSheet(),
);

class _ExtrasSheet extends ConsumerWidget {
  const _ExtrasSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final kiosk = ref.watch(kioskActiveProvider);
    // Children and guests: only the fun ones.
    final restricted = ref.watch(
      restrictedModeProvider.select((s) => s.enabled),
    );
    final extras = <_Extra>[
      if (!restricted)
        (
          key: const Key('extraVacation'),
          icon: Icons.luggage_outlined,
          label: l10n.vacationTitle,
          open: showVacation,
        ),
      (
        key: const Key('extraParty'),
        icon: Icons.celebration_outlined,
        label: l10n.partyTitle,
        open: showParty,
      ),
      if (!restricted)
        (
          key: const Key('extraSunrise'),
          icon: Icons.wb_twilight,
          label: l10n.sunriseTitle,
          open: showSunriseWake,
        ),
      (
        key: const Key('extraBedtime'),
        icon: Icons.nightlight_outlined,
        label: l10n.bedtimeTitle,
        open: showBedtime,
      ),
      (
        key: const Key('extraGuestWifi'),
        icon: Icons.wifi,
        label: l10n.guestWifiTitle,
        open: showGuestWifi,
      ),
      (
        key: const Key('extraFloorPlan'),
        icon: Icons.map_outlined,
        label: l10n.floorPlanTitle,
        open: showFloorPlan,
      ),
    ];
    // Opens the tool after this sheet is gone (from the caller's context).
    final navigator = Navigator.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          key: const Key('extrasSheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.extrasTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final perRow = c.maxWidth >= 560 ? 4 : 3;
                final width = (c.maxWidth - 12 * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final e in extras)
                      SizedBox(
                        width: width,
                        child: _ExtraTile(
                          extra: e,
                          kiosk: kiosk,
                          onTap: () {
                            final host = navigator.context;
                            navigator.pop();
                            e.open(host);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtraTile extends StatelessWidget {
  const _ExtraTile({
    required this.extra,
    required this.kiosk,
    required this.onTap,
  });

  final _Extra extra;
  final bool kiosk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: extra.key,
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(extra.icon, size: kiosk ? 34 : 28, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                extra.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
