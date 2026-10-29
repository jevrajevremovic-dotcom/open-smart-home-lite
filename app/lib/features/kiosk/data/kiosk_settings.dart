import 'package:flutter/foundation.dart';

import '../../clap/clap_detector.dart';

/// The one extra thing the always-on screen shows under the clock.
enum AodFocus { none, nextEvent, list, device, energy, media, home }

/// Cards of the kiosk's home overview.
enum HomeCard { cameras, weather, media, calendar, lists, floorPlan }

/// What wakes the idle kiosk screen besides a touch.
enum ApproachWake { off, sensor, camera }

/// Wall-panel options, stored locally (non-secret; the PIN only as a
/// salted PBKDF2 hash).
@immutable
class KioskSettings {
  const KioskSettings({
    this.startInKiosk = false,
    this.keepScreenOn = true,
    this.dimAfter = const Duration(minutes: 2),
    this.returnHomeAfter = const Duration(seconds: 60),
    this.pinHash,
    this.pinSalt,
    this.showCameras = true,
    this.clapEnabled = false,
    this.clapTargetId,
    this.clapSensitivity = ClapSensitivity.medium,
    this.wakeWordEnabled = false,
    this.approachWake = ApproachWake.off,
    this.approachSensorId,
    this.alertOverlay = true,
    this.greetPeople = true,
    this.quickControls = const [],
    this.homeCards = HomeCard.values,
    this.openAlertMinutes = 10,
    this.popupTriggerIds = const [],
    this.popupCameraId,
    this.popupSeconds = 60,
    this.popupLive = true,
    this.popupOpenId,
    this.popupSpeakerId,
    this.aodFocus = AodFocus.nextEvent,
    this.aodEntityId,
    this.morningScreen = true,
    this.morningFrom = 6 * 60,
    this.morningTo = 10 * 60,
    this.nightBrightness = false,
    this.nightFrom = 22 * 60,
    this.nightTo = 7 * 60,
    this.nightLevel = 0.15,
    this.nightClock = false,
    this.photoFrame = false,
    this.framePhotos = const [],
    this.frameSeconds = 30,
    this.nightLightId,
    this.darkScreensaver = true,
    this.aodBrightness = 0.4,
  });

