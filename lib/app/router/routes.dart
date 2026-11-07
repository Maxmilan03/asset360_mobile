/// Every path in the app. Screens navigate with these, never with string literals.
///
/// Modules live under the bottom-bar tab that is highlighted for them in design/
/// (Work: maintenance, inspection, issues, WIP, movement, audit; More: the rest).
/// `notifications`, `profile` and `scan` are registered under every tab, so the
/// header bell, avatar and the centre Scan button open them on top of the
/// current screen (back returns there) and the bottom bar always stays visible.
abstract final class Routes {
  // Auth (outside the shell, no bottom bar)
  static const splash = '/splash';
  static const login = '/login';
  static const authRoutes = [splash, login, forgotPassword, authenticator, authenticatorSetup, authDiagnostics];
  static const forgotPassword = '/forgot-password';
  static const authenticator = '/authenticator';

  /// API mode, first sign-in: add the account to an authenticator app.
  static const authenticatorSetup = '/authenticator-setup';

  /// Auth diagnostics from the Login screen (signed out). Signed in: [settingsAuthDiagnostics].
  static const authDiagnostics = '/auth-diagnostics';

  // Tab roots (branches of the shell, in bottom-bar order; Scan is not a branch)
  static const home = '/home';
  static const assets = '/assets';
  static const work = '/work';
  static const more = '/more';
  static const tabRoots = [home, assets, work, more];

  // Shared children, registered under every tab root
  static const notificationsSegment = 'notifications';
  static const profileSegment = 'profile';
  static const scanSegment = 'scan';
  static const moreActionsSegment = 'more-actions';

  /// Marker for "open Scan & Identify on top of the current screen" in route tables
  /// (e.g. Home quick actions). Resolve it with [scanFrom].
  static const scan = '/scan';

  /// Marker for "open Scan History on the current tab" (resolve with [scanHistoryFrom]).
  static const scanHistory = '/scan/history';

  // Home
  static const approvals = '/home/approvals';
  static const myTasks = '/home/tasks';

  // Home drill-downs (the "View All / View Details / View Map / View Calendar" links)
  static const assetOverview = '/home/asset-overview';
  static const maintenancePerformance = '/home/maintenance-performance';
  static const activities = '/home/activities';

  /// Upcoming Activities on the list or calendar view.
  static String activitiesView(String view) => '$activities?view=$view';
  static const recentAlerts = '/home/recent-alerts';

  /// API mode: Recent Alerts opened on a severity tab (Critical / Warning / Info).
  static String recentAlertsSeverity(String severity) => '$recentAlerts?severity=$severity';
  static const assetLocation = '/home/asset-location';
  static const assetHealth = '/home/asset-health';
  static const costSummary = '/home/cost-summary';
  static const recentAssets = '/home/recent-assets';

  /// API mode: Recent Assets narrowed to a status group key, asset type and / or site
  /// (the filters GET /api/dashboards/mobile/recent-assets accepts).
  static String recentAssetsFiltered({String? status, String? type, String? site}) {
    final q = {'status': ?status, 'type': ?type, 'site': ?site};
    return q.isEmpty ? recentAssets : Uri(path: recentAssets, queryParameters: q).toString();
  }

  /// API mode: Live Devices (GET /api/dashboards/network-status/tags).
  static const devices = '/home/devices';

  // Assets
  static String assetDetail(String assetId, {String? tab}) =>
      tab == null ? '/assets/detail/$assetId' : '/assets/detail/$assetId?tab=$tab';

  /// API mode Edit Asset: the registration wizard pre-filled from the asset ("Save changes").
  static String assetEdit(String assetId) => '/assets/detail/${Uri.encodeComponent(assetId)}/edit';

  // Scan (under the tab the user is in)
  static String scanFrom(String location) => '${tabRootOf(location)}/$scanSegment';
  static String scanResultFrom(String location, String assetId) => '${scanFrom(location)}/result/$assetId';
  static String scanHistoryFrom(String location) => '${scanFrom(location)}/history';

