import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/main_shell.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true);
}

/// Home card title → (link text, route it opens, page title shown).
final _links = {
  'Asset Overview': ('View All', Routes.assetOverview, 'Asset Overview'),
  'Maintenance Performance': ('View All', Routes.maintenancePerformance, 'Maintenance Performance'),
  'Upcoming Activities': ('View Calendar', Routes.activitiesView('calendar'), 'Upcoming Activities'),
  'Recent Alerts': ('View All', Routes.recentAlerts, 'Recent Alerts'),
  'Asset Location (Live)': ('View Map', Routes.assetLocation, 'Asset Location (Live)'),
  'Asset Health': ('View Details', Routes.assetHealth, 'Asset Health'),
  'Cost Summary (AED)': ('View Details', Routes.costSummary, 'Cost Summary (AED)'),
  'Recent Assets': ('View All', Routes.recentAssets, 'Recent Assets'),
};

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

  testWidgets('every Home "View …" link opens its drill-down under the Home tab with the bottom bar', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
    );
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(Asset360App)));
    final router = c.read(routerProvider);

    for (final MapEntry(key: card, value: (link, route, title)) in _links.entries) {
      final action = find.descendant(of: find.widgetWithText(SectionCard, card), matching: find.text(link));
      // Centre it: the pinned Home header would cover a link scrolled to the top edge.
      await Scrollable.ensureVisible(tester.element(action), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.state.uri.toString(), route, reason: card);
      expect(find.widgetWithText(PageTitle, title), findsOneWidget, reason: card);
      expect(find.byType(MainShell), findsOneWidget, reason: '$card: bottom bar');
      expect(find.byTooltip('Back'), findsOneWidget, reason: '$card: back arrow');
      expect(tester.takeException(), isNull, reason: card);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.state.uri.toString(), Routes.home, reason: '$card: back');
    }
  });
}
