import 'package:asset360_mobile/data/models/common.dart';

abstract final class DisposalStatus {
  static const pending = 'Pending';
  static const approved = 'Approved';
  static const rejected = 'Rejected';
}

/// More Actions → Create Disposal Request. Approved = the asset becomes Disposed.
class DisposalRequest {
  const DisposalRequest({
    required this.id,
    required this.assetId,
    required this.reason,
    required this.requestedDate,
    required this.requesterId,
    required this.approverId,
    required this.createdAt,
    this.status = DisposalStatus.pending,
    this.notes,
    this.rejectReason,
    this.timeline = const [],
  });

  final String id;
  final String assetId;

  /// One of `disposalReasons`, or the text typed for "Other".
  final String reason;
  final DateTime requestedDate;
  final String requesterId;
  final String approverId;
  final DateTime createdAt;
  final String status;
  final String? notes;
  final String? rejectReason;
  final List<LogEntry> timeline;

  bool get isPending => status == DisposalStatus.pending;

  DisposalRequest copyWith({String? status, String? rejectReason, List<LogEntry>? timeline}) => DisposalRequest(
    id: id,
    assetId: assetId,
    reason: reason,
    requestedDate: requestedDate,
    requesterId: requesterId,
    approverId: approverId,
    createdAt: createdAt,
    status: status ?? this.status,
    notes: notes,
    rejectReason: rejectReason ?? this.rejectReason,
    timeline: timeline ?? this.timeline,
  );
}
