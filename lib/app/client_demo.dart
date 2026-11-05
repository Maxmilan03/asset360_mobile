/// Client demo: a screen-level allow-list (README "Client demo").
///
/// With [kUseClientDemo] on, only the screens in [kDemoScreens] are registered in
/// the router, and only the in-screen actions in [kDemoActions] respond. Every
/// other control stays visible but inert (`DemoGuard`, lib/core/widgets/demo_guard.dart).
/// To allow one more screen or action, add its entry to the set and rebuild.
/// Reference screenshots: design/client_demo/.
library;

// Set to false to restore the full app.
const bool kUseClientDemo = false;

/// Allowed screens, as route patterns from lib/app/router/routes.dart
/// (`:name` matches one path segment). Children of a screen that is not listed
/// are not registered either.
const Set<String> kDemoScreens = {
  // Always on
  '/splash',
  '/login',
  '/forgot-password', // + its success sheet
  '/authenticator',
  '/authenticator-setup', // API mode, first sign-in
  '/auth-diagnostics', // API mode, from Sign in
  '/home', // Home dashboard
  '/work', // Work hub
  '/more', // All Modules (the More tab's page; the sheet itself is always on)
  // 02_assets_list
  '/assets',
  // 03_asset_detail_* (overview, location, iot, maintenance, inspection, financial, documents, history)
  '/assets/detail/:assetId',
  // 04_scan_qr / 04_scan_nfc / 04_scan_rfid / 04_scan_ble — Scan & Identify opens on the current tab
  '/home/scan',
  '/assets/scan',
  '/work/scan',
  '/more/scan',
  // 06_movement_hub
  '/work/movement',
  // 07_transfer_asset_step1 (steps 1–5, submit and the success sheet)
  '/work/movement/transfer',
  // 08_maintenance_hub (hub + work order lists)
  '/work/maintenance',
  // 09_work_order_detail_top / _bottom (Overview tab only, see DemoAction.woOtherTabs)
  '/work/maintenance/orders/:woId',
  // 10_inventory_hub (hub + parts list)
  '/more/inventory',
  // 11_part_details
  '/more/inventory/part/:partId',
  // 12_stock_movement (Stock History tab only, see DemoAction.stockOtherTabs)
  '/more/inventory/part/:partId/movement',
  // Local storage & scanning: Local Data and Settings → Scanner
  '/more/local-data',
  '/more/scanner',
};

/// Named in-screen actions: the controls that open a sheet, dialog, picker or form,
/// or change data, on an allowed screen. Navigation into a screen is decided by
/// [kDemoScreens]; scrolling, pull-to-refresh, search, filter sheets, chips and
/// tabs that only change what a screen shows are always on.
enum DemoAction {
  // Home
  homeSiteSelector,
  homeCustomize,
  homeMoreActions,
  homeLegendFilters, // Asset Overview legend rows → filtered Assets list
  homeActivityRows, // Upcoming Activities rows
  // Header
  headerUserMenu,
  // Assets list
  assetsListScan, // scan icon beside the search field
  assetFavourite,
  // Asset detail
  assetEditKeyInfo,
  assetIotMetric, // metric dropdown and telemetry tiles (chart tooltips are always on)
  assetMove,
  assetCheckOut,
  assetAddPhoto,
  assetMenu,
  assetMoreActions,
  assetHealthSheet,
  assetHelpSheet,
  assetFloorPlanPin,
  assetGeneratePm,
  assetPhotoViewer,
  assetLinkIot,
  assetAssessCriticality, // Key Information → Criticality → Assess sheet
  // Scan
  scanTap,
  scanFlash,
  scanGallery,
  scanManualEntry,
  scanMultiScan,
  // Transfer Asset
  transferScanAsset,
  transferSearchAsset,
  transferMyAssets,
  transferManualId,
  transferForm,
  transferSubmit,
  movementAssetLink, // Selected Asset / Review asset card → Asset detail
  // Maintenance / work order
  woStatus,
  woEditDescription,
  woOtherTabs,
  woReassign,
  woPhotos,
  woClose,
  // Inventory
  partEditStock,
  partManage,
  partMenu,
  partSpecSheet,
  partScanLabel, // camera icon beside the Part Details / Stock Movement title
  stockOtherTabs,
  stockRefLinks, // REF: WO-… → work order
  stockOtherRefs, // REF: GRN-… sheet and internal references (TR-…)
}

/// Allowed in-screen actions (each matches a control in the screenshots).
const Set<DemoAction> kDemoActions = {
  DemoAction.assetFavourite, // 02_assets_list / 03_asset_detail_overview: ☆
  DemoAction.assetEditKeyInfo, // 03_asset_detail_overview: Key Information Edit / Save / Cancel
  DemoAction.assetIotMetric, // 03_asset_detail_iot: metric dropdown, telemetry tiles that pick the chart
  DemoAction.assetMove, // 03_asset_detail_overview: Move Asset → Transfer step 1
  DemoAction.scanTap, // 04_scan_*: Tap to Scan / Tap to Read
  DemoAction.scanFlash, // 04_scan_qr: flash
  DemoAction.scanGallery, // 04_scan_qr: scan from gallery
  DemoAction.scanManualEntry, // 04_scan_*: Manual Entry sheet
  DemoAction.transferScanAsset, // 07_transfer_asset_step1: Scan Asset
  DemoAction.transferSearchAsset, // 07_transfer_asset_step1: Search Asset
  DemoAction.transferMyAssets, // 07_transfer_asset_step1: My Assets
  DemoAction.transferManualId, // 07_transfer_asset_step1: Enter Asset ID Manually
  DemoAction.transferForm, // 07_transfer_asset_step1: steps 2–5 fields, Back / Next, Review Edit links
  DemoAction.transferSubmit, // 07_transfer_asset_step1: Submit for Approval + success sheet
  DemoAction.woStatus, // 09_work_order_detail_top / _bottom: status dropdown, Update Status sheet
  DemoAction.woEditDescription, // 09_work_order_detail_bottom: Issue Description Edit
  DemoAction.partEditStock, // 11_part_details: Stock Overview Edit
  DemoAction.stockRefLinks, // 12_stock_movement: REF: WO-… links (GRN / PO / TR stay inert)
};

/// Tests only: overrides [kUseClientDemo] (test/flutter_test_config.dart turns the
/// demo off so the module tests see the full app).
bool? debugClientDemo;

/// Whether the client demo restrictions apply.
bool get clientDemoActive => debugClientDemo ?? kUseClientDemo;

/// Whether the location [route] (query allowed) is an allowed screen.
bool demoCanOpen(String route) => !clientDemoActive || demoScreenFor(route) != null;

/// Whether in-screen action [a] is allowed.
bool demoCanDo(DemoAction a) => !clientDemoActive || kDemoActions.contains(a);

/// The [kDemoScreens] pattern that matches [route], or null.
String? demoScreenFor(String route) {
  final segments = _segments(Uri.parse(route).path);
  for (final pattern in kDemoScreens) {
    if (demoPatternMatches(pattern, segments)) return pattern;
  }
  return null;
}

/// Whether [pattern] (`:name` = any one segment) matches the path [segments].
bool demoPatternMatches(String pattern, List<String> segments) {
  final p = _segments(pattern);
  if (p.length != segments.length) return false;
  for (var i = 0; i < p.length; i++) {
    if (!p[i].startsWith(':') && p[i] != segments[i]) return false;
  }
  return true;
}

List<String> _segments(String path) => path.split('/').where((s) => s.isNotEmpty).toList();
