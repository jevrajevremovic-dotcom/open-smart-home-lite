import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../favorites/application/favorites_controller.dart';

/// Thermostat shown on the kiosk: a favorite one if there is any,
/// otherwise the first by name. `null` = no climate device in the home.
final kioskThermostatIdProvider = Provider<String?>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final favorites = ref.watch(favoritesProvider);
  bool isClimate(SmartHomeDevice d) =>
      (d.kind == DeviceKind.climate || d.kind == DeviceKind.thermostat) &&
      d.supports(Capability.targetTemperature);
  for (final id in favorites) {
    final d = devices[id];
    if (d != null && isClimate(d)) return id;
  }
  final all = devices.values.where(isClimate).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return all.isEmpty ? null : all.first.id;
});

/// Colour of the active arc for an HVAC mode.
Color hvacColor(String? mode) => switch (mode) {
  'heat' => const Color(0xFFFF9C5B),
  'cool' => const Color(0xFF6CC4FF),
  'heat_cool' || 'auto' => const Color(0xFF8FE3B0),
  'dry' => const Color(0xFFFFD36B),
  'fan_only' => const Color(0xFFB9C7FF),
  _ => const Color(0x66FFFFFF),
};

IconData hvacIcon(String mode) => switch (mode) {
  'off' => Icons.power_settings_new,
  'heat' => Icons.local_fire_department_outlined,
  'cool' => Icons.ac_unit,
  'heat_cool' || 'auto' => Icons.thermostat_auto,
  'dry' => Icons.water_drop_outlined,
  'fan_only' => Icons.air,
  _ => Icons.thermostat,
};

IconData presetIcon(String preset) => switch (preset) {
  'none' => Icons.do_not_disturb_on_outlined,
  'home' => Icons.home_outlined,
  'away' => Icons.directions_walk,
  'sleep' => Icons.bedtime_outlined,
  'eco' => Icons.eco_outlined,
  'comfort' => Icons.weekend_outlined,
  'boost' => Icons.rocket_launch_outlined,
  'activity' => Icons.directions_run,
  _ => Icons.tune,
};

