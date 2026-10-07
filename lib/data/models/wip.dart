import 'common.dart';

abstract final class OpStatus {
  static const completed = 'Completed';
  static const inProgress = 'In Progress';
  static const paused = 'Paused';
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
    required this.location,
    required this.status,
    required this.expectedMins,
    this.startedAt,
    this.completedAt,
    this.operatorId,
    this.actualMins,
    this.goodQty,
    this.scrapQty,
    this.qcPassed,
  });

  /// "AOI Inspection".
  final String name;

  /// Short label on the mini progress bar, e.g. "AOI".
  final String station;

  /// Machine / station where it runs, e.g. "AOI Line 1" (the unit's current station while it runs).
  final String location;
  final String status;

  /// Standard time.
  final int expectedMins;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? operatorId;

  /// Recorded duration (completed), or the duration already logged before the demo started (running).
  final int? actualMins;
  final int? goodQty;
  final int? scrapQty;

  /// Quality check at the end of the operation (null = not checked).
  final bool? qcPassed;

  bool get isDone => status == OpStatus.completed;
  bool get isRunning => status == OpStatus.inProgress || status == OpStatus.paused;

  Operation copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? operatorId,
    int? actualMins,
    int? goodQty,
    int? scrapQty,
    bool? qcPassed,
    int? expectedMins,
  }) => Operation(
    name: name,
    station: station,
    location: location,
    status: status ?? this.status,
    expectedMins: expectedMins ?? this.expectedMins,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    operatorId: operatorId ?? this.operatorId,
    actualMins: actualMins ?? this.actualMins,
    goodQty: goodQty ?? this.goodQty,
    scrapQty: scrapQty ?? this.scrapQty,
    qcPassed: qcPassed ?? this.qcPassed,
  );
}

/// Bill of materials line. [partId] links to Inventory (null = free-issue item).
class BomLine {
  const BomLine({required this.name, required this.required, this.issued = 0, this.partId});

  final String name;
  final String? partId;
  final int required;
  final int issued;

  int get outstanding => (required - issued).clamp(0, required);

  BomLine copyWith({int? issued}) =>
      BomLine(name: name, partId: partId, required: required, issued: issued ?? this.issued);
}

/// A scan of the unit at a station (Location History).
class UnitScan {
  const UnitScan({required this.at, required this.location, required this.by, required this.device});

  final DateTime at;
  final String location;
  final String by;
  final String device;
}

/// A quality check result (Quality tab). A failed one is a finding on the order.
class QualityCheck {
  const QualityCheck({required this.at, required this.operation, required this.passed, this.note, this.by});

  final DateTime at;
  final String operation;
  final bool passed;
  final String? note;
  final String? by;
}

/// Production order (MO-…). Never shares numbers with maintenance WOs.
class ProductionOrder {
  const ProductionOrder({
    required this.id,
    required this.product,
    required this.unitSerial,
    required this.status,
    required this.operations,
    required this.plannedQty,
    required this.completedQty,
    required this.dueDate,
    this.batch,
    this.customer = 'Internal Production',
    this.site = 'Factory 1',
    this.area = 'Production Floor',
    this.scans = const [],
    this.photos = const [],
    this.imagePath,
    this.components = const [],
    this.notes = const [],
    this.history = const [],
    this.quality = const [],
    this.documents = const [],
    this.holdReason,
  });

  final String id;
  final String product;
  final String unitSerial;
  final String status;
  final List<Operation> operations;
  final int plannedQty;
  final int completedQty;
  final DateTime dueDate;
  final String? batch;
  final String customer;
  final String site;
  final String area;

  /// Newest first.
  final List<UnitScan> scans;
  final List<String> photos;
  final String? imagePath;
  final List<BomLine> components;
  final List<LogEntry> notes;
  final List<LogEntry> history;
  final List<QualityCheck> quality;
  final List<Attachment> documents;
  final String? holdReason;

  double get progress => plannedQty == 0 ? 0 : completedQty / plannedQty;
  bool get allOpsDone => operations.every((o) => o.isDone);
  bool get isActive => status != MoStatus.completed;

  /// The running (or failed) operation, else -1.
  int get currentOpIndex => operations.indexWhere((o) => o.isRunning || o.status == OpStatus.failed);

  /// The next operation that may be started: the first not completed, when nothing is running.
  int get nextStartIndex {
    if (currentOpIndex >= 0 && operations[currentOpIndex].isRunning) return -1;
    return operations.indexWhere((o) => !o.isDone);
  }

  /// Where the unit is: the running / failed operation's station, else the next one's, else Dispatch.
  String get currentStation {
    final i = currentOpIndex >= 0 ? currentOpIndex : operations.indexWhere((o) => !o.isDone);
    return i < 0 ? 'Dispatch' : operations[i].location;
  }

  String get locationPath => '$site > $area > $currentStation';

  UnitScan? get lastScan => scans.isEmpty ? null : scans.first;

  /// First-pass yield: good / (good + scrap) over operations that recorded quantities.
  double? get firstPassYield {
    final good = operations.fold<int>(0, (s, o) => s + (o.goodQty ?? 0));
    final scrap = operations.fold<int>(0, (s, o) => s + (o.scrapQty ?? 0));
    return good + scrap == 0 ? null : good / (good + scrap);
  }

  ProductionOrder copyWith({
    String? status,
    List<Operation>? operations,
    int? completedQty,
    List<UnitScan>? scans,
    List<String>? photos,
    List<BomLine>? components,
    List<LogEntry>? notes,
    List<LogEntry>? history,
    List<QualityCheck>? quality,
    String? holdReason,
    bool clearHold = false,
  }) {
    return ProductionOrder(
      id: id,
      product: product,
      unitSerial: unitSerial,
      status: status ?? this.status,
      operations: operations ?? this.operations,
      plannedQty: plannedQty,
      completedQty: completedQty ?? this.completedQty,
      dueDate: dueDate,
      batch: batch,
      customer: customer,
      site: site,
      area: area,
      scans: scans ?? this.scans,
      photos: photos ?? this.photos,
      imagePath: imagePath,
      components: components ?? this.components,
      notes: notes ?? this.notes,
      history: history ?? this.history,
      quality: quality ?? this.quality,
      documents: documents,
      holdReason: clearHold ? null : holdReason ?? this.holdReason,
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
