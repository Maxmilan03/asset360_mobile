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
   No freezed. build_runner for drift only (`dart run build_runner build --delete-conflicting-outputs --force-jit`).
   Add other packages only when a prompt names them (also: drift, drift_flutter, sqlite3_flutter_libs,
   path_provider, nfc_manager, shared_preferences, printing, pdf, share_plus, video_player).
   Scans, locations and tag links are stored in SQLite via drift (lib/data/db/). Screens read them through
   Riverpod StreamProviders using .watch(). Every scan from any source goes through ScanService.
8. QUALITY: `flutter analyze` must be clean after every prompt. Reuse shared widgets from
   lib/core/widgets/. Don't duplicate UI code.
9. After finishing each prompt: run `flutter analyze`, fix everything, then give me a short summary
   of what was built and a checklist of every button on the new screens and what it does.
10. The bottom bar with the centre Scan button is visible on every screen after login. Never create a screen
   or route that hides it. Every route is a child of the StatefulShellRoute (never push onto the root
   navigator); dialogs and pickers pass `useRootNavigator: false` so they open on the tab's navigator, under
   the bar. Only Splash, Login, Forgot Password, Authenticator, Authenticator Setup and Auth diagnostics (the
   pre-login copy; Settings opens the in-shell one) are outside the shell.

## Project map (kept up to date)
- `prompts/` — the build prompts, run in order (01 … 19). `design/` — the 16 design images.
- `lib/app/theme/` — `AppColors` (all colors, sampled from design/), `AppTheme`, text styles.
- `lib/app/router/` — `app_router.dart` (go_router + StatefulShellRoute), `routes.dart` (all path constants).
- `lib/core/widgets/` — shared widgets (AppHeader, PageTitle, chips, tiles, cards, sheets …).
- `lib/features/` — one folder per bottom-bar tab (matches the bar and `routes.dart`):
  ```
  lib/features/
    auth/                 splash, login, forgot password, authenticator
    home/                 home, my tasks, my approvals, quick actions
    assets/               asset list + Asset 360° detail
      scan/               scan, scan result, scan history, demo scan
    work/                 work_hub_screen.dart
      maintenance/  inspection/  issues/  wip/  movement/  audit/
    more/                 all_modules.dart
      registration/  tracking/  documents/  inventory/  alerts/  sync/
      insights/           reports, financial, contracts & warranty
      account/            profile, settings (+ data check, demo tags), help, admin
  ```
  Shared pickers (`asset_picker.dart`, `location_picker.dart`, `scan_capture.dart`) live in `lib/core/widgets/`
  and are exported from `widgets.dart`.
- RULE: New screens go in the folder of the bottom-bar tab their route lives under (see routes.dart). Use package imports only.
- Shell: 4 branches (Home, Assets, Work, More) with `branchKeys` in `app_router.dart`. The bar's Scan button
  pushes `Routes.scanFrom(location)` (scan routes exist under every tab, like notifications/profile, so Back
  returns to the origin); `Routes.scan` / `Routes.scanHistory` are markers resolved by `openRoute`. More opens
  the All Modules sheet (`features/more/all_modules.dart`: `allModules`, `moreModules`, `openModule`) on the
  current branch navigator; `/more` itself is the All Modules page. New modules: Audit & Compliance
  (`/work/audit`), Contracts & Warranty, Financial, Reports & Analytics, Administration (`/more/...`).
  `test/shell_test.dart` visits every route and checks the bar + Scan button.
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
  `Routes.withAsset(route, id)` (`?asset=`). `core/widgets/scan_capture.dart` = camera scan that returns a code.
  Shared widgets added: `Code39Barcode`, `IconFilterChip`, `TagLabel`.
