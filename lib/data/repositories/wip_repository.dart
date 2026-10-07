import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/wip_mock.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/models/inventory.dart';
import 'package:asset360_mobile/data/models/wip.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';

class WipState {
  const WipState({required this.summary, required this.orders});

  final WipSummary summary;
  final List<ProductionOrder> orders;

  ProductionOrder? order(String id) => orders.firstWhereOrNull((o) => o.id == id);
  ProductionOrder? byUnit(String serial) =>
      orders.firstWhereOrNull((o) => o.unitSerial.toUpperCase() == serial.trim().toUpperCase());

  List<ProductionOrder> get active => orders.where((o) => o.isActive).toList();
  List<ProductionOrder> withStatus(String s) => orders.where((o) => o.status == s).toList();

  /// Orders with an operation running (End Operation).
  List<ProductionOrder> get running =>
      active.where((o) => o.currentOpIndex >= 0 && o.operations[o.currentOpIndex].isRunning).toList();

  /// Orders whose next operation can be started (Start Operation).
  List<ProductionOrder> get startable =>
      active.where((o) => o.status != MoStatus.onHold && o.nextStartIndex >= 0).toList();

  WipState copyWith({WipSummary? summary, List<ProductionOrder>? orders}) =>
      WipState(summary: summary ?? this.summary, orders: orders ?? this.orders);
}

/// Live duration of a running operation: minutes since it started in the app, or (for operations
/// started before the demo) the logged minutes plus the time the app has been open, capped at 2× standard.
int liveMinutes(Operation o) {
  if (o.status == OpStatus.completed) return o.actualMins ?? o.expectedMins;
  final started = o.startedAt;
  if (started == null) return 0;
  final cap = o.expectedMins * 2;
  if (started.isBefore(DemoClock.start)) {
    return ((o.actualMins ?? 0) + DemoClock.now.difference(DemoClock.start).inMinutes).clamp(0, cap);
  }
  return DemoClock.now.difference(started).inMinutes.clamp(0, cap);
}

class WipNotifier extends Notifier<WipState> {
  @override
  WipState build() => WipState(summary: seedWipSummary(), orders: seedProductionOrders());

