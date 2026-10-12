import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/client_demo.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/demo_guard.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

/// Sample values for path parameters.
const _params = {
  'assetId': 'CNC-00123',
  'woId': 'WO-2026-0045',
  'unitId': 'PCB-A-4587',
  'moId': 'MO-2026-0018',
  'partId': 'BR-6205',
};

/// Every concrete path in the router, with parameters filled in.
List<String> _allPaths(List<RouteBase> routes, [String parent = '']) => [
  for (final r in routes)
    if (r is ShellRouteBase)
      ..._allPaths(r.routes, parent)
    else if (r is GoRoute)
      for (final path in [
        (r.path.startsWith('/') ? r.path : '${parent == '/' ? '' : parent}/${r.path}').replaceAllMapped(
          RegExp(r':(\w+)'),
          (m) => switch (m[1]) {
            'id' when parent.contains('/reports') => 'maintenance',
            'id' when parent.contains('/admin/users') => 'rex',
            final k => _params[k] ?? 'X-0001',
          },
        ),
      ]) ...[path, ..._allPaths(r.routes, path)],
];

/// Module tile label on the All Modules page → the screen it opens.
const _modules = {
  'Assets': Routes.assets,
  'Tracking & IoT': Routes.tracking,
  'Movement & Custody': Routes.movement,
  'Maintenance': Routes.maintenance,
  'Inspection': Routes.inspection,
  'Inventory': Routes.inventory,
  'WIP / Operations': Routes.wip,
  'Audit & Compliance': Routes.audit,
  'Contracts & Warranty': Routes.contracts,
  'Financial': Routes.financial,
  'Reports & Analytics': Routes.reports,
  'Administration': Routes.admin,
  'Issues / Defects': Routes.issues,
  'Alerts & Notifications': Routes.alerts,
  'Documents': Routes.documents,
  'Asset Registration': Routes.registration,
  'Offline Sync': Routes.offlineSync,
  'Settings': Routes.settings,
};

/// No DemoGuard on screen blocks its control.
void _expectNothingLocked(WidgetTester tester, String where) {
  for (final g in tester.widgetList<DemoGuard>(find.byType(DemoGuard, skipOffstage: false))) {
    expect(g.allowed ?? true, isTrue, reason: where);
    expect(DemoGuard.allows(route: g.route, action: g.action), isTrue, reason: '$where ${g.route ?? g.action}');
  }
}

void main() {
  setUp(() {
    DemoClock.frozen = true;
    debugClientDemo = null; // this build's kUseClientDemo, not the test default
  });
  tearDown(() => debugClientDemo = false);

  testWidgets('full app: every module opens from All Modules, every screen opens, nothing is locked', (
    tester,
  ) async {
    expect(clientDemoActive, isFalse);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    final router = c.read(routerProvider);
    String location() => router.routerDelegate.currentConfiguration.uri.path;

    // Scan: the centre button opens Scan & Identify.
    await tester.tap(find.bySemanticsLabel('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan & Identify'), findsOneWidget);
    _expectNothingLocked(tester, 'scan');

    // Each module tile on the All Modules page opens its screen.
    for (final MapEntry(key: label, value: route) in _modules.entries) {
      router.go(Routes.more);
      await tester.pumpAndSettle();
      final tile = find.text(label).last;
      await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(location(), route, reason: label);
      expect(tester.takeException(), isNull, reason: label);
      _expectNothingLocked(tester, label);
    }

    // Profile is pushed on the current tab.
    router.go(Routes.more);
    await tester.pumpAndSettle();
    final profile = find.text('Profile').last;
    await tester.scrollUntilVisible(profile, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(profile);
    await tester.pumpAndSettle();
    expect(find.text('Your details, role and password'), findsOneWidget);
    _expectNothingLocked(tester, 'profile');

    // Every registered screen opens (go_router keeps the old screen for a refused one).
    final paths = _allPaths(router.configuration.routes).where((p) => !Routes.authRoutes.contains(p)).toList();
    expect(paths.length, greaterThan(60));
    for (final p in paths) {
      expect(demoCanOpen(p), isTrue, reason: p);
      router.go(p);
      await tester.pumpAndSettle();
      expect(location(), p, reason: p);
      expect(tester.takeException(), isNull, reason: p);
      _expectNothingLocked(tester, p);
    }

    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
