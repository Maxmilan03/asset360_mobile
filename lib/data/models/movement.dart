import 'common.dart';

abstract final class MoveStatus {
  static const pending = 'Pending Approval';
  static const approved = 'Approved';
  static const inTransit = 'In Transit';
  static const completed = 'Completed';
  static const rejected = 'Rejected';
  static const cancelled = 'Cancelled';
}

abstract final class MoveType {
  static const transfer = 'Transfer';
  static const checkOut = 'Check Out';
  static const checkIn = 'Check In';
  static const assign = 'Assign Custodian';
  static const returnAsset = 'Return';
}

/// A "From" or "To" card: name plus two address lines.
class MovePlace {
  const MovePlace(this.name, [this.line1, this.line2]);

  final String name;
  final String? line1;
  final String? line2;
}

class MovementRequest {
  const MovementRequest({
    required this.id,
    required this.assetId,
    required this.type,
    required this.status,
    required this.from,
    required this.to,
    required this.requesterId,
    required this.createdAt,
    this.approverId,
    this.fromCustodian,
    this.newCustodian,
    this.requiredDate,
    this.reason,
    this.remarks,
    this.attachments = const [],
    this.timeline = const [],
    this.rejectReason,
  });

  final String id;
  final String assetId;
  final String type;
  final String status;
  final MovePlace from;
  final MovePlace to;
  final String requesterId;
  final String? approverId;
  final String? fromCustodian;
  final String? newCustodian;
  final DateTime createdAt;
  final DateTime? requiredDate;
  final String? reason;
  final String? remarks;
  final List<Attachment> attachments;
  final List<LogEntry> timeline;
  final String? rejectReason;

  MovementRequest copyWith({String? status, List<LogEntry>? timeline, String? rejectReason}) => MovementRequest(
    id: id,
    assetId: assetId,
    type: type,
    status: status ?? this.status,
    from: from,
    to: to,
    requesterId: requesterId,
    createdAt: createdAt,
    approverId: approverId,
    fromCustodian: fromCustodian,
    newCustodian: newCustodian,
    requiredDate: requiredDate,
    reason: reason,
    remarks: remarks,
    attachments: attachments,
    timeline: timeline ?? this.timeline,
    rejectReason: rejectReason ?? this.rejectReason,
  );
}
