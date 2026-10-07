abstract final class AuditStatus {
  static const inProgress = 'In Progress';
  static const pending = 'Pending';
  static const paused = 'Paused';
  static const completed = 'Completed';
}

abstract final class AuditResult {
  static const verified = 'Verified';
  static const wrongLocation = 'Wrong Location';
  static const notFound = 'Not Found';
  static const unregistered = 'Unregistered';

  static const all = [verified, wrongLocation, notFound, unregistered];
}

/// Condition options on the Asset Found screen.
const auditConditions = ['Good', 'Fair', 'Poor', 'Damaged'];

/// How the asset was identified during the audit (the Tag ID label shows the scanned technology).
abstract final class AuditMethod {
  static const qr = 'QR';
  static const barcode = 'Barcode';
  static const rfid = 'RFID';
  static const search = 'Search';
  static const manual = 'Manual Entry';
  static const multiScan = 'Multi Scan';
  static const auto = 'Audit completion';
}

class AuditEntry {
  const AuditEntry({
    required this.assetId,
    required this.result,
    required this.at,
    this.location,
    this.expectedLocation,
    this.condition,
    this.remarks,
    this.photos = const [],
    this.method,
    this.by,
    this.description,
    this.locationUpdated = false,
  });

  /// Asset ID, or a temporary tag for an unregistered asset.
  final String assetId;
  final String result;
  final DateTime at;

  /// Where the asset was found (scanned location).
  final String? location;

  /// The registered location at the time of the audit.
  final String? expectedLocation;
  final String? condition;
  final String? remarks;
  final List<String> photos;
  final String? method;
  final String? by;

  /// What an unregistered asset is ("Portable welding set").
  final String? description;

  /// The asset's location was changed to [location] (a movement record was added).
  final bool locationUpdated;
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
    this.auditorIds = const [],
    this.scopeLocations = const [],
    this.scopeCategories = const [],
    this.blindCount = false,
    this.verified = 0,
    this.wrongLocation = 0,
    this.notFound = 0,
    this.unregistered = 0,
    this.entries = const [],
    this.imagePath,
    this.completedAt,
  });

  final String id;
  final String name;
  final String site;
  final DateTime start;
  final DateTime end;
  final int totalAssets;
  final String status;

  /// Lead auditor (creator).
  final String auditorId;

  /// Further auditors.
  final List<String> auditorIds;

  /// Buildings / areas in scope (empty = whole site) and asset categories (empty = all).
  final List<String> scopeLocations;
  final List<String> scopeCategories;

  /// Blind count: auditors do not see the registered location / custodian.
  final bool blindCount;

  /// Result counts: summary figures that include the sample [entries]; every new entry moves them.
  final int verified;
  final int wrongLocation;
  final int notFound;
  final int unregistered;
  final List<AuditEntry> entries;
  final String? imagePath;
  final DateTime? completedAt;

  int get done => verified + wrongLocation + notFound + unregistered;
  int get remaining => totalAssets - done < 0 ? 0 : totalAssets - done;
  double get progress => totalAssets == 0 ? 0 : (done / totalAssets).clamp(0, 1).toDouble();

  bool isAssignedTo(String userId) => auditorId == userId || auditorIds.contains(userId);
  List<String> get allAuditors => [auditorId, ...auditorIds.where((a) => a != auditorId)];

  int count(String result) => switch (result) {
    AuditResult.verified => verified,
    AuditResult.wrongLocation => wrongLocation,
    AuditResult.notFound => notFound,
    _ => unregistered,
  };

  List<AuditEntry> entriesFor(String result) => entries.where((e) => e.result == result).toList();

  AuditEntry? entryFor(String assetId) {
    for (final e in entries) {
      if (e.assetId == assetId) return e;
    }
    return null;
  }

  Audit copyWith({
    String? status,
    int? totalAssets,
    int? verified,
    int? wrongLocation,
    int? notFound,
    int? unregistered,
    List<AuditEntry>? entries,
    DateTime? completedAt,
  }) {
    return Audit(
      id: id,
      name: name,
      site: site,
      start: start,
      end: end,
      totalAssets: totalAssets ?? this.totalAssets,
      status: status ?? this.status,
      auditorId: auditorId,
      auditorIds: auditorIds,
      scopeLocations: scopeLocations,
      scopeCategories: scopeCategories,
      blindCount: blindCount,
      verified: verified ?? this.verified,
      wrongLocation: wrongLocation ?? this.wrongLocation,
      notFound: notFound ?? this.notFound,
      unregistered: unregistered ?? this.unregistered,
      entries: entries ?? this.entries,
      imagePath: imagePath,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
