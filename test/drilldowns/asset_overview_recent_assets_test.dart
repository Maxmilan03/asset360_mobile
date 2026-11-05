import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/main_shell.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_detail_screen.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

Future<ProviderContainer> _open(WidgetTester tester, String route) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  c.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

final _page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

void _expectBar() {
  expect(find.byType(AppBottomBar), findsOneWidget);
  expect(find.bySemanticsLabel('Scan'), findsOneWidget);
}

void main() {
  setUp(() {
    DemoClock.frozen = true;
    LoadingGate.delay = Duration.zero;
    DrilldownPage.refreshDelay = Duration.zero;
  });

  testWidgets('Asset Overview: tabs, donut total, search and filtered Assets list', (tester) async {
    final c = await _open(tester, Routes.assetOverview);
    _expectBar();
    expect(find.text('Asset Overview'), findsOneWidget);
    expect(find.text('12,458'), findsWidgets); // donut centre = Home total
    expect(find.text('10,842'), findsWidgets); // Active, as on Home

    // By Type → a row opens the Assets list filtered by that type with the org figure.
    await _tap(tester, find.text('By Type'));
    expect(find.text('Production Equipment'), findsWidgets);
    expect(c.read(assetBreakdownProvider).total, 12458);
    await _tap(tester, find.text('IT Equipment').last);
    expect(find.text('Showing 3 of 3,120'), findsOneWidget);
    await _tap(tester, find.byTooltip('Back'));
    _expectBar();

    // By Location + search.
    await _tap(tester, find.text('By Location'));
    expect(find.text('Dubai Factory · Main Plant'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'warehouse');
    await tester.pumpAndSettle();
    expect(find.text('Dubai Factory · Main Warehouse'), findsOneWidget);
    expect(find.text('Dubai Factory · Main Plant'), findsNothing);
    await _tap(tester, find.text('Dubai Factory · Main Warehouse'));
    expect(find.text('Showing 4 of 2,150'), findsOneWidget);
    await _tap(tester, find.byTooltip('Back'));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Clear search'), findsWidgets);
    await _tap(tester, find.text('Clear search').last);
    expect(find.text('Dubai Factory · Main Plant'), findsOneWidget);

    // By Status → a row opens the Assets list filtered by status.
    await _tap(tester, find.text('By Status'));
    await _tap(tester, find.text('Under Maintenance').last);
    expect(find.text('Showing 1 of 303'), findsOneWidget); // GEN-00045 (AHU-03 is In Repair)
  });

  testWidgets('Recent Assets: org-count chips, sort by last activity, search and row tap', (tester) async {
    final c = await _open(tester, Routes.recentAssets);
    _expectBar();
    expect(find.text('All (12,458)'), findsOneWidget);
    expect(find.text('Active (10,842)'), findsOneWidget);
    expect(find.text('Under Maintenance (303)'), findsOneWidget);
    // Newest activity first: GEN-00046 (10:27) above GEN-00045 (10:26).
    final y46 = tester.getTopLeft(find.text('GEN-00046')).dy;
    final y45 = tester.getTopLeft(find.text('GEN-00045')).dy;
    expect(y46, lessThan(y45));

    await tester.scrollUntilVisible(find.textContaining('Showing 21 of 12,458'), 300, scrollable: _page);
    expect(find.textContaining('Showing 21 of 12,458'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Under Maintenance (303)'));
    final underMaintenance = c.read(assetsProvider).where((a) => a.status == AssetStatus.underMaintenance).length;
    expect(find.textContaining('Showing $underMaintenance of 303'), findsOneWidget);
    await _tap(tester, find.text('All (12,458)'));

    await tester.enterText(find.byType(TextField), 'warehouse');
    await tester.pumpAndSettle();
    expect(find.text('FL-012'), findsOneWidget);
    expect(find.text('CNC-00123'), findsNothing);
    await _tap(tester, find.text('FL-012'));
    expect(c.read(recentAssetsProvider).first, 'FL-012');
    expect(find.byType(AssetDetailScreen), findsOneWidget);
    _expectBar();
  });

  testWidgets('Recent Assets: no match shows the empty state', (tester) async {
    await _open(tester, Routes.recentAssets);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No assets found'), findsOneWidget);
    await _tap(tester, find.text('Clear search & filters'));
    expect(find.text('No assets found'), findsNothing);
  });
}
