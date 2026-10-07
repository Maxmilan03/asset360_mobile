import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/checklist/checklist.dart';
import 'package:asset360_mobile/data/mock/inspections_mock.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/models/inspection.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';

class InspectionsNotifier extends Notifier<List<Inspection>> {
  @override
  List<Inspection> build() => seedInspections();

  String get _me => ref.read(currentUserProvider).name;
  LogEntry _log(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  Inspection? byId(String id) => state.firstWhereOrNull((i) => i.id == id);

  /// Every change also goes into the sync queue while offline ([change] is the queue subtitle).
  void _update(String id, Inspection Function(Inspection) f, {String change = 'Updated', bool queue = true}) {
    state = replaceWhere(state, id, (i) => i.id, f);
    if (queue) _queue(id, change);
  }

  void _queue(String id, String change) {
    final ins = byId(id);
    if (ins == null) return;
    if (ref.queueOffline(SyncKind.inspection, id, '${ins.type} · $change', refId: id) && !ins.savedOffline) {
      state = replaceWhere(state, id, (i) => i.id, (i) => i.copyWith(savedOffline: true));
    }
  }

  void _queuePhoto(String id, String path) =>
      ref.queueOffline(SyncKind.photo, syncFileName(path), 'Inspection Photos', refId: id);

  /// Creates an inspection from a template (see `inspectionTemplates`). Returns its ID.
  String create({required String assetId, required String template, required DateTime dueAt, String? inspectorId}) {
    final id = nextId('INS-2026-', state.map((i) => i.id));
    final (type, suffix, checklist) = inspectionTemplates[template] ?? inspectionTemplates.values.first;
    final asset = ref.read(assetByIdProvider(assetId));
    final title = '${asset?.type ?? assetId} – $suffix';
    state = [
      Inspection(
        id: id,
        assetId: assetId,
        title: title,
        type: type,
        template: template,
        status: InspectionStatus.scheduled,
        dueAt: dueAt,
        inspectorId: inspectorId ?? ref.read(currentUserProvider).id,
        sections: checklist(),
        history: [_log('Inspection scheduled', template)],
      ),
      ...state,
    ];
    ref.read(assetsProvider.notifier).addEvent(assetId, 'Inspection $id scheduled', note: title);
    _queue(id, 'Created');
    return id;
  }

  /// Replaces a checklist item; the first answer moves a scheduled inspection to In Progress.
  void setItem(String id, CheckItem item) => _update(
    id,
    (i) => i.copyWith(
      status: i.status == InspectionStatus.scheduled && item.answered ? InspectionStatus.inProgress : i.status,
      sections: i.sections.updateItem(item.code, (_) => item),
    ),
    change: 'Answers saved',
  );

  /// Answers a choice / number / text item.
  void answer(String id, String code, String value) {
    final item = byId(id)?.sections.item(code);
    if (item != null) setItem(id, item.copyWith(value: value));
  }

  void _updateSection(String id, int index, CheckSection Function(CheckSection) f) =>
      _update(id, (i) => i.copyWith(sections: [for (final (n, s) in i.sections.indexed) n == index ? f(s) : s]));

  void setSectionNotes(String id, int section, String notes) =>
      _updateSection(id, section, (s) => s.copyWith(notes: notes));
  void addSectionPhoto(String id, int section, String path) {
    _update(
      id,
      (i) => i.copyWith(
        sections: [
          for (final (n, s) in i.sections.indexed) n == section ? s.copyWith(photos: [...s.photos, path]) : s,
        ],
      ),
      queue: false,
    );
    _queuePhoto(id, path);
  }

  void removeSectionPhoto(String id, int section, int index) =>
      _updateSection(id, section, (s) => s.copyWith(photos: [...s.photos]..removeAt(index)));

  /// "Save as Draft": answers are already kept; this logs it.
  void saveDraft(String id) => _update(id, (i) => i.copyWith(history: [...i.history, _log('Draft saved')]));

  void setNotes(String id, String notes) => _update(id, (i) => i.copyWith(notes: notes));
  void setStatus(String id, String status) =>
      _update(id, (i) => i.copyWith(status: status, history: [...i.history, _log('Status changed to $status')]));
  void addPhoto(String id, String path) {
    _update(id, (i) => i.copyWith(photos: [...i.photos, path]), queue: false);
    _queuePhoto(id, path);
  }

  void removePhoto(String id, int index) => _update(id, (i) => i.copyWith(photos: [...i.photos]..removeAt(index)));

  /// Adds a finding and returns its ID.
  String addFinding(
    String id, {
    required String title,
    required String severity,
    String description = '',
    String? questionCode,
    List<String> photos = const [],
  }) {
    final all = state.expand((i) => i.findings).map((f) => f.id);
    final f = Finding(
      id: nextId('FND-2026-', all),
      title: title,
      severity: severity,
      createdAt: DemoClock.now,
      description: description,
      questionCode: questionCode,
      photos: photos,
    );
    _update(
      id,
      (i) => i.copyWith(findings: [...i.findings, f], history: [...i.history, _log('Finding added: $title')]),
    );
    return f.id;
  }

  void _updateFinding(String findingId, Finding Function(Finding) f, String log) {
    final ins = state.firstWhereOrNull((i) => i.findings.any((x) => x.id == findingId));
    if (ins == null) return;
    _update(
      ins.id,
      (i) => i.copyWith(
        findings: [for (final x in i.findings) x.id == findingId ? f(x) : x],
        history: [...i.history, _log(log)],
      ),
    );
  }

  /// A work order was created for the finding: status Action Taken.
  void linkWorkOrder(String findingId, String woId) => _updateFinding(
    findingId,
    (f) => f.copyWith(status: FindingStatus.actionTaken, workOrderId: woId),
    'Work order $woId created for $findingId',
  );

  void closeFinding(String findingId) => _updateFinding(
    findingId,
    (f) => f.copyWith(status: FindingStatus.closed, closedAt: DemoClock.now),
    'Finding $findingId closed',
  );

  void linkDocument(String id, String docId) => _update(
    id,
    (i) => i.copyWith(documentIds: [...i.documentIds, docId], history: [...i.history, _log('Document attached')]),
  );

  void reschedule(String id, DateTime due) => _update(
    id,
    (i) => i.copyWith(dueAt: due, history: [...i.history, _log('Rescheduled to ${DemoClock.formatDateTime(due)}')]),
  );

  /// Submit: marks the inspection Completed with the inspector's signature.
  void complete(String id, {List<List<SignaturePoint>> signature = const []}) {
    final ins = byId(id);
    _update(
      id,
      (i) => i.copyWith(
        status: InspectionStatus.completed,
        completedAt: DemoClock.now,
        signature: signature,
        history: [...i.history, _log('Inspection completed', 'Score ${i.passedQuestions} / ${i.totalQuestions}')],
      ),
      change: 'Submitted',
    );
    if (ins != null) {
      ref.read(assetsProvider.notifier).addEvent(ins.assetId, 'Inspection $id completed', note: ins.title);
    }
  }

  void markSynced(String id) => _update(id, (i) => i.copyWith(savedOffline: false), queue: false);
}

final inspectionsProvider = NotifierProvider<InspectionsNotifier, List<Inspection>>(InspectionsNotifier.new);

final inspectionByIdProvider = Provider.family<Inspection?, String>(
  (ref, id) => ref.watch(inspectionsProvider).firstWhereOrNull((i) => i.id == id),
);

extension InspectionQueries on List<Inspection> {
  List<Inspection> get open => where((i) => !i.isCompleted).toList();

