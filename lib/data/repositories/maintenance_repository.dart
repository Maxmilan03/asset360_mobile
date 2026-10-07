import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/checklist/checklist.dart';
import '../../core/demo_clock.dart';
import '../mock/maintenance_mock.dart';
import '../models/asset.dart';
import '../models/common.dart';
import '../models/inventory.dart';
import '../models/work_order.dart';
import 'assets_repository.dart';
import 'audits_repository.dart';
import 'inspections_repository.dart';
import 'inventory_repository.dart';
import 'repo_utils.dart';
import 'session_repository.dart';
import 'sync_repository.dart';
import '../models/sync_item.dart';

class WorkOrdersNotifier extends Notifier<List<WorkOrder>> {
  @override
  List<WorkOrder> build() => seedWorkOrders();

  String get _me => ref.read(currentUserProvider).name;
  LogEntry _log(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  WorkOrder? byId(String id) => state.firstWhereOrNull((w) => w.id == id);
  void _update(String id, WorkOrder Function(WorkOrder) f) => state = replaceWhere(state, id, (w) => w.id, f);

  String get nextWoId => nextId('WO-2026-', state.map((w) => w.id));

  /// Offline: queue the change and flag the WO "saved offline" until it syncs.
  void _queue(String id, String change) {
    final w = byId(id);
    if (w == null) return;
    if (ref.queueOffline(SyncKind.workOrder, id, '${w.workType} · $change', refId: id) && !w.savedOffline) {
      _update(id, (w) => w.copyWith(savedOffline: true));
    }
  }

  void _queuePhoto(String id, String path) =>
      ref.queueOffline(SyncKind.photo, syncFileName(path), 'Work Order Attachment', refId: id);

  /// Creates a WO (Create Work Order form, "Generate WO now", issue → WO). Returns its ID.
  String create({
    required String assetId,
    required String title,
    required String priority,
    required String category,
    required String workType,
    required DateTime dueAt,
    String description = '',
    String? assigneeId,
    String? issueId,
  }) {
    final id = nextWoId;
    final assignee = ref.read(personByIdProvider(assigneeId));
    final wo = WorkOrder(
      id: id,
      assetId: assetId,
      title: title,
      description: description,
      priority: priority,
      status: assigneeId == null ? WoStatus.open : WoStatus.assigned,
      category: category,
      workType: workType,
      sla: priority == 'Critical' ? '4 Hours (Response)' : '24 Hours',
      openedAt: DemoClock.now,
      dueAt: dueAt,
      assigneeId: assigneeId,
      reporterId: ref.read(currentUserProvider).id,
      coordinatorId: ref.read(currentUserProvider).id,
      issueId: issueId,
      tasks: [
        WoTask(
          id: '$id-T1',
          title: 'Arrival & Safety Check',
          checklist: [
            CheckItem(code: '$id-T1-1', label: 'PPE worn', type: CheckType.tick),
            CheckItem(code: '$id-T1-2', label: 'Area isolated (LOTO)', type: CheckType.tick),
          ],
        ),
        WoTask(
          id: '$id-T2',
          title: 'Inspection & Repair',
          checklist: [
            CheckItem(code: '$id-T2-1', label: 'Diagnose the fault', type: CheckType.tick),
            CheckItem(code: '$id-T2-2', label: 'Carry out the repair', type: CheckType.tick),
          ],
        ),
        WoTask(
          id: '$id-T3',
          title: 'Testing & Sign-off',
          checklist: [
            CheckItem(code: '$id-T3-1', label: 'Functional test', type: CheckType.tick),
            CheckItem(code: '$id-T3-2', label: 'Operator sign-off', type: CheckType.tick),
          ],
        ),
      ],
      history: [_log('Work order created'), if (assignee != null) _log('Assigned to ${assignee.name}')],
    );
    state = [wo, ...state];
    ref.read(assetsProvider.notifier).addEvent(assetId, 'Work order $id created', note: title);
    _queue(id, 'Created');
    return id;
  }

  void updateStatus(String id, String status, {String? note}) {
    _update(
      id,
      (w) => w.copyWith(
        status: status,
        holdReason: status == WoStatus.onHold ? note : null,
        clearHold: status != WoStatus.onHold,
        history: [...w.history, _log('Status changed to $status', note)],
      ),
    );
    _queue(id, 'Status: $status');
    if (status == WoStatus.inProgress) {
      final wo = byId(id)!;
      if (wo.workType == 'Breakdown') {
        ref.read(assetsProvider.notifier).setStatus(wo.assetId, AssetStatus.underMaintenance);
      }
    }
  }

  void reassign(String id, String personId) {
    final p = ref.read(personByIdProvider(personId));
    _update(
      id,
      (w) => w.copyWith(
        assigneeId: personId,
        status: w.status == WoStatus.open ? WoStatus.assigned : w.status,
        history: [...w.history, _log('Assigned to ${p?.name ?? personId}')],
      ),
    );
    _queue(id, 'Reassigned');
  }

  void updateDescription(String id, String text) {
    _update(id, (w) => w.copyWith(description: text, history: [...w.history, _log('Description edited')]));
    _queue(id, 'Description edited');
  }

  void addPhoto(String id, String path) {
    _update(id, (w) => w.copyWith(photos: [...w.photos, path]));
    _queuePhoto(id, path);
  }

  void removePhoto(String id, int index) {
    _update(id, (w) => w.copyWith(photos: [...w.photos]..removeAt(index)));
    _queue(id, 'Photo removed');
  }

  void _updateTask(String woId, String taskId, WoTask Function(WoTask) f) =>
      _update(woId, (w) => w.copyWith(tasks: [for (final t in w.tasks) t.id == taskId ? f(t) : t]));

  /// Replaces one checklist item of a task (any change made in the checklist engine).
  void setChecklistItem(String woId, String taskId, CheckItem item) {
    _updateTask(
      woId,
      taskId,
      (t) => t.copyWith(checklist: [for (final c in t.checklist) c.code == item.code ? item : c]),
    );
    _queue(woId, 'Checklist updated');
  }

  void toggleChecklistItem(String woId, String taskId, String itemId) {
    _updateTask(
      woId,
      taskId,
      (t) => t.copyWith(
        checklist: [
          for (final c in t.checklist)
            c.code == itemId ? (c.answered ? c.copyWith(clearValue: true) : c.copyWith(value: CheckItem.done)) : c,
        ],
      ),
    );
    _queue(woId, 'Checklist updated');
  }

  void setTaskNotes(String woId, String taskId, String notes) {
    _updateTask(woId, taskId, (t) => t.copyWith(notes: notes));
    _queue(woId, 'Task notes');
  }

  void addVoiceNote(String woId, String taskId, String label) {
    _updateTask(woId, taskId, (t) => t.copyWith(voiceNotes: [...t.voiceNotes, label]));
    _queue(woId, 'Voice note added');
  }

  void addTaskPhoto(String woId, String taskId, String path) {
    _updateTask(woId, taskId, (t) => t.copyWith(photos: [...t.photos, path]));
    _queuePhoto(woId, path);
  }

  /// Marks the task done and opens the next pending one.
  void completeTask(String woId, String taskId) {
    final wo = byId(woId);
    if (wo == null) return;
    final idx = wo.tasks.indexWhere((t) => t.id == taskId);
    final now = DemoClock.now;
    final tasks = [
      for (var i = 0; i < wo.tasks.length; i++)
        if (i == idx)
          wo.tasks[i].copyWith(status: TaskStatus.completed, completedAt: now)
        else if (i == idx + 1 && wo.tasks[i].status == TaskStatus.pending)
          wo.tasks[i].copyWith(status: TaskStatus.inProgress)
        else
          wo.tasks[i],
    ];
    _update(
      woId,
      (w) => w.copyWith(
        tasks: tasks,
        status: w.status == WoStatus.open || w.status == WoStatus.assigned ? WoStatus.inProgress : w.status,
        history: [...w.history, _log('Task completed: ${wo.tasks[idx].title}')],
      ),
    );
    _queue(woId, 'Task completed');
  }

  /// Adds a part from inventory and reserves it there.
  void addPart(String woId, String partId, int qty) {
    _update(woId, (w) {
      final existing = w.parts.firstWhereOrNull((p) => p.partId == partId && p.status == 'Reserved');
      final parts = existing == null
          ? [...w.parts, WoPart(partId: partId, qty: qty)]
          : [for (final p in w.parts) p == existing ? p.copyWith(qty: p.qty + qty) : p];
      return w.copyWith(parts: parts, history: [...w.history, _log('Part added: $partId × $qty')]);
    });
    ref.read(inventoryProvider.notifier).reserve(partId, qty, ref: woId, assetId: byId(woId)?.assetId);
    _queue(woId, 'Parts updated');
  }

  /// Inventory → Issue to Work Order: stock is issued and the WO shows the part as used.
  void issuePart(String woId, String partId, int qty) {
    final wo = byId(woId);
    if (wo == null) return;
    ref.read(inventoryProvider.notifier).issue(partId, qty, ref: woId, assetId: wo.assetId, type: TxnType.issuedToWo);
    _update(
      woId,
      (w) => w.copyWith(
        parts: [
          ...w.parts,
          WoPart(partId: partId, qty: qty, status: 'Used'),
        ],
        history: [...w.history, _log('Part issued from stores: $partId × $qty')],
      ),
    );
    _queue(woId, 'Parts updated');
  }

  /// Removes a reserved part and releases the reservation in inventory.
  void removePart(String woId, String partId) {
    final part = byId(woId)?.parts.firstWhereOrNull((p) => p.partId == partId && p.status == 'Reserved');
    if (part == null) return;
    _update(
      woId,
      (w) => w.copyWith(
        parts: [...w.parts]..remove(part),
        history: [...w.history, _log('Part removed: $partId × ${part.qty}')],
      ),
    );
    ref.read(inventoryProvider.notifier).unreserve(partId, part.qty, ref: woId, assetId: byId(woId)?.assetId);
    _queue(woId, 'Parts updated');
  }

  /// Closes the WO: parts become used (issued from stock) and the asset returns to Active.
  /// [usedQty] overrides how many of each reserved part were really used (the rest is released).
  void close(
    String id, {
    required String resolution,
    required double labourHours,
    Map<String, int> usedQty = const {},
    List<List<(double, double)>> signature = const [],
  }) {
    final wo = byId(id);
    if (wo == null) return;
    final inventory = ref.read(inventoryProvider.notifier);
    final parts = <WoPart>[];
    for (final p in wo.parts) {
      if (p.status != 'Reserved') {
        parts.add(p);
        continue;
      }
      final used = (usedQty[p.partId] ?? p.qty).clamp(0, p.qty);
      if (used > 0) inventory.issue(p.partId, used, ref: id, assetId: wo.assetId, fromReserved: true);
      if (used < p.qty) inventory.unreserve(p.partId, p.qty - used, ref: id, assetId: wo.assetId);
      if (used > 0) parts.add(p.copyWith(qty: used, status: 'Used'));
    }
    _update(
      id,
      (w) => w.copyWith(
        status: WoStatus.closed,
        completedAt: DemoClock.now,
        resolution: resolution,
        labourHours: labourHours,
        parts: parts,
        signature: signature,
        clearHold: true,
        history: [...w.history, _log('Work order closed', '$resolution · ${labourHours}h labour')],
      ),
    );
    final assets = ref.read(assetsProvider.notifier);
    assets.setStatus(wo.assetId, AssetStatus.active);
    assets.addEvent(wo.assetId, 'Work order $id closed', note: resolution);
    _queue(id, 'Closed');
  }

  void markSynced(String id) => _update(id, (w) => w.copyWith(savedOffline: false));
}

final workOrdersProvider = NotifierProvider<WorkOrdersNotifier, List<WorkOrder>>(WorkOrdersNotifier.new);

final workOrderByIdProvider = Provider.family<WorkOrder?, String>(
  (ref, id) => ref.watch(workOrdersProvider).firstWhereOrNull((w) => w.id == id),
);

extension WorkOrderQueries on List<WorkOrder> {
  List<WorkOrder> get active => where((w) => w.isActive).toList();

