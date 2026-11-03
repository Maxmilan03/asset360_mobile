// Home drill-downs: Upcoming Activities (list + calendar) and Recent Alerts.
import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/more/alerts/alert_detail_screen.dart';
import 'package:asset360_mobile/features/work/inspection/inspection_screen.dart';
import 'package:asset360_mobile/features/work/maintenance/work_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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
  final c = ProviderScope.containerOf(tester.element(find.byType(Asset360App)));
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

final _time = RegExp(r'^\d\d:\d\d [AP]M – \d\d:\d\d [AP]M$');

void main() {
  setUp(() {
    DemoClock.frozen = true;
    DrilldownPage.refreshDelay = Duration.zero;
  });

  test('every activity ends after it starts and sits in 21 Sep – 4 Oct', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final list = c.read(plannedActivitiesProvider);
    expect(list, isNotEmpty);
    for (final a in list) {
      expect(a.end.isAfter(a.start), isTrue, reason: a.refId);
      expect(a.start.isBefore(activityWindowStart), isFalse, reason: a.refId);
      expect(a.start.isBefore(activityWindowEnd), isTrue, reason: a.refId);
    }
    // Weekday labels come from the date itself.
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (final a in list) {
      expect(DateFormat('EEE').format(a.start), days[a.start.weekday - 1]);
    }
    expect(DateFormat('EEE, d MMM yyyy').format(DateTime(2026, 9, 29)), 'Tue, 29 Sep 2026');
  });

  testWidgets('calendar view: today, day selection, week navigation, row opens record', (tester) async {
    await _open(tester, Routes.activitiesView('calendar'));
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Fri, 25 Sep 2026'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'Today'), findsOneWidget);

    // 29 Sep is in the next week: › keeps the weekday (Fri → Fri 2 Oct), then pick Tuesday.
    await _tap(tester, find.byTooltip('Next week'));
    expect(find.text('Sep – Oct 2026'), findsOneWidget);
    expect(find.text('Fri, 2 Oct 2026'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('week-day-9-29')));
    expect(find.text('Tue, 29 Sep 2026'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'Today'), findsNothing);
    expect(find.textContaining('INS-2026-0047'), findsOneWidget);
    expect(find.textContaining('WO-2026-0039'), findsOneWidget);
    final times = find.textContaining(' – ').evaluate().map((e) => (e.widget as Text).data!).where(_time.hasMatch);
    expect(times.length, 2);

    await _tap(tester, find.byTooltip('Next week'));
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Tue, 6 Oct 2026'), findsOneWidget);
    expect(find.text('Nothing scheduled'), findsOneWidget);
    // Last week of the window: › is disabled.
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded)).onPressed, isNull);
    await _tap(tester, find.byTooltip('Previous week'));
    await _tap(tester, find.byTooltip('Previous week'));
    expect(find.text('Tue, 22 Sep 2026'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('week-day-9-23')));
    expect(find.text('Wed, 23 Sep 2026'), findsOneWidget);

    await _tap(tester, find.byTooltip('Next week'));
    await _tap(tester, find.byKey(const ValueKey('week-day-9-29')));
    await _tap(tester, find.textContaining('WO-2026-0039').first);
    expect(find.byType(WorkOrderScreen), findsOneWidget);
  });

  testWidgets('list view groups by date, filters by kind, row opens inspection', (tester) async {
    final c = await _open(tester, Routes.activities);
    final all = c.read(plannedActivitiesProvider);
    expect(find.text('List View'), findsOneWidget);
    expect(find.text('All (${all.length})'), findsOneWidget);
    expect(find.text('Mon, 21 Sep 2026'), findsNothing); // no activity that day
    expect(find.text('Tue, 22 Sep 2026'), findsOneWidget);
    expect(find.text('Fri, 25 Sep 2026'), findsOneWidget);

    final ins = all.where((a) => a.refId.startsWith('INS')).length;
    await _tap(tester, find.text('Inspections ($ins)'));
    expect(find.textContaining('WO-2026-0045'), findsNothing);
    await _tap(tester, find.textContaining('INS-2026-0047'));
    expect(find.byType(InspectionScreen), findsOneWidget);
  });

  testWidgets('toggle switches between list and calendar', (tester) async {
    await _open(tester, Routes.activities);
    await _tap(tester, find.text('Calendar View'));
    expect(find.byTooltip('Next week'), findsOneWidget);
    await _tap(tester, find.text('List View'));
    expect(find.byTooltip('Next week'), findsNothing);
  });

  testWidgets('recent alerts: tab counts, filters, row opens alert detail', (tester) async {
    final c = await _open(tester, Routes.recentAlerts);
    final alerts = c.read(alertsProvider);
    int n(List<String> sev) => alerts.where((a) => sev.contains(a.severity)).length;
    final crit = n([Severity.critical]), warn = n([Severity.high, Severity.medium]), info = n([Severity.low]);
    expect(crit + warn + info, alerts.length);
    expect(find.text('All (${alerts.length})'), findsOneWidget);
    expect(find.text('Critical ($crit)'), findsOneWidget);
    expect(find.text('Warning ($warn)'), findsOneWidget);
    expect(find.text('Info ($info)'), findsOneWidget);

    await _tap(tester, find.byTooltip('Filter alerts'));
    await _tap(tester, find.widgetWithText(FilterChip, 'Low Battery').first);
    await _tap(tester, find.text('Apply'));
    final low = alerts.where((a) => a.type == 'Low Battery').length;
    expect(low, lessThan(alerts.length));
    expect(find.text('All ($low)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Low Battery'), findsOneWidget);
    await _tap(tester, find.text('Clear all'));
    expect(find.text('All (${alerts.length})'), findsOneWidget);

    await _tap(tester, find.text('Info ($info)'));
    expect(find.widgetWithText(StatusChip, Severity.critical), findsNothing);
    final firstLow =
        (alerts.where((a) => a.severity == Severity.low).toList()..sort((a, b) => b.at.compareTo(a.at))).first;
    await _tap(tester, find.text(firstLow.message).first);
    expect(find.byType(AlertDetailScreen), findsOneWidget);
  });
}
