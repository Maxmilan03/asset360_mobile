import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/inspections_mock.dart';
import '../models/common.dart';
import '../models/inspection.dart';
import 'assets_repository.dart';
import 'repo_utils.dart';
import 'session_repository.dart';

class InspectionsNotifier extends Notifier<List<Inspection>> {
  @override
  List<Inspection> build() => seedInspections();

  String get _me => ref.read(currentUserProvider).name;
  LogEntry _log(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  Inspection? byId(String id) => state.firstWhereOrNull((i) => i.id == id);
  void _update(String id, Inspection Function(Inspection) f) => state = replaceWhere(state, id, (i) => i.id, f);

  /// Creates an inspection with the standard checklist. Returns its ID.
  String create({
    required String assetId,
    required String title,
    required String type,
    required DateTime dueAt,
    String? inspectorId,
  }) {
    final id = nextId('INS-2026-', state.map((i) => i.id));
    state = [
      Inspection(
        id: id,
        assetId: assetId,
        title: title,
        type: type,
        status: InspectionStatus.scheduled,
        dueAt: dueAt,
        inspectorId: inspectorId ?? ref.read(currentUserProvider).id,
        sections: [
          for (final s in fireAndPumpChecklist())
            s.copyWith(
              questions: [
                for (final q in s.questions)
                  ChecklistQuestion(
                    code: q.code,
                    text: q.text,
                    type: q.type,
                    options: q.options,
                    unit: q.unit,
                    min: q.min,
                    max: q.max,
                  ),
              ],
            ),
        ],
        history: [_log('Inspection scheduled')],
      ),
      ...state,
    ];
    ref.read(assetsProvider.notifier).addEvent(assetId, 'Inspection $id scheduled', note: title);
    return id;
  }

  /// Answers a question; the first answer moves a scheduled inspection to In Progress.
  void answer(String id, String code, String value) => _update(
    id,
    (i) => i.copyWith(
      status: i.status == InspectionStatus.scheduled ? InspectionStatus.inProgress : i.status,
      sections: [
        for (final s in i.sections)
          s.copyWith(questions: [for (final q in s.questions) q.code == code ? q.copyWith(answer: value) : q]),
      ],
    ),
  );

  void setQuestionNote(String id, String code, String note) => _update(
    id,
    (i) => i.copyWith(
      sections: [
        for (final s in i.sections)
          s.copyWith(questions: [for (final q in s.questions) q.code == code ? q.copyWith(note: note) : q]),
      ],
    ),
  );

  void setNotes(String id, String notes) => _update(id, (i) => i.copyWith(notes: notes));
  void setStatus(String id, String status) =>
      _update(id, (i) => i.copyWith(status: status, history: [...i.history, _log('Status changed to $status')]));
  void addPhoto(String id, String path) => _update(id, (i) => i.copyWith(photos: [...i.photos, path]));
  void removePhoto(String id, int index) => _update(id, (i) => i.copyWith(photos: [...i.photos]..removeAt(index)));

  void addFinding(
    String id, {
    required String title,
    required String severity,
    String description = '',
    String? questionCode,
  }) {
    final all = state.expand((i) => i.findings).map((f) => f.id);
    final f = Finding(
      id: nextId('FND-2026-', all),
      title: title,
      severity: severity,
      createdAt: DemoClock.now,
      description: description,
      questionCode: questionCode,
    );
    _update(
      id,
      (i) => i.copyWith(findings: [...i.findings, f], history: [...i.history, _log('Finding added: $title')]),
    );
  }

  void reschedule(String id, DateTime due) => _update(
    id,
    (i) => i.copyWith(dueAt: due, history: [...i.history, _log('Rescheduled to ${DemoClock.formatDateTime(due)}')]),
  );

  void complete(String id) {
    final ins = byId(id);
    _update(
      id,
      (i) => i.copyWith(
        status: InspectionStatus.completed,
        completedAt: DemoClock.now,
        history: [...i.history, _log('Inspection completed')],
      ),
    );
    if (ins != null) {
      ref.read(assetsProvider.notifier).addEvent(ins.assetId, 'Inspection $id completed', note: ins.title);
    }
  }

  void markSynced(String id) => _update(id, (i) => i.copyWith(savedOffline: false));
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
  List<Inspection> forAsset(String assetId) => where((i) => i.assetId == assetId).toList();

  /// Display status: "Overdue" / "Due Today" override the stored status in lists.
  static String displayStatus(Inspection i) {
    if (i.isCompleted) return InspectionStatus.completed;
    if (DemoClock.isOverdue(i.dueAt)) return 'Overdue';
    if (DemoClock.isToday(i.dueAt)) return 'Due Today';
    return i.status;
  }
}
