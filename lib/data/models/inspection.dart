import '../../core/checklist/checklist.dart';
import 'common.dart';

abstract final class InspectionStatus {
  static const scheduled = 'Scheduled';
  static const inProgress = 'In Progress';
  static const completed = 'Completed';

  static const all = [scheduled, inProgress, completed];
}

abstract final class FindingStatus {
  static const open = 'Open';
  static const actionTaken = 'Action Taken';
  static const closed = 'Closed';

  static const all = [open, actionTaken, closed];
}

const findingSeverities = ['Low', 'Medium', 'High', 'Critical'];

class Finding {
  const Finding({
    required this.id,
    required this.title,
    required this.severity,
    required this.createdAt,
    this.description = '',
    this.questionCode,
    this.status = FindingStatus.open,
    this.photos = const [],
    this.workOrderId,
    this.closedAt,
  });

  final String id;
  final String title;
  final String severity;
  final DateTime createdAt;
  final String description;

  /// The checklist item that raised it ("1.1").
  final String? questionCode;

  /// Open / Action Taken (a work order was created) / Closed.
  final String status;
  final List<String> photos;
  final String? workOrderId;
  final DateTime? closedAt;

  bool get isOpen => status != FindingStatus.closed;

  Finding copyWith({String? status, String? workOrderId, DateTime? closedAt}) => Finding(
    id: id,
    title: title,
    severity: severity,
    createdAt: createdAt,
    description: description,
    questionCode: questionCode,
    status: status ?? this.status,
    photos: photos,
    workOrderId: workOrderId ?? this.workOrderId,
    closedAt: closedAt ?? this.closedAt,
  );
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
    this.template,
    this.signature = const [],
  });

  final String id;
  final String assetId;

  /// Display line, e.g. "Fire Pump – Routine Inspection".
  final String title;
  final String type;
  final String status;
  final DateTime dueAt;
  final String inspectorId;
  final List<CheckSection> sections;
  final List<Finding> findings;
  final List<String> photos;
  final String notes;
  final List<LogEntry> history;
  final List<String> documentIds;
  final DateTime? completedAt;
  final bool savedOffline;

  /// Template it was created from ("Fire Pump Routine").
  final String? template;

  /// Inspector signature given at Submit.
  final List<List<SignaturePoint>> signature;

  bool get isCompleted => status == InspectionStatus.completed;
  int get totalQuestions => sections.totalItems;
  int get answeredQuestions => sections.answeredItems;
  int get passedQuestions => sections.passedItems;
  double get progress => totalQuestions == 0 ? 0 : answeredQuestions / totalQuestions;
  List<Finding> get openFindings => findings.where((f) => f.isOpen).toList();

  Inspection copyWith({
    String? status,
    DateTime? dueAt,
    String? inspectorId,
    List<CheckSection>? sections,
    List<Finding>? findings,
    List<String>? photos,
    String? notes,
    List<LogEntry>? history,
    DateTime? completedAt,
    bool? savedOffline,
    List<String>? documentIds,
    List<List<SignaturePoint>>? signature,
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
      documentIds: documentIds ?? this.documentIds,
      completedAt: completedAt ?? this.completedAt,
      savedOffline: savedOffline ?? this.savedOffline,
      template: template,
      signature: signature ?? this.signature,
    );
  }
}