- Registration (backend-aligned): `features/more/registration/` — hub (+ bulk CSV panel, `bulk_import.dart`, My Drafts),
  `register_asset_screen.dart` = web steps 1–5 (`step_basic/classification/location/purchase/additional.dart`) + mobile
  Review (`registration_review.dart`); field widgets in `registration_widgets.dart` / `registration_fields.dart` take an
  `error:` keyed by backend path. Model = `data/models/asset_registration.dart` (`AssetRegistration`, field-for-field the
  swagger DTOs in `docs/api_samples/swagger.json`, `toJson`/`fromJson`; app-only Parent Asset / IoT / Assess ratings in
  `local` = `RegistrationLocalExtras`, stored via `toStorageJson`, never sent). Asset ↔ registration mapping =
  `asset_registration_mapping.dart` (`toAsset`, `toRegistration`). Rules + messages = `data/validation/
  asset_registration_validator.dart` (Next = required + rules, Save as Draft = rules only, keys like "Purchase.PurchaseCost").
  Drafts = `registration_drafts_repository.dart` (shared_preferences, survive restart, `assetRegistrationId` DRAFT-0001,
  `currentStep`). Category / Sub Category / Asset Type / Criticality are entered in step 2 only; criticality is written to
  both basicInformation and classification. Location IDs = location codes (`locationCodeOf` in data/db/location_seed.dart).
  Value lists: ONLY `data/reference/asset_options.dart` (statuses = 4 values; any other raw value, e.g. Inactive / Retired,
  is grey and counts as Other via `AssetStatus.bucketOf`; TEMP lists until the Master Data API). Category tree, countries:
  `registration_options.dart`; spec templates: `technical_templates.dart`. Asset status chips: `AssetStatusChip`.
  Web screenshots: `design/web_registration/`. Report: `docs/registration_backend_report.md`. Tests: test/registration_test.dart
  (swagger field names, round trip, validator, drafts restart, end-to-end generator).
- Backend API (services called DIRECTLY, gateway 5296 unused): `lib/data/api/` — `api_config.dart` (`kUseApi` /
  `apiMode` (tests: `debugApiMode`), `kApiBaseUrl` = Asset service 5401, `kMediaBaseUrl` = Media 5300, `kAuthBaseUrl` =
  login 5018, optional `kDevToken`; dart-defines only; `BackendService` enum = base URL + config problem per service),
  `api_client.dart` (`dioProvider` / `apiClientProvider` = Asset, `mediaDioProvider` / `mediaClientProvider` = Media;
  `AuthInterceptor` = session access token if any (never blocks), one shared refresh on 401 then retry),
  `media_api.dart` (`MediaApi.upload` → POST /api/media/upload, `resolveMediaUrl` localhost → MEDIA_BASE_URL,
  `mediaHeadersProvider`), `api_exception.dart` (400 →
  `fieldErrors`, server `message` first), `auth_api.dart` (login service, own Dio, every call recorded redacted in
  `auth_diagnostics.dart`), `auth_models.dart` (TOLERANT parsing: `LoginResult`, `TokenPair` (expiresIn / expiresAt /
  JWT exp / 30 min), `CurrentUser`, `AuthRole`, `redactSecrets`), `token_store.dart` (refresh token in
  flutter_secure_storage only with Remember me). Session: `data/repositories/auth_repository.dart` (`AuthNotifier`:
  signedOut → twoFactorPending → signedIn; `enterApp()` after the 1 s success animation flips `sessionProvider`, which
  the router reads; `restore()` on Splash). `currentUserProvider` shows the /me user in API mode (person record stays
  the demo user so mock modules keep working). Screens: `features/auth/authenticator_setup_screen.dart`,
  `auth_diagnostics_screen.dart` (`/auth-diagnostics`, `/more/settings/auth-diagnostics`); Login / Authenticator /
  Splash / confirmLogout / Profile branch on `apiMode`. Shared: `showContactAdminSheet`, `showSignInSuccess`
  (auth_widgets.dart). `connection_repository.dart` (Test connection = GET /health on AUTH / ASSET / MEDIA) + `backend_connection_card.dart` (Administration). Sources:
  `docs/api/useraccount_swagger.json` (requests only), `docs/api/openapi.json` (not downloaded yet); unknowns in
  `docs/questions_for_backend.md`. Tests: test/api_client_test.dart, test/auth_api_test.dart (fake adapters).
