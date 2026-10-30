# Bezbednost

Open Smart Home Lite upravlja kućom sa telefona: ko ima telefon i aplikaciju, upravlja uređajima koji su u njoj. Nema servera ni naloga; uređaji se nalaze na kućnoj mreži, pa je deo zaštite u aplikaciji, a deo u mreži i na samim uređajima.

## Šta radi aplikacija

| Pretnja | Zaštita |
|---|---|
| Krađa lozinki uređaja sa telefona | Lozinke, ključevi, tokeni i TP-Link nalog su samo u Android Keystore (šifrovano, vezano za uređaj); nikad u podešavanjima, logovima ni Androidovoj rezervnoj kopiji (isključena). „Obriši sve podatke“ briše i njih. |
| Rezervna kopija u pogrešnim rukama | Lozinke idu u kopiju samo ako to izaberete, šifrovane lozinkom kopije (PBKDF2-SHA256, 100 000 ponavljanja, AES-256-GCM). Uvoz upisuje u zaštićeno skladište samo lozinke uređaja, ništa drugo. |
| Prenos na drugi telefon | Preko iste Wi-Fi mreže, šifrovano šestocifrenim kodom, najviše 5 minuta, samo jednom i samo na Wi-Fi adresi. Kopiju dobija samo ko pokaže da zna kod; posle tri pogrešna koda prenos se prekida. Ograničenje: neko ko pasivno snima saobraćaj na istoj mreži mogao bi da pogađa kod van mreže; zato lozinke uređaja u kopiji imaju i svoju lozinku. |
| Lažni uređaj na mreži (TLS) | DIRIGERA i Samsung/LG televizori imaju sopstveni sertifikat: aplikacija ga zapamti pri uparivanju i posle prihvata samo njega (drugi sertifikat = odbijeno, uz objašnjenje). |
| Prisluškivanje mreže | Većina kućnih uređaja (Shelly, WLED, Tasmota, Hue, Kasa…) govori samo nešifrovani HTTP/UDP; to je svojstvo uređaja. Lozinke Shelly uređaja idu kao HTTP Digest, ne u čistom tekstu. ESPHome sa ključem koristi Noise šifrovanje, Tapo KLAP, Tuya i Xiaomi AES. |
| Slučajno ili tuđe otključavanje | Brave, alarm, garaža/kapija traže potvrdu; opciono otisak prsta (Podešavanja → Bezbednost). Na zidnom tabletu i PIN kioska ili lični PIN ukućanina. |
| Izgubljen telefon | Zaključavanje aplikacije otiskom/PIN-om uređaja (Podešavanja → Bezbednost). |
| Deca i gosti | Ograničen režim: sakriva brave i alarm, zatvara podešavanja i dodavanje uređaja (i preko linka). |
| Druge aplikacije na telefonu | Link iz widgeta i prečice pokreću samo scenu koja je stvarno na widgetu ili među prečicama. |
| Lažno ažuriranje | APK mora da se poklopi sa SHA-256 iz izdanja, a Android prihvata samo APK potpisan istim ključem. |
| Curenje podataka | Sve radi lokalno; jedini izlaz na internet (vreme, provera ažuriranja) je opcion i naveden u [PRIVACY.md](PRIVACY.md). Javni repozitorijum ne sadrži tajne. |

## Šta treba podesiti (spisak)

**Mreža**
- [ ] Wi-Fi sa WPA2/WPA3 i jakom lozinkom; gosti na posebnoj (guest) mreži, bez pristupa pametnim uređajima.
- [ ] Ruter ažuriran, administratorska lozinka promenjena; pametni uređaji bez otvorenih portova ka internetu.

**Uređaji**
- [ ] Shelly i kamere sa lozinkom; ESPHome sa ključem za šifrovanje (`api: encryption: key`).
- [ ] Firmver uređaja ažuran.
- [ ] Telefoni: zaključavanje ekrana i zaključavanje aplikacije.
- [ ] Zidni tablet: PIN kioska; najbolje pripremljen kao „vlasnik uređaja”.
- [ ] Ključ za potpis aplikacije čuvati van računara ([RELEASE.md](RELEASE.md)).

## Prijava problema

Bezbednosni propust prijavite privatno vlasniku repozitorijuma (GitHub → Security → Report a vulnerability), ne kao javni issue.
