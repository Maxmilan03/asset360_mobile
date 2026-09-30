import 'common.dart';

enum QuestionType { choice, number, yesNo, text }

abstract final class InspectionStatus {
  static const scheduled = 'Scheduled';
  static const inProgress = 'In Progress';
  static const completed = 'Completed';
}

/// One checklist question. "Answered" = [answer] is not empty.
class ChecklistQuestion {
  const ChecklistQuestion({
    required this.code,
    required this.text,
    required this.type,
    this.options = const [],
    this.unit,
    this.min,
    this.max,
    this.answer,
    this.note,
  });

  final String code;
  final String text;
  final QuestionType type;

  /// For choice / yesNo, the first option is the "good" answer.
  final List<String> options;
  final String? unit;
  final double? min;
  final double? max;
  final String? answer;
  final String? note;

  bool get answered => answer != null && answer!.trim().isNotEmpty;

  /// For number answers: true when inside the normal range.
  bool? get inRange {
    if (type != QuestionType.number || !answered || min == null || max == null) return null;
    final v = double.tryParse(answer!);
    return v != null && v >= min! && v <= max!;
  }

  String? get rangeLabel =>
      min == null || max == null ? null : 'Normal Range: ${_n(min!)} – ${_n(max!)} ${unit ?? ''}'.trim();

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  ChecklistQuestion copyWith({String? answer, String? note}) => ChecklistQuestion(
    code: code,
    text: text,
    type: type,
    options: options,
    unit: unit,
    min: min,
    max: max,
    answer: answer ?? this.answer,
    note: note ?? this.note,
  );
}

class ChecklistSection {
  const ChecklistSection({required this.title, required this.questions});

  final String title;
  final List<ChecklistQuestion> questions;

  int get answered => questions.where((q) => q.answered).length;
  bool get complete => answered == questions.length;

  ChecklistSection copyWith({List<ChecklistQuestion>? questions}) =>
      ChecklistSection(title: title, questions: questions ?? this.questions);
}

class Finding {
  const Finding({
    required this.id,
    required this.title,
    required this.severity,
    required this.createdAt,
    this.description = '',
    this.questionCode,
  });

  final String id;
  final String title;
  final String severity;
  final DateTime createdAt;
  final String description;
  final String? questionCode;
}

class Inspection {
  const Inspection({
    required this.id,
    required this.assetId,
    required this.title,
    required this.type,
    required this.status,
    required this.dueAt,
    required this.inspectorId,
    this.sections = const [],
    this.findings = const [],
    this.photos = const [],
    this.notes = '',
    this.history = const [],
    this.documentIds = const [],
    this.completedAt,
    this.savedOffline = false,
  });

  final String id;
  final String assetId;

  /// Display line, e.g. "Fire Pump – Routine Inspection".
  final String title;
  final String type;
  final String status;
  final DateTime dueAt;
  final String inspectorId;
  final List<ChecklistSection> sections;
  final List<Finding> findings;
  final List<String> photos;
  final String notes;
  final List<LogEntry> history;
  final List<String> documentIds;
  final DateTime? completedAt;
  final bool savedOffline;

  bool get isCompleted => status == InspectionStatus.completed;
  int get totalQuestions => sections.fold(0, (s, e) => s + e.questions.length);
  int get answeredQuestions => sections.fold(0, (s, e) => s + e.answered);
  double get progress => totalQuestions == 0 ? 0 : answeredQuestions / totalQuestions;

  Inspection copyWith({
    String? status,
    DateTime? dueAt,
    String? inspectorId,
    List<ChecklistSection>? sections,
    List<Finding>? findings,
    List<String>? photos,
    String? notes,
    List<LogEntry>? history,
    DateTime? completedAt,
    bool? savedOffline,
  }) {
    return Inspection(
      id: id,
      assetId: assetId,
      title: title,
      type: type,
      status: status ?? this.status,
      dueAt: dueAt ?? this.dueAt,
      inspectorId: inspectorId ?? this.inspectorId,
      sections: sections ?? this.sections,
      findings: findings ?? this.findings,
      photos: photos ?? this.photos,
      notes: notes ?? this.notes,
      history: history ?? this.history,
      documentIds: documentIds,
      completedAt: completedAt ?? this.completedAt,
      savedOffline: savedOffline ?? this.savedOffline,
    );
  }
}
