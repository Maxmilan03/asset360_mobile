import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/inventory_mock.dart';
import 'package:asset360_mobile/data/models/inventory.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
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

/// Every part's history adds up: each balance = previous + change, last balance = stock,
/// and (for parts with reservation history) reserved = sum of reservation changes.
void _expectConsistent(InventoryState inv) {
  for (final p in inv.parts) {
    final h = inv.historyFor(p.id).reversed.toList();
    if (h.isEmpty) continue;
    var bal = p.id == 'BR-6205' ? br6205OpeningBalance : h.first.balanceAfter - h.first.qtyChange;
    for (final t in h) {
      bal += t.qtyChange;
      expect(t.balanceAfter, bal, reason: '${p.id} ${t.ref}');
    }
    expect(bal, p.qty, reason: '${p.id} stock');
  }
  final br = inv.part('BR-6205')!;
  expect(br.reserved, inv.historyFor('BR-6205').fold<int>(0, (s, t) => s + t.reservedChange));
}

void main() {
  setUp(() => DemoClock.frozen = true);

  test('every stock action keeps quantities, reservations and balances consistent', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(inventoryProvider.notifier);
    _expectConsistent(c.read(inventoryProvider));
    var br = c.read(partByIdProvider('BR-6205'))!;
    expect((br.qty, br.reserved, br.available), (36, 6, 30));

    n.reserve('BR-6205', 3, ref: 'WO-2026-0044');
    expect(c.read(partByIdProvider('BR-6205'))!.available, 27);
    n.unreserve('BR-6205', 3, ref: 'WO-2026-0044');
    n.transfer('BR-6205', 5, to: 'Warehouse B');
    n.adjust('BR-6205', 30, reason: 'Cycle count');
    c.read(workOrdersProvider.notifier).issuePart('WO-2026-0044', 'BR-6205', 2);
    _expectConsistent(c.read(inventoryProvider));
    br = c.read(partByIdProvider('BR-6205'))!;
    expect((br.qty, br.reserved, br.available), (28, 6, 22));
    expect(c.read(inventoryProvider).historyFor('BR-6205').first.type, TxnType.issuedToWo);

    // Receiving an open PO adds stock and a GRN entry; the PO becomes Received.
    final vb = c.read(partByIdProvider('VB-1120'))!.qty;
    final grn = n.receivePo('PO-2026-0131');
    expect(c.read(partByIdProvider('VB-1120'))!.qty, vb + 20);
    expect(c.read(inventoryProvider).request('PO-2026-0131')!.status, RequestStatus.received);
    expect(c.read(inventoryProvider).grn(grn)!.po, 'PO-2026-0131');

    // Pushing available stock to the reorder level posts "Stock Level Low".
    final unread = c.read(unreadNotificationCountProvider);
    n.issue('BR-6205', 12, ref: 'WO-2026-0044');
    expect(c.read(partByIdProvider('BR-6205'))!.available, 10);
    expect(c.read(unreadNotificationCountProvider), unread + 1);
    expect(c.read(notificationsProvider).first.title, 'Stock Level Low');
    _expectConsistent(c.read(inventoryProvider));
  });

  testWidgets('hub: computed tabs, Showing 20 of 124, search and row chips', (tester) async {
    final c = await _open(tester, Routes.inventory);
    // The list shows a shimmer skeleton first, then the rows.
    c.read(routerProvider).go(Routes.purchaseOrders);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
    c.read(routerProvider).go(Routes.inventory);
    await tester.pumpAndSettle();
    expect(find.text('All Items (124)'), findsOneWidget);
    expect(find.text('Low Stock (8)'), findsOneWidget);
    expect(find.text('Reorder (12)'), findsOneWidget);
    expect(find.text('Reserved (6)'), findsOneWidget);
    await tester.drag(find.byWidgetPredicate((w) => w is ScrollView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Showing 20 of 124'), findsOneWidget);
    await tester.drag(find.byWidgetPredicate((w) => w is ScrollView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz-no-such-part');
    await tester.pumpAndSettle();
    expect(find.text('No parts match'), findsOneWidget);
    await _tap(tester, find.text('Clear filters'));
    expect(find.text('No parts match'), findsNothing);
    await tester.enterText(find.byType(TextField), 'bearing');
    await tester.pumpAndSettle();
    expect(find.text('Motor Bearing 6205'), findsOneWidget);
    await _tap(tester, find.text('Motor Bearing 6205'));
    expect(find.text('Part Details'), findsOneWidget);
  });

  testWidgets('Part Details: levels edit, transfer, issue to WO, stock count, create PO', (tester) async {
    final c = await _open(tester, Routes.partDetail('BR-6205'));
    expect(find.text('36'), findsOneWidget);
    expect(c.read(partByIdProvider('BR-6205'))!.available, 30);

    await _tap(tester, find.text('Edit'));
    await tester.enterText(find.byType(TextField).at(0), '12');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await _tap(tester, find.text('Save'));
    expect(find.text('Reorder qty should be more than the reorder level'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '60');
    await _tap(tester, find.text('Save'));
    expect(c.read(partByIdProvider('BR-6205'))!.reorderLevel, 12);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Manage'));
    await _tap(tester, find.text('Transfer Stock'));
    await tester.enterText(find.byType(TextField), '5');
    await _tap(tester, find.byType(DropdownButtonFormField<String>));
    await _tap(tester, find.text('Warehouse B').last);
    await _tap(tester, find.widgetWithText(FilledButton, 'Transfer'));
    expect(c.read(partByIdProvider('BR-6205'))!.qty, 31);
    expect(c.read(inventoryProvider).historyFor('BR-6205').first.type, TxnType.transferred);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.drag(find.byWidgetPredicate((w) => w is ScrollView).first, const Offset(0, 800));
    await tester.pumpAndSettle();
    await _tap(tester, find.byTooltip('Stock actions'));
    await _tap(tester, find.text('Stock Count Adjustment'));
    await tester.enterText(find.byType(TextField).at(0), '29');
    await tester.enterText(find.byType(TextField).at(1), 'Two damaged');
    await _tap(tester, find.text('Adjust Stock'));
    expect(c.read(partByIdProvider('BR-6205'))!.qty, 29);

    await tester.pump(const Duration(seconds: 5));
    await _tap(tester, find.text('Create Purchase Order'));
    expect(find.text('SpareTech LLC'), findsOneWidget);
    final pos = c.read(inventoryProvider).purchaseOrders.length;
    await _tap(tester, find.textContaining('Create PO ·'));
    expect(c.read(inventoryProvider).purchaseOrders.length, pos + 1);
    final po = c.read(inventoryProvider).purchaseOrders.first;
    expect((po.status, po.qty, po.supplier), (RequestStatus.open, 60, 'SpareTech LLC'));
  });

  testWidgets('Stock Movement: GRN link, Reserved release; PO receive; Request Part', (tester) async {
    final c = await _open(tester, Routes.partStock('BR-6205'));
    expect(find.text('Balance: 36'), findsWidgets);
    await _tap(tester, find.text('REF: GRN-2026-0045'));
    expect(find.text('Goods Receipt GRN-2026-0045'), findsOneWidget);
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    await tester.drag(find.byWidgetPredicate((w) => w is ScrollView).first, const Offset(0, 1500));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Reserved'));
    expect(find.text('WO-2026-0045 · 2 Piece'), findsOneWidget);
    await _tap(tester, find.text('Release').first);
    await _tap(tester, find.widgetWithText(FilledButton, 'Release'));
    expect(c.read(partByIdProvider('BR-6205'))!.reserved, 4);

    c.read(routerProvider).go(Routes.purchaseOrder('PO-2026-0131'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final vb = c.read(partByIdProvider('VB-1120'))!.qty;
    await _tap(tester, find.text('Receive (GRN)'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Receive (GRN)'));
    expect(c.read(partByIdProvider('VB-1120'))!.qty, vb + 20);
    expect(find.textContaining('Goods Receipt GRN-2026-'), findsOneWidget);
    await tester.tapAt(const Offset(20, 100)); // close the receipt
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    c.read(routerProvider).go(Routes.requestPart(partId: 'SP-001'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Submit Request'));
    expect(find.text('Choose when it is needed'), findsOneWidget);
    await _tap(tester, find.text('Select date'));
    await tester.tap(find.text('30').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _tap(tester, find.byType(DropdownButtonFormField<String>).last);
    await _tap(tester, find.text('Emergency').last);
    await _tap(tester, find.text('Submit Request'));
    await _tap(tester, find.text('Done'));
    expect(find.text('My Requests'), findsOneWidget);
    expect(c.read(inventoryProvider).partRequests.first.status, RequestStatus.pending);
  });

  for (final (label, size) in [('small 360x640', const Size(1080, 1920)), ('large 430x932', const Size(1290, 2796))]) {
    testWidgets('$label phone: inventory screens lay out without overflow', (tester) async {
      final c = await _open(tester, Routes.inventory, size: size);
      for (final route in [
        Routes.inventory,
        Routes.partDetail('BR-6205'),
        for (final t in ['history', 'usage', 'reserved', 'pos']) Routes.partStock('BR-6205', tab: t),
        Routes.stockMovement,
        Routes.purchaseOrders,
        Routes.purchaseOrder('PO-2026-0131'),
        Routes.newPurchaseOrder(partId: 'BR-6205'),
        Routes.partRequests,
        Routes.requestPart(),
        Routes.stockReports,
      ]) {
        c.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }
}
