import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/main_shell.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
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
  'action': 'print-tag',
};

/// Every concrete path in the router, with parameters filled in.
List<String> _allPaths(List<RouteBase> routes, [String parent = '']) {
  final out = <String>[];
  for (final r in routes) {
    if (r is ShellRouteBase) {
      out.addAll(_allPaths(r.routes, parent));
    } else if (r is GoRoute) {
      final raw = r.path.startsWith('/') ? r.path : '${parent == '/' ? '' : parent}/${r.path}';
      final path = raw.replaceAllMapped(RegExp(r':(\w+)'), (m) {
        if (m[1] == 'id' && raw.contains('/reports/')) return 'maintenance';
        if (m[1] == 'id' && raw.contains('/admin/users/')) return 'rex';
        return _params[m[1]] ?? 'X-0001';
      });
      out.add(path);
      out.addAll(_allPaths(r.routes, path));
    }
  }
  return out;
}

void main() {
  setUp(() => DemoClock.frozen = true);

  testWidgets('every signed-in route shows the bottom bar with the centre Scan button', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    final router = c.read(routerProvider);
    final paths = _allPaths(router.configuration.routes).where((p) => !Routes.authRoutes.contains(p)).toList();
    expect(paths.length, greaterThan(60));
    for (final p in paths) {
      router.go(p);
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomBar), findsOneWidget, reason: p);
      expect(find.bySemanticsLabel('Scan'), findsOneWidget, reason: p);
      expect(tester.takeException(), isNull, reason: p);
    }

    // Scan from a detail screen: back returns to that screen.
    router.go(Routes.assetDetail('CNC-00123'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan & Identify'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('CNC-00123'), findsWidgets);

    // Dialogs open under the bar: the Scan button is still there and on top.
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retire Asset'));
    await tester.pumpAndSettle();
    expect(find.text('Retire CNC-00123?'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
