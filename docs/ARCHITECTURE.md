# Arhitektura

## Više domova

`SessionRepository` čuva listu profila (`connection.savedProfiles`, bez tajni) i imena domova (`connection.homeNames`, iz `location_name`); token svakog doma je u secure storage-u pod ID-jem profila. Aktivan je jedan profil; promena aktivnog profila (`SessionController.switchTo`) ponovo gradi sve provajdere vezane za sesiju (REST, WebSocket, keš, omiljeni). Dok korisnik dodaje dom (`addingHomeProvider`), ekrani za povezivanje su dostupni i uz postojeću sesiju.

## Osnovna odluka

Telefon nema Zigbee/Z-Wave/Thread radio, pa aplikacija **ne implementira fizičke protokole**. Home Assistant Core je integration engine: registruje uređaje, drži stanja, izvršava servise i automatizacije, i povezuje Zigbee2MQTT, Z-Wave JS, Matter Server, OTBR, MQTT i LAN integracije. Aplikacija u MVP-u direktno koristi dokumentovane HA REST i WebSocket API-je; sopstveni backend (NestJS/PostgreSQL/Redis) uvodi se tek za multi-home, uloge, udaljeni pristup i push.

## Slojevi

```
presentation  (widgeti – samo prikaz i prosleđivanje akcija)
      │ ref.watch / ref.read
application   (Riverpod Notifier-i: SessionController, ConnectionSetupController, …)
      │
data/integrations (SessionRepository, HomeAssistantApi, HaWebSocketManager)
      │
core          (AppFailure, AppLogger + Redactor, ServerAddress, TlsTrust, CredentialStore, AppPreferences)
```

Pravila:
- Widgeti ne sadrže poslovnu logiku; parsiranje adrese, provere, retry i čuvanje tajni žive u `application`/`core`.
- Svi slojevi razmenjuju greške isključivo kao `AppFailure` (kategorija + tehnička poruka bez tajni). Korisnička poruka se bira u UI-ju po kategoriji (`failure_messages.dart`).
- `integrations/home_assistant` je jedini deo koda koji poznaje HA wire format. Mapper u interni `SmartHomeDevice` model (faza 5) biće granica – UI nikada neće videti HA atribute direktno.

## Ključne komponente

### `ServerAddress` (core/network)
Value object za bazni URL: normalizacija (`homeassistant.local:8123` → `http://homeassistant.local:8123`), odbijanje putanja/kredencijala/query-ja, detekcija lokalne mreže (RFC 1918, loopback, link-local, IPv6 ULA, `.local`, `.home.arpa`, jednodelni nazivi) i procena rizika (`none`, `remoteExposure`, `insecureRemote`). Iz njega se izvode REST i `ws(s)://…/api/websocket` URI-ji.

### `TlsTrust` (core/network)
Jedinstveno TLS pravilo za REST i WebSocket. Podrazumevano važe samo sistemski CA. `badCertificateCallback` se poziva samo za sertifikate koje platforma već odbila; prihvata se jedino sertifikat čiji se SHA-256 otisak poklapa sa onim koji je korisnik eksplicitno pinovao.

### Platformski sloj (web i mobilni)
Sav kod koji zavisi od `dart:io` izdvojen je iza uslovnih importa (`if (dart.library.js_interop)`), pa ostatak aplikacije ne zna na kojoj platformi radi:

| Fajl | `dart:io` (Android, iOS, testovi) | Web |
|---|---|---|
| `integrations/home_assistant/transport/transport_*.dart` | `IOHttpClientAdapter` + TLS pinovanje, `IOWebSocketChannel`, klasifikacija `SocketException`/`HandshakeException` | podrazumevani Dio browser adapter, browser WebSocket, bez klasifikacije (pregledač skriva uzrok) |
| `core/storage/credential_store_*.dart` | Keychain / Keystore | `sessionStorage` |

`ServerAddress` parsira IP adrese čistim Dart-om (`Uri.parseIPv4Address`/`parseIPv6Address`). `PlatformInfo` (provider) daje `isWeb`, `isSecurePage` i predlog adrese servera iz porekla stranice; u testovima se zamenjuje.

### `HomeAssistantApi` (integrations/home_assistant/api)
Interfejs sa dve implementacije: `DioHomeAssistantApi` (pravi server) i `MockHomeAssistantApi`. Timeout-i iz `AppConfig`, bez automatskih redirect-a, status kodovi se mapiraju na jednom mestu (`mapStatusCode`), nazivi servisa se validiraju (`^[a-z0-9_]+$`) da bi se sprečilo ubacivanje putanje.

