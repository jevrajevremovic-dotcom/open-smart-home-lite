import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/smart_home_device.dart';
import '../device_actions.dart';
import '../device_presentation.dart';
import 'command_slider.dart';

/// Fan: speed (in the fan's own steps), oscillation and presets.
class FanControls extends ConsumerWidget {
  const FanControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = device;
    final step = d.limits.percentageStep;
    final divisions = step != null && step > 0 ? (100 / step).round() : 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.supports(Capability.fanSpeed))
          CommandSlider(
            label: l10n.fanSpeed,
            value: d.state.isOn == true ? d.state.percentage?.toDouble() : 0,
            min: 0,
            max: 100,
            divisions: divisions,
            enabled: d.available,
            format: (v) => '${v.round()} %',
            leading: const Icon(Icons.air),
            onCommit: (v) =>
                runDeviceCommand(context, ref, d, SetFanSpeed(v.round())),
          ),
        if (d.supports(Capability.oscillate))
          SwitchListTile(
            key: const Key('fanOscillate'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_horiz),
            title: Text(l10n.fanOscillate),
            value: d.state.oscillating ?? false,
            onChanged: d.available
                ? (v) => runDeviceCommand(context, ref, d, SetOscillation(v))
                : null,
          ),
        if (d.supports(Capability.presetMode) &&
            d.limits.presetModes.isNotEmpty)
          _ModeChips(device: d),
      ],
    );
  }
}

/// Humidifier / dehumidifier: target humidity and mode.
class HumidifierControls extends ConsumerWidget {
  const HumidifierControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = device;
    final locale = l10n.localeName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.state.currentHumidity != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${l10n.summaryHumidity}: ${formatNumber(locale, d.state.currentHumidity!, unit: ' %')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        CommandSlider(
          label: l10n.targetHumidityLabel,
          value: d.state.targetHumidity,
          min: d.limits.minHumidity ?? 0,
          max: d.limits.maxHumidity ?? 100,
          divisions:
              ((d.limits.maxHumidity ?? 100) - (d.limits.minHumidity ?? 0))
                  .round()
                  .clamp(1, 100),
          enabled: d.available && d.state.isOn != false,
          format: (v) => '${v.round()} %',
          leading: const Icon(Icons.water_drop_outlined),
          onCommit: (v) =>
              runDeviceCommand(context, ref, d, SetTargetHumidity(v)),
        ),
        if (d.supports(Capability.presetMode) &&
            d.limits.presetModes.isNotEmpty)
          _ModeChips(device: d),
      ],
    );
  }
}

class _ModeChips extends ConsumerWidget {
  const _ModeChips({required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = device;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.modeLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in d.limits.presetModes)
                ChoiceChip(
                  key: ValueKey('mode-$m'),
                  label: Text(DevicePresentation.presetLabel(l10n, m)),
                  selected: d.state.presetMode == m,
                  onSelected: d.available
                      ? (_) =>
                            runDeviceCommand(context, ref, d, SetPresetMode(m))
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Robot vacuum: start, pause, back to the dock.
class VacuumControls extends ConsumerWidget {
  const VacuumControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = device;
    final cleaning = d.state.raw == 'cleaning';
    void run(DeviceCommand c) => runDeviceCommand(context, ref, d, c);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (d.supports(Capability.vacuumStart) && !cleaning)
          FilledButton.icon(
            key: const Key('vacuumStart'),
            onPressed: d.available ? () => run(const VacuumStart()) : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.vacuumStart),
          ),
        if (d.supports(Capability.vacuumPause) && cleaning)
          FilledButton.tonalIcon(
            key: const Key('vacuumPause'),
            onPressed: d.available ? () => run(const VacuumPause()) : null,
            icon: const Icon(Icons.pause),
            label: Text(l10n.vacuumPause),
          ),
        if (d.supports(Capability.vacuumReturnHome) && d.state.raw != 'docked')
          OutlinedButton.icon(
            key: const Key('vacuumReturnHome'),
            onPressed: d.available ? () => run(const VacuumReturnHome()) : null,
            icon: const Icon(Icons.home_outlined),
            label: Text(l10n.vacuumReturnHome),
          ),
      ],
    );
  }
}

/// `select` / `input_select`: one option out of a list.
class SelectControls extends ConsumerWidget {
  const SelectControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = device;
    return RadioGroup<String>(
      groupValue: d.state.textValue,
      onChanged: (v) {
        if (v != null && d.available) {
          runDeviceCommand(context, ref, d, SelectOption(v));
        }
      },
      child: Column(
        children: [
          for (final o in d.limits.options)
            RadioListTile<String>(
              key: ValueKey('option-$o'),
              contentPadding: EdgeInsets.zero,
              value: o,
              title: Text(o),
              enabled: d.available,
            ),
        ],
      ),
    );
  }
}

/// `number` / `input_number`: a slider within the entity's range.
class NumberControls extends ConsumerWidget {
  const NumberControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = device;
    final min = d.limits.minValue ?? 0;
    final max = d.limits.maxValue ?? 100;
    final step = d.limits.valueStep;
    final divisions = step != null && step > 0
        ? ((max - min) / step).round().clamp(1, 1000)
        : null;
    final unit = d.state.unit == null ? null : ' ${d.state.unit}';
    return CommandSlider(
      label: l10n.valueLabel,
      value: d.state.numericValue,
      min: min,
      max: max,
      divisions: divisions,
      enabled: d.available,
      format: (v) => formatNumber(l10n.localeName, v, unit: unit),
      onCommit: (v) => runDeviceCommand(context, ref, d, SetNumber(v)),
    );
  }
}
