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
  String get languageSystem => 'Sistemski';

  @override
  String get languageSerbian => 'Srpski';

  @override
  String get languageEnglish => 'English';

  @override
  String get back => 'Nazad';

  @override
  String get cancel => 'Otkaži';

  @override
  String get connect => 'Poveži se';

  @override
  String get connecting => 'Povezivanje…';

  @override
  String get failureNetwork =>
      'Uređaj nije dostupan. Proverite da li je uključen i da li je telefon na istoj Wi-Fi mreži.';

  @override
  String get failureTimeout => 'Uređaj predugo ne odgovara.';

  @override
  String get failureAuthentication =>
      'Uređaj je odbio lozinku, ključ ili token. Proverite ih u Podešavanja → Dom.';

  @override
  String get failureAuthorization =>
      'Ovaj korisnik nema dozvolu za ovu radnju.';

  @override
  String get failureValidation => 'Uređaj nije prihvatio komandu.';

  @override
  String get failureParsing => 'Uređaj je poslao neočekivan odgovor.';

  @override
  String get failureServer => 'Uređaj je prijavio grešku.';

  @override
  String get failureCertificate =>
      'Uređaj se predstavio drugim sertifikatom nego pri uparivanju. Možda se neko drugi javlja umesto njega; ako ste uređaj resetovali, uklonite ga i dodajte ponovo.';

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
  String get deleteAllData => 'Obriši sve lokalne podatke';

  @override
  String get deleteAllConfirmTitle => 'Obrisati sve lokalne podatke?';

  @override
  String get deleteAllConfirmBody =>
      'Sa ovog telefona biće uklonjeni dom, lozinke i ključevi uređaja i sva podešavanja. Sami uređaji se ne menjaju.';

  @override
  String get delete => 'Obriši';

  @override
  String get privacySection => 'Privatnost i podaci';

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
  String get noRoomsYet => 'Još nema soba. Dodajte ih u Podešavanja → Dom.';

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
  String get infoEntityId => 'ID uređaja';

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
  String get energyConsumption => 'Potrošnja doma';

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
  String get powerToggle => 'Uključi/isključi';

  @override
  String get personHome => 'Kod kuće';

  @override
  String get personAway => 'Nije kod kuće';

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
      'Za dom još nema prognoze. Uključite je u Podešavanja → Privatnost.';

  @override
  String get weatherFeelsHint => 'Prognoza MET Norway za lokaciju doma.';

  @override
  String get mediaPlayPause => 'Pusti ili pauziraj';

  @override
  String get mediaNext => 'Sledeća';

  @override
  String get mediaPrevious => 'Prethodna';

  @override
  String get addDeviceTitle => 'Dodaj uređaj';

  @override
  String get setUpDeviceTitle => 'Ime i prostorija';

  @override
  String get deviceNameLabel => 'Ime';

  @override
  String get deviceRoomLabel => 'Prostorija';

  @override
  String get setUpSaved => 'Sačuvano.';

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
  String get mediaTitle => 'Muzika i mediji';

  @override
  String get mediaNoPlayers =>
      'Još nema zvučnika ni televizora. Dodajte Sonos, Roku, Samsung ili LG televizor preko „Dodaj uređaj“ i pojaviće se ovde.';

  @override
  String get mediaSource => 'Izvor';

  @override
  String get mediaIdle => 'Ništa ne svira';

  @override
  String get mediaNoPlayersShort => 'Još nema media plejera';

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
      'Skriva osetljive uređaje i zaključava podešavanja PIN-om na ovom uređaju.';

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
  String get autoDelete => 'Obriši automatizaciju';

  @override
  String autoDeleteConfirm(String name) {
    return 'Obrisati „$name”? Ovo se ne može poništiti.';
  }

  @override
  String get autoIncomplete => 'Izaberite kada se pokreće i bar jednu radnju.';

  @override
  String get autoNameHint => 'Na primer: Svetlo u hodniku noću';

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
  String get sceneName => 'Ime scene';

  @override
  String get sceneDevices => 'Uređaji';

  @override
  String get sceneSave => 'Sačuvaj scenu';

  @override
  String get sceneNeedDevice => 'Izaberite bar jedan uređaj.';

  @override
  String get sceneDelete => 'Obriši scenu';

  @override
  String sceneDefaultName(String time) {
    return 'Scena $time';
  }

  @override
  String get autoEdit => 'Izmeni automatizaciju';

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
  String get alertsSetting => 'Obaveštenja o kritičnim upozorenjima';

  @override
  String get alertsSettingHint =>
      'Dim, CO, curenje vode, aktiviran alarm ili zaglavljena brava kao obaveštenje na telefonu. Dok aplikacija radi — ili stalno, uz Automatizacije u pozadini (Podešavanja → Dom).';

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
  String get dashCardShortcuts => 'Provera kuće, Još';

  @override
  String get dashCardAttention => 'Potrebna pažnja (baterije, nedostupni)';

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
  String timerTurnsOffAt(String time) {
    return 'Isključuje se u $time';
  }

  @override
  String timerTurnsOnAt(String time) {
    return 'Uključuje se u $time';
  }

  @override
  String get kioskPanelChooseDevice => 'Izaberi uređaj';

  @override
  String get settingsNotificationsSection => 'Obaveštenja';

  @override
  String get settingsAppearanceHint => 'Tema, jezik, početni ekran';

  @override
  String get settingsKioskHint =>
      'Zidni tablet: raspored, PIN, čuvar ekrana, kamera';

  @override
  String get settingsNotificationsHint => 'Upozorenja, baterije, gotov uređaj';

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
  String get morningScreen => 'Jutarnji ekran';

  @override
  String get morningScreenHint =>
      'Ujutru ekran u mirovanju pokazuje današnju prognozu, obaveze i podsetnike (stavke sa rokom danas).';

  @override
  String get morningFrom => 'Od';

  @override
  String get morningTo => 'Do';

  @override
  String morningHighLow(String high, String low) {
    return 'najviše $high, najniže $low';
  }

  @override
  String get aodBrightness => 'Osvetljenost u mirovanju';

  @override
  String get approachWake => 'Probudi ekran kad neko priđe';

  @override
  String get approachWakeHint => 'Samo dok je ekran kioska u mirovanju.';

  @override
  String get approachOff => 'Isključeno';

  @override
  String get approachSensor => 'Senzor pokreta';

  @override
  String get approachCamera => 'Kamera tableta';

  @override
  String get approachSensorPick => 'Senzor';

  @override
  String get approachNoSensors =>
      'Nema senzora pokreta ili prisustva. Dodajte jedan (npr. Shelly BLU, Hue, IKEA ili ESPHome).';

  @override
  String get approachCameraTitle => 'Koristiti kameru tableta?';

  @override
  String get approachCameraBody =>
      'Dok je ekran u mirovanju, prednja kamera nekoliko puta u sekundi proverava da li se nešto pomera ispred tableta, a Android prikazuje oznaku kamere. Slike se obrađuju samo na ovom tabletu i odmah odbacuju: ništa se ne snima, ne čuva i nigde ne šalje. Dok je ekran budan, kamera je isključena.';

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
  String get presenceLights => 'Svetla';

  @override
  String get presenceNoLights => 'U domu nema svetala.';

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
  String get kioskColumnsNoRooms =>
      'Još nema soba. Dodajte ih u Podešavanja → Dom.';

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
  String get applianceDoneRemove => 'Ukloni';

  @override
  String get applianceDoneRemoved => 'Javljanje je uklonjeno.';

  @override
  String applianceDoneSaved(String name) {
    return 'Javiće se kad „$name” završi.';
  }

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
      'Fotografija, ikonica i boja ostaju samo na ovom uređaju. Za zidni tablet izaberite ih na samom tabletu.';

  @override
  String get themeAutoDark => 'Tamno posle zalaska sunca';

  @override
  String get themeAutoDarkHint =>
      'Prati izlazak i zalazak sunca na lokaciji doma (bez nje: tamno od 20 do 7).';

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
  String get roomLookReset => 'Podrazumevano';

  @override
  String get favoritesBrowse => 'Pogledaj uređaje';

  @override
  String get bigSliderPosition => 'Položaj';

  @override
  String get deviceSheetMore => 'Svi detalji';

  @override
  String get setupNext => 'Dalje';

  @override
  String get setupBack => 'Nazad';

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
  String get firstRunSkip => 'Preskoči';

  @override
  String get firstRunWelcomeTitle => 'Dobro došli kući!';

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
      'Još nema uređaja kojima se upravlja. Dodajte ih posle, u Podešavanja → Dom.';

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
  String get firstRunSecurityTitle => 'Zaštita';

  @override
  String get firstRunSecurityBody =>
      'Ko ima vaš otključan telefon, može da upravlja kućom. Preporučujemo bar potvrdu za brave i alarm.';

  @override
  String get firstRunDoneTitle => 'Sve je spremno';

  @override
  String get firstRunDoneBody =>
      'Uređaje dodajete u Podešavanja → Dom → Dodaj uređaj. Sve što ste ovde izabrali menjate u Podešavanjima, a kartice Početne dugmetom ⚙ pored pozdrava.';

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
      'Na tabletu ukućanin dodirne svoje ime i dobija svoje brze kontrole. Otključavanje vrata, isključenje alarma i slične radnje dozvoljene su samo uz lični PIN ukućanina ili PIN tableta — ko nema PIN (npr. deca), ne može. Dodir na ime: rođendan.';

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
  String batteryReminderMessage(String name, String percent) {
    return 'Baterija je pri kraju: $name ($percent %)';
  }

  @override
  String get batteryLowShort => 'Slaba baterija';

  @override
  String get batteryOk => 'Baterija u redu';

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
  String get settingsHomeSection => 'Dom';

  @override
  String get settingsHomeHint => 'Uređaji i sobe';

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

  @override
  String get tuyaKeyHint =>
      'Tuya uređaj (Smart Life, Tuya Smart…) traži svoj lokalni ključ, 16 znakova. Ključ se jednom uzima iz Tuya naloga (npr. alatom tinytuya wizard); posle toga aplikacija razgovara direktno sa uređajem.';

  @override
  String get miioTokenHint =>
      'Xiaomi uređaj traži svoj token, 32 znaka. Token se jednom uzima iz Mi Home naloga (npr. alatom Xiaomi Cloud Tokens Extractor).';

  @override
  String get deviceTokenLabel => 'Lokalni ključ / token';

  @override
  String get deviceTokenWrong => 'Uređaj ne prihvata ovaj ključ.';

  @override
  String get irButtonsTitle => 'Dugmad daljinskog';

  @override
  String get irButtonsEmpty =>
      'Još nema naučenih dugmadi. Naučite ih sa originalnog daljinskog.';

  @override
  String get irLearn => 'Nauči dugme';

  @override
  String get irLearnName => 'Ime dugmeta (npr. Klima uključi)';

  @override
  String get irLearnPress =>
      'Usmerite originalni daljinski ka uređaju i pritisnite dugme. Čeka se 20 sekundi.';

  @override
  String get irLearnFailed => 'Uređaj nije čuo dugme. Pokušajte ponovo, bliže.';

  @override
  String irLearned(String name) {
    return 'Dugme „$name“ je naučeno.';
  }

  @override
  String get irSend => 'Pošalji';

  @override
  String get irDelete => 'Obriši dugme';

  @override
  String get cameraAdd => 'Dodaj kameru';

  @override
  String get cameraUrlLabel => 'Adresa slike sa kamere';

  @override
  String get cameraUrlHint =>
      'Kamera daje trenutnu sliku na svojoj adresi. Na primer: Reolink /cgi-bin/api.cgi?cmd=Snap&channel=0, Hikvision /ISAPI/Streaming/channels/101/picture, Dahua /cgi-bin/snapshot.cgi, ESP32-CAM /capture.';

  @override
  String get cameraUserLabel => 'Korisnik (ako kamera traži)';

  @override
  String get cameraNoImage =>
      'Na ovoj adresi nema slike sa kamere (ili je korisnik pogrešan).';

  @override
  String get cameraOffline => 'Kamera trenutno ne daje sliku.';

  @override
  String get emptyHomeTitle => 'Još nema uređaja';

  @override
  String get emptyHomeBody =>
      'Dodajte uređaje sa kućne Wi-Fi mreže ili preko Bluetooth-a: Shelly, Hue, WiZ, Tapo, Tuya, ESPHome, televizore i druge.';

  @override
  String get householdAdd => 'Dodaj ukućanina';

  @override
  String get householdName => 'Ime';

  @override
  String get householdRemove => 'Ukloni ukućanina';

  @override
  String get personMember => 'Ukućanin';

  @override
  String get setupHelpTitle => 'Uređaj se ne pojavljuje?';

  @override
  String get setupHelpHint =>
      'Telefon i uređaj moraju biti na istoj Wi-Fi mreži. Šta još treba, po proizvođaču:';

  @override
  String get tipShelly =>
      'Radi odmah. Ako je na uređaju uključena lozinka (Restrict login), unesite je pri dodavanju.';

  @override
  String get tipWled => 'Radi odmah.';

  @override
  String get tipTasmota =>
      'Obično se ne oglašava na mreži: dodajte je preko IP adrese.';

  @override
  String get tipEsphome =>
      'U konfiguraciji uređaja treba da postoji api:. Ako je uključeno šifrovanje (api: encryption: key), unesite taj ključ.';

  @override
  String get tipHue =>
      'Dodaje se Hue most; pri uparivanju pritisnite okruglo dugme na vrhu mosta. Svetla i senzori mosta dolaze sami.';

  @override
  String get tipYeelight =>
      'U Yeelight aplikaciji, za svaku sijalicu, uključite „LAN Control“.';

  @override
  String get tipWiz =>
      'U WiZ aplikaciji lokalna komunikacija mora biti dozvoljena (Podešavanja → Bezbednost → Dozvoli lokalnu komunikaciju).';

  @override
  String get tipLifx => 'Radi odmah.';

  @override
  String get tipGovee =>
      'U Govee aplikaciji, u podešavanjima uređaja, uključite „LAN Control“. Nemaju ga svi modeli.';

  @override
  String get tipNanoleaf =>
      'Pri uparivanju držite dugme za uključivanje 5–7 sekundi, dok svetla ne zatrepću.';

  @override
  String get tipSonoff =>
      'Radi samo u DIY režimu: uključite ga u eWeLink aplikaciji ili DIY prekidačem na uređaju.';

  @override
  String get tipTpLink =>
      'Stariji Kasa uređaji rade odmah. Tapo i noviji Kasa traže e-poštu i lozinku TP-Link naloga; dodajte ih preko IP adrese.';

  @override
  String get tipDirigera =>
      'Pri uparivanju pritisnite dugme za radnju na poleđini čvorišta. IKEA uređaji čvorišta dolaze sami.';

  @override
  String get tipTuya =>
      'Treba lokalni ključ uređaja (16 znakova), koji se jednom uzima iz Tuya naloga, npr. alatom tinytuya wizard. Uređaji sa protokolom 3.5 još ne rade.';

  @override
  String get tipXiaomi =>
      'Treba token uređaja (32 znaka), npr. iz alata Xiaomi Cloud Tokens Extractor. Rade utičnice i svetla (MIoT), Chuangmi utičnice i Roborock usisivači.';

  @override
  String get tipBroadlink =>
      'U Broadlink aplikaciji uređaj mora biti otključan (Unlock device); posle toga dugmad učite na ekranu uređaja.';

  @override
  String get tipSamsung =>
      'Pri prvom povezivanju izaberite Dozvoli na televizoru. Za paljenje sa telefona uključite „Power On with Mobile“ (ili IP Remote) u podešavanjima televizora.';

  @override
  String get tipLg =>
      'Pri prvom povezivanju potvrdite na televizoru. Za paljenje sa telefona uključite „Turn on via Wi-Fi“ (Mobile TV On).';

  @override
  String get tipRoku =>
      'U podešavanjima Roku-a (Sistem → Napredna podešavanja → Kontrola mobilnim aplikacijama) dozvolite pristup mreži.';

  @override
  String get tipSonos => 'Radi odmah.';

  @override
  String get tipCamera =>
      'Dugme „Dodaj kameru“: adresa slike sa kamere (primeri su u dijalogu) i korisnik, ako ga kamera traži.';

  @override
  String get tipBluetooth =>
      'Telefon mora biti blizu (do ~10 m). Rade BTHome (Shelly BLU), Xiaomi sa pvvx/ATC firmverom, SwitchBot i Govee termometri; šifrovani BTHome i Xiaomi MiBeacon ne.';

  @override
  String get tipUnavailable => 'Uređaj trenutno ne odgovara.';

  @override
  String get backupTransferLocked =>
      'Prenos je prekinut: tri puta je unet pogrešan kod. Pošaljite ponovo.';
}

/// The translations for Serbian, using the Latin script (`sr_Latn`).
class AppLocalizationsSrLatn extends AppLocalizationsSr {
  AppLocalizationsSrLatn() : super('sr_Latn');
}
