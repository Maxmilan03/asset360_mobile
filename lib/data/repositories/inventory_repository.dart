import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/inventory_mock.dart';
import '../models/inventory.dart';
import 'repo_utils.dart';

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

  void _updatePart(String id, Part Function(Part) f) =>
      state = state.copyWith(parts: replaceWhere(state.parts, id, (p) => p.id, f));

  /// Records a stock change: new balance = current qty + [change].
  void _txn(
    String partId,
    String type,
    String ref,
    int change, {
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
    _updatePart(partId, (p) => p.copyWith(qty: balance, lastUpdate: now));
    state = state.copyWith(
      txns: [
        StockTxn(
          id: nextId('TXN-', state.txns.map((t) => t.id)),
          partId: partId,
          at: now,
          type: type,
          ref: ref,
          qtyChange: change,
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

  /// Reserves stock for a work order (available goes down, stock stays).
  void reserve(String partId, int qty) => _updatePart(partId, (p) => p.copyWith(reserved: p.reserved + qty));

  void unreserve(String partId, int qty) =>
      _updatePart(partId, (p) => p.copyWith(reserved: (p.reserved - qty).clamp(0, p.qty)));

  /// Issues stock (Inventory Issue, or parts used when a WO is closed).
  void issue(
    String partId,
    int qty, {
    required String ref,
    String? assetId,
    String to = 'Maintenance Team',
    bool fromReserved = false,
  }) {
    if (fromReserved) unreserve(partId, qty);
    _txn(partId, TxnType.issued, ref, -qty, to: to, assetId: assetId);
  }

  void receive(String partId, int qty, {required String grn, required String from, String? po}) =>
      _txn(partId, TxnType.received, grn, qty, from: from, po: po);

  void transfer(String partId, int qty, {required String to}) {
    final ref = nextId('TR-2026-', state.txns.map((t) => t.ref));
    _txn(partId, TxnType.transferred, ref, -qty, from: state.part(partId)?.warehouse, to: to);
  }

  void adjust(String partId, int newQty, {required String reason}) {
    final part = state.part(partId);
    if (part == null || newQty == part.qty) return;
    _txn(
      partId,
      TxnType.adjusted,
      'ADJ-${DemoClock.now.millisecondsSinceEpoch % 10000}',
      newQty - part.qty,
      remarks: reason,
    );
  }

  void updateLevels(String partId, {int? reorderLevel, int? reorderQty}) =>
      _updatePart(partId, (p) => p.copyWith(reorderLevel: reorderLevel, reorderQty: reorderQty));

  void updateLocation(String partId, {String? warehouse, String? bin}) =>
      _updatePart(partId, (p) => p.copyWith(warehouse: warehouse, bin: bin));

  /// Part request or purchase order. Returns its number.
  String createRequest(String partId, int qty, {required String kind, String? supplier, String? remarks}) {
    final prefix = kind == 'Purchase Order' ? 'PO-2026-' : 'PR-2026-';
    final id = nextId(prefix, state.requests.map((r) => r.id));
    state = state.copyWith(
      requests: [
        PartRequest(
          id: id,
          partId: partId,
          qty: qty,
          kind: kind,
          status: kind == 'Purchase Order' ? 'Ordered' : 'Pending',
          createdAt: DemoClock.now,
          supplier: supplier,
          remarks: remarks,
        ),
        ...state.requests,
      ],
    );
    return id;
  }
}

final inventoryProvider = NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);

final partByIdProvider = Provider.family<Part?, String>((ref, id) => ref.watch(inventoryProvider).part(id));