  factory KioskSettings.fromJson(Map<String, Object?>? json) {
    if (json == null) return const KioskSettings();
    Duration? seconds(Object? v) =>
        v is int ? (v <= 0 ? Duration.zero : Duration(seconds: v)) : null;
    const d = KioskSettings();
    return KioskSettings(
      startInKiosk: json['startInKiosk'] == true,
      keepScreenOn: json['keepScreenOn'] != false,
      dimAfter: seconds(json['dimAfterSeconds']) ?? d.dimAfter,
      returnHomeAfter:
          seconds(json['returnHomeAfterSeconds']) ?? d.returnHomeAfter,
      pinHash: json['pinHash'] is String ? json['pinHash']! as String : null,
      pinSalt: json['pinSalt'] is String ? json['pinSalt']! as String : null,
      showCameras: json['showCameras'] != false,
      clapEnabled: json['clapEnabled'] == true,
      clapTargetId: json['clapTargetId'] is String
          ? json['clapTargetId']! as String
          : null,
      wakeWordEnabled: json['wakeWordEnabled'] == true,
      approachWake: ApproachWake.values.firstWhere(
        (a) => a.name == json['approachWake'],
        orElse: () => d.approachWake,
      ),
      alertOverlay: json['alertOverlay'] != false,
      greetPeople: json['greetPeople'] != false,
      homeCards: switch (json['homeCards']) {
        final List<Object?> list => [
          for (final name in list)
            ?HomeCard.values.where((c) => c.name == name).firstOrNull,
        ],
        _ => d.homeCards,
      },
      quickControls: [
        if (json['quickControls'] case final List<Object?> list)
          for (final k in list.take(24))
            if (k is String) k,
      ],
      openAlertMinutes: json['openAlertMinutes'] is int
          ? json['openAlertMinutes']! as int
          : d.openAlertMinutes,
      approachSensorId: json['approachSensorId'] is String
          ? json['approachSensorId']! as String
          : null,
      clapSensitivity: ClapSensitivity.values.firstWhere(
        (s) => s.name == json['clapSensitivity'],
        orElse: () => d.clapSensitivity,
      ),
      aodFocus: AodFocus.values.firstWhere(
        (f) => f.name == json['aodFocus'],
        orElse: () => d.aodFocus,
      ),
      aodEntityId: json['aodEntityId'] is String
          ? json['aodEntityId']! as String
          : null,
      morningScreen: json['morningScreen'] != false,
      morningFrom: _minutes(json['morningFrom']) ?? d.morningFrom,
      morningTo: _minutes(json['morningTo']) ?? d.morningTo,
      nightBrightness: json['nightBrightness'] == true,
      nightClock: json['nightClock'] == true,
      photoFrame: json['photoFrame'] == true,
      framePhotos: [
        if (json['framePhotos'] case final List<Object?> list)
          for (final p in list.take(maxFramePhotos))
            if (p is String) p,
      ],
      frameSeconds: switch (json['frameSeconds']) {
        final int v when v >= 5 && v <= 600 => v,
        _ => d.frameSeconds,
      },
      nightLightId: json['nightLightId'] is String
          ? json['nightLightId']! as String
          : null,
      nightFrom: _minutes(json['nightFrom']) ?? d.nightFrom,
      nightTo: _minutes(json['nightTo']) ?? d.nightTo,
      nightLevel: switch (json['nightLevel']) {
        final num v => v.toDouble().clamp(0.02, 1.0),
        _ => d.nightLevel,
      },
      darkScreensaver: json['darkScreensaver'] != false,
      aodBrightness: switch (json['aodBrightness']) {
        final num v when v >= 0.05 && v <= 1 => v.toDouble(),
        _ => d.aodBrightness,
      },
      popupTriggerIds: [
        if (json['popupTriggerIds'] case final List<Object?> ids)
          for (final id in ids.whereType<String>().take(10)) id,
      ],
      popupCameraId: json['popupCameraId'] is String
          ? json['popupCameraId']! as String
          : null,
      popupLive: json['popupLive'] != false,
      popupOpenId: json['popupOpenId'] is String
          ? json['popupOpenId']! as String
          : null,
      popupSpeakerId: json['popupSpeakerId'] is String
          ? json['popupSpeakerId']! as String
          : null,
      popupSeconds: switch (json['popupSeconds']) {
        final int s when popupOptions.contains(s) => s,
        _ => d.popupSeconds,
      },
    );
  }

  final bool startInKiosk;
  final bool keepScreenOn;

  /// `Duration.zero` = never.
  final Duration dimAfter;

  /// `Duration.zero` = never.
  final Duration returnHomeAfter;
  final String? pinHash;
  final String? pinSalt;

  /// Cameras on the kiosk's home overview (visible to anyone in the room).
  final bool showCameras;

  /// Double clap toggles [clapTargetId] while the kiosk is shown. Opt-in:
  /// the microphone listens (levels only, nothing recorded) meanwhile.
  final bool clapEnabled;
  final String? clapTargetId;
  final ClapSensitivity clapSensitivity;

  /// Hands-free Assist: while the kiosk is shown, microphone audio streams
  /// to the user's own Home Assistant, whose wake word engine (openWakeWord)
  /// listens for the wake word. Opt-in.
  final bool wakeWordEnabled;

  /// Wakes the idle screen when someone comes near: a motion sensor in
  /// Home Assistant ([approachSensorId]) or the tablet's front camera
  /// (movement found on the tablet, nothing recorded or sent).
  final ApproachWake approachWake;
  final String? approachSensorId;

  /// Critical alerts (smoke, CO, leak, alarm triggered, jammed lock) cover
  /// the whole kiosk screen until acknowledged.
  final bool alertOverlay;

  /// Says hello (and shows their messages) when a person comes home.
  final bool greetPeople;

  /// Devices on the right of the home overview: entity ids, or
  /// `group:<device id>` for all of one physical device.
  final List<String> quickControls;

  /// Shown on the home overview, in this order (others are hidden).
  final List<HomeCard> homeCards;

  /// A door or window open longer than this also covers the screen (0 =
  /// never).
  final int openAlertMinutes;

  /// A doorbell, motion or contact sensor that wakes the screen and shows
  /// [popupCameraId] full screen for [popupSeconds].
  final List<String> popupTriggerIds;
  final String? popupCameraId;
  final int popupSeconds;

  /// Live video in the pop-up when the camera offers it (else snapshots).
  final bool popupLive;

  /// Intercom on the pop-up: "Open" works this lock, gate or garage door
  /// (critical, so it asks for confirmation) …
  final String? popupOpenId;