  // Work
  static const maintenance = '/work/maintenance';
  static String workOrder(String woId) => '/work/maintenance/orders/$woId';
  static const maintenanceCalendar = '/work/maintenance/calendar';
  static const pmSchedules = '/work/maintenance/pm';
  static const breakdowns = '/work/maintenance/breakdowns';
  static const serviceHistory = '/work/maintenance/service-history';
  static String workOrderTab(String woId, String tab) => '/work/maintenance/orders/$woId?tab=$tab';

  /// Create Work Order form, optionally prefilled with an asset.
  static String createWorkOrder({String? assetId}) =>
      assetId == null ? '/work/maintenance/new' : '/work/maintenance/new?asset=$assetId';

  /// Module lists opened on a given tab / filter (read by the module screens).
  static String maintenanceTab(String tab) => '$maintenance?tab=$tab';
  static String inspectionTab(String tab) => '$inspection?tab=$tab';
  static String alertsTab(String tab) => '$alerts?tab=$tab';
  static String assetsWithStatus(String status) => '$assets?status=${Uri.encodeComponent(status)}';

  /// Assets list filtered by a breakdown type ("IT Equipment") or site / building ("Dubai Factory · Main Plant").
  static String assetsWithType(String type) => '$assets?type=${Uri.encodeComponent(type)}';
  static String assetsWithLocation(String location) => '$assets?location=${Uri.encodeComponent(location)}';

  /// A form route prefilled with an asset, e.g. withAsset(reportIssue, 'CNC-00123').
  static String withAsset(String route, String assetId) => '$route?asset=${Uri.encodeComponent(assetId)}';

  /// A bulk form route for several assets, e.g. withAssets(transferAsset, ['MTR-00123', 'FL-012']).
  static String withAssets(String route, List<String> assetIds) =>
      '$route?assets=${assetIds.map(Uri.encodeComponent).join(',')}';
  static const inspection = '/work/inspection';
  static const createInspection = '/work/inspection/new';
  static String inspectionDetail(String id, {String? tab}) =>
      tab == null ? '/work/inspection/detail/$id' : '/work/inspection/detail/$id?tab=$tab';
  static const inspectionFindings = '/work/inspection/findings';
  static String finding(String id) => '/work/inspection/findings/$id';
  static const issues = '/work/issues';
  static const reportIssue = '/work/issues/report';
  static String issueDetail(String id, {String? tab}) =>
      tab == null ? '/work/issues/detail/$id' : '/work/issues/detail/$id?tab=$tab';
  static String issuesTab(String tab) => '$issues?tab=$tab';
  static const wip = '/work/wip';
  static String wipUnit(String unitId) => '/work/wip/unit/$unitId';
  static String productionOrder(String moId) => '/work/wip/order/$moId';
  static const movement = '/work/movement';
  static const transferAsset = '/work/movement/transfer';
  static const movementHistory = '/work/movement/history';
  static String movementRequest(String id) => '/work/movement/request/$id';

  /// Check Out / Check In / Assign Custodian / Return Asset flows (optionally `withAsset`).
  static const checkOut = '/work/movement/check-out';
  static const checkIn = '/work/movement/check-in';
  static const assignCustodian = '/work/movement/assign';
  static const returnAsset = '/work/movement/return';
  static const audit = '/work/audit';

  /// mine | assigned | completed, or a tile filter: inProgress | pending.
  static String auditTab(String tab) => '/work/audit?tab=$tab';
  static const newAudit = '/work/audit/new';
  static const compliance = '/work/audit/compliance';
  static String auditSession(String id) => '/work/audit/session/$id';

  /// Asset Found for [assetId] in audit [id]; [method] = how it was identified (QR, RFID, Search …).
  static String auditAsset(String id, String assetId, {String? method}) =>
      '/work/audit/session/$id/asset/$assetId${method == null ? '' : '?method=${Uri.encodeQueryComponent(method)}'}';
  static String auditResults(String id, String result) =>
      '/work/audit/session/$id/results?result=${Uri.encodeQueryComponent(result)}';
  static String auditReport(String id) => '/work/audit/session/$id/report';

  // More
  static const tracking = '/more/tracking';
  static String trackingTab(String tab) => '$tracking?tab=$tab';
  static String trackAsset(String assetId, {String? tab}) =>
      tab == null ? '/more/tracking/asset/$assetId' : '/more/tracking/asset/$assetId?tab=$tab';

