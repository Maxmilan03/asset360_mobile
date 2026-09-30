# Asset360 — rules for every session
1. DESIGN FIDELITY: Before building any screen, open the matching image in design/ and study it.
   Match layout, order of sections, spacing, corner radius, colors, icons, font sizes and wording.
   Each design image shows 3 phone screens side by side (left, middle, right).
2. DATA: All data comes from lib/data/ (mock repositories). Never hard-code data inside widgets.
   Where a design image shows numbers or names that contradict the mock data, the MOCK DATA WINS.
3. COUNTS: Every count on a tab, badge, tile or "X of Y" is computed from the mock lists, so they
   always agree. Org-wide totals larger than 50 (e.g. 12,458 assets) are stored as summary figures;
   lists then show sample records plus a "Showing X of Y" footer.
4. EVERY TAP WORKS: Every button, tile, chip, tab, list row, icon and menu item must do something real:
   navigate, change state, open a dialog/bottom sheet, pick a photo/file, or start a simulated process.
   If a feature truly cannot work offline/hard-coded, show a SnackBar that says what WOULD happen
   (e.g. "Signed in with Google (demo)"). No dead taps, ever.
5. STATE: Actions change in-memory state through Riverpod notifiers, and every screen that shows that
   data updates immediately (e.g. closing a work order updates the list, badges and Home).
   State resets when the app restarts. That's fine for this demo.
6. DEMO CLOCK: "Now" is always DemoClock.now = Friday 25 Sep 2026, 10:30 AM (Asia/Dubai).
   All "5 mins ago", "Due in 1h 20m", "Overdue" etc. are computed from DemoClock, never DateTime.now().
7. STACK: Flutter stable, Dart 3, Material 3, flutter_riverpod (hand-written Notifier classes, no code
   generation), go_router, fl_chart, mobile_scanner, image_picker, file_picker, intl, shimmer.
   No freezed, no build_runner. Add other packages only when a prompt names them.
8. QUALITY: `flutter analyze` must be clean after every prompt. Reuse shared widgets from
   lib/core/widgets/. Don't duplicate UI code.
9. After finishing each prompt: run `flutter analyze`, fix everything, then give me a short summary
   of what was built and a checklist of every button on the new screens and what it does.

## Project map (kept up to date)
- `prompts/` — the build prompts, run in order (01 … 19). `design/` — the 16 design images.
- `lib/app/theme/` — `AppColors` (all colors, sampled from design/), `AppTheme`, text styles.
- `lib/app/router/` — `app_router.dart` (go_router + StatefulShellRoute), `routes.dart` (all path constants).
- `lib/core/widgets/` — shared widgets (AppHeader, PageTitle, chips, tiles, cards, sheets …).
- `lib/features/<module>/` — one folder per module screen set.
- Design notes: the bottom bar is WHITE with a raised violet Scan button (the designs win over prompt
  text that says "purple bottom bar"). Screens are a white rounded sheet overlapping the purple header.
- `lib/data/` — models/, mock/ (seed per module), repositories/ (one Notifier each). Counts come from the
  query extensions in each repository (e.g. `wos.mine(userId)`, `inspections.dueToday`, `issues.open`) —
  use those, never re-implement a count in a screen. `lib/data/data_check.dart` runs every check
  (screen: More → Settings → Developer → Data check; test: test/data_check_test.dart).
- Count definitions: My Work Orders = active WOs assigned to OR coordinated by the user (Home "Work Orders"
  tile shows the same number). Inspections "Due Today" (hub + Home) = not completed & due today (incl. overdue);
  "Due" tab = not completed, not overdue, due within 7 days. Summary figures (12,458 assets, 124 inventory
  items, 124 WIP, 64 documents, tracking 178) live in summary objects; lists show "Showing X of Y".
- Assets (prompt 05): `features/assets/` — list, Asset 360° detail (+ `asset_tabs.dart`, `asset_iot_tab.dart`,
  `asset_overview_tab.dart`, `asset_actions.dart` sheets). Finance/age/warranty maths is the `AssetFinance` extension
  in `assets_repository.dart`; "My Assets" = `myAssetsProvider`. Forms opened for one asset use
  `Routes.withAsset(route, id)` (`?asset=`). `features/common/scan_capture.dart` = camera scan that returns a code.
  Shared widgets added: `Code39Barcode`, `IconFilterChip`, `TagLabel`.
- Registration (prompt 06): `features/registration/` — hub (+ bulk CSV panel, `bulk_import.dart` validation),
  5-step `register_asset_screen.dart` (+ `registration_review.dart`). Hub tiles pass a `RegistrationPrefill` as the
  route `extra`. Uniqueness = `AssetsNotifier.ownerOf(value)` (ID / tag / barcode). Location tree, departments,
  spare IoT devices and the sample CSV are in `data/mock/registration_mock.dart`; `unlinkedIotDevicesProvider`,
  `sessionRegistrationsProvider`, `assetTypesProvider` in `assets_repository.dart`. Shared: `QrCode` (real,
  scannable encoder, tested in `test/qr_code_test.dart`), `core/csv.dart`.
- `DemoClock.now` starts at 25 Sep 2026 10:30 AM and runs forward; `DemoClock.frozen` pins it (tests).
