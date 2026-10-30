// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class AppLocalizationsSr extends AppLocalizations {
  AppLocalizationsSr([String locale = 'sr']) : super(locale);

  @override
  String get appTitle => 'Open Smart Home Lite';

  @override
  String get mockModeBanner => 'MOCK REŽIM — demo podaci, bez stvarnih uređaja';

  @override
  String get welcomeTitle => 'Vaš dom, u jednoj aplikaciji';

  @override
  String get welcomeBody =>
      'Upravljajte svetlima, klimom, senzorima i scenama svih proizvođača i protokola koje podržava vaš Home Assistant server.';

  @override
  String get welcomeLocalFirst => 'Radi lokalno. Cloud nalog nije potreban.';

  @override
  String get chooseLanguage => 'Jezik';

  @override
  String get languageSystem => 'Sistemski';

  @override
  String get languageSerbian => 'Srpski';

  @override
  String get languageEnglish => 'English';

  @override
  String get getStarted => 'Započni';

  @override
  String get back => 'Nazad';

  @override
  String get cancel => 'Otkaži';

  @override
  String get continueAction => 'Nastavi';

  @override
  String get serverAddressTitle => 'Povezivanje sa Home Assistantom';

  @override
  String get serverAddressIntro =>
      'Unesite adresu vašeg Home Assistant servera, na primer onu koju kod kuće otvarate u pregledaču.';

  @override
  String get serverAddressLabel => 'Adresa servera';

  @override
  String get serverAddressHint => 'homeassistant.local:8123';

  @override
  String get checkConnection => 'Proveri vezu';

  @override
  String get checking => 'Proveravam…';

  @override
  String serverReachable(String address) {
    return 'Home Assistant je pronađen na adresi $address';
  }

  @override
  String get addressErrorEmpty => 'Unesite adresu servera.';

  @override
  String get addressErrorMalformed => 'Ovo nije ispravna adresa.';

  @override
  String get addressErrorUnsupportedScheme =>
      'Podržane su samo http:// i https:// adrese.';

  @override
  String get addressErrorMissingHost =>
      'Adresi nedostaje naziv računara ili IP adresa.';

  @override
  String get addressErrorCredentials =>
      'Ne unosite korisničko ime ili lozinku u adresu.';

  @override
  String get addressErrorPath =>
      'Home Assistant mora biti dostupan na korenu adrese (bez putanje kao što je /ha).';

  @override
  String get addressErrorQuery => 'Uklonite deo adrese posle znaka ? ili #.';

  @override
  String get addressErrorPort => 'Port mora biti između 1 i 65535.';

  @override
  String get riskLocalHttp => 'Nešifrovana veza unutar vaše lokalne mreže.';

  @override
  String get riskRemoteExposure =>
      'Ovo je javna adresa. Proverite da je server ažuran i zaštićen.';

  @override
  String get riskInsecureRemote =>
      'Upozorenje: ova javna adresa koristi nešifrovani HTTP. Vaš pristupni token može biti presretnut. Koristite HTTPS, osim ako veza ide kroz VPN.';

  @override
  String get insecureAcknowledge => 'Razumem rizik (npr. koristim VPN)';

  @override
  String get certificateUntrustedTitle => 'Nepouzdan sertifikat';

  @override
  String get certificateUntrustedBody =>
      'Ovaj uređaj ne veruje sertifikatu servera. To je uobičajeno za samopotpisani sertifikat, ali može značiti i da neko presreće vezu. Nastavite samo ako se otisak poklapa sa onim na vašem serveru.';

  @override
  String get certificateSubject => 'Izdat za';

  @override
  String get certificateIssuer => 'Izdavač';

  @override
  String get certificateValidUntil => 'Važi do';

  @override
  String get certificateFingerprint => 'SHA-256 otisak';

  @override
  String get certificateExpired => 'Ovaj sertifikat je istekao.';

  @override
  String get certificateConfirm =>
      'Uporedio/la sam otisak i verujem ovom sertifikatu';

  @override
  String get trustCertificate => 'Veruj ovom sertifikatu';

  @override
  String get tokenTitle => 'Prijava';

  @override
  String get tokenIntro =>
      'Aplikacija se prijavljuje pomoću dugotrajnog pristupnog tokena iz vašeg Home Assistant korisničkog profila.';

  @override
  String get tokenSteps =>
      '1. Otvorite Home Assistant u pregledaču.\n2. Kliknite na svoje korisničko ime (dole levo) → Security.\n3. U delu „Long-lived access tokens” izaberite „Create token”.\n4. Kopirajte token i nalepite ga ispod. Home Assistant ga prikazuje samo jednom.';

  @override
  String get tokenLabel => 'Pristupni token';

  @override
  String get tokenMockHint =>
      'Mock režim: svaki token radi; „invalid” simulira odbijen token.';

  @override
  String get showToken => 'Prikaži token';

  @override
  String get hideToken => 'Sakrij token';

  @override
  String get connect => 'Poveži se';

  @override
  String get connecting => 'Povezivanje…';

  @override
  String get tokenInvalidFormat =>
      'Token ne sme biti prazan niti sadržati razmake.';

  @override
  String get failureNetwork =>
      'Server nije dostupan. Proverite adresu i da li je uređaj na odgovarajućoj mreži.';

  @override
  String get failureTimeout => 'Server predugo ne odgovara.';

  @override
  String get failureAuthentication =>
      'Pristupni token je odbijen. Možda je pogrešan, istekao ili opozvan.';

  @override
  String get failureAuthorization =>
      'Ovaj korisnik nema dozvolu za ovu radnju.';

  @override
  String get failureValidation => 'Server nije prihvatio zahtev.';

  @override
  String get failureParsing => 'Server je poslao neočekivan odgovor.';

  @override
  String get failureServer =>
      'Server je odgovorio, ali ne kao Home Assistant, ili je prijavio grešku.';

  @override
  String get failureCertificate =>
      'Bezbedna veza ne može da se potvrdi (problem sa sertifikatom).';

  @override
  String get failureUnavailableEntity => 'Ovaj uređaj trenutno nije dostupan.';

  @override
  String get failureUnsupportedFeature => 'Ovaj uređaj ne podržava ovu radnju.';

  @override
  String get failureWebSocket => 'Veza u realnom vremenu je prekinuta.';

  @override
  String get failureStorage =>
      'Nije moguće pristupiti bezbednom skladištu na uređaju.';

  @override
  String get failureUnknown => 'Došlo je do greške. Pokušajte ponovo.';

  @override
  String get navHome => 'Početna';

  @override
  String get navSettings => 'Podešavanja';

  @override
  String get statusConnected => 'Povezano';

  @override
  String get statusConnecting => 'Povezivanje…';

  @override
  String get statusAuthenticating => 'Prijavljivanje…';

  @override
  String get statusReconnecting => 'Ponovno povezivanje…';

  @override
  String statusReconnectingIn(int seconds) {
    return 'Ponovno povezivanje za $seconds s';
  }

  @override
  String get statusDisconnected => 'Nije povezano';

  @override
  String get statusAuthFailed => 'Prijava odbijena';

  @override
  String get statusServerUnavailable => 'Server nije dostupan';

  @override
  String get statusError => 'Greška veze';

  @override
  String get retryNow => 'Pokušaj odmah';

  @override
  String get signInAgain => 'Prijavi se ponovo';

  @override
  String serverVersion(String version) {
    return 'Home Assistant $version';
  }

  @override
  String get settingsTitle => 'Podešavanja';

  @override
  String get appearance => 'Izgled';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistemska';

  @override
  String get themeLight => 'Svetla';

  @override
  String get themeDark => 'Tamna';

  @override
  String get language => 'Jezik';

  @override
  String get serverSection => 'Server';

  @override
  String get signOut => 'Odjavi se';

  @override
  String get signOutConfirmTitle => 'Odjaviti se?';

  @override
  String get signOutConfirmBody =>
      'Pristupni token biće obrisan sa ovog uređaja. Možete se ponovo prijaviti u bilo kom trenutku.';

  @override
  String get deleteAllData => 'Obriši sve lokalne podatke';

  @override
  String get deleteAllConfirmTitle => 'Obrisati sve lokalne podatke?';

  @override
  String get deleteAllConfirmBody =>
      'Sa ovog uređaja biće uklonjeni pristupni token, adresa servera i sva podešavanja. Na Home Assistant serveru se ništa ne menja.';

  @override
  String get delete => 'Obriši';

  @override
  String get privacySection => 'Privatnost i podaci';

  @override
  String get addressErrorMixedContent =>
      'Ova stranica je učitana preko HTTPS-a, pa pregledač blokira veze ka http:// serveru. Koristite https:// adresu servera ili otvorite web aplikaciju sa iste adrese kao Home Assistant.';

  @override
  String get webConnectionHint =>
      'U pregledaču ovo može značiti i da Home Assistant ne dozvoljava adresu ove web aplikacije (dodajte je u http: cors_allowed_origins u configuration.yaml) ili da pregledač ne veruje sertifikatu servera (jednom otvorite adresu servera u novoj kartici i prihvatite ga).';

  @override
  String get webSessionNotice =>
      'Sa tokenom prijava traje samo dok je ova kartica otvorena.';

  @override
  String get failureConfirmationRequired => 'Potvrdite ovu radnju.';

  @override
  String devicesInRooms(int devices, int rooms) {
    String _temp0 = intl.Intl.pluralLogic(
      devices,
      locale: localeName,
      other: '$devices uređaja',
      few: '$devices uređaja',
      one: '$devices uređaj',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rooms,
      locale: localeName,
      other: '$rooms prostorija',
      one: '$rooms prostoriji',
      zero: '0 prostorija',
    );
    return '$_temp0 u $_temp1';
  }

  @override
  String dataStaleSince(String time) {
    return 'Nema veze — prikazani su podaci poslednji put ažurirani $time. Možda nisu aktuelni.';
  }

  @override
  String get navRooms => 'Prostorije';

  @override
  String get navFavorites => 'Omiljeno';

  @override
  String get navScenes => 'Scene';

  @override
  String get stateOn => 'Uključeno';

  @override
  String get stateOff => 'Isključeno';

  @override
  String get stateUnavailable => 'Nedostupno';

  @override
  String get stateUnknown => 'Nepoznato';

  @override
  String stateOnBrightness(int percent) {
    return 'Uključeno · $percent %';
  }

  @override
  String get motionDetected => 'Detektovan pokret';

  @override
  String get motionClear => 'Nema pokreta';

  @override
  String get occupancyDetected => 'Prisutno';

  @override
  String get occupancyClear => 'Nema prisustva';

  @override
  String get contactOpen => 'Otvoreno';

  @override
  String get contactClosed => 'Zatvoreno';

  @override
  String get smokeDetected => 'Detektovan dim!';

  @override
  String get smokeClear => 'Nema dima';

  @override
  String get coDetected => 'Detektovan CO!';

  @override
  String get coClear => 'Nema CO';

  @override
  String get leakDetected => 'Curenje vode!';

  @override
  String get leakClear => 'Suvo';

  @override
  String get vibrationDetected => 'Vibracija';

  @override
  String get vibrationClear => 'Mirno';

  @override
  String get binaryActive => 'Aktivno';

  @override
  String get binaryInactive => 'Neaktivno';

  @override
  String get coverOpening => 'Otvara se…';

  @override
  String get coverClosing => 'Zatvara se…';

  @override
  String coverOpenPercent(int percent) {
    return 'Otvoreno $percent %';
  }

  @override
  String get lockLocked => 'Zaključano';

  @override
  String get lockUnlocked => 'Otključano';

  @override
  String get lockLocking => 'Zaključava se…';

  @override
  String get lockUnlocking => 'Otključava se…';

  @override
  String get lockJammed => 'Zaglavljeno!';

  @override
  String get alarmDisarmed => 'Isključen';

  @override
  String get alarmArmed => 'Uključen';

  @override
  String get alarmArming => 'Uključuje se…';

  @override
  String get alarmPending => 'Odbrojavanje…';

  @override
  String get alarmTriggered => 'ALARM!';

  @override
  String get hvacOff => 'Isključeno';

  @override
  String get hvacHeat => 'Grejanje';

  @override
  String get hvacCool => 'Hlađenje';

  @override
  String get hvacHeatCool => 'Grejanje/hlađenje';

  @override
  String get hvacAuto => 'Automatski';

  @override
  String get hvacDry => 'Sušenje';

  @override
  String get hvacFanOnly => 'Samo ventilator';

  @override
  String climateStatus(String mode, String temperature) {
    return '$mode · $temperature';
  }

  @override
  String get mediaPlaying => 'Reprodukcija';

  @override
  String get mediaPaused => 'Pauzirano';

  @override
  String get cameraIdle => 'Spremna';

  @override
  String get cameraStreaming => 'Prenos';

  @override
  String get cameraRecording => 'Snimanje';

  @override
  String get scriptRunning => 'Pokrenuto';

  @override
  String get routineReady => 'Spremno';

  @override
  String doorbellLast(String time) {
    return 'Poslednje zvono $time';
  }

  @override
  String get lowBattery => 'Slaba baterija';

  @override
  String batteryLevel(int percent) {
    return 'Baterija $percent %';
  }

  @override
  String get protocolCloud => 'Cloud';

  @override
  String get protocolVirtual => 'Virtuelni';

  @override
  String get favoritesEmpty =>
      'Dodirnite zvezdicu na stranici uređaja da ga dodate u omiljeno.';

  @override
  String get scenesTitle => 'Scene';

  @override
  String get scriptsTitle => 'Skripte';

  @override
  String get automationsTitle => 'Automatizacije';

  @override
  String get noScenes => 'Još nema scena.';

  @override
  String get dashboardAttention => 'Potrebna pažnja';

  @override
  String get summaryTemperature => 'Unutra';

  @override
  String get summaryHumidity => 'Vlažnost';

  @override
  String get summaryLights => 'Upaljena svetla';

  @override
  String get summaryOpenings => 'Vrata i prozori';

  @override
  String get summaryOpeningsClosed => 'Zatvoreno';

  @override
  String summaryOpeningsOpen(int count) {
    return '$count otvoreno';
  }

  @override
  String get summaryPower => 'Snaga';

  @override
  String get greetingMorning => 'Dobro jutro';

  @override
  String get greetingAfternoon => 'Dobar dan';

  @override
  String get greetingEvening => 'Dobro veče';

  @override
  String get greetingNight => 'Laku noć';

  @override
  String get summaryAlerts => 'Upozorenja';

  @override
  String get valueNotAvailable => 'Nije dostupno';

  @override
  String lightsOnOf(int on, int total) {
    return '$on od $total';
  }

  @override
  String lowBatteryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slabih baterija',
      few: '$count slabe baterije',
      one: '$count slaba baterija',
    );
    return '$_temp0';
  }

  @override
  String unavailableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nedostupnih',
      few: '$count nedostupna',
      one: '$count nedostupan',
    );
    return '$_temp0';
  }

  @override
  String get roomNoRoom => 'Bez prostorije';

  @override
  String get allDevices => 'Svi uređaji';

  @override
  String roomDevicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uređaja',
      few: '$count uređaja',
      one: '$count uređaj',
      zero: 'Nema uređaja',
    );
    return '$_temp0';
  }

  @override
  String roomLightsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count upaljenih svetala',
      few: '$count upaljena svetla',
      one: '$count upaljeno svetlo',
    );
    return '$_temp0';
  }

  @override
  String get roomEmpty => 'Nema uređaja u ovoj prostoriji.';

  @override
  String get noRoomsYet => 'U Home Assistantu nisu definisane prostorije.';

  @override
  String get groupLights => 'Svetla';

  @override
  String get groupClimate => 'Klima';

  @override
  String get groupCovers => 'Roletne i vrata';

  @override
  String get groupSwitches => 'Prekidači i utičnice';

  @override
  String get groupSecurity => 'Bezbednost';

  @override
  String get groupSensors => 'Senzori';

  @override
  String get groupMedia => 'Mediji';

  @override
  String get groupEnergy => 'Energija';

  @override
  String get groupOther => 'Ostalo';

  @override
  String get addFavorite => 'Dodaj u omiljeno';

  @override
  String get removeFavorite => 'Ukloni iz omiljenog';

  @override
  String get brightness => 'Jačina svetla';

  @override
  String get colorTemperature => 'Temperatura boje';

  @override
  String get warm => 'Toplo';

  @override
  String get cool => 'Hladno';

  @override
  String get color => 'Boja';

  @override
  String get targetTemperature => 'Željena temperatura';

  @override
  String get currentTemperature => 'Trenutno';

  @override
  String get increaseTemperature => 'Povećaj temperaturu';

  @override
  String get decreaseTemperature => 'Smanji temperaturu';

  @override
  String get mode => 'Režim';

  @override
  String get fanMode => 'Ventilator';

  @override
  String get position => 'Položaj';

  @override
  String get open => 'Otvori';

  @override
  String get close => 'Zatvori';

  @override
  String get stop => 'Zaustavi';

  @override
  String get lock => 'Zaključaj';

  @override
  String get unlock => 'Otključaj';

  @override
  String confirmUnlockTitle(String name) {
    return 'Otključati: $name?';
  }

  @override
  String confirmOpenTitle(String name) {
    return 'Otvoriti: $name?';
  }

  @override
  String confirmDisarmTitle(String name) {
    return 'Isključiti alarm: $name?';
  }

  @override
  String get confirmCriticalBody =>
      'Ova radnja utiče na bezbednost vašeg doma.';

  @override
  String get confirm => 'Potvrdi';

  @override
  String get activate => 'Pokreni';

  @override
  String get runNow => 'Pokreni sada';

  @override
  String sceneActivated(String name) {
    return 'Pokrenuto: $name';
  }

  @override
  String get automationEnabled => 'Uključena';

  @override
  String lastTriggered(String time) {
    return 'Poslednje pokretanje $time';
  }

  @override
  String get neverTriggered => 'Nikad pokrenuta';

  @override
  String get volume => 'Jačina zvuka';

  @override
  String get detailInfo => 'Informacije';

  @override
  String get infoRoom => 'Prostorija';

  @override
  String get infoManufacturer => 'Proizvođač';

  @override
  String get infoModel => 'Model';

  @override
  String get infoProtocol => 'Protokol';

  @override
  String get infoLastChanged => 'Poslednja promena';

  @override
  String get infoEntityId => 'ID entiteta';

  @override
  String get infoSignal => 'Signal';

  @override
  String get infoBattery => 'Baterija';

  @override
  String get deviceNotFound => 'Ovaj uređaj više ne postoji.';

  @override
  String get unavailableBanner =>
      'Uređaj je nedostupan. Kontrole su onemogućene dok se ponovo ne poveže.';

  @override
  String get controlsOffline =>
      'Kontrole će ponovo biti dostupne kada se veza uspostavi.';

  @override
  String get kioskSection => 'Kiosk režim (zidni tablet)';

  @override
  String get kioskStart => 'Pokreni kiosk režim';

  @override
  String get kioskStartOnLaunch => 'Otvori u kiosk režimu pri pokretanju';

  @override
  String get kioskKeepAwake => 'Drži ekran uključen';

  @override
  String get kioskDimAfter => 'Zatamni ekran posle';

  @override
  String get kioskReturnAfter => 'Vrati na početni ekran posle';

  @override
  String get kioskPin => 'PIN za izlaz';

  @override
  String get kioskPinSet => 'PIN je postavljen';

  @override
  String get kioskPinNotSet =>
      'Nema PIN-a — svako može da izađe iz kiosk režima';

  @override
  String get kioskSetPin => 'Postavi PIN';

  @override
  String get kioskChangePin => 'Promeni PIN';

  @override
  String get kioskRemovePin => 'Ukloni PIN';

  @override
  String get kioskPinHint => '4–8 cifara';

  @override
  String get kioskPinConfirm => 'Ponovite PIN';

  @override
  String get kioskPinMismatch => 'PIN-ovi se ne poklapaju.';

  @override
  String get kioskPinInvalid => 'Koristite 4–8 cifara.';

  @override
  String get kioskExit => 'Izađi iz kiosk režima';

  @override
  String get kioskEnterPin => 'Unesite PIN';

  @override
  String get kioskWrongPin => 'Pogrešan PIN.';

  @override
  String kioskLockedOut(int seconds) {
    return 'Previše pokušaja. Pokušajte ponovo za $seconds s.';
  }

  @override
  String get kioskOsHint =>
      'Za potpuno zaključan zidni panel koristite i sistemsku kiosk funkciju: Android pinovanje ekrana ili kiosk launcher, iOS Guided Access. One mogu i automatski da pokrenu aplikaciju.';

  @override
  String get durationNever => 'Nikad';

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
    return 'Prikazani su podaci od $time — ažuriranje…';
  }

  @override
  String get oauthSignIn => 'Prijavi se preko Home Assistanta';

  @override
  String get oauthHint =>
      'Prijavljujete se na stranici za prijavu vašeg Home Assistanta – aplikacija nikad ne vidi vašu lozinku.';

  @override
  String get rememberMe => 'Zapamti me na ovom uređaju';

  @override
  String get rememberMeHint =>
      'Ostajete prijavljeni i posle zatvaranja pregledača. Pristup možete opozvati bilo kada u Home Assistant profilu (Security → Refresh tokens).';

  @override
  String get orUseToken => 'Ili koristite dugotrajni pristupni token';

  @override
  String get loginFailed => 'Prijava nije završena. Pokušajte ponovo.';

  @override
  String get discoveryTitle => 'Home Assistant na ovoj mreži';

  @override
  String get discoverySearching => 'Pretraga…';

  @override
  String get discoveryNothingFound =>
      'Server nije automatski pronađen. Unesite adresu ispod.';

  @override
  String get discoverySearchAgain => 'Traži ponovo';

  @override
  String get energyTitle => 'Energija';

  @override
  String get energyToday => 'Danas';

  @override
  String get energyWeek => 'Ova nedelja';

  @override
  String get energyMonth => 'Ovaj mesec';

  @override
  String get energyCurrentPower => 'Trenutna snaga';

  @override
  String get energyNotConfigured =>
      'Energija još nije podešena u Home Assistantu (Podešavanja → Kontrolne table → Energija). Kada se podesi, ovde se prikazuju potrošnja, solar i uređaji.';

  @override
  String get energyOffline =>
      'Statistika energije se učitava iz Home Assistanta i dostupna je dok je aplikacija povezana.';

  @override
  String get energyConsumption => 'Potrošnja doma';

  @override
  String get energyFromGrid => 'Iz mreže';

  @override
  String get energyToGrid => 'U mrežu';

  @override
  String get energySolar => 'Solarna proizvodnja';

  @override
  String get energyBatteryCharge => 'Baterija – punjenje';

  @override
  String get energyBatteryDischarge => 'Baterija – pražnjenje';

  @override
  String get energyGas => 'Gas';

  @override
  String get energyCostEstimate => 'Procena troška';

  @override
  String get energySetTariff => 'Unesite tarifu za procenu troška';

  @override
  String get energyPerHour => 'Potrošnja po satima';

  @override
  String get energyPerDay => 'Potrošnja po danima';

  @override
  String get energyTopConsumers => 'Najveći potrošači';

  @override
  String get energyNoDevices =>
      'U Home Assistantu nijedan uređaj nije dodat u Energy kontrolnu tablu.';

  @override
  String get energyNoData => 'Još nema podataka za ovaj period.';

  @override
  String energyPeak(String time, String value) {
    return 'Najviše: $time · $value';
  }

  @override
  String get energyShowChart => 'Grafikon';

  @override
  String get energyShowTable => 'Tabela';

  @override
  String get energyConsumptionChart => 'Grafikon potrošnje';

  @override
  String get energyTariffTitle => 'Tarifa za struju';

  @override
  String get energyTariffHint =>
      'Koristi se samo za procenu na ovom uređaju. Pravi račun uključuje i fiksne naknade, poreze i obračun po zonama.';

  @override
  String get energyTariffImport => 'Cena po kWh iz mreže';

  @override
  String get energyTariffExport => 'Naknada po kWh predatom u mrežu (opciono)';

  @override
  String get energyTariffCurrency => 'Valuta';

  @override
  String get energyTariffInvalid => 'Unesite ispravnu, nenegativnu cenu.';

  @override
  String get save => 'Sačuvaj';

  @override
  String get weatherClear => 'Vedro';

  @override
  String get weatherClearNight => 'Vedra noć';

  @override
  String get weatherPartlyCloudy => 'Delimično oblačno';

  @override
  String get weatherCloudy => 'Oblačno';

  @override
  String get weatherFog => 'Magla';

  @override
  String get weatherRain => 'Kiša';

  @override
  String get weatherHeavyRain => 'Jaka kiša';

  @override
  String get weatherSnow => 'Sneg';

  @override
  String get weatherSleet => 'Susnežica';

  @override
  String get weatherHail => 'Grad';

  @override
  String get weatherThunderstorm => 'Grmljavina';

  @override
  String get weatherWindy => 'Vetrovito';

  @override
  String get weatherExceptional => 'Nepogoda';

  @override
  String get weatherAtHome => 'Vreme kod kuće';

  @override
  String get weatherAtMyLocation => 'Vreme na mojoj lokaciji';

  @override
  String get weatherEnableDevice => 'Vreme na mojoj lokaciji';

  @override
  String get weatherEnableDeviceConfirm => 'Uključi';

  @override
  String get weatherDeviceDisclosure =>
      'Aplikacija će tražiti vašu približnu lokaciju (ne precizan GPS), zaokružiti je na oko 1 km i slati je servisu MET Norway (api.met.no) radi prognoze – otprilike na svakih 30 minuta dok je aplikacija otvorena. Ništa drugo se ne šalje. Možete isključiti bilo kada u Podešavanja → Privatnost i podaci.';

  @override
  String get weatherDeviceSettingHint =>
      'Približna lokacija se šalje servisu MET Norway. Podrazumevano isključeno.';

  @override
  String get weatherMetAttribution => 'Podaci: MET Norway (CC BY 4.0)';

  @override
  String get weatherLocationDeniedForever =>
      'Pristup lokaciji je blokiran za ovu aplikaciju.';

  @override
  String get weatherOpenSettings => 'Otvori podešavanja';

  @override
  String get weatherLocationOff => 'Lokacija je isključena na ovom uređaju.';

  @override
  String get weatherLocationDenied => 'Pristup lokaciji nije dozvoljen.';

  @override
  String get weatherDeviceUnavailable =>
      'Vreme za vašu lokaciju trenutno nije dostupno.';

  @override
  String get weatherWind => 'Vetar';

  @override
  String get summaryOutdoor => 'Napolju';

  @override
  String get presetNone => 'Bez režima';

  @override
  String get presetHome => 'Kod kuće';

  @override
  String get presetAway => 'Odsutni';

  @override
  String get presetSleep => 'Spavanje';

  @override
  String get presetEco => 'Eco';

  @override
  String get presetComfort => 'Udobno';

  @override
  String get presetBoost => 'Pojačano';

  @override
  String get presetActivity => 'Aktivnost';

  @override
  String get thermostatModes => 'Režimi';

  @override
  String get powerToggle => 'Uključi/isključi';

  @override
  String get personHome => 'Kod kuće';

  @override
  String get personAway => 'Nije kod kuće';

  @override
  String get householdTitle => 'Ukućani';

  @override
  String get searchHint => 'Pretraži';

  @override
  String get done => 'Gotovo';

  @override
  String get timeJustNow => 'upravo';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count minuta',
      few: 'pre $count minuta',
      one: 'pre $count minut',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count sati',
      few: 'pre $count sata',
      one: 'pre $count sat',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pre $count dana',
      few: 'pre $count dana',
      one: 'pre $count dan',
    );
    return '$_temp0';
  }

  @override
  String get weatherForecastTitle => 'Vremenska prognoza';

  @override
  String get weatherHourly => 'Narednih sati';

  @override
  String get weatherDaily => 'Narednih dana';

  @override
  String get weatherToday => 'Danas';

  @override
  String get weatherNow => 'Sada';

  @override
  String get weatherNoForecast =>
      'Vaš Home Assistant entitet za vreme ne daje prognozu.';

  @override
  String get weatherPrecipitation => 'Padavine';

  @override
  String get weatherFeelsHint =>
      'Iz vašeg Home Assistant entiteta za vreme. Ništa ne napušta vašu mrežu.';

  @override
  String get camerasTitle => 'Kamere';

  @override
  String get cameraUnavailable => 'Kamera trenutno ne šalje sliku.';

  @override
  String cameraSnapshotAt(String time) {
    return 'Snimak $time';
  }

  @override
  String cameraRefreshHint(int seconds) {
    return 'Slika se osvežava svake $seconds s dok je ovaj ekran otvoren. Ništa se ne snima niti čuva.';
  }

  @override
  String get cameraFullscreen => 'Ceo ekran';

  @override
  String get cameraLoading => 'Učitavam kameru…';

  @override
  String get kioskShowCameras => 'Prikaži kamere';

  @override
  String get kioskShowCamerasHint =>
      'Sliku kamera vidi svako ko gleda u zidni tablet.';

  @override
  String get calendarTitle => 'Kalendar';

  @override
  String get calendarToday => 'Danas';

  @override
  String get calendarTomorrow => 'Sutra';

  @override
  String get calendarAllDay => 'Ceo dan';

  @override
  String get calendarNoEvents => 'Nema događaja';

  @override
  String get calendarNone =>
      'U Home Assistantu nema kalendara. Dodajte ga tamo, na primer Google Calendar, CalDAV ili integraciju Local Calendar.';

  @override
  String get calendarUnavailable => 'Kalendar trenutno nije dostupan.';

  @override
  String get calendarPrevMonth => 'Prethodni mesec';

  @override
  String get calendarNextMonth => 'Sledeći mesec';

  @override
  String get calendarBackToToday => 'Danas';

  @override
  String get assistTitle => 'Assist';

  @override
  String get assistHint => 'Napišite komandu ili pitanje';

  @override
  String get assistSend => 'Pošalji';

  @override
  String get assistIntro =>
      'Zamolite Home Assistant da nešto uradi, na primer:';

  @override
  String get assistSuggestionLightsOff => 'Ugasi svetla';

  @override
  String get assistSuggestionTemperature =>
      'Kolika je temperatura u dnevnoj sobi?';

  @override
  String get assistSuggestionLightsOn => 'Upali svetla';

  @override
  String get assistUnavailable => 'Assist trenutno nije dostupan.';

  @override
  String get assistNotUnderstood => 'Assist to nije mogao da uradi.';

  @override
  String get assistPrivacy =>
      'Tekst ide samo na vaš Home Assistant server. Assist razume jezike koji su tamo podešeni i radi sa ovlašćenjima vašeg naloga.';

  @override
  String get mediaPlayPause => 'Pusti ili pauziraj';

  @override
  String get mediaNext => 'Sledeća';

  @override
  String get mediaPrevious => 'Prethodna';

  @override
  String get mediaNowPlaying => 'Sada svira';

  @override
  String get addDeviceTitle => 'Dodaj uređaj';

  @override
  String get addDeviceIntro =>
      'Novi uređaji se uparuju sa vašim Home Assistant hubom, koji ima Zigbee ili Z-Wave radio, a ne sa ovim telefonom. Aplikacija vas vodi kroz postupak.';

  @override
  String get addDeviceZigbee => 'Zigbee';

  @override
  String get addDeviceZigbeeSubtitle =>
      'Senzori, sijalice, utičnice, prekidači';

  @override
  String get addDeviceWifi => 'Wi-Fi i LAN';

  @override
  String get addDeviceMatter => 'Matter';

  @override
  String get addDeviceZwave => 'Z-Wave';

  @override
  String get addDeviceSoon => 'Uskoro';

  @override
  String get zigbeeViaZha => 'Preko ZHA';

  @override
  String get zigbeeViaZ2m => 'Preko Zigbee2MQTT';

  @override
  String get zigbeeNotFound =>
      'U Home Assistantu nije pronađen ni ZHA ni Zigbee2MQTT. Prvo tamo dodajte Zigbee koordinator.';

  @override
  String get zigbeeStep1 => 'Pokrenite uparivanje dugmetom ispod.';

  @override
  String get zigbeeStep2 =>
      'Resetujte uređaj ili ga stavite u režim uparivanja. Obično držite njegovo dugme oko 5 sekundi dok ne zatrepće; pogledajte uputstvo uređaja.';

  @override
  String get zigbeeStep3 =>
      'Držite uređaj blizu huba dok se ne pojavi na listi.';

  @override
  String get pairingStart => 'Pokreni uparivanje';

  @override
  String get pairingStop => 'Zaustavi';

  @override
  String get pairingExtend => 'Produži';

  @override
  String get pairingOpen => 'Uparivanje je uključeno';

  @override
  String pairingRemaining(String time) {
    return 'Još $time';
  }

  @override
  String get pairingClosed => 'Uparivanje je isključeno';

  @override
  String get pairingWaiting => 'Čekam nove uređaje…';

  @override
  String get pairingFound => 'Novi uređaji';

  @override
  String pairingFailed(String reason) {
    return 'Uparivanje nije pokrenuto. $reason';
  }

  @override
  String get newDeviceSetUp => 'Podesi';

  @override
  String get setUpDeviceTitle => 'Ime i prostorija';

  @override
  String get deviceNameLabel => 'Ime';

  @override
  String get deviceRoomLabel => 'Prostorija';

  @override
  String get setUpSaved => 'Sačuvano.';

  @override
  String get setUpFailed =>
      'Ime i prostorija ne mogu da se promene odavde. Uradite to u Home Assistantu, u Podešavanja → Uređaji.';

  @override
  String get weatherHomeLocationTitle => 'Prognoza za vaš dom';

  @override
  String get weatherHomeLocationHint =>
      'Uključite prognozu: aplikacija će zapamtiti približnu lokaciju ovog telefona kao lokaciju doma.';

  @override
  String get weatherHomeLocationEnable => 'Uključi prognozu';

  @override
  String get weatherHomeLocationDisclosure =>
      'Aplikacija će jednom uzeti približnu lokaciju ovog telefona (zaokruženu na oko 1 km) kao lokaciju doma i slati je servisu MET Norway (api.met.no) svakih 30 minuta. Ništa drugo se ne šalje. Možete je isključiti u Podešavanjima.';

  @override
  String get weatherHomeLocationSetting =>
      'Prognoza za lokaciju doma (MET Norway)';

  @override
  String get weatherHomeLocationSettingHint =>
      'Šalje približnu lokaciju doma (zapamćenu kad ste uključili prognozu).';

  @override
  String get weatherNoHomeCoordinates =>
      'U Home Assistantu nije podešena lokacija doma.';

  @override
  String get calendarNoneShort => 'U Home Assistantu nema kalendara';

  @override
  String get mediaTitle => 'Muzika i mediji';

  @override
  String get mediaNoPlayers =>
      'U Home Assistantu još nema media plejera. Dodajte ga tamo, na primer Spotify, Google Cast, Sonos, DLNA, Kodi ili integraciju vašeg smart TV-a, i pojaviće se ovde.';

  @override
  String get mediaSource => 'Izvor';

  @override
  String get mediaIdle => 'Ništa ne svira';

  @override
  String weatherHomeLocationFar(int km) {
    return 'Lokacija doma u Home Assistantu je oko $km km od ovog uređaja. Ako to nije tačno, podesite je u Home Assistantu (Podešavanja → Sistem → Opšte); prognoza za dom koristi tu lokaciju.';
  }

  @override
  String get mediaNoPlayersShort => 'Još nema media plejera';

  @override
  String get assistMic => 'Izgovorite komandu';

  @override
  String get assistListening => 'Slušam…';

  @override
  String get voicePrivacyTitle => 'Glasovne komande';

  @override
  String get voicePrivacyBody =>
      'Prepoznavač govora na telefonu pretvara govor u tekst; vašem Home Assistantu ide samo tekst. Neki telefoni prepoznaju govor samo preko interneta (na primer Google ili Apple servis), koji tada dobija snimak vašeg glasa.';

  @override
  String get voiceOnDeviceOnly => 'Samo na uređaju';

  @override
  String get voiceAllowCloud => 'Dozvoli i preko interneta';

  @override
  String get voiceUnavailable =>
      'Prepoznavanje govora nije dostupno. Proverite dozvolu za mikrofon.';

  @override
  String get voiceOnDeviceUnavailable =>
      'Ovaj uređaj ne može da prepozna ovaj jezik bez interneta. Prepoznavanje preko interneta možete dozvoliti u Podešavanjima.';

  @override
  String get voiceNoMatch => 'Nisam razumeo. Pokušajte ponovo.';

  @override
  String get voiceCloudSetting => 'Prepoznavanje govora preko interneta';

  @override
  String get voiceCloudSettingHint =>
      'Kad je isključeno, glasovne komande se prepoznaju samo na uređaju.';

  @override
  String get addDeviceWifiSubtitle =>
      'Uređaji koje je Home Assistant pronašao na mreži';

  @override
  String get discoveredTitle => 'Pronađeno na mreži';

  @override
  String get discoveredEmpty =>
      'Home Assistant nije pronašao nove uređaje. Povežite uređaj na istu Wi-Fi mrežu i sačekajte minut; uređaji koje HA ne može sam da pronađe dodaju se u Home Assistantu, u Podešavanja → Uređaji.';

  @override
  String discoveredVia(String source) {
    return 'Pronađeno preko: $source';
  }

  @override
  String get discoveredRefresh => 'Traži ponovo';

  @override
  String get discoveredUnavailable =>
      'Lista pronađenih uređaja nije dostupna. Za to je obično potreban administratorski nalog u Home Assistantu.';

  @override
  String get flowAdd => 'Dodaj';

  @override
  String get flowNext => 'Dalje';

  @override
  String flowConfirm(String name) {
    return 'Dodati $name u vaš dom?';
  }

  @override
  String flowDone(String title) {
    return 'Dodato: $title';
  }

  @override
  String get flowDoneDevices => 'Novi uređaji';

  @override
  String flowAborted(String reason) {
    return 'Podešavanje je prekinuto: $reason';
  }

  @override
  String get flowAbortedGeneric => 'Home Assistant je prekinuo podešavanje.';

  @override
  String get flowUnsupported =>
      'Ovaj korak zahteva sam Home Assistant (na primer prijavu u pregledaču). Nastavite tamo.';

  @override
  String get flowUnsupportedField =>
      'Ovaj formular ima polja koja aplikacija još ne prikazuje. Nastavite u Home Assistantu.';

  @override
  String get flowWorking => 'Podešavam…';

  @override
  String get flowRequired => 'Obavezno';

  @override
  String get flowFinish => 'Gotovo';

  @override
  String get matterTitle => 'Matter';

  @override
  String get matterIntro =>
      'Dodajte Matter uređaj koji već radi sa nekom drugom aplikacijom (Google Home, Apple Home, SmartThings, Alexa…).';

  @override
  String get matterStep1 =>
      'U toj aplikaciji otvorite uređaj i izaberite da ga podelite sa drugom aplikacijom ili kontrolerom („Povezane Matter aplikacije”, „Uključi režim uparivanja”).';

  @override
  String get matterStep2 =>
      'Skenirajte QR kod koji se prikaže ili unesite 11-cifreni kod.';

  @override
  String get matterStep3 =>
      'Home Assistant tada dodaje uređaj preko vaše mreže; obe aplikacije mogu da ga kontrolišu.';

  @override
  String get matterNewDeviceNote =>
      'Potpuno novi Matter uređaji preko Bluetooth-a dodaju se iz Android aplikacije.';

  @override
  String get matterCodeLabel => 'Kod za uparivanje';

  @override
  String get matterCodeHint => '1234-567-8901 ili MT:…';

  @override
  String get matterInvalidCode =>
      'To nije ispravan Matter kod. Proverite cifre.';

  @override
  String get matterScan => 'Skeniraj QR kod';

  @override
  String get matterAdding => 'Dodajem uređaj… može potrajati do minut.';

  @override
  String get matterNotAvailable =>
      'Matter integracija nije podešena u Home Assistantu. Prvo je dodajte tamo.';

  @override
  String get matterFailed =>
      'Uređaj nije dodat. Proverite da je deljenje i dalje uključeno u drugoj aplikaciji (kod važi nekoliko minuta) i da je uređaj na istoj mreži.';

  @override
  String get matterAdded => 'Uređaj je dodat';

  @override
  String get scanPointCamera => 'Usmerite kameru na Matter QR kod.';

  @override
  String get zwaveTitle => 'Z-Wave';

  @override
  String get zwaveIntro =>
      'Dodajte Z-Wave uređaj preko vašeg Z-Wave JS kontrolera.';

  @override
  String get zwaveNotAvailable =>
      'Z-Wave JS integracija nije podešena u Home Assistantu.';

  @override
  String get zwaveStart => 'Pokreni uključivanje';

  @override
  String get zwaveStop => 'Zaustavi';

  @override
  String get zwaveStatusWaiting =>
      'Stavite uređaj u režim uključivanja (često tri brza pritiska dugmeta; pogledajte uputstvo).';

  @override
  String get zwaveStatusFound => 'Uređaj je pronađen…';

  @override
  String get zwaveStatusInterview =>
      'Upoznajem uređaj (intervju)… uređajima na bateriju može trebati nekoliko minuta.';

  @override
  String get zwaveStatusDone => 'Uređaj je dodat';

  @override
  String get zwaveStatusFailed =>
      'Uključivanje nije uspelo. Pokušajte ponovo, bliže kontroleru.';

  @override
  String get zwaveStatusStopped => 'Uključivanje je zaustavljeno.';

  @override
  String get zwaveGrantTitle => 'Bezbednost';

  @override
  String get zwaveGrantBody =>
      'Uređaj traži ove nivoe bezbednosti. Preporučeno je dozvoliti sve.';

  @override
  String get zwaveS2Unauth => 'S2 bez autentifikacije';

  @override
  String get zwaveS2Auth => 'S2 sa autentifikacijom';

  @override
  String get zwaveS2Access => 'S2 kontrola pristupa (brave, garažna vrata)';

  @override
  String get zwaveS0 => 'S0 (stari način)';

  @override
  String get zwaveGrant => 'Dozvoli';

  @override
  String get zwavePinTitle => 'PIN sa uređaja';

  @override
  String zwavePinBody(String dsk) {
    return 'Unesite prvih 5 cifara DSK koda sa nalepnice uređaja ili kutije (obično podvučene). Ostatak koda: $dsk';
  }

  @override
  String get zwavePinLabel => '5 cifara';

  @override
  String get zwavePinInvalid => 'Unesite tačno 5 cifara.';

  @override
  String get zwaveSmartStart => 'SmartStart: skeniraj QR';

  @override
  String get zwaveSmartStartHint =>
      'Uređaji sa SmartStart QR kodom se sami pridruže kad ih uključite.';

  @override
  String get zwaveSmartStartDone =>
      'Uređaj je prijavljen. Uključite ga; pridružiće se sam za nekoliko minuta.';

  @override
  String get zwaveSmartStartInvalid => 'To nije Z-Wave QR kod.';

  @override
  String get scanPointCameraZwave => 'Usmerite kameru na Z-Wave QR kod.';

  @override
  String get historyTitle => 'Istorija';

  @override
  String get history24h => '24 h';

  @override
  String get history7d => '7 dana';

  @override
  String historyMin(String value) {
    return 'Min $value';
  }

  @override
  String historyMax(String value) {
    return 'Maks $value';
  }

  @override
  String get historyEmpty => 'Nema podataka za ovaj period.';

  @override
  String get historyUnavailable =>
      'Istorija nije dostupna. Moguće je da je snimanje (recorder) isključeno u Home Assistantu.';

  @override
  String get activityTitle => 'Aktivnost';

  @override
  String get activityByUser => 'ručno';

  @override
  String get activityEmpty => 'U poslednja 24 sata nije bilo promena.';

  @override
  String get notificationsTitle => 'Obaveštenja';

  @override
  String notificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count obaveštenja iz Home Assistanta',
      few: '$count obaveštenja iz Home Assistanta',
      one: '$count obaveštenje iz Home Assistanta',
    );
    return '$_temp0';
  }

  @override
  String get notificationDismiss => 'Odbaci';

  @override
  String get notificationsDismissAll => 'Odbaci sve';

  @override
  String get notificationsEmpty => 'Nema obaveštenja.';

  @override
  String get cameraSnapshots => 'Snimci';

  @override
  String get cameraLive => 'Uživo';

  @override
  String get cameraLiveHint =>
      'Video uživo iz Home Assistanta dok je ovaj ekran otvoren; zvuk je isključen. Ništa se ne snima.';

  @override
  String get cameraLiveFailed =>
      'Video uživo nije dostupan za ovu kameru (ili video plejer ne veruje sertifikatu servera). Snimci i dalje rade.';

  @override
  String get appLockTitle => 'Open Smart Home je zaključan';

  @override
  String get appUnlock => 'Otključaj';

  @override
  String get appLockReason => 'Otključajte Open Smart Home';

  @override
  String appLockCriticalReason(String device) {
    return 'Potvrdite: $device';
  }

  @override
  String get securitySection => 'Bezbednost';

  @override
  String get appLockSetting => 'Zaključaj aplikaciju';

  @override
  String get appLockSettingHint =>
      'Traži otisak, lice ili PIN uređaja pri otvaranju aplikacije (posle 1 minuta u pozadini).';

  @override
  String get appLockCriticalSetting => 'Potvrda za brave i alarm';

  @override
  String get appLockCriticalSettingHint =>
      'Traži potvrdu i pre otključavanja vrata, otvaranja garaže ili isključivanja alarma.';

  @override
  String get appLockNoDeviceAuth =>
      'Na ovom uređaju nije podešeno zaključavanje ekrana ni biometrija.';

  @override
  String get homesTitle => 'Domovi';

  @override
  String get addHome => 'Dodaj još jedan dom';

  @override
  String get alarmArm_home => 'Kod kuće';

  @override
  String get alarmArm_away => 'Odsutni';

  @override
  String get alarmArm_night => 'Noć';

  @override
  String get alarmArm_vacation => 'Odmor';

  @override
  String get alarmArm_custom_bypass => 'Prilagođeno';

  @override
  String get alarmArmTitle => 'Uključi alarm';

  @override
  String get alarmDisarm => 'Isključi alarm';

  @override
  String get alarmCodeTitle => 'Kod alarma';

  @override
  String get vacuumCleaning => 'Čisti';

  @override
  String get vacuumDocked => 'Na punjaču';

  @override
  String get vacuumReturning => 'Vraća se na punjač';

  @override
  String get vacuumPaused => 'Pauzirano';

  @override
  String get vacuumError => 'Greška';

  @override
  String get vacuumIdle => 'Miruje';

  @override
  String get vacuumStart => 'Pokreni';

  @override
  String get vacuumPause => 'Pauza';

  @override
  String get vacuumReturnHome => 'Na punjač';

  @override
  String get fanSpeed => 'Brzina';

  @override
  String get fanOscillate => 'Okretanje';

  @override
  String get targetHumidityLabel => 'Ciljna vlažnost';

  @override
  String get modeLabel => 'Režim';

  @override
  String get valueLabel => 'Vrednost';

  @override
  String get editDevice => 'Izmeni ime i prostoriju';

  @override
  String get deviceSearchHint => 'Pretraga po imenu, prostoriji ili vrsti';

  @override
  String get deviceSearchEmpty => 'Nijedan uređaj ne odgovara.';

  @override
  String get favoritesReorder => 'Promeni redosled';

  @override
  String get restrictedTitle => 'Režim za decu i goste';

  @override
  String get restrictedHint =>
      'Skriva osetljive uređaje i zaključava podešavanja PIN-om na ovom uređaju. Ovlašćenja u Home Assistantu se ne menjaju; za prava ograničenja koristite posebnog HA korisnika.';

  @override
  String get restrictedHideSecurity => 'Sakrij brave, alarm i garažna vrata';

  @override
  String get restrictedHideCameras => 'Sakrij kamere';

  @override
  String get restrictedEnable => 'Uključi (postavi PIN)';

  @override
  String get restrictedActive => 'Režim za decu i goste je uključen';

  @override
  String get restrictedDisable => 'Isključi (PIN)';

  @override
  String get restrictedHidden => 'Nije dostupno u režimu za decu i goste.';

  @override
  String get autoNew => 'Nova automatizacija';

  @override
  String get autoWhen => 'Kada';

  @override
  String get autoThen => 'Uradi';

  @override
  String get autoName => 'Ime';

  @override
  String get autoTriggerTime => 'Vreme';

  @override
  String get autoTriggerDevice => 'Uređaj';

  @override
  String get autoTriggerSun => 'Sunce';

  @override
  String get autoEveryDay => 'Svaki dan';

  @override
  String get autoSunrise => 'Izlazak sunca';

  @override
  String get autoSunset => 'Zalazak sunca';

  @override
  String autoOffset(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      zero: 'Tačno u to vreme',
    );
    return '$_temp0';
  }

  @override
  String get autoPickDevice => 'Izaberi uređaj';

  @override
  String get autoAddAction => 'Dodaj radnju';

  @override
  String get autoSave => 'Sačuvaj u Home Assistant';

  @override
  String get autoSaved => 'Automatizacija je sačuvana u Home Assistantu.';

  @override
  String get autoSaveFailed =>
      'Automatizacija nije sačuvana. Za to je potreban administratorski nalog u Home Assistantu.';

  @override
  String get autoDelete => 'Obriši automatizaciju';

  @override
  String autoDeleteConfirm(String name) {
    return 'Obrisati „$name”? Ovo se ne može poništiti.';
  }

  @override
  String get autoIncomplete => 'Izaberite kada se pokreće i bar jednu radnju.';

  @override
  String get autoChangesTo => 'pređe u';

  @override
  String get autoNameHint => 'Na primer: Svetlo u hodniku noću';

  @override
  String get autoHint =>
      'Čuva se kao obična Home Assistant automatizacija, pa radi i kad je ovaj telefon isključen. Kasnije je možete menjati i u Home Assistantu.';

  @override
  String get svc_turn_on => 'Uključi';

  @override
  String get svc_turn_off => 'Isključi';

  @override
  String get svc_open_cover => 'Otvori';

  @override
  String get svc_close_cover => 'Zatvori';

  @override
  String get svc_lock => 'Zaključaj';

  @override
  String get svc_start => 'Pokreni';

  @override
  String get svc_return_to_base => 'Na punjač';

  @override
  String get svc_media_play => 'Pusti';

  @override
  String get svc_media_pause => 'Pauziraj';

  @override
  String get svc_activate => 'Aktiviraj';

  @override
  String get allLightsOn => 'Upali sva';

  @override
  String get allLightsOff => 'Ugasi sva';

  @override
  String get allLightsTitle => 'Sva svetla u kući';

  @override
  String get floorOther => 'Ostalo';

  @override
  String get sceneNew => 'Nova scena od trenutnog stanja';

  @override
  String get sceneHint =>
      'Čuva kako su izabrani uređaji podešeni sada (uključeno/isključeno, jačina, boja, roletne, temperatura) kao Home Assistant scenu.';

  @override
  String get sceneName => 'Ime scene';

  @override
  String get sceneDevices => 'Uređaji';

  @override
  String get sceneSave => 'Sačuvaj scenu';

  @override
  String get sceneSaved => 'Scena je sačuvana u Home Assistantu.';

  @override
  String get sceneNeedDevice => 'Izaberite bar jedan uređaj.';

  @override
  String get sceneDelete => 'Obriši scenu';

  @override
  String sceneDefaultName(String time) {
    return 'Scena $time';
  }

  @override
  String energyPrevDay(String value) {
    return 'Juče: $value';
  }

  @override
  String energyPrevWeek(String value) {
    return 'Prošle nedelje: $value';
  }

  @override
  String energyPrevMonth(String value) {
    return 'Prošlog meseca: $value';
  }

  @override
  String get autoEdit => 'Izmeni automatizaciju';

  @override
  String get autoTooComplex =>
      'Ova automatizacija radi više nego što editor u aplikaciji može da prikaže. Izmenite je u Home Assistantu.';

  @override
  String get backupSection => 'Rezervna kopija i prenos';

  @override
  String get backupHint =>
      'Ceo dom — uređaji, sobe, imena, scene, automatizacije i dodaci — i izgled aplikacije, da ih sačuvate ili prenesete na drugi telefon ili zidni tablet. PIN-ovi, fotografije i izbori ovog uređaja se ne prenose.';

  @override
  String get backupCopy => 'Kopiraj podešavanja';

  @override
  String get backupPaste => 'Nalepi podešavanja';

  @override
  String get backupCopied =>
      'Kopirano. Nalepite u aplikaciju na drugom uređaju.';

  @override
  String get backupImported => 'Podešavanja su primenjena.';

  @override
  String get backupInvalid => 'To nisu Open Smart Home podešavanja.';

  @override
  String get autoAddTrigger => 'Dodaj okidač';

  @override
  String get autoAnyTrigger => 'Pokreće se kad se desi bilo šta od ovoga.';

  @override
  String get autoOnlyIf => 'Samo ako';

  @override
  String get autoOnlyIfHint => 'Opciono. Sve ovo mora da važi kada se pokrene.';

  @override
  String get autoAddCondition => 'Dodaj uslov';

  @override
  String get autoTriggerValue => 'Vrednost';

  @override
  String get autoAbove => 'Poraste iznad';

  @override
  String get autoBelow => 'Padne ispod';

  @override
  String get autoThreshold => 'Granica';

  @override
  String get autoCondTime => 'Između dva vremena';

  @override
  String get autoCondAfter => 'Od';

  @override
  String get autoCondBefore => 'Do';

  @override
  String get autoCondDevice => 'Uređaj je u stanju';

  @override
  String get autoCondDark => 'Samo kad je mrak';

  @override
  String get autoCondLight => 'Samo kad je dan';

  @override
  String get autoIs => 'je';

  @override
  String get activityAll => 'Sve';

  @override
  String get activitySecurity => 'Vrata i bezbednost';

  @override
  String get activityPeople => 'Ukućani';

  @override
  String get activityHint =>
      'Iz dnevnika Home Assistanta za poslednja 24 sata. Senzori koji mere neprekidno (temperatura, snaga) se ne prikazuju.';

  @override
  String get alertsSetting => 'Obaveštenja o kritičnim upozorenjima';

  @override
  String get alertsSettingHint =>
      'Dim, CO, curenje vode, aktiviran alarm ili zaglavljena brava kao obaveštenje na telefonu, koje prikazuje sam uređaj. Dok aplikacija radi — ili stalno, uz „I kad je aplikacija zatvorena” kod Poruka iz Home Assistanta.';

  @override
  String get alertsPermissionDenied =>
      'Obaveštenja su isključena za ovu aplikaciju u podešavanjima telefona.';

  @override
  String get fanLow => 'Slabo';

  @override
  String get fanMedium => 'Srednje';

  @override
  String get fanMiddle => 'Srednje';

  @override
  String get fanHigh => 'Jako';

  @override
  String get fanTop => 'Najjače';

  @override
  String get fanFocus => 'Usmereno';

  @override
  String get fanDiffuse => 'Raspršeno';

  @override
  String get allCoversOpen => 'Podigni sve';

  @override
  String get allCoversClose => 'Spusti sve';

  @override
  String get widgetNoScenes => 'Još nema scena: napravite ih u aplikaciji';

  @override
  String get widgetSignedOut => 'Prijavite se u Open Smart Home';

  @override
  String get riskVpnTunnel =>
      'Tailscale VPN adresa: veza je šifrovana i radi i van kuće.';

  @override
  String get remoteTitle => 'Adresa van kuće';

  @override
  String get remoteNotSet => 'Nije podešena: koristi se samo kućna adresa';

  @override
  String get remoteInUse => 'Sada se koristi (kućna adresa ne odgovara)';

  @override
  String get remoteHint =>
      'Isti Home Assistant, dostupan spolja: adresa Home Assistant Cloud-a (Nabu Casa), sopstveni domen sa HTTPS-om ili Tailscale adresa. Kod kuće aplikacija koristi kućnu adresu; kada ona ne odgovara, prelazi na ovu. Koristi se isti token.';

  @override
  String get remoteSameAsLocal => 'Ovo je već kućna adresa.';

  @override
  String get remoteNeedsHttps =>
      'Za javnu adresu potreban je HTTPS (ili Tailscale), inače bi token putovao internetom nešifrovan.';

  @override
  String get remoteRemove => 'Ukloni';

  @override
  String get clapSetting => 'Dvostruki pljesak';

  @override
  String get clapSettingHint =>
      'Dva pljeska nešto uključe ili isključe. Samo dok je kiosk na ekranu.';

  @override
  String get clapPrivacyTitle => 'Da aplikacija sluša pljesak?';

  @override
  String get clapPrivacyBody =>
      'Dok je kiosk na ekranu mikrofon je uključen, i Android prikazuje oznaku mikrofona. Aplikacija samo meri koliko je glasno, 50 puta u sekundi, na ovom tabletu: zvuk se ne snima, ne čuva i nigde ne šalje. Isključite ovde kad god želite.';

  @override
  String get clapAllow => 'Uključi';

  @override
  String get clapPermissionDenied =>
      'Mikrofon nije dozvoljen ovoj aplikaciji u podešavanjima sistema.';

  @override
  String get clapTarget => 'Šta radi dvostruki pljesak';

  @override
  String get clapTargetNone => 'Još ništa nije izabrano';

  @override
  String get clapToggle => 'uključi/isključi';

  @override
  String get clapSensitivity => 'Osetljivost';

  @override
  String get clapLow => 'Niska';

  @override
  String get clapMedium => 'Srednja';

  @override
  String get clapHigh => 'Visoka';

  @override
  String clapSwitched(String name, String state) {
    return '$name: $state';
  }

  @override
  String clapDone(String name) {
    return '$name: urađeno';
  }

  @override
  String get clapLockAction =>
      'zaključaj / otključaj (otključavanje uz potvrdu)';

  @override
  String get clapGarageAction => 'otvori (uz potvrdu) / zatvori';

  @override
  String get clapCoverAction => 'otvori / zatvori';

  @override
  String get clapVacuumAction => 'pokreni / vrati na punjač';

  @override
  String get clapMediaAction => 'pusti / pauziraj';

  @override
  String get clapOpenScreen => 'otvara ekran uređaja';

  @override
  String get clapSearch => 'Pretraži uređaje';

  @override
  String get oauthHintNative =>
      'Prijavite se na stranici za prijavu vašeg Home Assistanta korisničkim imenom i lozinkom. Aplikacija dobija samo jednokratni kod i ne čuva lozinku; dugotrajni token nije potreban.';

  @override
  String get oauthPageFailed =>
      'Stranica za prijavu Home Assistanta se nije učitala. Proverite vezu ili se prijavite tokenom ispod. (Sa samopotpisanim sertifikatom radi samo prijava tokenom.)';

  @override
  String get haPushTitle => 'Poruke iz Home Assistanta';

  @override
  String get haPushHint =>
      'Neka HA automatizacije šalju obaveštenja na ovaj uređaj';

  @override
  String get haPushExplain =>
      'Ovaj uređaj se dodaje u Home Assistant (integracija Mobile App). Automatizacije mu tada mogu slati poruke preko notify servisa. Stižu preko lokalne veze dok aplikacija radi, bez ikakvog cloud servisa.';

  @override
  String get haPushName => 'Ime uređaja u Home Assistantu';

  @override
  String get haPushDefaultName => 'Open Smart Home';

  @override
  String get haPushRegister => 'Dodaj u Home Assistant';

  @override
  String haPushReady(String service) {
    return 'Automatizacije šalju poruke servisom $service';
  }

  @override
  String get haPushCopy => 'Kopiraj ime servisa';

  @override
  String get haPushCopied => 'Ime servisa je kopirano.';

  @override
  String get haPushTest => 'Pošalji probnu poruku';

  @override
  String get haPushTestMessage =>
      'Poruke iz Home Assistanta stižu na ovaj uređaj.';

  @override
  String get haPushForget => 'Prestani da primaš poruke';

  @override
  String get haPushForgetHint =>
      'Aplikacija prestaje da sluša poruke. Da biste uređaj potpuno uklonili, obrišite ga u Home Assistantu: Podešavanja → Uređaji i servisi → Mobile App.';

  @override
  String get haPushBackground => 'I kad je aplikacija zatvorena';

  @override
  String get haPushBackgroundHint =>
      'Drži vezu otvorenom u pozadini, i posle restarta telefona. Android tada prikazuje tiho, stalno obaveštenje; troši malo više baterije.';

  @override
  String get haPushServiceTitle => 'Povezano sa Home Assistantom';

  @override
  String get haPushServiceText => 'Čeka poruke vaših automatizacija';

  @override
  String get haPushRemovedInHa =>
      'Ovaj uređaj je obrisan u Home Assistantu (Mobile App). Dodajte ga ponovo da biste primali poruke.';

  @override
  String get kioskPopup => 'Iskačuća kamera';

  @override
  String get kioskPopupHint =>
      'Prikaži kameru kad neko pozvoni ili se pomeri ispred vrata';

  @override
  String kioskPopupSummary(String camera, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count okidača',
      few: '$count okidača',
      one: '1 okidač',
    );
    return '$camera · $_temp0';
  }

  @override
  String get kioskPopupExplain =>
      'Kad se oglasi neki od izabranih uređaja — zvono, pokret, otvaranje vrata ili kapije — kiosk se probudi i prikaže kameru preko celog ekrana.';

  @override
  String get kioskPopupCamera => 'Kamera';

  @override
  String get kioskPopupOff => 'Isključeno';

  @override
  String get kioskPopupDuration => 'Prikazuj';

  @override
  String get kioskPopupTriggers => 'Okidači';

  @override
  String kioskPopupClosesIn(int seconds) {
    return 'zatvara se za $seconds s';
  }

  @override
  String get kioskDarkScreensaver => 'Prigušeno osvetljenje u mirovanju';

  @override
  String get kioskDarkScreensaverHint =>
      'Dok je ekran u mirovanju, osvetljenje je na nivou ispod (noću najviše „Tamnije noću”).';

  @override
  String get kioskNight => 'Tamnije noću';

  @override
  String get kioskNightHint => 'Niža osvetljenost u zadato vreme';

  @override
  String kioskNightRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String kioskNightFrom(String time) {
    return 'Od $time';
  }

  @override
  String kioskNightTo(String time) {
    return 'Do $time';
  }

  @override
  String get kioskNightFromHelp => 'Noć počinje u';

  @override
  String get kioskNightToHelp => 'Noć se završava u';

  @override
  String kioskNightLevel(int percent) {
    return 'Noćna osvetljenost: $percent %';
  }

  @override
  String get dashLayoutTitle => 'Početni ekran';

  @override
  String get dashLayoutSubtitle => 'Izaberite kartice i njihov redosled';

  @override
  String get dashLayoutHint =>
      'Prevucite ili koristite strelicu za redosled; prekidač prikazuje ili skriva karticu. Upozorenja (veza, kritična upozorenja) uvek ostaju na vrhu. Na tabletu su omiljeni i prostorije u desnoj koloni.';

  @override
  String get dashLayoutReset => 'Podrazumevano';

  @override
  String get dashMoveUp => 'Pomeri gore';

  @override
  String get dashCardSummary => 'Pregled (temperatura, svetla, snaga…)';

  @override
  String get dashCardWeather => 'Vreme';

  @override
  String get dashCardMedia => 'Sada svira';

  @override
  String get dashCardNotifications => 'Obaveštenja iz Home Assistanta';

  @override
  String get dashCardShortcuts => 'Energija, kalendar, aktivnost';

  @override
  String get dashCardAttention => 'Potrebna pažnja (baterije, nedostupni)';

  @override
  String get kioskPopupLive => 'Video uživo';

  @override
  String get kioskPopupLiveHint =>
      'Kad kamera nudi stream; dok se ne pokrene, ili ako ne može, prikazuju se snimci.';

  @override
  String get timerSet => 'Tajmer';

  @override
  String get timerTurnOff => 'Isključi';

  @override
  String get timerTurnOn => 'Uključi';

  @override
  String timerHours(int hours) {
    return '$hours h';
  }

  @override
  String get timerHint =>
      'Odbrojava ovaj telefon ili zidni tablet, dok aplikacija radi (ili uz automatizacije u pozadini).';

  @override
  String get timerRunning => 'Tajmer je uključen';

  @override
  String timerTurnsOffAt(String time) {
    return 'Isključuje se u $time';
  }

  @override
  String timerTurnsOnAt(String time) {
    return 'Uključuje se u $time';
  }

  @override
  String get timerNeedsAdmin =>
      'Za tajmer je potreban administratorski nalog u Home Assistantu.';

  @override
  String energyShareOfHome(int percent) {
    return '$percent % doma';
  }

  @override
  String get matterNewTitle => 'Novi Matter uređaj';

  @override
  String get matterNewHint =>
      'Potpuno nov, sa QR kodom na sebi ili kutiji. Google Play services ga podešava preko Bluetooth-a i dodaje na vašu Wi-Fi ili Thread mrežu, a zatim ga preuzima Home Assistant. Držite telefon blizu uređaja.';

  @override
  String get matterNewButton => 'Dodaj novi Matter uređaj';

  @override
  String get matterNoPlayServices =>
      'Novi Matter uređaji se na Androidu dodaju preko Google Play services, koji ovde nisu dostupni (npr. emulator ili telefon bez Google servisa). Koristite zvaničnu Home Assistant aplikaciju ili podelite uređaj iz druge Matter aplikacije ispod.';

  @override
  String get matterNewFailed =>
      'Uređaj nije dodat. Resetujte ga (vidi uputstvo) i pokušajte ponovo blizu telefona. Thread uređajima treba i Thread border router poznat ovom telefonu.';

  @override
  String get matterSharedTitle => 'Uređaj je već u drugoj aplikaciji';

  @override
  String get kioskPanelChooseDevice => 'Izaberi uređaj';

  @override
  String get settingsNotificationsSection => 'Obaveštenja';

  @override
  String get settingsAppearanceHint => 'Tema, jezik, početni ekran';

  @override
  String get settingsServerHint => 'Adresa, adresa van kuće, domovi, odjava';

  @override
  String get settingsKioskHint =>
      'Zidni tablet: raspored, PIN, čuvar ekrana, kamera';

  @override
  String get settingsNotificationsHint =>
      'Poruke iz Home Assistanta, upozorenja';

  @override
  String get settingsSecurityHint =>
      'Zaključavanje aplikacije, režim za decu i goste';

  @override
  String get settingsPrivacyHint => 'Lokacija, glas, brisanje podataka';

  @override
  String get settingsBackupHint =>
      'Sačuvajte dom ili ga prenesite na drugi uređaj';

  @override
  String get loadingContent => 'Učitavanje…';

  @override
  String get houseCheckTitle => 'Provera kuće';

  @override
  String get houseCheckShort => 'Provera';

  @override
  String get houseCheckLeaving => 'Odlazim';

  @override
  String get houseCheckNight => 'Laku noć';

  @override
  String get houseCheckAllGood => 'Sve je u redu';

  @override
  String get houseCheckAllGoodLeaving =>
      'Svetla su ugašena, brave zaključane, ništa nije ostalo otvoreno. Srećan put!';

  @override
  String get houseCheckAllGoodNight => 'Kuća je spremna za noć. Laku noć!';

  @override
  String houseCheckCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stvari za proveru',
      few: '$count stvari za proveru',
      one: '$count stvar za proveru',
    );
    return '$_temp0';
  }

  @override
  String houseCheckFixAll(int count) {
    return 'Sredi sve ($count)';
  }

  @override
  String get houseCheckFixing => 'Sređujem…';

  @override
  String get houseCheckManualHint =>
      'Prozore i vrata sa senzorom aplikacija ne može da zatvori — proverite ih. Alarm se uključuje na njegovom ekranu.';

  @override
  String get houseCheckLightOn => 'Upaljeno';

  @override
  String get houseCheckMediaOn => 'Uključeno';

  @override
  String get houseCheckClimateOn => 'Radi';

  @override
  String get houseCheckUnlocked => 'Otključano';

  @override
  String get houseCheckGarageOpen => 'Otvoreno';

  @override
  String get houseCheckOpened => 'Otvoreno';

  @override
  String get houseCheckAlarmOff => 'Alarm nije uključen';

  @override
  String get houseCheckTurnOff => 'Ugasi';

  @override
  String get houseCheckLock => 'Zaključaj';

  @override
  String get houseCheckClose => 'Zatvori';

  @override
  String get houseCheckPause => 'Pauziraj';

  @override
  String get houseCheckOpenDevice => 'Otvori';

  @override
  String todoOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stavki',
      few: '$count stavke',
      one: '$count stavka',
      zero: 'Sve urađeno',
    );
    return '$_temp0';
  }

  @override
  String get todoTitle => 'Liste';

  @override
  String get todoAddHint => 'Dodaj stavku…';

  @override
  String get todoAdd => 'Dodaj';

  @override
  String todoDone(int count) {
    return 'Urađeno ($count)';
  }

  @override
  String get todoClearDone => 'Obriši urađene';

  @override
  String get todoEmpty => 'Nema stavki. Dodajte prvu.';

  @override
  String get todoNoLists =>
      'U Home Assistantu nema lista. Dodajte integraciju „Spisak za kupovinu” ili „Lokalne liste zadataka”.';

  @override
  String get todoRename => 'Izmeni stavku';

  @override
  String get todoDelete => 'Obriši';

  @override
  String get todoReadOnly => 'Ova lista se ovde samo čita.';

  @override
  String todoDue(String date) {
    return 'Rok: $date';
  }

  @override
  String get todoUnavailable => 'Lista trenutno nije dostupna.';

  @override
  String get dashCardLists => 'Liste';

  @override
  String get energyTwoRate => 'Dvotarifno brojilo';

  @override
  String get energyTwoRateHint =>
      'Niža (noćna) tarifa važi u zadatim satima. Termini se razlikuju po području — proverite ih na računu ili kod distributera.';

  @override
  String get energyLowPrice => 'Cena u nižoj tarifi (po kWh)';

  @override
  String get energyHighPrice => 'Cena u višoj tarifi (po kWh)';

  @override
  String get energyLowFrom => 'Od';

  @override
  String get energyLowTo => 'Do';

  @override
  String get energyLowPresetBelgrade => 'Beograd 00–08';

  @override
  String get energyLowPresetVojvodina => 'Vojvodina 23–07';

  @override
  String get energyLowPresetCentral => 'Centralna Srbija 22–06';

  @override
  String get energyHighRateKwh => 'Viša tarifa';

  @override
  String get energyLowRateKwh => 'Niža tarifa';

  @override
  String energyLowShare(int percent) {
    return '$percent % potrošnje';
  }

  @override
  String energyLowNow(String time) {
    return 'Sada je niža tarifa, do $time';
  }

  @override
  String energyHighNow(String time) {
    return 'Sada je viša tarifa — niža počinje u $time';
  }

  @override
  String get energyLowLegend => 'Sati niže tarife';

  @override
  String get boardTitle => 'Tabla';

  @override
  String get boardNewPage => 'Nova strana';

  @override
  String get boardEmpty =>
      'Još nema strana. Napravite prvu i pišite ili crtajte prstom ili olovkom.';

  @override
  String get boardStorageNote =>
      'Strane se čuvaju na vašem Home Assistantu kao slike (image_upload), pa ih vide svi vaši uređaji. Home Assistant takve slike pokazuje bez prijave svakome u mreži ko zna njihov dugačak nasumičan link.';

  @override
  String get boardPen => 'Olovka';

  @override
  String get boardEraser => 'Gumica';

  @override
  String get boardUndo => 'Poništi';

  @override
  String get boardRedo => 'Vrati';

  @override
  String get boardClear => 'Očisti stranu';

  @override
  String get boardClearConfirm => 'Obrisati sve sa ove strane?';

  @override
  String get boardDeletePage => 'Obriši stranu';

  @override
  String get boardDeleteConfirm => 'Obrisati ovu stranu sa Home Assistanta?';

  @override
  String get boardDeleteNeedsAdmin =>
      'Brisanje slika u Home Assistantu traži administratorski nalog.';

  @override
  String get boardSaving => 'Čuvam…';

  @override
  String get boardSaved => 'Sačuvano';

  @override
  String get boardSaveFailed => 'Nije sačuvano — pokušaću ponovo.';

  @override
  String get boardChangedElsewhere => 'Strana je izmenjena na drugom uređaju.';

  @override
  String get boardReload => 'Učitaj';

  @override
  String boardColor(int n) {
    return 'Boja $n';
  }

  @override
  String boardWidth(int n) {
    return 'Debljina $n';
  }

  @override
  String get boardZoomHint => 'Dva prsta: uvećanje i pomeranje';

  @override
  String get boardUnavailable =>
      'Tabla nije dostupna. Proverite vezu sa Home Assistantom.';

  @override
  String boardPageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count strana',
      few: '$count strane',
      one: '$count strana',
      zero: 'Prazna — napišite ili nacrtajte nešto',
    );
    return '$_temp0';
  }

  @override
  String get deviceSensorBattery => 'Baterija';

  @override
  String get deviceSensorBatteryState => 'Stanje baterije';

  @override
  String get deviceSensorCharging => 'Punjenje';

  @override
  String get deviceSensorKiosk => 'Kiosk';

  @override
  String get deviceSensorsSwitch => 'Šalji stanje baterije u Home Assistant';

  @override
  String get deviceSensorsHint =>
      'Procenat baterije, punjenje i da li je kiosk uključen postaju senzori ovog uređaja u vašem HA. Ništa drugo se ne šalje.';

  @override
  String get smartChargeTitle => 'Pametno punjenje';

  @override
  String smartChargeHint(int low, int high) {
    return 'Utičnica punjača se pali na $low %, a gasi na $high % — baterija zidnog tableta duže traje.';
  }

  @override
  String get smartChargeWaiting =>
      'Čekam da se senzor baterije pojavi u Home Assistantu…';

  @override
  String get smartChargePlug => 'Utičnica ili prekidač punjača';

  @override
  String get smartChargeCreate => 'Napravi automatizaciju';

  @override
  String smartChargeDone(String name) {
    return 'Automatizacija „$name” je napravljena u Home Assistantu.';
  }

  @override
  String get smartChargeNeedsAdmin =>
      'Pravljenje automatizacija traži administratorski nalog.';

  @override
  String smartChargeAlias(String device) {
    return 'Pametno punjenje – $device';
  }

  @override
  String get nfcTitle => 'NFC nalepnice';

  @override
  String get nfcHint =>
      'Prislonite telefon na nalepnicu i Home Assistant pokreće ono što ste izabrali — npr. scenu „Odlazak” kod ulaznih vrata. Nalepnice su u istom formatu kao kod zvanične HA aplikacije.';

  @override
  String get nfcSectionHint => 'Scena na dodir telefona';

  @override
  String get nfcOff => 'NFC je isključen u podešavanjima telefona.';

  @override
  String get nfcMissing =>
      'Ovaj uređaj nema NFC. Postojeće nalepnice i dalje rade sa drugih telefona.';

  @override
  String get nfcNeedsRegistration =>
      'Za očitavanje dodajte ovaj uređaj u Home Assistant (Obaveštenja → Poruke iz Home Assistanta).';

  @override
  String get nfcNew => 'Nova nalepnica';

  @override
  String get nfcName => 'Ime nalepnice';

  @override
  String get nfcRuns => 'Kad se očita, pokreni';

  @override
  String get nfcWrite => 'Upiši nalepnicu';

  @override
  String get nfcHold => 'Prislonite nalepnicu uz poleđinu telefona…';

  @override
  String nfcWritten(String name) {
    return 'Nalepnica „$name” je spremna.';
  }

  @override
  String get nfcWrittenNoAdmin =>
      'Nalepnica je upisana, ali dodavanje u Home Assistant (i automatizacija) traži administratorski nalog. Očitavanja ipak stižu u HA.';

  @override
  String get nfcErrorReadOnly =>
      'Nalepnica je zaključana i ne može da se upiše.';

  @override
  String get nfcErrorTooSmall => 'Na nalepnicu ne staje adresa.';

  @override
  String get nfcErrorUnsupported => 'Ova vrsta nalepnice nije podržana.';

  @override
  String get nfcErrorFailed =>
      'Upis nije uspeo — držite nalepnicu mirno uz telefon i pokušajte ponovo.';

  @override
  String nfcScanned(String name) {
    return 'Nalepnica „$name” očitana';
  }

  @override
  String nfcScanFailed(String reason) {
    return 'Nalepnica nije prosleđena Home Assistantu: $reason';
  }

  @override
  String get nfcEmpty => 'U Home Assistantu još nema nalepnica.';

  @override
  String nfcLastScanned(String when) {
    return 'Poslednji put: $when';
  }

  @override
  String get nfcNeverScanned => 'Još nije očitana';

  @override
  String get nfcScannedUnnamed => 'Nalepnica očitana';

  @override
  String homeSayTime(String time) {
    return 'Sada je $time.';
  }

  @override
  String homeSayWeather(String condition, String temperature) {
    return 'Napolju je $condition, $temperature.';
  }

  @override
  String homeSayLights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Upaljeno je $count svetala',
      few: 'Upaljena su $count svetla',
      one: 'Upaljeno je $count svetlo',
    );
    return '$_temp0';
  }

  @override
  String get homeSayLightsOff => 'Sva svetla su ugašena';

  @override
  String homeSayOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'a $count prozora ili vrata je otvoreno.',
      few: 'a $count prozora ili vrata su otvorena.',
      one: 'a $count prozor ili vrata su otvoreni.',
    );
    return '$_temp0';
  }

  @override
  String get homeSayClosed => 'a sve je zatvoreno.';

  @override
  String homeSayUnlocked(String names) {
    return 'Otključano: $names.';
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
      other: 'Pažnja: $count upozorenja.',
      few: 'Pažnja: $count upozorenja.',
      one: 'Pažnja: $count upozorenje.',
    );
    return '$_temp0';
  }

  @override
  String get mediaShuffle => 'Nasumično';

  @override
  String get mediaRepeat => 'Ponavljanje';

  @override
  String get mediaRepeatOff => 'Bez ponavljanja';

  @override
  String get mediaRepeatAll => 'Ponovi sve';

  @override
  String get mediaRepeatOne => 'Ponovi jednu';

  @override
  String get mediaSeek => 'Pozicija';

  @override
  String get quickTilesTitle => 'Brzi prekidači';

  @override
  String get quickTilesHint =>
      'Tri prekidača u meniju koji se spušta odozgo (Android): jedan dodir pali ili gasi uređaj ili pokreće scenu, bez otvaranja aplikacije. Radi tek kad je telefon otključan; brave, garaža i alarm nisu ponuđeni.';

  @override
  String quickTileSlot(int n) {
    return 'Prekidač $n';
  }

  @override
  String get quickTileUnset => 'Nije podešeno';

  @override
  String quickTileChoose(int n) {
    return 'Šta radi prekidač $n';
  }

  @override
  String get quickTileClear => 'Ukloni';

  @override
  String get quickTileAdd => 'Dodaj u meni';

  @override
  String get quickTileAdded => 'Prekidač je u meniju brzih podešavanja.';

  @override
  String quickTileAddManually(int n) {
    return 'Prevucite meni nadole, dodirnite olovku i prevucite „Pametna kuća $n” među prekidače.';
  }

  @override
  String get aodTitle => 'Ekran u mirovanju (AOD)';

  @override
  String get aodHint =>
      'Kad se kiosk ne koristi: crni ekran sa satom, prognozom i jednom stvari po izboru. Sadržaj se polako pomera da se ekran ne „ureže”.';

  @override
  String get aodFocus => 'Ispod sata';

  @override
  String get aodFocusNone => 'Ništa';

  @override
  String get aodFocusNextEvent => 'Sledeća obaveza';

  @override
  String get aodFocusList => 'Lista';

  @override
  String get aodFocusDevice => 'Uređaj';

  @override
  String get aodFocusEnergy => 'Trenutna potrošnja';

  @override
  String get aodFocusMedia => 'Šta svira';

  @override
  String get aodFocusHome => 'Rečenica o kući';

  @override
  String get aodChoose => 'Izaberi';

  @override
  String get aodNextEvent => 'Sledeće';

  @override
  String get aodNoEvents => 'Nema obaveza u narednih 7 dana';

  @override
  String get aodToday => 'danas';

  @override
  String get aodTomorrow => 'sutra';

  @override
  String get morningScreen => 'Jutarnji ekran';

  @override
  String get morningScreenHint =>
      'Ujutru ekran u mirovanju pokazuje današnju prognozu, obaveze i podsetnike (stavke sa rokom danas).';

  @override
  String get morningFrom => 'Od';

  @override
  String get morningTo => 'Do';

  @override
  String get morningToday => 'Danas';

  @override
  String get morningReminders => 'Podsetnici';

  @override
  String get morningNothing => 'Danas nema obaveza ni podsetnika.';

  @override
  String morningHighLow(String high, String low) {
    return 'najviše $high, najniže $low';
  }

  @override
  String aodNowUntil(String time) {
    return 'sada, do $time';
  }

  @override
  String get aodBrightness => 'Osvetljenost u mirovanju';

  @override
  String get settingsAssistSection => 'Assist (glas)';

  @override
  String get settingsAssistHint => 'Izgovoreni odgovori, asistent telefona';

  @override
  String get assistSpeak => 'Izgovaraj odgovore';

  @override
  String get assistSpeakHint =>
      'Kad pitate glasom, odgovor se i izgovori (sintetizator govora na uređaju, ništa se ne šalje).';

  @override
  String get assistDefault => 'Asistent telefona';

  @override
  String get assistDefaultHint =>
      'Izaberite Open Smart Home za „digitalnog asistenta”: dugi pritisak na Home ili dugme za napajanje otvara Assist koji odmah sluša.';

  @override
  String get wakeWordSetting => 'Ključna reč (bez ruku)';

  @override
  String get wakeWordSettingHint =>
      'Izgovorite ključnu reč podešenu u Home Assistantu (na primer „Okay Nabu”), pa komandu. Samo dok je kiosk na ekranu.';

  @override
  String get wakeWordPrivacyTitle => 'Slušati ključnu reč?';

  @override
  String get wakeWordPrivacyBody =>
      'Dok je kiosk na ekranu mikrofon je stalno uključen (Android prikazuje oznaku mikrofona), a zvuk se neprekidno šalje Vašem Home Assistant serveru, istom vezom kao i sve ostalo, da bi njegov prepoznavač ključne reči (openWakeWord) čuo ključnu reč. Na ovom tabletu se ništa ne snima niti čuva. Šta Home Assistant radi sa komandom posle ključne reči zavisi od njegovih Assist podešavanja: lokalno prepoznavanje (na primer Whisper) ostaje kod kuće, Home Assistant Cloud je šalje na internet.';

  @override
  String get wakeWordAllow => 'Uključi';

  @override
  String get wakeWordActive => 'Sluša se ključna reč';

  @override
  String get wakeWordMissing =>
      'Home Assistant nema prepoznavač ključne reči. Instalirajte dodatak openWakeWord (Wyoming integracija ga sama pronalazi), pa ponovo uključite ovu opciju.';

  @override
  String get wakeWordNeedsServer => 'Potrebna je veza sa Home Assistantom.';

  @override
  String get approachWake => 'Probudi ekran kad neko priđe';

  @override
  String get approachWakeHint => 'Samo dok je ekran kioska u mirovanju.';

  @override
  String get approachOff => 'Isključeno';

  @override
  String get approachSensor => 'Senzor pokreta (Home Assistant)';

  @override
  String get approachCamera => 'Kamera tableta';

  @override
  String get approachSensorPick => 'Senzor';

  @override
  String get approachNoSensors =>
      'Home Assistant nema senzore pokreta ili prisustva.';

  @override
  String get approachCameraTitle => 'Koristiti kameru tableta?';

  @override
  String get approachCameraBody =>
      'Dok je ekran u mirovanju, prednja kamera nekoliko puta u sekundi proverava da li se nešto pomera ispred tableta, a Android prikazuje oznaku kamere. Slike se obrađuju samo na ovom tabletu i odmah odbacuju: ništa se ne snima, ne čuva i nigde ne šalje — ni Home Assistantu. Dok je ekran budan, kamera je isključena.';

  @override
  String get approachCameraAllow => 'Uključi';

  @override
  String get approachCameraDenied =>
      'Kamera nije dozvoljena za ovu aplikaciju u sistemskim podešavanjima.';

  @override
  String get presenceTitle => 'Simulacija prisustva';

  @override
  String get presenceHint =>
      'Svetla se uveče sama pale i gase dok niko nije kod kuće';

  @override
  String get presenceIntro =>
      'Dok je uključena, uveče se na svakih 15 minuta (uz nasumično čekanje do 10 minuta) upali ili ugasi jedno od izabranih svetala, a u vreme kraja ugase se sva. Telefon ili tablet koji je pokreće mora da ostane kod kuće i da radi.';

  @override
  String get presenceOn => 'Simulacija uključena';

  @override
  String get presenceNotSaved => 'Još nije sačuvana u Home Assistantu.';

  @override
  String get presenceLights => 'Svetla';

  @override
  String get presenceNoLights => 'U domu nema svetala.';

  @override
  String get presenceWhen => 'Kada';

  @override
  String get presenceWhenAway => 'Kad niko nije kod kuće';

  @override
  String get presenceWhenAwayHint =>
      'Prema osobama u Home Assistantu (zona Dom).';

  @override
  String get presenceWhenAlarm => 'Kad je alarm uključen (odsutni)';

  @override
  String get presenceWhenAlways => 'Uvek dok je uključena';

  @override
  String get presenceFromSunset => 'Od zalaska sunca';

  @override
  String get presenceStart => 'Početak';

  @override
  String get presenceEnd => 'Kraj (sva izabrana svetla se gase)';

  @override
  String get presenceSave => 'Sačuvaj';

  @override
  String get presenceSaved => 'Simulacija prisustva je sačuvana.';

  @override
  String get presenceRemove => 'Ukloni';

  @override
  String get presenceRemoved => 'Simulacija prisustva je uklonjena.';

  @override
  String get presenceNeedsAdmin =>
      'Za ovo je potreban administratorski nalog u Home Assistantu.';

  @override
  String lowTariffAlias(String device) {
    return 'Niža tarifa: podsetnik ($device)';
  }

  @override
  String get lowTariffTitle => 'Počela je niža tarifa';

  @override
  String lowTariffMessage(String until, String price) {
    return 'Struja je jeftinija do $until ($price/kWh): dobro vreme za veš-mašinu, sudove ili punjenje.';
  }

  @override
  String get lowTariffRemind => 'Podseti me kad počne niža tarifa';

  @override
  String get lowTariffRemindOn => 'Podsetnik za nižu tarifu je uključen';

  @override
  String lowTariffDialogBody(String time) {
    return 'Kad počne niža tarifa ($time), Home Assistant šalje poruku na ovaj telefon, a kad prođe, poruka se sama skloni. Radi kao automatizacija u Home Assistantu (za čuvanje je potreban administratorski nalog), a poruka stiže dok je aplikacija povezana, kao i sve poruke iz Home Assistanta.';
  }

  @override
  String get lowTariffCreate => 'Uključi podsetnik';

  @override
  String get lowTariffRemove => 'Ukloni podsetnik';

  @override
  String get lowTariffCreated => 'Podsetnik za nižu tarifu je uključen.';

  @override
  String get lowTariffRemoved => 'Podsetnik za nižu tarifu je uklonjen.';

  @override
  String get lowTariffNeedsPush =>
      'Prvo uključite „Poruke iz Home Assistanta” (Podešavanja › Obaveštenja).';

  @override
  String get kioskAlertAck => 'Video sam';

  @override
  String get kioskAlertShow => 'Prikaži uređaj';

  @override
  String kioskAlertOpenFor(int minutes) {
    return 'Otvoreno već $minutes min';
  }

  @override
  String kioskAlertMore(int count) {
    return 'još $count';
  }

  @override
  String kioskAlertSpeech(String name, String status) {
    return 'Upozorenje! $name: $status.';
  }

  @override
  String get kioskAlertSetting => 'Upozorenja preko celog ekrana';

  @override
  String get kioskAlertSettingHint =>
      'Dim, ugljen-monoksid, curenje vode, aktiviran alarm ili zaglavljena brava prekrivaju ceo ekran i izgovore se, dok neko ne potvrdi.';

  @override
  String get kioskOpenAlert => 'Vrata ili prozor otvoreni duže od';

  @override
  String get kioskOpenAlertNever => 'Nikad';

  @override
  String kioskOpenAlertMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get timerTitle => 'Tajmer';

  @override
  String get timerNew => 'Novi tajmer';

  @override
  String get timerStart => 'Pokreni';

  @override
  String get timerStop => 'Isključi';

  @override
  String get timerCancel => 'Otkaži tajmer';

  @override
  String get timerAddMinute => '+1 min';

  @override
  String timerDone(String label) {
    return 'Tajmer $label je istekao';
  }

  @override
  String timerDoneSpeech(String label) {
    return 'Tajmer od $label je istekao.';
  }

  @override
  String timerStarted(String label) {
    return 'Tajmer od $label je pokrenut.';
  }

  @override
  String kioskNightLightHint(String name) {
    return 'Dodir: $name na 10 %';
  }

  @override
  String kioskNightLightOn(String name) {
    return '$name je upaljeno · dodirnite ponovo za ekran';
  }

  @override
  String get kioskNightClock => 'Crveni noćni sat';

  @override
  String get kioskNightClockHint =>
      'Noću ekran u mirovanju prikazuje samo vreme, prigušeno crveno.';

  @override
  String get kioskNightLight => 'Noćno svetlo na dodir';

  @override
  String get kioskNightLightNone => 'Nijedno (dodir budi ekran)';

  @override
  String get kioskLeaving => 'Izlazim';

  @override
  String get kioskLeavingAllGood => 'Sve je ugašeno i zatvoreno. Prijatan dan!';

  @override
  String get kioskLeavingManual =>
      'Prozore i vrata bez kvačice treba zatvoriti ručno.';

  @override
  String kioskLeavingGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ugasi $count stvari',
      few: 'Ugasi $count stvari',
      one: 'Ugasi $count stvar',
      zero: 'Nema šta da se ugasi',
    );
    return '$_temp0';
  }

  @override
  String kioskLeavingGoArm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ugasi $count i uključi alarm',
      few: 'Ugasi $count i uključi alarm',
      one: 'Ugasi $count i uključi alarm',
      zero: 'Uključi alarm',
    );
    return '$_temp0';
  }

  @override
  String get kioskLeavingBye => 'Doviđenja!';

  @override
  String get photoFrame => 'Foto-okvir';

  @override
  String get photoFrameHint =>
      'U mirovanju prikazuj slike sa ovog tableta (ostaju na njemu).';

  @override
  String photoFrameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slika · ostaju na ovom tabletu',
      few: '$count slike · ostaju na ovom tabletu',
      one: '$count slika · ostaje na ovom tabletu',
    );
    return '$_temp0';
  }

  @override
  String get photoFrameAdd => 'Dodaj slike';

  @override
  String get photoFrameRemove => 'Ukloni sve';

  @override
  String photoFrameEverySeconds(int seconds) {
    return 'na $seconds s';
  }

  @override
  String photoFrameEveryMinutes(int minutes) {
    return 'na $minutes min';
  }

  @override
  String get familyMessages => 'Poruke';

  @override
  String get familyMessagesNone => 'Nema poruka. Ostavite poruku ukućanima.';

  @override
  String get familyMessageNew => 'Nova poruka';

  @override
  String get familyMessageEveryone => 'Svi';

  @override
  String familyMessageFor(String name) {
    return 'Poruka za: $name';
  }

  @override
  String get familyMessageForAll => 'Poruka za sve';

  @override
  String get familyMessageRead => 'Pročitano';

  @override
  String get familyMessageHint => 'Na primer: u frižideru je supa';

  @override
  String get familyMessageSend => 'Ostavi poruku';

  @override
  String welcomeHome(String name) {
    return 'Dobro došli kući, $name!';
  }

  @override
  String get greetPeople => 'Pozdravi ukućane kad dođu';

  @override
  String get greetPeopleHint =>
      'Kad neko stigne (po osobi u Home Assistantu), tablet ga pozdravi i pokaže poruke za njega.';

  @override
  String get kioskIntercom => 'Interfon';

  @override
  String get kioskIntercomOpen => 'Dugme „Otvori”';

  @override
  String get kioskIntercomSpeaker => 'Zvučnik kod vrata (dugme „Dolazim”)';

  @override
  String get kioskIntercomSpeakerHint =>
      'Home Assistant tamo izgovori odgovor svojim pretvaranjem teksta u govor.';

  @override
  String get kioskIntercomReply => 'Dolazim!';

  @override
  String get kioskIntercomReplyText => 'Dolazim, samo trenutak!';

  @override
  String get kioskIntercomReplied =>
      'Izgovoreno kod vrata: „Dolazim, samo trenutak!”';

  @override
  String get kioskIntercomNoTts =>
      'Home Assistant nema podešeno pretvaranje teksta u govor.';

  @override
  String kioskIntercomUnlock(String name) {
    return 'Otključaj: $name';
  }

  @override
  String kioskIntercomOpenDevice(String name) {
    return 'Otvori: $name';
  }

  @override
  String get kioskColumnsNoRooms =>
      'Još nema prostorija. Dodajte oblasti u Home Assistantu.';

  @override
  String get kioskColumnsDevices => 'Uređaji';

  @override
  String get kioskOpenDevice => 'Otvori uređaj';

  @override
  String get kioskBundleMain => 'Glavno';

  @override
  String get kioskBundleActions => 'Radnje';

  @override
  String get kioskBundleSettings => 'Podešavanja';

  @override
  String get kioskBundleState => 'Stanje';

  @override
  String kioskBundleCount(int count) {
    return '$count kontrola';
  }

  @override
  String get kioskQuickControls => 'Brze kontrole';

  @override
  String get kioskQuickControlsAdd => 'Dodaj';

  @override
  String get kioskQuickControlsEdit => 'Izmeni';

  @override
  String get kioskQuickControlsHint =>
      'Izaberite uređaje koje želite da imate pri ruci — svetla, fritezu, scenu…';

  @override
  String get kioskHomeCards => 'Kartice na Početnoj';

  @override
  String get applianceDoneAction => 'Javi kad završi';

  @override
  String get applianceDoneHint =>
      'Aplikacija prati snagu: kad uređaj radi (iznad praga) pa se umiri, ovaj telefon ili tablet javi da je gotovo. Radi na ovom telefonu ili zidnom tabletu dok aplikacija radi (ili uz automatizacije u pozadini).';

  @override
  String get applianceDoneName => 'Naziv (npr. Veš mašina)';

  @override
  String get applianceDoneThreshold => 'Radi iznad';

  @override
  String get applianceDoneQuiet => 'Gotovo posle mirovanja od';

  @override
  String applianceDoneMinutesValue(int minutes) {
    return '$minutes min';
  }

  @override
  String applianceDoneNow(String watts) {
    return 'Sada troši $watts W.';
  }

  @override
  String get applianceDoneThisPhone => 'Poruka na ovaj telefon';

  @override
  String get applianceDoneNeedsPush =>
      'Prvo uključite poruke iz Home Assistanta u podešavanjima.';

  @override
  String get applianceDoneHousehold => 'Poruka svim ukućanima';

  @override
  String get applianceDoneHouseholdHint =>
      'Vide je svi u aplikaciji i na zidnom tabletu.';

  @override
  String applianceDoneOtherPhones(int count) {
    return 'Javlja i na još $count telefon(a).';
  }

  @override
  String get applianceDoneRemove => 'Ukloni';

  @override
  String get applianceDoneRemoved => 'Javljanje je uklonjeno.';

  @override
  String applianceDoneSaved(String name) {
    return 'Javiće se kad „$name” završi.';
  }

  @override
  String get applianceDoneNeedsAdmin =>
      'Za ovo je potreban administratorski nalog u Home Assistantu.';

  @override
  String get applianceDoneOn => 'Javlja kad završi';

  @override
  String get applianceDoneOnHint => 'Prati ovaj telefon';

  @override
  String get applianceDoneChange => 'Promeni';

  @override
  String get applianceDoneTitle => 'Gotovo';

  @override
  String applianceDoneMessage(String name) {
    return '$name: ciklus je završen.';
  }

  @override
  String applianceDoneAlias(String name) {
    return 'Gotovo: $name (Open Smart Home)';
  }

  @override
  String get heatingScheduleAction => 'Nedeljni raspored';

  @override
  String get heatingScheduleTitle => 'Nedeljni raspored';

  @override
  String get heatingScheduleHint =>
      'Od svakog vremena važi ta temperatura, do sledećeg. Raspored se čuva kao automatizacije doma. Radi na ovom telefonu ili zidnom tabletu dok aplikacija radi (ili uz automatizacije u pozadini). Ručna promena važi do sledećeg vremena.';

  @override
  String get heatingScheduleWorkdays => 'Radni dani (pon–pet)';

  @override
  String get heatingScheduleWeekend => 'Vikend (sub–ned)';

  @override
  String get heatingScheduleAdd => 'Dodaj vreme';

  @override
  String get heatingScheduleColder => 'Hladnije';

  @override
  String get heatingScheduleWarmer => 'Toplije';

  @override
  String get heatingScheduleRemove => 'Ukloni raspored';

  @override
  String get heatingScheduleRemoved => 'Raspored je uklonjen.';

  @override
  String get heatingScheduleSaved => 'Raspored je sačuvan.';

  @override
  String heatingScheduleNext(String time, String temperature) {
    return 'Sledeće: $time → $temperature';
  }

  @override
  String heatingScheduleAlias(String name) {
    return 'Raspored: $name (Open Smart Home)';
  }

  @override
  String get mediaMute => 'Isključi zvuk';

  @override
  String get mediaUnmute => 'Uključi zvuk';

  @override
  String get mediaVolumeUp => 'Pojačaj';

  @override
  String get mediaVolumeDown => 'Utišaj';

  @override
  String get mediaSoundMode => 'Zvučni režim';

  @override
  String get tvRemote => 'Daljinski';

  @override
  String get tvUp => 'Gore';

  @override
  String get tvDown => 'Dole';

  @override
  String get tvLeft => 'Levo';

  @override
  String get tvRight => 'Desno';

  @override
  String get tvOk => 'OK';

  @override
  String get tvBack => 'Nazad';

  @override
  String get tvHome => 'Početni ekran';

  @override
  String get tvMenu => 'Meni';

  @override
  String get tvPlayPause => 'Pusti / pauziraj';

  @override
  String get tvVolume => 'Zvuk';

  @override
  String get tvChannel => 'Kanal';

  @override
  String get tvChannelUp => 'Sledeći kanal';

  @override
  String get tvChannelDown => 'Prethodni kanal';

  @override
  String get roomPhoto => 'Fotografija sobe';

  @override
  String get roomPhotoChange => 'Izaberi drugu fotografiju';

  @override
  String get roomPhotoRemove => 'Ukloni fotografiju';

  @override
  String get roomPhotoHint =>
      'Fotografija, ikonica i boja ostaju samo na ovom uređaju; ne šalju se u Home Assistant. Za zidni tablet izaberite ih na samom tabletu.';

  @override
  String get themeAutoDark => 'Tamno posle zalaska sunca';

  @override
  String get themeAutoDarkHint =>
      'Prati izlazak i zalazak sunca iz Home Assistanta (bez njega: tamno od 20 do 7).';

  @override
  String get accentTitle => 'Boja aplikacije';

  @override
  String get accentTerracotta => 'Terakota';

  @override
  String get accentBlue => 'Plava';

  @override
  String get accentGreen => 'Zelena';

  @override
  String get accentPurple => 'Ljubičasta';

  @override
  String get accentRose => 'Roze';

  @override
  String get accentTeal => 'Tirkizna';

  @override
  String get onNowTitle => 'Sada uključeno';

  @override
  String onNowLights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count svetala',
      few: '$count svetla',
      one: '1 svetlo',
    );
    return '$_temp0';
  }

  @override
  String get onNowLightsOff => 'Sva svetla su ugašena.';

  @override
  String onNowTurnedOff(String name) {
    return 'Ugašeno: $name';
  }

  @override
  String get onNowHint => 'Dodir otvara, dugi pritisak gasi';

  @override
  String get roomLook => 'Izgled sobe';

  @override
  String get roomPhotoChoose => 'Izaberi fotografiju';

  @override
  String get roomIconTitle => 'Ikonica';

  @override
  String get roomColorTitle => 'Boja';

  @override
  String get roomLookReset => 'Kao u Home Assistantu';

  @override
  String get favoritesBrowse => 'Pogledaj uređaje';

  @override
  String get bigSliderPosition => 'Položaj';

  @override
  String get bigSliderHint => 'Dugi pritisak: veliki klizač';

  @override
  String get deviceSheetMore => 'Svi detalji';

  @override
  String get serviceSection => 'Servis';

  @override
  String get serviceSectionHint =>
      'Dijagnostika, podrška i alati za instalatera';

  @override
  String serviceSupport(String brand) {
    return 'Podrška: $brand';
  }

  @override
  String get serviceApp => 'Aplikacija';

  @override
  String get serviceDevice => 'Uređaj';

  @override
  String get serviceServer => 'Server';

  @override
  String get serviceConnected => 'povezano';

  @override
  String get serviceDisconnected => 'nije povezano';

  @override
  String get serviceDevices => 'Uređaji';

  @override
  String serviceDevicesValue(int count, int unavailable) {
    return '$count uređaja, nedostupno: $unavailable';
  }

  @override
  String get servicePanel => 'Zidni panel';

  @override
  String get servicePanelManaged =>
      'Upravljan (vlasnik uređaja): kiosk se ne može napustiti, pokreće se posle restarta';

  @override
  String get servicePanelNot =>
      'Običan uređaj (bez instalaterskog upravljanja)';

  @override
  String get servicePanelApply => 'Primeni pravila panela';

  @override
  String get servicePanelApplied =>
      'Ekran ostaje upaljen na struji; aplikacija je početni ekran.';

  @override
  String get servicePanelFailed =>
      'Nije uspelo: aplikacija nije vlasnik uređaja.';

  @override
  String get servicePanelRelease => 'Vrati uređaj';

  @override
  String get servicePanelReleaseBody =>
      'Uklanja instalatersko upravljanje: kiosk se može napustiti, vraća se običan početni ekran. Ponovo uključivanje traži novu pripremu uređaja (fabričko resetovanje).';

  @override
  String get serviceProblems => 'Nedavni problemi';

  @override
  String get serviceNoProblems => 'Nema zabeleženih problema od pokretanja.';

  @override
  String get serviceCopy => 'Kopiraj dijagnostiku';

  @override
  String get serviceCopied => 'Dijagnostika je kopirana.';

  @override
  String get serviceCopyHint =>
      'Bez tokena i lozinki: samo verzije, uređaj, adresa servera (bez porta i putanje) i poslednje greške.';

  @override
  String get setupTitle => 'Čarobnjak za instalaciju';

  @override
  String setupIntro(String brand) {
    return 'Proverite i podesite sve za ovaj uređaj, korak po korak. ($brand)';
  }

  @override
  String get setupConnection => 'Veza sa Home Assistantom';

  @override
  String setupConnectionOk(String host, String version) {
    return 'Povezano sa $host (Home Assistant $version)';
  }

  @override
  String get setupConnectionMissing =>
      'Nije povezano — proverite adresu i mrežu u Podešavanja → Server.';

  @override
  String get setupRooms => 'Prostorije';

  @override
  String setupRoomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prostorija',
      few: '$count prostorije',
      one: '1 prostorija',
      zero: 'Nema prostorija',
    );
    return '$_temp0';
  }

  @override
  String setupNoRoom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uređaja bez prostorije',
      few: '$count uređaja bez prostorije',
      one: '1 uređaj bez prostorije',
      zero: 'Svi uređaji imaju prostoriju',
    );
    return '$_temp0';
  }

  @override
  String get setupRoomsHint =>
      'Prostorije i raspored uređaja se uređuju u Home Assistantu (Podešavanja → Oblasti).';

  @override
  String get setupMessages => 'Poruke iz Home Assistanta';

  @override
  String setupMessagesOk(String name) {
    return 'Registrovano kao „$name”';
  }

  @override
  String get setupMessagesHint =>
      'Registruje uređaj u Home Assistantu (Mobile App), da mu automatizacije šalju poruke.';

  @override
  String get setupDeviceName => 'Ime uređaja u Home Assistantu';

  @override
  String get setupDefaultDeviceName => 'Zidni tablet';

  @override
  String get setupRegister => 'Registruj';

  @override
  String get setupKiosk => 'Kiosk i PIN';

  @override
  String get setupPinHint => 'PIN za izlaz iz kioska još nije postavljen';

  @override
  String get setupPinSaved => 'PIN je sačuvan.';

  @override
  String get setupPanel => 'Zidni panel';

  @override
  String get setupPanelHint =>
      'Za panel koji se ne može napustiti i sam se pokreće posle nestanka struje, uređaj se priprema kao „vlasnik uređaja” pre prijave Google naloga — vidi uputstvo za instalatere (docs/INSTALLER.md).';

  @override
  String get setupDone => 'Gotovo';

  @override
  String get setupNext => 'Dalje';

  @override
  String get setupBack => 'Nazad';

  @override
  String get haBackupTitle => 'U Home Assistantu';

  @override
  String get haBackupHint =>
      'Podešavanja aplikacije (izgled, kiosk, kartice, brze kontrole, sobe) čuvaju se u vašem Home Assistantu pod imenom uređaja, pa se posle reinstalacije ili na drugom tabletu vraćaju jednim dodirom. Ne čuvaju se tokeni, PIN, fotografije ni izbori za mikrofon i kameru.';

  @override
  String get haBackupName => 'Ime kopije (uređaj)';

  @override
  String get haBackupSave => 'Sačuvaj';

  @override
  String haBackupSavedHome(String name) {
    return 'Sačuvano kao „$name” — vidljivo na svim uređajima u kući.';
  }

  @override
  String haBackupSavedUser(String name) {
    return 'Sačuvano kao „$name” za vaš nalog (za celu kuću je potreban administrator).';
  }

  @override
  String get haBackupNone => 'Još nema sačuvanih kopija.';

  @override
  String get haBackupScopeHome => 'za celu kuću';

  @override
  String get haBackupScopeUser => 'samo vaš nalog';

  @override
  String get haBackupRestore => 'Vrati';

  @override
  String haBackupRestoreTitle(String name) {
    return 'Vratiti „$name”?';
  }

  @override
  String get haBackupRestoreBody =>
      'Podešavanja ovog uređaja biće zamenjena sačuvanim. PIN, fotografije i izbori za mikrofon i kameru ostaju kakvi su.';

  @override
  String get haBackupDelete => 'Obriši kopiju';

  @override
  String get haBackupUnavailable =>
      'Kopije iz Home Assistanta trenutno nisu dostupne (nema veze).';

  @override
  String get backupFileTitle => 'Kao tekst';

  @override
  String get updateTitle => 'Ažuriranje aplikacije';

  @override
  String updateCurrent(String version) {
    return 'Verzija $version';
  }

  @override
  String get updateChecking => 'Proveravam…';

  @override
  String updateUpToDate(String version) {
    return 'Imate najnoviju verziju ($version).';
  }

  @override
  String get updateNoReleases =>
      'Nema objavljenih izdanja (ili izvor izdanja nije javan).';

  @override
  String updateAvailable(String version) {
    return 'Dostupna je nova verzija $version';
  }

  @override
  String updateDownloading(int percent) {
    return 'Preuzimam… $percent %';
  }

  @override
  String get updateInstalling =>
      'Instaliram — Android može da traži potvrdu; aplikacija se zatim ponovo pokreće.';

  @override
  String get updateNeedsPermission =>
      'Dozvolite „Instaliranje nepoznatih aplikacija” za ovu aplikaciju, pa dodirnite Instaliraj ponovo.';

  @override
  String get updateFailed =>
      'Provera ili preuzimanje nije uspelo (nema interneta?).';

  @override
  String get updateRejected =>
      'Preuzeta datoteka se ne poklapa sa objavljenim otiskom (SHA-256) — nije instalirana.';

  @override
  String get updateInstall => 'Instaliraj';

  @override
  String get updateCheck => 'Proveri sada';

  @override
  String get updateAuto => 'Proveravaj nova izdanja pri pokretanju';

  @override
  String get updateAutoHint =>
      'Pita GitHub (javna izdanja) da li postoji nova verzija; GitHub tada vidi adresu uređaja. Ništa drugo se ne šalje.';

  @override
  String get nfcLinkConfirmTitle => 'Pokrenuti oznaku?';

  @override
  String nfcLinkConfirm(String name) {
    return 'Link za oznaku „$name” nije došao sa NFC oznake prislonjene uz telefon, već iz QR koda, sa veba ili iz druge aplikacije. Pokrenuti je u Home Assistantu?';
  }

  @override
  String get nfcLinkConfirmUnnamed =>
      'Link za Home Assistant oznaku nije došao sa NFC oznake prislonjene uz telefon, već iz QR koda, sa veba ili iz druge aplikacije. Pokrenuti je?';

  @override
  String get nfcLinkRun => 'Pokreni';

  @override
  String get firstRunSkip => 'Preskoči';

  @override
  String get firstRunWelcomeTitle => 'Dobro došli kući!';

  @override
  String firstRunWelcomeBody(String host) {
    return 'Povezani ste sa $host. Podesimo aplikaciju — traje minut, a sve se kasnije može promeniti u Podešavanjima.';
  }

  @override
  String get firstRunRoleQuestion => 'Kako ćete koristiti ovaj uređaj?';

  @override
  String get firstRunRolePhone => 'Moj telefon ili tablet';

  @override
  String get firstRunRolePhoneHint => 'Lično, nosim ga sa sobom';

  @override
  String get firstRunRoleWall => 'Zidni tablet za celu kuću';

  @override
  String get firstRunRoleWallHint =>
      'Stoji na zidu, koriste ga svi ukućani (kiosk sa PIN-om)';

  @override
  String get firstRunWallNext => 'Podesi zidni panel';

  @override
  String get firstRunRestoreTitle => 'Preuzmite postojeća podešavanja';

  @override
  String get firstRunRestoreBody =>
      'U vašem Home Assistantu su sačuvana podešavanja sa drugih uređaja. Ako je ovo zamena ili još jedan isti uređaj, vratite jedno jednim dodirom — ili samo nastavite.';

  @override
  String get firstRunLookTitle => 'Izgled';

  @override
  String get firstRunLookBody =>
      'Izaberite svetlu ili tamnu temu i boju koja vam se dopada.';

  @override
  String get firstRunFavoritesTitle => 'Omiljeni uređaji';

  @override
  String get firstRunFavoritesBody =>
      'Dodirnite ono što najčešće koristite — biće na vrhu Početne.';

  @override
  String get firstRunFavoritesNone =>
      'U Home Assistantu još nema uređaja kojima se upravlja.';

  @override
  String firstRunFavoritesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Izabrano $count uređaja',
      few: 'Izabrana $count uređaja',
      one: 'Izabran 1 uređaj',
      zero: 'Ništa nije izabrano',
    );
    return '$_temp0';
  }

  @override
  String get firstRunMessagesTitle => 'Poruke na telefon';

  @override
  String get firstRunMessagesBody =>
      'Home Assistant može da javi ovom telefonu kad se nešto desi, npr. da su vrata ostala otvorena. Poruke idu direktno iz vaše kuće, bez clouda.';

  @override
  String get firstRunSecurityTitle => 'Zaštita';

  @override
  String get firstRunSecurityBody =>
      'Ko ima vaš otključan telefon, može da upravlja kućom. Preporučujemo bar potvrdu za brave i alarm.';

  @override
  String get firstRunDoneTitle => 'Sve je spremno';

  @override
  String get firstRunDoneBody =>
      'Prostorije, scene i uređaji stižu iz Home Assistanta. Sve što ste ovde izabrali menjate u Podešavanjima, a kartice Početne dugmetom ⚙ pored pozdrava.';

  @override
  String get firstRunStart => 'Počnimo';

  @override
  String kioskGreetingName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String kioskPersonButton(String name) {
    return '$name koristi tablet';
  }

  @override
  String kioskPersonEnterPin(String name) {
    return 'PIN — $name';
  }

  @override
  String get kioskCriticalPinHint => 'Vaš lični PIN ili PIN tableta';

  @override
  String kioskQuickControlsFor(String name) {
    return 'Brze kontrole — $name';
  }

  @override
  String get kioskQuickControlsShared => 'Koristi zajedničke';

  @override
  String get kioskPeopleTitle => 'Ukućani na tabletu';

  @override
  String get kioskPeopleHint =>
      'Na tabletu ukućanin dodirne svoju sliku i dobija svoj pozdrav i svoje brze kontrole. Otključavanje vrata, isključenje alarma i slične radnje dozvoljene su samo uz lični PIN ukućanina ili PIN tableta — ko nema PIN (npr. deca), ne može. Ukućani su osobe iz Home Assistanta.';

  @override
  String get kioskPersonPinSet => 'Lični PIN postavljen — sme da otključava';

  @override
  String get kioskPersonNoPin => 'Bez ličnog PIN-a';

  @override
  String kioskPersonSetPin(String name) {
    return 'Lični PIN — $name';
  }

  @override
  String get kioskPersonNoPinLocked =>
      'Bez ličnog PIN-a — ne može da otključava';

  @override
  String get extrasTitle => 'Još';

  @override
  String get extrasShort => 'Još';

  @override
  String get batteriesTitle => 'Baterije';

  @override
  String get batteriesNone => 'Nijedan uređaj ne javlja bateriju.';

  @override
  String batteriesSummary(int count, int low) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uređaja na baterije',
      few: '$count uređaja na baterije',
      one: '1 uređaj na bateriju',
    );
    String _temp1 = intl.Intl.pluralLogic(
      low,
      locale: localeName,
      other: '$low pri kraju',
      few: '$low pri kraju',
      one: '1 pri kraju',
      zero: 'sve u redu',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get batteryReminder => 'Javi kad je baterija pri kraju';

  @override
  String batteryReminderHint(int percent) {
    return 'Ovaj telefon ili tablet javi obaveštenjem kad baterija nekog uređaja padne na $percent % ili niže (dok aplikacija radi, ili uz automatizacije u pozadini).';
  }

  @override
  String get batteryReminderAlias => 'Baterija pri kraju (Open Smart Home)';

  @override
  String batteryReminderMessage(String name, String percent) {
    return 'Baterija je pri kraju: $name ($percent %)';
  }

  @override
  String get batteryLowShort => 'Slaba baterija';

  @override
  String get batteryOk => 'Baterija u redu';

  @override
  String get unlockLogPanel => 'Zidni tablet';

  @override
  String get unlockLogPhone => 'Telefon';

  @override
  String get unlockLogViaPanel => 'zidni tablet';

  @override
  String get unlockLogViaPhone => 'telefon';

  @override
  String unlockLogUnlock(String device, String via) {
    return 'otključava: $device ($via)';
  }

  @override
  String unlockLogDisarm(String device, String via) {
    return 'isključuje alarm: $device ($via)';
  }

  @override
  String unlockLogOpen(String device, String via) {
    return 'otvara: $device ($via)';
  }

  @override
  String get vacationTitle => 'Na odmoru';

  @override
  String get vacationHint =>
      'Jednim dodirom spremite kuću dok ste odsutni. Po povratku se grejanje i simulacija vraćaju kako su bili.';

  @override
  String get vacationTidy => 'Sredi kuću';

  @override
  String get vacationTidyHint =>
      'Ugasi svetla i muziku, spusti šta treba — kao „Izlazim”';

  @override
  String vacationHeating(String temperature) {
    return 'Grejanje na $temperature °C';
  }

  @override
  String vacationHeatingHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count termostata',
      few: '$count termostata',
      one: '1 termostat',
    );
    return '$_temp0; stare temperature se pamte';
  }

  @override
  String get vacationSimulation => 'Simulacija prisustva';

  @override
  String get vacationSimulationHint => 'Svetla se uveče sama pale i gase';

  @override
  String get vacationSimulationMissing => 'Još nije podešena';

  @override
  String get vacationSimulationSetUp => 'Podesi';

  @override
  String get vacationAlarm => 'Uključi alarm (odsutni)';

  @override
  String get vacationStart => 'Krećemo na odmor';

  @override
  String get vacationLocalNote =>
      'Šta treba vratiti pamti ovaj uređaj — povratak označite na njemu.';

  @override
  String get vacationActive => 'Na odmoru ste';

  @override
  String vacationActiveSince(String date) {
    return 'Od $date';
  }

  @override
  String get vacationEndHint =>
      'Kad se vratite: grejanje na stare temperature, simulacija kako je bila.';

  @override
  String get vacationAlarmStillOn =>
      'Alarm je i dalje uključen — isključite ga tastaturom ili kodom.';

  @override
  String get vacationEnd => 'Vratili smo se';

  @override
  String get comingHomeTitle => 'Stižem kući';

  @override
  String get comingHomeHint =>
      'Jednim dodirom (i sa ikonice aplikacije): upali šta treba, ugrej kuću i javi ukućanima.';

  @override
  String get comingHomeWho => 'Ko stiže';

  @override
  String get comingHomeNoOne => 'Bez imena';

  @override
  String get comingHomeRoutine => 'Scena ili skripta';

  @override
  String get comingHomeNone => 'Ništa';

  @override
  String get comingHomeHeatingOff => 'Grejanje: ne menjaj';

  @override
  String comingHomeHeating(String temperature) {
    return 'Grejanje na $temperature °C';
  }

  @override
  String get comingHomeAnnounce => 'Javi ukućanima';

  @override
  String get comingHomeAnnounceHint =>
      'Poruka se vidi u aplikaciji i na zidnom tabletu';

  @override
  String get comingHomeRun => 'Stižem kući';

  @override
  String get comingHomeShortcutHint =>
      'Isto radi i dugi pritisak na ikonicu aplikacije → „Stižem kući”.';

  @override
  String get comingHomeDone => 'Kuća zna da stižete.';

  @override
  String comingHomeMessage(String name) {
    return '$name stiže kući 🏠';
  }

  @override
  String get comingHomeMessageNoName => 'Neko stiže kući 🏠';

  @override
  String get guestWifiTitle => 'Wi-Fi za goste';

  @override
  String get guestWifiNotSet =>
      'Još nije podešen. Upišite mrežu za goste, pa je gosti dobijaju skeniranjem koda — bez diktiranja šifre.';

  @override
  String get guestWifiScan => 'Skenirajte kamerom telefona';

  @override
  String get guestWifiSetUp => 'Podesi';

  @override
  String get guestWifiChange => 'Promeni';

  @override
  String get guestWifiWarning =>
      'Upišite samo mrežu za goste: kod i šifru vidi svako ko otvori ovaj ekran. Šifra se čuva u zaštićenom skladištu uređaja i ne napušta ga.';

  @override
  String get guestWifiSsid => 'Ime mreže (SSID)';

  @override
  String get guestWifiPassword => 'Šifra';

  @override
  String get guestWifiPasswordHint => 'Najmanje 8 znakova';

  @override
  String get guestWifiOpen => 'Mreža bez šifre';

  @override
  String get guestWifiHidden => 'Skrivena mreža';

  @override
  String get guestWifiRemove => 'Ukloni';

  @override
  String airAdviceTitle(String place) {
    return 'Provetrite: $place';
  }

  @override
  String airAdviceCo2(int ppm) {
    return 'CO2 $ppm ppm — vazduh je zagušljiv, otvorite prozor na par minuta';
  }

  @override
  String airAdviceHumidity(int percent) {
    return 'Vlažnost $percent % — provetrite da se ne uhvati buđ';
  }

  @override
  String get partyTitle => 'Žurka';

  @override
  String get partyHint =>
      'Svetla u boji menjaju boje u krug dok je žurka uključena. Posle se sva vraćaju kako su bila.';

  @override
  String get partyNoLights =>
      'Nema svetala u boji — žurka treba bar jedno RGB svetlo.';

  @override
  String get partyMusic => 'Muzika';

  @override
  String get partyNoMusic => 'Bez muzike';

  @override
  String get partyStart => 'Počni žurku';

  @override
  String get partyOn => 'Žurka! 🎉';

  @override
  String partyLights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count svetala pleše',
      few: '$count svetla plešu',
      one: '1 svetlo pleše',
    );
    return '$_temp0';
  }

  @override
  String get partyStop => 'Kraj žurke';

  @override
  String get sunriseTitle => 'Buđenje svetlom';

  @override
  String get sunriseHint =>
      'Svetlo se pali polako pre buđenja, od tople prigušene svetlosti do dnevne, kao pravo svitanje. Radi na ovom telefonu ili zidnom tabletu dok aplikacija radi (ili uz automatizacije u pozadini).';

  @override
  String get sunriseWakeAt => 'Potpuno svetlo u';

  @override
  String sunriseMinutes(int minutes) {
    return 'Svitanje traje $minutes min';
  }

  @override
  String get sunriseLights => 'Svetla';

  @override
  String get sunriseSave => 'Uključi buđenje';

  @override
  String get sunriseUpdate => 'Sačuvaj izmene';

  @override
  String get sunriseRemove => 'Isključi buđenje';

  @override
  String sunriseSaved(String time) {
    return 'Buđenje svetlom: svetlo do $time.';
  }

  @override
  String get sunriseRemoved => 'Buđenje svetlom je isključeno.';

  @override
  String get sunriseAlias => 'Buđenje svetlom (Open Smart Home)';

  @override
  String get wrappedTitle => 'Ova nedelja';

  @override
  String get wrappedIntro => 'Vaša nedelja u kući';

  @override
  String get wrappedIntroCaption =>
      'Poslednjih 7 dana, iz dnevnika Home Assistanta. Dodirnite desno za dalje.';

  @override
  String get wrappedDoors => 'Vrata i prozori otvoreni';

  @override
  String wrappedTopDoor(String name) {
    return 'Najprometnije: $name';
  }

  @override
  String get wrappedLights => 'Puta je upaljeno svetlo';

  @override
  String wrappedTopLight(String name, int count) {
    return 'Najomiljenije: $name ($count×)';
  }

  @override
  String get wrappedArrivals => 'Dolazaka kući';

  @override
  String wrappedTopArrival(String name, int count) {
    return 'Najčešće: $name ($count×)';
  }

  @override
  String get wrappedUnlocks => 'Otključavanja';

  @override
  String get wrappedBusiestDay => 'Najživlji dan u kući';

  @override
  String get wrappedEnergy => 'kWh struje ove nedelje';

  @override
  String get wrappedEnergyUnit => 'od ponedeljka do sada';

  @override
  String wrappedEnergyLastWeek(String kwh) {
    return 'od ponedeljka do sada · prošle nedelje $kwh kWh';
  }

  @override
  String get wrappedOutro => 'Dobra nedelja!';

  @override
  String get wrappedOutroCaption => 'Vidimo se sledeće nedelje 👋';

  @override
  String get wrappedEmpty =>
      'Dnevnik Home Assistanta za ovu nedelju je prazan — još nema šta da se prebroji.';

  @override
  String get wrappedUnavailable =>
      'Dnevnik Home Assistanta trenutno nije dostupan.';

  @override
  String birthdayGreeting(String names) {
    return 'Srećan rođendan, $names!';
  }

  @override
  String get birthdayPick => 'Rođendan (dan i mesec)';

  @override
  String get seasonalSetting => 'Sezonski ukrasi';

  @override
  String get seasonalSettingHint =>
      'Sneg od decembra do Božića, konfete za Novu godinu i rođendane ukućana, bundeve pred Noć veštica. Staje kad je ekran zatamnjen.';

  @override
  String get bedtimeTitle => 'Priča za laku noć';

  @override
  String get bedtimeHint =>
      'Tablet ili telefon pročita kratku priču, a svetla u izabranoj sobi se za to vreme polako gase.';

  @override
  String get bedtimeLights => 'Svetla koja se gase';

  @override
  String get bedtimeNoLights => 'Bez svetala';

  @override
  String get bedtimeAloud => 'Čitaj naglas';

  @override
  String bedtimeMinutes(int minutes) {
    return 'oko $minutes min';
  }

  @override
  String get bedtimeNext => 'Dalje';

  @override
  String get bedtimeEnd => 'Kraj';

  @override
  String get bedtimeGoodNight => 'Laku noć. 🌙';

  @override
  String get themeOled => 'Potpuno crna tamna tema';

  @override
  String get themeOledHint =>
      'Za AMOLED ekrane: crni pikseli se gase — manje troši bateriju i ne svetli u mraku.';

  @override
  String get paletteHint => 'Soba, uređaj ili scena…';

  @override
  String get paletteEmpty => 'Kucajte deo imena — npr. „kuh” za kuhinju.';

  @override
  String get paletteNothing => 'Ništa se ne poklapa.';

  @override
  String get paletteRoom => 'Prostorija';

  @override
  String get paletteKeys =>
      'Enter: pokreni ili uključi/isključi · ↑↓ izbor · Esc zatvori';

  @override
  String get paletteTooltip => 'Pretraga (Ctrl+K)';

  @override
  String get simpleTitle => 'Jednostavni režim';

  @override
  String get simpleHint =>
      'Samo nekoliko velikih dugmadi i krupan tekst, bez menija — npr. na tabletu kod bake i deke.';

  @override
  String simpleChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dugmadi',
      few: '$count dugmeta',
      one: '1 dugme',
    );
    return '$_temp0';
  }

  @override
  String get simpleChoose => 'Izaberi';

  @override
  String simpleChooseTitle(int max) {
    return 'Dugmad (najviše $max)';
  }

  @override
  String get simpleStartMode => 'Pokreni jednostavni režim';

  @override
  String get simpleEmpty =>
      'Još nema dugmadi. Izađite (katanac gore desno) i izaberite ih u Podešavanjima.';

  @override
  String get simpleOn => 'Uključeno';

  @override
  String get simpleOff => 'Isključeno';

  @override
  String get simpleStart => 'Pokreni';

  @override
  String get simpleLeave => 'Izađi iz jednostavnog režima';

  @override
  String get simpleLeaveTitle => 'Izaći iz jednostavnog režima?';

  @override
  String get simpleLeaveBody => 'Vratiće se cela aplikacija sa svim menijima.';

  @override
  String get floorPlanTitle => 'Tlocrt';

  @override
  String get floorPlanEmpty =>
      'Učitajte sliku osnove stana ili kuće (crtež ili fotografija plana), pa na nju postavite uređaje. Dodir na uređaj na planu ga pali i gasi.';

  @override
  String get floorPlanPick => 'Izaberi sliku plana';

  @override
  String get floorPlanEdit => 'Uredi';

  @override
  String get floorPlanAdd => 'Dodaj uređaj';

  @override
  String get floorPlanChangePhoto => 'Druga slika';

  @override
  String get floorPlanEditHint => 'Prevucite uređaje na njihova mesta.';

  @override
  String get floorPlanUnsupported =>
      'Tlocrt se čuva na uređaju, pa u web verziji nije dostupan.';

  @override
  String get widgetHomeTitle => 'Kuća';

  @override
  String get widgetLightsOff => '💡 Sva svetla ugašena';

  @override
  String widgetLightsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '💡 Upaljeno $count svetala',
      few: '💡 Upaljena $count svetla',
      one: '💡 Upaljeno 1 svetlo',
    );
    return '$_temp0';
  }

  @override
  String get widgetAllClosed => '🚪 Sve zatvoreno';

  @override
  String widgetOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🚪 Otvoreno: $count',
      one: '🚪 Otvoreno: 1',
    );
    return '$_temp0';
  }

  @override
  String get widgetLocked => '🔒 Zaključano';

  @override
  String widgetUnlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔓 Otključano: $count',
      one: '🔓 Otključano: 1',
    );
    return '$_temp0';
  }

  @override
  String widgetUpdated(String time) {
    return 'Ažurirano u $time';
  }

  @override
  String widgetNow(String temperature) {
    return 'Sada $temperature';
  }

  @override
  String get widgetSettingsTitle => 'Widgeti na početnom ekranu';

  @override
  String get widgetSettingsHint =>
      '„Kuća”, „Termostat” i „Svetlo” dodajete dugim pritiskom na početni ekran telefona → Widgeti. Osvežavaju se dok aplikacija radi.';

  @override
  String get widgetThermostat => 'Termostat na widgetu';

  @override
  String get widgetLight => 'Svetlo na widgetu';

  @override
  String get nowPlayingSetting => 'Muzika u obaveštenju';

  @override
  String get nowPlayingSettingHint =>
      'Dok neki zvučnik u kući svira, u obaveštenjima su naslov i dugmad pauza i sledeća — bez otvaranja aplikacije. Radi dok aplikacija radi (i u pozadini, ako je uključena veza u pozadini).';

  @override
  String get nowPlayingPause => 'Pauza';

  @override
  String get nowPlayingPlay => 'Pusti';

  @override
  String get nowPlayingNext => 'Sledeća';

  @override
  String get nowPlayingChannel => 'Sada svira';

  @override
  String get simpleWarmer => 'Toplije';

  @override
  String get simpleCooler => 'Hladnije';

  @override
  String get serviceLicenses => 'Licence otvorenog koda';

  @override
  String get serviceLicensesHint => 'Aplikacija i svi paketi koje koristi';

  @override
  String get settingsHomeSection => 'Dom';

  @override
  String get settingsHomeHint => 'Uređaji i sobe';

  @override
  String get demoHomeNotice =>
      'Ovo je demo dom. Dodajte svoje uređaje (Shelly, WLED, Tasmota, ESPHome, Hue, Yeelight, Kasa) i demo će se sam ugasiti.';

  @override
  String get firstRunWelcomeBodyLite =>
      'Telefon sam upravlja vašim uređajima, bez servera. Podesimo aplikaciju — traje minut, a sve se kasnije može promeniti u Podešavanjima.';

  @override
  String get settingsAboutSection => 'O aplikaciji';

  @override
  String get settingsAboutHint => 'Verzija i ažuriranja';

  @override
  String get addDeviceLanHint =>
      'Shelly, WLED, ESPHome, Hue, Yeelight i Kasa uređaji na istoj Wi-Fi mreži kao telefon pojavljuju se ovde sami. Tasmota uređaje dodajte preko IP adrese.';

  @override
  String get addDeviceSearching => 'Tražim uređaje…';

  @override
  String get addDeviceNoneYet =>
      'Još ništa. Proverite da je telefon na istoj Wi-Fi mreži kao uređaj, ili unesite njegovu IP adresu.';

  @override
  String get addDeviceManual => 'Unesi IP adresu';

  @override
  String get addDeviceAddressLabel => 'IP adresa uređaja';

  @override
  String get addDeviceChecking => 'Proveravam…';

  @override
  String get addDeviceNotFound =>
      'Na toj adresi nije pronađen nijedan podržan uređaj.';

  @override
  String get addDeviceAdded => 'Dodat';

  @override
  String get addDeviceAdd => 'Dodaj';

  @override
  String addDeviceDone(String name) {
    return '$name je dodat.';
  }

  @override
  String get addDeviceWhere => 'U koju sobu?';

  @override
  String get roomNew => 'Nova soba…';

  @override
  String get roomNameLabel => 'Ime sobe';

  @override
  String get roomDelete => 'Obriši sobu';

  @override
  String roomDeleteConfirm(String name) {
    return 'Obrisati sobu $name? Uređaji ostaju, bez sobe.';
  }

  @override
  String get deviceRemove => 'Ukloni uređaj';

  @override
  String deviceRemoveConfirm(String name) {
    return 'Ukloniti $name iz aplikacije? Uređaj nastavlja da radi.';
  }

  @override
  String get demoDevicesSetting => 'Demo uređaji';

  @override
  String get demoDevicesHint => 'Izmišljeni dom za probu aplikacije.';

  @override
  String get homeDevicesTitle => 'Uređaji';

  @override
  String get devicePasswordLabel => 'Lozinka uređaja';

  @override
  String get devicePasswordHint =>
      'Ovaj uređaj traži lozinku (korisnik admin). Čuva se samo na ovom telefonu, u bezbednom skladištu.';

  @override
  String get devicePasswordChange => 'Lozinka uređaja…';

  @override
  String get deviceKeyLabel => 'Ključ za šifrovanje';

  @override
  String get deviceKeyHint =>
      'Ovaj ESPHome uređaj šifruje vezu. Unesite ključ iz njegovog YAML-a (api → encryption → key). Čuva se samo na ovom telefonu, u bezbednom skladištu.';

  @override
  String get deviceKeyWrong =>
      'Ključ nije dobar. Proverite ga u YAML-u uređaja.';

  @override
  String get deviceKeyNotEncrypted =>
      'Ovaj uređaj ne šifruje vezu; ostavite ključ prazan.';

  @override
  String get hueLinkTitle => 'Uparivanje sa Hue mostom';

  @override
  String get hueLinkBody =>
      'Pritisnite okruglo dugme na vrhu Hue mosta. Aplikacija čeka 30 sekundi.';

  @override
  String get hueLinkFailed =>
      'Dugme na mostu nije pritisnuto. Pokušajte ponovo.';

  @override
  String get sceneHintLocal =>
      'Čuva kako su izabrani uređaji podešeni sada (uključeno/isključeno, jačina, boja, roletne, temperatura). Pokretanje scene ih vraća tako.';

  @override
  String get sceneSavedLocal => 'Scena je sačuvana.';

  @override
  String get autoSavedLocal => 'Automatizacija je sačuvana.';

  @override
  String get autoHintLocal =>
      'Radi na ovom telefonu: dok je aplikacija otvorena, na zidnom tabletu u kiosku, ili kad je uključen rad u pozadini (Podešavanja → Dom).';

  @override
  String get autoSunNeedsHome =>
      'Za izlazak i zalazak sunca potrebna je lokacija doma: uključite prognozu za dom (Podešavanja → Privatnost).';

  @override
  String get autoActionTurnOn => 'Uključi';

  @override
  String get autoActionTurnOff => 'Isključi';

  @override
  String get autoActionToggle => 'Promeni (uključi/isključi)';

  @override
  String autoActionBrightness(int percent) {
    return 'Jačina $percent %';
  }

  @override
  String get autoActionScene => 'Pokreni scenu';

  @override
  String get autoPickAction => 'Šta da uradi';

  @override
  String autoTriggerAt(String time) {
    return 'U $time';
  }

  @override
  String get autoDays => 'Dani';

  @override
  String autoStateIs(String device, String state) {
    return '$device: $state';
  }

  @override
  String autoValueAbove(String device, String value) {
    return '$device iznad $value';
  }

  @override
  String autoValueBelow(String device, String value) {
    return '$device ispod $value';
  }

  @override
  String get autoTargetOn => 'uključen';

  @override
  String get autoTargetOff => 'isključen';

  @override
  String get autoTargetOpen => 'otvoren';

  @override
  String get autoTargetClosed => 'zatvoren';

  @override
  String get autoTargetActive => 'aktivan';

  @override
  String get autoTargetInactive => 'neaktivan';

  @override
  String get autoTargetLocked => 'zaključan';

  @override
  String get autoTargetUnlocked => 'otključan';

  @override
  String get autoBefore => 'pre';

  @override
  String get autoAfter => 'posle';

  @override
  String get backgroundAutomations => 'Automatizacije u pozadini';

  @override
  String get backgroundAutomationsHint =>
      'Aplikacija nastavlja da radi i kad je zatvorite, da bi automatizacije radile. Android tada prikazuje stalno obaveštenje.';

  @override
  String get backgroundNotificationText => 'Automatizacije rade';

  @override
  String get sceneEdit => 'Izmeni scenu';

  @override
  String get bleNearbyTitle => 'Bluetooth senzori u blizini';

  @override
  String get bleNearbyHint =>
      'Termometri i senzori vrata, pokreta i curenja koji šalju svoje vrednosti preko Bluetootha (BTHome, Shelly BLU, Xiaomi sa pvvx/ATC firmverom, SwitchBot Meter, Govee). Telefon samo sluša, ne povezuje se.';

  @override
  String get blePermission => 'Dozvoli Bluetooth';

  @override
  String get blePermissionHint =>
      'Za Bluetooth senzore aplikaciji treba dozvola za uređaje u blizini.';

  @override
  String get bleOff =>
      'Bluetooth je isključen. Uključite ga da bi se senzori pojavili.';

  @override
  String get bleNoneYet =>
      'Još ništa. Senzori se javljaju na nekoliko sekundi do minuta.';

  @override
  String get bleUnsupported => 'Ovaj uređaj nema Bluetooth.';

  @override
  String get backupWithSecrets => 'Sa lozinkama i ključevima uređaja';

  @override
  String get backupWithSecretsHint =>
      'Šifruju se lozinkom koju izaberete; bez nje ih niko ne može pročitati.';

  @override
  String get backupPassword => 'Lozinka za rezervnu kopiju';

  @override
  String get backupPasswordShort => 'Najmanje 6 znakova.';

  @override
  String get backupSaveFile => 'Sačuvaj u fajl';

  @override
  String get backupOpenFile => 'Učitaj iz fajla';

  @override
  String get backupSend => 'Pošalji na drugi uređaj';

  @override
  String get backupReceive => 'Primi sa drugog uređaja';

  @override
  String get backupSendTitle =>
      'Na drugom uređaju izaberite „Primi sa drugog uređaja“ i unesite:';

  @override
  String get backupAddress => 'Adresa';

  @override
  String get backupCode => 'Kod';

  @override
  String get backupSendWaiting =>
      'Čeka se drugi uređaj (najviše 5 minuta). Oba moraju biti na istoj Wi-Fi mreži.';

  @override
  String get backupSent => 'Poslato.';

  @override
  String get backupUnreachable =>
      'Drugi uređaj se ne javlja. Proverite adresu i da su oba na istoj Wi-Fi mreži.';

  @override
  String get backupWrongCode => 'Kod nije dobar.';

  @override
  String get backupNoWifi => 'Ovaj uređaj nije na Wi-Fi mreži.';

  @override
  String get backupHowTitle => 'Kako da uvezem?';

  @override
  String get backupReplace => 'Zameni sve';

  @override
  String get backupReplaceHint =>
      'Uređaji, sobe, scene i automatizacije ovde zamenjuju se onima iz kopije.';

  @override
  String get backupMerge => 'Dodaj samo novo';

  @override
  String get backupMergeHint =>
      'Sve što je ovde ostaje; dodaje se ono čega nema.';

  @override
  String get backupAskPassword =>
      'Ova kopija ima lozinke i ključeve uređaja. Unesite lozinku kojom je napravljena.';

  @override
  String get backupWrongPassword => 'Lozinka nije dobra.';

  @override
  String linkTitle(String brand) {
    return 'Uparivanje: $brand';
  }

  @override
  String get linkFailed => 'Uparivanje nije uspelo. Pokušajte ponovo.';

  @override
  String get nanoleafLinkBody =>
      'Držite dugme za uključivanje na Nanoleafu 5–7 sekundi, dok svetla ne počnu da trepću. Aplikacija čeka 30 sekundi.';

  @override
  String get tvLinkBody =>
      'Na televizoru se pojavilo pitanje da li aplikacija sme da se poveže: izaberite Dozvoli. Aplikacija čeka 30 sekundi.';

  @override
  String get dirigeraLinkBody =>
      'Pritisnite dugme za radnju na poleđini DIRIGERA čvorišta. Aplikacija čeka 30 sekundi.';

  @override
  String get tpLinkAccountHint =>
      'Tapo uređaj proverava TP-Link nalog na samom uređaju: unesite e-poštu i lozinku naloga u koji je dodat. Ništa se ne šalje TP-Linku.';

  @override
  String get tpLinkUserLabel => 'E-pošta TP-Link naloga';

  @override
  String get tpLinkWrongAccount => 'Uređaj ne prihvata ovu e-poštu i lozinku.';
}

/// The translations for Serbian, using the Latin script (`sr_Latn`).
class AppLocalizationsSrLatn extends AppLocalizationsSr {
  AppLocalizationsSrLatn() : super('sr_Latn');
}
