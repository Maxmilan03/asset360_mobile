import 'common.dart';

abstract final class IssueStatus {
  static const open = 'Open';
  static const inProgress = 'In Progress';
  static const resolved = 'Resolved';
  static const closed = 'Closed';

  static const all = [open, inProgress, resolved, closed];
  static bool isOpen(String s) => s == open || s == inProgress;
}

class Issue {
  const Issue({
    required this.id,
    required this.assetId,
    required this.title,
    required this.type,
    required this.priority,
    required this.status,
    required this.reporterId,
    required this.reportedAt,
    required this.location,
    this.description = '',
    this.assigneeId,
    this.assignedTeam,
    this.photos = const [],
    this.workOrderIds = const [],
    this.timeline = const [],
    this.resolvedAt,
  });

  final String id;
  final String assetId;
  final String title;
  final String type;
  final String priority;
  final String status;
  final String reporterId;
  final DateTime reportedAt;
  final String location;
  final String description;
  final String? assigneeId;
  final String? assignedTeam;
  final List<String> photos;
  final List<String> workOrderIds;
  final List<LogEntry> timeline;
  final DateTime? resolvedAt;

  bool get isOpen => IssueStatus.isOpen(status);

  Issue copyWith({
    String? title,
    String? type,
    String? priority,
    String? status,
    String? description,
    String? location,
    String? assigneeId,
    String? assignedTeam,
    List<String>? photos,
    List<String>? workOrderIds,
    List<LogEntry>? timeline,
    DateTime? resolvedAt,
  }) {
    return Issue(
      id: id,
      assetId: assetId,
      title: title ?? this.title,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      reporterId: reporterId,
      reportedAt: reportedAt,
      location: location ?? this.location,
      description: description ?? this.description,
      assigneeId: assigneeId ?? this.assigneeId,
      assignedTeam: assignedTeam ?? this.assignedTeam,
      photos: photos ?? this.photos,
      workOrderIds: workOrderIds ?? this.workOrderIds,
      timeline: timeline ?? this.timeline,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
