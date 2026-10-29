import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/smart_home_device.dart';
import '../device_actions.dart';
import 'command_slider.dart';

/// Large on/off switch, used by every device with the `power` capability.
class PowerControl extends ConsumerWidget {
  const PowerControl({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = device.state.isOn ?? false;
    return Card.filled(
      child: SwitchListTile(
        key: const Key('powerSwitch'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          on ? l10n.stateOn : l10n.stateOff,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        secondary: Icon(
          on ? Icons.power_settings_new : Icons.power_off_outlined,
          size: 32,
        ),
        value: on,
        onChanged: device.available
            ? (v) => runDeviceCommand(
                context,
                ref,
                device,
                v ? const TurnOn() : const TurnOff(),
              )
            : null,
      ),
    );
  }
}

class LightControls extends ConsumerWidget {
  const LightControls({super.key, required this.device});

  final SmartHomeDevice device;

  static const _presetColors = [
    RgbColor(255, 255, 255),
    RgbColor(255, 180, 107),
    RgbColor(255, 64, 64),
    RgbColor(255, 160, 0),
    RgbColor(255, 235, 59),
    RgbColor(76, 175, 80),
    RgbColor(0, 188, 212),
    RgbColor(33, 150, 243),
    RgbColor(156, 39, 176),
    RgbColor(233, 30, 99),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = device.state;
    final enabled = device.available;
    Future<void> send(DeviceCommand c) =>
        runDeviceCommand(context, ref, device, c);

    final minK = (device.limits.minColorTemperatureKelvin ?? 2000).toDouble();
    final maxK = (device.limits.maxColorTemperatureKelvin ?? 6500).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (device.supports(Capability.brightness))
          CommandSlider(
            key: const Key('brightnessSlider'),
            label: l10n.brightness,
            value: s.isOn == false ? 0 : s.brightnessPercent?.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            enabled: enabled,
            format: (v) => '${v.round()} %',
            leading: const Icon(Icons.brightness_low),
            trailing: const Icon(Icons.brightness_high),
            onCommit: (v) => send(SetBrightness(v.round())),
          ),
        if (device.supports(Capability.colorTemperature) && maxK > minK) ...[
          const SizedBox(height: 8),
          CommandSlider(
            label: l10n.colorTemperature,
            value: s.colorTemperatureKelvin?.toDouble(),
            min: minK,
            max: maxK,
            enabled: enabled,
            format: (v) => '${v.round()} K',
            leading: Tooltip(
              message: l10n.warm,
              child: const Icon(Icons.wb_incandescent_outlined),
            ),
            trailing: Tooltip(
              message: l10n.cool,
              child: const Icon(Icons.wb_sunny_outlined),
            ),
            onCommit: (v) => send(SetColorTemperature(v.round())),
          ),
        ],
        if (device.supports(Capability.rgb)) ...[
          const SizedBox(height: 12),
          Text(l10n.color, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _presetColors)
                _ColorSwatch(
                  color: c,
                  selected: s.rgb == c,
                  onTap: enabled ? () => send(SetRgbColor(c)) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.selected, this.onTap});

  final RgbColor color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Color.fromARGB(255, color.red, color.green, color.blue);
    final outline = Theme.of(context).colorScheme.outline;
    return Semantics(
      button: true,
      selected: selected,
      label: 'RGB ${color.red}, ${color.green}, ${color.blue}',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.primary : outline,
              width: selected ? 4 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  color: c.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
