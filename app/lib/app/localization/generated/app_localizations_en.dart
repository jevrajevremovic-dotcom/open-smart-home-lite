// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Open Smart Home Lite';

  @override
  String get mockModeBanner => 'MOCK MODE — demo data, no real devices';

  @override
  String get languageSystem => 'System';

  @override
  String get languageSerbian => 'Srpski';

  @override
  String get languageEnglish => 'English';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get connect => 'Connect';

  @override
  String get connecting => 'Connecting…';

  @override
  String get failureNetwork =>
      'The device cannot be reached. Check that it is on and that the phone is on the same Wi-Fi.';

  @override
  String get failureTimeout => 'The device took too long to answer.';

  @override
  String get failureAuthentication =>
      'The device refused the password, key or token. Check it in Settings → Home.';

  @override
  String get failureAuthorization =>
      'This user is not allowed to perform this action.';

  @override
  String get failureValidation => 'The device did not accept the command.';

  @override
  String get failureParsing => 'The device sent an unexpected answer.';

  @override
  String get failureServer => 'The device reported an error.';

  @override
  String get failureCertificate =>
      'The device presented a different certificate than when it was paired. Someone else may be answering in its place; if you reset the device, remove it and add it again.';

  @override
  String get failureUnavailableEntity =>
      'This device is currently unavailable.';

  @override
  String get failureUnsupportedFeature =>
      'This device does not support this action.';

  @override
  String get failureWebSocket => 'The live connection was interrupted.';

  @override
  String get failureStorage =>
      'Secure storage on this device could not be accessed.';

  @override
  String get failureUnknown => 'Something went wrong. Please try again.';

  @override
  String get navHome => 'Home';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get deleteAllData => 'Delete all local data';

  @override
  String get deleteAllConfirmTitle => 'Delete all local data?';

  @override
  String get deleteAllConfirmBody =>
      'This removes the home, the devices\' passwords and keys, and all settings from this phone. The devices themselves are not changed.';

  @override
  String get delete => 'Delete';

  @override
  String get privacySection => 'Privacy & data';

  @override
  String get failureConfirmationRequired => 'Please confirm this action.';

  @override
  String devicesInRooms(int devices, int rooms) {
    String _temp0 = intl.Intl.pluralLogic(
      devices,
      locale: localeName,
      other: '$devices devices',
      one: '1 device',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rooms,
      locale: localeName,
      other: '$rooms rooms',
      one: '1 room',
      zero: 'no rooms',
    );
    return '$_temp0 in $_temp1';
  }

  @override
  String dataStaleSince(String time) {
    return 'Not connected — showing data last updated $time. It may not be current.';
  }

  @override
  String get navRooms => 'Rooms';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navScenes => 'Scenes';

  @override
  String get stateOn => 'On';

  @override
  String get stateOff => 'Off';

  @override
  String get stateUnavailable => 'Unavailable';

  @override
  String get stateUnknown => 'Unknown';

  @override
  String stateOnBrightness(int percent) {
    return 'On · $percent %';
  }

  @override
  String get motionDetected => 'Motion detected';

  @override
  String get motionClear => 'No motion';

  @override
  String get occupancyDetected => 'Occupied';

  @override
  String get occupancyClear => 'Clear';

  @override
  String get contactOpen => 'Open';

  @override
  String get contactClosed => 'Closed';

  @override
  String get smokeDetected => 'Smoke detected!';

  @override
  String get smokeClear => 'No smoke';

  @override
  String get coDetected => 'CO detected!';

  @override
  String get coClear => 'No CO';

  @override
  String get leakDetected => 'Water leak!';

  @override
  String get leakClear => 'Dry';

  @override
  String get vibrationDetected => 'Vibration';

  @override
  String get vibrationClear => 'Still';

  @override
  String get binaryActive => 'Active';

  @override
  String get binaryInactive => 'Inactive';

  @override
  String get coverOpening => 'Opening…';

  @override
  String get coverClosing => 'Closing…';

  @override
  String coverOpenPercent(int percent) {
    return 'Open $percent %';
  }

  @override
  String get lockLocked => 'Locked';

  @override
  String get lockUnlocked => 'Unlocked';

  @override
  String get lockLocking => 'Locking…';

  @override
  String get lockUnlocking => 'Unlocking…';

  @override
  String get lockJammed => 'Jammed!';

  @override
  String get alarmDisarmed => 'Disarmed';

  @override
  String get alarmArmed => 'Armed';

  @override
  String get alarmArming => 'Arming…';

  @override
  String get alarmPending => 'Pending…';

  @override
  String get alarmTriggered => 'ALARM!';

  @override
  String get hvacOff => 'Off';

  @override
  String get hvacHeat => 'Heat';

  @override
  String get hvacCool => 'Cool';

  @override
  String get hvacHeatCool => 'Heat/Cool';

  @override
  String get hvacAuto => 'Auto';

  @override
  String get hvacDry => 'Dry';

  @override
  String get hvacFanOnly => 'Fan only';

  @override
  String climateStatus(String mode, String temperature) {
    return '$mode · $temperature';
  }

  @override
  String get mediaPlaying => 'Playing';

  @override
  String get mediaPaused => 'Paused';

  @override
  String get cameraIdle => 'Ready';

  @override
  String get cameraStreaming => 'Streaming';

  @override
  String get cameraRecording => 'Recording';

  @override
  String get scriptRunning => 'Running';

  @override
  String get routineReady => 'Ready';

  @override
  String doorbellLast(String time) {
    return 'Last ring $time';
  }

  @override
  String get lowBattery => 'Low battery';

  @override
  String batteryLevel(int percent) {
    return 'Battery $percent %';
  }

  @override
  String get protocolCloud => 'Cloud';

  @override
  String get protocolVirtual => 'Virtual';

  @override
  String get favoritesEmpty =>
      'Tap the star on a device\'s page to add it to your favorites.';

  @override
  String get scenesTitle => 'Scenes';

  @override
  String get scriptsTitle => 'Scripts';

  @override
  String get automationsTitle => 'Automations';

  @override
  String get noScenes => 'No scenes yet.';

  @override
  String get dashboardAttention => 'Needs attention';

  @override
  String get summaryTemperature => 'Indoor';

  @override
  String get summaryHumidity => 'Humidity';

  @override
  String get summaryLights => 'Lights on';

  @override
  String get summaryOpenings => 'Doors & windows';

  @override
  String get summaryOpeningsClosed => 'All closed';

  @override
  String summaryOpeningsOpen(int count) {
    return '$count open';
  }

  @override
  String get summaryPower => 'Power';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Good night';

  @override
  String get summaryAlerts => 'Alerts';

  @override
  String get valueNotAvailable => 'Not available';

  @override
  String lightsOnOf(int on, int total) {
    return '$on of $total';
  }

  @override
  String lowBatteryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count low batteries',
      one: '1 low battery',
    );
    return '$_temp0';
  }

  @override
  String unavailableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unavailable',
      one: '1 unavailable',
    );
    return '$_temp0';
  }

  @override
  String get roomNoRoom => 'Unassigned';

  @override
  String get allDevices => 'All devices';

  @override
  String roomDevicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
      zero: 'No devices',
    );
    return '$_temp0';
  }

  @override
  String roomLightsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lights on',
      one: '1 light on',
    );
    return '$_temp0';
  }

  @override
  String get roomEmpty => 'No devices in this room.';

  @override
  String get noRoomsYet => 'No rooms yet. Add them in Settings → Home.';

  @override
  String get groupLights => 'Lights';

  @override
  String get groupClimate => 'Climate';

  @override
  String get groupCovers => 'Blinds & doors';

  @override
  String get groupSwitches => 'Switches & outlets';

  @override
  String get groupSecurity => 'Security';

  @override
  String get groupSensors => 'Sensors';

  @override
  String get groupMedia => 'Media';

  @override
  String get groupEnergy => 'Energy';

  @override
  String get groupOther => 'Other';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get brightness => 'Brightness';

  @override
  String get colorTemperature => 'Color temperature';

  @override
  String get warm => 'Warm';

  @override
  String get cool => 'Cool';

  @override
  String get color => 'Color';

  @override
  String get targetTemperature => 'Target temperature';

  @override
  String get currentTemperature => 'Current';

  @override
  String get increaseTemperature => 'Increase temperature';

  @override
  String get decreaseTemperature => 'Decrease temperature';

  @override
  String get mode => 'Mode';

  @override
  String get fanMode => 'Fan';

  @override
  String get position => 'Position';

  @override
  String get open => 'Open';

  @override
  String get close => 'Close';

  @override
  String get stop => 'Stop';

  @override
  String get lock => 'Lock';

  @override
  String get unlock => 'Unlock';

  @override
  String confirmUnlockTitle(String name) {
    return 'Unlock $name?';
  }

  @override
  String confirmOpenTitle(String name) {
    return 'Open $name?';
  }

  @override
  String confirmDisarmTitle(String name) {
    return 'Disarm $name?';
  }

  @override
  String get confirmCriticalBody =>
      'This action affects the security of your home.';

  @override
  String get confirm => 'Confirm';

  @override
  String get activate => 'Activate';

  @override
  String get runNow => 'Run now';

  @override
  String sceneActivated(String name) {
    return '$name activated';
  }

  @override
  String get automationEnabled => 'Enabled';

  @override
  String lastTriggered(String time) {
    return 'Last triggered $time';
  }

  @override
  String get neverTriggered => 'Never triggered';

  @override
  String get volume => 'Volume';

  @override
  String get detailInfo => 'Information';

  @override
  String get infoRoom => 'Room';

  @override
  String get infoManufacturer => 'Manufacturer';

  @override
  String get infoModel => 'Model';

  @override
  String get infoProtocol => 'Protocol';

  @override
  String get infoLastChanged => 'Last changed';

  @override
  String get infoEntityId => 'Device ID';

  @override
  String get infoSignal => 'Signal';

  @override
  String get infoBattery => 'Battery';

  @override
  String get deviceNotFound => 'This device no longer exists.';

  @override
  String get unavailableBanner =>
      'This device is unavailable. Controls are disabled until it reconnects.';

  @override
  String get controlsOffline =>
      'Controls are available again once the connection is restored.';

  @override
  String get kioskSection => 'Kiosk mode (wall tablet)';

  @override
  String get kioskStart => 'Start kiosk mode';

  @override
  String get kioskStartOnLaunch => 'Open in kiosk mode on launch';

  @override
  String get kioskKeepAwake => 'Keep screen on';

  @override
  String get kioskDimAfter => 'Dim screen after';

  @override
  String get kioskReturnAfter => 'Return to dashboard after';

  @override
  String get kioskPin => 'Exit PIN';

  @override
  String get kioskPinSet => 'PIN is set';

  @override
  String get kioskPinNotSet => 'No PIN — anyone can leave kiosk mode';

  @override
  String get kioskSetPin => 'Set PIN';

  @override
  String get kioskChangePin => 'Change PIN';

  @override
  String get kioskRemovePin => 'Remove PIN';

  @override
  String get kioskPinHint => '4–8 digits';

  @override
  String get kioskPinConfirm => 'Repeat PIN';

  @override
  String get kioskPinMismatch => 'The PINs do not match.';

  @override
  String get kioskPinInvalid => 'Use 4–8 digits.';

  @override
  String get kioskExit => 'Exit kiosk mode';

  @override
  String get kioskEnterPin => 'Enter PIN';

  @override
  String get kioskWrongPin => 'Wrong PIN.';

  @override
  String kioskLockedOut(int seconds) {
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  String get kioskOsHint =>
      'For a fully locked wall panel also use the system\'s kiosk feature: Android screen pinning or a kiosk launcher, iOS Guided Access. They can also start the app automatically.';

  @override
  String get durationNever => 'Never';

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String dataUpdating(String time) {
    return 'Showing data from $time — updating…';
  }

  @override
  String get energyConsumption => 'Home consumption';

  @override
  String get save => 'Save';

  @override
  String get weatherClear => 'Clear';

  @override
  String get weatherClearNight => 'Clear night';

  @override
  String get weatherPartlyCloudy => 'Partly cloudy';

  @override
  String get weatherCloudy => 'Cloudy';

  @override
  String get weatherFog => 'Fog';

  @override
  String get weatherRain => 'Rain';

  @override
  String get weatherHeavyRain => 'Heavy rain';

  @override
  String get weatherSnow => 'Snow';

  @override
  String get weatherSleet => 'Sleet';

  @override
  String get weatherHail => 'Hail';

  @override
  String get weatherThunderstorm => 'Thunderstorm';

  @override
  String get weatherWindy => 'Windy';

  @override
  String get weatherExceptional => 'Severe weather';

  @override
  String get weatherAtHome => 'Weather at home';

  @override
  String get weatherAtMyLocation => 'Weather at my location';

  @override
  String get weatherEnableDevice => 'Weather at my location';

  @override
  String get weatherEnableDeviceConfirm => 'Turn on';

  @override
  String get weatherDeviceDisclosure =>
      'The app will ask for your approximate location (not precise GPS), round it to about 1 km and send it to MET Norway (api.met.no) to get the forecast – about every 30 minutes while the app is open. Nothing else is sent. You can turn this off anytime in Settings → Privacy & data.';

  @override
  String get weatherDeviceSettingHint =>
      'Approximate location is sent to MET Norway. Off by default.';

  @override
  String get weatherMetAttribution => 'Data: MET Norway (CC BY 4.0)';

  @override
  String get weatherLocationDeniedForever =>
      'Location access is blocked for this app.';

  @override
  String get weatherOpenSettings => 'Open settings';

  @override
  String get weatherLocationOff =>
      'Location services are turned off on this device.';

  @override
  String get weatherLocationDenied => 'Location access was not allowed.';

  @override
  String get weatherDeviceUnavailable =>
      'Weather for your location is not available right now.';

  @override
  String get weatherWind => 'Wind';

  @override
  String get summaryOutdoor => 'Outdoor';

  @override
  String get presetNone => 'No preset';

  @override
  String get presetHome => 'Home';

  @override
  String get presetAway => 'Away';

  @override
  String get presetSleep => 'Sleep';

  @override
  String get presetEco => 'Eco';

  @override
  String get presetComfort => 'Comfort';

  @override
  String get presetBoost => 'Boost';

  @override
  String get presetActivity => 'Activity';

  @override
  String get powerToggle => 'On/off';

  @override
  String get personHome => 'Home';

  @override
  String get personAway => 'Away';

  @override
  String get searchHint => 'Search';

  @override
  String get done => 'Done';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get weatherForecastTitle => 'Weather forecast';

  @override
  String get weatherHourly => 'Next hours';

  @override
  String get weatherDaily => 'Next days';

  @override
  String get weatherToday => 'Today';

  @override
  String get weatherNow => 'Now';

  @override
  String get weatherNoForecast =>
      'No forecast for the home yet. Turn it on in Settings → Privacy.';

  @override
  String get weatherFeelsHint =>
      'MET Norway\'s forecast for the home\'s location.';

  @override
  String get mediaPlayPause => 'Play or pause';

  @override
  String get mediaNext => 'Next';

  @override
  String get mediaPrevious => 'Previous';

  @override
  String get addDeviceTitle => 'Add device';

  @override
  String get setUpDeviceTitle => 'Name and room';

  @override
  String get deviceNameLabel => 'Name';

  @override
  String get deviceRoomLabel => 'Room';

  @override
  String get setUpSaved => 'Saved.';

  @override
  String get weatherHomeLocationTitle => 'Forecast for your home';

  @override
  String get weatherHomeLocationHint =>
      'Turn the forecast on: the app will remember this phone\'s approximate location as the home location.';

  @override
  String get weatherHomeLocationEnable => 'Turn on forecast';

  @override
  String get weatherHomeLocationDisclosure =>
      'The app will take this phone\'s approximate location once (rounded to about 1 km) as the home location and send it to MET Norway (api.met.no) every 30 minutes. Nothing else is sent. You can turn it off in Settings.';

  @override
  String get weatherHomeLocationSetting =>
      'Forecast for the home location (MET Norway)';

  @override
  String get weatherHomeLocationSettingHint =>
      'Sends the home\'s approximate location (saved when you turned the forecast on).';

  @override
  String get mediaTitle => 'Music and media';

  @override
  String get mediaNoPlayers =>
      'No speakers or TVs yet. Add a Sonos, Roku, Samsung or LG TV with \"Add device\" and it shows up here.';

  @override
  String get mediaSource => 'Source';

  @override
  String get mediaIdle => 'Not playing';

  @override
  String get mediaNoPlayersShort => 'No media players yet';

  @override
  String get appLockTitle => 'Open Smart Home is locked';

  @override
  String get appUnlock => 'Unlock';

  @override
  String get appLockReason => 'Unlock Open Smart Home';

  @override
  String appLockCriticalReason(String device) {
    return 'Confirm: $device';
  }

  @override
  String get securitySection => 'Security';

  @override
  String get appLockSetting => 'Lock the app';

  @override
  String get appLockSettingHint =>
      'Ask for fingerprint, face or the device PIN when opening the app (after 1 minute in the background).';

  @override
  String get appLockCriticalSetting => 'Confirm locks and alarm';

  @override
  String get appLockCriticalSettingHint =>
      'Also ask before unlocking doors, opening the garage or disarming the alarm.';

  @override
  String get alarmArm_home => 'Home';

  @override
  String get alarmArm_away => 'Away';

  @override
  String get alarmArm_night => 'Night';

  @override
  String get alarmArm_vacation => 'Vacation';

  @override
  String get alarmArm_custom_bypass => 'Custom';

  @override
  String get alarmArmTitle => 'Arm';

  @override
  String get alarmDisarm => 'Disarm';

  @override
  String get alarmCodeTitle => 'Alarm code';

  @override
  String get vacuumCleaning => 'Cleaning';

  @override
  String get vacuumDocked => 'Docked';

  @override
  String get vacuumReturning => 'Returning to dock';

  @override
  String get vacuumPaused => 'Paused';

  @override
  String get vacuumError => 'Error';

  @override
  String get vacuumIdle => 'Idle';

  @override
  String get vacuumStart => 'Start';

  @override
  String get vacuumPause => 'Pause';

  @override
  String get vacuumReturnHome => 'Dock';

  @override
  String get fanSpeed => 'Speed';

  @override
  String get fanOscillate => 'Oscillate';

  @override
  String get targetHumidityLabel => 'Target humidity';

  @override
  String get modeLabel => 'Mode';

  @override
  String get valueLabel => 'Value';

  @override
  String get editDevice => 'Edit name and room';

  @override
  String get deviceSearchHint => 'Search by name, room or type';

  @override
  String get deviceSearchEmpty => 'No device matches.';

  @override
  String get favoritesReorder => 'Change order';

  @override
  String get restrictedTitle => 'Child / guest mode';

  @override
  String get restrictedHint =>
      'Hides sensitive devices and locks settings with a PIN on this device.';

  @override
  String get restrictedHideSecurity => 'Hide locks, alarm and garage doors';

  @override
  String get restrictedHideCameras => 'Hide cameras';

  @override
  String get restrictedEnable => 'Turn on (set a PIN)';

  @override
  String get restrictedActive => 'Child / guest mode is on';

  @override
  String get restrictedDisable => 'Turn off (PIN)';

  @override
  String get restrictedHidden => 'Not available in child / guest mode.';

  @override
  String get autoNew => 'New automation';

  @override
  String get autoWhen => 'When';

  @override
  String get autoThen => 'Then';

  @override
  String get autoName => 'Name';

  @override
  String get autoTriggerTime => 'Time';

  @override
  String get autoTriggerDevice => 'Device';

  @override
  String get autoTriggerSun => 'Sun';

  @override
  String get autoEveryDay => 'Every day';

  @override
  String get autoSunrise => 'Sunrise';

  @override
  String get autoSunset => 'Sunset';

  @override
  String autoOffset(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      zero: 'Exactly at the time',
    );
    return '$_temp0';
  }

  @override
  String get autoPickDevice => 'Choose a device';

  @override
  String get autoAddAction => 'Add an action';

  @override
  String get autoDelete => 'Delete automation';

  @override
  String autoDeleteConfirm(String name) {
    return 'Delete \"$name\"? This can\'t be undone.';
  }

  @override
  String get autoIncomplete => 'Choose when it runs and at least one action.';

  @override
  String get autoNameHint => 'For example: Hallway light at night';

  @override
  String get svc_activate => 'Activate';

  @override
  String get allLightsOn => 'All on';

  @override
  String get allLightsOff => 'All off';

  @override
  String get allLightsTitle => 'All lights in the home';

  @override
  String get floorOther => 'Other';

  @override
  String get sceneNew => 'New scene from now';

  @override
  String get sceneName => 'Scene name';

  @override
  String get sceneDevices => 'Devices';

  @override
  String get sceneSave => 'Save scene';

  @override
  String get sceneNeedDevice => 'Choose at least one device.';

  @override
  String get sceneDelete => 'Delete scene';

  @override
  String sceneDefaultName(String time) {
    return 'Scene $time';
  }

  @override
  String get autoEdit => 'Edit automation';

  @override
  String get backupSection => 'Backup and transfer';

  @override
  String get backupHint =>
      'The whole home — devices, rooms, names, scenes, automations and programs — and the app\'s look, to keep or to move to another phone or wall panel. PINs, photos and this device\'s own choices stay here.';

  @override
  String get backupCopy => 'Copy settings';

  @override
  String get backupPaste => 'Paste settings';

  @override
  String get backupCopied =>
      'Copied. Paste it into the app on the other device.';

  @override
  String get backupImported => 'Settings applied.';

  @override
  String get backupInvalid => 'That is not an Open Smart Home backup.';

  @override
  String get autoAddTrigger => 'Add a trigger';

  @override
  String get autoAnyTrigger => 'Runs when any of these happens.';

  @override
  String get autoOnlyIf => 'Only if';

  @override
  String get autoOnlyIfHint =>
      'Optional. All of these must be true when it starts.';

  @override
  String get autoAddCondition => 'Add a condition';

  @override
  String get autoTriggerValue => 'Value';

  @override
  String get autoAbove => 'Rises above';

  @override
  String get autoBelow => 'Falls below';

  @override
  String get autoThreshold => 'Threshold';

  @override
  String get autoCondTime => 'Between two times';

  @override
  String get autoCondAfter => 'From';

  @override
  String get autoCondBefore => 'Until';

  @override
  String get autoCondDevice => 'A device is in a state';

  @override
  String get autoCondDark => 'Only when it\'s dark';

  @override
  String get autoCondLight => 'Only when it\'s light';

  @override
  String get alertsSetting => 'Notify about critical alerts';

  @override
  String get alertsSettingHint =>
      'Smoke, CO, water leak, a triggered alarm or a jammed lock as a phone notification. While the app runs — or always, with Background automations (Settings → Home).';

  @override
  String get alertsPermissionDenied =>
      'Notifications are turned off for this app in the phone\'s settings.';

  @override
  String get fanLow => 'Low';

  @override
  String get fanMedium => 'Medium';

  @override
  String get fanMiddle => 'Middle';

  @override
  String get fanHigh => 'High';

  @override
  String get fanTop => 'Top';

  @override
  String get fanFocus => 'Focused';

  @override
  String get fanDiffuse => 'Diffuse';

  @override
  String get allCoversOpen => 'Open all';

  @override
  String get allCoversClose => 'Close all';

  @override
  String get widgetNoScenes => 'No scenes yet: create one in the app';

  @override
  String get clapSetting => 'Double clap';

  @override
  String get clapSettingHint =>
      'Clap twice to switch something. Only while the kiosk is shown.';

  @override
  String get clapPrivacyTitle => 'Listen for claps?';

  @override
  String get clapPrivacyBody =>
      'While the kiosk is on screen the microphone stays on, and Android shows its microphone indicator. The app only measures how loud it is, 50 times a second, on this tablet: no sound is recorded, stored or sent anywhere. Turn it off here at any time.';

  @override
  String get clapAllow => 'Turn on';

  @override
  String get clapPermissionDenied =>
      'The microphone is not allowed for this app in the system settings.';

  @override
  String get clapTarget => 'What a double clap does';

  @override
  String get clapTargetNone => 'Nothing chosen yet';

  @override
  String get clapToggle => 'switch on/off';

  @override
  String get clapSensitivity => 'Sensitivity';

  @override
  String get clapLow => 'Low';

  @override
  String get clapMedium => 'Medium';

  @override
  String get clapHigh => 'High';

  @override
  String clapSwitched(String name, String state) {
    return '$name: $state';
  }

  @override
  String clapDone(String name) {
    return '$name: done';
  }

  @override
  String get clapLockAction =>
      'lock / unlock (unlocking asks for confirmation)';

  @override
  String get clapGarageAction => 'open (asks for confirmation) / close';

  @override
  String get clapCoverAction => 'open / close';

  @override
  String get clapVacuumAction => 'start / back to dock';

  @override
  String get clapMediaAction => 'play / pause';

  @override
  String get clapOpenScreen => 'opens its screen';

  @override
  String get clapSearch => 'Search devices';

  @override
  String get kioskDarkScreensaver => 'Dimmed backlight when idle';

  @override
  String get kioskDarkScreensaverHint =>
      'While the screen is idle the backlight is at the level below (at night at most “Darker at night”).';

  @override
  String get kioskNight => 'Darker at night';

  @override
  String get kioskNightHint => 'Lower brightness on a schedule';

  @override
  String kioskNightRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String kioskNightFrom(String time) {
    return 'From $time';
  }

  @override
  String kioskNightTo(String time) {
    return 'Until $time';
  }

  @override
  String get kioskNightFromHelp => 'Night starts at';

  @override
  String get kioskNightToHelp => 'Night ends at';

  @override
  String kioskNightLevel(int percent) {
    return 'Night brightness: $percent %';
  }

  @override
  String get dashLayoutTitle => 'Home screen';

  @override
  String get dashLayoutSubtitle => 'Choose and order the cards';

  @override
  String get dashLayoutHint =>
      'Drag or use the arrow to change the order; the switch shows or hides a card. Warnings (connection, critical alerts) always stay on top. On tablets favorites and rooms are in the right column.';

  @override
  String get dashLayoutReset => 'Default';

  @override
  String get dashMoveUp => 'Move up';

  @override
  String get dashCardSummary => 'Summary (temperature, lights, power…)';

  @override
  String get dashCardWeather => 'Weather';

  @override
  String get dashCardMedia => 'Now playing';

  @override
  String get dashCardShortcuts => 'House check, More';

  @override
  String get dashCardAttention => 'Needs attention (batteries, unavailable)';

  @override
  String get timerSet => 'Timer';

  @override
  String get timerTurnOff => 'Turn off';

  @override
  String get timerTurnOn => 'Turn on';

  @override
  String timerHours(int hours) {
    return '$hours h';
  }

  @override
  String get timerHint =>
      'This phone or wall panel counts down while the app runs (or with automations in the background).';

  @override
  String timerTurnsOffAt(String time) {
    return 'Turns off at $time';
  }

  @override
  String timerTurnsOnAt(String time) {
    return 'Turns on at $time';
  }

  @override
  String get kioskPanelChooseDevice => 'Choose device';

  @override
  String get settingsNotificationsSection => 'Notifications';

  @override
  String get settingsAppearanceHint => 'Theme, language, home screen';

  @override
  String get settingsKioskHint =>
      'Wall tablet: layout, PIN, screensaver, camera';

  @override
  String get settingsNotificationsHint => 'Alerts, batteries, appliance done';

  @override
  String get settingsSecurityHint => 'App lock, kids and guests mode';

  @override
  String get settingsPrivacyHint => 'Location, voice, deleting data';

  @override
  String get settingsBackupHint =>
      'Keep your home or move it to another device';

  @override
  String get loadingContent => 'Loading…';

  @override
  String get houseCheckTitle => 'House check';

  @override
  String get houseCheckShort => 'Check';

  @override
  String get houseCheckLeaving => 'Leaving';

  @override
  String get houseCheckNight => 'Good night';

  @override
  String get houseCheckAllGood => 'All good';

  @override
  String get houseCheckAllGoodLeaving =>
      'Lights are off, locks are locked, nothing is left open. Have a good trip!';

  @override
  String get houseCheckAllGoodNight =>
      'The house is ready for the night. Good night!';

  @override
  String houseCheckCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things to check',
      one: '$count thing to check',
    );
    return '$_temp0';
  }

  @override
  String houseCheckFixAll(int count) {
    return 'Fix all ($count)';
  }

  @override
  String get houseCheckFixing => 'Fixing…';

  @override
  String get houseCheckManualHint =>
      'The app cannot close windows and doors with a sensor — please check them. The alarm is armed on its own screen.';

  @override
  String get houseCheckLightOn => 'On';

  @override
  String get houseCheckMediaOn => 'On';

  @override
  String get houseCheckClimateOn => 'Running';

  @override
  String get houseCheckUnlocked => 'Unlocked';

  @override
  String get houseCheckGarageOpen => 'Open';

  @override
  String get houseCheckOpened => 'Open';

  @override
  String get houseCheckAlarmOff => 'Alarm not armed';

  @override
  String get houseCheckTurnOff => 'Turn off';

  @override
  String get houseCheckLock => 'Lock';

  @override
  String get houseCheckClose => 'Close';

  @override
  String get houseCheckPause => 'Pause';

  @override
  String get houseCheckOpenDevice => 'Open';

  @override
  String todoOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
      zero: 'All done',
    );
    return '$_temp0';
  }

  @override
  String homeSayTime(String time) {
    return 'It\'s $time.';
  }

  @override
  String homeSayWeather(String condition, String temperature) {
    return 'Outside it\'s $condition, $temperature.';
  }

  @override
  String homeSayLights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lights are on',
      one: '$count light is on',
    );
    return '$_temp0';
  }

  @override
  String get homeSayLightsOff => 'All lights are off';

  @override
  String homeSayOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count windows or doors are open.',
      one: 'and $count window or door is open.',
    );
    return '$_temp0';
  }

  @override
  String get homeSayClosed => 'and everything is closed.';

  @override
  String homeSayUnlocked(String names) {
    return 'Unlocked: $names.';
  }

  @override
  String homeSayAlarm(String state) {
    return 'Alarm: $state.';
  }

  @override
  String homeSayAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Attention: $count alerts.',
      one: 'Attention: $count alert.',
    );
    return '$_temp0';
  }

  @override
  String get mediaShuffle => 'Shuffle';

  @override
  String get mediaRepeat => 'Repeat';

  @override
  String get mediaRepeatOff => 'Repeat off';

  @override
  String get mediaRepeatAll => 'Repeat all';

  @override
  String get mediaRepeatOne => 'Repeat one';

  @override
  String get mediaSeek => 'Position';

  @override
  String get quickTilesTitle => 'Quick tiles';

  @override
  String get quickTilesHint =>
      'Three tiles in the pull-down menu (Android): one tap switches a device or runs a scene, without opening the app. Works only on an unlocked phone; locks, garage doors and alarms are not offered.';

  @override
  String quickTileSlot(int n) {
    return 'Tile $n';
  }

  @override
  String get quickTileUnset => 'Not set up';

  @override
  String quickTileChoose(int n) {
    return 'What tile $n does';
  }

  @override
  String get quickTileClear => 'Remove';

  @override
  String get quickTileAdd => 'Add to menu';

  @override
  String get quickTileAdded => 'The tile is in the Quick Settings menu.';

  @override
  String quickTileAddManually(int n) {
    return 'Pull down the menu, tap the pencil and drag “Smart Home $n” to the tiles.';
  }

  @override
  String get aodTitle => 'Always-on screen';

  @override
  String get aodHint =>
      'When the kiosk is not used: a black screen with the clock, the forecast and one thing you choose. The content shifts slowly so the screen does not burn in.';

  @override
  String get aodFocus => 'Under the clock';

  @override
  String get aodFocusNone => 'Nothing';

  @override
  String get aodFocusDevice => 'Device';

  @override
  String get aodFocusEnergy => 'Power now';

  @override
  String get aodFocusMedia => 'Now playing';

  @override
  String get aodFocusHome => 'Home sentence';

  @override
  String get aodChoose => 'Choose';

  @override
  String get morningScreen => 'Morning screen';

  @override
  String get morningScreenHint =>
      'In the morning the always-on screen shows today\'s forecast, events and reminders (items due today).';

  @override
  String get morningFrom => 'From';

  @override
  String get morningTo => 'To';

  @override
  String morningHighLow(String high, String low) {
    return 'high $high, low $low';
  }

  @override
  String get aodBrightness => 'Always-on brightness';

  @override
  String get approachWake => 'Wake the screen when someone comes near';

  @override
  String get approachWakeHint => 'Only while the kiosk screen is idle.';

  @override
  String get approachOff => 'Off';

  @override
  String get approachSensor => 'Motion sensor';

  @override
  String get approachCamera => 'Tablet camera';

  @override
  String get approachSensorPick => 'Sensor';

  @override
  String get approachNoSensors =>
      'No motion or presence sensors. Add one (e.g. Shelly BLU, Hue, IKEA or ESPHome).';

  @override
  String get approachCameraTitle => 'Use the tablet\'s camera?';

  @override
  String get approachCameraBody =>
      'While the screen is idle, the front camera checks a few times a second whether something moves in front of the tablet, and Android shows its camera indicator. Pictures are processed only on this tablet and dropped at once: nothing is recorded, stored or sent anywhere. While the screen is awake the camera is off.';

  @override
  String get approachCameraAllow => 'Turn on';

  @override
  String get approachCameraDenied =>
      'The camera is not allowed for this app in the system settings.';

  @override
  String get presenceTitle => 'Presence simulation';

  @override
  String get presenceHint =>
      'Lights go on and off by themselves in the evening while nobody is home';

  @override
  String get presenceIntro =>
      'While it is on, one of the chosen lights is switched on or off every 15 minutes in the evening (with a random wait of up to 10 minutes), and all go off at the end time. The phone or tablet running it has to stay at home, running.';

  @override
  String get presenceOn => 'Simulation on';

  @override
  String get presenceLights => 'Lights';

  @override
  String get presenceNoLights => 'The home has no lights.';

  @override
  String get presenceFromSunset => 'From sunset';

  @override
  String get presenceStart => 'Start';

  @override
  String get presenceEnd => 'End (all chosen lights go off)';

  @override
  String get presenceSave => 'Save';

  @override
  String get presenceSaved => 'Presence simulation saved.';

  @override
  String get kioskAlertAck => 'Got it';

  @override
  String get kioskAlertShow => 'Show device';

  @override
  String kioskAlertOpenFor(int minutes) {
    return 'Open for $minutes min';
  }

  @override
  String kioskAlertMore(int count) {
    return '+$count more';
  }

  @override
  String kioskAlertSpeech(String name, String status) {
    return 'Warning! $name: $status.';
  }

  @override
  String get kioskAlertSetting => 'Full-screen alerts';

  @override
  String get kioskAlertSettingHint =>
      'Smoke, carbon monoxide, water leak, a triggered alarm or a jammed lock covers the whole screen and is spoken until someone confirms it.';

  @override
  String get kioskOpenAlert => 'Door or window open longer than';

  @override
  String get kioskOpenAlertNever => 'Never';

  @override
  String kioskOpenAlertMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get timerTitle => 'Timer';

  @override
  String get timerNew => 'New timer';

  @override
  String get timerStart => 'Start';

  @override
  String get timerStop => 'Stop';

  @override
  String get timerCancel => 'Cancel timer';

  @override
  String get timerAddMinute => '+1 min';

  @override
  String timerDone(String label) {
    return 'Timer $label is done';
  }

  @override
  String timerDoneSpeech(String label) {
    return 'The $label timer is done.';
  }

  @override
  String kioskNightLightHint(String name) {
    return 'Tap: $name at 10 %';
  }

  @override
  String kioskNightLightOn(String name) {
    return '$name is on · tap again for the screen';
  }

  @override
  String get kioskNightClock => 'Red night clock';

  @override
  String get kioskNightClockHint =>
      'At night the idle screen shows only the time, in dim red.';

  @override
  String get kioskNightLight => 'Night light on tap';

  @override
  String get kioskNightLightNone => 'None (a tap wakes the screen)';

  @override
  String get kioskLeaving => 'I\'m leaving';

  @override
  String get kioskLeavingAllGood =>
      'Everything is off and closed. Have a nice day!';

  @override
  String get kioskLeavingManual =>
      'Windows and doors marked without a tick must be closed by hand.';

  @override
  String kioskLeavingGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Switch off $count things',
      one: 'Switch off 1 thing',
      zero: 'Nothing to switch off',
    );
    return '$_temp0';
  }

  @override
  String kioskLeavingGoArm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Switch off $count and arm',
      one: 'Switch off 1 thing and arm',
      zero: 'Arm the alarm',
    );
    return '$_temp0';
  }

  @override
  String get kioskLeavingBye => 'Goodbye!';

  @override
  String get photoFrame => 'Photo frame';

  @override
  String get photoFrameHint =>
      'While idle, show photos from this tablet (they stay on it).';

  @override
  String photoFrameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos · stay on this tablet',
      one: '1 photo · stays on this tablet',
    );
    return '$_temp0';
  }

  @override
  String get photoFrameAdd => 'Add photos';

  @override
  String get photoFrameRemove => 'Remove all';

  @override
  String photoFrameEverySeconds(int seconds) {
    return 'every $seconds s';
  }

  @override
  String photoFrameEveryMinutes(int minutes) {
    return 'every $minutes min';
  }

  @override
  String get kioskColumnsNoRooms =>
      'No rooms yet. Add them in Settings → Home.';

  @override
  String get kioskColumnsDevices => 'Devices';

  @override
  String get kioskOpenDevice => 'Open device';

  @override
  String get kioskBundleMain => 'Main';

  @override
  String get kioskBundleActions => 'Actions';

  @override
  String get kioskBundleSettings => 'Settings';

  @override
  String get kioskBundleState => 'State';

  @override
  String kioskBundleCount(int count) {
    return '$count controls';
  }

  @override
  String get kioskQuickControls => 'Quick controls';

  @override
  String get kioskQuickControlsAdd => 'Add';

  @override
  String get kioskQuickControlsEdit => 'Change';

  @override
  String get kioskQuickControlsHint =>
      'Choose devices to keep at hand here — lights, the air fryer, a scene…';

  @override
  String get kioskHomeCards => 'Home cards';

  @override
  String get applianceDoneAction => 'Tell me when it\'s done';

  @override
  String get applianceDoneHint =>
      'The app watches the power: once the appliance has run (above the threshold) and then goes quiet, this phone or tablet says it\'s done. Runs on this phone or wall panel while the app runs (or with automations in the background).';

  @override
  String get applianceDoneName => 'Name (e.g. Washing machine)';

  @override
  String get applianceDoneThreshold => 'Running above';

  @override
  String get applianceDoneQuiet => 'Done after quiet for';

  @override
  String applianceDoneMinutesValue(int minutes) {
    return '$minutes min';
  }

  @override
  String applianceDoneNow(String watts) {
    return 'Using $watts W now.';
  }

  @override
  String get applianceDoneRemove => 'Remove';

  @override
  String get applianceDoneRemoved => 'Reminder removed.';

  @override
  String applianceDoneSaved(String name) {
    return 'You\'ll hear when \"$name\" is done.';
  }

  @override
  String get applianceDoneOn => 'Tells you when it\'s done';

  @override
  String get applianceDoneOnHint => 'Watched by this phone';

  @override
  String get applianceDoneChange => 'Change';

  @override
  String get applianceDoneTitle => 'Done';

  @override
  String applianceDoneMessage(String name) {
    return '$name: the cycle has finished.';
  }

  @override
  String get heatingScheduleAction => 'Weekly schedule';

  @override
  String get heatingScheduleTitle => 'Weekly schedule';

  @override
  String get heatingScheduleHint =>
      'From each time on, that temperature holds until the next one. The schedule is kept as the home\'s automations. Runs on this phone or wall panel while the app runs (or with automations in the background). A manual change holds until the next time.';

  @override
  String get heatingScheduleWorkdays => 'Workdays (Mon–Fri)';

  @override
  String get heatingScheduleWeekend => 'Weekend (Sat–Sun)';

  @override
  String get heatingScheduleAdd => 'Add a time';

  @override
  String get heatingScheduleColder => 'Colder';

  @override
  String get heatingScheduleWarmer => 'Warmer';

  @override
  String get heatingScheduleRemove => 'Remove schedule';

  @override
  String get heatingScheduleRemoved => 'Schedule removed.';

  @override
  String get heatingScheduleSaved => 'Schedule saved.';

  @override
  String heatingScheduleNext(String time, String temperature) {
    return 'Next: $time → $temperature';
  }

  @override
  String get mediaMute => 'Mute';

  @override
  String get mediaUnmute => 'Unmute';

  @override
  String get mediaVolumeUp => 'Volume up';

  @override
  String get mediaVolumeDown => 'Volume down';

  @override
  String get mediaSoundMode => 'Sound mode';

  @override
  String get tvRemote => 'Remote';

  @override
  String get tvUp => 'Up';

  @override
  String get tvDown => 'Down';

  @override
  String get tvLeft => 'Left';

  @override
  String get tvRight => 'Right';

  @override
  String get tvOk => 'OK';

  @override
  String get tvBack => 'Back';

  @override
  String get tvHome => 'Home';

  @override
  String get tvMenu => 'Menu';

  @override
  String get tvPlayPause => 'Play / pause';

  @override
  String get tvVolume => 'Vol';

  @override
  String get tvChannel => 'Ch';

  @override
  String get tvChannelUp => 'Channel up';

  @override
  String get tvChannelDown => 'Channel down';

  @override
  String get roomPhoto => 'Room photo';

  @override
  String get roomPhotoChange => 'Choose another photo';

  @override
  String get roomPhotoRemove => 'Remove photo';

  @override
  String get roomPhotoHint =>
      'Photo, icon and colour stay on this device only. For the wall tablet, choose them on the tablet itself.';

  @override
  String get themeAutoDark => 'Dark after sunset';

  @override
  String get themeAutoDarkHint =>
      'Follows sunrise and sunset at the home\'s location (without it: dark from 20:00 to 7:00).';

  @override
  String get accentTitle => 'Accent colour';

  @override
  String get accentTerracotta => 'Terracotta';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentRose => 'Rose';

  @override
  String get accentTeal => 'Teal';

  @override
  String get onNowTitle => 'On now';

  @override
  String onNowLights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lights',
      one: '1 light',
    );
    return '$_temp0';
  }

  @override
  String get onNowLightsOff => 'All lights are off.';

  @override
  String onNowTurnedOff(String name) {
    return 'Turned off: $name';
  }

  @override
  String get onNowHint => 'Tap to open, long-press to turn off';

  @override
  String get roomLook => 'Room look';

  @override
  String get roomPhotoChoose => 'Choose a photo';

  @override
  String get roomIconTitle => 'Icon';

  @override
  String get roomColorTitle => 'Colour';

  @override
  String get roomLookReset => 'Default';

  @override
  String get favoritesBrowse => 'Browse devices';

  @override
  String get bigSliderPosition => 'Position';

  @override
  String get deviceSheetMore => 'All details';

  @override
  String get setupNext => 'Next';

  @override
  String get setupBack => 'Back';

  @override
  String get backupFileTitle => 'As text';

  @override
  String get updateTitle => 'App updates';

  @override
  String updateCurrent(String version) {
    return 'Version $version';
  }

  @override
  String get updateChecking => 'Checking…';

  @override
  String updateUpToDate(String version) {
    return 'You have the latest version ($version).';
  }

  @override
  String get updateNoReleases =>
      'No published releases (or the release source isn\'t public).';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String updateDownloading(int percent) {
    return 'Downloading… $percent %';
  }

  @override
  String get updateInstalling =>
      'Installing — Android may ask to confirm; the app then restarts.';

  @override
  String get updateNeedsPermission =>
      'Allow \"Install unknown apps\" for this app, then tap Install again.';

  @override
  String get updateFailed => 'The check or download failed (no internet?).';

  @override
  String get updateRejected =>
      'The download doesn\'t match its published checksum (SHA-256) — not installed.';

  @override
  String get updateInstall => 'Install';

  @override
  String get updateCheck => 'Check now';

  @override
  String get updateAuto => 'Check for new releases at start-up';

  @override
  String get updateAutoHint =>
      'Asks GitHub (public releases) whether there\'s a new version; GitHub then sees the device\'s address. Nothing else is sent.';

  @override
  String get firstRunSkip => 'Skip';

  @override
  String get firstRunWelcomeTitle => 'Welcome home!';

  @override
  String get firstRunRoleQuestion => 'How will you use this device?';

  @override
  String get firstRunRolePhone => 'My phone or tablet';

  @override
  String get firstRunRolePhoneHint => 'Personal, I carry it with me';

  @override
  String get firstRunRoleWall => 'Wall tablet for the whole home';

  @override
  String get firstRunRoleWallHint =>
      'Mounted on the wall, used by everyone (kiosk with a PIN)';

  @override
  String get firstRunWallNext => 'Set up the wall panel';

  @override
  String get firstRunLookTitle => 'Look';

  @override
  String get firstRunLookBody =>
      'Pick a light or dark theme and a colour you like.';

  @override
  String get firstRunFavoritesTitle => 'Favourite devices';

  @override
  String get firstRunFavoritesBody =>
      'Tap what you use most — it will be at the top of Home.';

  @override
  String get firstRunFavoritesNone =>
      'No controllable devices yet. Add them later in Settings → Home.';

  @override
  String firstRunFavoritesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices selected',
      one: '1 device selected',
      zero: 'Nothing selected',
    );
    return '$_temp0';
  }

  @override
  String get firstRunSecurityTitle => 'Protection';

  @override
  String get firstRunSecurityBody =>
      'Whoever has your unlocked phone can control the home. We recommend at least confirming locks and the alarm.';

  @override
  String get firstRunDoneTitle => 'All set';

  @override
  String get firstRunDoneBody =>
      'Add devices in Settings → Home → Add device. Everything chosen here can be changed in Settings, and Home\'s cards with the ⚙ button next to the greeting.';

  @override
  String get firstRunStart => 'Let\'s go';

  @override
  String kioskGreetingName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String kioskPersonButton(String name) {
    return '$name is using the panel';
  }

  @override
  String kioskPersonEnterPin(String name) {
    return 'PIN — $name';
  }

  @override
  String get kioskCriticalPinHint => 'Your own PIN or the panel\'s PIN';

  @override
  String kioskQuickControlsFor(String name) {
    return 'Quick controls — $name';
  }

  @override
  String get kioskQuickControlsShared => 'Use the shared ones';

  @override
  String get kioskPeopleTitle => 'Household on the panel';

  @override
  String get kioskPeopleHint =>
      'On the panel, a member taps their name and gets their own quick controls. Unlocking doors, disarming the alarm and similar actions need the member\'s own PIN or the panel\'s PIN — members without a PIN (e.g. children) cannot. Tap a name for the birthday.';

  @override
  String get kioskPersonPinSet => 'Own PIN set — may unlock';

  @override
  String get kioskPersonNoPin => 'No own PIN';

  @override
  String kioskPersonSetPin(String name) {
    return 'Own PIN — $name';
  }

  @override
  String get kioskPersonNoPinLocked => 'No own PIN — cannot unlock';

  @override
  String get extrasTitle => 'More';

  @override
  String get extrasShort => 'More';

  @override
  String get batteriesTitle => 'Batteries';

  @override
  String get batteriesNone => 'No device reports a battery.';

  @override
  String batteriesSummary(int count, int low) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count battery devices',
      one: '1 battery device',
    );
    String _temp1 = intl.Intl.pluralLogic(
      low,
      locale: localeName,
      other: '$low running low',
      one: '1 running low',
      zero: 'all fine',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get batteryReminder => 'Tell me when a battery runs low';

  @override
  String batteryReminderHint(int percent) {
    return 'This phone or tablet tells you with a notification when a device\'s battery drops to $percent % or lower (while the app runs, or with automations in the background).';
  }

  @override
  String batteryReminderMessage(String name, String percent) {
    return 'Battery running low: $name ($percent %)';
  }

  @override
  String get batteryLowShort => 'Battery low';

  @override
  String get batteryOk => 'Battery fine';

  @override
  String get vacationTitle => 'On holiday';

  @override
  String get vacationHint =>
      'Get the home ready while you are away, with one tap. On your return, heating and the simulation go back to how they were.';

  @override
  String get vacationTidy => 'Tidy up';

  @override
  String get vacationTidyHint =>
      'Lights and music off, and the rest — as \"Leaving\" does';

  @override
  String vacationHeating(String temperature) {
    return 'Heating at $temperature °C';
  }

  @override
  String vacationHeatingHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thermostats',
      one: '1 thermostat',
    );
    return '$_temp0; the old temperatures are remembered';
  }

  @override
  String get vacationSimulation => 'Presence simulation';

  @override
  String get vacationSimulationHint =>
      'Lights go on and off by themselves in the evening';

  @override
  String get vacationSimulationMissing => 'Not set up yet';

  @override
  String get vacationSimulationSetUp => 'Set up';

  @override
  String get vacationAlarm => 'Arm the alarm (away)';

  @override
  String get vacationStart => 'We\'re off';

  @override
  String get vacationLocalNote =>
      'This device remembers what to undo — mark your return on it.';

  @override
  String get vacationActive => 'You are on holiday';

  @override
  String vacationActiveSince(String date) {
    return 'Since $date';
  }

  @override
  String get vacationEndHint =>
      'When you are back: heating to the old temperatures, the simulation as it was.';

  @override
  String get vacationAlarmStillOn =>
      'The alarm is still on — disarm it with the keypad or code.';

  @override
  String get vacationEnd => 'We\'re back';

  @override
  String get guestWifiTitle => 'Guest Wi-Fi';

  @override
  String get guestWifiNotSet =>
      'Not set up yet. Enter the guest network; guests then join by scanning the code — no spelling out the password.';

  @override
  String get guestWifiScan => 'Scan with the phone\'s camera';

  @override
  String get guestWifiSetUp => 'Set up';

  @override
  String get guestWifiChange => 'Change';

  @override
  String get guestWifiWarning =>
      'Enter the guest network only: anyone who opens this screen sees the code and password. The password is kept in the device\'s protected storage and never leaves it.';

  @override
  String get guestWifiSsid => 'Network name (SSID)';

  @override
  String get guestWifiPassword => 'Password';

  @override
  String get guestWifiPasswordHint => 'At least 8 characters';

  @override
  String get guestWifiOpen => 'Network without a password';

  @override
  String get guestWifiHidden => 'Hidden network';

  @override
  String get guestWifiRemove => 'Remove';

  @override
  String airAdviceTitle(String place) {
    return 'Air the room: $place';
  }

  @override
  String airAdviceCo2(int ppm) {
    return 'CO2 $ppm ppm — the air is stuffy, open a window for a few minutes';
  }

  @override
  String airAdviceHumidity(int percent) {
    return 'Humidity $percent % — air it so mould doesn\'t settle';
  }

  @override
  String get partyTitle => 'Party';

  @override
  String get partyHint =>
      'Colour lights cycle through colours while the party is on. Afterwards they all go back to how they were.';

  @override
  String get partyNoLights =>
      'No colour lights — a party needs at least one RGB light.';

  @override
  String get partyMusic => 'Music';

  @override
  String get partyNoMusic => 'No music';

  @override
  String get partyStart => 'Start the party';

  @override
  String get partyOn => 'Party! 🎉';

  @override
  String partyLights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lights dancing',
      one: '1 light dancing',
    );
    return '$_temp0';
  }

  @override
  String get partyStop => 'End the party';

  @override
  String get sunriseTitle => 'Sunrise alarm';

  @override
  String get sunriseHint =>
      'The light comes up slowly before you wake, from a dim warm glow to daylight, like a real sunrise. Runs on this phone or wall panel while the app runs (or with automations in the background).';

  @override
  String get sunriseWakeAt => 'Fully bright at';

  @override
  String sunriseMinutes(int minutes) {
    return 'Sunrise takes $minutes min';
  }

  @override
  String get sunriseLights => 'Lights';

  @override
  String get sunriseSave => 'Turn on the alarm';

  @override
  String get sunriseUpdate => 'Save changes';

  @override
  String get sunriseRemove => 'Turn off the alarm';

  @override
  String sunriseSaved(String time) {
    return 'Sunrise alarm: bright by $time.';
  }

  @override
  String get sunriseRemoved => 'Sunrise alarm turned off.';

  @override
  String birthdayGreeting(String names) {
    return 'Happy birthday, $names!';
  }

  @override
  String get birthdayPick => 'Birthday (day and month)';

  @override
  String get seasonalSetting => 'Seasonal decorations';

  @override
  String get seasonalSettingHint =>
      'Snow from December to Christmas, confetti for New Year and household birthdays, pumpkins before Halloween. Stops while the screen is dimmed.';

  @override
  String get bedtimeTitle => 'Bedtime story';

  @override
  String get bedtimeHint =>
      'The tablet or phone reads a short story while the lights in the chosen room slowly go down.';

  @override
  String get bedtimeLights => 'Lights to dim';

  @override
  String get bedtimeNoLights => 'No lights';

  @override
  String get bedtimeAloud => 'Read aloud';

  @override
  String bedtimeMinutes(int minutes) {
    return 'about $minutes min';
  }

  @override
  String get bedtimeNext => 'Next';

  @override
  String get bedtimeEnd => 'The end';

  @override
  String get bedtimeGoodNight => 'Good night. 🌙';

  @override
  String get themeOled => 'Pure black dark theme';

  @override
  String get themeOledHint =>
      'For AMOLED screens: black pixels switch off — saves battery and does not glow in the dark.';

  @override
  String get paletteHint => 'Room, device or scene…';

  @override
  String get paletteEmpty =>
      'Type part of a name — e.g. \"kit\" for the kitchen.';

  @override
  String get paletteNothing => 'Nothing matches.';

  @override
  String get paletteRoom => 'Room';

  @override
  String get paletteKeys => 'Enter: run or switch · ↑↓ choose · Esc close';

  @override
  String get paletteTooltip => 'Search (Ctrl+K)';

  @override
  String get simpleTitle => 'Simple mode';

  @override
  String get simpleHint =>
      'Just a few big buttons and large text, no menus — e.g. on grandparents\' tablet.';

  @override
  String simpleChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buttons',
      one: '1 button',
    );
    return '$_temp0';
  }

  @override
  String get simpleChoose => 'Choose';

  @override
  String simpleChooseTitle(int max) {
    return 'Buttons (at most $max)';
  }

  @override
  String get simpleStartMode => 'Start simple mode';

  @override
  String get simpleEmpty =>
      'No buttons yet. Leave (the lock at the top right) and choose them in Settings.';

  @override
  String get simpleOn => 'On';

  @override
  String get simpleOff => 'Off';

  @override
  String get simpleStart => 'Start';

  @override
  String get simpleLeave => 'Leave simple mode';

  @override
  String get simpleLeaveTitle => 'Leave simple mode?';

  @override
  String get simpleLeaveBody => 'The full app with all its menus comes back.';

  @override
  String get floorPlanTitle => 'Floor plan';

  @override
  String get floorPlanEmpty =>
      'Load a picture of your home\'s plan (a drawing or a photo of it), then place devices on it. A tap on a device on the plan switches it.';

  @override
  String get floorPlanPick => 'Choose the plan picture';

  @override
  String get floorPlanEdit => 'Edit';

  @override
  String get floorPlanAdd => 'Add a device';

  @override
  String get floorPlanChangePhoto => 'Another picture';

  @override
  String get floorPlanEditHint => 'Drag the devices to their places.';

  @override
  String get floorPlanUnsupported =>
      'The floor plan is kept on the device, so it is not available on the web.';

  @override
  String get widgetHomeTitle => 'Home';

  @override
  String get widgetLightsOff => '💡 All lights off';

  @override
  String widgetLightsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '💡 $count lights on',
      one: '💡 1 light on',
    );
    return '$_temp0';
  }

  @override
  String get widgetAllClosed => '🚪 All closed';

  @override
  String widgetOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🚪 $count open',
      one: '🚪 1 open',
    );
    return '$_temp0';
  }

  @override
  String get widgetLocked => '🔒 Locked';

  @override
  String widgetUnlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔓 $count unlocked',
      one: '🔓 1 unlocked',
    );
    return '$_temp0';
  }

  @override
  String widgetUpdated(String time) {
    return 'Updated at $time';
  }

  @override
  String widgetNow(String temperature) {
    return 'Now $temperature';
  }

  @override
  String get widgetSettingsTitle => 'Home screen widgets';

  @override
  String get widgetSettingsHint =>
      'Add \"Home\", \"Thermostat\" and \"Light\" with a long press on the phone\'s home screen → Widgets. They refresh while the app runs.';

  @override
  String get widgetThermostat => 'Thermostat on the widget';

  @override
  String get widgetLight => 'Light on the widget';

  @override
  String get nowPlayingSetting => 'Music in the notifications';

  @override
  String get nowPlayingSettingHint =>
      'While a speaker at home plays, the notifications show the title with pause and next — without opening the app. Works while the app runs (also in the background, if the background connection is on).';

  @override
  String get nowPlayingPause => 'Pause';

  @override
  String get nowPlayingPlay => 'Play';

  @override
  String get nowPlayingNext => 'Next';

  @override
  String get nowPlayingChannel => 'Now playing';

  @override
  String get simpleWarmer => 'Warmer';

  @override
  String get simpleCooler => 'Cooler';

  @override
  String get settingsHomeSection => 'Home';

  @override
  String get settingsHomeHint => 'Devices and rooms';

  @override
  String get firstRunWelcomeBodyLite =>
      'The phone controls your devices itself, no server needed. Let\'s set the app up — it takes a minute, and everything can be changed later in Settings.';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsAboutHint => 'Version and updates';

  @override
  String get addDeviceLanHint =>
      'Shelly, WLED, ESPHome, Hue, Yeelight and Kasa devices on the same Wi-Fi network as the phone show up here by themselves. Add Tasmota devices by their IP address.';

  @override
  String get addDeviceSearching => 'Looking for devices…';

  @override
  String get addDeviceNoneYet =>
      'Nothing yet. Check that the phone is on the same Wi-Fi network as the device, or enter its IP address.';

  @override
  String get addDeviceManual => 'Enter IP address';

  @override
  String get addDeviceAddressLabel => 'Device IP address';

  @override
  String get addDeviceNotFound => 'No supported device found at that address.';

  @override
  String get addDeviceAdded => 'Added';

  @override
  String get addDeviceAdd => 'Add';

  @override
  String addDeviceDone(String name) {
    return '$name added.';
  }

  @override
  String get addDeviceWhere => 'Which room?';

  @override
  String get roomNew => 'New room…';

  @override
  String get roomNameLabel => 'Room name';

  @override
  String get roomDelete => 'Delete room';

  @override
  String roomDeleteConfirm(String name) {
    return 'Delete the room $name? Its devices stay, without a room.';
  }

  @override
  String get deviceRemove => 'Remove device';

  @override
  String deviceRemoveConfirm(String name) {
    return 'Remove $name from the app? The device keeps working.';
  }

  @override
  String get homeDevicesTitle => 'Devices';

  @override
  String get devicePasswordLabel => 'Device password';

  @override
  String get devicePasswordHint =>
      'This device asks for a password (user admin). It is kept only on this phone, in secure storage.';

  @override
  String get devicePasswordChange => 'Device password…';

  @override
  String get deviceKeyLabel => 'Encryption key';

  @override
  String get deviceKeyHint =>
      'This ESPHome device encrypts its connection. Enter the key from its YAML (api → encryption → key). It is kept only on this phone, in secure storage.';

  @override
  String get deviceKeyWrong =>
      'That key is not right. Check it in the device\'s YAML.';

  @override
  String get deviceKeyNotEncrypted =>
      'This device does not encrypt its connection; leave the key empty.';

  @override
  String get hueLinkTitle => 'Pairing with the Hue bridge';

  @override
  String get hueLinkBody =>
      'Press the round button on top of the Hue bridge. The app waits 30 seconds.';

  @override
  String get hueLinkFailed =>
      'The bridge\'s button was not pressed. Try again.';

  @override
  String get sceneHintLocal =>
      'Keeps how the chosen devices are set now (on/off, brightness, colour, blinds, temperature). Running the scene sets them so again.';

  @override
  String get sceneSavedLocal => 'Scene saved.';

  @override
  String get autoSavedLocal => 'Automation saved.';

  @override
  String get autoHintLocal =>
      'Runs on this phone: while the app is open, on a wall panel in kiosk mode, or with running in the background on (Settings → Home).';

  @override
  String get autoSunNeedsHome =>
      'Sunrise and sunset need the home\'s location: turn on the home forecast (Settings → Privacy).';

  @override
  String get autoActionTurnOn => 'Turn on';

  @override
  String get autoActionTurnOff => 'Turn off';

  @override
  String get autoActionToggle => 'Toggle';

  @override
  String autoActionBrightness(int percent) {
    return 'Brightness $percent %';
  }

  @override
  String get autoActionScene => 'Run scene';

  @override
  String get autoPickAction => 'What to do';

  @override
  String autoTriggerAt(String time) {
    return 'At $time';
  }

  @override
  String get autoDays => 'Days';

  @override
  String autoStateIs(String device, String state) {
    return '$device: $state';
  }

  @override
  String autoValueAbove(String device, String value) {
    return '$device above $value';
  }

  @override
  String autoValueBelow(String device, String value) {
    return '$device below $value';
  }

  @override
  String get autoTargetOn => 'on';

  @override
  String get autoTargetOff => 'off';

  @override
  String get autoTargetOpen => 'open';

  @override
  String get autoTargetClosed => 'closed';

  @override
  String get autoTargetActive => 'active';

  @override
  String get autoTargetInactive => 'inactive';

  @override
  String get autoTargetLocked => 'locked';

  @override
  String get autoTargetUnlocked => 'unlocked';

  @override
  String get autoBefore => 'before';

  @override
  String get autoAfter => 'after';

  @override
  String get backgroundAutomations => 'Automations in the background';

  @override
  String get backgroundAutomationsHint =>
      'The app keeps running when closed, so automations work. Android then shows a permanent notification.';

  @override
  String get backgroundNotificationText => 'Automations are running';

  @override
  String get sceneEdit => 'Edit scene';

  @override
  String get bleNearbyTitle => 'Bluetooth sensors nearby';

  @override
  String get bleNearbyHint =>
      'Thermometers and door, motion and leak sensors that send their values over Bluetooth (BTHome, Shelly BLU, Xiaomi with pvvx/ATC firmware, SwitchBot Meter, Govee). The phone only listens, it does not connect.';

  @override
  String get blePermission => 'Allow Bluetooth';

  @override
  String get blePermissionHint =>
      'Bluetooth sensors need the nearby devices permission.';

  @override
  String get bleOff =>
      'Bluetooth is off. Turn it on for the sensors to show up.';

  @override
  String get bleNoneYet =>
      'Nothing yet. Sensors call in every few seconds to a minute.';

  @override
  String get backupWithSecrets => 'With the devices\' passwords and keys';

  @override
  String get backupWithSecretsHint =>
      'Encrypted with a password you choose; without it nobody can read them.';

  @override
  String get backupPassword => 'Backup password';

  @override
  String get backupPasswordShort => 'At least 6 characters.';

  @override
  String get backupSaveFile => 'Save to a file';

  @override
  String get backupOpenFile => 'Load from a file';

  @override
  String get backupSend => 'Send to another device';

  @override
  String get backupReceive => 'Receive from another device';

  @override
  String get backupSendTitle =>
      'On the other device choose “Receive from another device” and enter:';

  @override
  String get backupAddress => 'Address';

  @override
  String get backupCode => 'Code';

  @override
  String get backupSendWaiting =>
      'Waiting for the other device (5 minutes at most). Both have to be on the same Wi-Fi.';

  @override
  String get backupSent => 'Sent.';

  @override
  String get backupUnreachable =>
      'The other device does not answer. Check the address and that both are on the same Wi-Fi.';

  @override
  String get backupWrongCode => 'That code is not right.';

  @override
  String get backupNoWifi => 'This device is not on a Wi-Fi network.';

  @override
  String get backupHowTitle => 'How to import?';

  @override
  String get backupReplace => 'Replace all';

  @override
  String get backupReplaceHint =>
      'The devices, rooms, scenes and automations here are replaced by the backup\'s.';

  @override
  String get backupMerge => 'Add only what is new';

  @override
  String get backupMergeHint =>
      'Everything here stays; what is missing is added.';

  @override
  String get backupAskPassword =>
      'This backup has the devices\' passwords and keys. Enter the password it was made with.';

  @override
  String get backupWrongPassword => 'That password is not right.';

  @override
  String linkTitle(String brand) {
    return 'Pairing: $brand';
  }

  @override
  String get linkFailed => 'Pairing did not work. Try again.';

  @override
  String get nanoleafLinkBody =>
      'Hold the power button on the Nanoleaf for 5–7 seconds, until the lights flash. The app waits 30 seconds.';

  @override
  String get tvLinkBody =>
      'The TV asks whether the app may connect: choose Allow. The app waits 30 seconds.';

  @override
  String get dirigeraLinkBody =>
      'Press the action button on the back of the DIRIGERA hub. The app waits 30 seconds.';

  @override
  String get tpLinkAccountHint =>
      'A Tapo device checks the TP-Link account on the device itself: enter the e-mail and password of the account it was added to. Nothing is sent to TP-Link.';

  @override
  String get tpLinkUserLabel => 'TP-Link account e-mail';

  @override
  String get tpLinkWrongAccount =>
      'The device does not accept this e-mail and password.';

  @override
  String get tuyaKeyHint =>
      'A Tuya device (Smart Life, Tuya Smart…) needs its local key, 16 characters. It is taken once from the Tuya account (e.g. with the tinytuya wizard); after that the app talks to the device directly.';

  @override
  String get miioTokenHint =>
      'A Xiaomi device needs its token, 32 characters. It is taken once from the Mi Home account (e.g. with Xiaomi Cloud Tokens Extractor).';

  @override
  String get deviceTokenLabel => 'Local key / token';

  @override
  String get deviceTokenWrong => 'The device does not accept this key.';

  @override
  String get irButtonsTitle => 'Remote buttons';

  @override
  String get irButtonsEmpty =>
      'No buttons learned yet. Learn them from the original remote.';

  @override
  String get irLearn => 'Learn a button';

  @override
  String get irLearnName => 'Button name (e.g. AC on)';

  @override
  String get irLearnPress =>
      'Point the original remote at the device and press the button. Waiting 20 seconds.';

  @override
  String get irLearnFailed =>
      'The device did not hear the button. Try again, closer.';

  @override
  String irLearned(String name) {
    return 'Button \"$name\" learned.';
  }

  @override
  String get irSend => 'Send';

  @override
  String get irDelete => 'Delete button';

  @override
  String get cameraAdd => 'Add a camera';

  @override
  String get cameraUrlLabel => 'Camera image address';

  @override
  String get cameraUrlHint =>
      'A camera serves its current image at an address of its own. For example: Reolink /cgi-bin/api.cgi?cmd=Snap&channel=0, Hikvision /ISAPI/Streaming/channels/101/picture, Dahua /cgi-bin/snapshot.cgi, ESP32-CAM /capture.';

  @override
  String get cameraUserLabel => 'User (if the camera asks)';

  @override
  String get cameraNoImage =>
      'There is no camera image at this address (or the user is wrong).';

  @override
  String get cameraOffline => 'The camera is not giving an image right now.';

  @override
  String get emptyHomeTitle => 'No devices yet';

  @override
  String get emptyHomeBody =>
      'Add devices from your home Wi-Fi or over Bluetooth: Shelly, Hue, WiZ, Tapo, Tuya, ESPHome, TVs and more.';

  @override
  String get householdAdd => 'Add a member';

  @override
  String get householdName => 'Name';

  @override
  String get householdRemove => 'Remove member';

  @override
  String get personMember => 'Member';

  @override
  String get setupHelpTitle => 'Device not showing up?';

  @override
  String get setupHelpHint =>
      'The phone and the device must be on the same Wi-Fi. What else is needed, by maker:';

  @override
  String get tipShelly =>
      'Works as is. If the device has a password (Restrict login), enter it when adding.';

  @override
  String get tipWled => 'Works as is.';

  @override
  String get tipTasmota =>
      'Usually does not announce itself: add it by its IP address.';

  @override
  String get tipEsphome =>
      'The device\'s configuration needs api:. With encryption on (api: encryption: key), enter that key.';

  @override
  String get tipHue =>
      'Add the Hue bridge; when pairing, press the round button on top of it. The bridge\'s lights and sensors come with it.';

  @override
  String get tipYeelight =>
      'In the Yeelight app, turn on \"LAN Control\" for each bulb.';

  @override
  String get tipWiz =>
      'In the WiZ app, local communication must be allowed (Settings → Security → Allow local communication).';

  @override
  String get tipLifx => 'Works as is.';

  @override
  String get tipGovee =>
      'In the Govee app, turn on \"LAN Control\" in the device\'s settings. Not every model has it.';

  @override
  String get tipNanoleaf =>
      'When pairing, hold the power button for 5–7 seconds, until the lights flash.';

  @override
  String get tipSonoff =>
      'Works in DIY mode only: turn it on in the eWeLink app or with the device\'s DIY switch.';

  @override
  String get tipTpLink =>
      'Older Kasa devices work as is. Tapo and newer Kasa need the TP-Link account\'s e-mail and password; add them by IP address.';

  @override
  String get tipDirigera =>
      'When pairing, press the action button on the back of the hub. The hub\'s IKEA devices come with it.';

  @override
  String get tipTuya =>
      'Needs the device\'s local key (16 characters), taken once from the Tuya account, e.g. with the tinytuya wizard. Devices on protocol 3.5 do not work yet.';

  @override
  String get tipXiaomi =>
      'Needs the device\'s token (32 characters), e.g. from Xiaomi Cloud Tokens Extractor. Plugs and lights (MIoT), Chuangmi plugs and Roborock vacuums work.';

  @override
  String get tipBroadlink =>
      'In the Broadlink app the device must be unlocked (Unlock device); then learn buttons on the device\'s screen.';

  @override
  String get tipSamsung =>
      'On the first connection choose Allow on the TV. To turn it on from the phone, enable \"Power On with Mobile\" (or IP Remote) in the TV\'s settings.';

  @override
  String get tipLg =>
      'On the first connection accept on the TV. To turn it on from the phone, enable \"Turn on via Wi-Fi\" (Mobile TV On).';

  @override
  String get tipRoku =>
      'In the Roku\'s settings (System → Advanced system settings → Control by mobile apps) allow network access.';

  @override
  String get tipSonos => 'Works as is.';

  @override
  String get tipCamera =>
      'The \"Add a camera\" button: the camera\'s image address (examples in the dialog) and a user, if the camera asks.';

  @override
  String get tipBluetooth =>
      'The phone must be near (up to ~10 m). BTHome (Shelly BLU), Xiaomi with pvvx/ATC firmware, SwitchBot and Govee thermometers work; encrypted BTHome and Xiaomi MiBeacon do not.';

  @override
  String get tipUnavailable => 'The device is not answering right now.';

  @override
  String get backupTransferLocked =>
      'The transfer was stopped: a wrong code was entered three times. Send again.';

  @override
  String get blePermissionDenied =>
      'Android did not allow Bluetooth. Allow \"Nearby devices\" in the app\'s settings.';

  @override
  String get openAppSettings => 'Settings';
}