- Assets live phase (apiMode = true: NO mock assets anywhere; apiMode = false unchanged): API `lib/data/api/assets/`
  (`assets_api.dart` `AssetsApi` / `assetsApiProvider`: list, filters, get, lookup, drafts + steps + submit, options,
  categories / types / models, images, documents, components tree, condition, criticality; `asset_api_models.dart`; full
  record = `AssetRegistration`). Providers: `live_assets_repository.dart` (`liveAssetListProvider(query)` paged 20,
  `assetSummaryProvider`, `recentLiveAssetsProvider`, `liveAssetProvider(id)` + images / documents / tree / condition /
  criticality, `liveAssetProviders(id)` to invalidate, dropdown providers, `liveFavoritesProvider` = device only,
  `myUserIdProvider`), `live_uploads.dart` (`AssetUploader`: `AssetFileRules.check` → Media upload → asset-images /
  asset-documents), `live_registration_repository.dart` (server drafts, `applyServerReply`). Screens branch on `apiMode`:
  `features/assets/live/` (list, filter/sort sheets, detail `live_detail_*`, upload, condition, more actions),
  registration `live_options.dart` (`RegLists`), Home `sections/live_home.dart` (`HomeNotAvailableCard`), scan
  `core/scanning/live_asset_lookup.dart` (GET /lookup, fallback search + exact match). No backend yet → `NotAvailableYet` /
  `showNotAvailableYet` (core/widgets/live_states.dart). Tests: `test/live/` (`FakeAssetBackend`, `no_mock_assets_test.dart`).
- Scan (prompt 07): `features/assets/scan/` — `scan_screen.dart` (QR camera + simulated NFC/RFID/BLE, Manual Entry, Multi Scan,
  debug "Simulate scan" chip), `scan_result_screen.dart` (Asset Identified), `scan_history_screen.dart`. Every scan goes
  through `openScannedCode` (`scan_flow.dart`), which records history and routes. Code matching = `ScanHistoryNotifier.resolve`
  (asset ID/tag/barcode/serial, part number, `LOC:` location). Beacons/demo tags in `scans_mock.dart`. Shared action grid =
  `assetActions()` in `asset_actions.dart`. Developer → Print demo tags = `more/account/demo_tags_screen.dart`.
  Shared: `PulseRings`, `SheetTitle`/`sheetFrame` (dialogs.dart), `AppLauncher.openAppSettings`.
- Tracking (prompt 08): `features/more/tracking/` — hub (`tracking_hub_screen.dart`: Live Map / Asset List / Sensors /
  Geofencing), `asset_tracking_screen.dart` (5 tabs + route playback sheet), `telemetry_view.dart` (Telemetry tab +
  full-screen zoomable chart), `tracking_pages.dart` (activity log, Add Zone drawing), `tracking_map.dart` (`TrackingMap`:
  badge pins, callout, trail, geofences, 2D/3D, zoom). Data: `trackingProvider` (geofences, allowed zones, zone events),
  `trackingLiveProvider` (watch it to run the 3 s FL-012 simulation), `sensorsProvider`, `metricsFor` +
  `telemetryHistory` (deterministic per asset/metric/range), `routePlayback`. Shared: `TrendChart`, `Sparkline`
  (core/widgets/trend_chart.dart), `SignalBars` (tracking_widgets.dart). Home's floor-plan legend keeps the design-02
  colours (`trackedKindColor`); the tracking module uses `pinLook` (design 06).
- Movement (prompt 09): `features/work/movement/` — hub (`movement_hub_screen.dart`), 5-step `transfer_asset_screen.dart`
  (`?asset=` / `?assets=` → one request per asset), `custody_screen.dart` (Check Out / Check In / Assign Custodian /
  Return, enum `CustodyAction`), `movement_pages.dart` (request detail with Approve/Reject/Cancel/In Transit/Received,
  Movement History). Shared: `MovementSummary` (Review layout, read-only in detail), `MoveStatusTimeline`,
  `rejectMovement` (also used by My Approvals), `AssetChooser`, `SelectedAssetCard`. `MovePlace.party` = department /
  person destination (asset location unchanged); `MovePlace.assetLocation` = location written on completion.
  Core: `AttachmentTile` + `showAttachmentPreview`, `DateBox(firstDate:)`, read-only `PhotoStrip` (no `onAdd`).