  /// … and "Coming" says a short reply through this speaker by the door
  /// (Home Assistant's `tts.speak`).
  final String? popupSpeakerId;
  static const popupOptions = [30, 60, 120, 300];

  bool get hasPopup => popupCameraId != null && popupTriggerIds.isNotEmpty;

  /// Under the clock of the always-on screen.
  final AodFocus aodFocus;

  /// The list or device for [AodFocus.list] / [AodFocus.device].
  final String? aodEntityId;

  /// Between [morningFrom] and [morningTo] (minutes after midnight) the
  /// always-on screen becomes a morning overview.
  final bool morningScreen;
  final int morningFrom;
  final int morningTo;

  bool isMorning(DateTime now) {
    if (!morningScreen) return false;
    final m = now.hour * 60 + now.minute;
    return morningFrom <= morningTo
        ? m >= morningFrom && m < morningTo
        : m >= morningFrom || m < morningTo;
  }

  /// Lower screen brightness between [nightFrom] and [nightTo] (minutes
  /// after midnight; the window may cross midnight).
  final bool nightBrightness;
  final int nightFrom;
  final int nightTo;

  /// 0…1 of full brightness at night.
  final double nightLevel;

  /// At night the idle screen is only a dim red clock (easy on the eyes).
  final bool nightClock;

  /// The idle screen shows [framePhotos] (kept on this tablet only), one
  /// after another every [frameSeconds], with a small clock.
  final bool photoFrame;
  final List<String> framePhotos;
  final int frameSeconds;
  static const maxFramePhotos = 60;

  /// At night the first tap on the idle screen turns this light on at 10 %
  /// instead of waking the screen (a night light for the hallway).
  final String? nightLightId;

  /// The screensaver also turns the backlight down to its minimum.
  final bool darkScreensaver;

  /// Screen brightness of the always-on screen (with [darkScreensaver]),
  /// 0.05–1. At night the lower of this and [nightLevel] applies.
  final double aodBrightness;

  static int? _minutes(Object? v) =>
      v is int && v >= 0 && v < 24 * 60 ? v : null;

  bool isNight(DateTime now) {
    final m = now.hour * 60 + now.minute;
    return nightFrom <= nightTo
        ? m >= nightFrom && m < nightTo
        : m >= nightFrom || m < nightTo;
  }

  /// Brightness the kiosk asks for; `null` = leave it to the system.
  double? brightnessAt(DateTime now, {required bool dimmed}) {
    if (dimmed && darkScreensaver) {
      return nightBrightness && isNight(now) && nightLevel < aodBrightness
          ? nightLevel
          : aodBrightness;
    }
    if (nightBrightness && isNight(now)) return nightLevel;
    return null;
  }

  bool get hasPin => pinHash != null && pinSalt != null;

