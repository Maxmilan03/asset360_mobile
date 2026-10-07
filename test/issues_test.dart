import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/issue.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

Future<ProviderContainer> _open(WidgetTester tester, String route, {Size size = const Size(1170, 2532)}) async {
  tester.view.physicalSize = size;
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

/// Small (360x640 dp) and large (430x932 dp) phones at device pixel ratio 3.
const _phones = {'small 360x640': Size(1080, 1920), 'large 430x932': Size(1290, 2796)};

/// A long text that must be ellipsized (or wrap) everywhere it is shown.
final _long = List.filled(12, 'Very long description text').join(' ');

/// Opens [route], waits for the loading shimmer, scrolls the page to the end and back, and checks
/// that nothing overflowed.
Future<void> _visit(WidgetTester tester, ProviderContainer c, String route) async {
  c.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: route);
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  if (page.evaluate().isNotEmpty) {
    await tester.drag(page.first, const Offset(0, -4000), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$route (scrolled)');
    await tester.drag(page.first, const Offset(0, 4000), warnIfMissed: false);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => DemoClock.frozen = true);

  test('counts; a Critical report raises an alert and a notification; close and link a WO', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final issues = c.read(issuesProvider);
    expect(issues.length, 22);
    expect(issues.mine('rex').length, 6);
    expect(issues.open.length, 10);
    expect(issues.resolved.length, 12);

    final alerts = c.read(alertsProvider).length;
    final unread = c.read(unreadNotificationCountProvider);
    final n = c.read(issuesProvider.notifier);
    final id = n.report(
      assetId: 'GEN-00045',
      title: 'Fuel leak',
      type: 'Leakage',
      priority: 'Critical',
      description: 'Diesel dripping from the return line.',
      location: 'Main Plant / Building A',
    );
    expect(id, 'ISS-2026-0057');
    expect(c.read(alertsProvider).length, alerts + 1);
    expect(c.read(unreadNotificationCountProvider), unread + 1);
    expect(c.read(issuesProvider).open.length, 11);

    n.linkWorkOrder(id, 'WO-2026-0099');
    expect(c.read(issueByIdProvider(id))!.status, IssueStatus.inProgress);
    n.close(id, 'Return line clamp replaced');
    final closed = c.read(issueByIdProvider(id))!;
    expect(closed.status, IssueStatus.closed);
    expect(closed.resolution, 'Return line clamp replaced');
    expect(c.read(issuesProvider).resolved.length, 13);
  });

  testWidgets('list: computed tabs, search, swipe right marks my issue resolved', (tester) async {
    final c = await _open(tester, Routes.issues);
    expect(find.text('All Issues (22)'), findsOneWidget);
    expect(find.text('My Issues (6)'), findsOneWidget);
    expect(find.text('Open (10)'), findsOneWidget);
    expect(find.text('Resolved (12)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'AHU-03');
    await tester.pumpAndSettle();
    expect(find.text('ISS-2026-0055'), findsOneWidget);
    expect(find.text('ISS-2026-0056'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.drag(find.text('ISS-2026-0056'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(FilledButton, 'Mark Resolved'));
    expect(c.read(issueByIdProvider('ISS-2026-0056'))!.status, IssueStatus.resolved);
    expect(find.text('Resolved (13)'), findsOneWidget);
  });

  testWidgets('report: validation, Critical submit updates the bell, then Create Work Order now', (tester) async {
    final c = await _open(tester, Routes.withAsset(Routes.reportIssue, 'GEN-00045'));
    expect(find.text('GEN-00045'), findsOneWidget);
    await _tap(tester, find.text('Submit Issue'));
    expect(find.text('Choose the issue type'), findsOneWidget);
    expect(find.text('Choose the priority'), findsOneWidget);

    await _tap(tester, find.text('Select type'));
    await _tap(tester, find.text('Breakdown').last);
    await _tap(tester, find.text('Critical'));
    await tester.enterText(find.byType(TextField).at(0), 'Generator not starting');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Starter motor clicks but engine is not cranking. Battery and fuse OK.',
    );
    await tester.pumpAndSettle();
    expect(find.text('69/500'), findsOneWidget);
    final unread = c.read(unreadNotificationCountProvider);
    await _tap(tester, find.text('Submit Issue'));
    expect(find.text('Issue ISS-2026-0057 submitted'), findsOneWidget);
    expect(c.read(unreadNotificationCountProvider), unread + 1);

    await _tap(tester, find.text('Create Work Order now'));
    expect(find.text('Generator not starting'), findsOneWidget);
    final wos = c.read(workOrdersProvider).length;
    await _tap(tester, find.widgetWithText(FilledButton, 'Create Work Order'));
    expect(c.read(workOrdersProvider).length, wos + 1);
    final issue = c.read(issueByIdProvider('ISS-2026-0057'))!;
    expect(issue.workOrderIds, hasLength(1));
    expect(c.read(workOrderByIdProvider(issue.workOrderIds.single))!.issueId, 'ISS-2026-0057');
  });

  testWidgets('detail: Update Status with comment, timeline comment, Close Issue', (tester) async {
    final c = await _open(tester, Routes.issueDetail('ISS-2026-0055'));
    expect(find.text('Work Orders (0)'), findsOneWidget);
    await _tap(tester, find.text('Update Status'));
    await _tap(tester, find.text(IssueStatus.onHold).last);
    await tester.enterText(find.byType(TextField).last, 'Waiting for compressor');
    await _tap(tester, find.widgetWithText(FilledButton, 'Update Status').last);
    expect(c.read(issueByIdProvider('ISS-2026-0055'))!.status, IssueStatus.onHold);

    await _tap(tester, find.text('Timeline'));
    expect(find.text('Waiting for compressor'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Vendor visit booked for tomorrow');
    await _tap(tester, find.byTooltip('Post comment'));
    expect(find.text('Vendor visit booked for tomorrow'), findsOneWidget);

    await _tap(tester, find.text('Close Issue'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Close Issue'));
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Compressor contactor replaced');
    await _tap(tester, find.widgetWithText(FilledButton, 'Close Issue'));
    expect(c.read(issueByIdProvider('ISS-2026-0055'))!.status, IssueStatus.closed);
  });

  for (final MapEntry(key: phone, value: size) in _phones.entries) {
    testWidgets('$phone phone: issue screens lay out without overflow (long texts too)', (tester) async {
      final c = await _open(tester, Routes.issues, size: size);
      final id = c
          .read(issuesProvider.notifier)
          .report(
            assetId: 'GEN-00045',
            title: _long,
            type: 'Breakdown',
            priority: 'High',
            description: _long,
            location: _long,
          );
      for (final route in [
        for (final t in ['all', 'mine', 'open', 'resolved']) Routes.issuesTab(t),
        Routes.reportIssue,
        Routes.withAsset(Routes.reportIssue, 'GEN-00045'),
        for (final t in ['details', 'workOrders', 'timeline', 'attachments']) ...[
          Routes.issueDetail('ISS-2026-0056', tab: t),
          Routes.issueDetail(id, tab: t),
        ],
      ]) {
        await _visit(tester, c, route);
      }
    });
  }

  testWidgets('list: a search with no match shows the empty state', (tester) async {
    await _open(tester, Routes.issues);
    await tester.enterText(find.byType(TextField), 'no-such-issue');
    await tester.pumpAndSettle();
    expect(find.text('No issues'), findsOneWidget);
  });
}
