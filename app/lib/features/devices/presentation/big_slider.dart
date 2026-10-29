import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../application/device_providers.dart';
import '../domain/capability.dart';
import '../domain/device_command.dart';
import '../domain/device_kind.dart';
import '../domain/smart_home_device.dart';
import 'device_actions.dart';
import 'device_presentation.dart';

/// What the big slider sets on [d], or `null` when it has nothing to slide.
({String label, int value, DeviceCommand Function(int) command})? bigSliderFor(
  AppLocalizations l10n,
  SmartHomeDevice d,
) {
  final s = d.state;
  if (d.kind.isLight && d.supports(Capability.brightness)) {
    return (
      label: l10n.brightness,
      value: s.isOn == true ? (s.brightnessPercent ?? 100) : 0,
      command: (v) => v == 0 ? const TurnOff() : SetBrightness(v),
    );
  }
  if (d.supports(Capability.position)) {
    return (
      label: l10n.bigSliderPosition,
      value: s.position ?? 0,
      command: SetCoverPosition.new,
    );
  }
  if (d.supports(Capability.volume)) {
    return (
      label: l10n.volume,
      value: s.volumePercent ?? 0,
      command: SetVolume.new,
    );
  }
  return null;
}

/// The device's level as one big slider over the screen (long press on a
/// card): drag up and down, or tap a height.
Future<void> showBigSlider(BuildContext context, String deviceId) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      // The list behind goes soft, so only the slider stands out.
      pageBuilder: (_, _, _) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: _BigSlider(deviceId: deviceId),
      ),
    );

class _BigSlider extends ConsumerStatefulWidget {
  const _BigSlider({required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<_BigSlider> createState() => _BigSliderState();
}

class _BigSliderState extends ConsumerState<_BigSlider> {
  static const _height = 340.0;
  static const _width = 120.0;

  /// While dragging; the device's own value otherwise.
  double? _dragging;
  int? _lastStep;

  void _set(double dy) {
    final v = (1 - dy / _height).clamp(0.0, 1.0) * 100;
    final step = (v / 10).floor();
    if (step != _lastStep) {
      _lastStep = step;
      unawaited(HapticFeedback.selectionClick());
    }
    setState(() => _dragging = v);
  }

  Future<void> _commit(SmartHomeDevice d) async {
    final slider = bigSliderFor(context.l10n, d);
    final v = _dragging;
    if (slider == null || v == null) return;
    await runDeviceCommand(context, ref, d, slider.command(v.round()));
    if (mounted) setState(() => _dragging = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(deviceProvider(widget.deviceId));
    final slider = d == null ? null : bigSliderFor(l10n, d);
    if (d == null || slider == null) {
      return const SizedBox.shrink();
    }
    final swatch = d.state.isOn == true || slider.value > 0
        ? DevicePresentation.swatch(context.deviceAccents, d)
        : context.deviceAccents.of(DevicePresentation.accent(d));
    final value = (_dragging ?? slider.value.toDouble()).clamp(0.0, 100.0);
    return SafeArea(
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                d.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${slider.label} · ${value.round()} %',
                key: const Key('bigSliderValue'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                slider: true,
                label: slider.label,
                value: '${value.round()} %',
                increasedValue: '${(value + 10).clamp(0, 100).round()} %',
                decreasedValue: '${(value - 10).clamp(0, 100).round()} %',
                onIncrease: () {
                  setState(() => _dragging = (value + 10).clamp(0, 100));
                  unawaited(_commit(d));
                },
                onDecrease: () {
                  setState(() => _dragging = (value - 10).clamp(0, 100));
                  unawaited(_commit(d));
                },
                child: GestureDetector(
                  key: const Key('bigSlider'),
                  onVerticalDragStart: (e) => _set(e.localPosition.dy),
                  onVerticalDragUpdate: (e) => _set(e.localPosition.dy),
                  onVerticalDragEnd: (_) => _commit(d),
                  onTapUp: (e) {
                    _set(e.localPosition.dy);
                    unawaited(_commit(d));
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Container(
                      width: _width,
                      height: _height,
                      color: Colors.white.withValues(alpha: 0.18),
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: _dragging == null
                            ? const Duration(milliseconds: 250)
                            : Duration.zero,
                        width: _width,
                        height: _height * value / 100,
                        color: swatch.container,
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 18),
                        child: value > 12
                            ? Icon(
                                DevicePresentation.icon(d),
                                color: swatch.onContainer,
                                size: 32,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (d.kind.isLight ||
                  d.kind == DeviceKind.mediaPlayer ||
                  d.kind == DeviceKind.speaker ||
                  d.kind == DeviceKind.television)
                IconButton.filled(
                  key: const Key('bigSliderPower'),
                  iconSize: 28,
                  tooltip: d.state.isOn == true
                      ? l10n.timerTurnOff
                      : l10n.timerTurnOn,
                  style: IconButton.styleFrom(
                    backgroundColor: d.state.isOn == true
                        ? swatch.container
                        : Colors.white.withValues(alpha: 0.2),
                    foregroundColor: d.state.isOn == true
                        ? swatch.onContainer
                        : Colors.white,
                  ),
                  onPressed: () => runDeviceCommand(
                    context,
                    ref,
                    d,
                    d.state.isOn == true ? const TurnOff() : const TurnOn(),
                  ),
                  icon: const Icon(Icons.power_settings_new),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