  /// Choices offered in settings.
  static const dimOptions = [
    Duration.zero,
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];
  static const returnOptions = [
    Duration.zero,
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  KioskSettings copyWith({
    bool? startInKiosk,
    bool? keepScreenOn,
    Duration? dimAfter,
    Duration? returnHomeAfter,
    String? pinHash,
    String? pinSalt,
    bool clearPin = false,
    bool? showCameras,
    bool? clapEnabled,
    String? clapTargetId,
    ClapSensitivity? clapSensitivity,
    bool? wakeWordEnabled,
    ApproachWake? approachWake,
    String? approachSensorId,
    bool? alertOverlay,
    bool? greetPeople,
    List<String>? quickControls,
    List<HomeCard>? homeCards,
    int? openAlertMinutes,
    List<String>? popupTriggerIds,
    String? popupCameraId,
    bool clearPopupCamera = false,
    int? popupSeconds,
    bool? popupLive,
    String? popupOpenId,
    String? popupSpeakerId,
    bool clearPopupOpen = false,
    bool clearPopupSpeaker = false,
    AodFocus? aodFocus,
    String? aodEntityId,
    bool clearAodEntity = false,
    bool? morningScreen,
    int? morningFrom,
    int? morningTo,
    bool? nightBrightness,
    int? nightFrom,
    int? nightTo,
    double? nightLevel,
    bool? nightClock,
    bool? photoFrame,
    List<String>? framePhotos,
    int? frameSeconds,
    String? nightLightId,
    bool? darkScreensaver,
    double? aodBrightness,
  }) => KioskSettings(
    aodFocus: aodFocus ?? this.aodFocus,
    aodEntityId: clearAodEntity ? null : (aodEntityId ?? this.aodEntityId),
    morningScreen: morningScreen ?? this.morningScreen,
    morningFrom: morningFrom ?? this.morningFrom,
    morningTo: morningTo ?? this.morningTo,
    nightBrightness: nightBrightness ?? this.nightBrightness,
    nightFrom: nightFrom ?? this.nightFrom,
    nightTo: nightTo ?? this.nightTo,
    nightLevel: nightLevel ?? this.nightLevel,
    nightClock: nightClock ?? this.nightClock,
    photoFrame: photoFrame ?? this.photoFrame,
    framePhotos: framePhotos ?? this.framePhotos,
    frameSeconds: frameSeconds ?? this.frameSeconds,
    nightLightId: nightLightId ?? this.nightLightId,
    darkScreensaver: darkScreensaver ?? this.darkScreensaver,
    aodBrightness: aodBrightness ?? this.aodBrightness,
    popupTriggerIds: popupTriggerIds ?? this.popupTriggerIds,
    popupCameraId: clearPopupCamera
        ? null
        : (popupCameraId ?? this.popupCameraId),
    popupSeconds: popupSeconds ?? this.popupSeconds,
    popupLive: popupLive ?? this.popupLive,
    popupOpenId: clearPopupOpen ? null : (popupOpenId ?? this.popupOpenId),
    popupSpeakerId: clearPopupSpeaker
        ? null
        : (popupSpeakerId ?? this.popupSpeakerId),
    clapEnabled: clapEnabled ?? this.clapEnabled,
    clapTargetId: clapTargetId ?? this.clapTargetId,
    clapSensitivity: clapSensitivity ?? this.clapSensitivity,
    wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
    approachWake: approachWake ?? this.approachWake,
    approachSensorId: approachSensorId ?? this.approachSensorId,
    alertOverlay: alertOverlay ?? this.alertOverlay,
    greetPeople: greetPeople ?? this.greetPeople,
    quickControls: quickControls ?? this.quickControls,
    homeCards: homeCards ?? this.homeCards,
    openAlertMinutes: openAlertMinutes ?? this.openAlertMinutes,
    showCameras: showCameras ?? this.showCameras,
    startInKiosk: startInKiosk ?? this.startInKiosk,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    dimAfter: dimAfter ?? this.dimAfter,
    returnHomeAfter: returnHomeAfter ?? this.returnHomeAfter,
    pinHash: clearPin ? null : (pinHash ?? this.pinHash),
    pinSalt: clearPin ? null : (pinSalt ?? this.pinSalt),
  );

  Map<String, Object?> toJson() => {
    'startInKiosk': startInKiosk,
    'keepScreenOn': keepScreenOn,
    'dimAfterSeconds': dimAfter.inSeconds,
    'returnHomeAfterSeconds': returnHomeAfter.inSeconds,
    'pinHash': pinHash,
    'pinSalt': pinSalt,
    'showCameras': showCameras,
    'clapEnabled': clapEnabled,
    'clapTargetId': clapTargetId,
    'clapSensitivity': clapSensitivity.name,
    'wakeWordEnabled': wakeWordEnabled,
    'approachWake': approachWake.name,
    'approachSensorId': approachSensorId,
    'alertOverlay': alertOverlay,
    'greetPeople': greetPeople,
    'quickControls': quickControls,
    'homeCards': [for (final c in homeCards) c.name],
    'openAlertMinutes': openAlertMinutes,
    'popupTriggerIds': popupTriggerIds,
    'popupCameraId': popupCameraId,
    'popupSeconds': popupSeconds,
    'popupLive': popupLive,
    'popupOpenId': popupOpenId,
    'popupSpeakerId': popupSpeakerId,
    'aodFocus': aodFocus.name,
    'aodEntityId': aodEntityId,
    'morningScreen': morningScreen,
    'morningFrom': morningFrom,
    'morningTo': morningTo,
    'nightBrightness': nightBrightness,
    'nightFrom': nightFrom,
    'nightTo': nightTo,
    'nightLevel': nightLevel,
    'nightClock': nightClock,
    'photoFrame': photoFrame,
    'framePhotos': framePhotos,
    'frameSeconds': frameSeconds,
    'nightLightId': nightLightId,
    'darkScreensaver': darkScreensaver,
    'aodBrightness': aodBrightness,
  };
}
