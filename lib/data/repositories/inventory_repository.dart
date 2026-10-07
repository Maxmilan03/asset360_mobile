import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/inventory_mock.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/data/models/inventory.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';

class InventoryState {
  const InventoryState({required this.parts, required this.txns, required this.requests, required this.untrackedItems});

  final List<Part> parts;

  /// All stock transactions, newest first.
  final List<StockTxn> txns;
  final List<PartRequest> requests;

  /// Items in the org total (124) that have no detailed record in the demo.
  final int untrackedItems;

  int get totalItems => untrackedItems + parts.length;
  List<Part> get lowStock => parts.where((p) => p.status == StockStatus.lowStock).toList();
  List<Part> get outOfStock => parts.where((p) => p.status == StockStatus.outOfStock).toList();
  List<Part> get reorder => parts.where((p) => p.needsReorder).toList();
  List<Part> get reserved => parts.where((p) => p.reserved > 0).toList();

  Part? part(String id) => parts.firstWhereOrNull((p) => p.id == id);
  List<StockTxn> historyFor(String partId) => txns.where((t) => t.partId == partId).toList();
  List<PartRequest> get purchaseOrders => requests.where((r) => r.isPo).toList();
  List<PartRequest> get partRequests => requests.where((r) => !r.isPo).toList();
  List<PartRequest> posFor(String partId) => purchaseOrders.where((r) => r.partId == partId).toList();
  PartRequest? request(String id) => requests.firstWhereOrNull((r) => r.id == id);

  /// Units issued per month for the last six months ([usageMonths]); this month adds issues made in the app.
  List<int> monthlyUsage(String partId) {
    final base = [...(seedMonthlyUsage[partId] ?? List.filled(usageMonths.length, 0))];
    final inApp = txns
        .where(
          (t) =>
              t.partId == partId &&
              t.qtyChange < 0 &&
              (t.type == TxnType.issued || t.type == TxnType.issuedToWo || t.type == TxnType.issuedToProduction) &&
              !t.at.isBefore(DemoClock.start),
        )
        .fold<int>(0, (s, t) => s - t.qtyChange);
    base[base.length - 1] += inApp;
    return base;
  }

  /// Average monthly usage over the six months.
  double averageUsage(String partId) {
    final u = monthlyUsage(partId);
    return u.isEmpty ? 0 : u.reduce((a, b) => a + b) / u.length;
  }

  /// Estimated date available stock reaches the reorder level (null when there is no usage, or already there).
  DateTime? reorderDate(String partId) {
    final p = part(partId);
    final perDay = averageUsage(partId) / 30;
    if (p == null || perDay <= 0) return null;
    if (p.available <= p.reorderLevel) return DemoClock.today;
    return DemoClock.today.add(Duration(days: ((p.available - p.reorderLevel) / perDay).floor()));
  }

  /// The Received entry of a goods receipt.
  StockTxn? grn(String ref) => txns.firstWhereOrNull((t) => t.ref == ref && t.type == TxnType.received);

  /// Search parts by number, name or category.
  List<Part> search(List<Part> list, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return list;
    return list.where((p) => '${p.id} ${p.name} ${p.category}'.toLowerCase().contains(s)).toList();
  }

  InventoryState copyWith({List<Part>? parts, List<StockTxn>? txns, List<PartRequest>? requests}) => InventoryState(
    parts: parts ?? this.parts,
    txns: txns ?? this.txns,
    requests: requests ?? this.requests,
    untrackedItems: untrackedItems,
  );
}

