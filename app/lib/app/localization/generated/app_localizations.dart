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

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your home, in one app'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Control lights, climate, sensors and scenes from every brand and protocol your Home Assistant server supports.'**
  String get welcomeBody;

  /// No description provided for @welcomeLocalFirst.
  ///
  /// In en, this message translates to:
  /// **'Works locally. No cloud account required.'**
  String get welcomeLocalFirst;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get chooseLanguage;

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

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

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

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @serverAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to Home Assistant'**
  String get serverAddressTitle;

  /// No description provided for @serverAddressIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of your Home Assistant server, for example the one you open in a browser at home.'**
  String get serverAddressIntro;

  /// No description provided for @serverAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddressLabel;

  /// No description provided for @serverAddressHint.
  ///
  /// In en, this message translates to:
  /// **'homeassistant.local:8123'**
  String get serverAddressHint;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get checkConnection;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @serverReachable.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant found at {address}'**
  String serverReachable(String address);

  /// No description provided for @addressErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a server address.'**
  String get addressErrorEmpty;

  /// No description provided for @addressErrorMalformed.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid address.'**
  String get addressErrorMalformed;

  /// No description provided for @addressErrorUnsupportedScheme.
  ///
  /// In en, this message translates to:
  /// **'Only http:// and https:// addresses are supported.'**
  String get addressErrorUnsupportedScheme;

  /// No description provided for @addressErrorMissingHost.
  ///
  /// In en, this message translates to:
  /// **'The address is missing a host name or IP address.'**
  String get addressErrorMissingHost;

  /// No description provided for @addressErrorCredentials.
  ///
  /// In en, this message translates to:
  /// **'Do not put a user name or password in the address.'**
  String get addressErrorCredentials;

  /// No description provided for @addressErrorPath.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant must be served from the root of the address (no path such as /ha).'**
  String get addressErrorPath;

  /// No description provided for @addressErrorQuery.
  ///
  /// In en, this message translates to:
  /// **'Remove the part after ? or # from the address.'**
  String get addressErrorQuery;

  /// No description provided for @addressErrorPort.
  ///
  /// In en, this message translates to:
  /// **'The port must be between 1 and 65535.'**
  String get addressErrorPort;

  /// No description provided for @riskLocalHttp.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted connection inside your local network.'**
  String get riskLocalHttp;

  /// No description provided for @riskRemoteExposure.
  ///
  /// In en, this message translates to:
  /// **'This is a public address. Make sure your server is kept up to date and protected.'**
  String get riskRemoteExposure;

  /// No description provided for @riskInsecureRemote.
  ///
  /// In en, this message translates to:
  /// **'Warning: this public address uses unencrypted HTTP. Your access token could be intercepted. Use HTTPS unless the connection runs through a VPN.'**
  String get riskInsecureRemote;

  /// No description provided for @insecureAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand the risk (e.g. I use a VPN)'**
  String get insecureAcknowledge;

  /// No description provided for @certificateUntrustedTitle.
  ///
  /// In en, this message translates to:
  /// **'Untrusted certificate'**
  String get certificateUntrustedTitle;

  /// No description provided for @certificateUntrustedBody.
  ///
  /// In en, this message translates to:
  /// **'The server\'s certificate is not trusted by this device. This is normal for a self-signed certificate, but can also mean someone is intercepting the connection. Only continue if the fingerprint matches the one shown on your server.'**
  String get certificateUntrustedBody;

  /// No description provided for @certificateSubject.
  ///
  /// In en, this message translates to:
  /// **'Issued to'**
  String get certificateSubject;

  /// No description provided for @certificateIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issued by'**
  String get certificateIssuer;

  /// No description provided for @certificateValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get certificateValidUntil;

  /// No description provided for @certificateFingerprint.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 fingerprint'**
  String get certificateFingerprint;

  /// No description provided for @certificateExpired.
  ///
  /// In en, this message translates to:
  /// **'This certificate has expired.'**
  String get certificateExpired;

  /// No description provided for @certificateConfirm.
  ///
  /// In en, this message translates to:
  /// **'I compared the fingerprint and trust this certificate'**
  String get certificateConfirm;

  /// No description provided for @trustCertificate.
  ///
  /// In en, this message translates to:
  /// **'Trust this certificate'**
  String get trustCertificate;

  /// No description provided for @tokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get tokenTitle;

  /// No description provided for @tokenIntro.
  ///
  /// In en, this message translates to:
  /// **'The app signs in with a long-lived access token from your Home Assistant user profile.'**
  String get tokenIntro;

  /// No description provided for @tokenSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Open Home Assistant in a browser.\n2. Click your user name (bottom left) → Security.\n3. Under “Long-lived access tokens” choose “Create token”.\n4. Copy the token and paste it below. Home Assistant shows it only once.'**
  String get tokenSteps;

  /// No description provided for @tokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get tokenLabel;

  /// No description provided for @tokenMockHint.
  ///
  /// In en, this message translates to:
  /// **'Mock mode: any token works; “invalid” simulates a rejected token.'**
  String get tokenMockHint;

  /// No description provided for @showToken.
  ///
  /// In en, this message translates to:
  /// **'Show token'**
  String get showToken;

  /// No description provided for @hideToken.
  ///
  /// In en, this message translates to:
  /// **'Hide token'**
  String get hideToken;

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

  /// No description provided for @tokenInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'The token must not be empty or contain spaces.'**
  String get tokenInvalidFormat;

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'The server cannot be reached. Check the address and that this device is on the right network.'**
  String get failureNetwork;

  /// No description provided for @failureTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond.'**
  String get failureTimeout;

  /// No description provided for @failureAuthentication.
  ///
  /// In en, this message translates to:
  /// **'The access token was rejected. It may be wrong, expired or revoked.'**
  String get failureAuthentication;

  /// No description provided for @failureAuthorization.
  ///
  /// In en, this message translates to:
  /// **'This user is not allowed to perform this action.'**
  String get failureAuthorization;

  /// No description provided for @failureValidation.
  ///
  /// In en, this message translates to:
  /// **'The request was not accepted by the server.'**
  String get failureValidation;

  /// No description provided for @failureParsing.
  ///
  /// In en, this message translates to:
  /// **'The server sent an unexpected response.'**
  String get failureParsing;

  /// No description provided for @failureServer.
  ///
  /// In en, this message translates to:
  /// **'The server responded, but not like Home Assistant, or reported an error.'**
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

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get statusConnecting;

  /// No description provided for @statusAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get statusAuthenticating;

  /// No description provided for @statusReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get statusReconnecting;

  /// No description provided for @statusReconnectingIn.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting in {seconds} s'**
  String statusReconnectingIn(int seconds);

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @statusAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in rejected'**
  String get statusAuthFailed;

  /// No description provided for @statusServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server unavailable'**
  String get statusServerUnavailable;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get statusError;

  /// No description provided for @retryNow.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get retryNow;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// No description provided for @serverVersion.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant {version}'**
  String serverVersion(String version);

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

  /// No description provided for @serverSection.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverSection;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The access token will be deleted from this device. You can sign in again at any time.'**
  String get signOutConfirmBody;

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
  /// **'This removes the access token, server address and all settings from this device. Nothing is changed on your Home Assistant server.'**
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

  /// No description provided for @addressErrorMixedContent.
  ///
  /// In en, this message translates to:
  /// **'This page is loaded over HTTPS, so the browser blocks connections to an http:// server. Use the server\'s https:// address, or open this web app from the same address as Home Assistant.'**
  String get addressErrorMixedContent;

  /// No description provided for @webConnectionHint.
  ///
  /// In en, this message translates to:
  /// **'In a browser this can also mean that Home Assistant does not allow this web app\'s address (add it to http: cors_allowed_origins in configuration.yaml), or that the browser does not trust the server\'s certificate (open the server address in a new tab once and accept it there).'**
  String get webConnectionHint;

  /// No description provided for @webSessionNotice.
  ///
  /// In en, this message translates to:
  /// **'With a token, sign-in lasts only while this tab is open.'**
  String get webSessionNotice;

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
  /// **'No rooms are defined in Home Assistant.'**
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
  /// **'Entity ID'**
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

  /// No description provided for @oauthSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Home Assistant'**
  String get oauthSignIn;

  /// No description provided for @oauthHint.
  ///
  /// In en, this message translates to:
  /// **'You sign in on your Home Assistant\'s own login page – this app never sees your password.'**
  String get oauthHint;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me on this device'**
  String get rememberMe;

  /// No description provided for @rememberMeHint.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in after the browser is closed. You can revoke access anytime in your Home Assistant profile (Security → Refresh tokens).'**
  String get rememberMeHint;

  /// No description provided for @orUseToken.
  ///
  /// In en, this message translates to:
  /// **'Or use a long-lived access token'**
  String get orUseToken;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not complete. Please try again.'**
  String get loginFailed;

  /// No description provided for @discoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant on this network'**
  String get discoveryTitle;

  /// No description provided for @discoverySearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get discoverySearching;

  /// No description provided for @discoveryNothingFound.
  ///
  /// In en, this message translates to:
  /// **'No server found automatically. Enter the address below.'**
  String get discoveryNothingFound;

  /// No description provided for @discoverySearchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get discoverySearchAgain;

  /// No description provided for @energyTitle.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energyTitle;

  /// No description provided for @energyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get energyToday;

  /// No description provided for @energyWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get energyWeek;

  /// No description provided for @energyMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get energyMonth;

  /// No description provided for @energyCurrentPower.
  ///
  /// In en, this message translates to:
  /// **'Power now'**
  String get energyCurrentPower;

  /// No description provided for @energyNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Energy is not set up in Home Assistant yet (Settings → Dashboards → Energy). Once it is, consumption, solar and devices appear here.'**
  String get energyNotConfigured;

  /// No description provided for @energyOffline.
  ///
  /// In en, this message translates to:
  /// **'Energy statistics are loaded from Home Assistant and are available while connected.'**
  String get energyOffline;

  /// No description provided for @energyConsumption.
  ///
  /// In en, this message translates to:
  /// **'Home consumption'**
  String get energyConsumption;

  /// No description provided for @energyFromGrid.
  ///
  /// In en, this message translates to:
  /// **'From grid'**
  String get energyFromGrid;

  /// No description provided for @energyToGrid.
  ///
  /// In en, this message translates to:
  /// **'To grid'**
  String get energyToGrid;

  /// No description provided for @energySolar.
  ///
  /// In en, this message translates to:
  /// **'Solar production'**
  String get energySolar;

  /// No description provided for @energyBatteryCharge.
  ///
  /// In en, this message translates to:
  /// **'Battery charged'**
  String get energyBatteryCharge;

  /// No description provided for @energyBatteryDischarge.
  ///
  /// In en, this message translates to:
  /// **'Battery discharged'**
  String get energyBatteryDischarge;

  /// No description provided for @energyGas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get energyGas;

  /// No description provided for @energyCostEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost'**
  String get energyCostEstimate;

  /// No description provided for @energySetTariff.
  ///
  /// In en, this message translates to:
  /// **'Enter a tariff for a cost estimate'**
  String get energySetTariff;

  /// No description provided for @energyPerHour.
  ///
  /// In en, this message translates to:
  /// **'Consumption per hour'**
  String get energyPerHour;

  /// No description provided for @energyPerDay.
  ///
  /// In en, this message translates to:
  /// **'Consumption per day'**
  String get energyPerDay;

  /// No description provided for @energyTopConsumers.
  ///
  /// In en, this message translates to:
  /// **'Top consumers'**
  String get energyTopConsumers;

  /// No description provided for @energyNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No individual devices are added to the Energy dashboard in Home Assistant.'**
  String get energyNoDevices;

  /// No description provided for @energyNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period yet.'**
  String get energyNoData;

  /// No description provided for @energyPeak.
  ///
  /// In en, this message translates to:
  /// **'Highest: {time} · {value}'**
  String energyPeak(String time, String value);

  /// No description provided for @energyShowChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get energyShowChart;

  /// No description provided for @energyShowTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get energyShowTable;

  /// No description provided for @energyConsumptionChart.
  ///
  /// In en, this message translates to:
  /// **'Consumption chart'**
  String get energyConsumptionChart;

  /// No description provided for @energyTariffTitle.
  ///
  /// In en, this message translates to:
  /// **'Electricity tariff'**
  String get energyTariffTitle;

  /// No description provided for @energyTariffHint.
  ///
  /// In en, this message translates to:
  /// **'Used only for an estimate on this device. Real bills also include fixed fees, taxes and consumption zones.'**
  String get energyTariffHint;

  /// No description provided for @energyTariffImport.
  ///
  /// In en, this message translates to:
  /// **'Price per kWh from the grid'**
  String get energyTariffImport;

  /// No description provided for @energyTariffExport.
  ///
  /// In en, this message translates to:
  /// **'Compensation per kWh to the grid (optional)'**
  String get energyTariffExport;

  /// No description provided for @energyTariffCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get energyTariffCurrency;

  /// No description provided for @energyTariffInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid, non-negative price.'**
  String get energyTariffInvalid;

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

  /// No description provided for @thermostatModes.
  ///
  /// In en, this message translates to:
  /// **'Modes'**
  String get thermostatModes;

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

  /// No description provided for @householdTitle.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get householdTitle;

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
  /// **'Your Home Assistant weather entity provides no forecast.'**
  String get weatherNoForecast;

  /// No description provided for @weatherPrecipitation.
  ///
  /// In en, this message translates to:
  /// **'Precipitation'**
  String get weatherPrecipitation;

  /// No description provided for @weatherFeelsHint.
  ///
  /// In en, this message translates to:
  /// **'From your Home Assistant weather entity. Nothing leaves your network.'**
  String get weatherFeelsHint;

  /// No description provided for @camerasTitle.
  ///
  /// In en, this message translates to:
  /// **'Cameras'**
  String get camerasTitle;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t sending images right now.'**
  String get cameraUnavailable;

  /// No description provided for @cameraSnapshotAt.
  ///
  /// In en, this message translates to:
  /// **'Snapshot {time}'**
  String cameraSnapshotAt(String time);

  /// No description provided for @cameraRefreshHint.
  ///
  /// In en, this message translates to:
  /// **'The picture refreshes every {seconds} s while this screen is open. Nothing is recorded or stored.'**
  String cameraRefreshHint(int seconds);

  /// No description provided for @cameraFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get cameraFullscreen;

  /// No description provided for @cameraLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the camera…'**
  String get cameraLoading;

  /// No description provided for @kioskShowCameras.
  ///
  /// In en, this message translates to:
  /// **'Show cameras'**
  String get kioskShowCameras;

  /// No description provided for @kioskShowCamerasHint.
  ///
  /// In en, this message translates to:
  /// **'Camera pictures are visible to anyone looking at the wall tablet.'**
  String get kioskShowCamerasHint;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get calendarTomorrow;

  /// No description provided for @calendarAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get calendarAllDay;

  /// No description provided for @calendarNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get calendarNoEvents;

  /// No description provided for @calendarNone.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant has no calendars. Add one there, for example Google Calendar, CalDAV or the Local Calendar integration.'**
  String get calendarNone;

  /// No description provided for @calendarUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The calendar isn\'t available right now.'**
  String get calendarUnavailable;

  /// No description provided for @calendarPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPrevMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// No description provided for @calendarBackToToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarBackToToday;

  /// No description provided for @assistTitle.
  ///
  /// In en, this message translates to:
  /// **'Assist'**
  String get assistTitle;

  /// No description provided for @assistHint.
  ///
  /// In en, this message translates to:
  /// **'Type a command or a question'**
  String get assistHint;

  /// No description provided for @assistSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get assistSend;

  /// No description provided for @assistIntro.
  ///
  /// In en, this message translates to:
  /// **'Ask Home Assistant to do something, for example:'**
  String get assistIntro;

  /// No description provided for @assistSuggestionLightsOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off the lights'**
  String get assistSuggestionLightsOff;

  /// No description provided for @assistSuggestionTemperature.
  ///
  /// In en, this message translates to:
  /// **'What is the temperature in the living room?'**
  String get assistSuggestionTemperature;

  /// No description provided for @assistSuggestionLightsOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on the lights'**
  String get assistSuggestionLightsOn;

  /// No description provided for @assistUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Assist isn\'t available right now.'**
  String get assistUnavailable;

  /// No description provided for @assistNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Assist couldn\'t do that.'**
  String get assistNotUnderstood;

  /// No description provided for @assistPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your text goes only to your Home Assistant server. Assist understands the languages set up there and acts with your account\'s permissions.'**
  String get assistPrivacy;

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

  /// No description provided for @mediaNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get mediaNowPlaying;

  /// No description provided for @addDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get addDeviceTitle;

  /// No description provided for @addDeviceIntro.
  ///
  /// In en, this message translates to:
  /// **'New devices pair with your Home Assistant hub, which has the Zigbee or Z-Wave radio, not with this phone. The app guides you through it.'**
  String get addDeviceIntro;

  /// No description provided for @addDeviceZigbee.
  ///
  /// In en, this message translates to:
  /// **'Zigbee'**
  String get addDeviceZigbee;

  /// No description provided for @addDeviceZigbeeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sensors, bulbs, plugs, switches'**
  String get addDeviceZigbeeSubtitle;

  /// No description provided for @addDeviceWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi and LAN'**
  String get addDeviceWifi;

  /// No description provided for @addDeviceMatter.
  ///
  /// In en, this message translates to:
  /// **'Matter'**
  String get addDeviceMatter;

  /// No description provided for @addDeviceZwave.
  ///
  /// In en, this message translates to:
  /// **'Z-Wave'**
  String get addDeviceZwave;

  /// No description provided for @addDeviceSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get addDeviceSoon;

  /// No description provided for @zigbeeViaZha.
  ///
  /// In en, this message translates to:
  /// **'Via ZHA'**
  String get zigbeeViaZha;

  /// No description provided for @zigbeeViaZ2m.
  ///
  /// In en, this message translates to:
  /// **'Via Zigbee2MQTT'**
  String get zigbeeViaZ2m;

  /// No description provided for @zigbeeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Neither ZHA nor Zigbee2MQTT was found in Home Assistant. Add a Zigbee coordinator there first.'**
  String get zigbeeNotFound;

  /// No description provided for @zigbeeStep1.
  ///
  /// In en, this message translates to:
  /// **'Start pairing with the button below.'**
  String get zigbeeStep1;

  /// No description provided for @zigbeeStep2.
  ///
  /// In en, this message translates to:
  /// **'Reset the device or put it in pairing mode. Usually you hold its button for about 5 seconds until it blinks; check the device\'s manual.'**
  String get zigbeeStep2;

  /// No description provided for @zigbeeStep3.
  ///
  /// In en, this message translates to:
  /// **'Keep the device near the hub until it shows up in the list.'**
  String get zigbeeStep3;

  /// No description provided for @pairingStart.
  ///
  /// In en, this message translates to:
  /// **'Start pairing'**
  String get pairingStart;

  /// No description provided for @pairingStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get pairingStop;

  /// No description provided for @pairingExtend.
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get pairingExtend;

  /// No description provided for @pairingOpen.
  ///
  /// In en, this message translates to:
  /// **'Pairing is on'**
  String get pairingOpen;

  /// No description provided for @pairingRemaining.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String pairingRemaining(String time);

  /// No description provided for @pairingClosed.
  ///
  /// In en, this message translates to:
  /// **'Pairing is off'**
  String get pairingClosed;

  /// No description provided for @pairingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for new devices…'**
  String get pairingWaiting;

  /// No description provided for @pairingFound.
  ///
  /// In en, this message translates to:
  /// **'New devices'**
  String get pairingFound;

  /// No description provided for @pairingFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing couldn\'t be started. {reason}'**
  String pairingFailed(String reason);

  /// No description provided for @newDeviceSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get newDeviceSetUp;

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

  /// No description provided for @setUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Name and room can\'t be changed from here. Do it in Home Assistant under Settings, Devices.'**
  String get setUpFailed;

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

  /// No description provided for @weatherNoHomeCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant has no home location set.'**
  String get weatherNoHomeCoordinates;

  /// No description provided for @calendarNoneShort.
  ///
  /// In en, this message translates to:
  /// **'No calendars in Home Assistant'**
  String get calendarNoneShort;

  /// No description provided for @mediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Music and media'**
  String get mediaTitle;

  /// No description provided for @mediaNoPlayers.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant has no media players yet. Add one there, for example Spotify, Google Cast, Sonos, DLNA, Kodi or your smart TV\'s integration, and it shows up here.'**
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

  /// No description provided for @weatherHomeLocationFar.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant\'s home location is about {km} km from this device. If that\'s wrong, set it in Home Assistant under Settings, System, General; the home forecast uses it.'**
  String weatherHomeLocationFar(int km);

  /// No description provided for @mediaNoPlayersShort.
  ///
  /// In en, this message translates to:
  /// **'No media players yet'**
  String get mediaNoPlayersShort;

  /// No description provided for @assistMic.
  ///
  /// In en, this message translates to:
  /// **'Speak a command'**
  String get assistMic;

  /// No description provided for @assistListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get assistListening;

  /// No description provided for @voicePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice commands'**
  String get voicePrivacyTitle;

  /// No description provided for @voicePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s speech recogniser turns speech into text; only the text goes to your Home Assistant. Some phones can only recognise speech online (for example Google\'s or Apple\'s service), which then receives a recording of your voice.'**
  String get voicePrivacyBody;

  /// No description provided for @voiceOnDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'On this device only'**
  String get voiceOnDeviceOnly;

  /// No description provided for @voiceAllowCloud.
  ///
  /// In en, this message translates to:
  /// **'Allow online too'**
  String get voiceAllowCloud;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition isn\'t available. Check the microphone permission.'**
  String get voiceUnavailable;

  /// No description provided for @voiceOnDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t recognise this language offline. You can allow online recognition in Settings.'**
  String get voiceOnDeviceUnavailable;

  /// No description provided for @voiceNoMatch.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t catch that. Try again.'**
  String get voiceNoMatch;

  /// No description provided for @voiceCloudSetting.
  ///
  /// In en, this message translates to:
  /// **'Online speech recognition'**
  String get voiceCloudSetting;

  /// No description provided for @voiceCloudSettingHint.
  ///
  /// In en, this message translates to:
  /// **'When off, voice commands are recognised on this device only.'**
  String get voiceCloudSettingHint;

  /// No description provided for @addDeviceWifiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Devices Home Assistant found on your network'**
  String get addDeviceWifiSubtitle;

  /// No description provided for @discoveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Found on the network'**
  String get discoveredTitle;

  /// No description provided for @discoveredEmpty.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant hasn\'t found any new devices. Connect the device to the same Wi-Fi network and wait a minute; devices HA can\'t find on its own are added in Home Assistant under Settings, Devices.'**
  String get discoveredEmpty;

  /// No description provided for @discoveredVia.
  ///
  /// In en, this message translates to:
  /// **'Found via {source}'**
  String discoveredVia(String source);

  /// No description provided for @discoveredRefresh.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get discoveredRefresh;

  /// No description provided for @discoveredUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The list of found devices isn\'t available. This usually needs an administrator account in Home Assistant.'**
  String get discoveredUnavailable;

  /// No description provided for @flowAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get flowAdd;

  /// No description provided for @flowNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get flowNext;

  /// No description provided for @flowConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add {name} to your home?'**
  String flowConfirm(String name);

  /// No description provided for @flowDone.
  ///
  /// In en, this message translates to:
  /// **'Added: {title}'**
  String flowDone(String title);

  /// No description provided for @flowDoneDevices.
  ///
  /// In en, this message translates to:
  /// **'New devices'**
  String get flowDoneDevices;

  /// No description provided for @flowAborted.
  ///
  /// In en, this message translates to:
  /// **'Setup stopped: {reason}'**
  String flowAborted(String reason);

  /// No description provided for @flowAbortedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant stopped the setup.'**
  String get flowAbortedGeneric;

  /// No description provided for @flowUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This step needs Home Assistant itself (for example a sign-in in a browser). Continue there.'**
  String get flowUnsupported;

  /// No description provided for @flowUnsupportedField.
  ///
  /// In en, this message translates to:
  /// **'This form has fields the app can\'t show yet. Continue in Home Assistant.'**
  String get flowUnsupportedField;

  /// No description provided for @flowWorking.
  ///
  /// In en, this message translates to:
  /// **'Setting up…'**
  String get flowWorking;

  /// No description provided for @flowRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get flowRequired;

  /// No description provided for @flowFinish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get flowFinish;

  /// No description provided for @matterTitle.
  ///
  /// In en, this message translates to:
  /// **'Matter'**
  String get matterTitle;

  /// No description provided for @matterIntro.
  ///
  /// In en, this message translates to:
  /// **'Add a Matter device that already works with another app (Google Home, Apple Home, SmartThings, Alexa…).'**
  String get matterIntro;

  /// No description provided for @matterStep1.
  ///
  /// In en, this message translates to:
  /// **'In that app, open the device and choose to share it with another app or controller (\"Linked Matter apps\", \"Turn on pairing mode\").'**
  String get matterStep1;

  /// No description provided for @matterStep2.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code it shows, or type the 11-digit code.'**
  String get matterStep2;

  /// No description provided for @matterStep3.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant then adds the device over your network; both apps can control it.'**
  String get matterStep3;

  /// No description provided for @matterNewDeviceNote.
  ///
  /// In en, this message translates to:
  /// **'Brand-new Matter devices over Bluetooth can be added from the Android app.'**
  String get matterNewDeviceNote;

  /// No description provided for @matterCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Setup code'**
  String get matterCodeLabel;

  /// No description provided for @matterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'1234-567-8901 or MT:…'**
  String get matterCodeHint;

  /// No description provided for @matterInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a valid Matter code. Check the digits.'**
  String get matterInvalidCode;

  /// No description provided for @matterScan.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get matterScan;

  /// No description provided for @matterAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding the device… this can take a minute.'**
  String get matterAdding;

  /// No description provided for @matterNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'The Matter integration isn\'t set up in Home Assistant. Add it there first.'**
  String get matterNotAvailable;

  /// No description provided for @matterFailed.
  ///
  /// In en, this message translates to:
  /// **'The device couldn\'t be added. Make sure sharing is still on in the other app (the code is valid for a few minutes) and the device is on the same network.'**
  String get matterFailed;

  /// No description provided for @matterAdded.
  ///
  /// In en, this message translates to:
  /// **'Device added'**
  String get matterAdded;

  /// No description provided for @scanPointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the Matter QR code.'**
  String get scanPointCamera;

  /// No description provided for @zwaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Z-Wave'**
  String get zwaveTitle;

  /// No description provided for @zwaveIntro.
  ///
  /// In en, this message translates to:
  /// **'Add a Z-Wave device through your Z-Wave JS controller.'**
  String get zwaveIntro;

  /// No description provided for @zwaveNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'The Z-Wave JS integration isn\'t set up in Home Assistant.'**
  String get zwaveNotAvailable;

  /// No description provided for @zwaveStart.
  ///
  /// In en, this message translates to:
  /// **'Start inclusion'**
  String get zwaveStart;

  /// No description provided for @zwaveStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get zwaveStop;

  /// No description provided for @zwaveStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Put the device into inclusion mode (often three quick presses of its button; see the manual).'**
  String get zwaveStatusWaiting;

  /// No description provided for @zwaveStatusFound.
  ///
  /// In en, this message translates to:
  /// **'Device found…'**
  String get zwaveStatusFound;

  /// No description provided for @zwaveStatusInterview.
  ///
  /// In en, this message translates to:
  /// **'Getting to know the device (interview)… battery devices can take a few minutes.'**
  String get zwaveStatusInterview;

  /// No description provided for @zwaveStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Device added'**
  String get zwaveStatusDone;

  /// No description provided for @zwaveStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Inclusion didn\'t work. Try again closer to the controller.'**
  String get zwaveStatusFailed;

  /// No description provided for @zwaveStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Inclusion stopped.'**
  String get zwaveStatusStopped;

  /// No description provided for @zwaveGrantTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get zwaveGrantTitle;

  /// No description provided for @zwaveGrantBody.
  ///
  /// In en, this message translates to:
  /// **'The device asks for these security levels. Allowing all of them is recommended.'**
  String get zwaveGrantBody;

  /// No description provided for @zwaveS2Unauth.
  ///
  /// In en, this message translates to:
  /// **'S2 unauthenticated'**
  String get zwaveS2Unauth;

  /// No description provided for @zwaveS2Auth.
  ///
  /// In en, this message translates to:
  /// **'S2 authenticated'**
  String get zwaveS2Auth;

  /// No description provided for @zwaveS2Access.
  ///
  /// In en, this message translates to:
  /// **'S2 access control (locks, garage doors)'**
  String get zwaveS2Access;

  /// No description provided for @zwaveS0.
  ///
  /// In en, this message translates to:
  /// **'S0 (legacy)'**
  String get zwaveS0;

  /// No description provided for @zwaveGrant.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get zwaveGrant;

  /// No description provided for @zwavePinTitle.
  ///
  /// In en, this message translates to:
  /// **'PIN from the device'**
  String get zwavePinTitle;

  /// No description provided for @zwavePinBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the first 5 digits of the DSK from the device label or box (usually underlined). The rest of the code: {dsk}'**
  String zwavePinBody(String dsk);

  /// No description provided for @zwavePinLabel.
  ///
  /// In en, this message translates to:
  /// **'5 digits'**
  String get zwavePinLabel;

  /// No description provided for @zwavePinInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter exactly 5 digits.'**
  String get zwavePinInvalid;

  /// No description provided for @zwaveSmartStart.
  ///
  /// In en, this message translates to:
  /// **'SmartStart: scan QR'**
  String get zwaveSmartStart;

  /// No description provided for @zwaveSmartStartHint.
  ///
  /// In en, this message translates to:
  /// **'Devices with a SmartStart QR code join by themselves once powered on.'**
  String get zwaveSmartStartHint;

  /// No description provided for @zwaveSmartStartDone.
  ///
  /// In en, this message translates to:
  /// **'Device registered. Power it on; it joins by itself within a few minutes.'**
  String get zwaveSmartStartDone;

  /// No description provided for @zwaveSmartStartInvalid.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a Z-Wave QR code.'**
  String get zwaveSmartStartInvalid;

  /// No description provided for @scanPointCameraZwave.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the Z-Wave QR code.'**
  String get scanPointCameraZwave;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @history24h.
  ///
  /// In en, this message translates to:
  /// **'24 h'**
  String get history24h;

  /// No description provided for @history7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get history7d;

  /// No description provided for @historyMin.
  ///
  /// In en, this message translates to:
  /// **'Min {value}'**
  String historyMin(String value);

  /// No description provided for @historyMax.
  ///
  /// In en, this message translates to:
  /// **'Max {value}'**
  String historyMax(String value);

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data for this period.'**
  String get historyEmpty;

  /// No description provided for @historyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'History isn\'t available. The recorder may be turned off in Home Assistant.'**
  String get historyUnavailable;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// No description provided for @activityByUser.
  ///
  /// In en, this message translates to:
  /// **'by a person'**
  String get activityByUser;

  /// No description provided for @activityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing happened in the last 24 hours.'**
  String get activityEmpty;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 notification from Home Assistant} other{{count} notifications from Home Assistant}}'**
  String notificationsCount(int count);

  /// No description provided for @notificationDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get notificationDismiss;

  /// No description provided for @notificationsDismissAll.
  ///
  /// In en, this message translates to:
  /// **'Dismiss all'**
  String get notificationsDismissAll;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications.'**
  String get notificationsEmpty;

  /// No description provided for @cameraSnapshots.
  ///
  /// In en, this message translates to:
  /// **'Snapshots'**
  String get cameraSnapshots;

  /// No description provided for @cameraLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get cameraLive;

  /// No description provided for @cameraLiveHint.
  ///
  /// In en, this message translates to:
  /// **'Live video from Home Assistant while this screen is open; sound is off. Nothing is recorded.'**
  String get cameraLiveHint;

  /// No description provided for @cameraLiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Live video isn\'t available for this camera (or the server\'s certificate isn\'t trusted by the video player). Snapshots still work.'**
  String get cameraLiveFailed;

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

  /// No description provided for @appLockNoDeviceAuth.
  ///
  /// In en, this message translates to:
  /// **'This device has no screen lock or biometrics set up.'**
  String get appLockNoDeviceAuth;

  /// No description provided for @homesTitle.
  ///
  /// In en, this message translates to:
  /// **'Homes'**
  String get homesTitle;

  /// No description provided for @addHome.
  ///
  /// In en, this message translates to:
  /// **'Add another home'**
  String get addHome;

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
  /// **'Hides sensitive devices and locks settings with a PIN on this device. Home Assistant permissions don\'t change; for real limits use a separate HA user.'**
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

  /// No description provided for @autoSave.
  ///
  /// In en, this message translates to:
  /// **'Save to Home Assistant'**
  String get autoSave;

  /// No description provided for @autoSaved.
  ///
  /// In en, this message translates to:
  /// **'Automation saved in Home Assistant.'**
  String get autoSaved;

  /// No description provided for @autoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The automation wasn\'t saved. This needs an administrator account in Home Assistant.'**
  String get autoSaveFailed;

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

  /// No description provided for @autoChangesTo.
  ///
  /// In en, this message translates to:
  /// **'changes to'**
  String get autoChangesTo;

  /// No description provided for @autoNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Hallway light at night'**
  String get autoNameHint;

  /// No description provided for @autoHint.
  ///
  /// In en, this message translates to:
  /// **'Saved as a normal Home Assistant automation, so it runs even when this phone is off. You can change it later in Home Assistant too.'**
  String get autoHint;

  /// No description provided for @svc_turn_on.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get svc_turn_on;

  /// No description provided for @svc_turn_off.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get svc_turn_off;

  /// No description provided for @svc_open_cover.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get svc_open_cover;

  /// No description provided for @svc_close_cover.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get svc_close_cover;

  /// No description provided for @svc_lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get svc_lock;

  /// No description provided for @svc_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get svc_start;

  /// No description provided for @svc_return_to_base.
  ///
  /// In en, this message translates to:
  /// **'Back to dock'**
  String get svc_return_to_base;

  /// No description provided for @svc_media_play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get svc_media_play;

  /// No description provided for @svc_media_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get svc_media_pause;

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

  /// No description provided for @sceneHint.
  ///
  /// In en, this message translates to:
  /// **'Saves how the chosen devices are right now (on/off, brightness, colour, blinds, temperature) as a Home Assistant scene.'**
  String get sceneHint;

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

  /// No description provided for @sceneSaved.
  ///
  /// In en, this message translates to:
  /// **'Scene saved in Home Assistant.'**
  String get sceneSaved;

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

  /// No description provided for @energyPrevDay.
  ///
  /// In en, this message translates to:
  /// **'Yesterday: {value}'**
  String energyPrevDay(String value);

  /// No description provided for @energyPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week: {value}'**
  String energyPrevWeek(String value);

  /// No description provided for @energyPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month: {value}'**
  String energyPrevMonth(String value);

  /// No description provided for @autoEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit automation'**
  String get autoEdit;

  /// No description provided for @autoTooComplex.
  ///
  /// In en, this message translates to:
  /// **'This automation does more than the app\'s editor can show. Change it in Home Assistant.'**
  String get autoTooComplex;

  /// No description provided for @backupSection.
  ///
  /// In en, this message translates to:
  /// **'Move to another device'**
  String get backupSection;

  /// No description provided for @backupHint.
  ///
  /// In en, this message translates to:
  /// **'Copies theme, language, favourites and kiosk layout as text, to paste in the app on another phone or tablet. Tokens, PINs and privacy choices are never included.'**
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
  /// **'Settings copied. Paste them in the app on the other device.'**
  String get backupCopied;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Settings applied.'**
  String get backupImported;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'The clipboard doesn\'t contain Open Smart Home settings.'**
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

  /// No description provided for @autoIs.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get autoIs;

  /// No description provided for @activityAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activityAll;

  /// No description provided for @activitySecurity.
  ///
  /// In en, this message translates to:
  /// **'Doors & security'**
  String get activitySecurity;

  /// No description provided for @activityPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get activityPeople;

  /// No description provided for @activityHint.
  ///
  /// In en, this message translates to:
  /// **'From Home Assistant\'s logbook for the last 24 hours. Sensors that measure continuously (temperature, power) aren\'t listed.'**
  String get activityHint;

  /// No description provided for @alertsSetting.
  ///
  /// In en, this message translates to:
  /// **'Notify about critical alerts'**
  String get alertsSetting;

  /// No description provided for @alertsSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Smoke, CO, water leak, a triggered alarm or a jammed lock as a phone notification, shown by this device. While the app runs — or always, with “Also when the app is closed” under Messages from Home Assistant.'**
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

  /// No description provided for @widgetSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Open Smart Home'**
  String get widgetSignedOut;

  /// No description provided for @riskVpnTunnel.
  ///
  /// In en, this message translates to:
  /// **'Tailscale VPN address: the connection is encrypted and also works away from home.'**
  String get riskVpnTunnel;

  /// No description provided for @remoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Address away from home'**
  String get remoteTitle;

  /// No description provided for @remoteNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set: only the home address is used'**
  String get remoteNotSet;

  /// No description provided for @remoteInUse.
  ///
  /// In en, this message translates to:
  /// **'In use now (the home address does not answer)'**
  String get remoteInUse;

  /// No description provided for @remoteHint.
  ///
  /// In en, this message translates to:
  /// **'The same Home Assistant as reached from outside: a Home Assistant Cloud (Nabu Casa) address, your own domain with HTTPS, or a Tailscale address. At home the app uses the home address; when it doesn\'t answer, it switches to this one. The same token is used.'**
  String get remoteHint;

  /// No description provided for @remoteSameAsLocal.
  ///
  /// In en, this message translates to:
  /// **'This is already the home address.'**
  String get remoteSameAsLocal;

  /// No description provided for @remoteNeedsHttps.
  ///
  /// In en, this message translates to:
  /// **'A public address needs HTTPS (or use Tailscale), otherwise the token would cross the internet unencrypted.'**
  String get remoteNeedsHttps;

  /// No description provided for @remoteRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remoteRemove;

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

  /// No description provided for @oauthHintNative.
  ///
  /// In en, this message translates to:
  /// **'Sign in on your Home Assistant\'s own login page with your user name and password. The app receives only a one-time code and keeps no password; no long-lived token is needed.'**
  String get oauthHintNative;

  /// No description provided for @oauthPageFailed.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant\'s login page did not load. Check the connection, or sign in with a token below. (A self-signed certificate works only with a token.)'**
  String get oauthPageFailed;

  /// No description provided for @haPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages from Home Assistant'**
  String get haPushTitle;

  /// No description provided for @haPushHint.
  ///
  /// In en, this message translates to:
  /// **'Let Home Assistant automations send notifications to this device'**
  String get haPushHint;

  /// No description provided for @haPushExplain.
  ///
  /// In en, this message translates to:
  /// **'This device is added to Home Assistant (Mobile App integration). Automations can then send it messages with a notify service. They arrive over the local connection while the app is running, without any cloud service.'**
  String get haPushExplain;

  /// No description provided for @haPushName.
  ///
  /// In en, this message translates to:
  /// **'Device name in Home Assistant'**
  String get haPushName;

  /// No description provided for @haPushDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Open Smart Home'**
  String get haPushDefaultName;

  /// No description provided for @haPushRegister.
  ///
  /// In en, this message translates to:
  /// **'Add to Home Assistant'**
  String get haPushRegister;

  /// No description provided for @haPushReady.
  ///
  /// In en, this message translates to:
  /// **'Automations send messages with {service}'**
  String haPushReady(String service);

  /// No description provided for @haPushCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy the service name'**
  String get haPushCopy;

  /// No description provided for @haPushCopied.
  ///
  /// In en, this message translates to:
  /// **'Service name copied.'**
  String get haPushCopied;

  /// No description provided for @haPushTest.
  ///
  /// In en, this message translates to:
  /// **'Send a test message'**
  String get haPushTest;

  /// No description provided for @haPushTestMessage.
  ///
  /// In en, this message translates to:
  /// **'Messages from Home Assistant arrive on this device.'**
  String get haPushTestMessage;

  /// No description provided for @haPushForget.
  ///
  /// In en, this message translates to:
  /// **'Stop messages'**
  String get haPushForget;

  /// No description provided for @haPushForgetHint.
  ///
  /// In en, this message translates to:
  /// **'The app stops listening for messages. To remove the device completely, delete it in Home Assistant: Settings → Devices & services → Mobile App.'**
  String get haPushForgetHint;

  /// No description provided for @haPushBackground.
  ///
  /// In en, this message translates to:
  /// **'Also when the app is closed'**
  String get haPushBackground;

  /// No description provided for @haPushBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps the connection open in the background, also after a restart. Android then shows a quiet, permanent notification; uses a little more battery.'**
  String get haPushBackgroundHint;

  /// No description provided for @haPushServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected to Home Assistant'**
  String get haPushServiceTitle;

  /// No description provided for @haPushServiceText.
  ///
  /// In en, this message translates to:
  /// **'Waiting for messages from your automations'**
  String get haPushServiceText;

  /// No description provided for @haPushRemovedInHa.
  ///
  /// In en, this message translates to:
  /// **'This device was removed in Home Assistant (Mobile App). Add it again to receive messages.'**
  String get haPushRemovedInHa;

  /// No description provided for @kioskPopup.
  ///
  /// In en, this message translates to:
  /// **'Camera pop-up'**
  String get kioskPopup;

  /// No description provided for @kioskPopupHint.
  ///
  /// In en, this message translates to:
  /// **'Show a camera when someone rings or moves at the door'**
  String get kioskPopupHint;

  /// No description provided for @kioskPopupSummary.
  ///
  /// In en, this message translates to:
  /// **'{camera} · {count, plural, =1{1 trigger} other{{count} triggers}}'**
  String kioskPopupSummary(String camera, int count);

  /// No description provided for @kioskPopupExplain.
  ///
  /// In en, this message translates to:
  /// **'When one of the chosen devices fires — a doorbell press, motion, a door or gate opening — the kiosk wakes up and shows the camera full screen.'**
  String get kioskPopupExplain;

  /// No description provided for @kioskPopupCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get kioskPopupCamera;

  /// No description provided for @kioskPopupOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get kioskPopupOff;

  /// No description provided for @kioskPopupDuration.
  ///
  /// In en, this message translates to:
  /// **'Show for'**
  String get kioskPopupDuration;

  /// No description provided for @kioskPopupTriggers.
  ///
  /// In en, this message translates to:
  /// **'Triggered by'**
  String get kioskPopupTriggers;

  /// No description provided for @kioskPopupClosesIn.
  ///
  /// In en, this message translates to:
  /// **'closes in {seconds} s'**
  String kioskPopupClosesIn(int seconds);

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

  /// No description provided for @dashCardNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications from Home Assistant'**
  String get dashCardNotifications;

  /// No description provided for @dashCardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Energy, calendar, activity'**
  String get dashCardShortcuts;

  /// No description provided for @dashCardAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention (batteries, unavailable)'**
  String get dashCardAttention;

  /// No description provided for @kioskPopupLive.
  ///
  /// In en, this message translates to:
  /// **'Live video'**
  String get kioskPopupLive;

  /// No description provided for @kioskPopupLiveHint.
  ///
  /// In en, this message translates to:
  /// **'When the camera offers a stream; until it starts, and otherwise, snapshots are shown.'**
  String get kioskPopupLiveHint;

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
  /// **'Home Assistant counts down, so it also works when this phone is off. It creates a small script for this device (visible in Home Assistant); this needs an administrator account.'**
  String get timerHint;

  /// No description provided for @timerRunning.
  ///
  /// In en, this message translates to:
  /// **'Timer is running'**
  String get timerRunning;

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

  /// No description provided for @timerNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Timers need an administrator account in Home Assistant.'**
  String get timerNeedsAdmin;

  /// No description provided for @energyShareOfHome.
  ///
  /// In en, this message translates to:
  /// **'{percent} % of the home'**
  String energyShareOfHome(int percent);

  /// No description provided for @matterNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Matter device'**
  String get matterNewTitle;

  /// No description provided for @matterNewHint.
  ///
  /// In en, this message translates to:
  /// **'Out of the box, with a QR code on it or its box. Google Play services sets it up over Bluetooth and puts it on your Wi-Fi or Thread network, then Home Assistant adds it. Keep the phone close to the device.'**
  String get matterNewHint;

  /// No description provided for @matterNewButton.
  ///
  /// In en, this message translates to:
  /// **'Add a new Matter device'**
  String get matterNewButton;

  /// No description provided for @matterNoPlayServices.
  ///
  /// In en, this message translates to:
  /// **'Adding new Matter devices on Android goes through Google Play services, which are not available here (for example an emulator, or a phone without Google services). Use Home Assistant\'s own app, or share the device from another Matter app below.'**
  String get matterNoPlayServices;

  /// No description provided for @matterNewFailed.
  ///
  /// In en, this message translates to:
  /// **'The device was not added. Reset it (see its manual) and try again close to the phone. Thread devices also need a Thread border router known to this phone.'**
  String get matterNewFailed;

  /// No description provided for @matterSharedTitle.
  ///
  /// In en, this message translates to:
  /// **'Device already in another app'**
  String get matterSharedTitle;

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

  /// No description provided for @settingsServerHint.
  ///
  /// In en, this message translates to:
  /// **'Address, away address, homes, sign out'**
  String get settingsServerHint;

  /// No description provided for @settingsKioskHint.
  ///
  /// In en, this message translates to:
  /// **'Wall tablet: layout, PIN, screensaver, camera'**
  String get settingsKioskHint;

  /// No description provided for @settingsNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Messages from Home Assistant, alerts'**
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
  /// **'Copy settings to another phone or tablet'**
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

  /// No description provided for @todoTitle.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get todoTitle;

  /// No description provided for @todoAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add an item…'**
  String get todoAddHint;

  /// No description provided for @todoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get todoAdd;

  /// No description provided for @todoDone.
  ///
  /// In en, this message translates to:
  /// **'Done ({count})'**
  String todoDone(int count);

  /// No description provided for @todoClearDone.
  ///
  /// In en, this message translates to:
  /// **'Clear done'**
  String get todoClearDone;

  /// No description provided for @todoEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items. Add the first one.'**
  String get todoEmpty;

  /// No description provided for @todoNoLists.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant has no lists. Add the “Shopping list” or “Local to-do” integration.'**
  String get todoNoLists;

  /// No description provided for @todoRename.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get todoRename;

  /// No description provided for @todoDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get todoDelete;

  /// No description provided for @todoReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This list is read-only here.'**
  String get todoReadOnly;

  /// No description provided for @todoDue.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String todoDue(String date);

  /// No description provided for @todoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The list is not available right now.'**
  String get todoUnavailable;

  /// No description provided for @dashCardLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get dashCardLists;

  /// No description provided for @energyTwoRate.
  ///
  /// In en, this message translates to:
  /// **'Two-rate meter'**
  String get energyTwoRate;

  /// No description provided for @energyTwoRateHint.
  ///
  /// In en, this message translates to:
  /// **'The lower (night) rate applies in the hours you set. They differ by area — check your bill or your distributor.'**
  String get energyTwoRateHint;

  /// No description provided for @energyLowPrice.
  ///
  /// In en, this message translates to:
  /// **'Low-rate price (per kWh)'**
  String get energyLowPrice;

  /// No description provided for @energyHighPrice.
  ///
  /// In en, this message translates to:
  /// **'High-rate price (per kWh)'**
  String get energyHighPrice;

  /// No description provided for @energyLowFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get energyLowFrom;

  /// No description provided for @energyLowTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get energyLowTo;

  /// No description provided for @energyLowPresetBelgrade.
  ///
  /// In en, this message translates to:
  /// **'Belgrade 00–08'**
  String get energyLowPresetBelgrade;

  /// No description provided for @energyLowPresetVojvodina.
  ///
  /// In en, this message translates to:
  /// **'Vojvodina 23–07'**
  String get energyLowPresetVojvodina;

  /// No description provided for @energyLowPresetCentral.
  ///
  /// In en, this message translates to:
  /// **'Central Serbia 22–06'**
  String get energyLowPresetCentral;

  /// No description provided for @energyHighRateKwh.
  ///
  /// In en, this message translates to:
  /// **'High rate'**
  String get energyHighRateKwh;

  /// No description provided for @energyLowRateKwh.
  ///
  /// In en, this message translates to:
  /// **'Low rate'**
  String get energyLowRateKwh;

  /// No description provided for @energyLowShare.
  ///
  /// In en, this message translates to:
  /// **'{percent} % of use'**
  String energyLowShare(int percent);

  /// No description provided for @energyLowNow.
  ///
  /// In en, this message translates to:
  /// **'Low rate now, until {time}'**
  String energyLowNow(String time);

  /// No description provided for @energyHighNow.
  ///
  /// In en, this message translates to:
  /// **'High rate now — low rate starts at {time}'**
  String energyHighNow(String time);

  /// No description provided for @energyLowLegend.
  ///
  /// In en, this message translates to:
  /// **'Low-rate hours'**
  String get energyLowLegend;

  /// No description provided for @boardTitle.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get boardTitle;

  /// No description provided for @boardNewPage.
  ///
  /// In en, this message translates to:
  /// **'New page'**
  String get boardNewPage;

  /// No description provided for @boardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pages yet. Make the first one and write or draw with a finger or a pen.'**
  String get boardEmpty;

  /// No description provided for @boardStorageNote.
  ///
  /// In en, this message translates to:
  /// **'Pages are saved on your Home Assistant as pictures (image_upload), so all your devices see them. Home Assistant shows such pictures without signing in to anyone on the network who knows their long random link.'**
  String get boardStorageNote;

  /// No description provided for @boardPen.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get boardPen;

  /// No description provided for @boardEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get boardEraser;

  /// No description provided for @boardUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get boardUndo;

  /// No description provided for @boardRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get boardRedo;

  /// No description provided for @boardClear.
  ///
  /// In en, this message translates to:
  /// **'Clear page'**
  String get boardClear;

  /// No description provided for @boardClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear everything on this page?'**
  String get boardClearConfirm;

  /// No description provided for @boardDeletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get boardDeletePage;

  /// No description provided for @boardDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this page from Home Assistant?'**
  String get boardDeleteConfirm;

  /// No description provided for @boardDeleteNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Deleting pictures in Home Assistant needs an administrator account.'**
  String get boardDeleteNeedsAdmin;

  /// No description provided for @boardSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get boardSaving;

  /// No description provided for @boardSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get boardSaved;

  /// No description provided for @boardSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Not saved — will try again.'**
  String get boardSaveFailed;

  /// No description provided for @boardChangedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This page was changed on another device.'**
  String get boardChangedElsewhere;

  /// No description provided for @boardReload.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get boardReload;

  /// No description provided for @boardColor.
  ///
  /// In en, this message translates to:
  /// **'Colour {n}'**
  String boardColor(int n);

  /// No description provided for @boardWidth.
  ///
  /// In en, this message translates to:
  /// **'Width {n}'**
  String boardWidth(int n);

  /// No description provided for @boardZoomHint.
  ///
  /// In en, this message translates to:
  /// **'Two fingers: zoom and move'**
  String get boardZoomHint;

  /// No description provided for @boardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The board is not available. Check the connection to Home Assistant.'**
  String get boardUnavailable;

  /// No description provided for @boardPageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty — write or draw something} one{{count} page} other{{count} pages}}'**
  String boardPageCount(int count);

  /// No description provided for @deviceSensorBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get deviceSensorBattery;

  /// No description provided for @deviceSensorBatteryState.
  ///
  /// In en, this message translates to:
  /// **'Battery state'**
  String get deviceSensorBatteryState;

  /// No description provided for @deviceSensorCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get deviceSensorCharging;

  /// No description provided for @deviceSensorKiosk.
  ///
  /// In en, this message translates to:
  /// **'Kiosk'**
  String get deviceSensorKiosk;

  /// No description provided for @deviceSensorsSwitch.
  ///
  /// In en, this message translates to:
  /// **'Send battery state to Home Assistant'**
  String get deviceSensorsSwitch;

  /// No description provided for @deviceSensorsHint.
  ///
  /// In en, this message translates to:
  /// **'Battery level, charging and whether the kiosk is on become sensors of this device in your HA. Nothing else is sent.'**
  String get deviceSensorsHint;

  /// No description provided for @smartChargeTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart charging'**
  String get smartChargeTitle;

  /// No description provided for @smartChargeHint.
  ///
  /// In en, this message translates to:
  /// **'The charger\'s plug turns on at {low} % and off at {high} % — the wall tablet\'s battery lasts longer.'**
  String smartChargeHint(int low, int high);

  /// No description provided for @smartChargeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the battery sensor to appear in Home Assistant…'**
  String get smartChargeWaiting;

  /// No description provided for @smartChargePlug.
  ///
  /// In en, this message translates to:
  /// **'Charger plug or switch'**
  String get smartChargePlug;

  /// No description provided for @smartChargeCreate.
  ///
  /// In en, this message translates to:
  /// **'Create automation'**
  String get smartChargeCreate;

  /// No description provided for @smartChargeDone.
  ///
  /// In en, this message translates to:
  /// **'Automation “{name}” created in Home Assistant.'**
  String smartChargeDone(String name);

  /// No description provided for @smartChargeNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Creating automations needs an administrator account.'**
  String get smartChargeNeedsAdmin;

  /// No description provided for @smartChargeAlias.
  ///
  /// In en, this message translates to:
  /// **'Smart charging – {device}'**
  String smartChargeAlias(String device);

  /// No description provided for @nfcTitle.
  ///
  /// In en, this message translates to:
  /// **'NFC tags'**
  String get nfcTitle;

  /// No description provided for @nfcHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the phone to a tag and Home Assistant runs what you chose — e.g. a “Leaving” scene by the front door. Tags use the same format as the official HA app.'**
  String get nfcHint;

  /// No description provided for @nfcSectionHint.
  ///
  /// In en, this message translates to:
  /// **'A scene with a tap of the phone'**
  String get nfcSectionHint;

  /// No description provided for @nfcOff.
  ///
  /// In en, this message translates to:
  /// **'NFC is turned off in the phone\'s settings.'**
  String get nfcOff;

  /// No description provided for @nfcMissing.
  ///
  /// In en, this message translates to:
  /// **'This device has no NFC. Existing tags still work from other phones.'**
  String get nfcMissing;

  /// No description provided for @nfcNeedsRegistration.
  ///
  /// In en, this message translates to:
  /// **'To scan, add this device to Home Assistant (Notifications → Messages from Home Assistant).'**
  String get nfcNeedsRegistration;

  /// No description provided for @nfcNew.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get nfcNew;

  /// No description provided for @nfcName.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get nfcName;

  /// No description provided for @nfcRuns.
  ///
  /// In en, this message translates to:
  /// **'When scanned, run'**
  String get nfcRuns;

  /// No description provided for @nfcWrite.
  ///
  /// In en, this message translates to:
  /// **'Write tag'**
  String get nfcWrite;

  /// No description provided for @nfcHold.
  ///
  /// In en, this message translates to:
  /// **'Hold the tag to the back of the phone…'**
  String get nfcHold;

  /// No description provided for @nfcWritten.
  ///
  /// In en, this message translates to:
  /// **'Tag “{name}” is ready.'**
  String nfcWritten(String name);

  /// No description provided for @nfcWrittenNoAdmin.
  ///
  /// In en, this message translates to:
  /// **'The tag is written, but adding it to Home Assistant (and the automation) needs an administrator account. Scans still reach HA.'**
  String get nfcWrittenNoAdmin;

  /// No description provided for @nfcErrorReadOnly.
  ///
  /// In en, this message translates to:
  /// **'The tag is locked and cannot be written.'**
  String get nfcErrorReadOnly;

  /// No description provided for @nfcErrorTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The address does not fit on this tag.'**
  String get nfcErrorTooSmall;

  /// No description provided for @nfcErrorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This kind of tag is not supported.'**
  String get nfcErrorUnsupported;

  /// No description provided for @nfcErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Writing failed — hold the tag still against the phone and try again.'**
  String get nfcErrorFailed;

  /// No description provided for @nfcScanned.
  ///
  /// In en, this message translates to:
  /// **'Tag “{name}” scanned'**
  String nfcScanned(String name);

  /// No description provided for @nfcScanFailed.
  ///
  /// In en, this message translates to:
  /// **'The tag did not reach Home Assistant: {reason}'**
  String nfcScanFailed(String reason);

  /// No description provided for @nfcEmpty.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant has no tags yet.'**
  String get nfcEmpty;

  /// No description provided for @nfcLastScanned.
  ///
  /// In en, this message translates to:
  /// **'Last: {when}'**
  String nfcLastScanned(String when);

  /// No description provided for @nfcNeverScanned.
  ///
  /// In en, this message translates to:
  /// **'Not scanned yet'**
  String get nfcNeverScanned;

  /// No description provided for @nfcScannedUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Tag scanned'**
  String get nfcScannedUnnamed;

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

  /// No description provided for @aodFocusNextEvent.
  ///
  /// In en, this message translates to:
  /// **'Next event'**
  String get aodFocusNextEvent;

  /// No description provided for @aodFocusList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get aodFocusList;

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

  /// No description provided for @aodNextEvent.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get aodNextEvent;

  /// No description provided for @aodNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events in the next 7 days'**
  String get aodNoEvents;

  /// No description provided for @aodToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get aodToday;

  /// No description provided for @aodTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get aodTomorrow;

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

  /// No description provided for @morningToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get morningToday;

  /// No description provided for @morningReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get morningReminders;

  /// No description provided for @morningNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing on today.'**
  String get morningNothing;

  /// No description provided for @morningHighLow.
  ///
  /// In en, this message translates to:
  /// **'high {high}, low {low}'**
  String morningHighLow(String high, String low);

  /// No description provided for @aodNowUntil.
  ///
  /// In en, this message translates to:
  /// **'now, until {time}'**
  String aodNowUntil(String time);

  /// No description provided for @aodBrightness.
  ///
  /// In en, this message translates to:
  /// **'Always-on brightness'**
  String get aodBrightness;

  /// No description provided for @settingsAssistSection.
  ///
  /// In en, this message translates to:
  /// **'Assist (voice)'**
  String get settingsAssistSection;

  /// No description provided for @settingsAssistHint.
  ///
  /// In en, this message translates to:
  /// **'Spoken answers, phone assistant'**
  String get settingsAssistHint;

  /// No description provided for @assistSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak answers'**
  String get assistSpeak;

  /// No description provided for @assistSpeakHint.
  ///
  /// In en, this message translates to:
  /// **'When you ask by voice, the answer is spoken too (the device\'s text-to-speech, nothing is sent).'**
  String get assistSpeakHint;

  /// No description provided for @assistDefault.
  ///
  /// In en, this message translates to:
  /// **'Phone assistant'**
  String get assistDefault;

  /// No description provided for @assistDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Choose Open Smart Home as the “digital assistant”: a long press of home or power opens Assist, listening.'**
  String get assistDefaultHint;

  /// No description provided for @wakeWordSetting.
  ///
  /// In en, this message translates to:
  /// **'Wake word (hands-free)'**
  String get wakeWordSetting;

  /// No description provided for @wakeWordSettingHint.
  ///
  /// In en, this message translates to:
  /// **'Say the wake word set up in Home Assistant (for example “Okay Nabu”), then the command. Only while the kiosk is shown.'**
  String get wakeWordSettingHint;

  /// No description provided for @wakeWordPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen for the wake word?'**
  String get wakeWordPrivacyTitle;

  /// No description provided for @wakeWordPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'While the kiosk is on screen the microphone stays on (Android shows its microphone indicator) and the sound is streamed continuously to your Home Assistant server, over the same connection as everything else, so that its wake word engine (openWakeWord) can recognise the wake word. Nothing is recorded or stored on this tablet. What Home Assistant does with the command after the wake word depends on its Assist settings: local recognition (for example Whisper) stays at home, Home Assistant Cloud sends it to the internet.'**
  String get wakeWordPrivacyBody;

  /// No description provided for @wakeWordAllow.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get wakeWordAllow;

  /// No description provided for @wakeWordActive.
  ///
  /// In en, this message translates to:
  /// **'Listening for the wake word'**
  String get wakeWordActive;

  /// No description provided for @wakeWordMissing.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant has no wake word engine. Install the openWakeWord add-on (the Wyoming integration finds it), then turn this on again.'**
  String get wakeWordMissing;

  /// No description provided for @wakeWordNeedsServer.
  ///
  /// In en, this message translates to:
  /// **'Needs a connection to Home Assistant.'**
  String get wakeWordNeedsServer;

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
  /// **'Motion sensor (Home Assistant)'**
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
  /// **'Home Assistant has no motion or presence sensors.'**
  String get approachNoSensors;

  /// No description provided for @approachCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Use the tablet\'s camera?'**
  String get approachCameraTitle;

  /// No description provided for @approachCameraBody.
  ///
  /// In en, this message translates to:
  /// **'While the screen is idle, the front camera checks a few times a second whether something moves in front of the tablet, and Android shows its camera indicator. Pictures are processed only on this tablet and dropped at once: nothing is recorded, stored or sent anywhere — not even to Home Assistant. While the screen is awake the camera is off.'**
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
  /// **'While nobody is home, Home Assistant switches one of the chosen lights on or off every 15 minutes in the evening (with a random wait of up to 10 minutes), and turns them all off at the end time. It runs in Home Assistant, so it works even when this device is off. Saving needs an administrator account.'**
  String get presenceIntro;

  /// No description provided for @presenceOn.
  ///
  /// In en, this message translates to:
  /// **'Simulation on'**
  String get presenceOn;

  /// No description provided for @presenceNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved in Home Assistant yet.'**
  String get presenceNotSaved;

  /// No description provided for @presenceLights.
  ///
  /// In en, this message translates to:
  /// **'Lights'**
  String get presenceLights;

  /// No description provided for @presenceNoLights.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant has no lights.'**
  String get presenceNoLights;

  /// No description provided for @presenceWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get presenceWhen;

  /// No description provided for @presenceWhenAway.
  ///
  /// In en, this message translates to:
  /// **'When nobody is home'**
  String get presenceWhenAway;

  /// No description provided for @presenceWhenAwayHint.
  ///
  /// In en, this message translates to:
  /// **'By the people in Home Assistant (the Home zone).'**
  String get presenceWhenAwayHint;

  /// No description provided for @presenceWhenAlarm.
  ///
  /// In en, this message translates to:
  /// **'When the alarm is armed away'**
  String get presenceWhenAlarm;

  /// No description provided for @presenceWhenAlways.
  ///
  /// In en, this message translates to:
  /// **'Always while it is on'**
  String get presenceWhenAlways;

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
  /// **'Save to Home Assistant'**
  String get presenceSave;

  /// No description provided for @presenceSaved.
  ///
  /// In en, this message translates to:
  /// **'Presence simulation saved in Home Assistant.'**
  String get presenceSaved;

  /// No description provided for @presenceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get presenceRemove;

  /// No description provided for @presenceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Presence simulation removed.'**
  String get presenceRemoved;

  /// No description provided for @presenceNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'This needs an administrator account in Home Assistant.'**
  String get presenceNeedsAdmin;

  /// No description provided for @lowTariffAlias.
  ///
  /// In en, this message translates to:
  /// **'Lower rate reminder ({device})'**
  String lowTariffAlias(String device);

  /// No description provided for @lowTariffTitle.
  ///
  /// In en, this message translates to:
  /// **'The lower rate has started'**
  String get lowTariffTitle;

  /// No description provided for @lowTariffMessage.
  ///
  /// In en, this message translates to:
  /// **'Electricity is cheaper until {until} ({price}/kWh): a good time for the washing machine, the dishwasher or charging.'**
  String lowTariffMessage(String until, String price);

  /// No description provided for @lowTariffRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind me when the lower rate starts'**
  String get lowTariffRemind;

  /// No description provided for @lowTariffRemindOn.
  ///
  /// In en, this message translates to:
  /// **'Lower rate reminder is on'**
  String get lowTariffRemindOn;

  /// No description provided for @lowTariffDialogBody.
  ///
  /// In en, this message translates to:
  /// **'When the lower rate starts ({time}), Home Assistant sends a message to this phone; when it ends, the message goes away by itself. It runs as an automation in Home Assistant (saving needs an administrator account), and the message arrives while the app is connected, as all messages from Home Assistant.'**
  String lowTariffDialogBody(String time);

  /// No description provided for @lowTariffCreate.
  ///
  /// In en, this message translates to:
  /// **'Turn on reminder'**
  String get lowTariffCreate;

  /// No description provided for @lowTariffRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove reminder'**
  String get lowTariffRemove;

  /// No description provided for @lowTariffCreated.
  ///
  /// In en, this message translates to:
  /// **'Lower rate reminder is on.'**
  String get lowTariffCreated;

  /// No description provided for @lowTariffRemoved.
  ///
  /// In en, this message translates to:
  /// **'Lower rate reminder removed.'**
  String get lowTariffRemoved;

  /// No description provided for @lowTariffNeedsPush.
  ///
  /// In en, this message translates to:
  /// **'First turn on “Messages from Home Assistant” (Settings › Notifications).'**
  String get lowTariffNeedsPush;

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

  /// No description provided for @timerStarted.
  ///
  /// In en, this message translates to:
  /// **'Timer for {label} started.'**
  String timerStarted(String label);

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

  /// No description provided for @familyMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get familyMessages;

  /// No description provided for @familyMessagesNone.
  ///
  /// In en, this message translates to:
  /// **'No messages. Leave one for the household.'**
  String get familyMessagesNone;

  /// No description provided for @familyMessageNew.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get familyMessageNew;

  /// No description provided for @familyMessageEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get familyMessageEveryone;

  /// No description provided for @familyMessageFor.
  ///
  /// In en, this message translates to:
  /// **'Message for {name}'**
  String familyMessageFor(String name);

  /// No description provided for @familyMessageForAll.
  ///
  /// In en, this message translates to:
  /// **'Message for everyone'**
  String get familyMessageForAll;

  /// No description provided for @familyMessageRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get familyMessageRead;

  /// No description provided for @familyMessageHint.
  ///
  /// In en, this message translates to:
  /// **'For example: there is soup in the fridge'**
  String get familyMessageHint;

  /// No description provided for @familyMessageSend.
  ///
  /// In en, this message translates to:
  /// **'Leave message'**
  String get familyMessageSend;

  /// No description provided for @welcomeHome.
  ///
  /// In en, this message translates to:
  /// **'Welcome home, {name}!'**
  String welcomeHome(String name);

  /// No description provided for @greetPeople.
  ///
  /// In en, this message translates to:
  /// **'Greet people coming home'**
  String get greetPeople;

  /// No description provided for @greetPeopleHint.
  ///
  /// In en, this message translates to:
  /// **'When someone arrives (by their person in Home Assistant), the tablet says hello and shows their messages.'**
  String get greetPeopleHint;

  /// No description provided for @kioskIntercom.
  ///
  /// In en, this message translates to:
  /// **'Intercom'**
  String get kioskIntercom;

  /// No description provided for @kioskIntercomOpen.
  ///
  /// In en, this message translates to:
  /// **'“Open” button'**
  String get kioskIntercomOpen;

  /// No description provided for @kioskIntercomSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker by the door (“Coming” button)'**
  String get kioskIntercomSpeaker;

  /// No description provided for @kioskIntercomSpeakerHint.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant says the reply there with its own text-to-speech.'**
  String get kioskIntercomSpeakerHint;

  /// No description provided for @kioskIntercomReply.
  ///
  /// In en, this message translates to:
  /// **'Coming!'**
  String get kioskIntercomReply;

  /// No description provided for @kioskIntercomReplyText.
  ///
  /// In en, this message translates to:
  /// **'Coming, just a moment!'**
  String get kioskIntercomReplyText;

  /// No description provided for @kioskIntercomReplied.
  ///
  /// In en, this message translates to:
  /// **'Said at the door: “Coming, just a moment!”'**
  String get kioskIntercomReplied;

  /// No description provided for @kioskIntercomNoTts.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant has no text-to-speech set up.'**
  String get kioskIntercomNoTts;

  /// No description provided for @kioskIntercomUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock {name}'**
  String kioskIntercomUnlock(String name);

  /// No description provided for @kioskIntercomOpenDevice.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String kioskIntercomOpenDevice(String name);

  /// No description provided for @kioskColumnsNoRooms.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet. Add areas in Home Assistant.'**
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
  /// **'Home Assistant watches the power: once the appliance has run (above the threshold) and then goes quiet, it tells you it\'s done. Works with the app closed; everything stays on your network.'**
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

  /// No description provided for @applianceDoneThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Message to this phone'**
  String get applianceDoneThisPhone;

  /// No description provided for @applianceDoneNeedsPush.
  ///
  /// In en, this message translates to:
  /// **'Turn on messages from Home Assistant in settings first.'**
  String get applianceDoneNeedsPush;

  /// No description provided for @applianceDoneHousehold.
  ///
  /// In en, this message translates to:
  /// **'Message to the whole household'**
  String get applianceDoneHousehold;

  /// No description provided for @applianceDoneHouseholdHint.
  ///
  /// In en, this message translates to:
  /// **'Everyone sees it in the app and on the wall tablet.'**
  String get applianceDoneHouseholdHint;

  /// No description provided for @applianceDoneOtherPhones.
  ///
  /// In en, this message translates to:
  /// **'Also tells {count} other phone(s).'**
  String applianceDoneOtherPhones(int count);

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

  /// No description provided for @applianceDoneNeedsAdmin.
  ///
  /// In en, this message translates to:
  /// **'This needs an administrator account in Home Assistant.'**
  String get applianceDoneNeedsAdmin;

  /// No description provided for @applianceDoneOn.
  ///
  /// In en, this message translates to:
  /// **'Tells you when it\'s done'**
  String get applianceDoneOn;

  /// No description provided for @applianceDoneOnHint.
  ///
  /// In en, this message translates to:
  /// **'Automation in Home Assistant'**
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

  /// No description provided for @applianceDoneAlias.
  ///
  /// In en, this message translates to:
  /// **'Done: {name} (Open Smart Home)'**
  String applianceDoneAlias(String name);

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
  /// **'From each time on, that temperature holds until the next one. Home Assistant keeps and runs the schedule, also with the app closed. A manual change holds until the next time.'**
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
  /// **'Schedule saved in Home Assistant.'**
  String get heatingScheduleSaved;

  /// No description provided for @heatingScheduleNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {time} → {temperature}'**
  String heatingScheduleNext(String time, String temperature);

  /// No description provided for @heatingScheduleAlias.
  ///
  /// In en, this message translates to:
  /// **'Schedule: {name} (Open Smart Home)'**
  String heatingScheduleAlias(String name);

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
  /// **'Photo, icon and colour stay on this device only; they are not sent to Home Assistant. For the wall tablet, choose them on the tablet itself.'**
  String get roomPhotoHint;

  /// No description provided for @themeAutoDark.
  ///
  /// In en, this message translates to:
  /// **'Dark after sunset'**
  String get themeAutoDark;

  /// No description provided for @themeAutoDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Follows sunrise and sunset from Home Assistant (without it: dark from 20:00 to 7:00).'**
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
  /// **'As in Home Assistant'**
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

  /// No description provided for @bigSliderHint.
  ///
  /// In en, this message translates to:
  /// **'Long press: big slider'**
  String get bigSliderHint;

  /// No description provided for @deviceSheetMore.
  ///
  /// In en, this message translates to:
  /// **'All details'**
  String get deviceSheetMore;

  /// No description provided for @serviceSection.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceSection;

  /// No description provided for @serviceSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics, support and installer tools'**
  String get serviceSectionHint;

  /// No description provided for @serviceSupport.
  ///
  /// In en, this message translates to:
  /// **'Support: {brand}'**
  String serviceSupport(String brand);

  /// No description provided for @serviceApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get serviceApp;

  /// No description provided for @serviceDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get serviceDevice;

  /// No description provided for @serviceServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serviceServer;

  /// No description provided for @serviceConnected.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get serviceConnected;

  /// No description provided for @serviceDisconnected.
  ///
  /// In en, this message translates to:
  /// **'not connected'**
  String get serviceDisconnected;

  /// No description provided for @serviceDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get serviceDevices;

  /// No description provided for @serviceDevicesValue.
  ///
  /// In en, this message translates to:
  /// **'{count} devices, unavailable: {unavailable}'**
  String serviceDevicesValue(int count, int unavailable);

  /// No description provided for @servicePanel.
  ///
  /// In en, this message translates to:
  /// **'Wall panel'**
  String get servicePanel;

  /// No description provided for @servicePanelManaged.
  ///
  /// In en, this message translates to:
  /// **'Managed (device owner): the kiosk cannot be left and starts after a restart'**
  String get servicePanelManaged;

  /// No description provided for @servicePanelNot.
  ///
  /// In en, this message translates to:
  /// **'Ordinary device (not installer-managed)'**
  String get servicePanelNot;

  /// No description provided for @servicePanelApply.
  ///
  /// In en, this message translates to:
  /// **'Apply panel rules'**
  String get servicePanelApply;

  /// No description provided for @servicePanelApplied.
  ///
  /// In en, this message translates to:
  /// **'Screen stays on while powered; the app is the home screen.'**
  String get servicePanelApplied;

  /// No description provided for @servicePanelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: the app is not the device owner.'**
  String get servicePanelFailed;

  /// No description provided for @servicePanelRelease.
  ///
  /// In en, this message translates to:
  /// **'Release the device'**
  String get servicePanelRelease;

  /// No description provided for @servicePanelReleaseBody.
  ///
  /// In en, this message translates to:
  /// **'Removes installer management: the kiosk can be left and the normal home screen returns. Turning it back on needs the device prepared again (factory reset).'**
  String get servicePanelReleaseBody;

  /// No description provided for @serviceProblems.
  ///
  /// In en, this message translates to:
  /// **'Recent problems'**
  String get serviceProblems;

  /// No description provided for @serviceNoProblems.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged since the app started.'**
  String get serviceNoProblems;

  /// No description provided for @serviceCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get serviceCopy;

  /// No description provided for @serviceCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied.'**
  String get serviceCopied;

  /// No description provided for @serviceCopyHint.
  ///
  /// In en, this message translates to:
  /// **'No tokens or passwords: only versions, the device, the server\'s host and recent errors.'**
  String get serviceCopyHint;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup wizard'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'Check and set up everything for this device, step by step. ({brand})'**
  String setupIntro(String brand);

  /// No description provided for @setupConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection to Home Assistant'**
  String get setupConnection;

  /// No description provided for @setupConnectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connected to {host} (Home Assistant {version})'**
  String setupConnectionOk(String host, String version);

  /// No description provided for @setupConnectionMissing.
  ///
  /// In en, this message translates to:
  /// **'Not connected — check the address and network in Settings → Server.'**
  String get setupConnectionMissing;

  /// No description provided for @setupRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get setupRooms;

  /// No description provided for @setupRoomsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No rooms} =1{1 room} other{{count} rooms}}'**
  String setupRoomsCount(int count);

  /// No description provided for @setupNoRoom.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Every device has a room} =1{1 device without a room} other{{count} devices without a room}}'**
  String setupNoRoom(int count);

  /// No description provided for @setupRoomsHint.
  ///
  /// In en, this message translates to:
  /// **'Rooms and devices are arranged in Home Assistant (Settings → Areas).'**
  String get setupRoomsHint;

  /// No description provided for @setupMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages from Home Assistant'**
  String get setupMessages;

  /// No description provided for @setupMessagesOk.
  ///
  /// In en, this message translates to:
  /// **'Registered as \"{name}\"'**
  String setupMessagesOk(String name);

  /// No description provided for @setupMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Registers the device in Home Assistant (Mobile App), so automations can send it messages.'**
  String get setupMessagesHint;

  /// No description provided for @setupDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name in Home Assistant'**
  String get setupDeviceName;

  /// No description provided for @setupDefaultDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Wall tablet'**
  String get setupDefaultDeviceName;

  /// No description provided for @setupRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get setupRegister;

  /// No description provided for @setupKiosk.
  ///
  /// In en, this message translates to:
  /// **'Kiosk and PIN'**
  String get setupKiosk;

  /// No description provided for @setupPinHint.
  ///
  /// In en, this message translates to:
  /// **'No PIN to leave the kiosk yet'**
  String get setupPinHint;

  /// No description provided for @setupPinSaved.
  ///
  /// In en, this message translates to:
  /// **'PIN saved.'**
  String get setupPinSaved;

  /// No description provided for @setupPanel.
  ///
  /// In en, this message translates to:
  /// **'Wall panel'**
  String get setupPanel;

  /// No description provided for @setupPanelHint.
  ///
  /// In en, this message translates to:
  /// **'For a panel that cannot be left and starts by itself after a power cut, the device is prepared as \"device owner\" before any Google account is added — see the installer guide (docs/INSTALLER.md).'**
  String get setupPanelHint;

  /// No description provided for @setupDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get setupDone;

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

  /// No description provided for @haBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'In Home Assistant'**
  String get haBackupTitle;

  /// No description provided for @haBackupHint.
  ///
  /// In en, this message translates to:
  /// **'The app\'s settings (look, kiosk, cards, quick controls, rooms) are kept in your Home Assistant under the device\'s name, so after a reinstall or on another tablet they come back with one tap. Tokens, PIN, photos and microphone/camera choices are never kept.'**
  String get haBackupHint;

  /// No description provided for @haBackupName.
  ///
  /// In en, this message translates to:
  /// **'Copy name (device)'**
  String get haBackupName;

  /// No description provided for @haBackupSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get haBackupSave;

  /// No description provided for @haBackupSavedHome.
  ///
  /// In en, this message translates to:
  /// **'Saved as \"{name}\" — visible on every device in the home.'**
  String haBackupSavedHome(String name);

  /// No description provided for @haBackupSavedUser.
  ///
  /// In en, this message translates to:
  /// **'Saved as \"{name}\" for your account (the whole home needs an administrator).'**
  String haBackupSavedUser(String name);

  /// No description provided for @haBackupNone.
  ///
  /// In en, this message translates to:
  /// **'No saved copies yet.'**
  String get haBackupNone;

  /// No description provided for @haBackupScopeHome.
  ///
  /// In en, this message translates to:
  /// **'for the whole home'**
  String get haBackupScopeHome;

  /// No description provided for @haBackupScopeUser.
  ///
  /// In en, this message translates to:
  /// **'your account only'**
  String get haBackupScopeUser;

  /// No description provided for @haBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get haBackupRestore;

  /// No description provided for @haBackupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore \"{name}\"?'**
  String haBackupRestoreTitle(String name);

  /// No description provided for @haBackupRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'This device\'s settings will be replaced by the saved ones. PIN, photos and microphone/camera choices stay as they are.'**
  String get haBackupRestoreBody;

  /// No description provided for @haBackupDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete copy'**
  String get haBackupDelete;

  /// No description provided for @haBackupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Copies in Home Assistant aren\'t available right now (no connection).'**
  String get haBackupUnavailable;

  /// No description provided for @backupFileTitle.
  ///
  /// In en, this message translates to:
  /// **'As text (manually)'**
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

  /// No description provided for @nfcLinkConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Run this tag?'**
  String get nfcLinkConfirmTitle;

  /// No description provided for @nfcLinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'The link for tag \"{name}\" didn\'t come from an NFC tag held to the phone, but from a QR code, the web or another app. Run it in Home Assistant?'**
  String nfcLinkConfirm(String name);

  /// No description provided for @nfcLinkConfirmUnnamed.
  ///
  /// In en, this message translates to:
  /// **'A Home Assistant tag link didn\'t come from an NFC tag held to the phone, but from a QR code, the web or another app. Run it?'**
  String get nfcLinkConfirmUnnamed;

  /// No description provided for @nfcLinkRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get nfcLinkRun;

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

  /// No description provided for @firstRunWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'You are connected to {host}. Let\'s set the app up — it takes a minute, and everything can be changed later in Settings.'**
  String firstRunWelcomeBody(String host);

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

  /// No description provided for @firstRunRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring over existing settings'**
  String get firstRunRestoreTitle;

  /// No description provided for @firstRunRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Your Home Assistant keeps settings saved from other devices. If this one replaces or matches one of them, restore it with a tap — or just continue.'**
  String get firstRunRestoreBody;

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
  /// **'Home Assistant has no controllable devices yet.'**
  String get firstRunFavoritesNone;

  /// No description provided for @firstRunFavoritesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing selected} =1{1 device selected} other{{count} devices selected}}'**
  String firstRunFavoritesCount(int count);

  /// No description provided for @firstRunMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages on this phone'**
  String get firstRunMessagesTitle;

  /// No description provided for @firstRunMessagesBody.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant can tell this phone when something happens, e.g. a door left open. Messages come straight from your home, without a cloud.'**
  String get firstRunMessagesBody;

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
  /// **'Rooms, scenes and devices come from Home Assistant. Everything chosen here can be changed in Settings, and Home\'s cards with the ⚙ button next to the greeting.'**
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
  /// **'On the panel, a member taps their picture and gets their own greeting and quick controls. Unlocking doors, disarming the alarm and similar actions need the member\'s own PIN or the panel\'s PIN — members without a PIN (e.g. children) cannot. Members are Home Assistant\'s people.'**
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
  /// **'Home Assistant leaves the household a message (and tells this phone, if registered) when a battery drops to {percent} % or below.'**
  String batteryReminderHint(int percent);

  /// No description provided for @batteryReminderAlias.
  ///
  /// In en, this message translates to:
  /// **'Battery running low (Open Smart Home)'**
  String get batteryReminderAlias;

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

  /// No description provided for @unlockLogPanel.
  ///
  /// In en, this message translates to:
  /// **'Wall panel'**
  String get unlockLogPanel;

  /// No description provided for @unlockLogPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get unlockLogPhone;

  /// No description provided for @unlockLogViaPanel.
  ///
  /// In en, this message translates to:
  /// **'wall panel'**
  String get unlockLogViaPanel;

  /// No description provided for @unlockLogViaPhone.
  ///
  /// In en, this message translates to:
  /// **'phone'**
  String get unlockLogViaPhone;

  /// No description provided for @unlockLogUnlock.
  ///
  /// In en, this message translates to:
  /// **'unlocks {device} ({via})'**
  String unlockLogUnlock(String device, String via);

  /// No description provided for @unlockLogDisarm.
  ///
  /// In en, this message translates to:
  /// **'disarms {device} ({via})'**
  String unlockLogDisarm(String device, String via);

  /// No description provided for @unlockLogOpen.
  ///
  /// In en, this message translates to:
  /// **'opens {device} ({via})'**
  String unlockLogOpen(String device, String via);

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

  /// No description provided for @comingHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming home'**
  String get comingHomeTitle;

  /// No description provided for @comingHomeHint.
  ///
  /// In en, this message translates to:
  /// **'One tap (also from the app icon): turn on what you like, warm the house and tell the household.'**
  String get comingHomeHint;

  /// No description provided for @comingHomeWho.
  ///
  /// In en, this message translates to:
  /// **'Who is coming'**
  String get comingHomeWho;

  /// No description provided for @comingHomeNoOne.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get comingHomeNoOne;

  /// No description provided for @comingHomeRoutine.
  ///
  /// In en, this message translates to:
  /// **'Scene or script'**
  String get comingHomeRoutine;

  /// No description provided for @comingHomeNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get comingHomeNone;

  /// No description provided for @comingHomeHeatingOff.
  ///
  /// In en, this message translates to:
  /// **'Heating: leave as is'**
  String get comingHomeHeatingOff;

  /// No description provided for @comingHomeHeating.
  ///
  /// In en, this message translates to:
  /// **'Heating to {temperature} °C'**
  String comingHomeHeating(String temperature);

  /// No description provided for @comingHomeAnnounce.
  ///
  /// In en, this message translates to:
  /// **'Tell the household'**
  String get comingHomeAnnounce;

  /// No description provided for @comingHomeAnnounceHint.
  ///
  /// In en, this message translates to:
  /// **'The message shows in the app and on the wall panel'**
  String get comingHomeAnnounceHint;

  /// No description provided for @comingHomeRun.
  ///
  /// In en, this message translates to:
  /// **'I\'m coming home'**
  String get comingHomeRun;

  /// No description provided for @comingHomeShortcutHint.
  ///
  /// In en, this message translates to:
  /// **'A long press on the app icon → \"Coming home\" does the same.'**
  String get comingHomeShortcutHint;

  /// No description provided for @comingHomeDone.
  ///
  /// In en, this message translates to:
  /// **'The home knows you are coming.'**
  String get comingHomeDone;

  /// No description provided for @comingHomeMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is coming home 🏠'**
  String comingHomeMessage(String name);

  /// No description provided for @comingHomeMessageNoName.
  ///
  /// In en, this message translates to:
  /// **'Someone is coming home 🏠'**
  String get comingHomeMessageNoName;

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
  /// **'The light comes up slowly before you wake, from a dim warm glow to daylight, like a real sunrise. Runs in Home Assistant, even with the phone off.'**
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

  /// No description provided for @sunriseAlias.
  ///
  /// In en, this message translates to:
  /// **'Sunrise alarm (Open Smart Home)'**
  String get sunriseAlias;

  /// No description provided for @wrappedTitle.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get wrappedTitle;

  /// No description provided for @wrappedIntro.
  ///
  /// In en, this message translates to:
  /// **'Your week at home'**
  String get wrappedIntro;

  /// No description provided for @wrappedIntroCaption.
  ///
  /// In en, this message translates to:
  /// **'The last 7 days, from Home Assistant\'s logbook. Tap the right side to go on.'**
  String get wrappedIntroCaption;

  /// No description provided for @wrappedDoors.
  ///
  /// In en, this message translates to:
  /// **'Doors and windows opened'**
  String get wrappedDoors;

  /// No description provided for @wrappedTopDoor.
  ///
  /// In en, this message translates to:
  /// **'Busiest: {name}'**
  String wrappedTopDoor(String name);

  /// No description provided for @wrappedLights.
  ///
  /// In en, this message translates to:
  /// **'Times a light went on'**
  String get wrappedLights;

  /// No description provided for @wrappedTopLight.
  ///
  /// In en, this message translates to:
  /// **'Favourite: {name} ({count}×)'**
  String wrappedTopLight(String name, int count);

  /// No description provided for @wrappedArrivals.
  ///
  /// In en, this message translates to:
  /// **'Homecomings'**
  String get wrappedArrivals;

  /// No description provided for @wrappedTopArrival.
  ///
  /// In en, this message translates to:
  /// **'Most often: {name} ({count}×)'**
  String wrappedTopArrival(String name, int count);

  /// No description provided for @wrappedUnlocks.
  ///
  /// In en, this message translates to:
  /// **'Unlocks'**
  String get wrappedUnlocks;

  /// No description provided for @wrappedBusiestDay.
  ///
  /// In en, this message translates to:
  /// **'The liveliest day at home'**
  String get wrappedBusiestDay;

  /// No description provided for @wrappedEnergy.
  ///
  /// In en, this message translates to:
  /// **'kWh of electricity this week'**
  String get wrappedEnergy;

  /// No description provided for @wrappedEnergyUnit.
  ///
  /// In en, this message translates to:
  /// **'since Monday'**
  String get wrappedEnergyUnit;

  /// No description provided for @wrappedEnergyLastWeek.
  ///
  /// In en, this message translates to:
  /// **'since Monday · last week {kwh} kWh'**
  String wrappedEnergyLastWeek(String kwh);

  /// No description provided for @wrappedOutro.
  ///
  /// In en, this message translates to:
  /// **'What a week!'**
  String get wrappedOutro;

  /// No description provided for @wrappedOutroCaption.
  ///
  /// In en, this message translates to:
  /// **'See you next week 👋'**
  String get wrappedOutroCaption;

  /// No description provided for @wrappedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant\'s logbook for this week is empty — nothing to count yet.'**
  String get wrappedEmpty;

  /// No description provided for @wrappedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant\'s logbook is not available right now.'**
  String get wrappedUnavailable;

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

  /// No description provided for @serviceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licences'**
  String get serviceLicenses;

  /// No description provided for @serviceLicensesHint.
  ///
  /// In en, this message translates to:
  /// **'The app and every package it uses'**
  String get serviceLicensesHint;

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

  /// No description provided for @demoHomeNotice.
  ///
  /// In en, this message translates to:
  /// **'This is the demo home. Add your Shelly, WLED, Tasmota or ESPHome devices and the demo turns itself off.'**
  String get demoHomeNotice;

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
  /// **'Shelly, WLED and ESPHome devices on the same Wi-Fi network as the phone show up here by themselves. Add Tasmota devices by their IP address.'**
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

  /// No description provided for @addDeviceChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get addDeviceChecking;

  /// No description provided for @addDeviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'No Shelly, WLED, Tasmota or ESPHome found at that address.'**
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

  /// No description provided for @demoDevicesSetting.
  ///
  /// In en, this message translates to:
  /// **'Demo devices'**
  String get demoDevicesSetting;

  /// No description provided for @demoDevicesHint.
  ///
  /// In en, this message translates to:
  /// **'A made-up home for trying the app.'**
  String get demoDevicesHint;

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
