import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/checklist/checklist.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/inspections_mock.dart';
import 'package:asset360_mobile/data/models/inspection.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
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

const _ins = 'INS-2026-0045';

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

  test('checklist engine: negatives, ranges, score and every template', () {
    const pressure = CheckItem(code: '2.1', label: 'Pressure', type: CheckType.number, unit: 'bar', min: 6, max: 9);
    expect(pressure.answered, isFalse);
    expect(pressure.copyWith(value: '7.5').inRange, isTrue);
    expect(pressure.copyWith(value: '9.4').negative, isTrue);
    expect(pressure.rangeLabel, '6 – 9 bar');
    const leak = CheckItem(code: '1.2', label: 'Leakage', type: CheckType.yesNo, options: ['No', 'Yes']);
    expect(leak.copyWith(value: 'Yes').negative, isTrue);
    expect(leak.copyWith(value: 'No').passed, isTrue);
    const tick = CheckItem(code: 'T', label: 'Oil', type: CheckType.tick, unit: 'mm/s', min: 0, max: 4);
    expect(tick.copyWith(value: CheckItem.done).answered, isTrue);
    expect(tick.copyWith(reading: '7').negative, isTrue);
    const photo = CheckItem(code: 'P', label: 'Photo', type: CheckType.photo);
    expect(photo.copyWith(photos: ['a.jpg']).answered, isTrue);
    const sign = CheckItem(code: 'S', label: 'Sign', type: CheckType.signature);
    expect(
      sign
          .copyWith(
            signature: [
              [(0.1, 0.1), (0.5, 0.5)],
            ],
          )
          .answered,
      isTrue,
    );

    final c = ProviderContainer();
    addTearDown(c.dispose);
    final ins = c.read(inspectionByIdProvider(_ins))!;
    expect(ins.sections.map((s) => '${s.answered}/${s.items.length}'), ['4/4', '3/4', '1/3', '0/1']);
    expect(ins.answeredQuestions, 8);
    for (final t in inspectionTemplates.keys) {
      final id = c.read(inspectionsProvider.notifier).create(assetId: 'FP-0021', template: t, dueAt: DemoClock.now);
      final created = c.read(inspectionByIdProvider(id))!;
      expect(created.answeredQuestions, 0, reason: t);
      expect(created.totalQuestions, greaterThan(0), reason: t);
    }
  });

  testWidgets('hub: tile badges equal tab counts; Findings tile lists open findings', (tester) async {
    final c = await _open(tester, Routes.inspection);
    final all = c.read(inspectionsProvider);
    final me = c.read(currentUserProvider).id;
    expect(find.text('My Inspections (${all.mine(me).length})'), findsOneWidget);
    expect(find.text('Due (${all.dueSoon.length})'), findsOneWidget);
    expect(find.text('Overdue (${all.overdue.length})'), findsOneWidget);
    // The Overdue tile badge shows the same number as the tab.
    final overdueTile = find.ancestor(of: find.text('Overdue').first, matching: find.byType(Stack)).first;
    expect(
      find.descendant(of: overdueTile, matching: find.text('${all.overdue.length}')),
      all.overdue.isEmpty ? findsNothing : findsOneWidget,
    );

    await _tap(tester, find.text('Due Today').first);
    expect(find.text('Due Today (${all.dueToday.length})'), findsOneWidget);

    await _tap(tester, find.text('Findings'));
    expect(find.text('Open (${all.openFindings.length})'), findsOneWidget);
  });

  testWidgets('INS-2026-0045 end to end: auto-finding, range check, summary, submit, WO from finding', (tester) async {
    final c = await _open(tester, Routes.inspectionDetail(_ins));
    expect(find.text('8 / 12'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);

    // A negative answer opens Add Finding.
    await _tap(tester, find.text('Minor Issue'));
    expect(find.text('Add Finding'), findsOneWidget);
    await _tap(tester, find.text('Save Finding'));
    expect(c.read(inspectionByIdProvider(_ins))!.findings.length, 2);

    await _tap(tester, find.text('Save as Draft'));
    expect(find.text('Draft saved'), findsOneWidget);

    // Section 2: 3 / 4 answered; the flow-rate range check.
    await _tap(tester, find.widgetWithText(FilledButton, 'Next'));
    expect(find.text('3 / 4'), findsWidgets);
    expect(find.byTooltip('Expected range: 400 – 600 LPM'), findsOneWidget);
    final flow = find.byType(TextField).at(1);
    await tester.enterText(flow, '700');
    await tester.pumpAndSettle();
    expect(find.textContaining('Out of range'), findsOneWidget);
    expect(find.text('Add Finding'), findsOneWidget);
    await tester.enterText(flow, '520');
    await tester.pumpAndSettle();
    expect(find.text('Normal Range: 400 – 600 LPM'), findsOneWidget);
    expect(find.text('9 / 12'), findsOneWidget);

    // Sections 3 and 4.
    await _tap(tester, find.text('Save & Next'));
    await _tap(tester, find.text('Good'));
    await _tap(tester, find.text('Yes').first);
    await _tap(tester, find.text('Save & Next'));
    await _tap(tester, find.text('Yes').first);
    await _tap(tester, find.text('Save & Review'));

    // Summary & Submit.
    expect(find.text('Summary & Submit'), findsOneWidget);
    await _tap(tester, find.text('Submit'));
    expect(find.text('Sign to submit the inspection'), findsOneWidget);
    final pad = find.byKey(const ValueKey('signature-pad'));
    await tester.ensureVisible(pad);
    await tester.pumpAndSettle();
    await tester.drag(pad, const Offset(100, 20));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Submit'));
    expect(find.text('$_ins completed'), findsOneWidget);
    expect(c.read(inspectionByIdProvider(_ins))!.isCompleted, isTrue);
    expect(c.read(inspectionsProvider).completed.any((i) => i.id == _ins), isTrue);
    await _tap(tester, find.text('Done'));

    // Open findings → Create Work Order (prefilled) links the finding.
    expect(find.text('Open findings (2)'), findsOneWidget);
    await _tap(tester, find.text('Create Work Order').first);
    expect(find.text('Minor corrosion on suction flange'), findsOneWidget);
    final wos = c.read(workOrdersProvider).length;
    await _tap(tester, find.widgetWithText(FilledButton, 'Create Work Order'));
    expect(c.read(workOrdersProvider).length, wos + 1);
    final f = c.read(inspectionByIdProvider(_ins))!.findings.first;
    expect(f.status, FindingStatus.actionTaken);
    expect(f.workOrderId, isNotNull);
  });

  testWidgets('Create Inspection from a template; finding detail closes a finding', (tester) async {
    final c = await _open(tester, Routes.createInspection);
    await _tap(tester, find.text('Schedule'));
    expect(find.text('Choose the asset to inspect'), findsOneWidget);
    await _tap(tester, find.text('Select asset'));
    await tester.enterText(find.byType(TextField).last, 'FE-0042');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('FE-0042').last);
    await _tap(tester, find.text('Select template'));
    await _tap(tester, find.text('Fire Extinguisher Monthly').last);
    final count = c.read(inspectionsProvider).length;
    await _tap(tester, find.text('Schedule'));
    expect(c.read(inspectionsProvider).length, count + 1);
    final created = c.read(inspectionsProvider).first;
    expect(created.template, 'Fire Extinguisher Monthly');
    expect(created.totalQuestions, 5);
    await _tap(tester, find.text('Done'));

    c.read(routerProvider).go(Routes.finding('FND-2026-0102'));
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Close Finding'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Close Finding'));
    expect(c.read(inspectionsProvider).findings.firstWhere((f) => f.id == 'FND-2026-0102').status, 'Closed');
  });

  for (final MapEntry(key: phone, value: size) in _phones.entries) {
    testWidgets('$phone phone: inspection screens lay out without overflow (long texts too)', (tester) async {
      final c = await _open(tester, Routes.inspection, size: size);
      final f = c
          .read(inspectionsProvider.notifier)
          .addFinding(_ins, title: _long, severity: 'High', description: _long);
      for (final route in [
        for (final t in ['mine', 'due', 'overdue', 'all', 'dueToday', 'completed']) Routes.inspectionTab(t),
        for (final t in ['details', 'checklist', 'findings', 'documents']) Routes.inspectionDetail(_ins, tab: t),
        Routes.inspectionFindings,
        Routes.finding('FND-2026-0101'),
        Routes.finding(f),
        Routes.createInspection,
      ]) {
        await _visit(tester, c, route);
      }
    });
  }

  testWidgets('hub: a search with no match shows the empty state', (tester) async {
    await _open(tester, Routes.inspectionTab('all'));
    await tester.enterText(find.byType(TextField), 'no-such-inspection');
    await tester.pumpAndSettle();
    expect(find.text('No inspections'), findsOneWidget);
  });
}
