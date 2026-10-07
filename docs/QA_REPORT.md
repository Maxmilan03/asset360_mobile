# Asset360 — final QA report (Prompt 19)

Date: 5 Oct 2026. Scope: every screen under `lib/features/`, the shared widgets in `lib/core/widgets/` and the mock data.

## 1. Button audit — Screen | Element | Action

The full tables (about 900 rows, one table per screen) are in `docs/qa/`:

| Group | Screens | Rows | Fixed |
|---|---|---|---|
| [A](qa/A-auth-home-assets-registration.md) | Login, Forgot, Authenticator, Home, My Tasks, My Approvals, Assets list, Asset 360° (8 tabs), Registration (hub, 5 steps, bulk) | 172 | 1 |
| [B](qa/B-scan-tracking-movement.md) | Scan (all modes), Asset Identified, Scan History, Tracking hub (4 tabs), Asset Tracking (5 tabs), Movement hub, Transfer, Custody, Request detail, History | 184 | 2 |
| [C](qa/C-maintenance-inspection-issues.md) | Maintenance hub, WO detail (4 tabs + tasks), Create WO, PM / Breakdowns / Service History, Inspection hub / detail / create, Findings, Issues list / report / detail | 147 | 3 |
| [D](qa/D-alerts-inventory-wip.md) | Alerts, Alert detail, Notifications + settings, Inventory hub, Part detail, Stock Movement, POs, Requests, Stock Reports, WIP hub, WIP Tracking, Production Order | 157 | 7 |
| [E](qa/E-documents-audit-sync.md) | Documents list / detail / add / viewer, Asset Audit list / session / Asset Found / results / report / Compliance, Offline Sync, Pending Sync, Syncing Data | 141 | 5 |
| [F](qa/F-profile-settings-help-more.md) | Profile, Settings, Data check, Demo tags, Help, Report a bug, All Modules, Work hub, Contracts, Financial, Reports, Administration | 111 | 8 |

Rows counts include table headers. "Fixed" rows are marked "(fixed)" in the tables.

Result: **no empty, `() {}`, TODO or print-only handlers anywhere** (static scan of 619 `onTap` / `onPressed` /
`onLongPress` handlers, then a manual read of each screen). Things fixed:
- Elements that looked tappable but did nothing: asset History movement rows, Geofencing map pins, the camera icons on
  Part Details / Stock Movement (now scan a part label), Contracts status chips (now filters), Financial "Value by
  Category" rows, the Work hub "My Tasks" (wrongly empty; now the same list as Home).
- Taps that only showed a "(demo)" SnackBar now do the real thing: WO voice-note playback, Reports Export (CSV save /
  copy), Audit Report Share (copies the summary), Print demo tags (large QR dialog), Production Order empty note.
- Empty-state action buttons added everywhere a list can be empty ("Clear filters", "Show all", "Add Document" …).

## 2. Design check

Each design image was compared with its screens; per-module notes are in the group files (section 2). Changed:
Registration Recent Scans rows (date + pin), Tracking Recent Activity (one card per event), WO rows without chevron,
camera glyph on WO / inspection headers, issue rows with the priority chip after the issue number, Add Document
subtitle + type icon, dark-safe notification rows. Kept on purpose (data corrections from the prompts): every count,
ID and name comes from the mock data (e.g. FL-012 not FLT-012, GEN-00045, MO- numbers, BR-6205 6 reserved / 30
available, sync ring 76%, audit tabs = tiles), and the prompt-mandated wording ("Can't access your authenticator?",
"Production Order").

## 3. Consistency check

`test/data_check_test.dart` runs the Data check screen logic (`runDataChecks`) plus two new tests:
- every tab / badge / tile count equals its list length, stock ledger balances chain to the stock on hand, org totals
  add up (all groups pass);
- **every asset ID shows the same name, location and status everywhere** — this found a real bug: 13 issues and 30
  alerts had location "—" (shown as "—" on the Issues list and Alert details) and 6 more had a different spelling of
  the asset's location. Seeds now copy the asset's location (`seedLocationOf`), and moving an asset carries its open
  issues / active alerts along (`followAsset`). The Data check screen has the same rule.

## 4. Cross-module flows — `test/flows_test.dart`

| # | Flow | Result |
|---|---|---|
| 1 | Report a critical Breakdown issue → critical alert + bell notification → Create WO → In Progress (asset Under Maintenance) → complete all tasks → close → asset Active, org totals and Home "Work Orders" back | Pass |
| 2 | Move (transfer, with the signed-in user picked as approver) → Home → My Approvals → Approve (UI) → Mark In Transit (UI) → Mark as Received (UI) → location shows in Asset detail and the Tracking asset list; alerts follow | Pass |
| 3 | Inspection INS-2026-0045 flow rate 850 LPM (range 400–600) → negative answer → finding → WO linked to the finding | Pass |
| 4 | Offline → complete a WO task + add a task photo → Pending Sync has the WO item and the photo → back online (Wi-Fi) → auto-sync uploads all → WO no longer "saved offline" | Pass |
| 5 | Receive PO-2026-0131 → stock +20, GRN entry, history balances chain, PO status Received | Pass |

Flow 2 needed a product change (agreed): Rex's transfers went to Ahmed Ali and only Rex can sign in, so the Transfer
form now has an **Approver** field (Ahmed by default, "self-approve (demo)" for the signed-in user). The UI test also
caught that the Transfer form kept the previous step's scroll position; every step now opens at its top.

## 5. Robustness

- Every module test file opens its screens at **360×640 and 430×932**, scrolls each to the end and fails on any layout
  exception. Overflows found and fixed: auth button labels and Forgot radio labels, Create WO "Assign to" dropdown
  (344 px), Add Zone with the keyboard up, IoT device picker sheet, Cost Summary legend, issue row chip.
- Long text: titles, names, IDs, locations and subtitles in rows / cards / page titles use ellipsis.
- Scrolling and keyboard: every page is a scroll view; sheets that held fixed columns (Renew, Registered, IoT picker,
  Admin Add) now scroll, so fields stay above the keyboard.
- Back navigation: all routes stay inside the shell; Back returns to the origin (navigation / shell tests).
- Loading shimmer + empty state on every list (`LoadingGate` / `SliverLoadingGate` / `GatedSliverList`).

## 6. Performance

Long or growing lists build lazily (`SliverList` / `ListView.builder`: Assets, Maintenance, Inspection, Issues,
Alerts, Notifications, Inventory, Stock History, POs, Requests, WIP, Documents, Pending Sync, Syncing, Scan History,
Activity Log, Contracts …). The `prefer_const_*` lints are on; `dart fix` added 225 `const`s.

## 7. Analyze and tests


- `flutter analyze`: **No issues found!** (with the `prefer_const_*` lints on).
- `flutter test`: **149 passed, 1 skipped** (`client_demo_test.dart` runs only when `kClientDemo = true`), 0 failed.
- `flutter build apk --release --split-per-abi`: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (30.4 MB).
- Not covered by automated tests (need the phone's camera / image picker): avatar photo change, bug-report
  screenshot, live camera scanning; install on a real phone has to be checked by hand.