- Maintenance (prompt 10): `features/work/maintenance/` — hub (`maintenance_hub_screen.dart`, `?tab=mine|pm|overdue|all`),
  `work_order_screen.dart` (Overview / Parts / History / Documents, `?tab=`), `wo_tasks_tab.dart`, `wo_actions.dart`
  (`changeWoStatus` = the status rules: On Hold asks a reason, Completed/Closed need every task done, Closed runs the
  close-out with resolution, labour, parts used and signature), `maintenance_lists.dart` (PM schedules, Breakdowns,
  Service History). The editable task is `WorkOrder.openTaskId` (in progress, else first unfinished). Shared:
  `SignaturePad` / `SignaturePainter` (eager pan: wins over scroll views), `DueCountdownChip`, `PersonLine`, `WoRow`.
  `ChipTone.forPriority`: Low is blue (prompt 10).
- Checklist engine (prompt 11): `lib/core/checklist/` — `checklist.dart` (`CheckItem` types tick / choice / yesNo /
  number (unit + range) / text / photo / signature; first option = good answer, others negative; `CheckSection`,
  `ChecklistX.updateItem`) and `checklist_widgets.dart` (`CheckItemView`, `CheckSectionHeader`, `ChecklistProgress`,
  `RadioChip`). Used by inspections and by WO tasks (`WoTask.checklist` is `List<CheckItem>` of tick items).
- Inspection (prompt 11): `features/work/inspection/` — hub (`InsView` mine/due/overdue/all + dueToday/completed tiles),
  `inspection_screen.dart` (Details / Checklist with auto "Add Finding" on negative answers, Summary & Submit with
  score + signature / Findings / Documents), `create_inspection_screen.dart` (templates = `inspectionTemplates` in
  inspections_mock.dart), Findings list + Finding detail (Create Work Order via `WoPrefill` route extra → finding
  becomes Action Taken / Close Finding). Home "Inspections Due Today" opens `?tab=dueToday`.
- Issues (prompt 12): `features/work/issues/` — `issues_screen.dart` (`?tab=all|mine|open|resolved`, In Progress tile list,
  swipe right = Mark Resolved on your own open issues, `IssueRow`), `report_issue_screen.dart` (`?asset=`; Critical
  issues raise an alert + notification in `IssuesNotifier.report`), `issue_detail_screen.dart` (Details with inline edit
  / Work Orders / Timeline with comments / Attachments; Close Issue needs resolution notes). Open = Open + In Progress
  + On Hold. Create Work Order uses `WoPrefill(issueId:, photos:)` → the WO links back to the issue.
  `PhotoStrip(allowVideo:, addLabel:)` / `pickPhoto(allowVideo:)` add "Record video".
- Alerts (prompt 13): `features/more/alerts/` — `alerts_screen.dart` (severity tiles → tabs, swipe left = acknowledge,
  long-press multi-select with bulk Acknowledge / Resolve, a live alert every `liveAlertEvery` (60 s) while on screen via
  `AlertsNotifier.raiseLive` + MaterialBanner), `alert_detail_screen.dart` (Details with trend to the alert time /
  History = `earlierOf` / Actions log / Related Assets = `relatedTo`; Acknowledge → Resolve; Create Work Order with
  `WoPrefill(alertId:)`), `notifications_screen.dart` (bell target under every tab; `notificationRoute` deep links,
  swipe delete + Undo, ⋮ Mark all as read / settings → `NotificationSettingsScreen`, `notificationSettingsProvider`).
  `AlertsNotifier.raise` always posts a notification, so other modules (critical issues) feed the bell.
- Inventory (prompt 14): `features/more/inventory/` — hub (`?tab=all|low|reorder|reserved`, "Showing 20 of 124"),
  `part_detail_screen.dart` (+ `inventory_actions.dart`: edit levels, manage bin / transfer, ⋮ Issue to Work Order,
  Stock Count Adjustment, spec sheet), `stock_movement_screen.dart` (per part or all parts; History / Usage / Reserved
  / Purchase Orders), `procurement_screens.dart` (PO list / detail with Receive (GRN) / PO form, My Requests + Request
  Part form, Stock Reports, `showPartPicker`). Ledger rule: `StockTxn.balanceAfter` = stock on hand; reservations
  carry `reservedChange` and leave the balance unchanged (BR-6205: reserved 6 = WO-0138 4 + WO-0045 2, available 30,
  opening balance 1). Every change goes through `InventoryNotifier._updatePart`, which posts "Stock Level Low" when
  available drops to the reorder level. `WorkOrdersNotifier.issuePart` = Issue to Work Order. Shared:
  `BarSeriesChart` (trend_chart.dart).