class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() {
    final parts = seedParts();
    return InventoryState(
      parts: parts,
      txns: seedStockTxns(),
      requests: seedPartRequests(),
      untrackedItems: inventoryTotalItems - parts.length,
    );
  }

  /// Every part change goes through here; crossing the reorder level posts "Stock Level Low".
  void _updatePart(String id, Part Function(Part) f) {
    final before = state.part(id);
    state = state.copyWith(parts: replaceWhere(state.parts, id, (p) => p.id, f));
    final after = state.part(id);
    if (before != null &&
        after != null &&
        before.available > before.reorderLevel &&
        after.available <= after.reorderLevel) {
      ref
          .read(notificationsProvider.notifier)
          .post(
            kind: 'stockLow',
            title: 'Stock Level Low',
            message: '${after.name} (${after.id}): ${after.available} available, reorder level ${after.reorderLevel}',
            refType: 'part',
            refId: after.id,
          );
    }
  }

  String _nextRef(String prefix) =>
      nextId(prefix, [...state.txns.map((t) => t.ref), ...state.requests.map((r) => r.grn ?? '')]);

  /// Records a stock movement: new balance = current qty + [change]; [reservedChange] moves the reserved qty.
  void _txn(
    String partId,
    String type,
    String ref,
    int change, {
    int reservedChange = 0,
    String? from,
    String? to,
    String? po,
    String? assetId,
    String? remarks,
  }) {
    final part = state.part(partId);
    if (part == null) return;
    final balance = (part.qty + change).clamp(0, 1 << 30);
    final now = DemoClock.now;
    _updatePart(
      partId,
      (p) => p.copyWith(qty: balance, reserved: (p.reserved + reservedChange).clamp(0, balance), lastUpdate: now),
    );
    state = state.copyWith(
      txns: [
        StockTxn(
          id: nextId('TXN-', state.txns.map((t) => t.id)),
          partId: partId,
          at: now,
          type: type,
          ref: ref,
          qtyChange: change,
          reservedChange: reservedChange,
          balanceAfter: balance,
          from: from,
          to: to,
          po: po,
          assetId: assetId,
          remarks: remarks,
        ),
        ...state.txns,
      ],
    );
  }

  /// Reserves stock for a work order: available goes down, stock on hand stays.
  void reserve(String partId, int qty, {String ref = 'Manual', String? assetId}) =>
      _txn(partId, TxnType.reserved, ref, 0, reservedChange: qty, assetId: assetId);

  /// Releases a reservation (part removed from a WO, or "Release" on the Reserved tab).
  void unreserve(String partId, int qty, {String ref = 'Manual', String? assetId}) {
    final part = state.part(partId);
    if (part == null || qty <= 0) return;
    _txn(partId, TxnType.released, ref, 0, reservedChange: -qty.clamp(0, part.reserved), assetId: assetId);
  }

  /// Issues stock: parts used when a WO is closed ([fromReserved]), or Issue to Work Order.
  void issue(
    String partId,
    int qty, {
    required String ref,
    String? assetId,
    String to = 'Maintenance Team',
    bool fromReserved = false,
    String type = TxnType.issued,
  }) {
    final part = state.part(partId);
    final release = fromReserved ? qty.clamp(0, part?.reserved ?? 0) : 0;
    _txn(partId, type, ref, -qty, reservedChange: -release, to: to, assetId: assetId);
  }

  void receive(String partId, int qty, {required String grn, required String from, String? po}) =>
      _txn(partId, TxnType.received, grn, qty, from: from, po: po);

  /// Offline: inventory changes also go into the sync queue (Other).
  void _q(String partId, String change) =>
      ref.queueOffline(SyncKind.other, partId, 'Inventory · $change', refId: partId);

  /// Moves [qty] out of this part's warehouse to [to]. Returns the transfer reference.
  String transfer(String partId, int qty, {required String to}) {
    final ref = _nextRef('TR-2026-');
    _txn(partId, TxnType.transferred, ref, -qty, from: state.part(partId)?.warehouse, to: to);
    _q(partId, 'Transfer $ref');
    return ref;
  }

  /// Stock count: sets on-hand to [newQty] with a reason.
  void adjust(String partId, int newQty, {required String reason}) {
    final part = state.part(partId);
    if (part == null || newQty == part.qty) return;
    _txn(partId, TxnType.adjusted, _nextRef('ADJ-2026-'), newQty - part.qty, remarks: reason);
    _q(partId, 'Stock adjusted');
  }

  void updateLevels(String partId, {int? reorderLevel, int? reorderQty}) {
    _updatePart(partId, (p) => p.copyWith(reorderLevel: reorderLevel, reorderQty: reorderQty));
    _q(partId, 'Stock levels edited');
  }

  void updateLocation(String partId, {String? warehouse, String? bin}) {
    _updatePart(partId, (p) => p.copyWith(warehouse: warehouse, bin: bin));
    _q(partId, 'Bin location edited');
  }

  /// Part request (Pending) or purchase order (Open). Returns its number.
  String createRequest(
    String partId,
    int qty, {
    required String kind,
    String? supplier,
    String? remarks,
    double? unitCost,
    DateTime? expectedAt,
    DateTime? neededBy,
    String? workOrderId,
  }) {
    final po = kind == 'Purchase Order';
    final id = nextId(po ? 'PO-2026-' : 'PR-2026-', state.requests.map((r) => r.id));
    state = state.copyWith(
      requests: [
        PartRequest(
          id: id,
          partId: partId,
          qty: qty,
          kind: kind,
          status: po ? RequestStatus.open : RequestStatus.pending,
          createdAt: DemoClock.now,
          supplier: supplier,
          remarks: remarks,
          unitCost: unitCost,
          expectedAt: expectedAt,
          neededBy: neededBy,
          workOrderId: workOrderId,
          requesterId: ref.read(currentUserProvider).id,
        ),
        ...state.requests,
      ],
    );
    _q(partId, '$kind $id');
    return id;
  }

  /// Receive (GRN) an open PO: stock goes up with a Received entry. Returns the GRN number.
  String receivePo(String poId) {
    final po = state.requests.firstWhere((r) => r.id == poId);
    final grn = _nextRef('GRN-2026-');
    receive(po.partId, po.qty, grn: grn, from: po.supplier ?? 'Supplier', po: po.id);
    state = state.copyWith(
      requests: [
        for (final r in state.requests)
          r.id == poId ? r.copyWith(status: RequestStatus.received, receivedAt: DemoClock.now, grn: grn) : r,
      ],
    );
    _q(po.partId, 'Received $grn');
    return grn;
  }

  void cancelRequest(String id) {
    state = state.copyWith(
      requests: [for (final r in state.requests) r.id == id ? r.copyWith(status: RequestStatus.cancelled) : r],
    );
    final partId = state.request(id)?.partId;
    if (partId != null) _q(partId, 'Request $id cancelled');
  }
}

final inventoryProvider = NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);

final partByIdProvider = Provider.family<Part?, String>((ref, id) => ref.watch(inventoryProvider).part(id));
