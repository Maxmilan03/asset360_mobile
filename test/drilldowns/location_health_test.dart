import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/main_shell.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_detail_screen.dart';
import 'package:asset360_mobile/features/assets/assets_list_screen.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true);
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
  c.read(routerProvider).go(Routes.home);
  await tester.pumpAndSettle();
  c.read(routerProvider).push(route);
  await tester.pumpAndSettle();
  return c;
}

void _expectBar() {
  expect(find.byType(AppBottomBar), findsOneWidget);
  expect(find.bySemanticsLabel('Scan'), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Leaves the map so the live tracking timer stops.
Future<void> _leave(WidgetTester tester, ProviderContainer c) async {
  c.read(routerProvider).go(Routes.home);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    DemoClock.frozen = true;
    LoadingGate.delay = Duration.zero;
    DrilldownPage.refreshDelay = Duration.zero;
  });
  tearDown(() {
    DemoClock.frozen = false;
    LoadingGate.delay = const Duration(milliseconds: 350);
    DrilldownPage.refreshDelay = const Duration(milliseconds: 800);
  });

  testWidgets('Asset Location: chips, floors, pin callout + card, directions, zoom, details', (tester) async {
    final c = await _open(tester, Routes.assetLocation);
    _expectBar();
    expect(find.text('Asset Location (Live)'), findsOneWidget);
    expect(find.textContaining('Live · updated'), findsOneWidget);

    // Warehouse floor: FL-012, FL-015, CR-001, CAB-011 (all Active).
    expect(find.text('All (4)'), findsOneWidget);
    expect(find.text('Active (4)'), findsOneWidget);
    expect(find.text('Under Maintenance (0)'), findsOneWidget);
    await _tap(tester, find.text('Under Maintenance (0)'));
    expect(find.text('No assets here'), findsOneWidget);
    await _tap(tester, find.text('Show all'));
    expect(find.byKey(const ValueKey('pin-FL-012')), findsOneWidget);

    // Floor switch → Building A & B: GEN-00045 / AHU-03 are Under Maintenance.
    await _tap(tester, find.byTooltip('Select site / floor'));
    await tester.tap(find.text('Dubai Factory · Building A & B · Ground Floor').last);
    await tester.pumpAndSettle();
    expect(find.text('Under Maintenance (2)'), findsOneWidget);
    await _tap(tester, find.text('Under Maintenance (2)'));
    expect(find.byKey(const ValueKey('pin-GEN-00046')), findsNothing);
    expect(find.byKey(const ValueKey('pin-GEN-00045')), findsOneWidget);

    // Pin → callout + card → directions.
    await _tap(tester, find.byKey(const ValueKey('pin-GEN-00045')));
    expect(find.text('GEN-00045'), findsNWidgets(2)); // callout + card
    expect(find.text('View Details'), findsOneWidget);
    await _tap(tester, find.text('Get Directions'));
    expect(find.textContaining(' m · ~'), findsOneWidget);
    expect(find.text('Building A & B · Ground Floor · Receiving'), findsOneWidget);
    expect(find.text('You are here'), findsOneWidget);

    // Zoom in / out / recenter clear the route.
    await _tap(tester, find.byTooltip('Zoom in'));
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), closeTo(1.5, .01));
    await _tap(tester, find.byTooltip('Zoom out'));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), closeTo(1, .01));
    await _tap(tester, find.byTooltip('Zoom in'));
    await _tap(tester, find.byTooltip('Recenter'));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), closeTo(1, .01));
    expect(find.textContaining(' m · ~'), findsNothing);

    // Layers sheet toggles pin labels.
    await _tap(tester, find.byTooltip('Layers'));
    await tester.tap(find.text('Pin labels'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();

    // Search across floors → jumps to the Head Office floor and selects LAP-0098.
    await tester.enterText(find.byType(TextField).first, 'LAP-0098');
    await tester.pumpAndSettle();
    await _tap(tester, find.textContaining('LAP-0098 · ').first);
    expect(find.text('Dubai Office · Head Office · Building A'), findsOneWidget);
    expect(find.text('LAP-0098'), findsWidgets);

    await _tap(tester, find.text('View Details'));
    expect(find.byType(AssetDetailScreen), findsOneWidget);
    _expectBar();
    await _leave(tester, c);
  });

  testWidgets('Asset Location: FL-012 pin moves with the live tracking', (tester) async {
    final c = await _open(tester, Routes.assetLocation);
    final before = tester.getTopLeft(find.byKey(const ValueKey('pin-FL-012')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('pin-FL-012'))), isNot(before));
    await _leave(tester, c);
  });

  testWidgets('Asset Health: 87% healthy, bands, critical list, tabs and rows', (tester) async {
    await _open(tester, Routes.assetHealth);
    _expectBar();
    expect(find.text('87%'), findsWidgets); // donut centre + Healthy bar
    expect(find.text('10,838'), findsWidgets);
    expect(find.text('1,245'), findsWidgets);
    expect(find.text('375'), findsWidgets);
    expect(find.text('Assets by Health Status'), findsOneWidget);
    await tester.ensureVisible(find.text('GEN-00046'));
    expect(find.text('Low Oil Pressure'), findsOneWidget);
    // Worst first.
    expect(tester.getTopLeft(find.text('GEN-00046')).dy, lessThan(tester.getTopLeft(find.text('GEN-00045')).dy));

    // Legend band → sheet of types → filtered Assets list.
    await _tap(tester, find.text('Critical').first);
    expect(find.text('Critical assets'), findsOneWidget);
    await tester.tap(find.text('Production Equipment').last);
    await tester.pumpAndSettle();
    expect(find.byType(AssetsListScreen), findsOneWidget);
    expect(find.text('Production Equipment'), findsWidgets);
    await _tap(tester, find.byTooltip('Back'));

    // Critical row → Asset detail.
    await _tap(tester, find.text('Low Oil Pressure'));
    expect(find.byType(AssetDetailScreen), findsOneWidget);
    await _tap(tester, find.byTooltip('Back'));

    await _tap(tester, find.text('By Asset Type'));
    expect(find.text('IT Equipment'), findsOneWidget);
    expect(find.text('2,840 · 250 · 30'), findsOneWidget);
    await _tap(tester, find.text('HVAC'));
    expect(find.byType(AssetsListScreen), findsOneWidget);
    expect(find.textContaining('of 1,045'), findsOneWidget);
    await _tap(tester, find.byTooltip('Back'));

    await _tap(tester, find.text('By Location'));
    expect(find.text('Dubai Factory · Main Plant'), findsOneWidget);
    await _tap(tester, find.text('Dubai Office · Head Office'));
    expect(find.byType(AssetsListScreen), findsOneWidget);
    expect(find.text('LAP-0098'), findsOneWidget);
    _expectBar();
  });
}