- WIP (prompt 15): `features/work/wip/` — hub (`wip_hub_screen.dart`: KPI tiles → tabs, Scan to Move / Start / End
  Operation / Report Issue, `showEndOperationSheet`), `wip_unit_screen.dart` (WIP Tracking for a unit serial),
  `production_order_screen.dart` (titled "Production Order"; MO- numbers). `ProductionOrder.currentStation` is derived
  from the running / failed / next operation's `location`, so list and detail always agree; `locationPath` likewise.
  `WipNotifier`: `startOperation` (next in sequence only), `pause/resumeOperation`, `endOperation` (good/scrap, QC;
  a failed QC = red step + `QualityCheck` finding + Delayed), `moveToNext`, `rework`, `completeOrder` (all ops done),
  `issueComponent` (Inventory `TxnType.issuedToProduction`). `liveMinutes` = live actual duration (capped 2×).
  Report Issue accepts `IssuePrefill(reference:)` (route extra) for non-asset issues; issue type "Production".
- Documents (prompt 16): `features/more/documents/` — `documents_screen.dart` (`?tab=all|manuals|warranty|certificates|
  others` or a tile `expiring|compliant|pending`; tiles filter, tabs = `summary.byBucket`), `document_detail_screen.dart`
  (inline edit, Related Documents = other docs of the asset, Versions with Restore), `add_document_screen.dart`
  (`?asset=`; `AddDocumentScreen.debugPickFile` replaces file_picker in tests), `document_viewer_screen.dart` (pdfx for
  PDFs, zoomable images; `/view?version=`), `document_widgets.dart` (`DocRow`, `DocMenuButton` ⋮ actions, download via
  `FilePicker.saveFile`, `pickDocumentFile` 10 MB limit). Counts: `DocumentsState.expiringSoon/compliant/pending` =
  summary figures (undetailed docs) + `expiryState` of listed docs (Expiring Soon = expiry within 30 days of DemoClock).
  `DocType.expires` (Warranty, Certificate, Contract / AMC, Insurance) decides whether an expiry date is asked.
