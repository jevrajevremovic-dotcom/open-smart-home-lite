import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../devices/application/device_groups.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/controls/more_controls.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_detail_screen.dart'
    show deviceControlsFor;
import '../../devices/presentation/device_presentation.dart';
import 'kiosk_columns.dart' show kioskColumnsDeviceProvider;
import 'thermostat_dial.dart';

/// All of one physical device in the kiosk's right column, in sections:
/// its main control, actions (buttons), settings (switches, modes,
/// numbers) and state (sensors).
class KioskBundleDetail extends ConsumerWidget {
  const KioskBundleDetail({super.key, required this.bundle, this.onOpen});

  final DeviceBundle bundle;

  /// Opens one part (a sensor with its chart); by default it is shown in
  /// the kiosk's right column.
  final void Function(SmartHomeDevice device)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = bundle.primary;
    final main = DeviceBundle.primaryRank(primary) <= 1 ? primary : null;
    final rest = [
      for (final d in bundle.members)
        if (d.id != main?.id) d,
    ];
    final actions = [
      for (final d in rest)
        if (d.kind == DeviceKind.button || d.kind.isRoutine) d,
    ];
    final settings = [
      for (final d in rest)
        if (d.kind == DeviceKind.select ||
            d.kind == DeviceKind.number ||
            d.kind == DeviceKind.switchDevice ||
            d.kind == DeviceKind.outlet)
          d,
    ];
    final state = [
      for (final d in rest)
        if (!actions.contains(d) && !settings.contains(d)) d,
    ];

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );

    final model = [?primary.manufacturer, ?primary.model].join(' · ');
    return Column(
      key: ValueKey('kioskBundle-${bundle.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: bundle.available
                  ? context.deviceAccents
                        .of(DevicePresentation.accent(primary))
                        .icon
                  : scheme.surfaceContainerHighest,
              child: Icon(
                DevicePresentation.icon(primary),
                color: bundle.available
                    ? Colors.white
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bundle.name,
                    key: const Key('kioskColumnsDetailName'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    !bundle.available
                        ? l10n.stateUnavailable
                        : model.isNotEmpty
                        ? model
                        : l10n.kioskBundleCount(bundle.members.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (main != null)
          section(l10n.kioskBundleMain, [
            if (main.kind == DeviceKind.climate ||
                main.kind == DeviceKind.thermostat)
              SizedBox(
                height: 440,
                child: KioskThermostatPanel(deviceId: main.id),
              )
            else
              ...deviceControlsFor(main),
          ]),
        if (actions.isNotEmpty)
          section(l10n.kioskBundleActions, [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in actions)
                  FilledButton.tonalIcon(
                    key: ValueKey('kioskBundleAction-${d.id}'),
                    onPressed: d.available
                        ? () => runDeviceCommand(
                            context,
                            ref,
                            d,
                            const Activate(),
                          )
                        : null,
                    icon: Icon(DevicePresentation.icon(d), size: 18),
                    label: Text(bundle.shortName(d)),
                  ),
              ],
            ),
          ]),
        if (settings.isNotEmpty)
          section(l10n.kioskBundleSettings, [
            for (final d in settings) _SettingRow(bundle: bundle, device: d),
          ]),
        if (state.isNotEmpty)
          section(l10n.kioskBundleState, [
            for (final d in state)
              ListTile(
                key: ValueKey('kioskBundleState-${d.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  DevicePresentation.icon(d),
                  color: scheme.onSurfaceVariant,
                ),
                title: Text(bundle.shortName(d)),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    DevicePresentation.status(l10n, d),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Shown on its own, with its chart.
                onTap: () => onOpen != null
                    ? onOpen!(d)
                    : ref
                          .read(kioskColumnsDeviceProvider.notifier)
                          .select(d.id),
              ),
          ]),
      ],
    );
  }
}

/// A switch, a choice or a number of the device, in one compact row.
class _SettingRow extends ConsumerWidget {
  const _SettingRow({required this.bundle, required this.device});

  final DeviceBundle bundle;
  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = device;
    final name = bundle.shortName(d);
    final key = ValueKey('kioskBundleSetting-${d.id}');
    switch (d.kind) {
      case DeviceKind.select:
        final value = d.limits.options.contains(d.state.textValue)
            ? d.state.textValue
            : null;
        return ListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(name),
          trailing: DropdownButton<String>(
            value: value,
            onChanged: d.available
                ? (v) => v == null
                      ? null
                      : runDeviceCommand(context, ref, d, SelectOption(v))
                : null,
            items: [
              for (final o in d.limits.options)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
          ),
        );
      case DeviceKind.number:
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
            ),
            NumberControls(device: d),
          ],
        );
      default:
        return SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(name),
          value: d.state.isOn == true,
          onChanged: d.available
              ? (v) => runDeviceCommand(
                  context,
                  ref,
                  d,
                  v ? const TurnOn() : const TurnOff(),
                )
              : null,
        );
    }
  }
}
