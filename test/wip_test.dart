import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/wip.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/wip_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _mo = 'MO-2026-0018';

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

Future<void> _settleSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Scrolls the page until the tab [label] is built and visible, then taps it.
Future<void> _showTab(WidgetTester tester, String label) async {
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
  await tester.scrollUntilVisible(find.text(label), 150, scrollable: page);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => DemoClock.frozen = true);

  test('run MO-2026-0018 from AOI to completion; summary and stations stay in sync', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(wipProvider.notifier);
    ProductionOrder mo() => c.read(wipProvider).order(_mo)!;
    expect(mo().currentStation, 'AOI Line 1');
    expect(mo().locationPath, 'Factory 1 > Production Floor > AOI Line 1');
    expect((mo().progress * 100).round(), 64);
    final inProcess = c.read(wipProvider).summary.inProcess;

    // Only the next operation in sequence can start.
    expect(n.startOperation(_mo, 3), isFalse);
    n.moveToNext(_mo);
    expect(mo().operations[1].status, OpStatus.completed);
    expect(mo().operations[2].status, OpStatus.inProgress);
    expect(mo().currentStation, 'Assembly Station 3');
    expect(mo().scans.first.location, 'Assembly Station 3');

    // A failed quality check: red step, finding, order Delayed; rework puts it back In Process.
    n.moveToNext(_mo, qcPassed: false, note: 'Missing screw');
    expect(mo().operations[2].status, OpStatus.failed);
    expect(mo().status, MoStatus.delayed);
    expect(mo().quality.last.passed, isFalse);
    expect(c.read(wipProvider).summary.inProcess, inProcess - 1);
    n.rework(_mo, 2);
    expect(mo().status, MoStatus.inProcess);

    expect(n.completeOrder(_mo), isFalse);
    n.moveToNext(_mo); // Assembly → Testing
    n.moveToNext(_mo); // Testing → Packing
    n.endOperation(_mo, 4, good: 10, scrap: 0);
    expect(mo().allOpsDone, isTrue);
    expect(mo().completedQty, 330);
    final done = c.read(wipProvider).summary.completedToday;
    expect(n.completeOrder(_mo), isTrue);
    expect(mo().status, MoStatus.completed);
    expect(mo().completedQty, 500);
    expect(c.read(wipProvider).summary.completedToday, done + 1);
    expect(mo().currentStation, 'Dispatch');

    // Issue from Inventory reduces stock.
    final ct = c.read(partByIdProvider('RL-24V'))!.qty;
    final qty = n.issueComponent('MO-2026-0018', 1);
    expect(qty, 8);
    expect(c.read(partByIdProvider('RL-24V'))!.qty, ct - 8);
  });

  testWidgets('hub: KPIs, tabs, tiles; row station equals the WIP Tracking station', (tester) async {
    final c = await _open(tester, Routes.wip);
    expect(find.text('All WIP (124)'), findsOneWidget);
    expect(find.text('In Process (78)'), findsOneWidget);
    expect(find.text('Completed (82)'), findsOneWidget);
    expect(find.text('Delayed (16)'), findsOneWidget);
    expect(find.text('Current Station:  AOI Line 1'), findsOneWidget);
    await tester.drag(find.byWidgetPredicate((w) => w is ScrollView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Showing 4 of 124'), findsOneWidget);
    await tester.drag(find.byWidgetPredicate((w) => w is ScrollView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Delayed').first);
    expect(find.text('MO-2026-0017'), findsOneWidget);
    expect(find.text('MO-2026-0018'), findsNothing);
    await _tap(tester, find.text('On Hold').first);
    expect(find.text('MO-2026-0014'), findsOneWidget);
    await _tap(tester, find.byTooltip('Show all'));

    // Start Operation sheet lists only orders with nothing running.
    await _tap(tester, find.text('Start Operation'));
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.textContaining('MO-2026-0018')), findsNothing);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.textContaining('MO-2026-0014')), findsNothing);
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();

    // End Operation on MO-2026-0016.
    await _tap(tester, find.text('End Operation'));
    await _tap(tester, find.text('MO-2026-0016 · Pressure Testing'));
    await _tap(tester, find.widgetWithText(FilledButton, 'End Operation'));
    expect(c.read(wipProvider).order('MO-2026-0016')!.operations[1].status, OpStatus.completed);

    await _settleSnack(tester);
    await _tap(tester, find.text('Serial No:  PCB-A-4587'));
    expect(find.text('WIP Tracking'), findsOneWidget);
    expect(find.text('AOI Line 1'), findsWidgets);
  });

  testWidgets('WIP Tracking: move with QC pass and fail, station scan', (tester) async {
    final c = await _open(tester, Routes.wipUnit('PCB-A-4587'));
    expect(find.text('Factory 1 > Production Floor > AOI Line 1'), findsOneWidget);
    await _tap(tester, find.text('Move to Next Operation'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Move'));
    await _tap(tester, find.text('Yes'));
    expect(c.read(wipProvider).order(_mo)!.currentStation, 'Assembly Station 3');
    expect(find.text('Factory 1 > Production Floor > Assembly Station 3'), findsOneWidget);

    await _settleSnack(tester);
    await _tap(tester, find.text('Move to Next Operation'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Move'));
    await _tap(tester, find.text('No'));
    await tester.enterText(find.byType(TextField), 'Connector misaligned');
    await _tap(tester, find.text('Record Failure'));
    final mo = c.read(wipProvider).order(_mo)!;
    expect(mo.operations[2].status, OpStatus.failed);
    expect(mo.quality.last.note, 'Connector misaligned');

    await _settleSnack(tester);
    final scans = c.read(wipProvider).order(_mo)!.scans.length;
    await _tap(tester, find.byTooltip('Scan station tag'));
    await _tap(tester, find.text('STATION:Assembly Station 3'));
    expect(c.read(wipProvider).order(_mo)!.scans.length, scans + 1);
  });

  testWidgets('Production Order: Start only in sequence, Pause/Resume, issue, notes, complete', (tester) async {
    final c = await _open(tester, Routes.productionOrder('MO-2026-0016'));
    expect(find.text('Production Order'), findsOneWidget);
    expect(find.text('65%'), findsOneWidget);

    // Running step shows Pause / End; pending steps Start disabled.
    await tester.drag(find.byWidgetPredicate((w) => w is ScrollView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);
    for (final b in tester.widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Start'))) {
      expect(b.onPressed, isNull);
    }
    await _tap(tester, find.text('End'));
    await _tap(tester, find.widgetWithText(FilledButton, 'End Operation'));
    await _settleSnack(tester);
    // Now the next step can start.
    final start = find.widgetWithText(FilledButton, 'Start').first;
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    await _tap(tester, start);
    expect(c.read(wipProvider).order('MO-2026-0016')!.operations[2].status, OpStatus.inProgress);

    await _settleSnack(tester);
    await _tap(tester, find.text('Pause WO'));
    await _tap(tester, find.text('Material shortage'));
    expect(c.read(wipProvider).order('MO-2026-0016')!.status, MoStatus.onHold);
    await _settleSnack(tester);
    await _tap(tester, find.text('Resume').last);
    expect(c.read(wipProvider).order('MO-2026-0016')!.status, MoStatus.inProcess);

    await _settleSnack(tester);
    await _tap(tester, find.text('Complete Work Order'));
    expect(find.textContaining('Finish every operation first'), findsOneWidget);

    await _settleSnack(tester);
    await _tap(tester, find.text('Notes'));
    await tester.enterText(find.byType(TextField), 'Seal kit changed');
    await _tap(tester, find.byTooltip('Add note'));
    expect(find.text('Seal kit changed'), findsOneWidget);
  });

  for (final (label, size) in [('small 360x640', const Size(1080, 1920)), ('large 430x932', const Size(1290, 2796))]) {
    testWidgets('$label phone: WIP screens lay out without overflow', (tester) async {
      final c = await _open(tester, Routes.wip, size: size);
      for (final route in [
        Routes.wip,
        Routes.wipUnit('PCB-A-4587'),
        Routes.wipUnit('CPB-3201'),
        Routes.productionOrder(_mo),
        Routes.productionOrder('MO-2026-0017'),
        Routes.productionOrder('MO-2026-0015'),
      ]) {
        c.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        final tabs = route.contains('/unit/')
            ? ['Process Flow', 'Location History', 'Documents', 'Overview']
            : route == Routes.wip
            ? <String>[]
            : ['Components', 'Resources', 'Quality', 'Notes', 'Operations'];
        for (final t in tabs) {
          await _showTab(tester, t);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$route · $t');
        }
      }
    });
  }
}
