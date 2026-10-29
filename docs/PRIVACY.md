# Privatnost

Open Smart Home je aplikacija za **vaš** Home Assistant. Nema naloga, servera ni oblaka autora aplikacije: aplikacija razgovara samo sa vašim Home Assistantom, a sa ostatkom interneta samo kad to sami uključite.

## Šta ostaje u kući

- Stanja uređaja, prostorije, kamere, kalendari, liste, poruke ukućanima, istorija i dnevnik dolaze iz vašeg Home Assistanta i ne idu nigde drugde.
- Token za prijavu je u zaštićenom skladištu uređaja (Android Keystore / iOS Keychain), nikad u logovima ni u rezervnoj kopiji.
- Obaveštenja (upozorenja, poruke iz HA, muzika) pravi sam uređaj iz podataka koje prima od HA — nema push servera.
- Podešavanja aplikacije su na uređaju; „Rezervna kopija u Home Assistantu” ih po vašem izboru čuva u **vašem** HA (bez tokena, PIN-ova i fotografija).
- Fotografije soba, tlocrt i foto-okvir su samo na uređaju.
- Lični PIN-ovi ukućana i PIN tableta su samo na tom tabletu, kao heš.
- Šifra Wi-Fi mreže za goste je u zaštićenom skladištu uređaja.
- Obrada kamere tableta za buđenje ekrana i ključne reči (ako je uključeno) radi na uređaju ili u vašem HA.

## Šta izlazi na internet — samo ako uključite

| Šta | Kome | Kada | Šta tačno |
|---|---|---|---|
| Vremenska prognoza | MET Norway (`api.met.no`) | Ako HA nema prognozu, a vi izaberete MET | Koordinate doma ili telefona zaokružene na ~1 km, najviše na 30 min |
| Provera ažuriranja | GitHub (`api.github.com`) | Ako uključite proveru (ili je ručno pokrenete) | Vaša IP adresa i da aplikacija traži novu verziju |
| Prepoznavanje govora preko interneta | Google/Apple servis telefona | Samo ako ga izričito izaberete (podrazumevano je na uređaju) | Snimak glasa dok držite dugme |
| Pristup van kuće | Vaš Tailscale, Nabu Casa ili domen | Ako podesite spoljnu adresu | Isto što i kod kuće, šifrovano |
| Assist preko Home Assistant Clouda | Nabu Casa | Ako je tako podešeno u vašem HA | Tekst komande |
| Dodavanje novog Matter uređaja preko Bluetooth-a | Google Play services | Samo dok dodajete uređaj | Ono što Google Play services koristi za uparivanje |

Ništa od ovoga nije uključeno samo od sebe. Analitike, praćenja i reklama nema.

## Dozvole na Androidu

| Dozvola | Zašto | Kada se traži |
|---|---|---|
| Internet, multicast | Veza sa Home Assistantom; pronalaženje servera na mreži (mDNS) | Uvek |
| Približna lokacija | Vreme na mestu gde je telefon | Samo ako to izaberete |
| Mikrofon | Glasovne komande, ključna reč na tabletu, pljesak | Samo pri uključivanju |
| Kamera | Skeniranje QR koda; buđenje tableta kad neko priđe | Samo pri korišćenju |
| NFC | NFC nalepnice | Kad se koriste |
| Obaveštenja | Upozorenja, poruke iz HA, muzika | Samo pri uključivanju |
| Usluga u prvom planu, pokretanje posle restarta | Poruke iz HA i kad je aplikacija zatvorena | Samo ako to uključite |
| Instaliranje paketa | Ažuriranje sa GitHub izdanja (posle provere SHA-256) | Pri prvom ažuriranju |

## Demo aplikacija

„Open Smart Home Demo” radi sa izmišljenom kućom ugrađenom u aplikaciju, bez Home Assistanta i bez interneta.

Pitanja i prijave: GitHub → Issues (za bezbednosne propuste: Security → Report a vulnerability).
