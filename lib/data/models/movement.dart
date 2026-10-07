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

  /// Location corrected during an asset audit (completes at once).
  static const auditCorrection = 'Audit Correction';
}

/// A "From" or "To" card: name plus two address lines.
class MovePlace {
  const MovePlace(this.name, [this.line1, this.line2, this.assetLocation]);

  /// A department or person: the custodian changes, the asset stays where it is.
  const MovePlace.party(this.name, [this.line1]) : line2 = null, assetLocation = '';

  final String name;
  final String? line1;
  final String? line2;

  /// The asset's new location text when the move completes ('' = unchanged; null = the joined lines).
  final String? assetLocation;

  List<String> get lines => [?line1, ?line2];
}

/// Why an asset is transferred (Transfer → Details).
const moveReasons = ['Department Transfer', 'Repair', 'Project', 'Return', 'Other'];

/// Condition options at check-in / return.
const moveConditions = ['Good', 'Fair', 'Damaged', 'Needs Repair'];

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
    this.condition,
    this.photos = const [],
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

  /// Condition recorded at check-in / return.
  final String? condition;
  final List<String> photos;

  bool get isOpen => status == MoveStatus.pending || status == MoveStatus.approved || status == MoveStatus.inTransit;

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
    condition: condition,
    photos: photos,
  );
}