  /// "My Inspections": not completed, inspector is [userId].
  List<Inspection> mine(String userId) => where((i) => !i.isCompleted && i.inspectorId == userId).toList();

  List<Inspection> get overdue => where((i) => !i.isCompleted && DemoClock.isOverdue(i.dueAt)).toList();

  /// Hub "Due Today" and Home "Inspections Due Today": due today, not completed (overdue ones included).
  List<Inspection> get dueToday => where((i) => !i.isCompleted && DemoClock.isToday(i.dueAt)).toList();

  /// "Due" tab: not completed, not overdue, due within the next 7 days.
  List<Inspection> get dueSoon => where(
    (i) =>
        !i.isCompleted &&
        !DemoClock.isOverdue(i.dueAt) &&
        i.dueAt.isBefore(DemoClock.today.add(const Duration(days: 8))),
  ).toList();

  List<Inspection> get completed => where((i) => i.isCompleted).toList();
  List<Finding> get findings => expand((i) => i.findings).toList();
  List<Finding> get openFindings => findings.where((f) => f.isOpen).toList();

  /// The inspection a finding belongs to.
  Inspection? ofFinding(String findingId) => firstWhereOrNull((i) => i.findings.any((f) => f.id == findingId));
  List<Inspection> forAsset(String assetId) => where((i) => i.assetId == assetId).toList();

  /// Display status: "Overdue" / "Due Today" override the stored status in lists.
  static String displayStatus(Inspection i) {
    if (i.isCompleted) return InspectionStatus.completed;
    if (DemoClock.isOverdue(i.dueAt)) return 'Overdue';
    if (DemoClock.isToday(i.dueAt)) return 'Due Today';
    return i.status;
  }
}
