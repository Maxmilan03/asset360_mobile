import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  c.read(routerProvider).go(Routes.home);
  await tester.pumpAndSettle();
  c.read(routerProvider).push(route);
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Location of the top route, including pushed ones.
String _location(ProviderContainer c) {
  final cfg = c.read(routerProvider).routerDelegate.currentConfiguration;
  final last = cfg.last;
  return last is ImperativeRouteMatch ? last.matches.uri.toString() : cfg.uri.toString();
}

/// The value shown on the count card labelled [label].
String _count(WidgetTester tester, String label) {
  final card = find.ancestor(of: find.text(label), matching: find.byType(CountCard));
  return tester.widget<CountCard>(card).value;
}

void main() {
  setUp(() {
    DemoClock.frozen = true;
    DrilldownPage.refreshDelay = Duration.zero;
  });

  testWidgets('Maintenance Performance: tabs, period, filters and count cards', (tester) async {
    final c = await _open(tester, Routes.maintenancePerformance);
    expect(find.bySemanticsLabel('Scan'), findsOneWidget);
    expect(find.text('Maintenance Performance'), findsOneWidget);
    expect(find.text('87%'), findsOneWidget);
    expect(_count(tester, 'Planned WOs'), '236');
    expect(_count(tester, 'Unplanned WOs'), '24');
    expect(_count(tester, 'Overdue WOs'), '11');
    expect(find.text('1.8 hrs', findRichText: true), findsOneWidget);
    expect(find.text('120 days', findRichText: true), findsOneWidget);

    final rows = c.read(maintenanceMonthsProvider);
    // Last 3 months
    await _tap(tester, find.byKey(const ValueKey('period')));
    await _tap(tester, find.text('Last 3 Months').last);
    final three = WoMix.of(rows.where((r) => lastMonths(3).contains(r.month)));
    expect(_count(tester, 'Planned WOs'), '${three.planned}');
    expect(_count(tester, 'Unplanned WOs'), '${three.unplanned}');

    // Filter sheet: asset type HVAC
    await _tap(tester, find.bySemanticsLabel('Filters'));
    await _tap(tester, find.text('HVAC'));
    await _tap(tester, find.text('Apply'));
    final hvac = WoMix.of(rows.where((r) => lastMonths(3).contains(r.month) && r.type == 'HVAC'));
    expect(_count(tester, 'Planned WOs'), '${hvac.planned}');
    expect(find.widgetWithText(InputChip, 'HVAC'), findsOneWidget);
    // Remove the chip → back to all types.
    tester.widget<InputChip>(find.widgetWithText(InputChip, 'HVAC')).onDeleted!();
    await tester.pumpAndSettle();
    expect(_count(tester, 'Planned WOs'), '${three.planned}');

    // Trends tab
    await _tap(tester, find.text('Trends'));
    expect(find.text('MTTR Trend (hrs)'), findsOneWidget);

    // By Asset Type: tap a row → Overview filtered by that type.
    await _tap(tester, find.text('By Asset Type'));
    await _tap(tester, find.text('Generator'));
    final gen = WoMix.of(rows.where((r) => lastMonths(3).contains(r.month) && r.type == 'Generator'));
    expect(_count(tester, 'Planned WOs'), '${gen.planned}');

    // Reset via the sheet, then the count cards navigate.
    await _tap(tester, find.bySemanticsLabel('Filters'));
    await _tap(tester, find.text('Reset'));
    await _tap(tester, find.text('Overdue WOs'));
    expect(_location(c), Routes.maintenanceTab('overdue'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Maintenance Performance count cards open the filtered lists', (tester) async {
    final c = await _open(tester, Routes.maintenancePerformance);
    await _tap(tester, find.text('Planned WOs'));
    expect(_location(c), Routes.maintenanceTab('pm'));
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Unplanned WOs'));
    expect(_location(c), Routes.breakdowns);
  });

  testWidgets('Cost Summary: year switch, cards and table open the top-5 sheet', (tester) async {
    final c = await _open(tester, Routes.costSummary);
    expect(find.bySemanticsLabel('Scan'), findsOneWidget);
    expect(find.text('AED 1,250,000'), findsNWidgets(2)); // total + table footer
    expect(find.text('480,000'), findsOneWidget);
    expect(find.text('550,000'), findsOneWidget);
    expect(find.text('220,000'), findsOneWidget);
    expect(find.text('1.8% vs last year'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('year')));
    await _tap(tester, find.text('2025').last);
    expect(find.text('AED 1,640,000'), findsNWidgets(2));
    expect(find.text('730,000'), findsOneWidget);
    expect(find.text('3.8% vs last year'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('year')));
    await _tap(tester, find.text('YTD 2026').last);
    expect(find.text('AED 1,250,000'), findsNWidgets(2)); // total + table footer

    // Card → top assets by maintenance cost.
    await _tap(tester, find.text('Maintenance').first);
    expect(find.text('Top assets – Maintenance'), findsOneWidget);
    expect(find.text('Lifetime running cost (AED)'), findsOneWidget);
    await _tap(tester, find.text('Close'));

    // Plumbing has no detailed assets → empty state.
    await _tap(tester, find.text('Plumbing'));
    expect(find.text('No detailed assets'), findsOneWidget);
    await _tap(tester, find.text('Close'));

    // Type row → sheet → asset detail.
    await _tap(tester, find.text('Generator'));
    expect(find.text('Top assets – Generator'), findsOneWidget);
    await _tap(tester, find.text('GEN-00045'));
    expect(_location(c), Routes.assetDetail('GEN-00045'));
    expect(tester.takeException(), isNull);
  });
}
