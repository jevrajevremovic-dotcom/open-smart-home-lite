import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/value_list.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/all_lights.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../kiosk/application/kiosk_controller.dart';

/// Kinds that are "on" in a way worth turning off on the way out: not
/// sensors, locks or covers (those have their own checks).
bool _switchable(SmartHomeDevice d) => switch (d.kind) {
  DeviceKind.switchDevice ||
  DeviceKind.outlet ||
  DeviceKind.fan ||
  DeviceKind.airPurifier ||
  DeviceKind.humidifier ||
  DeviceKind.dehumidifier ||
  DeviceKind.climate ||
  DeviceKind.thermostat ||
  DeviceKind.mediaPlayer ||
  DeviceKind.speaker ||
  DeviceKind.television ||
  DeviceKind.vacuum ||
  DeviceKind.siren => true,
  _ => false,
};

/// What is on right now: the number of lights, and every other device
/// that is on (ids, by name).
final onNowProvider = Provider<({int lights, ValueList<String> others})>((ref) {
  final visible = ref.watch(visibleDeviceIdsProvider);
  return ref.watch(
    homeSnapshotProvider.select((s) {
      var lights = 0;
      final others = <String>[];
      for (final id in visible) {
        final d = s.devices[id];
        if (d == null || !d.available || d.state.isOn != true) continue;
        if (d.kind.isLight) {
          lights++;
        } else if (_switchable(d)) {
          others.add(id);
        }
      }
      return (lights: lights, others: ValueList(others));
    }),
  );
});

/// A row of chips: what is on now. A tap opens it, a long press turns it
/// off. Nothing on: nothing shown.
class OnNowStrip extends ConsumerWidget {
  const OnNowStrip({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(onNowProvider);
    if (now.lights == 0 && now.others.isEmpty) return const SizedBox.shrink();
    final messenger = ScaffoldMessenger.maybeOf(context);
    void said(String text) => messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    return Padding(
      padding: padding,
      child: Semantics(
        container: true,
        label: l10n.onNowTitle,
        child: SingleChildScrollView(
          key: const Key('onNowStrip'),
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              if (now.lights > 0)
                _OnChip(
                  key: const Key('onNowLights'),
                  icon: Icons.lightbulb,
                  label: l10n.onNowLights(now.lights),
                  swatch: context.deviceAccents.of(DeviceAccent.light),
                  onTap: () => showAllLightsSheet(context),
                  onLongPress: () async {
                    unawaited(HapticFeedback.mediumImpact());
                    await setAllLights(
                      context,
                      ref,
                      on: false,
                      wholeHome: true,
                    );
                    said(l10n.onNowLightsOff);
                  },
                ),
              for (final id in now.others) _DeviceChip(id: id, onOff: said),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceChip extends ConsumerWidget {
  const _DeviceChip({required this.id, required this.onOff});

  final String id;
  final void Function(String) onOff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(deviceProvider(id));
    if (d == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return _OnChip(
      key: ValueKey('onNow-$id'),
      icon: DevicePresentation.icon(d),
      label: d.name,
      swatch: DevicePresentation.swatch(context.deviceAccents, d),
      onTap: () => context.push(
        AppRoutes.device(id, kiosk: ref.read(kioskActiveProvider)),
      ),
      onLongPress: () async {
        unawaited(HapticFeedback.mediumImpact());
        final ok = await runDeviceCommand(context, ref, d, const TurnOff());
        if (ok) {
          onOff(l10n.onNowTurnedOff(d.name));
        }
      },
    );
  }
}

class _OnChip extends StatelessWidget {
  const _OnChip({
    super.key,
    required this.icon,
    required this.label,
    required this.swatch,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final String label;
  final AccentSwatch swatch;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A tooltip would take the long press: the hint goes to screen
    // readers instead.
    return Semantics(
      onLongPressHint: l10n.onNowHint,
      child: Material(
        color: swatch.container,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(icon, size: 18, color: swatch.onContainer),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: swatch.onContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
