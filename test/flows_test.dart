// Cross-module flows from Prompt 19: each step is driven through the same notifier calls the screens
// make, and every screen-facing count / record is checked after it. The Move flow also runs through the UI.
import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/checklist/checklist.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/inventory.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
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
  final c = ProviderScope.containerOf(tester.element(find.byType(Asset360App)));
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

void main() {
  setUp(() => DemoClock.frozen = true);
  tearDown(() => DemoClock.frozen = false);

  test('1. critical issue → alert + notification → WO → tasks → close → asset Active, Home updates', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    const asset = 'GEN-00046';
    final home0 = c.read(homeDataProvider).myWorkOrders;
    final critical0 = c.read(alertsProvider).withSeverity(Severity.critical).length;
    final unread0 = c.read(unreadNotificationCountProvider);
    final active0 = c.read(orgSummaryProvider).statusCounts[AssetStatus.active]!;

    final issueId = c
        .read(issuesProvider.notifier)
        .report(
          assetId: asset,
          title: 'Engine will not start',
          type: 'Breakdown',
          priority: 'Critical',
          description: 'Starter clicks, engine does not crank.',
          location: c.read(assetByIdProvider(asset))!.location,
        );
    expect(c.read(alertsProvider).withSeverity(Severity.critical).length, critical0 + 1);
    expect(c.read(alertsProvider).first.message, contains(issueId));
    expect(c.read(unreadNotificationCountProvider), unread0 + 1, reason: 'bell badge');

    final woId = c.read(issuesProvider.notifier).createWorkOrder(issueId);
    expect(c.read(issueByIdProvider(issueId))!.workOrderIds, [woId]);
    expect(c.read(homeDataProvider).myWorkOrders, home0 + 1, reason: 'Home Work Orders tile');

    final wos = c.read(workOrdersProvider.notifier);
    wos.updateStatus(woId, WoStatus.inProgress);
    expect(c.read(assetByIdProvider(asset))!.status, AssetStatus.underMaintenance);
    expect(c.read(orgSummaryProvider).statusCounts[AssetStatus.active], active0 - 1);

    for (final t in c.read(workOrderByIdProvider(woId))!.tasks) {
      for (final item in t.checklist) {
        wos.toggleChecklistItem(woId, t.id, item.code);
      }
      wos.completeTask(woId, t.id);
    }
    expect(c.read(workOrderByIdProvider(woId))!.tasks.every((t) => t.isDone), isTrue);

    wos.close(woId, resolution: 'Starter motor replaced', labourHours: 2);
    expect(c.read(workOrderByIdProvider(woId))!.status, WoStatus.closed);
    expect(c.read(assetByIdProvider(asset))!.status, AssetStatus.active);
    expect(c.read(orgSummaryProvider).statusCounts[AssetStatus.active], active0);
    expect(c.read(homeDataProvider).myWorkOrders, home0);
  });

  testWidgets('2. scan → Move → submit (self-approver) → My Approvals → In Transit → Received → location', (
    tester,
  ) async {
    const asset = 'TL-034';
    const target = 'Maintenance Store';
    final c = await _open(tester, Routes.home);
    final approvals0 = c.read(homeDataProvider).pendingApprovals;

    // What the Transfer form submits when the signed-in user picks themselves as the approver (demo).
    final id = c
        .read(movementsProvider.notifier)
        .submit(
          assetId: asset,
          type: MoveType.transfer,
          from: MovePlace(c.read(assetByIdProvider(asset))!.location),
          to: const MovePlace(target),
          reason: 'Maintenance',
          requiredDate: DemoClock.today,
          approverId: c.read(currentUserProvider).id,
        );
    expect(c.read(homeDataProvider).pendingApprovals, approvals0 + 1);

    // Home → My Approvals → Approve.
    c.read(routerProvider).go(Routes.approvals);
    await tester.pumpAndSettle();
    final card = find.ancestor(of: find.text(id), matching: find.byType(AppCard)).first;
    await _tap(tester, find.descendant(of: card, matching: find.widgetWithText(FilledButton, 'Approve')));
    expect(c.read(movementByIdProvider(id))!.status, MoveStatus.approved);
    expect(c.read(homeDataProvider).pendingApprovals, approvals0);

    await tester.pump(const Duration(seconds: 5)); // let the "approved" SnackBar go
    await tester.pumpAndSettle();

    // Request detail → Mark In Transit → Mark as Received.
    c.read(routerProvider).go(Routes.movementRequest(id));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Mark In Transit'));
    expect(c.read(movementByIdProvider(id))!.status, MoveStatus.inTransit);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Mark as Received'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Received'));
    expect(c.read(movementByIdProvider(id))!.status, MoveStatus.completed);
    expect(c.read(assetByIdProvider(asset))!.location, target);
    expect(c.read(assetByIdProvider(asset))!.status, AssetStatus.active);

    // Asset detail and Tracking show the new location; its open alerts follow the asset.
    c.read(routerProvider).go(Routes.assetDetail(asset));
    await tester.pumpAndSettle();
    expect(find.textContaining(target), findsWidgets);
    expect(c.read(trackedAssetsProvider).firstWhere((a) => a.id == asset).location, target);
    c.read(routerProvider).go(Routes.trackingTab('list'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining(target), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining(target), findsWidgets);
    for (final a in c.read(alertsProvider).where((a) => a.assetId == asset && !a.isResolved)) {
      expect(a.location, target, reason: a.id);
    }
  });

  test('3. inspection reading out of range → finding → work order', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    const insId = 'INS-2026-0045';
    final ins = c.read(inspectionsProvider.notifier);
    final open0 = c.read(inspectionsProvider).openFindings.length;

    ins.answer(insId, '2.2', '850'); // flow rate, range 400–600 LPM
    final item = c.read(inspectionByIdProvider(insId))!.sections.item('2.2')!;
    expect(item.negative, isTrue, reason: 'out of range → the screen offers Add Finding');

    final fId = ins.addFinding(insId, title: 'Flow rate above range (850 LPM)', severity: 'High', questionCode: '2.2');
    expect(c.read(inspectionsProvider).openFindings.length, open0 + 1);

    final woId = c
        .read(workOrdersProvider.notifier)
        .create(
          assetId: c.read(inspectionByIdProvider(insId))!.assetId,
          title: 'Flow rate above range',
          priority: 'High',
          category: 'Corrective Maintenance',
          workType: 'Corrective',
          dueAt: DemoClock.now.add(const Duration(days: 1)),
        );
    ins.linkWorkOrder(fId, woId); // what Create Work Order does for a WoPrefill(findingId:)
    final f = c.read(inspectionsProvider).findings.firstWhere((x) => x.id == fId);
    expect(f.workOrderId, woId);
    expect(c.read(workOrderByIdProvider(woId))!.assetId, c.read(inspectionByIdProvider(insId))!.assetId);
  });

  testWidgets('4. offline: complete a task + add a photo → Pending Sync lists them → online → sync runs', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    const woId = 'WO-2026-0045';
    final pending0 = c.read(syncProvider).pending.length;
    final photos0 = c.read(syncProvider).photosToSync;
    c.read(networkProvider.notifier).debugSetReal(NetType.wifi);
    c.read(networkProvider.notifier).setSimulatedOffline(true);
    expect(c.read(isOfflineProvider), isTrue);

    final wos = c.read(workOrdersProvider.notifier);
    final task = c.read(workOrderByIdProvider(woId))!.openTaskId!;
    wos.completeTask(woId, task);
    wos.addTaskPhoto(woId, task, '/photos/seal.jpg');
    final s = c.read(syncProvider);
    expect(s.pending.length, pending0 + 2, reason: 'one WO item + one photo');
    expect(s.pendingOf(SyncKind.workOrder).any((i) => i.refId == woId), isTrue);
    expect(s.photosToSync, photos0 + 1);
    expect(c.read(workOrderByIdProvider(woId))!.savedOffline, isTrue);

    c.read(networkProvider.notifier).setSimulatedOffline(false);
    expect(c.read(syncProvider).running, isTrue, reason: 'auto-sync on Wi-Fi');
    await tester.pump(const Duration(seconds: 30));
    expect(c.read(syncProvider).running, isFalse);
    expect(c.read(syncProvider).pending, isEmpty);
    expect(c.read(workOrderByIdProvider(woId))!.savedOffline, isFalse);
  });

  test('5. receive a PO → stock and the history balance update', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    const poId = 'PO-2026-0131';
    final inv0 = c.read(inventoryProvider);
    final po = inv0.requests.firstWhere((r) => r.id == poId);
    final qty0 = inv0.part(po.partId)!.qty;

    final grn = c.read(inventoryProvider.notifier).receivePo(poId);
    final inv = c.read(inventoryProvider);
    final part = inv.part(po.partId)!;
    expect(part.qty, qty0 + po.qty);
    final last = inv.historyFor(po.partId).first;
    expect((last.ref, last.type, last.qtyChange, last.balanceAfter), (grn, TxnType.received, po.qty, part.qty));
    expect(inv.requests.firstWhere((r) => r.id == poId).status, RequestStatus.received);
    // Every balance in the ledger still chains to the stock on hand.
    final h = inv.historyFor(po.partId).reversed.toList();
    var bal = h.first.balanceAfter - h.first.qtyChange;
    for (final t in h) {
      bal += t.qtyChange;
      expect(t.balanceAfter, bal, reason: t.ref);
    }
  });
}
