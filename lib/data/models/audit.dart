abstract final class AuditStatus {
  static const inProgress = 'In Progress';
  static const pending = 'Pending';
  static const completed = 'Completed';
}

abstract final class AuditResult {
  static const verified = 'Verified';
  static const wrongLocation = 'Wrong Location';
  static const notFound = 'Not Found';
  static const unregistered = 'Unregistered';
}

class AuditEntry {
  const AuditEntry({
    required this.assetId,
    required this.result,
    required this.at,
    this.location,
    this.condition,
    this.remarks,
    this.photos = const [],
  });

  /// Asset ID, or a temporary tag for an unregistered asset.
  final String assetId;
  final String result;
  final DateTime at;
  final String? location;
  final String? condition;
  final String? remarks;
  final List<String> photos;
}

class Audit {
  const Audit({
    required this.id,
    required this.name,
    required this.site,
    required this.start,
    required this.end,
    required this.totalAssets,
    required this.status,
    required this.auditorId,
    this.verified = 0,
    this.wrongLocation = 0,
    this.notFound = 0,
    this.unregistered = 0,
    this.entries = const [],
    this.imagePath,
  });

  final String id;
  final String name;
  final String site;
  final DateTime start;
  final DateTime end;
  final int totalAssets;
  final String status;
  final String auditorId;

  /// Result counts (summary figures, incremented by new [entries]).
  final int verified;
  final int wrongLocation;
  final int notFound;
  final int unregistered;
  final List<AuditEntry> entries;
  final String? imagePath;

  int get done => verified + wrongLocation + notFound + unregistered;
  double get progress => totalAssets == 0 ? 0 : done / totalAssets;

  Audit copyWith({
    String? status,
    int? verified,
    int? wrongLocation,
    int? notFound,
    int? unregistered,
    List<AuditEntry>? entries,
  }) {
    return Audit(
      id: id,
      name: name,
      site: site,
      start: start,
      end: end,
      totalAssets: totalAssets,
      status: status ?? this.status,
      auditorId: auditorId,
      verified: verified ?? this.verified,
      wrongLocation: wrongLocation ?? this.wrongLocation,
      notFound: notFound ?? this.notFound,
      unregistered: unregistered ?? this.unregistered,
      entries: entries ?? this.entries,
      imagePath: imagePath,
    );
  }
}
