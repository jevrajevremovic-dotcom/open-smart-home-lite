# Format rezervne kopije

Rezervna kopija (Podešavanja → Rezervna kopija i prenos) je JSON fajl. Format **2** važi od verzije 0.3.

## Obećanje

- Svaka buduća verzija aplikacije čita kopije formata 1 i 2.
- Format se menja samo dodavanjem: nova polja mogu da se pojave, postojeća ne menjaju značenje i ne nestaju. Nepoznata polja se pri uvozu zanemaruju, pa i starija verzija aplikacije uvozi noviju kopiju (bez onoga što ne poznaje).
- Ako ikad bude potrebna nespojiva promena, dobiće novi broj formata, a aplikacija će i dalje čitati stare.
- Test `app/test/features/backup_format_test.dart` uvozi pravu kopiju formata 2 (`app/test/fixtures/backup_v2.json`). Taj fajl se menja samo dodavanjem.

## Sadržaj

| Polje | Šta je |
|---|---|
| `app` | uvek `open-smart-home-settings` |
| `version` | `2` (stari izvozi: `1`) |
| `theme`, `autoDark`, `oled`, `accent`, `language` | izgled |
| `favorites` | ID-jevi omiljenih uređaja |
| `homeLayout`, `roomLooks` | kartice Početne; ikone i boje soba (bez fotografija) |
| `kiosk` | podešavanja zidnog tableta, bez onoga što je izbor samog uređaja (PIN tableta, mikrofon, kamera, pokretanje u kiosku, foto-okvir) |
| `home.rooms` | sobe: `id`, `name`, `icon` |
| `home.devices` | dodati uređaji: `adapter`, `id`, `host`, `model`, `label`, `secured`, `options` (npr. Tuya `version`, Broadlink naučena dugmad `btn:<ime>`, zapamćen sertifikat `cert`, MAC televizora `mac`) |
| `home.names`, `home.roomOf` | imena i sobe uređaja koje je domaćinstvo izabralo |
| `home.members` | ukućani: `id`, `name` (lični PIN-ovi ostaju na tabletu) |
| `routines` | scene i automatizacije |
| `presence`, `sunrise`, `appliances` | simulacija prisustva, buđenje svetlom, „javi kad je gotov“ |
| `homeLocation` | lokacija doma za prognozu i zalazak sunca (zaokružena na ~1 km) |
| `secrets` | samo ako je izabrano: lozinke, ključevi i tokeni uređaja, šifrovani lozinkom kopije |

`secrets` je objekat `{kdf: "pbkdf2-sha256", iterations, salt, nonce, data}` (base64): ključ iz lozinke preko PBKDF2-HMAC-SHA256, podaci AES-256-GCM. Unutra je mapa `device:<adapter>:<id>` → lozinka. Pri uvozu se upisuju samo ključevi tog oblika (i lozinka gostujuće mreže).

Uvoz bira **Zameni sve** (dom postaje kao u kopiji) ili **Dodaj samo novo** (dodaju se uređaji, sobe, ukućani, scene i automatizacije kojih nema).
