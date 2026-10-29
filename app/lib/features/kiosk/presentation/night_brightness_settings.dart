import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../devices/application/device_providers.dart';
import '../application/kiosk_controller.dart';
import '../data/kiosk_settings.dart';
import '../../../core/widgets/time_picker.dart';

/// Kiosk brightness options: lower at night, minimum on the screensaver.
class NightBrightnessSettings extends ConsumerWidget {
  const NightBrightnessSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lights =
        ref
            .watch(homeSnapshotProvider.select((s) => s.devices))
            .values
            .where((d) => d.kind.isLight)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final l10n = context.l10n;
    final s = ref.watch(kioskSettingsProvider);
    final controller = ref.read(kioskSettingsProvider.notifier);
    String time(int minutes) =>
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

    Future<int?> pick(int current, String help) async {
      final t = await showAppTimePicker(
        context: context,
        helpText: help,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      );
      return t == null ? null : t.hour * 60 + t.minute;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('kioskDarkScreensaver'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.kioskDarkScreensaver),
          subtitle: Text(l10n.kioskDarkScreensaverHint),
          value: s.darkScreensaver,
          onChanged: (v) =>
              controller.update((k) => k.copyWith(darkScreensaver: v)),
        ),
        if (s.darkScreensaver)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            // The label above the slider: both fit a narrow phone.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.aodBrightness),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        key: const Key('aodBrightness'),
                        value: s.aodBrightness,
                        min: 0.05,
                        max: 1,
                        divisions: 19,
                        label: '${(s.aodBrightness * 100).round()} %',
                        onChanged: (v) => controller.update(
                          (k) => k.copyWith(aodBrightness: v),
                        ),
                      ),
                    ),
                    Text('${(s.aodBrightness * 100).round()} %'),
                  ],
                ),
              ],
            ),
          ),
        SwitchListTile(
          key: const Key('kioskNight'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.kioskNight),
          subtitle: Text(
            s.nightBrightness
                ? l10n.kioskNightRange(time(s.nightFrom), time(s.nightTo))
                : l10n.kioskNightHint,
          ),
          value: s.nightBrightness,
          onChanged: (v) =>
              controller.update((k) => k.copyWith(nightBrightness: v)),
        ),
        if (s.nightBrightness) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('kioskNightFrom'),
                  icon: const Icon(Icons.bedtime_outlined),
                  label: Text(l10n.kioskNightFrom(time(s.nightFrom))),
                  onPressed: () async {
                    final m = await pick(s.nightFrom, l10n.kioskNightFromHelp);
                    if (m != null) {
                      await controller.update((k) => k.copyWith(nightFrom: m));
                    }
                  },
                ),
                OutlinedButton.icon(
                  key: const Key('kioskNightTo'),
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text(l10n.kioskNightTo(time(s.nightTo))),
                  onPressed: () async {
                    final m = await pick(s.nightTo, l10n.kioskNightToHelp);
                    if (m != null) {
                      await controller.update((k) => k.copyWith(nightTo: m));
                    }
                  },
                ),
              ],
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.only(left: 16),
            title: Text(l10n.kioskNightLevel((s.nightLevel * 100).round())),
            subtitle: Slider(
              key: const Key('kioskNightLevel'),
              value: s.nightLevel,
              min: 0.02,
              max: 0.6,
              divisions: 29,
              onChanged: (v) =>
                  controller.update((k) => k.copyWith(nightLevel: v)),
            ),
          ),
          SwitchListTile(
            key: const Key('kioskNightClock'),
            contentPadding: const EdgeInsets.only(left: 16),
            title: Text(l10n.kioskNightClock),
            subtitle: Text(l10n.kioskNightClockHint),
            value: s.nightClock,
            onChanged: (v) =>
                controller.update((k) => k.copyWith(nightClock: v)),
          ),
          if (s.nightClock)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32),
              title: Text(l10n.kioskNightLight),
              subtitle: DropdownButton<String>(
                key: const Key('kioskNightLight'),
                isExpanded: true,
                value: lights.any((d) => d.id == s.nightLightId)
                    ? s.nightLightId
                    : '',
                onChanged: (v) => controller.update(
                  (k) => v == null || v.isEmpty
                      ? KioskSettings.fromJson({
                          ...k.toJson(),
                          'nightLightId': null,
                        })
                      : k.copyWith(nightLightId: v),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.kioskNightLightNone),
                  ),
                  for (final d in lights)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
