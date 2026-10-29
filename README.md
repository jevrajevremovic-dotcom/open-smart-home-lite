# Open Smart Home Lite

Lite verzija [Open Smart Home](https://github.com/jevrajevremovic-dotcom/open-smart-home) aplikacije: uređaji koji se povezuju na telefon preko **Wi-Fi-ja** (lokalna mreža) i **Bluetooth-a**, u jednoj aplikaciji, **bez Home Assistanta i bez Raspberry Pi-ja**. Telefon je centrala.

Nastala je od Open Smart Home 1.0 i deli njen model uređaja i korisnički interfejs. Aplikacija se instalira pored originala (`org.opensmarthome.lite`). Radi sa Shelly i WLED uređajima na lokalnoj mreži; dok se ne doda prvi uređaj, prikazuje demo dom.

## Plan

| Faza | Šta | Status |
|---|---|---|
| 0 | `HomeBackend` interfejs: stanje i komande idu kroz njega | ✅ |
| 0b | Bez Home Assistanta: `LocalBackend` + adapteri, demo dom, prvo pokretanje bez prijave | ✅ |
| 1 | Lokalna lista uređaja i soba, mDNS otkrivanje, Shelly i WLED | ✅ |
| 1b | Tasmota, ESPHome; Shelly sa lozinkom; WLED efekti i preseti | |
| 2 | Hue bridge, LIFX, Yeelight, TP-Link Kasa | |
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
                                 ├─ ShellyAdapter ─┐ PolledAdapter (HTTP, svakih 5 s)
                                 └─ WledAdapter  ──┘
```

- `app/lib/features/devices/domain/home_backend.dart`: `HomeBackend`, `DeviceCommandSink`
- `app/lib/features/devices/domain/home_snapshot.dart`: `HomeSnapshot`, `SyncStatus`
- `app/lib/features/devices/data/local/`: `LocalBackend`, `DeviceAdapter`, `PolledAdapter`, `DemoAdapter`, `ShellyAdapter`, `WledAdapter`, `LocalHome` (sobe, dodati uređaji, imena; čuva se na telefonu)
- `app/lib/features/add_device/`: mDNS otkrivanje (`_http._tcp`), prepoznavanje (`/shelly`, `/json/info`), ekran za dodavanje

ID uređaja je `<adapter>:<MAC>:<kanal>` (npr. `shelly:a8032ab12345:switch0`, `wled:e8db84aabbcc:light`), pa `LocalBackend` zna kom adapteru ide komanda. Jedan fizički uređaj (`deviceId` = `<adapter>:<MAC>`) daje po jedan uređaj za svaki kanal, i merač snage gde ga ima.

## Podržani uređaji

| Uređaj | Šta radi |
|---|---|
| Shelly Gen2+ (Plus, Pro, Gen3, Gen4) | releji i utičnice (`switch`), dimeri (`light`), roletne (`cover`, sa pozicijom ako je kalibrisana), snaga (`apower`), temperatura i vlažnost |
| Shelly Gen1 | releji (`relay`), dimeri (`light`), roletne (`roller`), snaga (`meters`) |
| WLED | uključi/isključi, jačina, boja glavnog segmenta |

Ograničenja: Shelly sa uključenom lozinkom (odgovara 401) i uređaji na baterije koji spavaju (H&T) za sada se prikazuju kao nedostupni. Stanje se proverava svakih 5 s dok je aplikacija otvorena (zidni tablet u kiosku i u pozadini). Ako ruter da uređaju novu IP adresu, ekran „Dodaj uređaj“ je sam ažurira kad ga ponovo pronađe.

## Šta je uklonjeno iz 1.0 i kad se vraća

Sve što je radilo preko Home Assistanta je izbačeno (kod je u istoriji originalnog projekta):

| Funkcija | Vraća se |
|---|---|
| Prijava, povezivanje na server, više domova, van kuće | — (nema servera) |
| Dodavanje Zigbee, Z-Wave i Matter uređaja | faza 4 (Matter) |
| Editor scena i automatizacija | uz lokalne automatizacije |
| Zabava, laku noć, buđenje uz svetlo, odmor, dolazak kući, baterije, tajmer uređaja, raspored grejanja, gotov uređaj, simulacija prisustva | uz lokalne automatizacije / prebacivanje na `DeviceCommand` |
| Istorija, energija, aktivnost, nedeljni pregled | uz lokalnu istoriju stanja |
| Assist (glas), wake word, kalendar, liste, tabla, porodične poruke, HA obaveštenja i najave, NFC scene, kamere, HA backup podešavanja, servisni ekran instalatera | — |

Prognoza za dom sada koristi lokaciju telefona zapamćenu kad se prognoza uključi (ranije: lokacija doma iz HA).

## Testovi

`flutter test` pokreće testove lite verzije (`TestAdapter` i `testDevice` u `test/helpers.dart`). Testovi iz 1.0 koji grade dom preko lažnog HA servera čekaju prebacivanje u `app/test_to_port/` (vidi tamošnji README).

## Ograničenja lite verzije

- Automatizacije rade samo dok aplikacija radi (Android: foreground servis).
- Nema pristupa van kuće ni Zigbee/Z-Wave uređaja (osim preko Hue bridge-a / Dirigera).
- Samo Android; web ne može (nema mDNS ni BLE u pregledaču).

Licenca: vidi [LICENSE](LICENSE) i [NOTICE](NOTICE).
