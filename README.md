# Open Smart Home Lite

Lite verzija [Open Smart Home](https://github.com/jevrajevremovic-dotcom/open-smart-home) aplikacije: uređaji koji se povezuju na telefon preko **Wi-Fi-ja** (lokalna mreža) i **Bluetooth-a**, u jednoj aplikaciji, **bez Home Assistanta i bez Raspberry Pi-ja**. Telefon je centrala.

Nastala je od Open Smart Home 1.0 i deli njen model uređaja i korisnički interfejs. Aplikacija se instalira pored originala (`org.opensmarthome.lite`). Za sada prikazuje demo dom; pravi uređaji dolaze u fazi 1.

## Plan

| Faza | Šta | Status |
|---|---|---|
| 0 | `HomeBackend` interfejs: stanje i komande idu kroz njega | ✅ |
| 0b | Bez Home Assistanta: `LocalBackend` + adapteri, demo dom, prvo pokretanje bez prijave | ✅ |
| 1 | Wi-Fi adapteri: Shelly, WLED, Tasmota, ESPHome (mDNS), lokalna lista uređaja | |
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
                                 ├─ DemoAdapter (sada)
                                 └─ Shelly, WLED, Tasmota, ESPHome… (faza 1)
```

- `app/lib/features/devices/domain/home_backend.dart`: `HomeBackend`, `DeviceCommandSink`
- `app/lib/features/devices/domain/home_snapshot.dart`: `HomeSnapshot`, `SyncStatus`
- `app/lib/features/devices/data/local/`: `LocalBackend`, `DeviceAdapter`, `DemoAdapter`

ID uređaja je `<adapter>:<id u adapteru>` (npr. `demo:living_ceiling`), pa `LocalBackend` zna kom adapteru ide komanda.

## Šta je uklonjeno iz 1.0 i kad se vraća

Sve što je radilo preko Home Assistanta je izbačeno (kod je u istoriji originalnog projekta):

| Funkcija | Vraća se |
|---|---|
| Prijava, povezivanje na server, više domova, van kuće | — (nema servera) |
| Dodavanje uređaja (Zigbee, Z-Wave, Matter, HA otkrivanje) | faza 1 (Wi-Fi, mDNS), faza 4 (Matter) |
| Preimenovanje uređaja i premeštanje u sobu | faza 1 (lokalna lista uređaja) |
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