  /// "My Work Orders": active WOs assigned to or coordinated by [userId].
  List<WorkOrder> mine(String userId) =>
      where((w) => w.isActive && (w.assigneeId == userId || w.coordinatorId == userId)).toList();

  /// Home "Work Orders – My Assigned".
  List<WorkOrder> assignedTo(String userId) => where((w) => w.isActive && w.assigneeId == userId).toList();

  List<WorkOrder> get pmDue => where((w) => w.isActive && w.isPreventive && !DemoClock.isOverdue(w.dueAt)).toList();
  List<WorkOrder> get overdue => where((w) => w.isActive && DemoClock.isOverdue(w.dueAt)).toList();
  List<WorkOrder> get breakdowns => where((w) => w.workType == 'Breakdown').toList();
  List<WorkOrder> get serviceHistory => where((w) => !w.isActive).toList();
  List<WorkOrder> forAsset(String assetId) => where((w) => w.assetId == assetId).toList();
  List<WorkOrder> on(DateTime day) =>
      where((w) => w.dueAt.year == day.year && w.dueAt.month == day.month && w.dueAt.day == day.day).toList();
}

class PmSchedulesNotifier extends Notifier<List<PmSchedule>> {
  @override
  List<PmSchedule> build() => seedPmSchedules();

  /// "Generate WO now": creates a preventive WO and moves the schedule's next due date.
  String generateWorkOrder(String pmId) {
    final pm = state.firstWhere((p) => p.id == pmId);
    final asset = ref.read(assetByIdProvider(pm.assetId));
    final id = ref
        .read(workOrdersProvider.notifier)
        .create(
          assetId: pm.assetId,
          title: '${asset?.type ?? pm.assetId} – ${pm.title}',
          priority: 'Medium',
          category: 'Preventive Maintenance',
          workType: 'Scheduled',
          dueAt: pm.nextDue.isBefore(DemoClock.now) ? DemoClock.now.add(const Duration(days: 1)) : pm.nextDue,
        );
    final step = switch (pm.frequency) {
      'Monthly' => 30,
      'Quarterly' => 91,
      'Yearly' => 365,
      _ => 7,
    };
    state = [for (final p in state) p.id == pmId ? p.copyWith(nextDue: p.nextDue.add(Duration(days: step))) : p];
    return id;
  }
}

final pmSchedulesProvider = NotifierProvider<PmSchedulesNotifier, List<PmSchedule>>(PmSchedulesNotifier.new);

final upcomingActivitiesProvider = Provider<List<UpcomingActivity>>((ref) => seedUpcomingActivities());

/// One entry on the Maintenance Calendar.
class CalendarEvent {
  const CalendarEvent({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.at,
  });

