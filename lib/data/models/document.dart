abstract final class DocType {
  static const manual = 'Manual';
  static const warranty = 'Warranty';
  static const certificate = 'Certificate';
  static const maintenance = 'Maintenance';
  static const photo = 'Photo';
  static const serviceReport = 'Service Report';
  static const invoice = 'Invoice';
  static const drawing = 'Drawing';
  static const contract = 'Contract / AMC';
  static const insurance = 'Insurance';
  static const other = 'Other';

  static const all = [
    manual,
    warranty,
    certificate,
    maintenance,
    photo,
    serviceReport,
    invoice,
    drawing,
    contract,
    insurance,
    other,
  ];

  /// Add Document type dropdown.
  static const uploadTypes = [manual, warranty, certificate, maintenance, photo, serviceReport, invoice, other];

  /// Types that carry an expiry date.
  static bool expires(String type) => type == warranty || type == certificate || type == contract || type == insurance;

  /// Tab bucket: Manuals, Warranty, Certificates or Others.
  static String bucket(String type) => switch (type) {
    manual => 'Manuals',
    warranty => 'Warranty',
    certificate => 'Certificates',
    _ => 'Others',
  };
}

/// One stored version of a document (Versions section).
class DocVersion {
  const DocVersion({
    required this.version,
    required this.at,
    required this.by,
    required this.sizeMb,
    this.filePath,
    this.note,
  });

  final String version;
  final DateTime at;
  final String by;
  final double sizeMb;
  final String? filePath;
  final String? note;
}

/// Expiry state, from [DemoClock]: expiring within 30 days, expired, or valid beyond 30 days.
enum ExpiryState { none, valid, expiring, expired }

const expiringWithinDays = 30;

/// Categories offered on Add Document / Edit.
const docCategories = [
  'Operation Manual',
  'Service Manual',
  'Warranty Certificate',
  'Compliance Certificate',
  'Calibration Certificate',
  'Maintenance Plan',
  'Service Report',
  'Site Photo',
  'Purchase Invoice',
  'Other',
];

class AssetDocument {
  const AssetDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.assetId,
    required this.sizeMb,
    required this.uploadedAt,
    required this.uploadedBy,
    this.category,
    this.version,
    this.description = '',
    this.expiry,
    this.filePath,
    this.versions = const [],
    this.pendingReview = false,
  });

  final String id;
  final String name;
  final String type;
  final String assetId;
  final String? category;
  final String? version;
  final double sizeMb;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String description;

  /// Null = no expiry.
  final DateTime? expiry;

  /// Bundled asset ('assets/docs/…') or picked file path, used by "View".
  final String? filePath;

  /// Every stored version, newest first; the current one is [version].
  final List<DocVersion> versions;

  /// Waiting for review (Pending tile).
  final bool pendingReview;

  String get extension => name.contains('.') ? name.split('.').last.toLowerCase() : '';

  bool get isImage => ['jpg', 'jpeg', 'png'].contains(extension);
  bool get isPdf => name.toLowerCase().endsWith('.pdf');
  String get sizeLabel => '${sizeMb.toStringAsFixed(1)} MB';

  AssetDocument copyWith({
    String? name,
    String? type,
    String? category,
    String? version,
    String? description,
    DateTime? expiry,
    bool clearExpiry = false,
    double? sizeMb,
    String? filePath,
    DateTime? uploadedAt,
    String? uploadedBy,
    List<DocVersion>? versions,
    bool? pendingReview,
  }) => AssetDocument(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    assetId: assetId,
    sizeMb: sizeMb ?? this.sizeMb,
    uploadedAt: uploadedAt ?? this.uploadedAt,
    uploadedBy: uploadedBy ?? this.uploadedBy,
    category: category ?? this.category,
    version: version ?? this.version,
    description: description ?? this.description,
    expiry: clearExpiry ? null : expiry ?? this.expiry,
    filePath: filePath ?? this.filePath,
    versions: versions ?? this.versions,
    pendingReview: pendingReview ?? this.pendingReview,
  );
}

/// Org-wide document figures (summary). Expiring / compliant / pending are the counts for documents
/// that have no detailed record here; the state adds the detailed documents (see DocumentsState).
class DocumentSummary {
  const DocumentSummary({
    required this.byBucket,
    required this.expiringSoon,
    required this.compliant,
    required this.pending,
  });

  /// Manuals, Warranty, Certificates, Others.
  final Map<String, int> byBucket;

  /// Undetailed documents only.
  final int expiringSoon;
  final int compliant;
  final int pending;

  int get total => byBucket.values.fold(0, (a, b) => a + b);

  DocumentSummary copyWith({Map<String, int>? byBucket, int? pending}) => DocumentSummary(
    byBucket: byBucket ?? this.byBucket,
    expiringSoon: expiringSoon,
    compliant: compliant,
    pending: pending ?? this.pending,
  );
}
