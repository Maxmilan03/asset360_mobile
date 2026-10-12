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
