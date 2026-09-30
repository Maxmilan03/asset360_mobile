/// Every path in the app. Screens navigate with these, never with string literals.
///
/// Modules live under the bottom-bar tab that is highlighted for them in design/
/// (Work: maintenance, inspection, issues, WIP, movement, audit; More: the rest).
/// `notifications` and `profile` are registered under every tab so the header
/// bell and avatar open them without leaving the current tab.
abstract final class Routes {
  // Auth (outside the shell, no bottom bar)
  static const splash = '/splash';
  static const login = '/login';
  static const authRoutes = [splash, login, forgotPassword, authenticator];
  static const forgotPassword = '/forgot-password';
  static const authenticator = '/authenticator';

  // Tab roots
  static const home = '/home';
  static const assets = '/assets';
  static const scan = '/scan';
  static const work = '/work';
  static const more = '/more';
  static const tabRoots = [home, assets, scan, work, more];

  // Shared children, registered under every tab root
  static const notificationsSegment = 'notifications';
  static const profileSegment = 'profile';

  // Home
  static const approvals = '/home/approvals';
  static const myTasks = '/home/tasks';

  // Assets
  static String assetDetail(String assetId) => '/assets/detail/$assetId';

  // Scan
  static String scanResult(String assetId) => '/scan/result/$assetId';
  static const scanHistory = '/scan/history';

  // Work
  static const maintenance = '/work/maintenance';
  static String workOrder(String woId) => '/work/maintenance/orders/$woId';
  static const maintenanceCalendar = '/work/maintenance/calendar';

  /// Create Work Order form, optionally prefilled with an asset.
  static String createWorkOrder({String? assetId}) =>
      assetId == null ? '/work/maintenance/new' : '/work/maintenance/new?asset=$assetId';

  /// Module lists opened on a given tab / filter (read by the module screens).
  static String maintenanceTab(String tab) => '$maintenance?tab=$tab';
  static String inspectionTab(String tab) => '$inspection?tab=$tab';
  static String alertsTab(String tab) => '$alerts?tab=$tab';
  static String assetsWithStatus(String status) => '$assets?status=${Uri.encodeComponent(status)}';

  /// A form route prefilled with an asset, e.g. withAsset(reportIssue, 'CNC-00123').
  static String withAsset(String route, String assetId) => '$route?asset=${Uri.encodeComponent(assetId)}';
  static const inspection = '/work/inspection';
  static const createInspection = '/work/inspection/new';
  static String inspectionDetail(String id) => '/work/inspection/detail/$id';
  static const issues = '/work/issues';
  static const reportIssue = '/work/issues/report';
  static String issueDetail(String id) => '/work/issues/detail/$id';
  static const wip = '/work/wip';
  static String wipUnit(String unitId) => '/work/wip/unit/$unitId';
  static String productionOrder(String moId) => '/work/wip/order/$moId';
  static const movement = '/work/movement';
  static const transferAsset = '/work/movement/transfer';
  static const movementHistory = '/work/movement/history';
  static const audit = '/work/audit';
  static String auditSession(String id) => '/work/audit/session/$id';

  // More
  static const tracking = '/more/tracking';
  static String trackAsset(String assetId) => '/more/tracking/asset/$assetId';
  static const inventory = '/more/inventory';
  static String partDetail(String partId) => '/more/inventory/part/$partId';
  static const stockMovement = '/more/inventory/stock-movement';
  static const documents = '/more/documents';
  static const addDocument = '/more/documents/add';
  static String documentDetail(String id) => '/more/documents/detail/$id';
  static const registration = '/more/registration';
  static const newRegistration = '/more/registration/new';
  static const bulkRegistration = '/more/registration/bulk';
  static const alerts = '/more/alerts';
  static String alertDetail(String id) => '/more/alerts/detail/$id';
  static const offlineSync = '/more/sync';
  static const pendingSync = '/more/sync/pending';
  static const syncProgress = '/more/sync/progress';
  static const settings = '/more/settings';
  static const dataCheck = '/more/settings/data-check';
  static const help = '/more/help';

  /// The tab root the given location belongs to (e.g. '/work/maintenance' → '/work').
  static String tabRootOf(String location) {
    for (final root in tabRoots) {
      if (location == root || location.startsWith('$root/')) return root;
    }
    return home;
  }

  static String notificationsFrom(String location) => '${tabRootOf(location)}/$notificationsSegment';
  static String profileFrom(String location) => '${tabRootOf(location)}/$profileSegment';
}
