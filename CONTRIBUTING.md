# Doprinos projektu

Hvala na interesovanju! Ovo je kratak vodič kako da izmene budu prihvaćene brzo.

## Priprema

```bash
cd app
flutter pub get
flutter gen-l10n
flutter run --dart-define=SMARTHOME_MOCK=true   # bez stvarnog Home Assistanta
```

## Pre slanja pull request-a

```bash
dart format lib test integration_test
flutter analyze            # mora biti bez ijedne napomene
flutter test               # unit, widget i performance testovi
flutter test integration_test -d <uređaj>   # za izmene koje diraju platformu
```

CI (`.github/workflows/ci.yml`) pokreće iste provere i pravi web i Android build.

## Pravila

- **Ne izmišljati API-je.** Koristiti samo dokumentovane Home Assistant API-je. Ako se koristi nedokumentovana komanda (kao registri), mora biti opciona, sa rezervnim ponašanjem i opisana u `docs/API_INTEGRATION.md`.
- **Bez poslovne logike u widgetima.** Logika ide u `application/` (Riverpod Notifier-i) ili `data/`/`integrations/`. Widget samo prikazuje i prosleđuje akcije.
- **Svaki tekst za korisnika ide u ARB** (`lib/app/localization/arb/app_en.arb` i `app_sr.arb`). Oba jezika moraju biti popunjena.
- **Tajne se nikad ne loguju.** Koristiti `AppLogger` (sam redaktuje), a u poruke ne stavljati tokene, lozinke ni zaglavlja.
- **Kontrola postoji samo uz mogućnost.** UI za uređaj se gradi iz `Capability`, ne iz naziva entiteta ni proizvođača.
- **Testovi uz izmenu.** Novi domen/mapping → test u `test/integrations/ha_device_mapper_test.dart` sa stvarnim HA atributima. Ispravka greške → test koji bi je uhvatio.
- **Zavisnosti** se dodaju samo uz jasnu ulogu (opisati je u PR-u i u README tabeli).
- **Pristupačnost:** dodirne površine ≥ 48 dp, značenje se ne prenosi samo bojom, a ekran mora raditi sa tekstom od 150 % (postoji test).

## Dodavanje novog tipa uređaja

Vidi [docs/DEVICE_CAPABILITIES.md](docs/DEVICE_CAPABILITIES.md#dodavanje-novog-domena).

## Dodavanje jezika

1. Kopirajte `app_en.arb` u `app_<kod>.arb` i prevedite vrednosti.
2. Dodajte jezik u `AppLocales.selectable` i u izbor jezika (`language_selector.dart`).
3. `flutter gen-l10n` i proverite ekrane sa dužim tekstovima.

## Commit poruke

Kratak naslov u imperativu (engleski), prazan red, pa opis šta i zašto. Jedna logička celina po commit-u.

## Prijava bezbednosnih problema

Ne preko javnog issue-a – vidi [docs/SECURITY.md](docs/SECURITY.md#prijava-ranjivosti).
