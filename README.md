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

## Client demo mode

`lib/app/feature_flags.dart` holds one switch:

```dart
// Set to false to restore the full app.
const bool kClientDemo = true;
```

With `kClientDemo = true` the app is cut down to what the client should see:

- **Works fully:** Splash, Login (Remember me, password eye, validation, lockout), simulated Google /
  Microsoft sign-in, Forgot Username or Password, Authenticator code screen (code `123456`), the Home
  dashboard with pull-to-refresh, the bottom bar's **Scan** button (live camera scan; a known asset ID
  shows its card, an unknown code shows "Tag not registered") and **More** button (All Modules sheet
  with the 13 tiles plus a **Logout** row, so the login can be replayed).
- **Visible but inert:** everything else on Home (KPI tiles, site picker, quick actions, My Tasks,
  View All / Calendar / Map / Details links, chart legends, list rows), the header bell / avatar /
  name menu, Assets and Work in the bottom bar, and the 13 module tiles. Inert means no navigation,
  no ripple and no SnackBar. This is done by `DemoGate` (`lib/core/widgets/demo_gate.dart`):
  `DemoGate(child: …)` or `onTap: DemoGate.tap(…)`.
- **Not registered:** every other route (Assets, Work, More branches, Registration, Maintenance, …).
  `app_router.dart` leaves them out with `if (!kClientDemo) ...[ … ]`. Their code stays in the project.

Set the flag to `false` and rebuild to get the full app back. Client APK:

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`test/client_demo_test.dart` runs only in demo mode. The other widget tests cover the full app, so run
them with the flag set to `false`.
