abstract final class StockStatus {
  static const inStock = 'In Stock';
  static const lowStock = 'Low Stock';
  static const outOfStock = 'Out of Stock';
}

class Part {
  const Part({
    required this.id,
    required this.name,
    required this.category,
    required this.qty,
    required this.reorderLevel,
    required this.reorderQty,
    required this.warehouse,
    required this.unitCost,
    this.manufacturer = '—',
    this.description = '',
    this.unit = 'Piece',
    this.bin = '—',
    this.reserved = 0,
    this.lastUpdate,
    this.leadTimeDays = 7,
    this.currency = 'USD',
    this.supplier = '—',
    this.warrantyMonths = 0,
    this.remarks = '',
    this.imagePath,
  });

  /// Part number, e.g. BR-6205.
  final String id;
  final String name;
  final String category;
  final String manufacturer;
  final String description;
  final String unit;
  final int qty;
  final int reorderLevel;
  final int reorderQty;
  final String warehouse;
  final String bin;
  final int reserved;
  final DateTime? lastUpdate;
  final int leadTimeDays;
  final double unitCost;
  final String currency;
  final String supplier;
  final int warrantyMonths;
  final String remarks;
  final String? imagePath;

  int get available => (qty - reserved).clamp(0, qty);

  String get status {
    if (qty <= 0) return StockStatus.outOfStock;
    if (qty <= reorderLevel) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  /// Needs reordering: low stock or out of stock.
  bool get needsReorder => qty <= reorderLevel;

  Part copyWith({
    int? qty,
    int? reserved,
    int? reorderLevel,
    int? reorderQty,
    String? warehouse,
    String? bin,
    DateTime? lastUpdate,
  }) => Part(
    id: id,
    name: name,
    category: category,
    manufacturer: manufacturer,
    description: description,
    unit: unit,
    qty: qty ?? this.qty,
    reorderLevel: reorderLevel ?? this.reorderLevel,
    reorderQty: reorderQty ?? this.reorderQty,
    warehouse: warehouse ?? this.warehouse,
    bin: bin ?? this.bin,
    reserved: reserved ?? this.reserved,
    lastUpdate: lastUpdate ?? this.lastUpdate,
    leadTimeDays: leadTimeDays,
    unitCost: unitCost,
    currency: currency,
    supplier: supplier,
    warrantyMonths: warrantyMonths,
    remarks: remarks,
    imagePath: imagePath,
  );
}

abstract final class TxnType {
  static const received = 'Received (GRN)';
  static const issued = 'Issued for Maintenance';
  static const transferred = 'Transferred';
  static const reserved = 'Reserved for Work Order';
  static const returned = 'Returned';
  static const adjusted = 'Stock Count Adjustment';
  static const released = 'Reservation Released';
  static const issuedToWo = 'Issued to Work Order';
  static const issuedToProduction = 'Issued to Production';

  static const all = [received, issued, issuedToWo, issuedToProduction, transferred, reserved, released, adjusted];
}

/// One stock transaction. [balanceAfter] (stock on hand) must equal the previous balance + [qtyChange].
/// Reservations do not move stock: they carry [reservedChange] and leave the balance unchanged.
class StockTxn {
  const StockTxn({
    required this.id,
    required this.partId,
    required this.at,
    required this.type,
    required this.ref,
    required this.qtyChange,
    required this.balanceAfter,
    this.from,
    this.to,
    this.po,
    this.assetId,
    this.remarks,
    this.reservedChange = 0,
  });

  final String id;
  final String partId;
  final DateTime at;
  final String type;
  final String ref;
  final int qtyChange;

  /// + reserved / − released (balance unchanged).
  final int reservedChange;
  final int balanceAfter;
  final String? from;
  final String? to;
  final String? po;
  final String? assetId;
  final String? remarks;
}

abstract final class RequestStatus {
  static const pending = 'Pending';
  static const approved = 'Approved';
  static const open = 'Open';
  static const received = 'Received';
  static const cancelled = 'Cancelled';
}

/// Purchase order (one line) or part request raised from Inventory.
class PartRequest {
  const PartRequest({
    required this.id,
    required this.partId,
    required this.qty,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.supplier,
    this.remarks,
    this.unitCost,
    this.expectedAt,
    this.neededBy,
    this.workOrderId,
    this.requesterId,
    this.receivedAt,
    this.grn,
  });

  final String id;
  final String partId;
  final int qty;

  /// Request or Purchase Order.
  final String kind;
  final String status;
  final DateTime createdAt;
  final String? supplier;

  /// Request: reason. PO: notes.
  final String? remarks;
  final double? unitCost;

  /// PO: expected delivery date. Request: [neededBy].
  final DateTime? expectedAt;
  final DateTime? neededBy;
  final String? workOrderId;
  final String? requesterId;
  final DateTime? receivedAt;

  /// Goods receipt number once received.
  final String? grn;

  bool get isPo => kind == 'Purchase Order';
  bool get isOpen => status == RequestStatus.open;
  double get total => (unitCost ?? 0) * qty;

  PartRequest copyWith({String? status, DateTime? receivedAt, String? grn}) => PartRequest(
    id: id,
    partId: partId,
    qty: qty,
    kind: kind,
    status: status ?? this.status,
    createdAt: createdAt,
    supplier: supplier,
    remarks: remarks,
    unitCost: unitCost,
    expectedAt: expectedAt,
    neededBy: neededBy,
    workOrderId: workOrderId,
    requesterId: requesterId,
    receivedAt: receivedAt ?? this.receivedAt,
    grn: grn ?? this.grn,
  );
}

const partRequestReasons = ['Work order', 'Preventive maintenance', 'Stock replenishment', 'Emergency', 'Other'];
