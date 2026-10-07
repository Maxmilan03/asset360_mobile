import 'package:asset360_mobile/core/checklist/checklist.dart';
import 'package:asset360_mobile/data/models/common.dart';

abstract final class WoStatus {
  static const open = 'Open';
  static const assigned = 'Assigned';
  static const inProgress = 'In Progress';
  static const onHold = 'On Hold';
  static const completed = 'Completed';
  static const closed = 'Closed';

  static const all = [open, assigned, inProgress, onHold, completed, closed];
  static bool isActive(String s) => s != completed && s != closed;
}

abstract final class TaskStatus {
  static const pending = 'Pending';
  static const inProgress = 'In Progress';
  static const completed = 'Completed';
}

class WoTask {
  const WoTask({
    required this.id,
    required this.title,
    this.status = TaskStatus.pending,
    this.completedAt,
    this.checklist = const [],
    this.notes = '',
    this.voiceNotes = const [],
    this.photos = const [],
  });

  final String id;
  final String title;
  final String status;
  final DateTime? completedAt;
  final List<CheckItem> checklist;
  final String notes;
  final List<String> voiceNotes;
  final List<String> photos;

  bool get isDone => status == TaskStatus.completed;
  int get checklistDone => checklist.answered;
  bool get checklistComplete => checklist.complete;

  WoTask copyWith({
    String? status,
    DateTime? completedAt,
    List<CheckItem>? checklist,
    String? notes,
    List<String>? voiceNotes,
    List<String>? photos,
  }) => WoTask(
    id: id,
    title: title,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    checklist: checklist ?? this.checklist,
    notes: notes ?? this.notes,
    voiceNotes: voiceNotes ?? this.voiceNotes,
    photos: photos ?? this.photos,
  );
}

class WoPart {
  const WoPart({required this.partId, required this.qty, this.status = 'Reserved'});

  final String partId;
  final int qty;

  /// Reserved or Used.
  final String status;

  WoPart copyWith({int? qty, String? status}) =>
      WoPart(partId: partId, qty: qty ?? this.qty, status: status ?? this.status);
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.assetId,
    required this.title,
    required this.priority,
    required this.status,
    required this.category,
    required this.workType,
    required this.openedAt,
    required this.dueAt,
    required this.reporterId,
    this.description = '',
    this.sla,
    this.scheduledAt,
    this.assigneeId,
    this.coordinatorId,
    this.tasks = const [],
    this.parts = const [],
    this.history = const [],
    this.documentIds = const [],
    this.photos = const [],
    this.issueId,
    this.completedAt,
    this.resolution,
    this.labourHours,
    this.savedOffline = false,
    this.signature = const [],
    this.holdReason,
  });

  final String id;
  final String assetId;

  /// Display line, e.g. "Generator – High vibration".
  final String title;
  final String description;
  final String priority;
  final String status;

  /// Corrective or Preventive.
  final String category;

  /// Breakdown, Scheduled, Inspection, Calibration …
  final String workType;
  final String? sla;
  final DateTime openedAt;
  final DateTime dueAt;

  /// For scheduled work (e.g. PM – AHU-02 at 10:00 AM); due time can be later.
  final DateTime? scheduledAt;
  final String? assigneeId;
  final String reporterId;

  /// The supervisor who follows the WO. Shows in the coordinator's "My Work Orders".
  final String? coordinatorId;
  final List<WoTask> tasks;
  final List<WoPart> parts;
  final List<LogEntry> history;
  final List<String> documentIds;
  final List<String> photos;
  final String? issueId;
  final DateTime? completedAt;
  final String? resolution;
  final double? labourHours;

  /// Saved on the device while offline, waiting for Offline Sync.
  final bool savedOffline;

  /// Close-out signature: strokes of points as 0–1 fractions of the pad.
  final List<List<(double, double)>> signature;

  /// Why the WO is On Hold (null otherwise).
  final String? holdReason;

  /// The task being worked on: the one in progress, else the first unfinished one.
  String? get openTaskId {
    for (final t in tasks) {
      if (t.status == TaskStatus.inProgress) return t.id;
    }
    for (final t in tasks) {
      if (!t.isDone) return t.id;
    }
    return null;
  }

  bool get isActive => WoStatus.isActive(status);
  bool get isPreventive => category == 'Preventive Maintenance';
  int get tasksDone => tasks.where((t) => t.isDone).length;
  bool get allTasksDone => tasks.every((t) => t.isDone);

  WorkOrder copyWith({
    String? title,
    String? description,
    String? priority,
    String? status,
    DateTime? dueAt,
    String? assigneeId,
    List<WoTask>? tasks,
    List<WoPart>? parts,
    List<LogEntry>? history,
    List<String>? documentIds,
    List<String>? photos,
    DateTime? completedAt,
    String? resolution,
    double? labourHours,
    bool? savedOffline,
    List<List<(double, double)>>? signature,
    String? holdReason,
    bool clearHold = false,
  }) {
    return WorkOrder(
      id: id,
      assetId: assetId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category,
      workType: workType,
      sla: sla,
      openedAt: openedAt,
      dueAt: dueAt ?? this.dueAt,
      scheduledAt: scheduledAt,
      assigneeId: assigneeId ?? this.assigneeId,
      reporterId: reporterId,
      coordinatorId: coordinatorId,
      tasks: tasks ?? this.tasks,
      parts: parts ?? this.parts,
      history: history ?? this.history,
      documentIds: documentIds ?? this.documentIds,
      photos: photos ?? this.photos,
      issueId: issueId,
      completedAt: completedAt ?? this.completedAt,
      resolution: resolution ?? this.resolution,
      labourHours: labourHours ?? this.labourHours,
      savedOffline: savedOffline ?? this.savedOffline,
      signature: signature ?? this.signature,
      holdReason: clearHold ? null : holdReason ?? this.holdReason,
    );
  }
}

/// Preventive maintenance schedule (Maintenance hub → Preventive Maintenance).
class PmSchedule {
  const PmSchedule({
    required this.id,
    required this.assetId,
    required this.title,
    required this.frequency,
    required this.nextDue,
    required this.lastDone,
  });

  final String id;
  final String assetId;
  final String title;
  final String frequency;
  final DateTime nextDue;
  final DateTime lastDone;

  PmSchedule copyWith({DateTime? nextDue, DateTime? lastDone}) => PmSchedule(
    id: id,
    assetId: assetId,
    title: title,
    frequency: frequency,
    nextDue: nextDue ?? this.nextDue,
    lastDone: lastDone ?? this.lastDone,
  );
}

/// Home "Upcoming Activities" row, pointing at a WO, inspection or audit.
class UpcomingActivity {
  const UpcomingActivity({
    required this.kind,
    required this.refId,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.location,
  });

  /// workOrder, inspection or audit.
  final String kind;
  final String refId;
  final String title;
  final String subtitle;
  final DateTime at;
  final String location;
}