- Asset Audit (prompt 17): `features/work/audit/` — `asset_audit_screen.dart` (`/work/audit?tab=mine|assigned|completed`
  or tile `inProgress|pending`; tabs = tiles, all from `AuditQueries` on the user's audits), `audit_session_screen.dart`
  (mobile_scanner card, Search / Manual Entry, unknown code → `_UnregisteredSheet` → Register now, ⋮ Complete / Export
  Report / Pause), `audit_asset_screen.dart` (Asset Found; pops the saved result; Tag ID label = scan method),
  `audit_pages.dart` (Create Audit Campaign, result lists, report), `compliance_screen.dart` (`/work/audit/compliance`,
  linked from the audit list). Counts: `Audit.verified/…` are summary figures that include the sample `entries`;
  `AuditsNotifier.record` moves them (re-audit replaces), `updateLocation` adds a completed `MoveType.auditCorrection`
  movement; `complete` turns `remaining` into Not Found. Scope = `auditScope` (site + buildings + categories).
  Shared: `showLocationPicker` (core/widgets/location_picker.dart, "Building / Floor – Zone").
- Offline Sync (prompt 18): `networkProvider` (network_repository.dart: connectivity_plus + Developer "Simulate offline";
  `isOfflineProvider`). Every module's create / update calls `ref.queueOffline(kind, title, subtitle, refId:)`
  (sync_repository.dart) — offline only; changes to the same record collapse into one item, photos / files stay separate;
  WOs and inspections get `savedOffline` until synced. The upload engine lives in `SyncNotifier` (`startRun`,
  `cancelRun` = stop after the current item, `retry`, `dismissRun`; Timer-driven, 0.6–1.0 s per item, attachments
  1.2–1.5 s, 10% failures with Developer "Simulate sync failures"); going back online starts it when Automatic Sync
  allows the connection. `OfflineBanner` (core/widgets, inside `AppScaffold`) shows offline / background sync.
  Screens: `features/more/sync/` — `offline_sync_screen.dart`, `pending_sync_screen.dart` (`?tab=` = `SyncKind` name),
  `syncing_screen.dart`; `sync_widgets.dart` (`startSync` = offline "Try anyway (demo)", `syncItemRoute` = View Item).
- Profile / Settings / Help (prompt 19): `features/more/account/profile_screen.dart` (Edit Profile, Change Password =
  `passwordRules`, Switch Site, Logout via `confirmLogout` in core/session_actions.dart), `features/more/account/` (settings) (Appearance =
  `AppColors.dark`, Developer section only in `kDebugMode`, `resetDemoData`), `features/more/account/help_screen.dart` (`helpFaqs`,
  `ReportBugScreen`). Tests: `test/profile_settings_test.dart`.
- Home drill-downs: `features/home/drilldowns/` (one screen per file, frame = `DrilldownPage`: back arrow, title,
  pull-to-refresh shimmer) at `/home/asset-overview`, `maintenance-performance`, `activities?view=list|calendar`,
  `recent-alerts`, `asset-location`, `asset-health`, `cost-summary`, `recent-assets` (not in the client demo allow-list,
  so the Home links stay inert there). Home sections live in `features/home/sections/` (one widget per card); shared
  colours / icons in `features/home/home_style.dart`. Data: `home_mock.dart` + `home_repository.dart` —
  `assetBreakdownProvider` (by type / by site-building, each split Healthy ≥80 / Warning 60–79 / Critical <60; kept in
  step by `AssetsNotifier.add/delete`), `assetTypeGroup` / `assetLocationGroup` map a detailed asset to a breakdown row
  (Assets list `?type=` / `?location=`), `maintenanceMonthsProvider` (Oct 2025 – Sep 2026 per site × type; last 6 =
  236 / 24 / 11), `mttrPerMonth` / `mtbfPerMonth`, `costYearsProvider` (YTD 2026 = org costs, 2025; 3 cards = `CostGroup`),
  `plannedActivitiesProvider` (21 Sep – 4 Oct from WOs, inspections, audits, my approvals), `criticalHealthAssetsProvider`
  (`healthReasons`), `assetLastActivityProvider`, `mapPinsProvider` (`mapFloors` / `mapPins`, live for tracked assets).
  Shared: `core/widgets/insight_widgets.dart` (`DonutChart`, `DonutWithLegend`, `LegendRow`, `CountCard`, `ChangeChip`,
  `StackedMiniBar`, `WeekStrip`, `SeriesLegend`). Data check group "Home drill-downs"; tests in `test/drilldowns/`.
- Lists (prompt 19 QA): every list shows a shimmer first and has an `EmptyState`. Shared in `core/widgets/loading_list.dart`:
  `ListSkeleton`, `LoadingGate` (box lists; `LoadingGate.delay` = 350 ms), `SliverLoadingGate`, `SliverCardList` (rows of
  one card, lazy), `GatedSliverList` (gate + empty state + lazy rows) and `LazyListPage` (header widgets + lazy sliver list).
  Long or growing lists are lazy (`SliverList` / `ListView.builder`). `AssetListTile.titleTrailing` = chip after the title.
  The const lints (`prefer_const_*`) are on in analysis_options.yaml.
- Consistency: issues and alerts copy their asset's location (`seedLocationOf` in assets_mock.dart);
  `AssetsNotifier.setLocation` carries open issues / active alerts along (`followAsset`). Data check has the rule; tests in
  `test/data_check_test.dart`. Cross-module flows: `test/flows_test.dart`. QA report: `docs/QA_REPORT.md` + `docs/qa/`.
- More Actions: `features/assets/more_actions/` — `more_actions_screen.dart` (`/<tab>/more-actions?asset=`, under every
  tab like Scan; `Routes.moreActionsFrom` / `moreActionFrom(location, slug, id)`; `openMoreActions` / `openMoreAction` in
  asset_actions.dart; a `ScanTarget` selects the asset from any scan), one screen per action (`MoreAction` enum + shared
  `MoreActionPage`, `MoreActionAssetCard`, `SelectField`, `finishAction` in `more_action_widgets.dart`). Entry points:
  Home "More Actions" tile (inert in the client demo), Asset detail tile + ⋮, Scan result tile. Data:
  `Asset.conditionHistory` / `videos` / `favoriteGroup`, `favoriteGroupsProvider`, `AssetsNotifier.updateCondition` /
  `setFavorite` / `addVideo`, `disposalsProvider` (disposals_repository.dart; approver = signed-in user; counted in Home
  Approvals + My Approvals; approve → `AssetStatus.disposed`). Options in `data/mock/more_actions_mock.dart`. Print =
  `buildTagPdf` + printing; Share = share_plus; Email = `AppLauncher.openUrl` (mailto, platform channel). Shared:
  `showPersonPicker` / `PersonField` / `PersonAvatar` (core/widgets/person_picker.dart), `VideoPreview` (video_player),
  `showReasonDialog` (dialogs.dart), `FloorPlan(variant:, showLabels:)`, `DocumentUploadBox`. Tests: test/more_actions_test.dart.
- Transfer approver: the Transfer form's Details step has an Approver dropdown (Ahmed Ali by default; the signed-in user
  can pick themselves, "self-approve (demo)", so the request appears in My Approvals). Multi-step forms jump to the top on
  every step change (`_goTo`).
