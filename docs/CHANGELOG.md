# Changelog

## [Unreleased]

### Uklonjeno
- Demo uređaji: aplikacija više ne prikazuje izmišljeni dom. Dok nema uređaja, početna kaže kako se dodaju; prekidač „Demo uređaji“ u Podešavanjima je uklonjen.

## [0.3.0] – 2026-10-30

### Novi uređaji
- Svetla: WiZ, LIFX, Govee (LAN), Nanoleaf (uparivanje dugmetom).
- Sonoff u DIY režimu; TP-Link Tapo i noviji Kasa preko KLAP-a (uz TP-Link nalog, proverava ga uređaj).
- IKEA DIRIGERA čvorište i njegovi Zigbee uređaji.
- Tuya lokalno (3.3 i 3.4, uz lokalni ključ) i Xiaomi miIO (utičnice, svetla, Roborock usisivači, uz token).
- Televizori: Roku, Samsung (Tizen), LG (webOS), sa daljinskim; Sonos zvučnici.
- Broadlink IR daljinski: dugmad se uče sa originalnog daljinskog.
- Kamere: slika sa adrese kamere, osvežava se dok je ekran otvoren.
- SwitchBot Bot i Curtain preko Bluetooth-a (traži i dozvolu za povezivanje na Androidu 12+).

### Ispravljeno
- Izjava o privatnosti opisuje lite verziju (ranije: Home Assistant).

## [0.2.0] – 2026-10-30

Prvo izdanje lite verzije: uređaji na lokalnoj Wi-Fi mreži i Bluetooth LE senzori, bez Home Assistanta i bez Raspberry Pi-ja. Verzije 0.1.0 bile su probne (potpisane debug ključem): pre instalacije ove treba ih obrisati, a dom pre toga sačuvati u rezervnu kopiju.

### Uređaji
- Shelly (Gen1 i Gen2+, sa lozinkom), WLED (efekti i preseti), Tasmota, ESPHome (native API, sa Noise šifrovanjem), Philips Hue preko mosta, Yeelight, TP-Link Kasa (stariji lokalni protokol).
- Bluetooth LE senzori iz oglasa: BTHome v2 (Shelly BLU), Xiaomi sa pvvx/ATC firmverom, SwitchBot Meter, Govee H5072/H5075.
- Otkrivanje na mreži (mDNS, SSDP, UDP) i dodavanje preko IP adrese; dodati uređaj koji dobije novu adresu (DHCP) se sam prati.
- Demo dom dok se ne doda prvi uređaj.

### Scene, automatizacije i dodaci
- Scene i automatizacije na telefonu: vreme, izlazak i zalazak sunca, stanje i vrednost uređaja; uslovi po danima, vremenu, stanju i mraku.
- Rad u pozadini (Android servis, i posle restarta telefona).
- Vraćeno iz 1.0, sada na telefonu: zabava, laku noć, buđenje svetlom, odmor, simulacija prisustva, tajmer uređaja, raspored grejanja, „javi kad je gotov“, baterije sa podsetnikom.

### Rezervna kopija
- Dom, scene, automatizacije i dodaci u fajl, kao tekst, ili drugom telefonu preko iste Wi-Fi mreže (adresa i šestocifreni kod).
- Po želji i lozinke i ključevi uređaja, šifrovani lozinkom kopije (PBKDF2-SHA256, AES-256-GCM).
- Uvoz: zameni dom ili dodaj samo ono čega nema.

### Ispravljeno u odnosu na 1.0
- Automatska tamna tema i boja neba u vremenskoj kartici prate zalazak sunca na lokaciji doma (ranije: HA `sun.sun`, kog u lite nema, pa je važilo 20–7 h).
- Upozorenje kioska „vrata otvorena predugo“ i „Poslednja promena“ na ekranu uređaja: aplikacija sama beleži kad se stanje promenilo, jer lokalni uređaji to ne javljaju.
- Widget sa scenama na početnom ekranu pokreće lite scene.
- Ograničeni režim (za decu) ne pušta na dodavanje uređaja ni preko linka.
- Krupan tekst: ekran „Dodaj uređaj“ na uskom telefonu i imena scena u kiosku se više ne prelivaju.

### Uklonjeno iz 1.0
- Sve što je radilo preko Home Assistanta: prijava i server, Assist i wake word, kalendar, liste, tabla, kamere, istorija i energija, NFC scene, Matter dodavanje. Dozvole za NFC, Matter i mikrofonski PCM tok su izbačene.

### Nije provereno na pravim uređajima
- ESPHome šifrovanje (testirano samo protiv sopstvene implementacije uređajske strane), Hue most, Yeelight i Kasa, Bluetooth skeniranje, rad u pozadini posle restarta.
