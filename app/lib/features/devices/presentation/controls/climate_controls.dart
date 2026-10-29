import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/smart_home_device.dart';
import '../device_actions.dart';
import '../device_presentation.dart';

class ClimateControls extends ConsumerStatefulWidget {
  const ClimateControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  ConsumerState<ClimateControls> createState() => _ClimateControlsState();
}

class _ClimateControlsState extends ConsumerState<ClimateControls> {
  /// Target chosen with +/- but not yet confirmed by the device.
  double? _pendingTarget;
  Timer? _debounce;

  @override
  void didUpdateWidget(ClimateControls old) {
    super.didUpdateWidget(old);
    if (widget.device.state.targetTemperature !=
        old.device.state.targetTemperature) {
      _pendingTarget = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _step(double delta) {
    final d = widget.device;
    final base = _pendingTarget ?? d.state.targetTemperature;
    if (base == null) return;
    final min = d.limits.minTemperature ?? 7;
    final max = d.limits.maxTemperature ?? 35;
    setState(() => _pendingTarget = (base + delta).clamp(min, max));
    // Several taps in a row become one command.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      final target = _pendingTarget;
      if (target != null && mounted) {
        runDeviceCommand(context, ref, d, SetTargetTemperature(target));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.device;
    final s = d.state;
    final theme = Theme.of(context);
    final locale = l10n.localeName;
    final step = d.limits.temperatureStep ?? 0.5;
    final target = _pendingTarget ?? s.targetTemperature;
    final enabled = d.available;

    String temp(double? v) =>
        v == null ? '—' : formatNumber(locale, v, unit: '°');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (d.supports(Capability.currentTemperature))
              Expanded(
                child: _Reading(
                  label: l10n.currentTemperature,
                  value: temp(s.currentTemperature),
                ),
              ),
            if (d.supports(Capability.humidity))
              Expanded(
                child: _Reading(
                  label: l10n.summaryHumidity,
                  value: s.currentHumidity == null
                      ? '—'
                      : formatNumber(locale, s.currentHumidity!, unit: '%'),
                ),
              ),
          ],
        ),
        if (d.supports(Capability.targetTemperature) &&
            s.hvacMode != 'off') ...[
          const SizedBox(height: 16),
          Text(
            l10n.targetTemperature,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                key: const Key('decreaseTemperature'),
                iconSize: 32,
                tooltip: l10n.decreaseTemperature,
                onPressed: enabled && target != null
                    ? () => _step(-step)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        temp(target),
                        key: const Key('targetTemperature'),
                        style: theme.textTheme.displayMedium,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const Key('increaseTemperature'),
                iconSize: 32,
                tooltip: l10n.increaseTemperature,
                onPressed: enabled && target != null ? () => _step(step) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
        if (d.supports(Capability.hvacMode) &&
            d.limits.hvacModes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.mode, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in d.limits.hvacModes)
                ChoiceChip(
                  label: Text(DevicePresentation.hvacModeLabel(l10n, mode)),
                  selected: s.hvacMode == mode,
                  onSelected: enabled
                      ? (_) =>
                            runDeviceCommand(context, ref, d, SetHvacMode(mode))
                      : null,
                ),
            ],
          ),
        ],
        if (d.supports(Capability.fanMode) && d.limits.fanModes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.fanMode, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in d.limits.fanModes)
                ChoiceChip(
                  label: Text(DevicePresentation.fanModeLabel(l10n, mode)),
                  selected: s.fanMode == mode,
                  onSelected: enabled
                      ? (_) =>
                            runDeviceCommand(context, ref, d, SetFanMode(mode))
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        Text(value, style: theme.textTheme.headlineMedium),
      ],
    );
  }
}
