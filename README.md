# Asset360 (Purple IQ) — mobile demo

A clickable Flutter demo of the Asset360 enterprise asset management app. Every screen runs on in-memory
mock data (`lib/data/`); every button does something. State resets when the app restarts.

## How to run

Requirements: Flutter stable (3.38+, Dart 3.10+), Android SDK (or Xcode for iOS).

```bash
flutter pub get
flutter run                 # debug build on a connected phone or emulator (Developer section visible)
flutter analyze             # must report "No issues found!"
flutter test                # all widget / unit tests
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   (most phones)
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (older 32-bit phones)
#   build/app/outputs/flutter-apk/app-x86_64-release.apk      (emulators)
```

Install on a phone: `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, or copy the APK to the
phone and open it (allow "Install unknown apps").

Release builds are shrunk (R8 code + resource shrinking, rules in `android/app/proguard-rules.pro`) and the Dart
code is obfuscated. **Keep `build/symbols/` for every build you hand out** — it is the only way to read its crash
reports. Copy it somewhere safe next to the APK (it is wiped by `flutter clean`), then decode a stack trace with:

```bash
flutter symbolize -i crash.txt -d build/symbols/app.android-arm64.symbols
```

The QR / barcode scanner uses the unbundled ML Kit model (`dev.steenbakker.mobile_scanner.useUnbundled=true` in
`android/gradle.properties`): Google Play services downloads it once, so the phone needs Play services, and the
first scan after install can need a network connection.

## Demo login

| Field | Value |
|---|---|
| Username | `rex.kumar` (or the email `rkumar@purpleiq.ai`) |
| Password | `Asset@360` |
| Authenticator code | `123456` |

Five wrong passwords lock sign-in for a short time; five wrong codes return to Login. Google / Microsoft sign-in
are simulated. Profile → Change Password needs the current password `Asset@360`; the new one applies until restart.

"Now" is always Friday 25 Sep 2026, 10:30 AM (Asia/Dubai) — `DemoClock` — so due dates and "x mins ago" never drift.

## Developer toggles

**More → Settings → Developer** (debug builds only; hidden in release APKs):

| Toggle | What it does |
|---|---|
| Data check | Runs every count / total / balance check on the current data and lists pass or fail (same logic as `test/data_check_test.dart`). |
| Simulate offline | Forces the app offline: the offline banner shows and every change is queued for Offline Sync. Switching back starts auto-sync (Wi-Fi). |
| Simulate sync failures | Each item has a 10% chance to fail while syncing, so Retry can be tried. |
| Print demo tags | QR codes for the demo assets, to scan from a second phone (tap a tag for a large QR). |
| Reset demo data | After a confirm, reloads every seed record (you stay signed in). |

Also in Settings: Appearance (Light / Dark / System), notification categories, default scan mode, beep and
vibration, language (Arabic is "coming soon"), app version and open-source licenses. On the Scan screen, debug builds
show a "Simulate scan" chip.

Single-login demo note: when you transfer an asset you can pick yourself as the **Approver** ("self-approve (demo)"),
so the request shows in Home → My Approvals and the whole Approve → In Transit → Received cycle can be tried alone.

## Modules

| Module | Where | Highlights |
|---|---|---|
| Login & security | Splash → Login | Remember me, lockout, Forgot username / password, Authenticator code |
| Home dashboard | Home tab | KPI tiles, My Tasks (WOs / inspections / approvals), alerts, floor plan, charts, site filter, pull to refresh |
| Assets | Assets tab | Search / filters / favourites, Asset 360° detail (overview, IoT, WOs, inspections, documents, financial, history) |
| Asset Registration | More → Asset Registration | 5-step form, barcode / RFID / QR uniqueness, IoT link, bulk CSV import |
| Scan & Identify | Centre Scan button | QR / barcode camera, NFC / RFID / BLE (simulated), manual entry, multi scan, scan history |
| Tracking & IoT | More → Tracking & IoT | Live map (FL-012 moves every 3 s), asset list, sensors, geofencing, telemetry charts, route playback |
| Movement & Custody | Work → Movement | Transfer (5 steps, approval), check out / in, assign custodian, return, history |
| Maintenance | Work → Maintenance | My WOs / PM / overdue, WO detail with tasks, checklists, parts, close-out with signature, PM schedules |
| Inspection | Work → Inspection | Checklist engine (ranges, photos, signature), auto findings, score, WO from finding |
| Issues / Defects | Work → Issues | Report (critical → alert + notification), detail, timeline, create WO, close |
| Alerts & Notifications | More / bell | Severity tabs, acknowledge / resolve, live alerts, notification settings |
| Inventory & Spare Parts | More → Inventory | Stock levels, reservations, stock ledger, POs with GRN, part requests, reports |
| WIP / Operations | Work → WIP | Production orders (MO-), start / end operation, QC, rework, unit tracking |
| Documents | More → Documents | Manuals, warranties, certificates, expiry, versions, PDF / image viewer, upload |
| Asset Audit & Compliance | Work → Asset Audit | Audit campaigns, scan session, found / wrong location / not found / unregistered, report |
| Offline Sync | More → Offline Sync | Pending queue by type, auto-sync rules, sync progress, retry, history |
| Contracts, Financial, Reports, Administration | More | Warranty / AMC filters, value by category, report export, users and sites |
| Profile, Settings, Help & Support | Avatar / More | Edit profile, change password, logout; settings above; searchable FAQ, contact, report a bug |

## Local storage & scanning

Only **scans, locations and tag links** are stored on the device, in SQLite via drift
(`lib/data/db/`: `app_database.dart`, seed in `location_seed.dart`, providers in `db_providers.dart`).
Every other module keeps its in-memory mock repository. Screens read the tables through Riverpod
`StreamProvider`s (`.watch()`), so Local Data, badges and forms update live and survive restarts.

- **Tables:** `ScanLog` (every scan: value, format, source, NFC UID + decoded NDEF records as JSON, match,
  real time, device), `Locations` (Site → Building → Floor → Room, seeded on first launch from the mock
  location tree, each with a printable code), `TagLinks` (a barcode / QR value or `NFC:<uid>` linked to a
  location or an asset; `tagKey` is unique).
- **ScanService** (`lib/core/scanning/scan_service.dart`): every scan from the camera, NFC, the HHT scanner
  and Manual Entry goes through it. Same value within 2 s is ignored. Match order: TagLinks → `LOC:` +
  location code → asset ID / barcode / tag (then part number) → unknown. The row is saved, then delivered.
- **Targets:** a visible `LocationField` (or the Scan screen) registers as a scan target; the topmost one
  that accepts the match gets it. With no target: asset → Asset detail, location → "Location: …" sheet,
  unknown → "This tag isn't linked yet" (Link to a location / Link to an asset / Just save).
- **NFC:** real reads with `nfc_manager` (Scan → NFC → Tap to Read, or the scan icon of a location field).
  Any tag works; blank tags give `NFC:<UID>`. RFID and BLE stay simulated ("Demo").
- **iOS NFC** needs the *NFC Tag Reading* capability (entitlement `ios/Runner/Runner.entitlements`), which
  requires a paid Apple Developer account and a provisioning profile with NFC enabled.
- **More → Local Data**: stats, All / QR & Barcode / NFC / Linked Tags, search + filters, detail sheet
  (Copy, Open asset, Link this tag, Delete), swipe to delete with Undo, ⋮ Clear all scans.

Regenerate drift code after changing a table (build_runner is used for drift only):

```bash
dart run build_runner build --delete-conflicting-outputs --force-jit
```

(`--force-jit` is needed because some dependencies ship build hooks, which the AOT build script can't compile.)

### Configuring the HHT (handheld terminal) scanner

The scanner works on every screen. Settings → Scanning → **Scanner** (or Local Data ⋮ → Scanner settings):

- **Mode:** Auto (both), Broadcast (Android intents) or Keyboard (the scanner types the code + Enter;
  characters < 50 ms apart, ≥ 3 characters; ignored while a normal text field has focus).
- **Zebra DataWedge:** create a profile for `com.purpleiq.asset360_mobile`, Keystroke output **off**, Intent
  output **on**, action `com.purpleiq.asset360.SCAN`, category empty, delivery **Broadcast intent**.
- **Honeywell:** pick the preset; the app claims the scanner (`ACTION_CLAIM_SCANNER`) with data intents sent to
  `com.purpleiq.asset360.HONEYWELL_SCAN` (extra `data`).
- **Urovo:** Scanner settings → Output mode *Intent*; action `android.intent.ACTION_DECODE_DATA`, extra
  `barcode_string` (the defaults).
- **Custom:** enter your scanner's broadcast action and data extra.
- Use **Test scanner** to see the last value received. Without hardware:
  `adb shell am broadcast -a com.purpleiq.asset360.SCAN --es com.symbol.datawedge.data_string LOC:BLD-A-F2`

### Seeded location codes (for test QR labels)

Print a QR code whose text is `LOC:` + the code (e.g. `LOC:BLD-A-F2`). A floor label fills Site / Building /
Floor; a room label fills all four.

| Code | Level | Site | Location |
|---|---|---|---|
| `LOC:DF` | site | Dubai Factory | Dubai Factory |
| `LOC:MP` | building | Dubai Factory | Main Plant – Dubai Factory |
| `LOC:MP-PF1` | floor | Dubai Factory | Production Floor 1 – Main Plant |
| `LOC:MP-PF1-L1` | room | Dubai Factory | Line 1 – Production Floor 1 – Main Plant |
| `LOC:MP-PF1-L2` | room | Dubai Factory | Line 2 – Production Floor 1 – Main Plant |
| `LOC:MP-PF1-CB` | room | Dubai Factory | CNC Bay – Production Floor 1 – Main Plant |
| `LOC:MP-PF1-ASSE` | room | Dubai Factory | Assembly – Production Floor 1 – Main Plant |
| `LOC:MP-PF2` | floor | Dubai Factory | Production Floor 2 – Main Plant |
| `LOC:MP-PF2-L3` | room | Dubai Factory | Line 3 – Production Floor 2 – Main Plant |
| `LOC:MP-PF2-PS` | room | Dubai Factory | Paint Shop – Production Floor 2 – Main Plant |
| `LOC:MP-PF2-QL` | room | Dubai Factory | Quality Lab – Production Floor 2 – Main Plant |
| `LOC:MP-F2` | floor | Dubai Factory | Floor 2 – Main Plant |
| `LOC:MP-F2-MEZZ` | room | Dubai Factory | Mezzanine – Floor 2 – Main Plant |
| `LOC:MP-F2-CR` | room | Dubai Factory | Control Room – Floor 2 – Main Plant |
| `LOC:MP-ROOF` | floor | Dubai Factory | Roof – Main Plant |
| `LOC:MP-ROOF-CD` | room | Dubai Factory | Chiller Deck – Roof – Main Plant |
| `LOC:MP-ROOF-PR` | room | Dubai Factory | Plant Room – Roof – Main Plant |
| `LOC:BLD-A` | building | Dubai Factory | Building A – Dubai Factory |
| `LOC:BLD-A-GF` | floor | Dubai Factory | Ground Floor – Building A |
| `LOC:BLD-A-GF-GRG01` | room | Dubai Factory | Generator Room GR-01 – Ground Floor – Building A |
| `LOC:BLD-A-GF-ER` | room | Dubai Factory | Electrical Room – Ground Floor – Building A |
| `LOC:BLD-A-F2` | floor | Dubai Factory | Floor 2 – Building A |
| `LOC:BLD-A-F2-OFFI` | room | Dubai Factory | Offices – Floor 2 – Building A |
| `LOC:BLD-A-F2-CORR` | room | Dubai Factory | Corridor – Floor 2 – Building A |
| `LOC:BLD-A-ROOF` | floor | Dubai Factory | Roof – Building A |
| `LOC:BLD-A-ROOF-AD` | room | Dubai Factory | AHU Deck – Roof – Building A |
| `LOC:BLD-B` | building | Dubai Factory | Building B – Dubai Factory |
| `LOC:BLD-B-GF` | floor | Dubai Factory | Ground Floor – Building B |
| `LOC:BLD-B-GF-PR` | room | Dubai Factory | Pump Room – Ground Floor – Building B |
| `LOC:BLD-B-GF-WORK` | room | Dubai Factory | Workshop – Ground Floor – Building B |
| `LOC:BLD-B-F1` | floor | Dubai Factory | Floor 1 – Building B |
| `LOC:BLD-B-F1-TC` | room | Dubai Factory | Tool Crib – Floor 1 – Building B |
| `LOC:BLD-B-F1-STOR` | room | Dubai Factory | Stores – Floor 1 – Building B |
| `LOC:MW` | building | Dubai Factory | Main Warehouse – Dubai Factory |
| `LOC:MW-GF` | floor | Dubai Factory | Ground Floor – Main Warehouse |
| `LOC:MW-GF-RECE` | room | Dubai Factory | Receiving – Ground Floor – Main Warehouse |
| `LOC:MW-GF-ZA` | room | Dubai Factory | Zone A – Ground Floor – Main Warehouse |
| `LOC:MW-GF-ZB` | room | Dubai Factory | Zone B – Ground Floor – Main Warehouse |
| `LOC:MW-GF-DISP` | room | Dubai Factory | Dispatch – Ground Floor – Main Warehouse |
| `LOC:MW-MEZZ` | floor | Dubai Factory | Mezzanine – Main Warehouse |
| `LOC:MW-MEZZ-SS` | room | Dubai Factory | Spares Store – Mezzanine – Main Warehouse |
| `LOC:DO` | site | Dubai Office | Dubai Office |
| `LOC:HO` | building | Dubai Office | Head Office – Dubai Office |
| `LOC:HO-BLD-A` | floor | Dubai Office | Building A – Head Office |
| `LOC:HO-BLD-A-R101` | room | Dubai Office | Room 101 – Building A – Head Office |
| `LOC:HO-BLD-A-R102` | room | Dubai Office | Room 102 – Building A – Head Office |
| `LOC:HO-BLD-A-IS` | room | Dubai Office | IT Store – Building A – Head Office |
| `LOC:HO-BLD-A-RECE` | room | Dubai Office | Reception – Building A – Head Office |
| `LOC:HO-BLD-B` | floor | Dubai Office | Building B – Head Office |
| `LOC:HO-BLD-B-MARK` | room | Dubai Office | Marketing – Building B – Head Office |
| `LOC:HO-BLD-B-FINA` | room | Dubai Office | Finance – Building B – Head Office |
| `LOC:HO-BLD-B-BR` | room | Dubai Office | Board Room – Building B – Head Office |
| `LOC:EC` | site | Education City | Education City |
| `LOC:AB` | building | Education City | Admin Block – Education City |
| `LOC:AB-GF` | floor | Education City | Ground Floor – Admin Block |
| `LOC:AB-GF-LOBB` | room | Education City | Lobby – Ground Floor – Admin Block |
| `LOC:AB-GF-SECU` | room | Education City | Security – Ground Floor – Admin Block |
| `LOC:AB-F2` | floor | Education City | 2nd Floor – Admin Block |
| `LOC:AB-F2-MR3` | room | Education City | Meeting Room 3 – 2nd Floor – Admin Block |
| `LOC:AB-F2-SR` | room | Education City | Staff Room – 2nd Floor – Admin Block |
| `LOC:AB2` | building | Education City | Admin Building – Education City |
| `LOC:AB2-CORE` | floor | Education City | Core – Admin Building |
| `LOC:AB2-CORE-LL` | room | Education City | Lift Lobby – Core – Admin Building |
| `LOC:AB2-CORE-PR` | room | Education City | Plant Room – Core – Admin Building |

## Project layout and QA

- Rules and the project map: `CLAUDE.md`. Build prompts: `prompts/`. Design images: `design/`.
- Final QA (Prompt 19): `docs/QA_REPORT.md` — button audit tables per module in `docs/qa/`, design check notes,
  cross-module flow results (`test/flows_test.dart`) and consistency checks (`test/data_check_test.dart`).

## Client demo

The client demo is a **screen-level allow-list** in `lib/app/client_demo.dart`
(reference screenshots: `design/client_demo/`, one file per screen):

```dart
// Set to false to restore the full app (current build: full app).
const bool kUseClientDemo = false;
```

- `kDemoScreens` — the allowed screens, as route patterns from `routes.dart` (`/assets/detail/:assetId`).
  Today: Splash, Login, Forgot Password, Authenticator, Home, Work hub, All Modules, Assets list, Asset
  detail (all 8 tabs), Scan & Identify (QR / NFC / RFID / BLE + Manual Entry), Movement & Custody hub,
  Transfer Asset, Maintenance hub, Work Order detail (Overview tab), Inventory hub, Part Details and Stock
  Movement (Stock History tab).
- `DemoAction` / `kDemoActions` — named in-screen actions (a control that opens a sheet, dialog, picker
  or form, or changes data). Only the actions in `kDemoActions` respond.
- Helpers: `demoCanOpen(route)` and `demoCanDo(action)`. Both return `true` when `kUseClientDemo` is false.

How it is enforced:

- **Router:** `demoRoutes()` in `app_router.dart` registers only the routes whose full path is in
  `kDemoScreens` (with their children filtered the same way). The redirect sends any other location to an
  unregistered path, and `onException` keeps the current screen, for `go` and `push` alike.
- **Controls:** `DemoGuard` (`lib/core/widgets/demo_guard.dart`) keeps a blocked control visible but
  inert: no navigation, no ripple, no SnackBar, no visual change. Use `DemoGuard(route: …)` /
  `DemoGuard(action: …)` around a button, or build a callback with `DemoGuard.push(context, route)`,
  `DemoGuard.go(…)`, `DemoGuard.open(route, onTap)` or `DemoGuard.tap(action, onTap)`, which return
  `null` when blocked. Tabs that are shown but can't be selected use `SegmentTab(enabled: …)`.
- In the demo a scan that finds an asset opens its Asset detail directly (Asset Identified is not on the
  list); an unknown tag shows "Tag not registered" with Scan Again.

### Allowing one more screen or action

1. **A screen:** add its route pattern to `kDemoScreens`, e.g. `'/work/maintenance/calendar', //
   Maintenance Calendar`. Its parent must be listed too (a child of an unlisted route is never
   registered). Every link, tile and row that leads to it starts working by itself, because they all go
   through `DemoGuard.push` / `DemoGuard.go` / `demoCanOpen`.
2. **An in-screen action:** add it to `kDemoActions`, e.g. `DemoAction.woOtherTabs` to let the Tasks /
   Parts / History / Documents tabs of a work order be selected. If the control is not guarded yet, add a
   new `DemoAction` value and wrap the control with `DemoGuard(action: …)`.
3. Run `flutter test test/client_demo_allowlist_test.dart`, then rebuild.

Set `kUseClientDemo = false` and rebuild to get the full app back. Client APK:

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Tests: `test/flutter_test_config.dart` turns the demo off (`debugClientDemo = false`) so the module tests
always see the full app. `test/client_demo_allowlist_test.dart` (the allow-list) and
`test/client_demo_test.dart` (the demo flows) switch it on themselves.
