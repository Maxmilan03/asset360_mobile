import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/wip_mock.dart';
import '../models/common.dart';
import '../models/wip.dart';
import 'repo_utils.dart';
import 'session_repository.dart';

class WipState {
  const WipState({required this.summary, required this.orders});

  final WipSummary summary;
  final List<ProductionOrder> orders;

  ProductionOrder? order(String id) => orders.firstWhereOrNull((o) => o.id == id);
  ProductionOrder? byUnit(String serial) => orders.firstWhereOrNull((o) => o.unitSerial == serial);

  WipState copyWith({WipSummary? summary, List<ProductionOrder>? orders}) =>
      WipState(summary: summary ?? this.summary, orders: orders ?? this.orders);
}

class WipNotifier extends Notifier<WipState> {
  @override
  WipState build() => WipState(summary: seedWipSummary(), orders: seedProductionOrders());

  String get _me => ref.read(currentUserProvider).name;
  LogEntry _log(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  void _update(String id, ProductionOrder Function(ProductionOrder) f) =>
      state = state.copyWith(orders: replaceWhere(state.orders, id, (o) => o.id, f));

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
    _update(id, (x) => x.copyWith(status: status, history: [...x.history, _log(logTitle, note)]));
  }

  void startOperation(String id, int index) => _update(id, (o) {
    final ops = [
      for (var i = 0; i < o.operations.length; i++)
        i == index
            ? o.operations[i].copyWith(
                status: OpStatus.inProgress,
                startedAt: DemoClock.now,
                operatorId: ref.read(currentUserProvider).id,
                actualMins: 0,
              )
            : o.operations[i],
    ];
    return o.copyWith(
      operations: ops,
      currentStation: o.operations[index].name,
      history: [...o.history, _log('Started ${o.operations[index].name}')],
    );
  });

  /// Completes the current operation and starts the next one ("Move to Next Operation").
  void completeOperation(String id, int index) {
    final o = state.order(id);
    if (o == null) return;
    final now = DemoClock.now;
    final ops = [
      for (var i = 0; i < o.operations.length; i++)
        if (i == index)
          o.operations[i].copyWith(
            status: OpStatus.completed,
            completedAt: now,
            actualMins: o.operations[i].startedAt == null
                ? o.operations[i].expectedMins
                : now.difference(o.operations[i].startedAt!).inMinutes.clamp(1, 600),
          )
        else if (i == index + 1 && o.operations[i].status == OpStatus.pending)
          o.operations[i].copyWith(
            status: OpStatus.inProgress,
            startedAt: now,
            operatorId: ref.read(currentUserProvider).id,
            actualMins: 0,
          )
        else
          o.operations[i],
    ];
    final last = index == o.operations.length - 1;
    _update(
      id,
      (x) => x.copyWith(
        operations: ops,
        currentStation: last ? 'Dispatch' : ops[index + 1].name,
        lastScanned: now,
        scannedBy: _me,
        history: [...x.history, _log('Completed ${o.operations[index].name}')],
      ),
    );
    if (last) completeOrder(id);
  }

  void failOperation(String id, int index, String reason) {
    _update(
      id,
      (o) => o.copyWith(
        operations: [
          for (var i = 0; i < o.operations.length; i++)
            i == index ? o.operations[i].copyWith(status: OpStatus.failed) : o.operations[i],
        ],
      ),
    );
    _setStatus(id, MoStatus.delayed, 'Operation failed', note: reason);
  }

  void pause(String id, String reason) => _setStatus(id, MoStatus.onHold, 'Order paused', note: reason);
  void resume(String id) => _setStatus(id, MoStatus.inProcess, 'Order resumed');

  void completeOrder(String id) {
    final o = state.order(id);
    if (o == null) return;
    _update(id, (x) => x.copyWith(completedQty: x.plannedQty));
    _setStatus(id, MoStatus.completed, 'Production order completed');
  }

  void addPhoto(String id, String path) => _update(id, (o) => o.copyWith(photos: [...o.photos, path]));
  void addNote(String id, String note) => _update(id, (o) => o.copyWith(notes: [...o.notes, note]));
  void recordScan(String id) => _update(id, (o) => o.copyWith(lastScanned: DemoClock.now, scannedBy: _me));
}

final wipProvider = NotifierProvider<WipNotifier, WipState>(WipNotifier.new);
