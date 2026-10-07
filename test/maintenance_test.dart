import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
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

const _wo = 'WO-2026-0045';

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

/// Ticks every checklist item of the current task and completes it.
void _finishCurrentTask(ProviderContainer c) {
  final n = c.read(workOrdersProvider.notifier);
  final wo = c.read(workOrderByIdProvider(_wo))!;
  final t = wo.tasks.firstWhere((t) => t.id == wo.openTaskId);
  for (final item in t.checklist.where((i) => !i.answered)) {
    n.toggleChecklistItem(_wo, t.id, item.code);
  }
  n.completeTask(_wo, t.id);
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

  test('close issues the used parts, releases the rest and sets the asset back to Active', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(workOrdersProvider.notifier);
    expect(c.read(workOrdersProvider).mine('rex').length, 8);
    expect(c.read(assetByIdProvider('GEN-00045'))!.status, 'Under Maintenance');
    final before = c.read(partByIdProvider('BR-6205'))!;

    final af = c.read(partByIdProvider('AF-250-001'))!.reserved;
    n.addPart(_wo, 'AF-250-001', 1);
    expect(c.read(partByIdProvider('AF-250-001'))!.reserved, af + 1);
    n.removePart(_wo, 'AF-250-001');
    expect(c.read(partByIdProvider('AF-250-001'))!.reserved, af);

    while (!c.read(workOrderByIdProvider(_wo))!.allTasksDone) {
      _finishCurrentTask(c);
    }
    n.close(_wo, resolution: 'Bearing replaced', labourHours: 3.5, usedQty: {'BR-6205': 1});
    final wo = c.read(workOrderByIdProvider(_wo))!;
    expect(wo.status, WoStatus.closed);
    expect(wo.parts.single.qty, 1);
    final after = c.read(partByIdProvider('BR-6205'))!;
    expect(after.qty, before.qty - 1); // one issued
    expect(after.reserved, before.reserved - 2); // both released from the reservation
    expect(c.read(assetByIdProvider('GEN-00045'))!.status, 'Active');
    expect(c.read(workOrdersProvider).mine('rex').length, 7);
  });

  testWidgets('hub: computed tabs, badge, search; tile opens PM schedules and Generate WO', (tester) async {
    final c = await _open(tester, Routes.maintenance);
    final all = c.read(workOrdersProvider);
    expect(find.text('My Work Orders (8)'), findsOneWidget);
    expect(find.text('PM Due (${all.pmDue.length})'), findsOneWidget);
    expect(find.text('Overdue (${all.overdue.length})'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'AHU-03');
    await tester.pumpAndSettle();
    expect(find.text('WO-2026-0044'), findsOneWidget);
    expect(find.text(_wo), findsNothing);

    await _tap(tester, find.text('Preventive Maintenance'));
    final count = c.read(workOrdersProvider).length;
    await _tap(tester, find.text('Generate WO now').first);
    await _tap(tester, find.text('Generate WO'));
    expect(c.read(workOrdersProvider).length, count + 1);
  });

  testWidgets('WO-2026-0045: Overview, On Hold reason, Close disabled until tasks are done', (tester) async {
    final c = await _open(tester, Routes.workOrder(_wo));
    expect(find.text('Under Maintenance'), findsOneWidget);
    expect(
      find.textContaining(DemoClock.isOverdue(c.read(workOrderByIdProvider(_wo))!.dueAt) ? 'Overdue by' : 'remaining'),
      findsOneWidget,
    );

    await _tap(tester, find.text('Close Work Order'));
    expect(find.text('Complete all tasks first (1 of 6 done)'), findsOneWidget);

    // Edit the description inline.
    await _tap(tester, find.text('Edit'));
    await tester.enterText(find.byType(TextField), 'Vibration 7 mm/s at bearing housing.');
    await _tap(tester, find.text('Save'));
    expect(c.read(workOrderByIdProvider(_wo))!.description, 'Vibration 7 mm/s at bearing housing.');

    // Status dropdown → On Hold asks for a reason.
    await tester.drag(find.byType(ListView).first, const Offset(0, 800));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('wo-status')));
    await _tap(tester, find.text(WoStatus.onHold).last);
    expect(find.text('Put WO-2026-0045 on hold?'), findsOneWidget);
    await _tap(tester, find.text('Waiting for spare parts'));
    await _tap(tester, find.text('Put On Hold'));
    expect(c.read(workOrderByIdProvider(_wo))!.status, WoStatus.onHold);
    expect(c.read(workOrderByIdProvider(_wo))!.holdReason, 'Waiting for spare parts');

    // Reassign.
    await _tap(tester, find.text('Mohammed Rafi'));
    await _tap(tester, find.text('Suresh Kumar'));
    expect(c.read(workOrderByIdProvider(_wo))!.assigneeId, 'suresh');
  });

  testWidgets('Tasks: checklist, voice note, Complete Task; then close with signature', (tester) async {
    final c = await _open(tester, Routes.workOrderTab(_wo, 'tasks'));
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.text('4 / 6 completed'), findsOneWidget);
    final complete = find.widgetWithText(FilledButton, 'Complete Task');
    expect(tester.widget<FilledButton>(complete).onPressed, isNull);

    await _tap(tester, find.text('Check electrical connections'));
    await _tap(tester, find.text('Check exhaust system'));
    expect(find.text('6 / 6 completed'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Record voice note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record voice note'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Recording…'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Voice note 0:1'), findsOneWidget);

    // Tapping the voice note plays it back (simulated player).
    await _tap(tester, find.textContaining('Voice note 0:1'));
    expect(find.text('Demo playback: no audio was recorded'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('0:02 /'), findsOneWidget);
    await _tap(tester, find.text('Close'));

    await _tap(tester, complete);
    expect(find.text('2 / 6'), findsOneWidget);
    expect(c.read(workOrderByIdProvider(_wo))!.tasks[2].status, TaskStatus.inProgress);

    // Finish the rest, then close from Overview.
    while (!c.read(workOrderByIdProvider(_wo))!.allTasksDone) {
      _finishCurrentTask(c);
    }
    await tester.pump(const Duration(seconds: 5));
    await _tap(tester, find.text('Overview'));
    await _tap(tester, find.text('Close Work Order'));
    expect(find.text('Close $_wo'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Close Work Order').last);
    expect(find.text('Sign to close the work order'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Replaced bearings; vibration 1.6 mm/s');
    await tester.enterText(find.byType(TextField).at(1), '3.5');
    final pad = find.byKey(const ValueKey('signature-pad'));
    await tester.ensureVisible(pad);
    await tester.pumpAndSettle();
    await tester.drag(pad, const Offset(0, 60));
    await tester.drag(pad, const Offset(120, 10));
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(FilledButton, 'Close Work Order').last);
    expect(find.text('$_wo closed'), findsOneWidget);
    await _tap(tester, find.text('Done'));
    final wo = c.read(workOrderByIdProvider(_wo))!;
    expect(wo.status, WoStatus.closed);
    expect(wo.signature, isNotEmpty);
    expect(c.read(assetByIdProvider('GEN-00045'))!.status, 'Active');
    expect(c.read(workOrdersProvider).mine('rex').length, 7);
  });

  testWidgets('Parts: Add Part reserves stock; History lists the log', (tester) async {
    final c = await _open(tester, Routes.workOrderTab(_wo, 'parts'));
    final before = c.read(partByIdProvider('AF-250-001'))!.available;
    await _tap(tester, find.text('Add Part'));
    await _tap(tester, find.textContaining('AF-250-001'));
    await _tap(tester, find.byTooltip('More'));
    await _tap(tester, find.text('Reserve 2 × AF-250-001'));
    expect(c.read(partByIdProvider('AF-250-001'))!.available, before - 2);
    await tester.pump(const Duration(seconds: 5));
    await _tap(tester, find.text('History'));
    expect(find.text('Part added: AF-250-001 × 2'), findsOneWidget);
  });

  for (final MapEntry(key: phone, value: size) in _phones.entries) {
    testWidgets('$phone phone: maintenance screens lay out without overflow (long texts too)', (tester) async {
      final c = await _open(tester, Routes.maintenance, size: size);
      final id = c
          .read(workOrdersProvider.notifier)
          .create(
            assetId: 'GEN-00045',
            title: _long,
            description: _long,
            priority: 'Critical',
            category: 'Corrective Maintenance',
            workType: 'Breakdown',
            dueAt: DemoClock.now.add(const Duration(hours: 5)),
            assigneeId: 'rex',
          );
      for (final route in [
        for (final t in ['mine', 'pm', 'overdue', 'all']) Routes.maintenanceTab(t),
        for (final t in ['overview', 'tasks', 'parts', 'history', 'documents']) Routes.workOrderTab(_wo, t),
        Routes.workOrder(id),
        Routes.workOrder('WO-2026-0142'),
        Routes.pmSchedules,
        Routes.breakdowns,
        Routes.serviceHistory,
        Routes.maintenanceCalendar,
        Routes.createWorkOrder(),
        Routes.createWorkOrder(assetId: 'GEN-00045'),
      ]) {
        await _visit(tester, c, route);
      }
    });
  }

  testWidgets('hub: a search with no match shows the empty state', (tester) async {
    await _open(tester, Routes.maintenanceTab('all'));
    await tester.enterText(find.byType(TextField), 'no-such-work-order');
    await tester.pumpAndSettle();
    expect(find.text('No work orders'), findsOneWidget);
  });
}
