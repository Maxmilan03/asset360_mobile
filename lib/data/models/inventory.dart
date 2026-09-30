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
  static const adjusted = 'Adjusted';
}

/// One stock transaction. [balanceAfter] must equal the previous balance + [qtyChange].
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
  });

  final String id;
  final String partId;
  final DateTime at;
  final String type;
  final String ref;
  final int qtyChange;
  final int balanceAfter;
  final String? from;
  final String? to;
  final String? po;
  final String? assetId;
  final String? remarks;
}

/// Purchase order / part request raised from Inventory.
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
  });

  final String id;
  final String partId;
  final int qty;

  /// Request or Purchase Order.
  final String kind;
  final String status;
  final DateTime createdAt;
  final String? supplier;
  final String? remarks;

  PartRequest copyWith({String? status}) => PartRequest(
    id: id,
    partId: partId,
    qty: qty,
    kind: kind,
    status: status ?? this.status,
    createdAt: createdAt,
    supplier: supplier,
    remarks: remarks,
  );
}
