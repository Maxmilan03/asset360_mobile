import 'package:asset360_mobile/app/client_demo.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Every route pattern the full router registers (`/assets/detail/:assetId` …).
List<String> _patterns(List<RouteBase> routes, [String parent = '']) => [
  for (final r in routes)
    if (r is ShellRouteBase)
      ..._patterns(r.routes, parent)
    else if (r is GoRoute)
      for (final full in [r.path.startsWith('/') ? r.path : '${parent == '/' ? '' : parent}/${r.path}']) ...[
        full,
        ..._patterns(r.routes, full),
      ],
];

/// A concrete location for a pattern (path parameters filled in).
String _sample(String pattern) => pattern.replaceAll(RegExp(r':\w+'), 'X-1');

/// The allowed screens, written out with the Routes helpers (what the client sees).
final _allowedLocations = [
  Routes.splash,
  Routes.login,
  Routes.forgotPassword,
  Routes.authenticator,
  Routes.home,
  Routes.work,
  Routes.more,
  Routes.assets,
  Routes.assetsWithStatus('Active'),
  Routes.assetDetail('CNC-00123'),
  Routes.assetDetail('GEN-00045', tab: 'history'),
  for (final tab in Routes.tabRoots) Routes.scanFrom(tab),
  Routes.movement,
  Routes.transferAsset,
  Routes.withAsset(Routes.transferAsset, 'CNC-00123'),
  Routes.maintenance,
  Routes.maintenanceTab('mine'),
  Routes.workOrder('WO-2026-0045'),
  Routes.inventory,
  Routes.inventoryTab('low'),
  Routes.partDetail('BR-6205'),
  Routes.partStock('BR-6205'),
];

/// A sample of screens the client must not reach.
final _blockedLocations = [
  Routes.approvals,
  Routes.myTasks,
  // Home drill-downs: the Home links stay inert in the client demo.
  Routes.assetOverview,
  Routes.maintenancePerformance,
  Routes.activitiesView('calendar'),
  Routes.recentAlerts,
  Routes.assetLocation,
  Routes.assetHealth,
  Routes.costSummary,
  Routes.recentAssets,
  for (final tab in Routes.tabRoots) ...[
    Routes.scanResultFrom(tab, 'CNC-00123'),
    Routes.scanHistoryFrom(tab),
    Routes.notificationsFrom(tab),
    Routes.profileFrom(tab),
  ],
  Routes.checkOut,
  Routes.movementHistory,
  Routes.movementRequest('MOV-2026-0045'),
  Routes.createWorkOrder(),
  Routes.createWorkOrder(assetId: 'CNC-00123'),
  Routes.pmSchedules,
  Routes.breakdowns,
  Routes.serviceHistory,
  Routes.maintenanceCalendar,
  Routes.inspection,
  Routes.createInspection,
  Routes.issues,
  Routes.reportIssue,
  Routes.wip,
  Routes.audit,
  Routes.tracking,
  Routes.trackAsset('FL-012'),
  Routes.registration,
  Routes.documents,
  Routes.documentDetail('DOC-1'),
  Routes.alerts,
  Routes.stockMovement,
  Routes.partRequests,
  Routes.requestPart(partId: 'BR-6205'),
  Routes.purchaseOrders,
  Routes.purchaseOrder('PO-2026-0123'),
  Routes.newPurchaseOrder(partId: 'BR-6205'),
  Routes.stockReports,
  Routes.offlineSync,
  Routes.contracts,
  Routes.financial,
  Routes.reports,
  Routes.admin,
  Routes.settings,
  Routes.help,
];

void main() {
  setUp(() => debugClientDemo = true);
  tearDown(() => debugClientDemo = false);

  test('kUseClientDemo is off in this build (full app)', () => expect(kUseClientDemo, isFalse));

  test('this build (no test override) registers every route and allows every action', () {
    debugClientDemo = null;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final router = c.read(routerProvider).configuration.routes;
    final patterns = _patterns(router);
    // demoRoutes() returns the full route tree unchanged, so every route of routes.dart is registered.
    expect(identical(demoRoutes(router), router), isTrue);
    debugClientDemo = false;
    final full = ProviderContainer();
    addTearDown(full.dispose);
    expect(patterns, _patterns(full.read(routerProvider).configuration.routes));
    debugClientDemo = null;
    for (final p in patterns) {
      expect(demoCanOpen(_sample(p)), isTrue, reason: p);
    }
    for (final l in [..._allowedLocations, ..._blockedLocations]) {
      expect(demoCanOpen(l), isTrue, reason: l);
    }
    for (final a in DemoAction.values) {
      expect(demoCanDo(a), isTrue, reason: '$a');
    }
  });

  test('demoCanOpen is true for the allowed screens', () {
    for (final l in _allowedLocations) {
      expect(demoCanOpen(l), isTrue, reason: l);
    }
  });

  test('demoCanOpen is false for the other screens', () {
    for (final l in _blockedLocations) {
      expect(demoCanOpen(l), isFalse, reason: l);
    }
  });

  test('of every route in the full app, only the kDemoScreens ones can be opened', () {
    debugClientDemo = false;
    final full = ProviderContainer();
    addTearDown(full.dispose);
    final patterns = _patterns(full.read(routerProvider).configuration.routes);
    debugClientDemo = true;

    // Every allow-list entry is a real route…
    for (final allowed in kDemoScreens) {
      expect(patterns, contains(allowed), reason: 'kDemoScreens has $allowed, which the router does not have');
    }
    // …and every other route is refused.
    for (final p in patterns) {
      expect(demoCanOpen(_sample(p)), kDemoScreens.contains(p), reason: p);
    }
  });

  test('client demo router registers exactly the allowed screens', () {
    final demo = ProviderContainer();
    addTearDown(demo.dispose);
    final registered = _patterns(demo.read(routerProvider).configuration.routes).toSet();
    expect(registered, kDemoScreens);
  });

  test('demoCanDo is true only for kDemoActions', () {
    for (final a in DemoAction.values) {
      expect(demoCanDo(a), kDemoActions.contains(a), reason: '$a');
    }
  });

  test('with the demo off everything is allowed', () {
    debugClientDemo = false;
    for (final l in [..._allowedLocations, ..._blockedLocations]) {
      expect(demoCanOpen(l), isTrue, reason: l);
    }
    for (final a in DemoAction.values) {
      expect(demoCanDo(a), isTrue, reason: '$a');
    }
  });
}