/// Circular thermostat: drag along the arc or use −/+; modes underneath.
class KioskThermostatPanel extends ConsumerStatefulWidget {
  const KioskThermostatPanel({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<KioskThermostatPanel> createState() =>
      _KioskThermostatPanelState();
}

class _KioskThermostatPanelState extends ConsumerState<KioskThermostatPanel> {
  /// Target chosen on the dial but not yet confirmed by the device.
  double? _pending;
  double? _confirmedTarget;
  Timer? _debounce;

  static const _sweep = 1.5 * math.pi; // 270°
  static const _start = 0.75 * math.pi; // from bottom-left, clockwise

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  (double, double, double) _range(SmartHomeDevice d) => (
    d.limits.minTemperature ?? 7,
    d.limits.maxTemperature ?? 35,
    d.limits.temperatureStep ?? 0.5,
  );

  double _snap(SmartHomeDevice d, double v) {
    final (min, max, step) = _range(d);
    return ((v / step).round() * step).clamp(min, max);
  }

  void _setPending(SmartHomeDevice d, double value, {bool sendNow = false}) {
    setState(() => _pending = _snap(d, value));
    _debounce?.cancel();
    _debounce = Timer(
      sendNow ? Duration.zero : const Duration(milliseconds: 700),
      () {
        final target = _pending;
        if (target != null && mounted) {
          runDeviceCommand(context, ref, d, SetTargetTemperature(target));
        }
      },
    );
  }

  void _fromPosition(SmartHomeDevice d, Offset local, Size size) {
    final c = size.center(Offset.zero);
    var angle = math.atan2(local.dy - c.dy, local.dx - c.dx) - _start;
    while (angle < 0) {
      angle += 2 * math.pi;
    }
    // The 90° gap at the bottom snaps to the nearer end.
    final f = angle > _sweep
        ? (angle - _sweep < (2 * math.pi - _sweep) / 2 ? 1.0 : 0.0)
        : angle / _sweep;
    final (min, max, _) = _range(d);
    setState(() => _pending = _snap(d, min + f * (max - min)));
    _debounce?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = l10n.localeName;
    final d = ref.watch(deviceProvider(widget.deviceId));
    if (d == null) return const SizedBox.shrink();
    final s = d.state;
    // A new value from the device replaces what was chosen locally.
    if (s.targetTemperature != _confirmedTarget) {
      _confirmedTarget = s.targetTemperature;
      _pending = null;
    }
    final off = s.hvacMode == 'off';
    final target = _pending ?? s.targetTemperature;
    final (min, max, step) = _range(d);
    final fraction = target == null
        ? 0.0
        : ((target - min) / (max - min)).clamp(0.0, 1.0);
    final enabled = d.available && !off && target != null;
    final color = off ? hvacColor('off') : hvacColor(s.hvacMode);
    final pal = _Palette.of(theme.colorScheme);

    String temp(double? v) =>
        v == null ? '—' : formatNumber(locale, v, unit: '°');

    final dial = LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth, c.maxHeight);
        final size = Size.square(side);
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: Semantics(
              slider: true,
              label: '${d.name}, ${l10n.targetTemperature}',
              value: temp(target),
              increasedValue: target == null
                  ? null
                  : temp(_snap(d, target + step)),
              decreasedValue: target == null
                  ? null
                  : temp(_snap(d, target - step)),
              onIncrease: enabled ? () => _setPending(d, target + step) : null,
              onDecrease: enabled ? () => _setPending(d, target - step) : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: enabled
                    ? (e) => _fromPosition(d, e.localPosition, size)
                    : null,
                onPanUpdate: enabled
                    ? (e) => _fromPosition(d, e.localPosition, size)
                    : null,
                onPanEnd: enabled
                    ? (_) => _setPending(d, _pending ?? target, sendNow: true)
                    : null,
                child: CustomPaint(
                  painter: _DialPainter(
                    fraction: off ? 0 : fraction,
                    color: color,
                    showKnob: !off && target != null,
                    track: pal.track,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            side * 0.2,
                            side * 0.17,
                            side * 0.2,
                            side * 0.34,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ExcludeSemantics(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DevicePresentation.hvacModeLabel(
                                      l10n,
                                      s.hvacMode,
                                    ),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(color: pal.muted),
                                  ),
                                  Text(
                                    off ? '—' : temp(target),
                                    key: const Key('kioskTargetTemperature'),
                                    style: theme.textTheme.displayLarge
                                        ?.copyWith(
                                          color: pal.text,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -2,
                                          height: 1.05,
                                        ),
                                  ),
                                  if (s.currentTemperature != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.thermostat,
                                          size: 18,
                                          color: pal.muted,
                                        ),
                                        Text(
                                          temp(s.currentTemperature),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(color: pal.muted),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // −/+ sit in the gap at the bottom of the arc.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: side * 0.04,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _RoundButton(
                                pal: pal,
                                key: const Key('kioskDecreaseTemperature'),
                                icon: Icons.remove,
                                tooltip: l10n.decreaseTemperature,
                                onPressed: enabled
                                    ? () => _setPending(d, target - step)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              _RoundButton(
                                pal: pal,
                                key: const Key('kioskIncreaseTemperature'),
                                icon: Icons.add,
                                tooltip: l10n.increaseTemperature,
                                onPressed: enabled
                                    ? () => _setPending(d, target + step)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final presets = d.supports(Capability.presetMode)
        ? d.limits.presetModes
        : const <String>[];
    final modes = d.supports(Capability.hvacMode)
        ? d.limits.hvacModes
        : const <String>[];

    return Column(
      children: [
        Expanded(child: dial),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // With presets: power + presets (like a wall thermostat).
              // Without: the HVAC modes, which include "off".
              if (presets.isNotEmpty)
                _ModeButton(
                  pal: pal,
                  key: const Key('kioskThermostatPower'),
                  icon: Icons.power_settings_new,
                  label: l10n.powerToggle,
                  selected: !off,
                  color: hvacColor(s.hvacMode),
                  onPressed: d.available
                      ? () => runDeviceCommand(
                          context,
                          ref,
                          d,
                          _powerCommand(d, turnOn: off),
                        )
                      : null,
                )
              else
                for (final mode in modes)
                  _ModeButton(
                    pal: pal,
                    icon: hvacIcon(mode),
                    label: DevicePresentation.hvacModeLabel(l10n, mode),
                    selected: s.hvacMode == mode,
                    color: hvacColor(mode),
                    onPressed: d.available
                        ? () => runDeviceCommand(
                            context,
                            ref,
                            d,
                            SetHvacMode(mode),
                          )
                        : null,
                  ),
              if (!off)
                for (final p in presets.where((p) => p != 'none'))
                  _ModeButton(
                    pal: pal,
                    icon: presetIcon(p),
                    label: DevicePresentation.presetLabel(l10n, p),
                    selected: s.presetMode == p,
                    color: pal.text,
                    onPressed: d.available
                        ? () => runDeviceCommand(
                            context,
                            ref,
                            d,
                            SetPresetMode(s.presetMode == p ? 'none' : p),
                          )
                        : null,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `turn_on` restores the previous mode in Home Assistant; devices without
/// it get the first mode that is not "off".
DeviceCommand _powerCommand(SmartHomeDevice d, {required bool turnOn}) {
  if (d.supports(Capability.power)) {
    return turnOn ? const TurnOn() : const TurnOff();
  }
  if (!turnOn) return const SetHvacMode('off');
  return SetHvacMode(
    d.limits.hvacModes.firstWhere((m) => m != 'off', orElse: () => 'heat'),
  );
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.fraction,
    required this.color,
    required this.showKnob,
    required this.track,
  });

  final double fraction;
  final Color color;
  final bool showKnob;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke,
    );
    const start = 0.75 * math.pi;
    const sweep = 1.5 * math.pi;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, trackPaint);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        start,
        sweep * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    if (showKnob) {
      final a = start + sweep * fraction;
      final p =
          rect.center + Offset(math.cos(a), math.sin(a)) * (rect.width / 2);
      canvas.drawCircle(p, stroke * 0.95, Paint()..color = Colors.white);
      canvas.drawCircle(p, stroke * 0.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.showKnob != showKnob ||
      old.track != track;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.pal,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final _Palette pal;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    iconSize: 24,
    style: IconButton.styleFrom(
      foregroundColor: pal.text,
      disabledForegroundColor: pal.faint,
      minimumSize: const Size.square(48),
      side: BorderSide(color: pal.muted, width: 1.5),
    ),
    icon: Icon(icon),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.pal,
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final _Palette pal;
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Tooltip(
      message: label,
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? pal.fillStrong : pal.fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 52,
              child: Icon(icon, color: selected ? color : pal.muted, size: 26),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Colours of the dial, from the app theme.
class _Palette {
  const _Palette({
    required this.text,
    required this.muted,
    required this.faint,
    required this.track,
    required this.fill,
    required this.fillStrong,
  });

  factory _Palette.of(ColorScheme c) => _Palette(
    text: c.onSurface,
    muted: c.onSurfaceVariant,
    faint: c.outline,
    track: c.surfaceContainerHighest,
    fill: c.surfaceContainerHigh,
    fillStrong: c.surfaceContainerHighest,
  );

  final Color text;
  final Color muted;
  final Color faint;
  final Color track;
  final Color fill;
  final Color fillStrong;
}