### `HaWebSocketManager` (integrations/home_assistant/websocket)
Jedini vlasnik WebSocket veze, živi tačno koliko i sesija (`webSocketManagerProvider`).

```
disconnected → connecting → authenticating → connected
                    ▲              │  auth_invalid → authenticationFailed (bez daljih pokušaja)
                    │              ▼
              reconnecting ◄── prekid / ping timeout / auth timeout
                    │  posle N neuspeha
                    ▼
            serverUnavailable (pokušaji se nastavljaju sa max. kašnjenjem)
```

- Generacijski brojač odbacuje poruke zakasnelih soketa.
- Jedna serverska pretplata po tipu događaja, deljena između svih slušalaca; `unsubscribe_events` kada otkaže poslednji.
- Posle `auth_ok`: reset backoff-a, ponovna pretplata svih aktivnih tokova, start heartbeat-a (`ping` svakih 30 s, timeout 10 s).
- Backoff: eksponencijalni, ograničen na 60 s, „equal jitter” – nema uskih petlji, a više zidnih tableta se ne povezuje istovremeno nakon restarta servera.
- Komande na zatvorenoj vezi odmah dobijaju `AppFailure(webSocket)`.

### Sesija
`SessionController` (AsyncNotifier) učitava `ServerProfile` (netajno, u preferences) samo ako za njega postoji token u `CredentialStore`. Provideri `homeAssistantApiProvider`, `webSocketManagerProvider`, `connectionStatusProvider` zavise od aktivnog profila – odjava ih automatski uništava (zatvara soket, otkazuje tajmere).

