abstract final class DocType {
  static const manual = 'Manual';
  static const warranty = 'Warranty';
  static const certificate = 'Certificate';
  static const maintenance = 'Maintenance';
  static const photo = 'Photo';
  static const serviceReport = 'Service Report';
  static const invoice = 'Invoice';
  static const drawing = 'Drawing';

  static const all = [manual, warranty, certificate, maintenance, photo, serviceReport, invoice, drawing];

  /// Tab bucket: Manuals, Warranty, Certificates or Others.
  static String bucket(String type) => switch (type) {
    manual => 'Manuals',
    warranty => 'Warranty',
    certificate => 'Certificates',
    _ => 'Others',
  };
}

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

  bool get isImage => name.toLowerCase().endsWith('.jpg') || name.toLowerCase().endsWith('.png');
  bool get isPdf => name.toLowerCase().endsWith('.pdf');
  String get sizeLabel => '${sizeMb.toStringAsFixed(1)} MB';

  AssetDocument copyWith({
    String? name,
    String? type,
    String? category,
    String? version,
    String? description,
    DateTime? expiry,
  }) => AssetDocument(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    assetId: assetId,
    sizeMb: sizeMb,
    uploadedAt: uploadedAt,
    uploadedBy: uploadedBy,
    category: category ?? this.category,
    version: version ?? this.version,
    description: description ?? this.description,
    expiry: expiry ?? this.expiry,
    filePath: filePath,
  );
}

/// Org-wide document figures (summary).
class DocumentSummary {
  const DocumentSummary({
    required this.byBucket,
    required this.expiringSoon,
    required this.compliant,
    required this.pending,
  });

  /// Manuals, Warranty, Certificates, Others.
  final Map<String, int> byBucket;
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
