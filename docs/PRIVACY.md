# Privatnost

Open Smart Home Lite razgovara sa uređajima u kući direktno, preko kućne Wi-Fi mreže i Bluetooth-a. Nema naloga, servera ni oblaka autora aplikacije, a nema ni Home Assistanta.

## Šta ostaje u kući

- Spisak uređaja, sobe, imena, scene i automatizacije su samo na telefonu.
- Lozinke, ključevi i tokeni uređaja su u zaštićenom skladištu telefona (Android Keystore), nikad u podešavanjima ni u logovima. To su Shelly lozinke, ESPHome ključevi, Hue korisnik, Nanoleaf i DIRIGERA tokeni, ključevi Samsung i LG televizora, Tuya lokalni ključevi, Xiaomi tokeni, TP-Link nalog i prijava na kameru.
- **TP-Link nalog** (Tapo i noviji Kasa): uređaj ga proverava sam, preko lokalne mreže. Aplikacija ga ne šalje TP-Linku.
- **Tuya lokalni ključ i Xiaomi token** se jednom uzimaju iz naloga tih proizvođača, alatom van aplikacije. Aplikacija sama ne pristupa njihovim nalozima.
- Slika sa kamere se preuzima samo dok je ekran kamere otvoren i nigde se ne čuva.
- Naučena dugmad daljinskog (Broadlink) čuvaju se uz uređaj na telefonu.
- Rezervna kopija nosi lozinke i ključeve samo ako to izaberete, šifrovane lozinkom kopije. Prenos na drugi telefon ide preko iste Wi-Fi mreže, šifrovan šestocifrenim kodom.
- Lični PIN-ovi ukućana i PIN tableta su samo na tom tabletu, kao heš.

## Šta izlazi na internet, samo ako uključite

| Šta | Kome | Kada | Šta tačno |
|---|---|---|---|
| Vremenska prognoza i zalazak sunca | MET Norway (`api.met.no`) | Ako uključite prognozu za dom ili za telefon | Koordinate zaokružene na ~1 km, najviše jednom na 30 min |
| Provera ažuriranja | GitHub (`api.github.com`) | Ako uključite proveru ili je pokrenete ručno | Vaša IP adresa i da aplikacija traži novu verziju |

Ništa od ovoga nije uključeno samo od sebe. Analitike, praćenja i reklama nema.

## Dozvole na Androidu

| Dozvola | Zašto | Kada se traži |
|---|---|---|
| Internet, multicast | Razgovor sa uređajima u kući; pronalaženje uređaja na mreži (mDNS, SSDP, UDP) | Uvek |
| Bluetooth (traženje, povezivanje) | Bluetooth senzori; kratko povezivanje sa SwitchBot Bot i Curtain radi komande | Pri dodavanju Bluetooth uređaja |
| Približna lokacija | Vreme na mestu gde je telefon | Samo ako to izaberete |
| Mikrofon | Pljesak za paljenje svetla na tabletu | Samo pri uključivanju |
| Kamera | Buđenje tableta kad neko priđe; slike soba | Samo pri korišćenju |
| Obaveštenja | Upozorenja, baterije, „gotovo je“, muzika | Samo pri uključivanju |
| Usluga u prvom planu, pokretanje posle restarta | Automatizacije dok je aplikacija zatvorena | Samo ako to uključite |
| Instaliranje paketa | Ažuriranje sa GitHub izdanja (posle provere SHA-256) | Pri prvom ažuriranju |

Pitanja i prijave: GitHub → Issues (za bezbednosne propuste: Security → Report a vulnerability).
