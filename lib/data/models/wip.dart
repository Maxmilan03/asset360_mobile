import 'common.dart';

abstract final class OpStatus {
  static const completed = 'Completed';
  static const inProgress = 'In Progress';
  static const pending = 'Pending';
  static const failed = 'Failed';
}

abstract final class MoStatus {
  static const inProcess = 'In Process';
  static const delayed = 'Delayed';
  static const onHold = 'On Hold';
  static const completed = 'Completed';
  static const queued = 'Queued';
}

class Operation {
  const Operation({
    required this.name,
    required this.station,
    required this.status,
    required this.expectedMins,
    this.startedAt,
    this.completedAt,
    this.operatorId,
    this.actualMins,
  });

  /// "AOI Inspection".
  final String name;

  /// Short label on the mini progress bar, e.g. "AOI".
  final String station;
  final String status;
  final int expectedMins;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? operatorId;
  final int? actualMins;

  Operation copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? operatorId,
    int? actualMins,
  }) => Operation(
    name: name,
    station: station,
    status: status ?? this.status,
    expectedMins: expectedMins,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    operatorId: operatorId ?? this.operatorId,
    actualMins: actualMins ?? this.actualMins,
  );
}

/// Production order (MO-…). Never shares numbers with maintenance WOs.
class ProductionOrder {
  const ProductionOrder({
    required this.id,
    required this.product,
    required this.unitSerial,
    required this.status,
    required this.currentStation,
    required this.operations,
    required this.plannedQty,
    required this.completedQty,
    required this.dueDate,
    this.batch,
    this.customer = 'Internal Production',
    this.locationPath,
    this.lastScanned,
    this.scannedBy,
    this.scanDevice,
    this.photos = const [],
    this.imagePath,
    this.components = const [],
    this.notes = const [],
    this.history = const [],
  });

  final String id;
  final String product;
  final String unitSerial;
  final String status;
  final String currentStation;
  final List<Operation> operations;
  final int plannedQty;
  final int completedQty;
  final DateTime dueDate;
  final String? batch;
  final String customer;

  /// "Factory 1 > Production Floor > AOI Line 1".
  final String? locationPath;
  final DateTime? lastScanned;
  final String? scannedBy;
  final String? scanDevice;
  final List<String> photos;
  final String? imagePath;
  final List<String> components;
  final List<String> notes;
  final List<LogEntry> history;

  double get progress => plannedQty == 0 ? 0 : completedQty / plannedQty;
  int get currentOpIndex =>
      operations.indexWhere((o) => o.status == OpStatus.inProgress || o.status == OpStatus.failed);

  ProductionOrder copyWith({
    String? status,
    String? currentStation,
    List<Operation>? operations,
    int? completedQty,
    DateTime? lastScanned,
    String? scannedBy,
    List<String>? photos,
    List<String>? notes,
    List<LogEntry>? history,
  }) {
    return ProductionOrder(
      id: id,
      product: product,
      unitSerial: unitSerial,
      status: status ?? this.status,
      currentStation: currentStation ?? this.currentStation,
      operations: operations ?? this.operations,
      plannedQty: plannedQty,
      completedQty: completedQty ?? this.completedQty,
      dueDate: dueDate,
      batch: batch,
      customer: customer,
      locationPath: locationPath,
      lastScanned: lastScanned ?? this.lastScanned,
      scannedBy: scannedBy ?? this.scannedBy,
      scanDevice: scanDevice,
      photos: photos ?? this.photos,
      imagePath: imagePath,
      components: components,
      notes: notes ?? this.notes,
      history: history ?? this.history,
    );
  }
}

/// Plant-wide WIP figures (summary).
class WipSummary {
  const WipSummary({
    required this.inProcess,
    required this.completedToday,
    required this.delayed,
    required this.onHold,
    required this.queued,
  });

  final int inProcess;
  final int completedToday;
  final int delayed;
  final int onHold;
  final int queued;

  /// All WIP = In Process + Delayed + On Hold + Queued.
  int get allWip => inProcess + delayed + onHold + queued;

  WipSummary copyWith({int? inProcess, int? completedToday, int? delayed, int? onHold}) => WipSummary(
    inProcess: inProcess ?? this.inProcess,
    completedToday: completedToday ?? this.completedToday,
    delayed: delayed ?? this.delayed,
    onHold: onHold ?? this.onHold,
    queued: queued,
  );
}
