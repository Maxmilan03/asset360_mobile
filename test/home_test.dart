import 'dart:math' as math;

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true);
}

Future<ProviderContainer> _pumpHome(WidgetTester tester) async {
  DemoClock.frozen = true;
  addTearDown(() => DemoClock.frozen = false);
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Asset360App)));
}

const _phones = {'small 360x640': Size(1080, 1920), 'large 430x932': Size(1290, 2796)};

/// Scrolls the page's vertical scrollable to the end, checking for layout errors (overflow) at each step.
Future<void> _scrollThrough(WidgetTester tester, String reason) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: reason);
  final f = find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical);
  if (f.evaluate().isEmpty) return;
  final pos = tester.state<ScrollableState>(f.first).position;
  for (var i = 0; i < 60 && pos.pixels < pos.maxScrollExtent; i++) {
    pos.jumpTo(math.min(pos.pixels + 300, pos.maxScrollExtent));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$reason @ ${pos.pixels.round()}');
  }
  pos.jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  test('My Tasks: All = Work Orders + Inspections + Approvals', () {
    DemoClock.frozen = true;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final h = c.read(homeDataProvider);
    expect(h.allTasks.length, h.workOrderTasks.length + h.inspectionTasks.length + h.approvalTasks.length);
    expect(h.myWorkOrders, 8);
    expect(h.inspectionsDueToday, 3);
    expect(h.pendingApprovals, 2);
  });

  test('closing WO-2026-0045 lowers the Home Work Orders count; site filter narrows counts', () {
    DemoClock.frozen = true;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(workOrdersProvider.notifier).close('WO-2026-0045', resolution: 'Done', labourHours: 1);
    expect(c.read(homeDataProvider).myWorkOrders, 7);
    c.read(sessionProvider.notifier).switchSite('Dubai Office');
    final h = c.read(homeDataProvider);
    expect(h.filtered, isTrue);
    expect(h.myWorkOrders, 0);
    expect(h.pendingApprovals, 0);
  });

  testWidgets('Home shows computed tiles; approving from My Approvals updates the tile', (tester) async {
    await _pumpHome(tester);
    expect(find.text('Good Morning, Rex!'), findsOneWidget);
    expect(find.text('Fri, 25 Sep 2026'), findsOneWidget);
    expect(find.text('8'), findsWidgets);

    await tester.tap(find.text('Approvals'));
    await tester.pumpAndSettle();
    expect(find.text('My Approvals'), findsOneWidget);
    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('approved'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    final pending = tester.widget<Text>(
      find
          .descendant(
            of: find.ancestor(of: find.text('Pending'), matching: find.byType(Column)).first,
            matching: find.byType(Text),
          )
          .at(0),
    );
    expect(pending.data, '1');
  });

  testWidgets('Customize hides a quick action; More Actions and pull-to-refresh work', (tester) async {
    final c = await _pumpHome(tester);
    expect(find.text('Scan Asset'), findsOneWidget);
    c.read(quickActionsProvider.notifier).toggle('scan');
    await tester.pumpAndSettle();
    expect(find.text('Scan Asset'), findsNothing);

    await tester.tap(find.text('More Actions'));
    await tester.pumpAndSettle();
    expect(find.text('Tracking & IoT'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Good Morning, Rex!'), findsOneWidget);
  });

  testWidgets('Create Work Order validates and adds the WO', (tester) async {
    final c = await _pumpHome(tester);
    await tester.tap(find.text('Create Work Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Work Order'));
    await tester.pumpAndSettle();
    expect(find.text('Select the asset'), findsOneWidget);
    expect(find.text('Enter a short title'), findsOneWidget);

    await tester.tap(find.text('Select an asset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CNC-00123').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Generator – High vibration'), 'Spindle noise');
    final before = c.read(workOrdersProvider).length;
    await tester.tap(find.widgetWithText(FilledButton, 'Create Work Order'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Work order created'), findsOneWidget);
    expect(c.read(workOrdersProvider).length, before + 1);
    expect(c.read(workOrdersProvider).first.title, 'Spindle noise');
  });

  testWidgets('Maintenance Calendar lists the day items', (tester) async {
    await _pumpHome(tester);
    await tester.ensureVisible(find.text('View Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance Calendar'), findsOneWidget);
    expect(find.textContaining('Fri, 25 Sep 2026 ('), findsOneWidget);
    expect(find.text('WO-2026-0045'), findsOneWidget);
  });

  for (final MapEntry(key: name, value: size) in _phones.entries) {
    testWidgets('no overflow on a $name phone: Home, My Tasks (all tabs), My Approvals', (tester) async {
      final c = await _pumpHome(tester);
      tester.view.physicalSize = size;
      await _scrollThrough(tester, 'Home');

      c.read(routerProvider).push(Routes.myTasks);
      await _scrollThrough(tester, 'My Tasks');
      for (final tab in ['Work Orders', 'Inspections', 'Approvals', 'All']) {
        await tester.tap(find.textContaining(tab).first);
        await _scrollThrough(tester, 'My Tasks · $tab');
      }
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();

      c.read(routerProvider).push(Routes.approvals);
      await _scrollThrough(tester, 'My Approvals');
    });
  }
}