  /// workOrder, inspection or audit.
  final String kind;
  final String id;
  final String title;
  final String subtitle;
  final DateTime at;
}

/// Work orders and inspections by due date, audits by start date plus
/// scheduled audit activities, grouped by day.
final calendarEventsProvider = Provider<Map<DateTime, List<CalendarEvent>>>((ref) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final events = <CalendarEvent>[
    for (final w in ref.watch(workOrdersProvider))
      CalendarEvent(kind: 'workOrder', id: w.id, title: w.id, subtitle: w.title, at: w.scheduledAt ?? w.dueAt),
    for (final i in ref.watch(inspectionsProvider))
      CalendarEvent(kind: 'inspection', id: i.id, title: i.id, subtitle: i.title, at: i.dueAt),
    for (final a in ref.watch(auditsProvider)) ...[
      CalendarEvent(kind: 'audit', id: a.id, title: a.name, subtitle: '${a.site} · starts', at: a.start),
      CalendarEvent(kind: 'audit', id: a.id, title: a.name, subtitle: '${a.site} · ends', at: a.end),
    ],
    for (final u in ref.watch(upcomingActivitiesProvider).where((u) => u.kind == 'audit'))
      CalendarEvent(kind: 'audit', id: u.refId, title: u.title, subtitle: '${u.subtitle} · ${u.location}', at: u.at),
  ];
  final map = <DateTime, List<CalendarEvent>>{};
  for (final e in events) {
    (map[day(e.at)] ??= []).add(e);
  }
  for (final l in map.values) {
    l.sort((a, b) => a.at.compareTo(b.at));
  }
  return map;
});
