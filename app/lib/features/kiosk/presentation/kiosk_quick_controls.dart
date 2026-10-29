import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../devices/application/device_groups.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/controls/command_slider.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../restricted/application/restricted_mode.dart';
import '../application/kiosk_controller.dart';
import '../application/kiosk_people.dart';
import 'kiosk_motion.dart';

/// Every physical device of the home (entities grouped), sorted by name;
/// what the quick controls are chosen from.
final homeBundlesProvider = Provider<List<DeviceBundle>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final visible = ref.watch(visibleDeviceIdsProvider).toSet();
  final restricted = ref.watch(restrictedModeProvider);
  return groupDevices([
    for (final d in devices.values)
      // Devices as everywhere, plus scenes and scripts (not automations).
      if ((visible.contains(d.id) ||
              ((d.kind == DeviceKind.scene || d.kind == DeviceKind.script) &&
                  !d.isAuxiliary &&
                  !restricted.hides(d))) &&
          d.kind != DeviceKind.camera)
        d,
  ])..sort((a, b) => a.name.compareTo(b.name));
});

/// The devices chosen for the home overview's right column, each as a
/// compact control: switch, brightness, and a device's actions as chips.
class KioskQuickControls extends ConsumerWidget {
  const KioskQuickControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Whoever is at the panel may have their own.
    final keys = ref.watch(kioskQuickControlsProvider);
    final user = ref.watch(kioskUserProvider);
    final userName = user == null
        ? null
        : ref.watch(deviceProvider(user).select((d) => d?.name));
    final bundles = {for (final b in ref.watch(homeBundlesProvider)) b.key: b};
    final chosen = [for (final k in keys) ?bundles[k]];
    return Column(
      key: const Key('kioskQuickControls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                userName == null
                    ? l10n.kioskQuickControls
                    : l10n.kioskQuickControlsFor(userName),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('kioskQuickControlsEdit'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _QuickControlsPicker(),
              ),
              icon: Icon(chosen.isEmpty ? Icons.add : Icons.edit_outlined),
              label: Text(
                chosen.isEmpty
                    ? l10n.kioskQuickControlsAdd
                    : l10n.kioskQuickControlsEdit,
              ),
            ),
          ],
        ),
        if (chosen.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              l10n.kioskQuickControlsHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final b in chosen) ...[
          const SizedBox(height: 10),
          _QuickControl(bundle: b),
        ],
      ],
    );
  }
}

class _QuickControl extends ConsumerWidget {
  const _QuickControl({required this.bundle});

  final DeviceBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = bundle.primary;
    final on = DevicePresentation.tone(d) == DeviceTone.active;
    final toggle = DevicePresentation.hasQuickToggle(d) && d.available;
    final accent = DevicePresentation.swatch(context.deviceAccents, d);
    final actions = [
      for (final m in bundle.members)
        if (m.id != d.id && (m.kind == DeviceKind.button || m.kind.isRoutine))
          m,
    ];
    final dimmable =
        d.kind.isLight &&
        d.supports(Capability.brightness) &&
        d.state.isOn == true;
    Future<void> run(SmartHomeDevice x, DeviceCommand c) =>
        runDeviceCommand(context, ref, x, c);
    return Material(
      key: ValueKey('kioskQuick-${bundle.key}'),
      color: on ? accent.container : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: on ? Colors.transparent : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Material(
                  color: on ? accent.icon : scheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: toggle
                        ? () => run(
                            d,
                            d.state.isOn == true
                                ? const TurnOff()
                                : const TurnOn(),
                          )
                        : d.kind.isRoutine || d.kind == DeviceKind.button
                        ? () => run(d, const Activate())
                        : null,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: LiveDeviceIcon(
                          device: d,
                          color: on ? Colors.white : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bundle.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: on ? accent.onContainer : null,
                        ),
                      ),
                      Text(
                        bundle.available
                            ? DevicePresentation.status(l10n, d)
                            : l10n.stateUnavailable,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: on
                              ? accent.onContainer.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!toggle &&
                    d.available &&
                    (d.kind.isRoutine || d.kind == DeviceKind.button))
                  IconButton.filledTonal(
                    key: ValueKey('kioskQuickRun-${d.id}'),
                    tooltip: l10n.svc_activate,
                    onPressed: () => run(d, const Activate()),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                if (toggle)
                  Switch(
                    key: ValueKey('kioskQuickSwitch-${d.id}'),
                    value: d.state.isOn == true,
                    onChanged: (v) =>
                        run(d, v ? const TurnOn() : const TurnOff()),
                  ),
              ],
            ),
            if (dimmable)
              CommandSlider(
                label: l10n.brightness,
                value: d.state.brightnessPercent?.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                format: (v) => '${v.round()} %',
                onCommit: (v) => run(d, SetBrightness(v.round())),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in actions)
                    ActionChip(
                      key: ValueKey('kioskQuickAction-${a.id}'),
                      avatar: Icon(DevicePresentation.icon(a), size: 16),
                      label: Text(bundle.shortName(a)),
                      onPressed: a.available
                          ? () => run(a, const Activate())
                          : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chooses (and orders, by the order of choosing) the quick controls.
class _QuickControlsPicker extends ConsumerStatefulWidget {
  const _QuickControlsPicker();

  @override
  ConsumerState<_QuickControlsPicker> createState() =>
      _QuickControlsPickerState();
}

class _QuickControlsPickerState extends ConsumerState<_QuickControlsPicker> {
  late final String? _user = ref.read(kioskUserProvider);
  late final List<String> _chosen = [...ref.read(kioskQuickControlsProvider)];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final bundles = [
      for (final b in ref.watch(homeBundlesProvider))
        if (q.isEmpty || b.name.toLowerCase().contains(q)) b,
    ];
    final userName = _user == null
        ? null
        : ref.watch(deviceProvider(_user).select((d) => d?.name));
    final ownList =
        _user != null &&
        ref.watch(
          kioskPeopleProvider.select((m) => m[_user]?.quickControls != null),
        );
    return AlertDialog(
      title: Text(
        userName == null
            ? l10n.kioskQuickControls
            : l10n.kioskQuickControlsFor(userName),
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 480,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                key: const Key('kioskQuickSearch'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.clapSearch,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final b in bundles)
                    CheckboxListTile(
                      key: ValueKey('kioskQuickPick-${b.key}'),
                      secondary: Icon(DevicePresentation.icon(b.primary)),
                      title: Text(b.name),
                      subtitle: b.isGroup
                          ? Text(l10n.kioskBundleCount(b.members.length))
                          : null,
                      value: _chosen.contains(b.key),
                      onChanged: (v) => setState(
                        () => v == true
                            ? _chosen.add(b.key)
                            : _chosen.remove(b.key),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (ownList)
          TextButton(
            key: const Key('kioskQuickShared'),
            onPressed: () {
              final navigator = Navigator.of(context);
              ref
                  .read(kioskPeopleProvider.notifier)
                  .setQuickControls(_user, null);
              navigator.pop();
            },
            child: Text(l10n.kioskQuickControlsShared),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('kioskQuickSave'),
          onPressed: () {
            final navigator = Navigator.of(context);
            final user = _user;
            if (user != null) {
              ref.read(kioskPeopleProvider.notifier).setQuickControls(user, [
                ..._chosen,
              ]);
            } else {
              ref
                  .read(kioskSettingsProvider.notifier)
                  .update((s) => s.copyWith(quickControls: [..._chosen]));
            }
            navigator.pop();
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
