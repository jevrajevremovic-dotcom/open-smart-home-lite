# Open Smart Home Lite

Lite verzija [Open Smart Home](https://github.com/jevrajevremovic-dotcom/open-smart-home) aplikacije: uređaji koji se povezuju na telefon preko **Wi-Fi-ja** (lokalna mreža) i **Bluetooth-a**, u jednoj aplikaciji, **bez Home Assistanta i bez Raspberry Pi-ja**. Telefon je centrala.

Nastala je od Open Smart Home 1.0 i deli njen model uređaja i korisnički interfejs. Aplikacija se instalira pored originala (`org.opensmarthome.lite`). Radi sa Shelly, WLED, Tasmota, ESPHome, Philips Hue, Yeelight i TP-Link Kasa uređajima na lokalnoj mreži; dok se ne doda prvi uređaj, prikazuje demo dom.

## Plan

| Faza | Šta | Status |
|---|---|---|
| 0 | `HomeBackend` interfejs: stanje i komande idu kroz njega | ✅ |
| 0b | Bez Home Assistanta: `LocalBackend` + adapteri, demo dom, prvo pokretanje bez prijave | ✅ |
| 1 | Lokalna lista uređaja i soba, mDNS otkrivanje, Shelly i WLED | ✅ |
| 1b | Tasmota, Shelly sa lozinkom, WLED efekti i preseti, praćenje promenjene IP adrese | ✅ |
| 1c | ESPHome (native API, sa Noise šifrovanjem) | ✅ |
| 2 | Hue most, Yeelight, TP-Link Kasa (stari lokalni protokol) | ✅ |
| 2b | LIFX; Kasa/Tapo sa novim protokolom (KLAP) | |
| A | Lokalne scene i automatizacije, rad u pozadini | ✅ |
| 3 | Bluetooth LE: SwitchBot, Xiaomi/Govee senzori | |
| 4 | Matter | |

## Granica

```
UI (kartice, sobe, kiosk…)
   │ homeSnapshotProvider, deviceCommandServiceProvider
DeviceCommandService  (provere: dostupnost, mogućnost, potvrda)
   │
HomeBackend ── LocalBackend ── DeviceAdapter (jedan po vrsti uređaja)
                                 ├─ DemoAdapter
                                 ├─ ShellyAdapter  ─┐
                                 ├─ WledAdapter    ─┼ PolledAdapter (HTTP, svakih 5 s)
                                 ├─ TasmotaAdapter ─┤
                                 ├─ HueAdapter     ─┤ (most, v1 API)
                                 ├─ YeelightAdapter ┤ (TCP 55443, svakih 10 s)
                                 ├─ KasaAdapter    ─┘ (TCP 9999, XOR)
                                 └─ EsphomeAdapter (TCP 6053, trajna veza, promene stižu same)
```

- `app/lib/features/devices/domain/home_backend.dart`: `HomeBackend`, `DeviceCommandSink`
- `app/lib/features/devices/domain/home_snapshot.dart`: `HomeSnapshot`, `SyncStatus`
- `app/lib/features/devices/data/local/`: `LocalBackend`, `DeviceAdapter`, `PolledAdapter`, `DemoAdapter`, `ShellyAdapter`, `WledAdapter`, `LocalHome` (sobe, dodati uređaji, imena; čuva se na telefonu)
- `app/lib/features/add_device/`: mDNS otkrivanje (`_http._tcp`), prepoznavanje (`/shelly`, `/json/info`, `Status 0`, ESPHome iz mDNS-a `_esphomelib._tcp` ili preko API-ja), ekran za dodavanje, `AddressKeeper` (prati promenjene IP adrese)

ID uređaja je `<adapter>:<MAC>:<kanal>` (npr. `shelly:a8032ab12345:switch0`, `wled:e8db84aabbcc:light`), pa `LocalBackend` zna kom adapteru ide komanda. Jedan fizički uređaj (`deviceId` = `<adapter>:<MAC>`) daje po jedan uređaj za svaki kanal, i merač snage gde ga ima.

## Podržani uređaji

| Uređaj | Šta radi |
|---|---|
| Shelly Gen2+ (Plus, Pro, Gen3, Gen4) | releji i utičnice (`switch`), dimeri (`light`), roletne (`cover`, sa pozicijom ako je kalibrisana), snaga (`apower`), temperatura i vlažnost |
| Shelly Gen1 | releji (`relay`), dimeri (`light`), roletne (`roller`), snaga (`meters`) |
| WLED | uključi/isključi, jačina, boja glavnog segmenta; efekat i preset kao izbori |
| Tasmota | releji (`POWER1…`, imena iz `FriendlyName`), svetlo sa jačinom i bojom, snaga (`ENERGY`), temperatura i vlažnost |
| Philips Hue (preko mosta) | svetla (uključi/isključi, jačina, temperatura boje, boja), utičnice, senzori temperature i pokreta; uparuje se dugmetom na mostu |
| Yeelight | sijalice, trake, plafonjere: jačina, temperatura boje, boja (treba uključiti „LAN Control“ u Yeelight aplikaciji) |
| TP-Link Kasa | utičnice, prekidači, dimeri, razdelnici (svaka utičnica posebno), sijalice; snaga gde je meri; samo stariji lokalni protokol — novi firmver (KLAP) i Tapo ne odgovaraju |
| ESPHome | prekidači, svetla (jačina, boja, temperatura boje), roletne, dugmad, senzori, binarni senzori (vrata, pokret, curenje…), tekstualni senzori; dijagnostički entiteti se ne prikazuju u listama |

ESPHome: veza je trajna (native API, port 6053) i uređaj sam šalje promene. Ako uređaj ima `api: encryption: key:`, ključ se unosi pri dodavanju i proverava pre nego što se uređaj doda (Noise `NNpsk0_25519_ChaChaPoly_SHA256`, `app/lib/features/devices/data/local/esphome/`). Ventilatori, klima, `number` i `select` entiteti još nisu podržani. Šifrovanje je testirano samo protiv sopstvene implementacije uređajske strane (`test/esphome_fake.dart`), ne protiv pravog uređaja.

Shelly sa lozinkom: Gen2+ preko HTTP Digest (SHA-256), Gen1 preko Basic, korisnik `admin`. Lozinka se unosi pri dodavanju ili u Podešavanja → Dom i čuva samo u bezbednom skladištu telefona (Keystore), nikad u podešavanjima ili rezervnoj kopiji.

Ograničenja: uređaji na baterije koji spavaju (Shelly H&T) prikazuju se kao nedostupni. Tasmota se obično ne oglašava preko mDNS-a, pa se dodaje preko IP adrese. Stanje se proverava svakih 5 s dok je aplikacija otvorena (zidni tablet u kiosku i u pozadini). Pri pokretanju i povratku u aplikaciju telefon 30 s osluškuje mrežu; dodati uređaj koji se javi sa nove IP adrese (DHCP) se sam prati.

## Scene i automatizacije

Čuvaju se na telefonu (`app/lib/features/automations/`) i prikazuju kao uređaji (`routine:scene_…`, `routine:auto_…`), pa ih početna, kiosk, brze pločice i prečice prikazuju kao i ranije HA scene.

- **Scena** pamti kako su izabrani uređaji podešeni sada (uključeno/isključeno, jačina, boja, roletne, temperatura).
- **Automatizacija**: kada (vreme, izlazak/zalazak sunca ± minuti, uređaj pređe u stanje, vrednost poraste iznad / padne ispod), samo ako (dani, vreme od–do, stanje uređaja, mrak/dan), uradi (komanda uređaju ili scena).
- Izlazak i zalazak sunca računaju se na telefonu iz lokacije doma (Podešavanja → Privatnost → prognoza za dom); bez nje sunčevi okidači ne rade, a „mrak“ je 20–6 h.
- Rade dok aplikacija radi: otvorena, na zidnom tabletu u kiosku, ili uz **Automatizacije u pozadini** (Podešavanja → Dom), kad Androidov servis drži aplikaciju živom uz stalno obaveštenje i posle restarta telefona.

## Dodaci (meni „Još“ i ekran uređaja)

Vraćeni iz 1.0, sada rade na telefonu umesto u Home Assistantu: **zabava** (boje svetala se smenjuju, posle se sve vraća), **laku noć** (priča uz prigušivanje u koracima), **buđenje svetlom** (svakog minuta svetlije i hladnije do vremena buđenja), **odmor** (grejanje dole, simulacija prisustva uključena; posle sve kako je bilo), **simulacija prisustva** (Podešavanja → Bezbednost), **tajmer uređaja** („isključi za 30 min“), **raspored grejanja** (čuva se kao automatizacije doma) i **javi kad je gotov** (prati snagu uređaja, javlja obaveštenjem), **baterije** (lista, najprazniji prvi; podsetnik obaveštenjem jednom po uređaju kad padne na 15 %; nivo javljaju Hue senzori, ESPHome senzori klase `battery` i Shelly uređaji na baterije). Sve što radi po vremenu radi dok aplikacija radi (kiosk ili automatizacije u pozadini); simulacija prisustva traži uređaj koji ostaje kod kuće.

## Šta je uklonjeno iz 1.0 i kad se vraća

Sve što je radilo preko Home Assistanta je izbačeno (kod je u istoriji originalnog projekta):

| Funkcija | Vraća se |
|---|---|
| Prijava, povezivanje na server, više domova, van kuće | — (nema servera) |
| Dodavanje Zigbee, Z-Wave i Matter uređaja | faza 4 (Matter) |
| Dolazak kući | — (bez pristupa van kuće dugme ne može da stigne do uređaja) |
| Istorija, energija, aktivnost, nedeljni pregled | uz lokalnu istoriju stanja |
| Assist (glas), wake word, kalendar, liste, tabla, porodične poruke, HA obaveštenja i najave, NFC scene, kamere, HA backup podešavanja, servisni ekran instalatera | — |

Prognoza za dom sada koristi lokaciju telefona zapamćenu kad se prognoza uključi (ranije: lokacija doma iz HA).

## Testovi

`flutter test` pokreće testove lite verzije (`TestAdapter` i `testDevice` u `test/helpers.dart`). Testovi iz 1.0 koji grade dom preko lažnog HA servera čekaju prebacivanje u `app/test_to_port/` (vidi tamošnji README).

## Ograničenja lite verzije

- Automatizacije rade samo dok aplikacija radi (kiosk ili rad u pozadini); telefon je centrala, nema servera koji radi kad je telefon ugašen.
- Nema pristupa van kuće ni Zigbee/Z-Wave uređaja (osim preko Hue bridge-a / Dirigera).
- Samo Android; web ne može (nema mDNS ni BLE u pregledaču).

Licenca: vidi [LICENSE](LICENSE) i [NOTICE](NOTICE).
