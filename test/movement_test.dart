import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
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

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

/// Picks the last day of the month in the open date picker (always in the future here).
Future<void> _pickDate(WidgetTester tester) async {
  await tester.tap(find.text('30').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String dropdownHint, String option, {int index = 0}) async {
  await tester.ensureVisible(find.text(dropdownHint).at(index));
  await tester.tap(find.text(dropdownHint).at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => DemoClock.frozen = true);

  test('transfer lifecycle: pending → approved → in transit → received updates the asset and counts', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(movementsProvider.notifier);
    expect(c.read(movementsProvider).mine('rex').length, 8);
    expect(c.read(movementsProvider).pending.length, 4);
    expect(c.read(movementsProvider).toApprove('rex').length, 2);

    final id = n.submit(
      assetId: 'LAP-0098',
      type: MoveType.transfer,
      from: const MovePlace('IT Store (Dubai)'),
      to: const MovePlace('Room 102', 'Head Office', 'Dubai Office', 'Head Office / Building A – Room 102'),
      newCustodian: 'Sara Khan (Finance)',
      requiredDate: DemoClock.today,
      reason: 'Department Transfer',
    );
    expect(id, 'MOV-2026-0048');
    expect(c.read(movementsProvider).mine('rex').length, 9);
    expect(c.read(movementsProvider).pending.length, 5);

    n.approve(id);
    n.dispatch(id);
    expect(c.read(assetByIdProvider('LAP-0098'))!.status, 'In Transit');
    n.markReceived(id);
    final lap = c.read(assetByIdProvider('LAP-0098'))!;
    expect(lap.location, 'Head Office / Building A – Room 102');
    expect(lap.custodian, 'Sara Khan (Finance)');
    expect(lap.status, 'Active');
    expect(c.read(movementByIdProvider(id))!.timeline.map((t) => t.title), [
      'Submitted',
      'Approved',
      'In Transit',
      'Completed',
    ]);

    // Approving one of Rex's approvals lowers the Home Approvals count.
    n.approve('MOV-2026-0047');
    expect(c.read(movementsProvider).toApprove('rex').length, 1);

    // Return clears the custodian and moves the asset; check-in records the condition.
    n.submit(
      assetId: 'TL-034',
      type: MoveType.checkIn,
      from: const MovePlace('Admin Block – 2nd Floor'),
      to: const MovePlace('Admin Block – 2nd Floor'),
      condition: 'Fair',
    );
    expect(c.read(assetByIdProvider('TL-034'))!.custodian, 'Unassigned');
    expect(c.read(assetByIdProvider('TL-034'))!.condition, 'Fair');
    expect(c.read(movementsProvider).checkedOutAssetIds, isNot(contains('TL-034')));
  });

  testWidgets('hub counts, then the 5-step transfer submits MOV-2026-0048 and My Requests updates', (tester) async {
    final c = await _open(tester, Routes.movement);
    expect(find.text('My Requests (8)'), findsOneWidget);
    expect(find.text('Pending Approval (4)'), findsOneWidget);
    expect(find.text('MOV-2026-0045'), findsOneWidget);

    await tester.tap(find.text('Transfer Asset'));
    await tester.pumpAndSettle();
    final next = find.widgetWithText(FilledButton, 'Next');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);

    await tester.tap(find.text('Search Asset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'LAP-0098');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AssetListTile), matching: find.text('LAP-0098')));
    await tester.pumpAndSettle();
    expect(find.text('Selected Asset'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();

    // From: prefilled.
    expect(find.text('IT Store (Dubai) – Head Office, Building A, Room 101'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    // To: Department → Finance.
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the site, building and floor'), findsOneWidget);
    await tester.tap(find.text('Department'));
    await tester.pumpAndSettle();
    await _choose(tester, 'Select', 'Finance');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    // Details: custodian suggested from the department; date, reason.
    expect(find.text('Sara Khan (Finance)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the required date'), findsOneWidget);
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await _pickDate(tester);
    await _choose(tester, 'Select reason', 'Department Transfer');
    // Approver: Ahmed by default; the signed-in user can pick themselves (single-login demo).
    await _choose(tester, 'Ahmed Ali (Operations)', 'Rex Kumar (DCS) – self-approve (demo)');
    await tester.enterText(find.byType(TextField), 'For Finance team use');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    // Review.
    expect(find.text('Review the details and submit for approval'), findsOneWidget);
    expect(find.text('Finance Department'), findsOneWidget);
    expect(find.text('For Finance team use'), findsOneWidget);
    await tester.tap(find.text('Submit for Approval'));
    await tester.pumpAndSettle();
    expect(find.text('Request MOV-2026-0048 submitted'), findsOneWidget);
    expect(find.textContaining('Approve it from Home → My Approvals.'), findsOneWidget);
    await tester.tap(find.text('Back to Movement & Custody'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, Routes.movement);
    expect(find.text('My Requests (9)'), findsOneWidget);
    expect(find.text('Pending Approval (5)'), findsOneWidget);
    expect(c.read(movementByIdProvider('MOV-2026-0048'))!.newCustodian, 'Sara Khan (Finance)');
    expect(c.read(movementByIdProvider('MOV-2026-0048'))!.approverId, 'rex');
  });

  testWidgets('request detail: approve → in transit → received; cancel my pending request', (tester) async {
    final c = await _open(tester, Routes.movementRequest('MOV-2026-0046'));
    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5)); // SnackBar gone
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark In Transit'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(c.read(assetByIdProvider('PRJ-0042'))!.status, 'In Transit');
    await tester.tap(find.text('Mark as Received'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Received'));
    await tester.pumpAndSettle();
    expect(c.read(movementByIdProvider('MOV-2026-0046'))!.status, MoveStatus.completed);
    expect(c.read(assetByIdProvider('PRJ-0042'))!.location, 'IT Store (Dubai) – Head Office – Building A – Room 101');

    c.read(routerProvider).go(Routes.movementRequest('MOV-2026-0045'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel Request'));
    await tester.pumpAndSettle();
    expect(c.read(movementByIdProvider('MOV-2026-0045'))!.status, MoveStatus.cancelled);
    expect(c.read(movementsProvider).pending.length, 2);

    // Reject from detail asks for a reason.
    c.read(routerProvider).go(Routes.movementRequest('MOV-2026-0047'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Not needed');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(c.read(movementByIdProvider('MOV-2026-0047'))!.status, MoveStatus.rejected);
  });

  testWidgets('Check Out then Check In change the custodian; Movement History lists them', (tester) async {
    final c = await _open(tester, Routes.withAsset(Routes.checkOut, 'LAP-0098'));
    expect(find.text('LAP-0098'), findsOneWidget);
    await tester.tap(find.text('Confirm Check Out'));
    await tester.pumpAndSettle();
    expect(find.text('Choose who takes the asset'), findsOneWidget);
    await _choose(tester, 'Select', 'Sara Khan (Finance)');
    await _tapText(tester, 'Select date');
    await _pickDate(tester);
    await tester.enterText(find.byType(TextField), 'Audit visit');
    await tester.tap(find.text('Confirm Check Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(c.read(assetByIdProvider('LAP-0098'))!.custodian, 'Sara Khan (Finance)');
    expect(c.read(movementsProvider).checkedOutAssetIds, contains('LAP-0098'));

    c.read(routerProvider).go(Routes.checkIn);
    await tester.pumpAndSettle();
    await tester.tap(find.text('LAP-0098'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Check In'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(c.read(assetByIdProvider('LAP-0098'))!.custodian, 'Unassigned');

    c.read(routerProvider).go(Routes.movementHistory);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(MoveType.checkIn));
    await tester.pumpAndSettle();
    await tester.tap(find.text(MoveType.checkIn));
    await tester.pumpAndSettle();
    expect(find.text('Check In · LAP-0098'), findsOneWidget);
    expect(find.text('Check Out · LAP-0098'), findsNothing);
  });

  for (final (name, size) in [('small 360x640', const Size(1080, 1920)), ('large 430x932', const Size(1290, 2796))]) {
    testWidgets('$name phone: movement screens lay out without overflow', (tester) async {
      final c = await _open(tester, Routes.movement, size: size);
      for (final route in [
        Routes.movement,
        Routes.withAsset(Routes.transferAsset, 'LAP-0098'),
        Routes.withAssets(Routes.transferAsset, ['MTR-00123', 'GEN-00045']),
        Routes.movementRequest('MOV-2026-0045'),
        Routes.movementRequest('MOV-2026-0044'),
        Routes.movementHistory,
        Routes.checkOut,
        Routes.checkIn,
        Routes.assignCustodian,
        Routes.returnAsset,
      ]) {
        c.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      // Transfer steps 1 → 3 with a preselected asset.
      c.read(routerProvider).go(Routes.withAsset(Routes.transferAsset, 'LAP-0098'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'transfer step ${i + 2}');
      }
      expect(find.text('3. To'), findsOneWidget);
    });
  }

  testWidgets('hub list shows a loading skeleton first, then the requests', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
    );
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    c.read(routerProvider).go(Routes.movement);
    await tester.pump();
    await tester.pump();
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
    expect(find.text('MOV-2026-0045'), findsWidgets);
  });
}
