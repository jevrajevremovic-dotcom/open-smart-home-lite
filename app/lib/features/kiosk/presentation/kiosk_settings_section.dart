import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../assist/presentation/wake_word_settings.dart';
import '../../clap/clap_settings.dart';
import 'approach_settings.dart';
import '../application/kiosk_controller.dart';
import '../data/kiosk_settings.dart';
import 'camera_popup_settings.dart';
import 'aod_settings.dart';
import '../../extras/celebrations.dart';
import 'kiosk_people_settings.dart';
import 'night_brightness_settings.dart';
import 'pin_dialog.dart';

/// Kiosk options inside the settings screen.
class KioskSettingsSection extends ConsumerWidget {
  const KioskSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(kioskSettingsProvider);
    final controller = ref.read(kioskSettingsProvider.notifier);

    String label(Duration d) => d == Duration.zero
        ? l10n.durationNever
        : d.inSeconds < 60
        ? l10n.durationSeconds(d.inSeconds)
        : l10n.durationMinutes(d.inMinutes);

    Widget durationPicker({
      required Key key,
      required String title,
      required Duration value,
      required List<Duration> options,
      required void Function(Duration) onChanged,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: DropdownButton<Duration>(
        key: key,
        value: options.contains(value) ? value : options.first,
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text(label(o))),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('startKiosk'),
          onPressed: () {
            ref.read(kioskActiveProvider.notifier).enter();
            context.go(AppRoutes.kiosk);
          },
          icon: const Icon(Icons.tablet_outlined),
          label: Text(l10n.kioskStart),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.kioskStartOnLaunch),
          value: settings.startInKiosk,
          onChanged: (v) =>
              controller.update((s) => s.copyWith(startInKiosk: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.kioskKeepAwake),
          value: settings.keepScreenOn,
          onChanged: (v) =>
              controller.update((s) => s.copyWith(keepScreenOn: v)),
        ),
        SwitchListTile(
          key: const Key('kioskShowCameras'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.kioskShowCameras),
          subtitle: Text(l10n.kioskShowCamerasHint),
          value: settings.showCameras,
          onChanged: (v) =>
              controller.update((s) => s.copyWith(showCameras: v)),
        ),
        const CameraPopupSettingsTile(),
        const ClapSettings(),
        const WakeWordSettings(),
        const ApproachSettings(),
        SwitchListTile(
          key: const Key('kioskGreetSwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.waving_hand_outlined),
          title: Text(l10n.greetPeople),
          subtitle: Text(l10n.greetPeopleHint),
          value: settings.greetPeople,
          onChanged: (v) =>
              controller.update((s) => s.copyWith(greetPeople: v)),
        ),
        SwitchListTile(
          key: const Key('kioskAlertSwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.crisis_alert_rounded),
          title: Text(l10n.kioskAlertSetting),
          subtitle: Text(l10n.kioskAlertSettingHint),
          value: settings.alertOverlay,
          onChanged: (v) =>
              controller.update((s) => s.copyWith(alertOverlay: v)),
        ),
        if (settings.alertOverlay)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 40),
            title: Text(l10n.kioskOpenAlert),
            trailing: DropdownButton<int>(
              key: const Key('kioskOpenAlert'),
              value: settings.openAlertMinutes,
              onChanged: (v) => v == null
                  ? null
                  : controller.update((s) => s.copyWith(openAlertMinutes: v)),
              items: [
                for (final m in {
                  0,
                  5,
                  10,
                  15,
                  30,
                  60,
                  settings.openAlertMinutes,
                })
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      m == 0
                          ? l10n.kioskOpenAlertNever
                          : l10n.kioskOpenAlertMinutes(m),
                    ),
                  ),
              ],
            ),
          ),
        durationPicker(
          key: const Key('kioskDimAfter'),
          title: l10n.kioskDimAfter,
          value: settings.dimAfter,
          options: KioskSettings.dimOptions,
          onChanged: (v) => controller.update((s) => s.copyWith(dimAfter: v)),
        ),
        durationPicker(
          key: const Key('kioskReturnAfter'),
          title: l10n.kioskReturnAfter,
          value: settings.returnHomeAfter,
          options: KioskSettings.returnOptions,
          onChanged: (v) =>
              controller.update((s) => s.copyWith(returnHomeAfter: v)),
        ),
        const AodSettings(),
        const NightBrightnessSettings(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            settings.hasPin ? Icons.lock_outline : Icons.lock_open_outlined,
          ),
          title: Text(l10n.kioskPin),
          subtitle: Text(
            settings.hasPin ? l10n.kioskPinSet : l10n.kioskPinNotSet,
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              TextButton(
                key: const Key('kioskSetPin'),
                onPressed: () => showSetPinDialog(context, ref),
                child: Text(
                  settings.hasPin ? l10n.kioskChangePin : l10n.kioskSetPin,
                ),
              ),
              if (settings.hasPin)
                TextButton(
                  onPressed: controller.removePin,
                  child: Text(l10n.kioskRemovePin),
                ),
            ],
          ),
        ),
        SwitchListTile(
          key: const Key('kioskSeasonal'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.ac_unit),
          title: Text(l10n.seasonalSetting),
          subtitle: Text(l10n.seasonalSettingHint),
          value: ref.watch(seasonalProvider),
          onChanged: (v) => ref.read(seasonalProvider.notifier).set(v),
        ),
        const KioskPeopleSettings(),
        const SizedBox(height: 8),
        InlineNotice.info(l10n.kioskOsHint),
      ],
    );
  }
}
