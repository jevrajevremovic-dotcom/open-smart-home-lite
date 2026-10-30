# Izdavanje (Android)

Release verzije se potpisuju sopstvenim ključem. Ključ i lozinke **nikad** ne idu u git
(`key.properties` je u `app/android/.gitignore`, a ključ stoji van repozitorijuma).

## Ključ (jednom)

Lite koristi isti ključ kao Open Smart Home 1.0; to je u redu, jer ima drugi Android id
(`org.opensmarthome.lite`) i instalira se pored originala. Novi ključ, ako treba:

```bash
mkdir -p ~/keys && keytool -genkey -v -keystore ~/keys/open-smart-home-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias osh
chmod 600 ~/keys/open-smart-home-release.jks
```

Fajl `app/android/key.properties` (dozvole 600):

```
storePassword=…
keyPassword=…
keyAlias=osh
storeFile=/apsolutna/putanja/do/open-smart-home-release.jks
```

Čuvajte rezervnu kopiju ključa i lozinke van računara (menadžer lozinki, USB). Bez istog
ključa aplikacija se ne može ažurirati, samo obrisati i instalirati iznova.

## Build

```bash
cd app && flutter build apk --release --split-per-abi
```

Bez `key.properties` build i dalje radi, ali potpisuje **debug** ključem i to piše u izlazu
(„release signed with the DEBUG key“); takve verzije se ne dele.

Provera potpisa:

```bash
$ANDROID_HOME/build-tools/<verzija>/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Prelazak sa probnih (debug) verzija

Telefon na kome je verzija potpisana drugim ključem ne prima ažuriranje
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`): aplikacija se mora jednom obrisati, što briše dom i
podešavanja. Pre toga: Podešavanja → Rezervna kopija i prenos → Sačuvaj u fajl (ili Pošalji na drugi
uređaj), uz „Sa lozinkama i ključevima uređaja“ ako ih ima.

## Objavljivanje izdanja (ažuriranje u aplikaciji)

Instalirane aplikacije same nalaze nove verzije (Podešavanja → O aplikaciji). Izvor su
**GitHub Releases** javnog repozitorijuma `jevrajevremovic-dotcom/open-smart-home-lite`
(`UPDATE_REPO` pri buildu; brend ga zadaje sa `updates=` u `brand.properties`).

```bash
cd app && tool/release.sh 0.2.0 --notes "Šta je novo"
```

Skripta upisuje verziju u `pubspec.yaml` (build broj +1, Android traži da raste) i
`lib/app/app_info.dart`, pravi APK-ove potpisane vašim ključem, piše `SHA256SUMS` i objavljuje
izdanje `v0.2.0`. Aplikacija instalira samo APK čiji se SHA-256 poklapa sa `SHA256SUMS`, a
Android sam odbija APK potpisan drugim ključem. Zatim komitujte `pubspec.yaml` i
`lib/app/app_info.dart`, a u [CHANGELOG.md](CHANGELOG.md) odeljak `[Unreleased]` preimenujte u
verziju.

Repozitorijum mora biti **javan** da bi ga aplikacije videle bez tokena.
