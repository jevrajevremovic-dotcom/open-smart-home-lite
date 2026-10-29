import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_locales.dart';
import '../../favorites/application/favorites_controller.dart';
import '../../dashboard/application/dashboard_layout.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../../kiosk/data/kiosk_settings.dart';
import '../../rooms/presentation/room_look.dart';
import '../application/appearance_controllers.dart';

/// App settings as a small JSON text to move to another device.
///
/// Never included: tokens and server credentials, PINs, photos, and this
/// device's own choices (microphone, camera, start in kiosk, location) –
/// those are asked again on the new device.
abstract final class SettingsBackup {
  static const _marker = 'open-smart-home-settings';
  static const _version = 1;

  /// This device's own: never carried to another one.
  static const _deviceOnlyKiosk = {
    'pinHash',
    'pinSalt',
    'startInKiosk',
    'clapEnabled',
    'clapTargetId',
    'clapSensitivity',
    'wakeWordEnabled',
    'approachWake',
    'approachSensorId',
    'photoFrame',
    'framePhotos',
  };

  static Map<String, Object?> exportMap(WidgetRef ref) {
    final locale = ref.read(localeProvider);
    return {
      'app': _marker,
      'version': _version,
      'theme': ref.read(themeModeProvider).name,
      'autoDark': ref.read(autoDarkProvider),
      'oled': ref.read(oledProvider),
      'accent': ref.read(accentProvider).name,
      'language': locale == null ? null : AppLocales.toTag(locale),
      'favorites': ref.read(favoritesProvider),
      'homeLayout': ref.read(dashboardLayoutProvider).toJson(),
      'roomLooks': {
        for (final e in ref.read(roomLooksProvider).entries)
          e.key: e.value.toJson(),
      },
      'kiosk': {
        for (final e in ref.read(kioskSettingsProvider).toJson().entries)
          if (!_deviceOnlyKiosk.contains(e.key)) e.key: e.value,
      },
    };
  }

  static String export(WidgetRef ref) =>
      const JsonEncoder.withIndent('  ').convert(exportMap(ref));

  /// Applies [text]; `false` when it is not an Open Smart Home backup.
  static Future<bool> import(WidgetRef ref, String text) async {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return false;
    }
    return json is Map ? importMap(ref, json) : false;
  }

  /// Applies an exported map; `false` when it is not one.
  static Future<bool> importMap(
    WidgetRef ref,
    Map<Object?, Object?> json,
  ) async {
    if (json['app'] != _marker || json['version'] != 1) {
      return false;
    }
    if (json['oled'] case final bool on) {
      await ref.read(oledProvider.notifier).set(on);
    }
    if (json['autoDark'] case final bool on) {
      await ref.read(autoDarkProvider.notifier).set(on);
    }
    if (AppAccent.values.where((a) => a.name == json['accent']).firstOrNull
        case final accent?) {
      await ref.read(accentProvider.notifier).set(accent);
    }
    if (json['roomLooks'] case final Map<Object?, Object?> looks) {
      final controller = ref.read(roomLooksProvider.notifier);
      for (final e in looks.entries) {
        if (e.key is! String) continue;
        final look = RoomLook.fromJson(e.value);
        await controller.setIcon(e.key! as String, look.icon);
        await controller.setColor(e.key! as String, look.color);
      }
    }
    final themeName = json['theme'];
    final theme = ThemeMode.values
        .where((m) => m.name == themeName)
        .firstOrNull;
    if (theme != null) await ref.read(themeModeProvider.notifier).set(theme);
    if (json['language'] case final String tag) {
      await ref.read(localeProvider.notifier).set(AppLocales.fromTag(tag));
    }
    if (json['homeLayout'] case final Map<Object?, Object?> raw) {
      final layout = raw.cast<String, Object?>();
      final parsed = DashboardLayout.fromJson(layout);
      final controller = ref.read(dashboardLayoutProvider.notifier);
      await controller.reset();
      for (final (i, card) in parsed.order.indexed) {
        final from = ref.read(dashboardLayoutProvider).order.indexOf(card);
        if (from != i) await controller.move(from, i);
      }
      for (final card in parsed.hidden) {
        await controller.setVisible(card, false);
      }
    }
    if (json['favorites'] case final List<Object?> favorites) {
      await ref.read(favoritesProvider.notifier).setOrder([
        for (final f in favorites)
          if (f is String) f,
      ]);
    }
    if (json['kiosk'] case final Map<Object?, Object?> raw) {
      final k = raw.cast<String, Object?>();
      final current = ref.read(kioskSettingsProvider);
      final imported = KioskSettings.fromJson(k);
      await ref
          .read(kioskSettingsProvider.notifier)
          .update(
            (_) => imported.copyWith(
              // Keep this device's own PIN and start-up choice.
              pinHash: current.pinHash,
              pinSalt: current.pinSalt,
              startInKiosk: current.startInKiosk,
              // Microphone use is this device's own choice.
              clapEnabled: current.clapEnabled,
              clapTargetId: current.clapTargetId,
              clapSensitivity: current.clapSensitivity,
              wakeWordEnabled: current.wakeWordEnabled,
              // So is the camera; the frame's photos live on this device.
              approachWake: current.approachWake,
              photoFrame: current.photoFrame,
              framePhotos: current.framePhotos,
            ),
          );
    }
    return true;
  }
}