  String get _me => ref.read(currentUserProvider).name;
  String get _meId => ref.read(currentUserProvider).id;
  LogEntry _log(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  void _update(String id, ProductionOrder Function(ProductionOrder) f) {
    state = state.copyWith(orders: replaceWhere(state.orders, id, (o) => o.id, f));
    // Offline: the production change also goes into the sync queue.
    final o = state.order(id);
    if (o != null) ref.queueOffline(SyncKind.other, id, 'Production · ${o.currentStation}', refId: id);
  }

  /// Keeps the plant summary in step with a sample order's status change.
  void _shift(String from, String to) {
    var s = state.summary;
    int d(String status, int v) => (from == status ? -1 : 0) + (to == status ? 1 : 0) + v;
    s = s.copyWith(
      inProcess: d(MoStatus.inProcess, s.inProcess),
      delayed: d(MoStatus.delayed, s.delayed),
      onHold: d(MoStatus.onHold, s.onHold),
      completedToday: to == MoStatus.completed ? s.completedToday + 1 : s.completedToday,
    );
    state = state.copyWith(summary: s);
  }

  void _setStatus(String id, String status, String logTitle, {String? note}) {
    final o = state.order(id);
    if (o == null || o.status == status) return;
    _shift(o.status, status);
    _update(
      id,
      (x) => x.copyWith(
        status: status,
        holdReason: status == MoStatus.onHold ? note : null,
        clearHold: status != MoStatus.onHold,
        history: [...x.history, _log(logTitle, note)],
      ),
    );
  }

  UnitScan _scan(String location, {String device = 'Mobile (Asset360)'}) =>
      UnitScan(at: DemoClock.now, location: location, by: _me, device: device);

  List<Operation> _withOp(ProductionOrder o, int index, Operation Function(Operation) f) => [
    for (var i = 0; i < o.operations.length; i++) i == index ? f(o.operations[i]) : o.operations[i],
  ];

  /// Starts the next operation in sequence; the unit is scanned in at its station.
  bool startOperation(String id, int index) {
    final o = state.order(id);
    if (o == null || index != o.nextStartIndex) return false;
    final op = o.operations[index];
    _update(
      id,
      (x) => x.copyWith(
        operations: _withOp(
          x,
          index,
          (p) => p.copyWith(status: OpStatus.inProgress, startedAt: DemoClock.now, operatorId: _meId, actualMins: 0),
        ),
        scans: [_scan(op.location), ...x.scans],
        history: [...x.history, _log('Started ${op.name}', op.location)],
      ),
    );
    return true;
  }

  void pauseOperation(String id, int index) => _update(
    id,
    (o) => o.copyWith(
      operations: _withOp(o, index, (p) => p.copyWith(status: OpStatus.paused, actualMins: liveMinutes(p))),
      history: [...o.history, _log('Paused ${o.operations[index].name}')],
    ),
  );

  void resumeOperation(String id, int index) => _update(
    id,
    (o) => o.copyWith(
      operations: _withOp(o, index, (p) => p.copyWith(status: OpStatus.inProgress)),
      history: [...o.history, _log('Resumed ${o.operations[index].name}')],
    ),
  );

  /// Ends a running operation with good / scrap quantities and the quality result. A failed check marks
  /// the step red, records a quality finding and makes the order Delayed. The last operation adds the
  /// good units to the completed quantity.
  void endOperation(String id, int index, {int? good, int? scrap, bool qcPassed = true, String? note}) {
    final o = state.order(id);
    if (o == null) return;
    final op = o.operations[index];
    final now = DemoClock.now;
    final last = index == o.operations.length - 1;
    _update(
      id,
      (x) => x.copyWith(
        operations: _withOp(
          x,
          index,
          (p) => p.copyWith(
            status: qcPassed ? OpStatus.completed : OpStatus.failed,
            completedAt: qcPassed ? now : null,
            actualMins: liveMinutes(p).clamp(1, 600),
            goodQty: good,
            scrapQty: scrap,
            qcPassed: qcPassed,
          ),
        ),
        quality: [
          ...x.quality,
          QualityCheck(at: now, operation: op.name, passed: qcPassed, note: note, by: _me),
        ],
        completedQty: qcPassed && last ? (x.completedQty + (good ?? 1)).clamp(0, x.plannedQty) : null,
        history: [...x.history, _log(qcPassed ? 'Completed ${op.name}' : 'Quality check failed at ${op.name}', note)],
      ),
    );
    if (!qcPassed) _setStatus(id, MoStatus.delayed, 'Order delayed', note: note);
  }

  /// "Move to Next Operation": ends the current operation and, if it passed, starts the next one.
  void moveToNext(String id, {bool qcPassed = true, String? note}) {
    final o = state.order(id);
    if (o == null || o.currentOpIndex < 0) return;
    final i = o.currentOpIndex;
    endOperation(id, i, qcPassed: qcPassed, note: note);
    if (qcPassed && i + 1 < o.operations.length) startOperation(id, i + 1);
  }

  /// Rework after a failed check: the step runs again and the order is back In Process.
  void rework(String id, int index) {
    _update(
      id,
      (o) => o.copyWith(
        operations: _withOp(
          o,
          index,
          (p) => p.copyWith(status: OpStatus.inProgress, startedAt: DemoClock.now, operatorId: _meId, actualMins: 0),
        ),
      ),
    );
    _setStatus(id, MoStatus.inProcess, 'Rework started', note: state.order(id)?.operations[index].name);
  }

  void pause(String id, String reason) => _setStatus(id, MoStatus.onHold, 'Order paused', note: reason);
  void resume(String id) => _setStatus(id, MoStatus.inProcess, 'Order resumed');

  /// Complete Work Order: only when every operation is done.
  bool completeOrder(String id) {
    final o = state.order(id);
    if (o == null || !o.allOpsDone) return false;
    _update(
      id,
      (x) => x.copyWith(
        completedQty: x.plannedQty,
        scans: [
          _scan('Dispatch', device: 'Station-DSP-01'),
          ...x.scans,
        ],
      ),
    );
    _setStatus(id, MoStatus.completed, 'Production order completed');
    return true;
  }

  /// A station tag scanned for the unit (location scan / Scan to Move).
  void recordScan(String id, String location, {String device = 'Mobile (Asset360)'}) => _update(
    id,
    (o) => o.copyWith(
      scans: [
        _scan(location, device: device),
        ...o.scans,
      ],
    ),
  );

  void setOperator(String id, int index, String personId) => _update(
    id,
    (o) => o.copyWith(
      operations: _withOp(o, index, (p) => p.copyWith(operatorId: personId)),
      history: [...o.history, _log('Operator changed for ${o.operations[index].name}')],
    ),
  );

  void setExpected(String id, int index, int mins) =>
      _update(id, (o) => o.copyWith(operations: _withOp(o, index, (p) => p.copyWith(expectedMins: mins))));

  /// Issues the outstanding quantity of a BOM line from Inventory (up to what is available). Returns the qty.
  int issueComponent(String id, int line) {
    final o = state.order(id);
    if (o == null) return 0;
    final bom = o.components[line];
    final inventory = ref.read(inventoryProvider.notifier);
    var qty = bom.outstanding;
    if (bom.partId != null) {
      final part = ref.read(inventoryProvider).part(bom.partId!);
      qty = qty.clamp(0, part?.available ?? 0);
      if (qty == 0) return 0;
      inventory.issue(
        bom.partId!,
        qty,
        ref: id,
        to: 'Production – ${o.currentStation}',
        type: TxnType.issuedToProduction,
      );
    }
    _update(
      id,
      (x) => x.copyWith(
        components: [for (final (i, c) in x.components.indexed) i == line ? c.copyWith(issued: c.issued + qty) : c],
        history: [...x.history, _log('Issued ${bom.name} × $qty')],
      ),
    );
    return qty;
  }

  void addPhoto(String id, String path) => _update(id, (o) => o.copyWith(photos: [...o.photos, path]));
  void addNote(String id, String note) => _update(
    id,
    (o) => o.copyWith(
      notes: [
        ...o.notes,
        LogEntry(at: DemoClock.now, title: note, by: _me),
      ],
    ),
  );
}

final wipProvider = NotifierProvider<WipNotifier, WipState>(WipNotifier.new);

/// "STATION:AOI Line 1" or the bare station name → the station.
String stationFromTag(String code) =>
    code.trim().replaceFirst(RegExp(stationTagPrefix, caseSensitive: false), '').trim();
