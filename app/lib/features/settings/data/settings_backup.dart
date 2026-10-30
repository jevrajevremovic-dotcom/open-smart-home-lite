import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_locales.dart';
import '../../../core/security/backup_crypto.dart';
import '../../../core/storage/credential_store.dart';
import '../../appliance_done/appliance_done.dart';
import '../../automations/application/routines_controller.dart';
import '../../devices/data/local/local_home.dart';
import '../../extras/sunrise_wake.dart';
import '../../favorites/application/favorites_controller.dart';
import '../../presence_sim/presence_simulation.dart';
import '../../weather/application/weather_providers.dart';
import '../../dashboard/application/dashboard_layout.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../../kiosk/data/kiosk_settings.dart';
import '../../rooms/presentation/room_look.dart';
import '../application/appearance_controllers.dart';

/// How an import went.
enum BackupImport {
  done,

  /// Not an Open Smart Home backup.
  notBackup,

  /// It has secrets; the password is needed for them.
  needsPassword,
  wrongPassword,
}

/// The home and the app's settings as JSON, to keep or to move to another
/// phone or wall panel: the devices added, rooms, names, scenes and
/// automations, the home's programs, the look and the wall panel.
///
/// Device passwords and keys only with a password (then encrypted, see
/// [BackupCrypto]). Never included: PINs, photos, and this device's own
/// choices (microphone, camera, start in kiosk, running in the
/// background) – those are asked again on the new device.
abstract final class SettingsBackup {
  static const _marker = 'open-smart-home-settings';
  static const _version = 2;

  /// The secrets a backup may carry: devices' passwords and keys, the
  /// guest Wi-Fi.
  static List<String> _secretIds(LocalHome home) => [
    for (final d in home.devices)
      if (d.secured) devicePasswordId(d.key),
    'osh.guest_wifi',
  ];

  /// This device's own: never carried to another one.
  static const _deviceOnlyKiosk = {
    'pinHash',
    'pinSalt',
    'startInKiosk',
    'clapEnabled',
    'clapTargetId',
    'clapSensitivity',
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
      'home': ref.read(localHomeProvider).toJson(),
      'routines': ref.read(routinesProvider).toJson(),
      'presence': ref.read(presenceSimProvider).toJson(),
      'sunrise': ref.read(sunriseWakeProvider)?.toJson(),
      'appliances': ref.read(applianceDoneProvider.notifier).toJson(),
      if (ref.read(homeLocationWeatherEnabledProvider) case final at?)
        'homeLocation': {'latitude': at.latitude, 'longitude': at.longitude},
    };
  }

  static String export(WidgetRef ref) =>
      const JsonEncoder.withIndent('  ').convert(exportMap(ref));

  /// With the devices' passwords and keys, encrypted with [password].
  static Future<String> exportWithSecrets(
    WidgetRef ref,
    String password,
  ) async {
    final map = exportMap(ref);
    final store = ref.read(credentialStoreProvider);
    final secrets = <String, String>{
      for (final id in _secretIds(ref.read(localHomeProvider)))
        if (await store.readCredential(id) case final v? when v.isNotEmpty)
          id: v,
    };
    if (secrets.isNotEmpty) {
      map['secrets'] = await BackupCrypto.seal(secrets, password);
    }
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Whether [text] carries secrets (a password is then asked).
  static bool hasSecrets(String text) {
    try {
      final json = jsonDecode(text);
      return json is Map && json['secrets'] is Map;
    } on FormatException {
      return false;
    }
  }

  /// Applies [text]. The home (devices, rooms, scenes, automations)
  /// replaces this one's, or with [replace] `false` only adds what is
  /// missing. Secrets need [password].
  static Future<BackupImport> import(
    WidgetRef ref,
    String text, {
    String? password,
    bool replace = true,
  }) async {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return BackupImport.notBackup;
    }
    if (json is! Map) return BackupImport.notBackup;
    return importMap(ref, json, password: password, replace: replace);
  }

  /// Applies an exported map.
  static Future<BackupImport> importMap(
    WidgetRef ref,
    Map<Object?, Object?> json, {
    String? password,
    bool replace = true,
  }) async {
    if (json['app'] != _marker ||
        (json['version'] != 1 && json['version'] != 2)) {
      return BackupImport.notBackup;
    }
    // Secrets first: a wrong password changes nothing.
    Map<String, String>? secrets;
    if (json['secrets'] case final Map<Object?, Object?> sealed) {
      if (password == null) return BackupImport.needsPassword;
      secrets = await BackupCrypto.open(sealed, password);
      if (secrets == null) return BackupImport.wrongPassword;
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
              // So is the camera; the frame's photos live on this device.
              approachWake: current.approachWake,
              photoFrame: current.photoFrame,
              framePhotos: current.framePhotos,
            ),
          );
    }
    if (json['home'] case final Map<Object?, Object?> home) {
      await ref
          .read(localHomeProvider.notifier)
          .importHome(
            LocalHome.fromJson(home.cast<String, Object?>()),
            replace: replace,
          );
    }
    if (json['routines'] case final Map<Object?, Object?> routines) {
      await ref
          .read(routinesProvider.notifier)
          .importAll(
            Routines.fromJson(routines.cast<String, Object?>()),
            replace: replace,
          );
    }
    if (json['presence'] case final Map<Object?, Object?> sim) {
      await ref
          .read(presenceSimProvider.notifier)
          .save(PresenceSimulation.fromJson(sim.cast<String, Object?>()));
    }
    if (json['sunrise'] case final Map<Object?, Object?> wake) {
      await ref
          .read(sunriseWakeProvider.notifier)
          .save(SunriseWake.fromJson(wake.cast<String, Object?>()));
    }
    if (json['appliances'] case final Map<Object?, Object?> appliances) {
      await ref
          .read(applianceDoneProvider.notifier)
          .importJson(appliances, replace: replace);
    }
    if (json['homeLocation'] case {
      'latitude': final num lat,
      'longitude': final num lon,
    }) {
      await ref.read(homeLocationWeatherEnabledProvider.notifier).set((
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
      ));
    }
    if (secrets != null) {
      final store = ref.read(credentialStoreProvider);
      for (final MapEntry(:key, :value) in secrets.entries) {
        // Only what a backup may carry: a file cannot write anything else
        // into the phone's secure storage.
        if (key.startsWith('device:') || key == 'osh.guest_wifi') {
          await store.writeCredential(key, value);
        }
      }
    }
    return BackupImport.done;
  }
}
