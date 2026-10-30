import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sr'),
    Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Smart Home Lite'**
  String get appTitle;

  /// No description provided for @mockModeBanner.
  ///
  /// In en, this message translates to:
  /// **'MOCK MODE — demo data, no real devices'**
  String get mockModeBanner;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageSerbian.
  ///
  /// In en, this message translates to:
  /// **'Srpski'**
  String get languageSerbian;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'The device cannot be reached. Check that it is on and that the phone is on the same Wi-Fi.'**
  String get failureNetwork;

  /// No description provided for @failureTimeout.
  ///
  /// In en, this message translates to:
  /// **'The device took too long to answer.'**
  String get failureTimeout;

  /// No description provided for @failureAuthentication.
  ///
  /// In en, this message translates to:
  /// **'The device refused the password, key or token. Check it in Settings → Home.'**
  String get failureAuthentication;

  /// No description provided for @failureAuthorization.
  ///
  /// In en, this message translates to:
  /// **'This user is not allowed to perform this action.'**
  String get failureAuthorization;

  /// No description provided for @failureValidation.
  ///
  /// In en, this message translates to:
  /// **'The device did not accept the command.'**
  String get failureValidation;

  /// No description provided for @failureParsing.
  ///
  /// In en, this message translates to:
  /// **'The device sent an unexpected answer.'**
  String get failureParsing;

  /// No description provided for @failureServer.
  ///
  /// In en, this message translates to:
  /// **'The device reported an error.'**
  String get failureServer;

  /// No description provided for @failureCertificate.
  ///
  /// In en, this message translates to:
  /// **'The secure connection could not be verified (certificate problem).'**
  String get failureCertificate;

  /// No description provided for @failureUnavailableEntity.
  ///
  /// In en, this message translates to:
  /// **'This device is currently unavailable.'**
  String get failureUnavailableEntity;

  /// No description provided for @failureUnsupportedFeature.
  ///
  /// In en, this message translates to:
  /// **'This device does not support this action.'**
  String get failureUnsupportedFeature;

  /// No description provided for @failureWebSocket.
  ///
  /// In en, this message translates to:
  /// **'The live connection was interrupted.'**
  String get failureWebSocket;

  /// No description provided for @failureStorage.
  ///
  /// In en, this message translates to:
  /// **'Secure storage on this device could not be accessed.'**
  String get failureStorage;

  /// No description provided for @failureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get failureUnknown;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all local data'**
  String get deleteAllData;

  /// No description provided for @deleteAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all local data?'**
  String get deleteAllConfirmTitle;

  /// No description provided for @deleteAllConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the home, the devices\' passwords and keys, and all settings from this phone. The devices themselves are not changed.'**
  String get deleteAllConfirmBody;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @privacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacySection;

  /// No description provided for @failureConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm this action.'**
  String get failureConfirmationRequired;

  /// No description provided for @devicesInRooms.
  ///
  /// In en, this message translates to:
  /// **'{devices, plural, =1{1 device} other{{devices} devices}} in {rooms, plural, =0{no rooms} =1{1 room} other{{rooms} rooms}}'**
  String devicesInRooms(int devices, int rooms);

  /// No description provided for @dataStaleSince.
  ///
  /// In en, this message translates to:
  /// **'Not connected — showing data last updated {time}. It may not be current.'**
  String dataStaleSince(String time);

  /// No description provided for @navRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get navRooms;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navScenes.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get navScenes;

  /// No description provided for @stateOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get stateOn;

  /// No description provided for @stateOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get stateOff;

  /// No description provided for @stateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get stateUnavailable;

  /// No description provided for @stateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get stateUnknown;

  /// No description provided for @stateOnBrightness.
  ///
  /// In en, this message translates to:
  /// **'On · {percent} %'**
  String stateOnBrightness(int percent);

  /// No description provided for @motionDetected.
  ///
  /// In en, this message translates to:
  /// **'Motion detected'**
  String get motionDetected;

  /// No description provided for @motionClear.
  ///
  /// In en, this message translates to:
  /// **'No motion'**
  String get motionClear;

  /// No description provided for @occupancyDetected.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get occupancyDetected;

  /// No description provided for @occupancyClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get occupancyClear;

  /// No description provided for @contactOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get contactOpen;

  /// No description provided for @contactClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get contactClosed;

  /// No description provided for @smokeDetected.
  ///
  /// In en, this message translates to:
  /// **'Smoke detected!'**
  String get smokeDetected;

  /// No description provided for @smokeClear.
  ///
  /// In en, this message translates to:
  /// **'No smoke'**
  String get smokeClear;

  /// No description provided for @coDetected.
  ///
  /// In en, this message translates to:
  /// **'CO detected!'**
  String get coDetected;

  /// No description provided for @coClear.
  ///
  /// In en, this message translates to:
  /// **'No CO'**
  String get coClear;

  /// No description provided for @leakDetected.
  ///
  /// In en, this message translates to:
  /// **'Water leak!'**
  String get leakDetected;

  /// No description provided for @leakClear.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get leakClear;

  /// No description provided for @vibrationDetected.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibrationDetected;

  /// No description provided for @vibrationClear.
  ///
  /// In en, this message translates to:
  /// **'Still'**
  String get vibrationClear;

  /// No description provided for @binaryActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get binaryActive;

  /// No description provided for @binaryInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get binaryInactive;

  /// No description provided for @coverOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening…'**
  String get coverOpening;

  /// No description provided for @coverClosing.
  ///
  /// In en, this message translates to:
  /// **'Closing…'**
  String get coverClosing;

  /// No description provided for @coverOpenPercent.
  ///
  /// In en, this message translates to:
  /// **'Open {percent} %'**
  String coverOpenPercent(int percent);

  /// No description provided for @lockLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockLocked;

  /// No description provided for @lockUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get lockUnlocked;

  /// No description provided for @lockLocking.
  ///
  /// In en, this message translates to:
  /// **'Locking…'**
  String get lockLocking;

  /// No description provided for @lockUnlocking.
  ///
  /// In en, this message translates to:
  /// **'Unlocking…'**
  String get lockUnlocking;

  /// No description provided for @lockJammed.
  ///
  /// In en, this message translates to:
  /// **'Jammed!'**
  String get lockJammed;

  /// No description provided for @alarmDisarmed.
  ///
  /// In en, this message translates to:
  /// **'Disarmed'**
  String get alarmDisarmed;

  /// No description provided for @alarmArmed.
  ///
  /// In en, this message translates to:
  /// **'Armed'**
  String get alarmArmed;

  /// No description provided for @alarmArming.
  ///
  /// In en, this message translates to:
  /// **'Arming…'**
  String get alarmArming;

  /// No description provided for @alarmPending.
  ///
  /// In en, this message translates to:
  /// **'Pending…'**
  String get alarmPending;

  /// No description provided for @alarmTriggered.
  ///
  /// In en, this message translates to:
  /// **'ALARM!'**
  String get alarmTriggered;

  /// No description provided for @hvacOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get hvacOff;

  /// No description provided for @hvacHeat.
  ///
  /// In en, this message translates to:
  /// **'Heat'**
  String get hvacHeat;

  /// No description provided for @hvacCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get hvacCool;

  /// No description provided for @hvacHeatCool.
  ///
  /// In en, this message translates to:
  /// **'Heat/Cool'**
  String get hvacHeatCool;

  /// No description provided for @hvacAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get hvacAuto;

  /// No description provided for @hvacDry.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get hvacDry;

  /// No description provided for @hvacFanOnly.
  ///
  /// In en, this message translates to:
  /// **'Fan only'**
  String get hvacFanOnly;

  /// No description provided for @climateStatus.
  ///
  /// In en, this message translates to:
  /// **'{mode} · {temperature}'**
  String climateStatus(String mode, String temperature);

  /// No description provided for @mediaPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get mediaPlaying;

  /// No description provided for @mediaPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get mediaPaused;

  /// No description provided for @cameraIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get cameraIdle;

  /// No description provided for @cameraStreaming.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get cameraStreaming;

  /// No description provided for @cameraRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get cameraRecording;

  /// No description provided for @scriptRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get scriptRunning;

  /// No description provided for @routineReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get routineReady;

  /// No description provided for @doorbellLast.
  ///
  /// In en, this message translates to:
  /// **'Last ring {time}'**
  String doorbellLast(String time);

  /// No description provided for @lowBattery.
  ///
  /// In en, this message translates to:
  /// **'Low battery'**
  String get lowBattery;

  /// No description provided for @batteryLevel.
  ///
  /// In en, this message translates to:
  /// **'Battery {percent} %'**
  String batteryLevel(int percent);

  /// No description provided for @protocolCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get protocolCloud;

  /// No description provided for @protocolVirtual.
  ///
  /// In en, this message translates to:
  /// **'Virtual'**
  String get protocolVirtual;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap the star on a device\'s page to add it to your favorites.'**
  String get favoritesEmpty;

  /// No description provided for @scenesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get scenesTitle;

  /// No description provided for @scriptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scripts'**
  String get scriptsTitle;

  /// No description provided for @automationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Automations'**
  String get automationsTitle;

  /// No description provided for @noScenes.
  ///
  /// In en, this message translates to:
  /// **'No scenes yet.'**
  String get noScenes;

  /// No description provided for @dashboardAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get dashboardAttention;

  /// No description provided for @summaryTemperature.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get summaryTemperature;

  /// No description provided for @summaryHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get summaryHumidity;

  /// No description provided for @summaryLights.
  ///
  /// In en, this message translates to:
  /// **'Lights on'**
  String get summaryLights;

  /// No description provided for @summaryOpenings.
  ///
  /// In en, this message translates to:
  /// **'Doors & windows'**
  String get summaryOpenings;

  /// No description provided for @summaryOpeningsClosed.
  ///
  /// In en, this message translates to:
  /// **'All closed'**
  String get summaryOpeningsClosed;

  /// No description provided for @summaryOpeningsOpen.
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String summaryOpeningsOpen(int count);

  /// No description provided for @summaryPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get summaryPower;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get greetingNight;

  /// No description provided for @summaryAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get summaryAlerts;

  /// No description provided for @valueNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get valueNotAvailable;

  /// No description provided for @lightsOnOf.
  ///
  /// In en, this message translates to:
  /// **'{on} of {total}'**
  String lightsOnOf(int on, int total);

  /// No description provided for @lowBatteryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 low battery} other{{count} low batteries}}'**
  String lowBatteryCount(int count);

  /// No description provided for @unavailableCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unavailable} other{{count} unavailable}}'**
  String unavailableCount(int count);

  /// No description provided for @roomNoRoom.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get roomNoRoom;

  /// No description provided for @allDevices.
  ///
  /// In en, this message translates to:
  /// **'All devices'**
  String get allDevices;

  /// No description provided for @roomDevicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No devices} =1{1 device} other{{count} devices}}'**
  String roomDevicesCount(int count);

  /// No description provided for @roomLightsOn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 light on} other{{count} lights on}}'**
  String roomLightsOn(int count);

  /// No description provided for @roomEmpty.
  ///
  /// In en, this message translates to:
  /// **'No devices in this room.'**
  String get roomEmpty;

  /// No description provided for @noRoomsYet.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet. Add them in Settings → Home.'**
  String get noRoomsYet;

  /// No description provided for @groupLights.
  ///
  /// In en, this message translates to:
  /// **'Lights'**
  String get groupLights;

  /// No description provided for @groupClimate.
  ///
  /// In en, this message translates to:
  /// **'Climate'**
  String get groupClimate;

  /// No description provided for @groupCovers.
  ///
  /// In en, this message translates to:
  /// **'Blinds & doors'**
  String get groupCovers;

  /// No description provided for @groupSwitches.
  ///
  /// In en, this message translates to:
  /// **'Switches & outlets'**
  String get groupSwitches;

  /// No description provided for @groupSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get groupSecurity;

  /// No description provided for @groupSensors.
  ///
  /// In en, this message translates to:
  /// **'Sensors'**
  String get groupSensors;

  /// No description provided for @groupMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get groupMedia;

  /// No description provided for @groupEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get groupEnergy;

  /// No description provided for @groupOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get groupOther;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFavorite;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @colorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Color temperature'**
  String get colorTemperature;

  /// No description provided for @warm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get warm;

  /// No description provided for @cool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get cool;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @targetTemperature.
  ///
  /// In en, this message translates to:
  /// **'Target temperature'**
  String get targetTemperature;

  /// No description provided for @currentTemperature.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentTemperature;

  /// No description provided for @increaseTemperature.
  ///
  /// In en, this message translates to:
  /// **'Increase temperature'**
  String get increaseTemperature;

  /// No description provided for @decreaseTemperature.
  ///
  /// In en, this message translates to:
  /// **'Decrease temperature'**
  String get decreaseTemperature;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @fanMode.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get fanMode;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @confirmUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock {name}?'**
  String confirmUnlockTitle(String name);

  /// No description provided for @confirmOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open {name}?'**
  String confirmOpenTitle(String name);

  /// No description provided for @confirmDisarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Disarm {name}?'**
  String confirmDisarmTitle(String name);

  /// No description provided for @confirmCriticalBody.
  ///
  /// In en, this message translates to:
  /// **'This action affects the security of your home.'**
  String get confirmCriticalBody;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @runNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get runNow;

  /// No description provided for @sceneActivated.
  ///
  /// In en, this message translates to:
  /// **'{name} activated'**
  String sceneActivated(String name);

  /// No description provided for @automationEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get automationEnabled;

  /// No description provided for @lastTriggered.
  ///
  /// In en, this message translates to:
  /// **'Last triggered {time}'**
  String lastTriggered(String time);

  /// No description provided for @neverTriggered.
  ///
  /// In en, this message translates to:
  /// **'Never triggered'**
  String get neverTriggered;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @detailInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get detailInfo;

  /// No description provided for @infoRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get infoRoom;

  /// No description provided for @infoManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get infoManufacturer;

  /// No description provided for @infoModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get infoModel;

  /// No description provided for @infoProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get infoProtocol;

  /// No description provided for @infoLastChanged.
  ///
  /// In en, this message translates to:
  /// **'Last changed'**
  String get infoLastChanged;

  /// No description provided for @infoEntityId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get infoEntityId;

  /// No description provided for @infoSignal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get infoSignal;

  /// No description provided for @infoBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get infoBattery;

  /// No description provided for @deviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'This device no longer exists.'**
  String get deviceNotFound;

  /// No description provided for @unavailableBanner.
  ///
  /// In en, this message translates to:
  /// **'This device is unavailable. Controls are disabled until it reconnects.'**
  String get unavailableBanner;

  /// No description provided for @controlsOffline.
  ///
  /// In en, this message translates to:
  /// **'Controls are available again once the connection is restored.'**
  String get controlsOffline;

  /// No description provided for @kioskSection.
  ///
  /// In en, this message translates to:
  /// **'Kiosk mode (wall tablet)'**
  String get kioskSection;

  /// No description provided for @kioskStart.
  ///
  /// In en, this message translates to:
  /// **'Start kiosk mode'**
  String get kioskStart;

  /// No description provided for @kioskStartOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Open in kiosk mode on launch'**
  String get kioskStartOnLaunch;

  /// No description provided for @kioskKeepAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get kioskKeepAwake;

  /// No description provided for @kioskDimAfter.
  ///
  /// In en, this message translates to:
  /// **'Dim screen after'**
  String get kioskDimAfter;

  /// No description provided for @kioskReturnAfter.
  ///
  /// In en, this message translates to:
  /// **'Return to dashboard after'**
  String get kioskReturnAfter;

  /// No description provided for @kioskPin.
  ///
  /// In en, this message translates to:
  /// **'Exit PIN'**
  String get kioskPin;

  /// No description provided for @kioskPinSet.
  ///
  /// In en, this message translates to:
  /// **'PIN is set'**
  String get kioskPinSet;

  /// No description provided for @kioskPinNotSet.
  ///
  /// In en, this message translates to:
  /// **'No PIN — anyone can leave kiosk mode'**
  String get kioskPinNotSet;

  /// No description provided for @kioskSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get kioskSetPin;

  /// No description provided for @kioskChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get kioskChangePin;

  /// No description provided for @kioskRemovePin.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get kioskRemovePin;

  /// No description provided for @kioskPinHint.
  ///
  /// In en, this message translates to:
  /// **'4–8 digits'**
  String get kioskPinHint;

  /// No description provided for @kioskPinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Repeat PIN'**
  String get kioskPinConfirm;

  /// No description provided for @kioskPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs do not match.'**
  String get kioskPinMismatch;

  /// No description provided for @kioskPinInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 4–8 digits.'**
  String get kioskPinInvalid;

  /// No description provided for @kioskExit.
  ///
  /// In en, this message translates to:
  /// **'Exit kiosk mode'**
  String get kioskExit;

  /// No description provided for @kioskEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get kioskEnterPin;

  /// No description provided for @kioskWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN.'**
  String get kioskWrongPin;

  /// No description provided for @kioskLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} s.'**
  String kioskLockedOut(int seconds);

  /// No description provided for @kioskOsHint.
  ///
  /// In en, this message translates to:
  /// **'For a fully locked wall panel also use the system\'s kiosk feature: Android screen pinning or a kiosk launcher, iOS Guided Access. They can also start the app automatically.'**
  String get kioskOsHint;

  /// No description provided for @durationNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get durationNever;

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(int seconds);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @dataUpdating.
  ///
  /// In en, this message translates to:
  /// **'Showing data from {time} — updating…'**
  String dataUpdating(String time);

  /// No description provided for @energyConsumption.
  ///
  /// In en, this message translates to:
  /// **'Home consumption'**
  String get energyConsumption;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @weatherClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get weatherClear;

  /// No description provided for @weatherClearNight.
  ///
  /// In en, this message translates to:
  /// **'Clear night'**
  String get weatherClearNight;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherCloudy.
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get weatherCloudy;

  /// No description provided for @weatherFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weatherFog;

  /// No description provided for @weatherRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherRain;

  /// No description provided for @weatherHeavyRain.
  ///
  /// In en, this message translates to:
  /// **'Heavy rain'**
  String get weatherHeavyRain;

  /// No description provided for @weatherSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weatherSnow;

  /// No description provided for @weatherSleet.
  ///
  /// In en, this message translates to:
  /// **'Sleet'**
  String get weatherSleet;

  /// No description provided for @weatherHail.
  ///
  /// In en, this message translates to:
  /// **'Hail'**
  String get weatherHail;

  /// No description provided for @weatherThunderstorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherThunderstorm;

  /// No description provided for @weatherWindy.
  ///
  /// In en, this message translates to:
  /// **'Windy'**
  String get weatherWindy;

  /// No description provided for @weatherExceptional.
  ///
  /// In en, this message translates to:
  /// **'Severe weather'**
  String get weatherExceptional;

  /// No description provided for @weatherAtHome.
  ///
  /// In en, this message translates to:
  /// **'Weather at home'**
  String get weatherAtHome;

  /// No description provided for @weatherAtMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Weather at my location'**
  String get weatherAtMyLocation;

  /// No description provided for @weatherEnableDevice.
  ///
  /// In en, this message translates to:
  /// **'Weather at my location'**
  String get weatherEnableDevice;

  /// No description provided for @weatherEnableDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get weatherEnableDeviceConfirm;

  /// No description provided for @weatherDeviceDisclosure.
  ///
  /// In en, this message translates to:
  /// **'The app will ask for your approximate location (not precise GPS), round it to about 1 km and send it to MET Norway (api.met.no) to get the forecast – about every 30 minutes while the app is open. Nothing else is sent. You can turn this off anytime in Settings → Privacy & data.'**
  String get weatherDeviceDisclosure;

  /// No description provided for @weatherDeviceSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Approximate location is sent to MET Norway. Off by default.'**
  String get weatherDeviceSettingHint;

  /// No description provided for @weatherMetAttribution.
  ///
  /// In en, this message translates to:
  /// **'Data: MET Norway (CC BY 4.0)'**
  String get weatherMetAttribution;

  /// No description provided for @weatherLocationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location access is blocked for this app.'**
  String get weatherLocationDeniedForever;

  /// No description provided for @weatherOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get weatherOpenSettings;

  /// No description provided for @weatherLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off on this device.'**
  String get weatherLocationOff;

  /// No description provided for @weatherLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access was not allowed.'**
  String get weatherLocationDenied;

  /// No description provided for @weatherDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weather for your location is not available right now.'**
  String get weatherDeviceUnavailable;

  /// No description provided for @weatherWind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get weatherWind;

  /// No description provided for @summaryOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get summaryOutdoor;

  /// No description provided for @presetNone.
  ///
  /// In en, this message translates to:
  /// **'No preset'**
  String get presetNone;

  /// No description provided for @presetHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get presetHome;

  /// No description provided for @presetAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get presetAway;

  /// No description provided for @presetSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get presetSleep;

  /// No description provided for @presetEco.
  ///
  /// In en, this message translates to:
  /// **'Eco'**
  String get presetEco;

  /// No description provided for @presetComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get presetComfort;

  /// No description provided for @presetBoost.
  ///
  /// In en, this message translates to:
  /// **'Boost'**
  String get presetBoost;

  /// No description provided for @presetActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get presetActivity;

  /// No description provided for @powerToggle.
  ///
  /// In en, this message translates to:
  /// **'On/off'**
  String get powerToggle;

  /// No description provided for @personHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get personHome;

  /// No description provided for @personAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get personAway;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @weatherForecastTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather forecast'**
  String get weatherForecastTitle;

  /// No description provided for @weatherHourly.
  ///
  /// In en, this message translates to:
  /// **'Next hours'**
  String get weatherHourly;

  /// No description provided for @weatherDaily.
  ///
  /// In en, this message translates to:
  /// **'Next days'**
  String get weatherDaily;

  /// No description provided for @weatherToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get weatherToday;

  /// No description provided for @weatherNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get weatherNow;

  /// No description provided for @weatherNoForecast.
  ///
  /// In en, this message translates to:
  /// **'No forecast for the home yet. Turn it on in Settings → Privacy.'**
  String get weatherNoForecast;

  /// No description provided for @weatherFeelsHint.
  ///
  /// In en, this message translates to:
  /// **'MET Norway\'s forecast for the home\'s location.'**
  String get weatherFeelsHint;

  /// No description provided for @mediaPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play or pause'**
  String get mediaPlayPause;

  /// No description provided for @mediaNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get mediaNext;

  /// No description provided for @mediaPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get mediaPrevious;

  /// No description provided for @addDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get addDeviceTitle;

  /// No description provided for @setUpDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Name and room'**
  String get setUpDeviceTitle;

  /// No description provided for @deviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get deviceNameLabel;

  /// No description provided for @deviceRoomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get deviceRoomLabel;

  /// No description provided for @setUpSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get setUpSaved;

  /// No description provided for @weatherHomeLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Forecast for your home'**
  String get weatherHomeLocationTitle;

  /// No description provided for @weatherHomeLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Turn the forecast on: the app will remember this phone\'s approximate location as the home location.'**
  String get weatherHomeLocationHint;

  /// No description provided for @weatherHomeLocationEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on forecast'**
  String get weatherHomeLocationEnable;

  /// No description provided for @weatherHomeLocationDisclosure.
  ///
  /// In en, this message translates to:
  /// **'The app will take this phone\'s approximate location once (rounded to about 1 km) as the home location and send it to MET Norway (api.met.no) every 30 minutes. Nothing else is sent. You can turn it off in Settings.'**
  String get weatherHomeLocationDisclosure;

  /// No description provided for @weatherHomeLocationSetting.
  ///
  /// In en, this message translates to:
  /// **'Forecast for the home location (MET Norway)'**
  String get weatherHomeLocationSetting;

  /// No description provided for @weatherHomeLocationSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Sends the home\'s approximate location (saved when you turned the forecast on).'**
  String get weatherHomeLocationSettingHint;

  /// No description provided for @mediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Music and media'**
  String get mediaTitle;

  /// No description provided for @mediaNoPlayers.
  ///
  /// In en, this message translates to:
  /// **'No speakers or TVs yet. Add a Sonos, Roku, Samsung or LG TV with \"Add device\" and it shows up here.'**
  String get mediaNoPlayers;

  /// No description provided for @mediaSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get mediaSource;

  /// No description provided for @mediaIdle.
  ///
  /// In en, this message translates to:
  /// **'Not playing'**
  String get mediaIdle;

  /// No description provided for @mediaNoPlayersShort.
  ///
  /// In en, this message translates to:
  /// **'No media players yet'**
  String get mediaNoPlayersShort;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Smart Home is locked'**
  String get appLockTitle;

  /// No description provided for @appUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appUnlock;

  /// No description provided for @appLockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Open Smart Home'**
  String get appLockReason;

  /// No description provided for @appLockCriticalReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm: {device}'**
  String appLockCriticalReason(String device);

  /// No description provided for @securitySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securitySection;

  /// No description provided for @appLockSetting.
  ///
  /// In en, this message translates to:
  /// **'Lock the app'**
  String get appLockSetting;

  /// No description provided for @appLockSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Ask for fingerprint, face or the device PIN when opening the app (after 1 minute in the background).'**
  String get appLockSettingHint;

  /// No description provided for @appLockCriticalSetting.
  ///
  /// In en, this message translates to:
  /// **'Confirm locks and alarm'**
  String get appLockCriticalSetting;

  /// No description provided for @appLockCriticalSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Also ask before unlocking doors, opening the garage or disarming the alarm.'**
  String get appLockCriticalSettingHint;

  /// No description provided for @alarmArm_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get alarmArm_home;

  /// No description provided for @alarmArm_away.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get alarmArm_away;

  /// No description provided for @alarmArm_night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get alarmArm_night;

  /// No description provided for @alarmArm_vacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get alarmArm_vacation;

  /// No description provided for @alarmArm_custom_bypass.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get alarmArm_custom_bypass;

  /// No description provided for @alarmArmTitle.
  ///
  /// In en, this message translates to:
  /// **'Arm'**
  String get alarmArmTitle;

  /// No description provided for @alarmDisarm.
  ///
  /// In en, this message translates to:
  /// **'Disarm'**
  String get alarmDisarm;

  /// No description provided for @alarmCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm code'**
  String get alarmCodeTitle;

  /// No description provided for @vacuumCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get vacuumCleaning;

  /// No description provided for @vacuumDocked.
  ///
  /// In en, this message translates to:
  /// **'Docked'**
  String get vacuumDocked;

  /// No description provided for @vacuumReturning.
  ///
  /// In en, this message translates to:
  /// **'Returning to dock'**
  String get vacuumReturning;

  /// No description provided for @vacuumPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get vacuumPaused;

  /// No description provided for @vacuumError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get vacuumError;

  /// No description provided for @vacuumIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get vacuumIdle;

  /// No description provided for @vacuumStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get vacuumStart;

  /// No description provided for @vacuumPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get vacuumPause;

  /// No description provided for @vacuumReturnHome.
  ///
  /// In en, this message translates to:
  /// **'Dock'**
  String get vacuumReturnHome;

  /// No description provided for @fanSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get fanSpeed;

  /// No description provided for @fanOscillate.
  ///
  /// In en, this message translates to:
  /// **'Oscillate'**
  String get fanOscillate;

  /// No description provided for @targetHumidityLabel.
  ///
  /// In en, this message translates to:
  /// **'Target humidity'**
  String get targetHumidityLabel;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modeLabel;

  /// No description provided for @valueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get valueLabel;

  /// No description provided for @editDevice.
  ///
  /// In en, this message translates to:
  /// **'Edit name and room'**
  String get editDevice;

  /// No description provided for @deviceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, room or type'**
  String get deviceSearchHint;

  /// No description provided for @deviceSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No device matches.'**
  String get deviceSearchEmpty;

  /// No description provided for @favoritesReorder.
  ///
  /// In en, this message translates to:
  /// **'Change order'**
  String get favoritesReorder;

  /// No description provided for @restrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Child / guest mode'**
  String get restrictedTitle;

  /// No description provided for @restrictedHint.
  ///
  /// In en, this message translates to:
  /// **'Hides sensitive devices and locks settings with a PIN on this device.'**
  String get restrictedHint;

  /// No description provided for @restrictedHideSecurity.
  ///
  /// In en, this message translates to:
  /// **'Hide locks, alarm and garage doors'**
  String get restrictedHideSecurity;

  /// No description provided for @restrictedHideCameras.
  ///
  /// In en, this message translates to:
  /// **'Hide cameras'**
  String get restrictedHideCameras;

  /// No description provided for @restrictedEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on (set a PIN)'**
  String get restrictedEnable;

  /// No description provided for @restrictedActive.
  ///
  /// In en, this message translates to:
  /// **'Child / guest mode is on'**
  String get restrictedActive;

  /// No description provided for @restrictedDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn off (PIN)'**
  String get restrictedDisable;

  /// No description provided for @restrictedHidden.
  ///
  /// In en, this message translates to:
  /// **'Not available in child / guest mode.'**
  String get restrictedHidden;

  /// No description provided for @autoNew.
  ///
  /// In en, this message translates to:
  /// **'New automation'**
  String get autoNew;

  /// No description provided for @autoWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get autoWhen;

  /// No description provided for @autoThen.
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get autoThen;

  /// No description provided for @autoName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get autoName;

  /// No description provided for @autoTriggerTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get autoTriggerTime;

  /// No description provided for @autoTriggerDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get autoTriggerDevice;

  /// No description provided for @autoTriggerSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get autoTriggerSun;

  /// No description provided for @autoEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get autoEveryDay;

  /// No description provided for @autoSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get autoSunrise;

  /// No description provided for @autoSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get autoSunset;

  /// No description provided for @autoOffset.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =0{Exactly at the time} other{{minutes} min}}'**
  String autoOffset(int minutes);

  /// No description provided for @autoPickDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose a device'**
  String get autoPickDevice;

  /// No description provided for @autoAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add an action'**
  String get autoAddAction;

  /// No description provided for @autoDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete automation'**
  String get autoDelete;

  /// No description provided for @autoDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This can\'t be undone.'**
  String autoDeleteConfirm(String name);

  /// No description provided for @autoIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Choose when it runs and at least one action.'**
  String get autoIncomplete;

  /// No description provided for @autoNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Hallway light at night'**
  String get autoNameHint;

  /// No description provided for @svc_activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get svc_activate;

  /// No description provided for @allLightsOn.
  ///
  /// In en, this message translates to:
  /// **'All on'**
  String get allLightsOn;

  /// No description provided for @allLightsOff.
  ///
  /// In en, this message translates to:
  /// **'All off'**
  String get allLightsOff;

  /// No description provided for @allLightsTitle.
  ///
  /// In en, this message translates to:
  /// **'All lights in the home'**
  String get allLightsTitle;

  /// No description provided for @floorOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get floorOther;

  /// No description provided for @sceneNew.
  ///
  /// In en, this message translates to:
  /// **'New scene from now'**
  String get sceneNew;

  /// No description provided for @sceneName.
  ///
  /// In en, this message translates to:
  /// **'Scene name'**
  String get sceneName;

  /// No description provided for @sceneDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get sceneDevices;

  /// No description provided for @sceneSave.
  ///
  /// In en, this message translates to:
  /// **'Save scene'**
  String get sceneSave;

  /// No description provided for @sceneNeedDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one device.'**
  String get sceneNeedDevice;

  /// No description provided for @sceneDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete scene'**
  String get sceneDelete;

  /// No description provided for @sceneDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Scene {time}'**
  String sceneDefaultName(String time);

  /// No description provided for @autoEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit automation'**
  String get autoEdit;

  /// No description provided for @backupSection.
  ///
  /// In en, this message translates to:
  /// **'Backup and transfer'**
  String get backupSection;

  /// No description provided for @backupHint.
  ///
  /// In en, this message translates to:
  /// **'The whole home — devices, rooms, names, scenes, automations and programs — and the app\'s look, to keep or to move to another phone or wall panel. PINs, photos and this device\'s own choices stay here.'**
  String get backupHint;

  /// No description provided for @backupCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy settings'**
  String get backupCopy;

  /// No description provided for @backupPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste settings'**
  String get backupPaste;

  /// No description provided for @backupCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied. Paste it into the app on the other device.'**
  String get backupCopied;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Settings applied.'**
  String get backupImported;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'That is not an Open Smart Home backup.'**
  String get backupInvalid;

  /// No description provided for @autoAddTrigger.
  ///
  /// In en, this message translates to:
  /// **'Add a trigger'**
  String get autoAddTrigger;

  /// No description provided for @autoAnyTrigger.
  ///
  /// In en, this message translates to:
  /// **'Runs when any of these happens.'**
  String get autoAnyTrigger;

  /// No description provided for @autoOnlyIf.
  ///
  /// In en, this message translates to:
  /// **'Only if'**
  String get autoOnlyIf;

  /// No description provided for @autoOnlyIfHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. All of these must be true when it starts.'**
  String get autoOnlyIfHint;

  /// No description provided for @autoAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add a condition'**
  String get autoAddCondition;

  /// No description provided for @autoTriggerValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get autoTriggerValue;

  /// No description provided for @autoAbove.
  ///
  /// In en, this message translates to:
  /// **'Rises above'**
  String get autoAbove;

  /// No description provided for @autoBelow.
  ///
  /// In en, this message translates to:
  /// **'Falls below'**
  String get autoBelow;

  /// No description provided for @autoThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get autoThreshold;

  /// No description provided for @autoCondTime.
  ///
  /// In en, this message translates to:
  /// **'Between two times'**
  String get autoCondTime;

  /// No description provided for @autoCondAfter.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get autoCondAfter;

  /// No description provided for @autoCondBefore.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get autoCondBefore;

  /// No description provided for @autoCondDevice.
  ///
  /// In en, this message translates to:
  /// **'A device is in a state'**
  String get autoCondDevice;

  /// No description provided for @autoCondDark.
  ///
  /// In en, this message translates to:
  /// **'Only when it\'s dark'**
  String get autoCondDark;

  /// No description provided for @autoCondLight.
  ///
  /// In en, this message translates to:
  /// **'Only when it\'s light'**
  String get autoCondLight;

  /// No description provided for @alertsSetting.
  ///
  /// In en, this message translates to:
  /// **'Notify about critical alerts'**
  String get alertsSetting;

  /// No description provided for @alertsSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Smoke, CO, water leak, a triggered alarm or a jammed lock as a phone notification. While the app runs — or always, with Background automations (Settings → Home).'**
  String get alertsSettingHint;

  /// No description provided for @alertsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app in the phone\'s settings.'**
  String get alertsPermissionDenied;

  /// No description provided for @fanLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get fanLow;

  /// No description provided for @fanMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get fanMedium;

  /// No description provided for @fanMiddle.
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get fanMiddle;

  /// No description provided for @fanHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get fanHigh;

  /// No description provided for @fanTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get fanTop;

  /// No description provided for @fanFocus.
  ///
  /// In en, this message translates to:
  /// **'Focused'**
  String get fanFocus;

  /// No description provided for @fanDiffuse.
  ///
  /// In en, this message translates to:
  /// **'Diffuse'**
  String get fanDiffuse;

  /// No description provided for @allCoversOpen.
  ///
  /// In en, this message translates to:
  /// **'Open all'**
  String get allCoversOpen;

  /// No description provided for @allCoversClose.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get allCoversClose;

  /// No description provided for @widgetNoScenes.
  ///
  /// In en, this message translates to:
  /// **'No scenes yet: create one in the app'**
  String get widgetNoScenes;

  /// No description provided for @clapSetting.
  ///
  /// In en, this message translates to:
  /// **'Double clap'**
  String get clapSetting;

  /// No description provided for @clapSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Clap twice to switch something. Only while the kiosk is shown.'**
  String get clapSettingHint;

  /// No description provided for @clapPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen for claps?'**
  String get clapPrivacyTitle;

  /// No description provided for @clapPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'While the kiosk is on screen the microphone stays on, and Android shows its microphone indicator. The app only measures how loud it is, 50 times a second, on this tablet: no sound is recorded, stored or sent anywhere. Turn it off here at any time.'**
  String get clapPrivacyBody;

  /// No description provided for @clapAllow.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get clapAllow;

  /// No description provided for @clapPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'The microphone is not allowed for this app in the system settings.'**
  String get clapPermissionDenied;

  /// No description provided for @clapTarget.
  ///
  /// In en, this message translates to:
  /// **'What a double clap does'**
  String get clapTarget;

  /// No description provided for @clapTargetNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing chosen yet'**
  String get clapTargetNone;

  /// No description provided for @clapToggle.
  ///
  /// In en, this message translates to:
  /// **'switch on/off'**
  String get clapToggle;

  /// No description provided for @clapSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity'**
  String get clapSensitivity;

  /// No description provided for @clapLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get clapLow;

  /// No description provided for @clapMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get clapMedium;

  /// No description provided for @clapHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get clapHigh;

  /// No description provided for @clapSwitched.
  ///
  /// In en, this message translates to:
  /// **'{name}: {state}'**
  String clapSwitched(String name, String state);

  /// No description provided for @clapDone.
  ///
  /// In en, this message translates to:
  /// **'{name}: done'**
  String clapDone(String name);

  /// No description provided for @clapLockAction.
  ///
  /// In en, this message translates to:
  /// **'lock / unlock (unlocking asks for confirmation)'**
  String get clapLockAction;

  /// No description provided for @clapGarageAction.
  ///
  /// In en, this message translates to:
  /// **'open (asks for confirmation) / close'**
  String get clapGarageAction;

  /// No description provided for @clapCoverAction.
  ///
  /// In en, this message translates to:
  /// **'open / close'**
  String get clapCoverAction;

  /// No description provided for @clapVacuumAction.
  ///
  /// In en, this message translates to:
  /// **'start / back to dock'**
  String get clapVacuumAction;

  /// No description provided for @clapMediaAction.
  ///
  /// In en, this message translates to:
  /// **'play / pause'**
  String get clapMediaAction;

  /// No description provided for @clapOpenScreen.
  ///
  /// In en, this message translates to:
  /// **'opens its screen'**
  String get clapOpenScreen;

  /// No description provided for @clapSearch.
  ///
  /// In en, this message translates to:
  /// **'Search devices'**
  String get clapSearch;

  /// No description provided for @kioskDarkScreensaver.
  ///
  /// In en, this message translates to:
  /// **'Dimmed backlight when idle'**
  String get kioskDarkScreensaver;

  /// No description provided for @kioskDarkScreensaverHint.
  ///
  /// In en, this message translates to:
  /// **'While the screen is idle the backlight is at the level below (at night at most “Darker at night”).'**
  String get kioskDarkScreensaverHint;

  /// No description provided for @kioskNight.
  ///
  /// In en, this message translates to:
  /// **'Darker at night'**
  String get kioskNight;

  /// No description provided for @kioskNightHint.
  ///
  /// In en, this message translates to:
  /// **'Lower brightness on a schedule'**
  String get kioskNightHint;

  /// No description provided for @kioskNightRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String kioskNightRange(String from, String to);

  /// No description provided for @kioskNightFrom.
  ///
  /// In en, this message translates to:
  /// **'From {time}'**
  String kioskNightFrom(String time);

  /// No description provided for @kioskNightTo.
  ///
  /// In en, this message translates to:
  /// **'Until {time}'**
  String kioskNightTo(String time);

  /// No description provided for @kioskNightFromHelp.
  ///
  /// In en, this message translates to:
  /// **'Night starts at'**
  String get kioskNightFromHelp;

  /// No description provided for @kioskNightToHelp.
  ///
  /// In en, this message translates to:
  /// **'Night ends at'**
  String get kioskNightToHelp;

  /// No description provided for @kioskNightLevel.
  ///
  /// In en, this message translates to:
  /// **'Night brightness: {percent} %'**
  String kioskNightLevel(int percent);

  /// No description provided for @dashLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get dashLayoutTitle;

  /// No description provided for @dashLayoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose and order the cards'**
  String get dashLayoutSubtitle;

  /// No description provided for @dashLayoutHint.
  ///
  /// In en, this message translates to:
  /// **'Drag or use the arrow to change the order; the switch shows or hides a card. Warnings (connection, critical alerts) always stay on top. On tablets favorites and rooms are in the right column.'**
  String get dashLayoutHint;

  /// No description provided for @dashLayoutReset.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get dashLayoutReset;

  /// No description provided for @dashMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get dashMoveUp;

  /// No description provided for @dashCardSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary (temperature, lights, power…)'**
  String get dashCardSummary;

  /// No description provided for @dashCardWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get dashCardWeather;

  /// No description provided for @dashCardMedia.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get dashCardMedia;

  /// No description provided for @dashCardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'House check, More'**
  String get dashCardShortcuts;

  /// No description provided for @dashCardAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention (batteries, unavailable)'**
  String get dashCardAttention;

  /// No description provided for @timerSet.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerSet;

  /// No description provided for @timerTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get timerTurnOff;

  /// No description provided for @timerTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get timerTurnOn;

  /// No description provided for @timerHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String timerHours(int hours);

  /// No description provided for @timerHint.
  ///
  /// In en, this message translates to:
  /// **'This phone or wall panel counts down while the app runs (or with automations in the background).'**
  String get timerHint;

  /// No description provided for @timerTurnsOffAt.
  ///
  /// In en, this message translates to:
  /// **'Turns off at {time}'**
  String timerTurnsOffAt(String time);

  /// No description provided for @timerTurnsOnAt.
  ///
  /// In en, this message translates to:
  /// **'Turns on at {time}'**
  String timerTurnsOnAt(String time);

  /// No description provided for @kioskPanelChooseDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose device'**
  String get kioskPanelChooseDevice;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsAppearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, home screen'**
  String get settingsAppearanceHint;

  /// No description provided for @settingsKioskHint.
  ///
  /// In en, this message translates to:
  /// **'Wall tablet: layout, PIN, screensaver, camera'**
  String get settingsKioskHint;

  /// No description provided for @settingsNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Alerts, batteries, appliance done'**
  String get settingsNotificationsHint;

  /// No description provided for @settingsSecurityHint.
  ///
  /// In en, this message translates to:
  /// **'App lock, kids and guests mode'**
  String get settingsSecurityHint;

  /// No description provided for @settingsPrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'Location, voice, deleting data'**
  String get settingsPrivacyHint;

  /// No description provided for @settingsBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Keep your home or move it to another device'**
  String get settingsBackupHint;

  /// No description provided for @loadingContent.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingContent;

  /// No description provided for @houseCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'House check'**
  String get houseCheckTitle;

  /// No description provided for @houseCheckShort.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get houseCheckShort;

  /// No description provided for @houseCheckLeaving.
  ///
  /// In en, this message translates to:
  /// **'Leaving'**
  String get houseCheckLeaving;

  /// No description provided for @houseCheckNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get houseCheckNight;

  /// No description provided for @houseCheckAllGood.
  ///
  /// In en, this message translates to:
  /// **'All good'**
  String get houseCheckAllGood;

  /// No description provided for @houseCheckAllGoodLeaving.
  ///
  /// In en, this message translates to:
  /// **'Lights are off, locks are locked, nothing is left open. Have a good trip!'**
  String get houseCheckAllGoodLeaving;

  /// No description provided for @houseCheckAllGoodNight.
  ///
  /// In en, this message translates to:
  /// **'The house is ready for the night. Good night!'**
  String get houseCheckAllGoodNight;

  /// No description provided for @houseCheckCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} thing to check} other{{count} things to check}}'**
  String houseCheckCount(int count);

  /// No description provided for @houseCheckFixAll.
  ///
  /// In en, this message translates to:
  /// **'Fix all ({count})'**
  String houseCheckFixAll(int count);

  /// No description provided for @houseCheckFixing.
  ///
  /// In en, this message translates to:
  /// **'Fixing…'**
  String get houseCheckFixing;

  /// No description provided for @houseCheckManualHint.
  ///
  /// In en, this message translates to:
  /// **'The app cannot close windows and doors with a sensor — please check them. The alarm is armed on its own screen.'**
  String get houseCheckManualHint;

  /// No description provided for @houseCheckLightOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get houseCheckLightOn;

  /// No description provided for @houseCheckMediaOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get houseCheckMediaOn;

  /// No description provided for @houseCheckClimateOn.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get houseCheckClimateOn;

  /// No description provided for @houseCheckUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get houseCheckUnlocked;

  /// No description provided for @houseCheckGarageOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get houseCheckGarageOpen;

  /// No description provided for @houseCheckOpened.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get houseCheckOpened;

  /// No description provided for @houseCheckAlarmOff.
  ///
  /// In en, this message translates to:
  /// **'Alarm not armed'**
  String get houseCheckAlarmOff;

  /// No description provided for @houseCheckTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get houseCheckTurnOff;

  /// No description provided for @houseCheckLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get houseCheckLock;

  /// No description provided for @houseCheckClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get houseCheckClose;

  /// No description provided for @houseCheckPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get houseCheckPause;

  /// No description provided for @houseCheckOpenDevice.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get houseCheckOpenDevice;

  /// No description provided for @todoOpenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{All done} one{{count} item} other{{count} items}}'**
  String todoOpenCount(int count);

  /// No description provided for @homeSayTime.
  ///
  /// In en, this message translates to:
  /// **'It\'s {time}.'**
  String homeSayTime(String time);

  /// No description provided for @homeSayWeather.
  ///
  /// In en, this message translates to:
  /// **'Outside it\'s {condition}, {temperature}.'**
  String homeSayWeather(String condition, String temperature);

  /// No description provided for @homeSayLights.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} light is on} other{{count} lights are on}}'**
  String homeSayLights(int count);

  /// No description provided for @homeSayLightsOff.
  ///
  /// In en, this message translates to:
  /// **'All lights are off'**
  String get homeSayLightsOff;

  /// No description provided for @homeSayOpen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{and {count} window or door is open.} other{and {count} windows or doors are open.}}'**
  String homeSayOpen(int count);

  /// No description provided for @homeSayClosed.
  ///
  /// In en, this message translates to:
  /// **'and everything is closed.'**
  String get homeSayClosed;

  /// No description provided for @homeSayUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked: {names}.'**
  String homeSayUnlocked(String names);

  /// No description provided for @homeSayAlarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm: {state}.'**
  String homeSayAlarm(String state);

  /// No description provided for @homeSayAlerts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Attention: {count} alert.} other{Attention: {count} alerts.}}'**
  String homeSayAlerts(int count);

  /// No description provided for @mediaShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get mediaShuffle;

  /// No description provided for @mediaRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get mediaRepeat;

  /// No description provided for @mediaRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get mediaRepeatOff;

  /// No description provided for @mediaRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get mediaRepeatAll;

  /// No description provided for @mediaRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get mediaRepeatOne;

  /// No description provided for @mediaSeek.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get mediaSeek;

  /// No description provided for @quickTilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick tiles'**
  String get quickTilesTitle;

  /// No description provided for @quickTilesHint.
  ///
  /// In en, this message translates to:
  /// **'Three tiles in the pull-down menu (Android): one tap switches a device or runs a scene, without opening the app. Works only on an unlocked phone; locks, garage doors and alarms are not offered.'**
  String get quickTilesHint;

  /// No description provided for @quickTileSlot.
  ///
  /// In en, this message translates to:
  /// **'Tile {n}'**
  String quickTileSlot(int n);

  /// No description provided for @quickTileUnset.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get quickTileUnset;

  /// No description provided for @quickTileChoose.
  ///
  /// In en, this message translates to:
  /// **'What tile {n} does'**
  String quickTileChoose(int n);

  /// No description provided for @quickTileClear.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get quickTileClear;

  /// No description provided for @quickTileAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to menu'**
  String get quickTileAdd;

  /// No description provided for @quickTileAdded.
  ///
  /// In en, this message translates to:
  /// **'The tile is in the Quick Settings menu.'**
  String get quickTileAdded;

  /// No description provided for @quickTileAddManually.
  ///
  /// In en, this message translates to:
  /// **'Pull down the menu, tap the pencil and drag “Smart Home {n}” to the tiles.'**
  String quickTileAddManually(int n);

  /// No description provided for @aodTitle.
  ///
  /// In en, this message translates to:
  /// **'Always-on screen'**
  String get aodTitle;

  /// No description provided for @aodHint.
  ///
  /// In en, this message translates to:
  /// **'When the kiosk is not used: a black screen with the clock, the forecast and one thing you choose. The content shifts slowly so the screen does not burn in.'**
  String get aodHint;

  /// No description provided for @aodFocus.
  ///
  /// In en, this message translates to:
  /// **'Under the clock'**
  String get aodFocus;

  /// No description provided for @aodFocusNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get aodFocusNone;

  /// No description provided for @aodFocusDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get aodFocusDevice;

  /// No description provided for @aodFocusEnergy.
  ///
  /// In en, this message translates to:
  /// **'Power now'**
  String get aodFocusEnergy;

  /// No description provided for @aodFocusMedia.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get aodFocusMedia;

  /// No description provided for @aodFocusHome.
  ///
  /// In en, this message translates to:
  /// **'Home sentence'**
  String get aodFocusHome;

  /// No description provided for @aodChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get aodChoose;

  /// No description provided for @morningScreen.
  ///
  /// In en, this message translates to:
  /// **'Morning screen'**
  String get morningScreen;

  /// No description provided for @morningScreenHint.
  ///
  /// In en, this message translates to:
  /// **'In the morning the always-on screen shows today\'s forecast, events and reminders (items due today).'**
  String get morningScreenHint;

  /// No description provided for @morningFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get morningFrom;

  /// No description provided for @morningTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get morningTo;

  /// No description provided for @morningHighLow.
  ///
  /// In en, this message translates to:
  /// **'high {high}, low {low}'**
  String morningHighLow(String high, String low);

  /// No description provided for @aodBrightness.
  ///
  /// In en, this message translates to:
  /// **'Always-on brightness'**
  String get aodBrightness;

  /// No description provided for @approachWake.
  ///
  /// In en, this message translates to:
  /// **'Wake the screen when someone comes near'**
  String get approachWake;

  /// No description provided for @approachWakeHint.
  ///
  /// In en, this message translates to:
  /// **'Only while the kiosk screen is idle.'**
  String get approachWakeHint;

  /// No description provided for @approachOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get approachOff;

  /// No description provided for @approachSensor.
  ///
  /// In en, this message translates to:
  /// **'Motion sensor'**
  String get approachSensor;

  /// No description provided for @approachCamera.
  ///
  /// In en, this message translates to:
  /// **'Tablet camera'**
  String get approachCamera;

  /// No description provided for @approachSensorPick.
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get approachSensorPick;

  /// No description provided for @approachNoSensors.
  ///
  /// In en, this message translates to:
  /// **'No motion or presence sensors. Add one (e.g. Shelly BLU, Hue, IKEA or ESPHome).'**
  String get approachNoSensors;

  /// No description provided for @approachCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Use the tablet\'s camera?'**
  String get approachCameraTitle;

  /// No description provided for @approachCameraBody.
  ///
  /// In en, this message translates to:
  /// **'While the screen is idle, the front camera checks a few times a second whether something moves in front of the tablet, and Android shows its camera indicator. Pictures are processed only on this tablet and dropped at once: nothing is recorded, stored or sent anywhere. While the screen is awake the camera is off.'**
  String get approachCameraBody;

  /// No description provided for @approachCameraAllow.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get approachCameraAllow;

  /// No description provided for @approachCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'The camera is not allowed for this app in the system settings.'**
  String get approachCameraDenied;

  /// No description provided for @presenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Presence simulation'**
  String get presenceTitle;

  /// No description provided for @presenceHint.
  ///
  /// In en, this message translates to:
  /// **'Lights go on and off by themselves in the evening while nobody is home'**
  String get presenceHint;

  /// No description provided for @presenceIntro.
  ///
  /// In en, this message translates to:
  /// **'While it is on, one of the chosen lights is switched on or off every 15 minutes in the evening (with a random wait of up to 10 minutes), and all go off at the end time. The phone or tablet running it has to stay at home, running.'**
  String get presenceIntro;

  /// No description provided for @presenceOn.
  ///
  /// In en, this message translates to:
  /// **'Simulation on'**
  String get presenceOn;

  /// No description provided for @presenceLights.
  ///
  /// In en, this message translates to:
  /// **'Lights'**
  String get presenceLights;

  /// No description provided for @presenceNoLights.
  ///
  /// In en, this message translates to:
  /// **'The home has no lights.'**
  String get presenceNoLights;

  /// No description provided for @presenceFromSunset.
  ///
  /// In en, this message translates to:
  /// **'From sunset'**
  String get presenceFromSunset;

  /// No description provided for @presenceStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get presenceStart;

  /// No description provided for @presenceEnd.
  ///
  /// In en, this message translates to:
  /// **'End (all chosen lights go off)'**
  String get presenceEnd;

  /// No description provided for @presenceSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get presenceSave;

  /// No description provided for @presenceSaved.
  ///
  /// In en, this message translates to:
  /// **'Presence simulation saved.'**
  String get presenceSaved;

  /// No description provided for @kioskAlertAck.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get kioskAlertAck;

  /// No description provided for @kioskAlertShow.
  ///
  /// In en, this message translates to:
  /// **'Show device'**
  String get kioskAlertShow;

  /// No description provided for @kioskAlertOpenFor.
  ///
  /// In en, this message translates to:
  /// **'Open for {minutes} min'**
  String kioskAlertOpenFor(int minutes);

  /// No description provided for @kioskAlertMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String kioskAlertMore(int count);

  /// No description provided for @kioskAlertSpeech.
  ///
  /// In en, this message translates to:
  /// **'Warning! {name}: {status}.'**
  String kioskAlertSpeech(String name, String status);

  /// No description provided for @kioskAlertSetting.
  ///
  /// In en, this message translates to:
  /// **'Full-screen alerts'**
  String get kioskAlertSetting;

  /// No description provided for @kioskAlertSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Smoke, carbon monoxide, water leak, a triggered alarm or a jammed lock covers the whole screen and is spoken until someone confirms it.'**
  String get kioskAlertSettingHint;

  /// No description provided for @kioskOpenAlert.
  ///
  /// In en, this message translates to:
  /// **'Door or window open longer than'**
  String get kioskOpenAlert;

  /// No description provided for @kioskOpenAlertNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get kioskOpenAlertNever;

  /// No description provided for @kioskOpenAlertMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String kioskOpenAlertMinutes(int minutes);

  /// No description provided for @timerTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerTitle;

  /// No description provided for @timerNew.
  ///
  /// In en, this message translates to:
  /// **'New timer'**
  String get timerNew;

  /// No description provided for @timerStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get timerStart;

  /// No description provided for @timerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get timerStop;

  /// No description provided for @timerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get timerCancel;

  /// No description provided for @timerAddMinute.
  ///
  /// In en, this message translates to:
  /// **'+1 min'**
  String get timerAddMinute;

  /// No description provided for @timerDone.
  ///
  /// In en, this message translates to:
  /// **'Timer {label} is done'**
  String timerDone(String label);

  /// No description provided for @timerDoneSpeech.
  ///
  /// In en, this message translates to:
  /// **'The {label} timer is done.'**
  String timerDoneSpeech(String label);

  /// No description provided for @kioskNightLightHint.
  ///
  /// In en, this message translates to:
  /// **'Tap: {name} at 10 %'**
  String kioskNightLightHint(String name);

  /// No description provided for @kioskNightLightOn.
  ///
  /// In en, this message translates to:
  /// **'{name} is on · tap again for the screen'**
  String kioskNightLightOn(String name);

  /// No description provided for @kioskNightClock.
  ///
  /// In en, this message translates to:
  /// **'Red night clock'**
  String get kioskNightClock;

  /// No description provided for @kioskNightClockHint.
  ///
  /// In en, this message translates to:
  /// **'At night the idle screen shows only the time, in dim red.'**
  String get kioskNightClockHint;

  /// No description provided for @kioskNightLight.
  ///
  /// In en, this message translates to:
  /// **'Night light on tap'**
  String get kioskNightLight;

  /// No description provided for @kioskNightLightNone.
  ///
  /// In en, this message translates to:
  /// **'None (a tap wakes the screen)'**
  String get kioskNightLightNone;

  /// No description provided for @kioskLeaving.
  ///
  /// In en, this message translates to:
  /// **'I\'m leaving'**
  String get kioskLeaving;

  /// No description provided for @kioskLeavingAllGood.
  ///
  /// In en, this message translates to:
  /// **'Everything is off and closed. Have a nice day!'**
  String get kioskLeavingAllGood;

  /// No description provided for @kioskLeavingManual.
  ///
  /// In en, this message translates to:
  /// **'Windows and doors marked without a tick must be closed by hand.'**
  String get kioskLeavingManual;

  /// No description provided for @kioskLeavingGo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to switch off} =1{Switch off 1 thing} other{Switch off {count} things}}'**
  String kioskLeavingGo(int count);

  /// No description provided for @kioskLeavingGoArm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Arm the alarm} =1{Switch off 1 thing and arm} other{Switch off {count} and arm}}'**
  String kioskLeavingGoArm(int count);

  /// No description provided for @kioskLeavingBye.
  ///
  /// In en, this message translates to:
  /// **'Goodbye!'**
  String get kioskLeavingBye;

  /// No description provided for @photoFrame.
  ///
  /// In en, this message translates to:
  /// **'Photo frame'**
  String get photoFrame;

  /// No description provided for @photoFrameHint.
  ///
  /// In en, this message translates to:
  /// **'While idle, show photos from this tablet (they stay on it).'**
  String get photoFrameHint;

  /// No description provided for @photoFrameCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo · stays on this tablet} other{{count} photos · stay on this tablet}}'**
  String photoFrameCount(int count);

  /// No description provided for @photoFrameAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get photoFrameAdd;

  /// No description provided for @photoFrameRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get photoFrameRemove;

  /// No description provided for @photoFrameEverySeconds.
  ///
  /// In en, this message translates to:
  /// **'every {seconds} s'**
  String photoFrameEverySeconds(int seconds);

  /// No description provided for @photoFrameEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'every {minutes} min'**
  String photoFrameEveryMinutes(int minutes);

  /// No description provided for @kioskColumnsNoRooms.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet. Add them in Settings → Home.'**
  String get kioskColumnsNoRooms;

  /// No description provided for @kioskColumnsDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get kioskColumnsDevices;

  /// No description provided for @kioskOpenDevice.
  ///
  /// In en, this message translates to:
  /// **'Open device'**
  String get kioskOpenDevice;

  /// No description provided for @kioskBundleMain.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get kioskBundleMain;

  /// No description provided for @kioskBundleActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get kioskBundleActions;

  /// No description provided for @kioskBundleSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get kioskBundleSettings;

  /// No description provided for @kioskBundleState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get kioskBundleState;

  /// No description provided for @kioskBundleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} controls'**
  String kioskBundleCount(int count);

  /// No description provided for @kioskQuickControls.
  ///
  /// In en, this message translates to:
  /// **'Quick controls'**
  String get kioskQuickControls;

  /// No description provided for @kioskQuickControlsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get kioskQuickControlsAdd;

  /// No description provided for @kioskQuickControlsEdit.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get kioskQuickControlsEdit;

  /// No description provided for @kioskQuickControlsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose devices to keep at hand here — lights, the air fryer, a scene…'**
  String get kioskQuickControlsHint;

  /// No description provided for @kioskHomeCards.
  ///
  /// In en, this message translates to:
  /// **'Home cards'**
  String get kioskHomeCards;

  /// No description provided for @applianceDoneAction.
  ///
  /// In en, this message translates to:
  /// **'Tell me when it\'s done'**
  String get applianceDoneAction;

  /// No description provided for @applianceDoneHint.
  ///
  /// In en, this message translates to:
  /// **'The app watches the power: once the appliance has run (above the threshold) and then goes quiet, this phone or tablet says it\'s done. Runs on this phone or wall panel while the app runs (or with automations in the background).'**
  String get applianceDoneHint;

  /// No description provided for @applianceDoneName.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Washing machine)'**
  String get applianceDoneName;

  /// No description provided for @applianceDoneThreshold.
  ///
  /// In en, this message translates to:
  /// **'Running above'**
  String get applianceDoneThreshold;

  /// No description provided for @applianceDoneQuiet.
  ///
  /// In en, this message translates to:
  /// **'Done after quiet for'**
  String get applianceDoneQuiet;

  /// No description provided for @applianceDoneMinutesValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String applianceDoneMinutesValue(int minutes);

  /// No description provided for @applianceDoneNow.
  ///
  /// In en, this message translates to:
  /// **'Using {watts} W now.'**
  String applianceDoneNow(String watts);

  /// No description provided for @applianceDoneRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get applianceDoneRemove;

  /// No description provided for @applianceDoneRemoved.
  ///
  /// In en, this message translates to:
  /// **'Reminder removed.'**
  String get applianceDoneRemoved;

  /// No description provided for @applianceDoneSaved.
  ///
  /// In en, this message translates to:
  /// **'You\'ll hear when \"{name}\" is done.'**
  String applianceDoneSaved(String name);

  /// No description provided for @applianceDoneOn.
  ///
  /// In en, this message translates to:
  /// **'Tells you when it\'s done'**
  String get applianceDoneOn;

  /// No description provided for @applianceDoneOnHint.
  ///
  /// In en, this message translates to:
  /// **'Watched by this phone'**
  String get applianceDoneOnHint;

  /// No description provided for @applianceDoneChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get applianceDoneChange;

  /// No description provided for @applianceDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get applianceDoneTitle;

  /// No description provided for @applianceDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'{name}: the cycle has finished.'**
  String applianceDoneMessage(String name);

  /// No description provided for @heatingScheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Weekly schedule'**
  String get heatingScheduleAction;

  /// No description provided for @heatingScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly schedule'**
  String get heatingScheduleTitle;

  /// No description provided for @heatingScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'From each time on, that temperature holds until the next one. The schedule is kept as the home\'s automations. Runs on this phone or wall panel while the app runs (or with automations in the background). A manual change holds until the next time.'**
  String get heatingScheduleHint;

  /// No description provided for @heatingScheduleWorkdays.
  ///
  /// In en, this message translates to:
  /// **'Workdays (Mon–Fri)'**
  String get heatingScheduleWorkdays;

  /// No description provided for @heatingScheduleWeekend.
  ///
  /// In en, this message translates to:
  /// **'Weekend (Sat–Sun)'**
  String get heatingScheduleWeekend;

  /// No description provided for @heatingScheduleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a time'**
  String get heatingScheduleAdd;

  /// No description provided for @heatingScheduleColder.
  ///
  /// In en, this message translates to:
  /// **'Colder'**
  String get heatingScheduleColder;

  /// No description provided for @heatingScheduleWarmer.
  ///
  /// In en, this message translates to:
  /// **'Warmer'**
  String get heatingScheduleWarmer;

  /// No description provided for @heatingScheduleRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove schedule'**
  String get heatingScheduleRemove;

  /// No description provided for @heatingScheduleRemoved.
  ///
  /// In en, this message translates to:
  /// **'Schedule removed.'**
  String get heatingScheduleRemoved;

  /// No description provided for @heatingScheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved.'**
  String get heatingScheduleSaved;

  /// No description provided for @heatingScheduleNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {time} → {temperature}'**
  String heatingScheduleNext(String time, String temperature);

  /// No description provided for @mediaMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mediaMute;

  /// No description provided for @mediaUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get mediaUnmute;

  /// No description provided for @mediaVolumeUp.
  ///
  /// In en, this message translates to:
  /// **'Volume up'**
  String get mediaVolumeUp;

  /// No description provided for @mediaVolumeDown.
  ///
  /// In en, this message translates to:
  /// **'Volume down'**
  String get mediaVolumeDown;

  /// No description provided for @mediaSoundMode.
  ///
  /// In en, this message translates to:
  /// **'Sound mode'**
  String get mediaSoundMode;

  /// No description provided for @tvRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get tvRemote;

  /// No description provided for @tvUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get tvUp;

  /// No description provided for @tvDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get tvDown;

  /// No description provided for @tvLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get tvLeft;

  /// No description provided for @tvRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get tvRight;

  /// No description provided for @tvOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get tvOk;

  /// No description provided for @tvBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get tvBack;

  /// No description provided for @tvHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tvHome;

  /// No description provided for @tvMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get tvMenu;

  /// No description provided for @tvPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play / pause'**
  String get tvPlayPause;

  /// No description provided for @tvVolume.
  ///
  /// In en, this message translates to:
  /// **'Vol'**
  String get tvVolume;

  /// No description provided for @tvChannel.
  ///
  /// In en, this message translates to:
  /// **'Ch'**
  String get tvChannel;

  /// No description provided for @tvChannelUp.
  ///
  /// In en, this message translates to:
  /// **'Channel up'**
  String get tvChannelUp;

  /// No description provided for @tvChannelDown.
  ///
  /// In en, this message translates to:
  /// **'Channel down'**
  String get tvChannelDown;

  /// No description provided for @roomPhoto.
  ///
  /// In en, this message translates to:
  /// **'Room photo'**
  String get roomPhoto;

  /// No description provided for @roomPhotoChange.
  ///
  /// In en, this message translates to:
  /// **'Choose another photo'**
  String get roomPhotoChange;

  /// No description provided for @roomPhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get roomPhotoRemove;

  /// No description provided for @roomPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Photo, icon and colour stay on this device only. For the wall tablet, choose them on the tablet itself.'**
  String get roomPhotoHint;

  /// No description provided for @themeAutoDark.
  ///
  /// In en, this message translates to:
  /// **'Dark after sunset'**
  String get themeAutoDark;

  /// No description provided for @themeAutoDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Follows sunrise and sunset at the home\'s location (without it: dark from 20:00 to 7:00).'**
  String get themeAutoDarkHint;

  /// No description provided for @accentTitle.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get accentTitle;

  /// No description provided for @accentTerracotta.
  ///
  /// In en, this message translates to:
  /// **'Terracotta'**
  String get accentTerracotta;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get accentPurple;

  /// No description provided for @accentRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get accentRose;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @onNowTitle.
  ///
  /// In en, this message translates to:
  /// **'On now'**
  String get onNowTitle;

  /// No description provided for @onNowLights.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 light} other{{count} lights}}'**
  String onNowLights(int count);

  /// No description provided for @onNowLightsOff.
  ///
  /// In en, this message translates to:
  /// **'All lights are off.'**
  String get onNowLightsOff;

  /// No description provided for @onNowTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Turned off: {name}'**
  String onNowTurnedOff(String name);

  /// No description provided for @onNowHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to open, long-press to turn off'**
  String get onNowHint;

  /// No description provided for @roomLook.
  ///
  /// In en, this message translates to:
  /// **'Room look'**
  String get roomLook;

  /// No description provided for @roomPhotoChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get roomPhotoChoose;

  /// No description provided for @roomIconTitle.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get roomIconTitle;

  /// No description provided for @roomColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get roomColorTitle;

  /// No description provided for @roomLookReset.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get roomLookReset;

  /// No description provided for @favoritesBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse devices'**
  String get favoritesBrowse;

  /// No description provided for @bigSliderPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get bigSliderPosition;

  /// No description provided for @deviceSheetMore.
  ///
  /// In en, this message translates to:
  /// **'All details'**
  String get deviceSheetMore;

  /// No description provided for @setupNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get setupNext;

  /// No description provided for @setupBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get setupBack;

  /// No description provided for @backupFileTitle.
  ///
  /// In en, this message translates to:
  /// **'As text'**
  String get backupFileTitle;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'App updates'**
  String get updateTitle;

  /// No description provided for @updateCurrent.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String updateCurrent(String version);

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version ({version}).'**
  String updateUpToDate(String version);

  /// No description provided for @updateNoReleases.
  ///
  /// In en, this message translates to:
  /// **'No published releases (or the release source isn\'t public).'**
  String get updateNoReleases;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent} %'**
  String updateDownloading(int percent);

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing — Android may ask to confirm; the app then restarts.'**
  String get updateInstalling;

  /// No description provided for @updateNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow \"Install unknown apps\" for this app, then tap Install again.'**
  String get updateNeedsPermission;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'The check or download failed (no internet?).'**
  String get updateFailed;

  /// No description provided for @updateRejected.
  ///
  /// In en, this message translates to:
  /// **'The download doesn\'t match its published checksum (SHA-256) — not installed.'**
  String get updateRejected;

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get updateInstall;

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get updateCheck;

  /// No description provided for @updateAuto.
  ///
  /// In en, this message translates to:
  /// **'Check for new releases at start-up'**
  String get updateAuto;

  /// No description provided for @updateAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Asks GitHub (public releases) whether there\'s a new version; GitHub then sees the device\'s address. Nothing else is sent.'**
  String get updateAutoHint;

  /// No description provided for @firstRunSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get firstRunSkip;

  /// No description provided for @firstRunWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome home!'**
  String get firstRunWelcomeTitle;

  /// No description provided for @firstRunRoleQuestion.
  ///
  /// In en, this message translates to:
  /// **'How will you use this device?'**
  String get firstRunRoleQuestion;

  /// No description provided for @firstRunRolePhone.
  ///
  /// In en, this message translates to:
  /// **'My phone or tablet'**
  String get firstRunRolePhone;

  /// No description provided for @firstRunRolePhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Personal, I carry it with me'**
  String get firstRunRolePhoneHint;

  /// No description provided for @firstRunRoleWall.
  ///
  /// In en, this message translates to:
  /// **'Wall tablet for the whole home'**
  String get firstRunRoleWall;

  /// No description provided for @firstRunRoleWallHint.
  ///
  /// In en, this message translates to:
  /// **'Mounted on the wall, used by everyone (kiosk with a PIN)'**
  String get firstRunRoleWallHint;

  /// No description provided for @firstRunWallNext.
  ///
  /// In en, this message translates to:
  /// **'Set up the wall panel'**
  String get firstRunWallNext;

  /// No description provided for @firstRunLookTitle.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get firstRunLookTitle;

  /// No description provided for @firstRunLookBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a light or dark theme and a colour you like.'**
  String get firstRunLookBody;

  /// No description provided for @firstRunFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favourite devices'**
  String get firstRunFavoritesTitle;

  /// No description provided for @firstRunFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'Tap what you use most — it will be at the top of Home.'**
  String get firstRunFavoritesBody;

  /// No description provided for @firstRunFavoritesNone.
  ///
  /// In en, this message translates to:
  /// **'No controllable devices yet. Add them later in Settings → Home.'**
  String get firstRunFavoritesNone;

  /// No description provided for @firstRunFavoritesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing selected} =1{1 device selected} other{{count} devices selected}}'**
  String firstRunFavoritesCount(int count);

  /// No description provided for @firstRunSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get firstRunSecurityTitle;

  /// No description provided for @firstRunSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'Whoever has your unlocked phone can control the home. We recommend at least confirming locks and the alarm.'**
  String get firstRunSecurityBody;

  /// No description provided for @firstRunDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get firstRunDoneTitle;

  /// No description provided for @firstRunDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Add devices in Settings → Home → Add device. Everything chosen here can be changed in Settings, and Home\'s cards with the ⚙ button next to the greeting.'**
  String get firstRunDoneBody;

  /// No description provided for @firstRunStart.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get firstRunStart;

  /// No description provided for @kioskGreetingName.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String kioskGreetingName(String greeting, String name);

  /// No description provided for @kioskPersonButton.
  ///
  /// In en, this message translates to:
  /// **'{name} is using the panel'**
  String kioskPersonButton(String name);

  /// No description provided for @kioskPersonEnterPin.
  ///
  /// In en, this message translates to:
  /// **'PIN — {name}'**
  String kioskPersonEnterPin(String name);

  /// No description provided for @kioskCriticalPinHint.
  ///
  /// In en, this message translates to:
  /// **'Your own PIN or the panel\'s PIN'**
  String get kioskCriticalPinHint;

  /// No description provided for @kioskQuickControlsFor.
  ///
  /// In en, this message translates to:
  /// **'Quick controls — {name}'**
  String kioskQuickControlsFor(String name);

  /// No description provided for @kioskQuickControlsShared.
  ///
  /// In en, this message translates to:
  /// **'Use the shared ones'**
  String get kioskQuickControlsShared;

  /// No description provided for @kioskPeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'Household on the panel'**
  String get kioskPeopleTitle;

  /// No description provided for @kioskPeopleHint.
  ///
  /// In en, this message translates to:
  /// **'On the panel, a member taps their name and gets their own quick controls. Unlocking doors, disarming the alarm and similar actions need the member\'s own PIN or the panel\'s PIN — members without a PIN (e.g. children) cannot. Tap a name for the birthday.'**
  String get kioskPeopleHint;

  /// No description provided for @kioskPersonPinSet.
  ///
  /// In en, this message translates to:
  /// **'Own PIN set — may unlock'**
  String get kioskPersonPinSet;

  /// No description provided for @kioskPersonNoPin.
  ///
  /// In en, this message translates to:
  /// **'No own PIN'**
  String get kioskPersonNoPin;

  /// No description provided for @kioskPersonSetPin.
  ///
  /// In en, this message translates to:
  /// **'Own PIN — {name}'**
  String kioskPersonSetPin(String name);

  /// No description provided for @kioskPersonNoPinLocked.
  ///
  /// In en, this message translates to:
  /// **'No own PIN — cannot unlock'**
  String get kioskPersonNoPinLocked;

  /// No description provided for @extrasTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get extrasTitle;

  /// No description provided for @extrasShort.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get extrasShort;

  /// No description provided for @batteriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Batteries'**
  String get batteriesTitle;

  /// No description provided for @batteriesNone.
  ///
  /// In en, this message translates to:
  /// **'No device reports a battery.'**
  String get batteriesNone;

  /// No description provided for @batteriesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 battery device} other{{count} battery devices}} · {low, plural, =0{all fine} =1{1 running low} other{{low} running low}}'**
  String batteriesSummary(int count, int low);

  /// No description provided for @batteryReminder.
  ///
  /// In en, this message translates to:
  /// **'Tell me when a battery runs low'**
  String get batteryReminder;

  /// No description provided for @batteryReminderHint.
  ///
  /// In en, this message translates to:
  /// **'This phone or tablet tells you with a notification when a device\'s battery drops to {percent} % or lower (while the app runs, or with automations in the background).'**
  String batteryReminderHint(int percent);

  /// No description provided for @batteryReminderMessage.
  ///
  /// In en, this message translates to:
  /// **'Battery running low: {name} ({percent} %)'**
  String batteryReminderMessage(String name, String percent);

  /// No description provided for @batteryLowShort.
  ///
  /// In en, this message translates to:
  /// **'Battery low'**
  String get batteryLowShort;

  /// No description provided for @batteryOk.
  ///
  /// In en, this message translates to:
  /// **'Battery fine'**
  String get batteryOk;

  /// No description provided for @vacationTitle.
  ///
  /// In en, this message translates to:
  /// **'On holiday'**
  String get vacationTitle;

  /// No description provided for @vacationHint.
  ///
  /// In en, this message translates to:
  /// **'Get the home ready while you are away, with one tap. On your return, heating and the simulation go back to how they were.'**
  String get vacationHint;

  /// No description provided for @vacationTidy.
  ///
  /// In en, this message translates to:
  /// **'Tidy up'**
  String get vacationTidy;

  /// No description provided for @vacationTidyHint.
  ///
  /// In en, this message translates to:
  /// **'Lights and music off, and the rest — as \"Leaving\" does'**
  String get vacationTidyHint;

  /// No description provided for @vacationHeating.
  ///
  /// In en, this message translates to:
  /// **'Heating at {temperature} °C'**
  String vacationHeating(String temperature);

  /// No description provided for @vacationHeatingHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thermostat} other{{count} thermostats}}; the old temperatures are remembered'**
  String vacationHeatingHint(int count);

  /// No description provided for @vacationSimulation.
  ///
  /// In en, this message translates to:
  /// **'Presence simulation'**
  String get vacationSimulation;

  /// No description provided for @vacationSimulationHint.
  ///
  /// In en, this message translates to:
  /// **'Lights go on and off by themselves in the evening'**
  String get vacationSimulationHint;

  /// No description provided for @vacationSimulationMissing.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet'**
  String get vacationSimulationMissing;

  /// No description provided for @vacationSimulationSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get vacationSimulationSetUp;

  /// No description provided for @vacationAlarm.
  ///
  /// In en, this message translates to:
  /// **'Arm the alarm (away)'**
  String get vacationAlarm;

  /// No description provided for @vacationStart.
  ///
  /// In en, this message translates to:
  /// **'We\'re off'**
  String get vacationStart;

  /// No description provided for @vacationLocalNote.
  ///
  /// In en, this message translates to:
  /// **'This device remembers what to undo — mark your return on it.'**
  String get vacationLocalNote;

  /// No description provided for @vacationActive.
  ///
  /// In en, this message translates to:
  /// **'You are on holiday'**
  String get vacationActive;

  /// No description provided for @vacationActiveSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String vacationActiveSince(String date);

  /// No description provided for @vacationEndHint.
  ///
  /// In en, this message translates to:
  /// **'When you are back: heating to the old temperatures, the simulation as it was.'**
  String get vacationEndHint;

  /// No description provided for @vacationAlarmStillOn.
  ///
  /// In en, this message translates to:
  /// **'The alarm is still on — disarm it with the keypad or code.'**
  String get vacationAlarmStillOn;

  /// No description provided for @vacationEnd.
  ///
  /// In en, this message translates to:
  /// **'We\'re back'**
  String get vacationEnd;

  /// No description provided for @guestWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Guest Wi-Fi'**
  String get guestWifiTitle;

  /// No description provided for @guestWifiNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet. Enter the guest network; guests then join by scanning the code — no spelling out the password.'**
  String get guestWifiNotSet;

  /// No description provided for @guestWifiScan.
  ///
  /// In en, this message translates to:
  /// **'Scan with the phone\'s camera'**
  String get guestWifiScan;

  /// No description provided for @guestWifiSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get guestWifiSetUp;

  /// No description provided for @guestWifiChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get guestWifiChange;

  /// No description provided for @guestWifiWarning.
  ///
  /// In en, this message translates to:
  /// **'Enter the guest network only: anyone who opens this screen sees the code and password. The password is kept in the device\'s protected storage and never leaves it.'**
  String get guestWifiWarning;

  /// No description provided for @guestWifiSsid.
  ///
  /// In en, this message translates to:
  /// **'Network name (SSID)'**
  String get guestWifiSsid;

  /// No description provided for @guestWifiPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get guestWifiPassword;

  /// No description provided for @guestWifiPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get guestWifiPasswordHint;

  /// No description provided for @guestWifiOpen.
  ///
  /// In en, this message translates to:
  /// **'Network without a password'**
  String get guestWifiOpen;

  /// No description provided for @guestWifiHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden network'**
  String get guestWifiHidden;

  /// No description provided for @guestWifiRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get guestWifiRemove;

  /// No description provided for @airAdviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Air the room: {place}'**
  String airAdviceTitle(String place);

  /// No description provided for @airAdviceCo2.
  ///
  /// In en, this message translates to:
  /// **'CO2 {ppm} ppm — the air is stuffy, open a window for a few minutes'**
  String airAdviceCo2(int ppm);

  /// No description provided for @airAdviceHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity {percent} % — air it so mould doesn\'t settle'**
  String airAdviceHumidity(int percent);

  /// No description provided for @partyTitle.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get partyTitle;

  /// No description provided for @partyHint.
  ///
  /// In en, this message translates to:
  /// **'Colour lights cycle through colours while the party is on. Afterwards they all go back to how they were.'**
  String get partyHint;

  /// No description provided for @partyNoLights.
  ///
  /// In en, this message translates to:
  /// **'No colour lights — a party needs at least one RGB light.'**
  String get partyNoLights;

  /// No description provided for @partyMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get partyMusic;

  /// No description provided for @partyNoMusic.
  ///
  /// In en, this message translates to:
  /// **'No music'**
  String get partyNoMusic;

  /// No description provided for @partyStart.
  ///
  /// In en, this message translates to:
  /// **'Start the party'**
  String get partyStart;

  /// No description provided for @partyOn.
  ///
  /// In en, this message translates to:
  /// **'Party! 🎉'**
  String get partyOn;

  /// No description provided for @partyLights.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 light dancing} other{{count} lights dancing}}'**
  String partyLights(int count);

  /// No description provided for @partyStop.
  ///
  /// In en, this message translates to:
  /// **'End the party'**
  String get partyStop;

  /// No description provided for @sunriseTitle.
  ///
  /// In en, this message translates to:
  /// **'Sunrise alarm'**
  String get sunriseTitle;

  /// No description provided for @sunriseHint.
  ///
  /// In en, this message translates to:
  /// **'The light comes up slowly before you wake, from a dim warm glow to daylight, like a real sunrise. Runs on this phone or wall panel while the app runs (or with automations in the background).'**
  String get sunriseHint;

  /// No description provided for @sunriseWakeAt.
  ///
  /// In en, this message translates to:
  /// **'Fully bright at'**
  String get sunriseWakeAt;

  /// No description provided for @sunriseMinutes.
  ///
  /// In en, this message translates to:
  /// **'Sunrise takes {minutes} min'**
  String sunriseMinutes(int minutes);

  /// No description provided for @sunriseLights.
  ///
  /// In en, this message translates to:
  /// **'Lights'**
  String get sunriseLights;

  /// No description provided for @sunriseSave.
  ///
  /// In en, this message translates to:
  /// **'Turn on the alarm'**
  String get sunriseSave;

  /// No description provided for @sunriseUpdate.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get sunriseUpdate;

  /// No description provided for @sunriseRemove.
  ///
  /// In en, this message translates to:
  /// **'Turn off the alarm'**
  String get sunriseRemove;

  /// No description provided for @sunriseSaved.
  ///
  /// In en, this message translates to:
  /// **'Sunrise alarm: bright by {time}.'**
  String sunriseSaved(String time);

  /// No description provided for @sunriseRemoved.
  ///
  /// In en, this message translates to:
  /// **'Sunrise alarm turned off.'**
  String get sunriseRemoved;

  /// No description provided for @birthdayGreeting.
  ///
  /// In en, this message translates to:
  /// **'Happy birthday, {names}!'**
  String birthdayGreeting(String names);

  /// No description provided for @birthdayPick.
  ///
  /// In en, this message translates to:
  /// **'Birthday (day and month)'**
  String get birthdayPick;

  /// No description provided for @seasonalSetting.
  ///
  /// In en, this message translates to:
  /// **'Seasonal decorations'**
  String get seasonalSetting;

  /// No description provided for @seasonalSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Snow from December to Christmas, confetti for New Year and household birthdays, pumpkins before Halloween. Stops while the screen is dimmed.'**
  String get seasonalSettingHint;

  /// No description provided for @bedtimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Bedtime story'**
  String get bedtimeTitle;

  /// No description provided for @bedtimeHint.
  ///
  /// In en, this message translates to:
  /// **'The tablet or phone reads a short story while the lights in the chosen room slowly go down.'**
  String get bedtimeHint;

  /// No description provided for @bedtimeLights.
  ///
  /// In en, this message translates to:
  /// **'Lights to dim'**
  String get bedtimeLights;

  /// No description provided for @bedtimeNoLights.
  ///
  /// In en, this message translates to:
  /// **'No lights'**
  String get bedtimeNoLights;

  /// No description provided for @bedtimeAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get bedtimeAloud;

  /// No description provided for @bedtimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'about {minutes} min'**
  String bedtimeMinutes(int minutes);

  /// No description provided for @bedtimeNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get bedtimeNext;

  /// No description provided for @bedtimeEnd.
  ///
  /// In en, this message translates to:
  /// **'The end'**
  String get bedtimeEnd;

  /// No description provided for @bedtimeGoodNight.
  ///
  /// In en, this message translates to:
  /// **'Good night. 🌙'**
  String get bedtimeGoodNight;

  /// No description provided for @themeOled.
  ///
  /// In en, this message translates to:
  /// **'Pure black dark theme'**
  String get themeOled;

  /// No description provided for @themeOledHint.
  ///
  /// In en, this message translates to:
  /// **'For AMOLED screens: black pixels switch off — saves battery and does not glow in the dark.'**
  String get themeOledHint;

  /// No description provided for @paletteHint.
  ///
  /// In en, this message translates to:
  /// **'Room, device or scene…'**
  String get paletteHint;

  /// No description provided for @paletteEmpty.
  ///
  /// In en, this message translates to:
  /// **'Type part of a name — e.g. \"kit\" for the kitchen.'**
  String get paletteEmpty;

  /// No description provided for @paletteNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches.'**
  String get paletteNothing;

  /// No description provided for @paletteRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get paletteRoom;

  /// No description provided for @paletteKeys.
  ///
  /// In en, this message translates to:
  /// **'Enter: run or switch · ↑↓ choose · Esc close'**
  String get paletteKeys;

  /// No description provided for @paletteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search (Ctrl+K)'**
  String get paletteTooltip;

  /// No description provided for @simpleTitle.
  ///
  /// In en, this message translates to:
  /// **'Simple mode'**
  String get simpleTitle;

  /// No description provided for @simpleHint.
  ///
  /// In en, this message translates to:
  /// **'Just a few big buttons and large text, no menus — e.g. on grandparents\' tablet.'**
  String get simpleHint;

  /// No description provided for @simpleChosen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 button} other{{count} buttons}}'**
  String simpleChosen(int count);

  /// No description provided for @simpleChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get simpleChoose;

  /// No description provided for @simpleChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Buttons (at most {max})'**
  String simpleChooseTitle(int max);

  /// No description provided for @simpleStartMode.
  ///
  /// In en, this message translates to:
  /// **'Start simple mode'**
  String get simpleStartMode;

  /// No description provided for @simpleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No buttons yet. Leave (the lock at the top right) and choose them in Settings.'**
  String get simpleEmpty;

  /// No description provided for @simpleOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get simpleOn;

  /// No description provided for @simpleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get simpleOff;

  /// No description provided for @simpleStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get simpleStart;

  /// No description provided for @simpleLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave simple mode'**
  String get simpleLeave;

  /// No description provided for @simpleLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave simple mode?'**
  String get simpleLeaveTitle;

  /// No description provided for @simpleLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'The full app with all its menus comes back.'**
  String get simpleLeaveBody;

  /// No description provided for @floorPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Floor plan'**
  String get floorPlanTitle;

  /// No description provided for @floorPlanEmpty.
  ///
  /// In en, this message translates to:
  /// **'Load a picture of your home\'s plan (a drawing or a photo of it), then place devices on it. A tap on a device on the plan switches it.'**
  String get floorPlanEmpty;

  /// No description provided for @floorPlanPick.
  ///
  /// In en, this message translates to:
  /// **'Choose the plan picture'**
  String get floorPlanPick;

  /// No description provided for @floorPlanEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get floorPlanEdit;

  /// No description provided for @floorPlanAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a device'**
  String get floorPlanAdd;

  /// No description provided for @floorPlanChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Another picture'**
  String get floorPlanChangePhoto;

  /// No description provided for @floorPlanEditHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the devices to their places.'**
  String get floorPlanEditHint;

  /// No description provided for @floorPlanUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The floor plan is kept on the device, so it is not available on the web.'**
  String get floorPlanUnsupported;

  /// No description provided for @widgetHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get widgetHomeTitle;

  /// No description provided for @widgetLightsOff.
  ///
  /// In en, this message translates to:
  /// **'💡 All lights off'**
  String get widgetLightsOff;

  /// No description provided for @widgetLightsOn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{💡 1 light on} other{💡 {count} lights on}}'**
  String widgetLightsOn(int count);

  /// No description provided for @widgetAllClosed.
  ///
  /// In en, this message translates to:
  /// **'🚪 All closed'**
  String get widgetAllClosed;

  /// No description provided for @widgetOpen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{🚪 1 open} other{🚪 {count} open}}'**
  String widgetOpen(int count);

  /// No description provided for @widgetLocked.
  ///
  /// In en, this message translates to:
  /// **'🔒 Locked'**
  String get widgetLocked;

  /// No description provided for @widgetUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{🔓 1 unlocked} other{🔓 {count} unlocked}}'**
  String widgetUnlocked(int count);

  /// No description provided for @widgetUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated at {time}'**
  String widgetUpdated(String time);

  /// No description provided for @widgetNow.
  ///
  /// In en, this message translates to:
  /// **'Now {temperature}'**
  String widgetNow(String temperature);

  /// No description provided for @widgetSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Home screen widgets'**
  String get widgetSettingsTitle;

  /// No description provided for @widgetSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Add \"Home\", \"Thermostat\" and \"Light\" with a long press on the phone\'s home screen → Widgets. They refresh while the app runs.'**
  String get widgetSettingsHint;

  /// No description provided for @widgetThermostat.
  ///
  /// In en, this message translates to:
  /// **'Thermostat on the widget'**
  String get widgetThermostat;

  /// No description provided for @widgetLight.
  ///
  /// In en, this message translates to:
  /// **'Light on the widget'**
  String get widgetLight;

  /// No description provided for @nowPlayingSetting.
  ///
  /// In en, this message translates to:
  /// **'Music in the notifications'**
  String get nowPlayingSetting;

  /// No description provided for @nowPlayingSettingHint.
  ///
  /// In en, this message translates to:
  /// **'While a speaker at home plays, the notifications show the title with pause and next — without opening the app. Works while the app runs (also in the background, if the background connection is on).'**
  String get nowPlayingSettingHint;

  /// No description provided for @nowPlayingPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get nowPlayingPause;

  /// No description provided for @nowPlayingPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get nowPlayingPlay;

  /// No description provided for @nowPlayingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nowPlayingNext;

  /// No description provided for @nowPlayingChannel.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlayingChannel;

  /// No description provided for @simpleWarmer.
  ///
  /// In en, this message translates to:
  /// **'Warmer'**
  String get simpleWarmer;

  /// No description provided for @simpleCooler.
  ///
  /// In en, this message translates to:
  /// **'Cooler'**
  String get simpleCooler;

  /// No description provided for @settingsHomeSection.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get settingsHomeSection;

  /// No description provided for @settingsHomeHint.
  ///
  /// In en, this message translates to:
  /// **'Devices and rooms'**
  String get settingsHomeHint;

  /// No description provided for @firstRunWelcomeBodyLite.
  ///
  /// In en, this message translates to:
  /// **'The phone controls your devices itself, no server needed. Let\'s set the app up — it takes a minute, and everything can be changed later in Settings.'**
  String get firstRunWelcomeBodyLite;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsAboutHint.
  ///
  /// In en, this message translates to:
  /// **'Version and updates'**
  String get settingsAboutHint;

  /// No description provided for @addDeviceLanHint.
  ///
  /// In en, this message translates to:
  /// **'Shelly, WLED, ESPHome, Hue, Yeelight and Kasa devices on the same Wi-Fi network as the phone show up here by themselves. Add Tasmota devices by their IP address.'**
  String get addDeviceLanHint;

  /// No description provided for @addDeviceSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices…'**
  String get addDeviceSearching;

  /// No description provided for @addDeviceNoneYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Check that the phone is on the same Wi-Fi network as the device, or enter its IP address.'**
  String get addDeviceNoneYet;

  /// No description provided for @addDeviceManual.
  ///
  /// In en, this message translates to:
  /// **'Enter IP address'**
  String get addDeviceManual;

  /// No description provided for @addDeviceAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Device IP address'**
  String get addDeviceAddressLabel;

  /// No description provided for @addDeviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'No supported device found at that address.'**
  String get addDeviceNotFound;

  /// No description provided for @addDeviceAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get addDeviceAdded;

  /// No description provided for @addDeviceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addDeviceAdd;

  /// No description provided for @addDeviceDone.
  ///
  /// In en, this message translates to:
  /// **'{name} added.'**
  String addDeviceDone(String name);

  /// No description provided for @addDeviceWhere.
  ///
  /// In en, this message translates to:
  /// **'Which room?'**
  String get addDeviceWhere;

  /// No description provided for @roomNew.
  ///
  /// In en, this message translates to:
  /// **'New room…'**
  String get roomNew;

  /// No description provided for @roomNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get roomNameLabel;

  /// No description provided for @roomDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete room'**
  String get roomDelete;

  /// No description provided for @roomDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the room {name}? Its devices stay, without a room.'**
  String roomDeleteConfirm(String name);

  /// No description provided for @deviceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get deviceRemove;

  /// No description provided for @deviceRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the app? The device keeps working.'**
  String deviceRemoveConfirm(String name);

  /// No description provided for @homeDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get homeDevicesTitle;

  /// No description provided for @devicePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Device password'**
  String get devicePasswordLabel;

  /// No description provided for @devicePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'This device asks for a password (user admin). It is kept only on this phone, in secure storage.'**
  String get devicePasswordHint;

  /// No description provided for @devicePasswordChange.
  ///
  /// In en, this message translates to:
  /// **'Device password…'**
  String get devicePasswordChange;

  /// No description provided for @deviceKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Encryption key'**
  String get deviceKeyLabel;

  /// No description provided for @deviceKeyHint.
  ///
  /// In en, this message translates to:
  /// **'This ESPHome device encrypts its connection. Enter the key from its YAML (api → encryption → key). It is kept only on this phone, in secure storage.'**
  String get deviceKeyHint;

  /// No description provided for @deviceKeyWrong.
  ///
  /// In en, this message translates to:
  /// **'That key is not right. Check it in the device\'s YAML.'**
  String get deviceKeyWrong;

  /// No description provided for @deviceKeyNotEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This device does not encrypt its connection; leave the key empty.'**
  String get deviceKeyNotEncrypted;

  /// No description provided for @hueLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing with the Hue bridge'**
  String get hueLinkTitle;

  /// No description provided for @hueLinkBody.
  ///
  /// In en, this message translates to:
  /// **'Press the round button on top of the Hue bridge. The app waits 30 seconds.'**
  String get hueLinkBody;

  /// No description provided for @hueLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'The bridge\'s button was not pressed. Try again.'**
  String get hueLinkFailed;

  /// No description provided for @sceneHintLocal.
  ///
  /// In en, this message translates to:
  /// **'Keeps how the chosen devices are set now (on/off, brightness, colour, blinds, temperature). Running the scene sets them so again.'**
  String get sceneHintLocal;

  /// No description provided for @sceneSavedLocal.
  ///
  /// In en, this message translates to:
  /// **'Scene saved.'**
  String get sceneSavedLocal;

  /// No description provided for @autoSavedLocal.
  ///
  /// In en, this message translates to:
  /// **'Automation saved.'**
  String get autoSavedLocal;

  /// No description provided for @autoHintLocal.
  ///
  /// In en, this message translates to:
  /// **'Runs on this phone: while the app is open, on a wall panel in kiosk mode, or with running in the background on (Settings → Home).'**
  String get autoHintLocal;

  /// No description provided for @autoSunNeedsHome.
  ///
  /// In en, this message translates to:
  /// **'Sunrise and sunset need the home\'s location: turn on the home forecast (Settings → Privacy).'**
  String get autoSunNeedsHome;

  /// No description provided for @autoActionTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get autoActionTurnOn;

  /// No description provided for @autoActionTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get autoActionTurnOff;

  /// No description provided for @autoActionToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get autoActionToggle;

  /// No description provided for @autoActionBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness {percent} %'**
  String autoActionBrightness(int percent);

  /// No description provided for @autoActionScene.
  ///
  /// In en, this message translates to:
  /// **'Run scene'**
  String get autoActionScene;

  /// No description provided for @autoPickAction.
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get autoPickAction;

  /// No description provided for @autoTriggerAt.
  ///
  /// In en, this message translates to:
  /// **'At {time}'**
  String autoTriggerAt(String time);

  /// No description provided for @autoDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get autoDays;

  /// No description provided for @autoStateIs.
  ///
  /// In en, this message translates to:
  /// **'{device}: {state}'**
  String autoStateIs(String device, String state);

  /// No description provided for @autoValueAbove.
  ///
  /// In en, this message translates to:
  /// **'{device} above {value}'**
  String autoValueAbove(String device, String value);

  /// No description provided for @autoValueBelow.
  ///
  /// In en, this message translates to:
  /// **'{device} below {value}'**
  String autoValueBelow(String device, String value);

  /// No description provided for @autoTargetOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get autoTargetOn;

  /// No description provided for @autoTargetOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get autoTargetOff;

  /// No description provided for @autoTargetOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get autoTargetOpen;

  /// No description provided for @autoTargetClosed.
  ///
  /// In en, this message translates to:
  /// **'closed'**
  String get autoTargetClosed;

  /// No description provided for @autoTargetActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get autoTargetActive;

  /// No description provided for @autoTargetInactive.
  ///
  /// In en, this message translates to:
  /// **'inactive'**
  String get autoTargetInactive;

  /// No description provided for @autoTargetLocked.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get autoTargetLocked;

  /// No description provided for @autoTargetUnlocked.
  ///
  /// In en, this message translates to:
  /// **'unlocked'**
  String get autoTargetUnlocked;

  /// No description provided for @autoBefore.
  ///
  /// In en, this message translates to:
  /// **'before'**
  String get autoBefore;

  /// No description provided for @autoAfter.
  ///
  /// In en, this message translates to:
  /// **'after'**
  String get autoAfter;

  /// No description provided for @backgroundAutomations.
  ///
  /// In en, this message translates to:
  /// **'Automations in the background'**
  String get backgroundAutomations;

  /// No description provided for @backgroundAutomationsHint.
  ///
  /// In en, this message translates to:
  /// **'The app keeps running when closed, so automations work. Android then shows a permanent notification.'**
  String get backgroundAutomationsHint;

  /// No description provided for @backgroundNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Automations are running'**
  String get backgroundNotificationText;

  /// No description provided for @sceneEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit scene'**
  String get sceneEdit;

  /// No description provided for @bleNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth sensors nearby'**
  String get bleNearbyTitle;

  /// No description provided for @bleNearbyHint.
  ///
  /// In en, this message translates to:
  /// **'Thermometers and door, motion and leak sensors that send their values over Bluetooth (BTHome, Shelly BLU, Xiaomi with pvvx/ATC firmware, SwitchBot Meter, Govee). The phone only listens, it does not connect.'**
  String get bleNearbyHint;

  /// No description provided for @blePermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Bluetooth'**
  String get blePermission;

  /// No description provided for @blePermissionHint.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth sensors need the nearby devices permission.'**
  String get blePermissionHint;

  /// No description provided for @bleOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off. Turn it on for the sensors to show up.'**
  String get bleOff;

  /// No description provided for @bleNoneYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Sensors call in every few seconds to a minute.'**
  String get bleNoneYet;

  /// No description provided for @backupWithSecrets.
  ///
  /// In en, this message translates to:
  /// **'With the devices\' passwords and keys'**
  String get backupWithSecrets;

  /// No description provided for @backupWithSecretsHint.
  ///
  /// In en, this message translates to:
  /// **'Encrypted with a password you choose; without it nobody can read them.'**
  String get backupWithSecretsHint;

  /// No description provided for @backupPassword.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPassword;

  /// No description provided for @backupPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters.'**
  String get backupPasswordShort;

  /// No description provided for @backupSaveFile.
  ///
  /// In en, this message translates to:
  /// **'Save to a file'**
  String get backupSaveFile;

  /// No description provided for @backupOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Load from a file'**
  String get backupOpenFile;

  /// No description provided for @backupSend.
  ///
  /// In en, this message translates to:
  /// **'Send to another device'**
  String get backupSend;

  /// No description provided for @backupReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive from another device'**
  String get backupReceive;

  /// No description provided for @backupSendTitle.
  ///
  /// In en, this message translates to:
  /// **'On the other device choose “Receive from another device” and enter:'**
  String get backupSendTitle;

  /// No description provided for @backupAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get backupAddress;

  /// No description provided for @backupCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get backupCode;

  /// No description provided for @backupSendWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device (5 minutes at most). Both have to be on the same Wi-Fi.'**
  String get backupSendWaiting;

  /// No description provided for @backupSent.
  ///
  /// In en, this message translates to:
  /// **'Sent.'**
  String get backupSent;

  /// No description provided for @backupUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The other device does not answer. Check the address and that both are on the same Wi-Fi.'**
  String get backupUnreachable;

  /// No description provided for @backupWrongCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not right.'**
  String get backupWrongCode;

  /// No description provided for @backupNoWifi.
  ///
  /// In en, this message translates to:
  /// **'This device is not on a Wi-Fi network.'**
  String get backupNoWifi;

  /// No description provided for @backupHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How to import?'**
  String get backupHowTitle;

  /// No description provided for @backupReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get backupReplace;

  /// No description provided for @backupReplaceHint.
  ///
  /// In en, this message translates to:
  /// **'The devices, rooms, scenes and automations here are replaced by the backup\'s.'**
  String get backupReplaceHint;

  /// No description provided for @backupMerge.
  ///
  /// In en, this message translates to:
  /// **'Add only what is new'**
  String get backupMerge;

  /// No description provided for @backupMergeHint.
  ///
  /// In en, this message translates to:
  /// **'Everything here stays; what is missing is added.'**
  String get backupMergeHint;

  /// No description provided for @backupAskPassword.
  ///
  /// In en, this message translates to:
  /// **'This backup has the devices\' passwords and keys. Enter the password it was made with.'**
  String get backupAskPassword;

  /// No description provided for @backupWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is not right.'**
  String get backupWrongPassword;

  /// No description provided for @linkTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing: {brand}'**
  String linkTitle(String brand);

  /// No description provided for @linkFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing did not work. Try again.'**
  String get linkFailed;

  /// No description provided for @nanoleafLinkBody.
  ///
  /// In en, this message translates to:
  /// **'Hold the power button on the Nanoleaf for 5–7 seconds, until the lights flash. The app waits 30 seconds.'**
  String get nanoleafLinkBody;

  /// No description provided for @tvLinkBody.
  ///
  /// In en, this message translates to:
  /// **'The TV asks whether the app may connect: choose Allow. The app waits 30 seconds.'**
  String get tvLinkBody;

  /// No description provided for @dirigeraLinkBody.
  ///
  /// In en, this message translates to:
  /// **'Press the action button on the back of the DIRIGERA hub. The app waits 30 seconds.'**
  String get dirigeraLinkBody;

  /// No description provided for @tpLinkAccountHint.
  ///
  /// In en, this message translates to:
  /// **'A Tapo device checks the TP-Link account on the device itself: enter the e-mail and password of the account it was added to. Nothing is sent to TP-Link.'**
  String get tpLinkAccountHint;

  /// No description provided for @tpLinkUserLabel.
  ///
  /// In en, this message translates to:
  /// **'TP-Link account e-mail'**
  String get tpLinkUserLabel;

  /// No description provided for @tpLinkWrongAccount.
  ///
  /// In en, this message translates to:
  /// **'The device does not accept this e-mail and password.'**
  String get tpLinkWrongAccount;

  /// No description provided for @tuyaKeyHint.
  ///
  /// In en, this message translates to:
  /// **'A Tuya device (Smart Life, Tuya Smart…) needs its local key, 16 characters. It is taken once from the Tuya account (e.g. with the tinytuya wizard); after that the app talks to the device directly.'**
  String get tuyaKeyHint;

  /// No description provided for @miioTokenHint.
  ///
  /// In en, this message translates to:
  /// **'A Xiaomi device needs its token, 32 characters. It is taken once from the Mi Home account (e.g. with Xiaomi Cloud Tokens Extractor).'**
  String get miioTokenHint;

  /// No description provided for @deviceTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Local key / token'**
  String get deviceTokenLabel;

  /// No description provided for @deviceTokenWrong.
  ///
  /// In en, this message translates to:
  /// **'The device does not accept this key.'**
  String get deviceTokenWrong;

  /// No description provided for @irButtonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote buttons'**
  String get irButtonsTitle;

  /// No description provided for @irButtonsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No buttons learned yet. Learn them from the original remote.'**
  String get irButtonsEmpty;

  /// No description provided for @irLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn a button'**
  String get irLearn;

  /// No description provided for @irLearnName.
  ///
  /// In en, this message translates to:
  /// **'Button name (e.g. AC on)'**
  String get irLearnName;

  /// No description provided for @irLearnPress.
  ///
  /// In en, this message translates to:
  /// **'Point the original remote at the device and press the button. Waiting 20 seconds.'**
  String get irLearnPress;

  /// No description provided for @irLearnFailed.
  ///
  /// In en, this message translates to:
  /// **'The device did not hear the button. Try again, closer.'**
  String get irLearnFailed;

  /// No description provided for @irLearned.
  ///
  /// In en, this message translates to:
  /// **'Button \"{name}\" learned.'**
  String irLearned(String name);

  /// No description provided for @irSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get irSend;

  /// No description provided for @irDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete button'**
  String get irDelete;

  /// No description provided for @cameraAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a camera'**
  String get cameraAdd;

  /// No description provided for @cameraUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera image address'**
  String get cameraUrlLabel;

  /// No description provided for @cameraUrlHint.
  ///
  /// In en, this message translates to:
  /// **'A camera serves its current image at an address of its own. For example: Reolink /cgi-bin/api.cgi?cmd=Snap&channel=0, Hikvision /ISAPI/Streaming/channels/101/picture, Dahua /cgi-bin/snapshot.cgi, ESP32-CAM /capture.'**
  String get cameraUrlHint;

  /// No description provided for @cameraUserLabel.
  ///
  /// In en, this message translates to:
  /// **'User (if the camera asks)'**
  String get cameraUserLabel;

  /// No description provided for @cameraNoImage.
  ///
  /// In en, this message translates to:
  /// **'There is no camera image at this address (or the user is wrong).'**
  String get cameraNoImage;

  /// No description provided for @cameraOffline.
  ///
  /// In en, this message translates to:
  /// **'The camera is not giving an image right now.'**
  String get cameraOffline;

  /// No description provided for @emptyHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'No devices yet'**
  String get emptyHomeTitle;

  /// No description provided for @emptyHomeBody.
  ///
  /// In en, this message translates to:
  /// **'Add devices from your home Wi-Fi or over Bluetooth: Shelly, Hue, WiZ, Tapo, Tuya, ESPHome, TVs and more.'**
  String get emptyHomeBody;

  /// No description provided for @householdAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a member'**
  String get householdAdd;

  /// No description provided for @householdName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get householdName;

  /// No description provided for @householdRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get householdRemove;

  /// No description provided for @personMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get personMember;

  /// No description provided for @setupHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Device not showing up?'**
  String get setupHelpTitle;

  /// No description provided for @setupHelpHint.
  ///
  /// In en, this message translates to:
  /// **'The phone and the device must be on the same Wi-Fi. What else is needed, by maker:'**
  String get setupHelpHint;

  /// No description provided for @tipShelly.
  ///
  /// In en, this message translates to:
  /// **'Works as is. If the device has a password (Restrict login), enter it when adding.'**
  String get tipShelly;

  /// No description provided for @tipWled.
  ///
  /// In en, this message translates to:
  /// **'Works as is.'**
  String get tipWled;

  /// No description provided for @tipTasmota.
  ///
  /// In en, this message translates to:
  /// **'Usually does not announce itself: add it by its IP address.'**
  String get tipTasmota;

  /// No description provided for @tipEsphome.
  ///
  /// In en, this message translates to:
  /// **'The device\'s configuration needs api:. With encryption on (api: encryption: key), enter that key.'**
  String get tipEsphome;

  /// No description provided for @tipHue.
  ///
  /// In en, this message translates to:
  /// **'Add the Hue bridge; when pairing, press the round button on top of it. The bridge\'s lights and sensors come with it.'**
  String get tipHue;

  /// No description provided for @tipYeelight.
  ///
  /// In en, this message translates to:
  /// **'In the Yeelight app, turn on \"LAN Control\" for each bulb.'**
  String get tipYeelight;

  /// No description provided for @tipWiz.
  ///
  /// In en, this message translates to:
  /// **'In the WiZ app, local communication must be allowed (Settings → Security → Allow local communication).'**
  String get tipWiz;

  /// No description provided for @tipLifx.
  ///
  /// In en, this message translates to:
  /// **'Works as is.'**
  String get tipLifx;

  /// No description provided for @tipGovee.
  ///
  /// In en, this message translates to:
  /// **'In the Govee app, turn on \"LAN Control\" in the device\'s settings. Not every model has it.'**
  String get tipGovee;

  /// No description provided for @tipNanoleaf.
  ///
  /// In en, this message translates to:
  /// **'When pairing, hold the power button for 5–7 seconds, until the lights flash.'**
  String get tipNanoleaf;

  /// No description provided for @tipSonoff.
  ///
  /// In en, this message translates to:
  /// **'Works in DIY mode only: turn it on in the eWeLink app or with the device\'s DIY switch.'**
  String get tipSonoff;

  /// No description provided for @tipTpLink.
  ///
  /// In en, this message translates to:
  /// **'Older Kasa devices work as is. Tapo and newer Kasa need the TP-Link account\'s e-mail and password; add them by IP address.'**
  String get tipTpLink;

  /// No description provided for @tipDirigera.
  ///
  /// In en, this message translates to:
  /// **'When pairing, press the action button on the back of the hub. The hub\'s IKEA devices come with it.'**
  String get tipDirigera;

  /// No description provided for @tipTuya.
  ///
  /// In en, this message translates to:
  /// **'Needs the device\'s local key (16 characters), taken once from the Tuya account, e.g. with the tinytuya wizard. Devices on protocol 3.5 do not work yet.'**
  String get tipTuya;

  /// No description provided for @tipXiaomi.
  ///
  /// In en, this message translates to:
  /// **'Needs the device\'s token (32 characters), e.g. from Xiaomi Cloud Tokens Extractor. Plugs and lights (MIoT), Chuangmi plugs and Roborock vacuums work.'**
  String get tipXiaomi;

  /// No description provided for @tipBroadlink.
  ///
  /// In en, this message translates to:
  /// **'In the Broadlink app the device must be unlocked (Unlock device); then learn buttons on the device\'s screen.'**
  String get tipBroadlink;

  /// No description provided for @tipSamsung.
  ///
  /// In en, this message translates to:
  /// **'On the first connection choose Allow on the TV. To turn it on from the phone, enable \"Power On with Mobile\" (or IP Remote) in the TV\'s settings.'**
  String get tipSamsung;

  /// No description provided for @tipLg.
  ///
  /// In en, this message translates to:
  /// **'On the first connection accept on the TV. To turn it on from the phone, enable \"Turn on via Wi-Fi\" (Mobile TV On).'**
  String get tipLg;

  /// No description provided for @tipRoku.
  ///
  /// In en, this message translates to:
  /// **'In the Roku\'s settings (System → Advanced system settings → Control by mobile apps) allow network access.'**
  String get tipRoku;

  /// No description provided for @tipSonos.
  ///
  /// In en, this message translates to:
  /// **'Works as is.'**
  String get tipSonos;

  /// No description provided for @tipCamera.
  ///
  /// In en, this message translates to:
  /// **'The \"Add a camera\" button: the camera\'s image address (examples in the dialog) and a user, if the camera asks.'**
  String get tipCamera;

  /// No description provided for @tipBluetooth.
  ///
  /// In en, this message translates to:
  /// **'The phone must be near (up to ~10 m). BTHome (Shelly BLU), Xiaomi with pvvx/ATC firmware, SwitchBot and Govee thermometers work; encrypted BTHome and Xiaomi MiBeacon do not.'**
  String get tipBluetooth;

  /// No description provided for @tipUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The device is not answering right now.'**
  String get tipUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'sr':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsSrLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sr':
      return AppLocalizationsSr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