- SnackBars are shown by the shell's root Scaffold; `AppScaffold` marks routes with sticky `bottomActions`
  (`markStickyActions`) so `context.showSnack` lifts the SnackBar above them. Custom SnackBars should pass
  `margin: context.snackMargin`. `SignaturePad` / `SignaturePainter` now live in core/widgets/signature_pad.dart.
- Client demo: screen-level allow-list in `lib/app/client_demo.dart` (`kUseClientDemo`, `kDemoScreens` route patterns,
  `DemoAction` / `kDemoActions`, `demoCanOpen` / `demoCanDo`; README "Client demo"). `demoRoutes()` in app_router.dart
  registers only allowed screens; blocked controls go through `DemoGuard` (core/widgets/demo_guard.dart). New links to a
  screen should use `DemoGuard.push/go`, new sheets / dialogs / pickers on an allowed screen need a `DemoAction`.
  Screenshots: `design/client_demo/`. Tests turn the demo off in `test/flutter_test_config.dart`.
- `DemoClock.now` starts at 25 Sep 2026 10:30 AM and runs forward; `DemoClock.frozen` pins it (tests).
- App size: bundled images in `assets/images/` are WebP (q80) — add new ones as `.webp`. Release builds use R8 code +
  resource shrinking (`android/app/proguard-rules.pro`), the unbundled ML Kit barcode model
  (`dev.steenbakker.mobile_scanner.useUnbundled=true` in android/gradle.properties) and
  `--obfuscate --split-debug-info=build/symbols` (keep build/symbols, see README).
- Local storage & scanning: `lib/data/db/` (drift `AppDatabase`: ScanLog, Locations (seeded from `locationTree`,
  codes like `BLD-A-F2`), TagLinks; `db_providers.dart` StreamProviders). `lib/core/scanning/`: `scan_service.dart`
  (`ScanService.submit` = 2 s duplicate guard + match order links → `LOC:` code → asset → part → none; `ScanTarget` /
  `ScanTargets`), `scan_dispatch.dart` (`handleScanEvent`, `deliverScan`, `ScanTargetScope`, unknown-tag / link /
  location sheets, `readNfcWithSheet`), `nfc_reader.dart` (nfc_manager, `nfcReaderProvider` — tests override it),
  `hht_scanner.dart` (presets, `scannerSettingsProvider` in shared_preferences, `KeyboardWedgeDetector`, broadcast
  channel), `hardware_scan_listener.dart` (wraps the shell; `ScanFieldScope` marks scan text fields). Kotlin
  receiver in MainActivity.kt. Shared: `LocationField` / `LocationSelector` / `LocationValue`
  (core/widgets/location_field.dart; used in Registration step 3, Transfer step 3, Audit Scanned Location, Report
  Issue, Check In / Return), `LocalDataBadge`. Screens: `features/more/local_data/` (`/more/local-data`),
  `features/more/account/scanner_settings_screen.dart` (`/more/scanner`). Tests use an in-memory database
  (test/flutter_test_config.dart); scans use real time (`DateTime.now`), demo data keeps DemoClock.