  /// Full-screen telemetry chart of one metric (key from `metricsFor`).
  static String trackChart(String assetId, String metric, {String? range}) =>
      '/more/tracking/asset/$assetId/chart?metric=$metric${range == null ? '' : '&range=$range'}';
  static const trackingActivity = '/more/tracking/activity';
  static const addGeofence = '/more/tracking/zones/new';
  static const inventory = '/more/inventory';
  static String partDetail(String partId) => '/more/inventory/part/$partId';
  static String inventoryTab(String tab) => '$inventory?tab=$tab';

  /// Stock Movement of one part (tab: history, usage, reserved, pos).
  static String partStock(String partId, {String? tab}) =>
      '/more/inventory/part/$partId/movement${tab == null ? '' : '?tab=$tab'}';

  /// Stock movements of every part.
  static const stockMovement = '/more/inventory/stock-movement';
  static const partRequests = '/more/inventory/requests';
  static String requestPart({String? partId}) =>
      partId == null ? '/more/inventory/requests/new' : '/more/inventory/requests/new?part=$partId';
  static const purchaseOrders = '/more/inventory/po';
  static String purchaseOrder(String id) => '/more/inventory/po/detail/$id';
  static String newPurchaseOrder({String? partId}) =>
      partId == null ? '/more/inventory/po/new' : '/more/inventory/po/new?part=$partId';
  static const stockReports = '/more/inventory/reports';
  static const documents = '/more/documents';
  static const addDocument = '/more/documents/add';
  static String documentDetail(String id) => '/more/documents/detail/$id';
  static String documentsTab(String tab) => '$documents?tab=$tab';

  /// In-app viewer (PDF or image). [version] views an older version's file.
  static String documentView(String id, {String? version}) =>
      '/more/documents/detail/$id/view${version == null ? '' : '?version=$version'}';
  static const registration = '/more/registration';
  static const newRegistration = '/more/registration/new';
  static const bulkRegistration = '/more/registration/bulk';
  static const alerts = '/more/alerts';
  static String alertDetail(String id) => '/more/alerts/detail/$id';
  static const offlineSync = '/more/sync';
  static const pendingSync = '/more/sync/pending';

  /// Pending Sync on one tab: a `SyncKind` name (workOrder, inspection, asset, issue, photo, document, other).
  static String pendingSyncTab(String kind) => '/more/sync/pending?tab=$kind';
  static const syncProgress = '/more/sync/progress';
  static const contracts = '/more/contracts';
  static const financial = '/more/financial';
  static const reports = '/more/reports';
  static String report(String id) => '/more/reports/$id';
  static const admin = '/more/admin';
  static String adminUser(String personId) => '/more/admin/users/$personId';
  static const settings = '/more/settings';
  static const localData = '/more/local-data';
  static const scannerSettings = '/more/scanner';
  static const dataCheck = '/more/settings/data-check';
  static const demoTags = '/more/settings/demo-tags';
  static const settingsAuthDiagnostics = '/more/settings/auth-diagnostics';
  static const help = '/more/help';
  static const reportBug = '/more/help/report-bug';

  /// The tab root the given location belongs to (e.g. '/work/maintenance' → '/work').
  static String tabRootOf(String location) {
    for (final root in tabRoots) {
      if (location == root || location.startsWith('$root/')) return root;
    }
    return home;
  }

  /// Asset More Actions on the tab the user is in, optionally with an asset selected.
  static String moreActionsFrom(String location, {String? assetId}) =>
      '${tabRootOf(location)}/$moreActionsSegment${assetId == null ? '' : '?asset=${Uri.encodeQueryComponent(assetId)}'}';

  /// One More Actions screen ([slug] from `MoreAction.slug`) for [assetId], on the current tab.
  static String moreActionFrom(String location, String slug, String assetId) =>
      '${tabRootOf(location)}/$moreActionsSegment/$slug?asset=${Uri.encodeQueryComponent(assetId)}';

  static String notificationsFrom(String location) => '${tabRootOf(location)}/$notificationsSegment';
  static String notificationSettingsFrom(String location) => '${notificationsFrom(location)}/settings';
  static String profileFrom(String location) => '${tabRootOf(location)}/$profileSegment';
}
