# Open Smart Home Lite

Lite verzija [Open Smart Home](https://github.com/jevrajevremovic-dotcom/open-smart-home) aplikacije: uređaji koji se povezuju na telefon preko **Wi-Fi-ja** (lokalna mreža) i **Bluetooth-a**, u jednoj aplikaciji, **bez Home Assistanta i bez Raspberry Pi-ja**. Telefon je centrala.

Nastala je kao kopija Open Smart Home 1.0 (`app/`) i deli njen model uređaja i korisnički interfejs. Aplikacija se instalira pored originala (`org.opensmarthome.lite`).

## Plan

| Faza | Šta | Status |
|---|---|---|
| 0 | `HomeBackend` interfejs: stanje i komande idu kroz njega, Home Assistant je samo jedna implementacija (`HaBackend`) | ✅ |
| 0b | Uklanjanje HA integracije i ekrana koji bez HA nemaju smisla; prvo pokretanje bez prijave | ⏳ |
| 1 | `LocalBackend` + Wi-Fi adapteri: Shelly, WLED, Tasmota, ESPHome (mDNS) | |
| 2 | Hue bridge, LIFX, Yeelight, TP-Link Kasa | |
| 3 | Bluetooth LE: SwitchBot, Xiaomi/Govee senzori | |
| 4 | Matter | |

## Granica

```
UI (kartice, sobe, kiosk…)
   │ homeSnapshotProvider, deviceCommandServiceProvider
DeviceCommandService  (provere: dostupnost, mogućnost, potvrda)
   │
HomeBackend  ── HaBackend (HA WebSocket + REST)
             └─ LocalBackend (faza 1: adapteri po protokolu)
```

- `app/lib/features/devices/domain/home_backend.dart`: `HomeBackend`, `DeviceCommandSink`
- `app/lib/features/devices/domain/home_snapshot.dart`: `HomeSnapshot`, `SyncStatus`
- `app/lib/integrations/home_assistant/ha_backend.dart`: `HaBackend`, `HaCommandSink`

## Ograničenja lite verzije

- Automatizacije rade samo dok aplikacija radi (Android: foreground servis).
- Nema pristupa van kuće ni Zigbee/Z-Wave uređaja (osim preko Hue bridge-a / Dirigera).
- Samo Android; web ne može (nema mDNS ni BLE u pregledaču).

Licenca: vidi [LICENSE](LICENSE) i [NOTICE](NOTICE).