### Model uređaja i sinhronizacija (faza 5)
- `features/devices/domain`: `SmartHomeDevice`, `DeviceKind`, `Capability`, `DeviceState`, `DeviceLimits`, `DeviceCommand`. Ne zavisi ni od Home Assistanta ni od Fluttera.
- `integrations/home_assistant/mappers`: `HaDeviceMapper` (HA entitet + registri → `SmartHomeDevice`), `HaCommandTranslator` (komanda → HA servis), feature bitovi, detekcija protokola.
- `features/devices/data/HomeStateRepository`: održava snimak doma (snapshot + događaji), vidi [API_INTEGRATION.md](API_INTEGRATION.md#sinhronizacija-stanja-implementirano-homestaterepository).
- `features/devices/application`: `homeSnapshotProvider`, `deviceProvider(id)`, `roomsProvider`, `deviceIdsByRoomProvider`, `DeviceCommandService`.

**Performanse:** događaj ponovo mapira samo svoj entitet (ili sve entitete fizičkog uređaja kad se promeni baterija ili signal). Nepromenjeni uređaji zadržavaju isti objekat, pa `deviceProvider(id)` (preko `select`) obnavlja samo karticu uređaja koji se promenio.

Detalji mapiranja: [DEVICE_CAPABILITIES.md](DEVICE_CAPABILITIES.md).

### Korisnički interfejs (faza 6)
| Feature | Ekrani |
|---|---|
| `dashboard` | `DashboardScreen`; `DashboardSummary`, `RoomSummary`, grupisanje po kategorijama (`home_summaries.dart`) |
| `rooms` | `RoomsScreen`, `RoomDetailScreen`, `AllDevicesScreen` |
| `devices/presentation` | `DeviceTile`, `DeviceSliverGrid`, `DeviceDetailScreen`, kontrole po mogućnostima, `DevicePresentation` (ikona/ton/lokalizovan status) |
| `favorites` | `FavoritesController` (lokalno po serveru), `FavoritesScreen` |
| `scenes` | `ScenesScreen` (scene, skripte, automatizacije) |

Pravila koja kod sledi:
- Kontrola postoji samo ako uređaj prijavi mogućnost; nedostupan uređaj ima onemogućene kontrole i jasnu poruku.
- Sve komande idu kroz `runDeviceCommand` → `DeviceCommandService`: kritične traže potvrdu, a greške se prikazuju kao lokalizovan snackbar.
- Slajderi šalju komandu tek kad se pusti prst i drže lokalnu vrednost dok uređaj ne potvrdi; termostat grupiše uzastopne +/− u jednu komandu.
- Izvedeni provideri vraćaju `ValueList` ili klase sa jednakošću po vrednosti, pa se ekran obnavlja samo kad se njegov sadržaj stvarno promeni; kartica uređaja prati samo svoj uređaj.
- Mreže su lenje (`SliverGrid.builder`), a visina kartica raste sa veličinom teksta.

### Tablet i kiosk (faza 7)
- `DashboardBody` je zajednički sadržaj običnog i kiosk dashboarda. Na širini ≥ 1200 dp, ili na landscape ekranu ≥ 840 dp, prelazi u dva panela: status levo, omiljeno i prostorije desno.
- `features/kiosk`: `KioskSettings` (lokalno, PIN samo kao heš), `KioskSettingsController`, `KioskSessionController` (da li je kiosk aktivan, provera PIN-a i blokada), `KioskShell` (fullscreen, wakelock, blokiran „back”, tajmeri neaktivnosti, zatamnjenje), `KioskDashboardScreen`.
- Kiosk rute (`/kiosk`, `/kiosk/device/:id`, `/kiosk/rooms/:id`) imaju sopstveni `ShellRoute` bez navigacije. `resolveRedirect(kioskActive: true)` dozvoljava samo njih. Kartice biraju kiosk ili običnu rutu preko `AppRoutes.device(id, kiosk: …)`.
- Platformski efekti (fullscreen, wakelock) su iza interfejsa `KioskPlatform`, pa testovi ne diraju platformske kanale. Greške na nepodržanim platformama (npr. Wake Lock API na `http://`) samo se loguju.
- `AppLifecycleListener` u `SmartHomeApp` poziva `retryNow()` kad se aplikacija vrati u prvi plan.

### Offline keš (faza 8)
- `features/devices/data/cache`: `SnapshotCache` (interfejs), `FileSnapshotCache` (io), `SessionStorageSnapshotCache` (web), `InMemorySnapshotCache` (testovi). Sve operacije su serijalizovane, pa brisanje pri odjavi ne može da pretekne raniji upis.
- Kešira se **sirov HA format** (`CachedHome`, verzija šeme 1), ne mapirani uređaji. Pri učitavanju podaci prolaze kroz isti mapper, pa poboljšanje mappera ne traži migraciju keša, a nepoznata verzija se jednostavno ignoriše.
- `HomeStateRepository.start()` učitava keš paralelno sa povezivanjem. Keš se primenjuje samo ako živi podaci još nisu stigli, i to sa statusom `stale`/`syncing` i originalnim vremenom sinhronizacije.
- Zašto ne Drift ili Isar: snimak je jedan dokument koji se čita i piše u celini, bez upita. Baza bi donela generisanje koda i SQLite/WASM na webu bez koristi. Ako kasnije zatrebaju upiti (istorija, energija), uvodi se tada.

### Mock režim
`MockHomeAssistantServer` je in-memory HA: stanja u HA wire formatu (svetla, prekidači, senzori, klima, roletna, brava, kamera, energija, scena, automatizacija, nedostupan uređaj, slaba baterija), podskup servisa, i WebSocket protokol (`auth_required/auth/auth_ok`, `subscribe_events`, `ping`, `get_states`, `call_service`). Isti `HaWebSocketManager` radi i protiv mock-a, pa se mock režim i testovi ponašaju kao produkcija. Uključuje se sa `--dart-define=SMARTHOME_MOCK=true`, a `AppConfig` ga gasi kad je `kReleaseMode`.

### Navigacija i responsive
`go_router` sa redirect pravilima izdvojenim u čistu funkciju `resolveRedirect` (testirana). `AppShell` bira `NavigationBar` (< 600 dp), `NavigationRail` (600–1199 dp) ili prošireni rail (≥ 1200 dp). Breakpoint-i postoje samo u `core/widgets/responsive.dart`.

## Odluke koje su namerno odložene
- **Lokalna baza (Drift)** – faza 8, kada postoji model uređaja koji se kešira.
- **freezed/json_serializable** – nisu potrebni za trenutni broj modela; ručno parsiranje je defanzivno (preskače neispravne entitete umesto da obori ceo ekran).
- **Prigušivanje događaja** – kod veoma velikog broja senzorskih promena snimak se emituje za svaki događaj; grupisanje po frame-u dodaje se ako merenje pokaže potrebu (faza 9).
- **`subscribe_entities`** – efikasniji, ali kompresovani format nije deo zvanične developer dokumentacije; koristi se dokumentovani `subscribe_events` + `state_changed`.
