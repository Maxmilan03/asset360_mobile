/// Typed models of the Asset service (A360.Asset.Api, docs/backend_ref/Services/Asset/Api/…/Contracts),
/// field for field, camelCase JSON names. Registrations and drafts use the existing
/// [AssetRegistration] model (lib/data/models/asset_registration.dart).
library;

import 'package:asset360_mobile/data/api/assets/json_read.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';

export 'package:asset360_mobile/data/models/asset_registration.dart';

// ------------------------------------------------------------------ list

/// AssetListItemResponse: one row of GET /api/asset-registrations.
class AssetListItem {
  const AssetListItem({
    required this.id,
    required this.assetRegistrationId,
    this.assetName,
    this.assetTag,
    this.imageUrl,
    this.category,
    this.assetType,
    this.siteName,
    this.buildingName,
    this.floorName,
    this.zoneName,
    this.roomName,
    this.locationPath,
    this.custodianUserId,
    this.custodianName,
    this.department,
    this.status,
    this.criticality,
    this.manufacturer,
    this.nextMaintenanceDate,
    this.createdAt,
  });

  final String id;
  final String assetRegistrationId;
  final String? assetName, assetTag, imageUrl, category, assetType;
  final String? siteName, buildingName, floorName, zoneName, roomName, locationPath;
  final String? custodianUserId, custodianName, department, status, criticality, manufacturer;
  final DateTime? nextMaintenanceDate, createdAt;

  /// Name, else tag, else the registration ID.
  String get title => assetName ?? assetTag ?? assetRegistrationId;

  factory AssetListItem.fromJson(Object? json) {
    final j = jMap(json);
    return AssetListItem(
      id: jStr(j['id']) ?? '',
      assetRegistrationId: jStr(j['assetRegistrationId']) ?? '',
      assetName: jStr(j['assetName']),
      assetTag: jStr(j['assetTag']),
      imageUrl: jStr(j['imageUrl']),
      category: jStr(j['category']),
      assetType: jStr(j['assetType']),
      siteName: jStr(j['siteName']),
      buildingName: jStr(j['buildingName']),
      floorName: jStr(j['floorName']),
      zoneName: jStr(j['zoneName']),
      roomName: jStr(j['roomName']),
      locationPath: jStr(j['locationPath']),
      custodianUserId: jStr(j['custodianUserId']),
      custodianName: jStr(j['custodianName']),
      department: jStr(j['department']),
      status: jStr(j['status']),
      criticality: jStr(j['criticality']),
      manufacturer: jStr(j['manufacturer']),
      nextMaintenanceDate: jDate(j['nextMaintenanceDate']),
      createdAt: jDate(j['createdAt']),
    );
  }

  /// The row for an asset read in full (lookup / detail).
  factory AssetListItem.fromRegistration(AssetRegistration r) {
    final b = r.basicInformation, c = r.classification;
    final l = r.locationAssignment.location, a = r.locationAssignment.assignment;
    return AssetListItem(
      id: r.id ?? '',
      assetRegistrationId: r.assetRegistrationId,
      assetName: b.assetName,
      assetTag: b.assetTag,
      imageUrl: b.images.firstOrNull,
      category: c.category,
      assetType: c.assetType,
      siteName: l.siteName,
      buildingName: l.buildingName,
      floorName: l.floorName,
      zoneName: l.zoneName,
      roomName: l.roomName,
      locationPath: l.locationPath,
      custodianUserId: a.assignedToUserId,
      custodianName: a.assignedToName,
      department: c.department,
      status: b.status,
      criticality: c.criticality,
      manufacturer: r.purchaseWarranty.purchase.manufacturer,
      nextMaintenanceDate: r.additionalInformation.operational.nextMaintenanceDate,
      createdAt: r.createdAt,
    );
  }
}

/// AssetStatusSummary: the status cards. Counted WITHOUT the status filter (the cards stay put
/// while a status is selected); statuses other than the four named ones are in [other].
class AssetStatusSummary {
  const AssetStatusSummary({
    this.total = 0,
    this.active = 0,
    this.underMaintenance = 0,
    this.inRepair = 0,
    this.disposed = 0,
    this.other = 0,
  });

  final int total, active, underMaintenance, inRepair, disposed, other;

  static const empty = AssetStatusSummary();

  factory AssetStatusSummary.fromJson(Object? json) {
    final j = jMap(json);
    return AssetStatusSummary(
      total: jInt(j['total']) ?? 0,
      active: jInt(j['active']) ?? 0,
      underMaintenance: jInt(j['underMaintenance']) ?? 0,
      inRepair: jInt(j['inRepair']) ?? 0,
      disposed: jInt(j['disposed']) ?? 0,
      other: jInt(j['other']) ?? 0,
    );
  }
}

/// AssetRegistrationListResponse.
class AssetListPage {
  const AssetListPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.summary,
  });

  final List<AssetListItem> items;
  final int totalCount, page, pageSize;
  final AssetStatusSummary summary;

  bool get hasMore => page * pageSize < totalCount;

  factory AssetListPage.fromJson(Object? json) {
    final j = jMap(json);
    return AssetListPage(
      items: [for (final i in jList(j['items'])) AssetListItem.fromJson(i)],
      totalCount: jInt(j['totalCount']) ?? 0,
      page: jInt(j['page']) ?? 1,
      pageSize: jInt(j['pageSize']) ?? 20,
      summary: AssetStatusSummary.fromJson(j['summary']),
    );
  }
}

/// Query of GET /api/asset-registrations. Filters match exactly (the values of /filters).
class AssetListQuery {
  const AssetListQuery({
    this.search,
    this.category,
    this.assetType,
    this.status,
    this.locationId,
    this.department,
    this.custodianUserId,
    this.criticality,
    this.manufacturer,
    this.condition,
    this.sortBy,
    this.sortDirection,
  });

  final String? search, category, assetType, status, locationId, department, custodianUserId;
  final String? criticality, manufacturer, condition;

  /// One of [AssetSortKeys]; null = the server default (createdAt, newest first).
  final String? sortBy;

  /// "asc" or "desc".
  final String? sortDirection;

  static const pageSize = 20;

  Map<String, dynamic> toQuery({int page = 1, int pageSize = pageSize}) => {
    'search': ?jStr(search?.trim()),
    'category': ?category,
    'assetType': ?assetType,
    'status': ?status,
    'locationId': ?locationId,
    'department': ?department,
    'custodianUserId': ?custodianUserId,
    'criticality': ?criticality,
    'manufacturer': ?manufacturer,
    'condition': ?condition,
    'sortBy': ?sortBy,
    'sortDirection': ?sortDirection,
    'page': page,
    'pageSize': pageSize,
  };

  /// Number of filters in use (search and sort not counted).
  int get filterCount => [
    category,
    assetType,
    status,
    locationId,
    department,
    custodianUserId,
    criticality,
    manufacturer,
    condition,
  ].nonNulls.length;

  AssetListQuery copyWith({
    String? Function()? search,
    String? Function()? category,
    String? Function()? assetType,
    String? Function()? status,
    String? Function()? locationId,
    String? Function()? department,
    String? Function()? custodianUserId,
    String? Function()? criticality,
    String? Function()? manufacturer,
    String? Function()? condition,
    String? Function()? sortBy,
    String? Function()? sortDirection,
  }) => AssetListQuery(
    search: search == null ? this.search : search(),
    category: category == null ? this.category : category(),
    assetType: assetType == null ? this.assetType : assetType(),
    status: status == null ? this.status : status(),
    locationId: locationId == null ? this.locationId : locationId(),
    department: department == null ? this.department : department(),
    custodianUserId: custodianUserId == null ? this.custodianUserId : custodianUserId(),
    criticality: criticality == null ? this.criticality : criticality(),
    manufacturer: manufacturer == null ? this.manufacturer : manufacturer(),
    condition: condition == null ? this.condition : condition(),
    sortBy: sortBy == null ? this.sortBy : sortBy(),
    sortDirection: sortDirection == null ? this.sortDirection : sortDirection(),
  );

  /// Same filters and search, without the sort (for "is anything filtered").
  AssetListQuery get unfiltered => AssetListQuery(sortBy: sortBy, sortDirection: sortDirection);

  @override
  bool operator ==(Object other) => other is AssetListQuery && _key == other._key;

  @override
  int get hashCode => _key.hashCode;

  String get _key => toQuery().toString();
}

/// The backend's sortBy keys (AssetRegistrationRepository.SortFields), with a label.
abstract final class AssetSortKeys {
  static const all = <String, String>{
    'createdAt': 'Date added',
    'assetName': 'Asset name',
    'assetTag': 'Asset tag',
    'category': 'Category',
    'assetType': 'Asset type',
    'location': 'Location',
    'custodian': 'Custodian',
    'status': 'Status',
    'criticality': 'Criticality',
    'nextMaintenance': 'Next maintenance',
  };
}

// ------------------------------------------------------------------ filters

/// AssetListFilterOptionsResponse (GET /api/asset-registrations/filters).
class AssetListFilters {
  const AssetListFilters({
    this.categories = const [],
    this.assetTypes = const [],
    this.statuses = const [],
    this.locations = const [],
    this.departments = const [],
    this.custodians = const [],
    this.criticalities = const [],
    this.manufacturers = const [],
    this.conditions = const [],
  });

  final List<String> categories;
  final List<AssetTypeFilterOption> assetTypes;
  final List<String> statuses;
  final List<AssetLocationFilterOption> locations;
  final List<String> departments;
  final List<AssetCustodianFilterOption> custodians;
  final List<String> criticalities, manufacturers, conditions;

  factory AssetListFilters.fromJson(Object? json) {
    final j = jMap(json);
    return AssetListFilters(
      categories: jStrings(j['categories']),
      assetTypes: [for (final t in jList(j['assetTypes'])) ?AssetTypeFilterOption.fromJson(t)],
      statuses: jStrings(j['statuses']),
      locations: [for (final l in jList(j['locations'])) ?AssetLocationFilterOption.fromJson(l)],
      departments: jStrings(j['departments']),
      custodians: [for (final c in jList(j['custodians'])) ?AssetCustodianFilterOption.fromJson(c)],
      criticalities: jStrings(j['criticalities']),
      manufacturers: jStrings(j['manufacturers']),
      conditions: jStrings(j['conditions']),
    );
  }
}

class AssetTypeFilterOption {
  const AssetTypeFilterOption(this.assetType, this.category);

  final String assetType;
  final String? category;

  static AssetTypeFilterOption? fromJson(Object? json) {
    final j = jMap(json);
    final t = jStr(j['assetType']);
    return t == null ? null : AssetTypeFilterOption(t, jStr(j['category']));
  }
}

class AssetCustodianFilterOption {
  const AssetCustodianFilterOption(this.userId, this.name);

  final String userId;
  final String? name;

  static AssetCustodianFilterOption? fromJson(Object? json) {
    final j = jMap(json);
    final id = jStr(j['userId']);
    return id == null ? null : AssetCustodianFilterOption(id, jStr(j['name']));
  }
}

/// One location level used by an asset; [id] is sent as the list's locationId (matches at or below).
class AssetLocationFilterOption {
  const AssetLocationFilterOption({required this.id, required this.name, required this.level, required this.path});

  final String id, name, level, path;

  static AssetLocationFilterOption? fromJson(Object? json) {
    final j = jMap(json);
    final id = jStr(j['id']), name = jStr(j['name']);
    if (id == null || name == null) return null;
    return AssetLocationFilterOption(id: id, name: name, level: jStr(j['level']) ?? '', path: jStr(j['path']) ?? name);
  }
}

// ------------------------------------------------------------------ lookup

/// AssetLookupResponse (GET /api/asset-registrations/lookup?code=&type=).
class AssetLookupResult {
  const AssetLookupResult({required this.code, required this.matchedBy, required this.asset});

  final String code;

  /// assetTag | barcode | rfid | nfc | assetRegistrationId.
  final String matchedBy;
  final AssetRegistration asset;

  factory AssetLookupResult.fromJson(Object? json) {
    final j = jMap(json);
    return AssetLookupResult(
      code: jStr(j['code']) ?? '',
      matchedBy: jStr(j['matchedBy']) ?? 'assetRegistrationId',
      asset: AssetRegistration.fromJson(jMap(j['asset'])),
    );
  }
}

/// The lookup's `type` values (AssetLookupCodeTypes).
abstract final class LookupCodeType {
  static const assetTag = 'assetTag';
  static const barcode = 'barcode';
  static const qr = 'qr';
  static const rfid = 'rfid';
  static const nfc = 'nfc';
  static const assetRegistrationId = 'assetRegistrationId';
}

// ------------------------------------------------------------------ paged lists

/// `{items, totalCount, page, pageSize}` (images, documents, condition assessments, components).
class PagedResult<T> {
  const PagedResult({required this.items, required this.totalCount, this.page = 1, this.pageSize = 10});

  final List<T> items;
  final int totalCount, page, pageSize;

  factory PagedResult.fromJson(Object? json, T Function(Object?) item) {
    final j = jMap(json);
    final items = [for (final i in jItems(json)) item(i)];
    return PagedResult(
      items: items,
      totalCount: jInt(j['totalCount']) ?? items.length,
      page: jInt(j['page']) ?? 1,
      pageSize: jInt(j['pageSize']) ?? items.length,
    );
  }
}

// ------------------------------------------------------------------ images

/// AssetImageResponse.
class AssetImageRecord {
  const AssetImageRecord({
    required this.id,
    required this.assetRegistrationId,
    required this.imageName,
    required this.imageType,
    required this.fileName,
    required this.fileUrl,
    this.tags = const [],
    this.location,
    this.remarks,
    this.description,
    this.contentType,
    this.fileSize,
    this.width,
    this.height,
    this.resolution,
    this.uploadedBy,
    this.uploadDate,
  });

  final String id, assetRegistrationId, imageName, imageType, fileName, fileUrl;
  final List<String> tags;
  final String? location, remarks, description, contentType, resolution, uploadedBy;
  final int? fileSize, width, height;
  final DateTime? uploadDate;

  factory AssetImageRecord.fromJson(Object? json) {
    final j = jMap(json);
    return AssetImageRecord(
      id: jStr(j['id']) ?? '',
      assetRegistrationId: jStr(j['assetRegistrationId']) ?? '',
      imageName: jStr(j['imageName']) ?? '',
      imageType: jStr(j['imageType']) ?? '',
      fileName: jStr(j['fileName']) ?? '',
      fileUrl: jStr(j['fileUrl']) ?? '',
      tags: jStrings(j['tags']),
      location: jStr(j['location']),
      remarks: jStr(j['remarks']),
      description: jStr(j['description']),
      contentType: jStr(j['contentType']),
      fileSize: jInt(j['fileSize']),
      width: jInt(j['width']),
      height: jInt(j['height']),
      resolution: jStr(j['resolution']),
      uploadedBy: jStr(j['uploadedBy']),
      uploadDate: jDate(j['uploadDate']),
    );
  }
}

/// AssetImageFileRequest: one uploaded file.
class AssetImageFile {
  const AssetImageFile({
    required this.fileName,
    required this.fileUrl,
    this.imageName,
    this.contentType,
    this.fileSize,
    this.width,
    this.height,
  });

  final String fileName, fileUrl;
  final String? imageName, contentType;
  final int? fileSize, width, height;

  Map<String, dynamic> toJson() => {
    'imageName': imageName,
    'fileName': fileName,
    'fileUrl': fileUrl,
    'contentType': contentType,
    'fileSize': fileSize,
    'width': width,
    'height': height,
  };
}

/// CreateAssetImagesRequest (POST /api/asset-images). ImageType is required by the server.
class CreateAssetImagesRequest {
  const CreateAssetImagesRequest({
    required this.assetRegistrationIds,
    required this.images,
    required this.imageType,
    this.tags = const [],
    this.location,
    this.remarks,
    this.description,
  });

  final List<String> assetRegistrationIds;
  final List<AssetImageFile> images;
  final String imageType;
  final List<String> tags;
  final String? location, remarks, description;

  Map<String, dynamic> toJson() => {
    'assetRegistrationIds': assetRegistrationIds,
    'images': [for (final i in images) i.toJson()],
    'imageType': imageType,
    'tags': tags,
    'location': location,
    'remarks': remarks,
    'description': description,
  };
}

// ------------------------------------------------------------------ documents

/// AssetDocumentResponse.
class AssetDocumentRecord {
  const AssetDocumentRecord({
    required this.id,
    required this.assetRegistrationId,
    required this.documentName,
    required this.documentType,
    required this.lifecycleStage,
    required this.version,
    required this.fileName,
    required this.fileUrl,
    this.expiryDate,
    this.description,
    this.tags = const [],
    this.status,
    this.contentType,
    this.fileSize,
    this.uploadedBy,
    this.uploadDate,
  });

  final String id, assetRegistrationId, documentName, documentType, lifecycleStage, version, fileName, fileUrl;
  final DateTime? expiryDate, uploadDate;
  final String? description, status, contentType, uploadedBy;
  final List<String> tags;
  final int? fileSize;

  factory AssetDocumentRecord.fromJson(Object? json) {
    final j = jMap(json);
    return AssetDocumentRecord(
      id: jStr(j['id']) ?? '',
      assetRegistrationId: jStr(j['assetRegistrationId']) ?? '',
      documentName: jStr(j['documentName']) ?? '',
      documentType: jStr(j['documentType']) ?? '',
      lifecycleStage: jStr(j['lifecycleStage']) ?? '',
      version: jStr(j['version']) ?? '',
      fileName: jStr(j['fileName']) ?? '',
      fileUrl: jStr(j['fileUrl']) ?? '',
      expiryDate: jDate(j['expiryDate']),
      description: jStr(j['description']),
      tags: jStrings(j['tags']),
      status: jStr(j['status']),
      contentType: jStr(j['contentType']),
      fileSize: jInt(j['fileSize']),
      uploadedBy: jStr(j['uploadedBy']),
      uploadDate: jDate(j['uploadDate']),
    );
  }
}

/// CreateAssetDocumentRequest (POST /api/asset-documents). DocumentName, DocumentType,
/// LifecycleStage and Version are required by the server; Status is Active / Inactive.
class CreateAssetDocumentRequest {
  const CreateAssetDocumentRequest({
    required this.assetRegistrationIds,
    required this.documentName,
    required this.documentType,
    required this.lifecycleStage,
    required this.version,
    required this.fileName,
    required this.fileUrl,
    this.expiryDate,
    this.description,
    this.tags = const [],
    this.status,
    this.contentType,
    this.fileSize,
  });

  final List<String> assetRegistrationIds;
  final String documentName, documentType, lifecycleStage, version, fileName, fileUrl;
  final DateTime? expiryDate;
  final String? description, status, contentType;
  final List<String> tags;
  final int? fileSize;

  Map<String, dynamic> toJson() => {
    'assetRegistrationIds': assetRegistrationIds,
    'documentName': documentName,
    'documentType': documentType,
    'lifecycleStage': lifecycleStage,
    'version': version,
    'expiryDate': jDay(expiryDate),
    'description': description,
    'tags': tags,
    'status': status,
    'fileName': fileName,
    'fileUrl': fileUrl,
    'contentType': contentType,
    'fileSize': fileSize,
  };
}

/// Upload limits of the Asset service forms (AssetImageFiles / AssetDocumentFiles) and the Media
/// service (MediaFileStorageService: only jpg, jpeg, png, webp, pdf).
abstract final class AssetFileRules {
  static const mediaExtensions = {'jpg', 'jpeg', 'png', 'webp', 'pdf'};
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const maxImageBytes = 20 * 1024 * 1024;
  static const maxDocumentBytes = 25 * 1024 * 1024;

  /// Media categories (the folder under /uploads/).
  static const imageCategory = 'asset-images';
  static const documentCategory = 'asset-documents';

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  /// Null when the file can be uploaded, else a message for the user.
  static String? check(String fileName, {int? size, bool imageOnly = false}) {
    final ext = extensionOf(fileName);
    final allowed = imageOnly ? imageExtensions : mediaExtensions;
    if (!allowed.contains(ext)) {
      return imageOnly
          ? 'Only JPG, PNG or WEBP photos can be uploaded.'
          : 'Only JPG, PNG, WEBP or PDF files can be uploaded.';
    }
    final max = imageOnly || ext != 'pdf' ? maxImageBytes : maxDocumentBytes;
    if (size != null && size > max) return 'The file is larger than ${max ~/ (1024 * 1024)} MB.';
    return null;
  }

  static String contentTypeOf(String fileName) => switch (extensionOf(fileName)) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

// ------------------------------------------------------------------ components

/// AssetComponentNodeResponse (GET …/{assetRegistrationId}/components/tree).
class AssetComponentNode {
  const AssetComponentNode({
    required this.id,
    required this.componentName,
    required this.componentTag,
    this.status,
    this.lifecyclePercent,
    this.expectedReplacementDate,
    this.children = const [],
  });

  final String id, componentName, componentTag;
  final String? status;
  final double? lifecyclePercent;
  final DateTime? expectedReplacementDate;
  final List<AssetComponentNode> children;

  int get count => 1 + children.fold(0, (n, c) => n + c.count);

  factory AssetComponentNode.fromJson(Object? json) {
    final j = jMap(json);
    return AssetComponentNode(
      id: jStr(j['id']) ?? '',
      componentName: jStr(j['componentName']) ?? '',
      componentTag: jStr(j['componentTag']) ?? '',
      status: jStr(j['status']),
      lifecyclePercent: jNum(j['lifecyclePercent']),
      expectedReplacementDate: jDate(j['expectedReplacementDate']),
      children: [for (final c in jList(j['children'])) AssetComponentNode.fromJson(c)],
    );
  }
}

// ------------------------------------------------------------------ condition

/// AssetConditionAssessmentResponse.
class AssetConditionAssessment {
  const AssetConditionAssessment({
    required this.id,
    required this.assetRegistrationId,
    required this.assessmentDate,
    required this.assessedBy,
    required this.overallCondition,
    required this.healthScore,
    this.physicalCondition,
    this.performance,
    this.safety,
    this.remarks,
    this.createdAt,
  });

  final String id, assetRegistrationId, assessedBy, overallCondition;
  final DateTime? assessmentDate, createdAt;
  final double healthScore;
  final String? physicalCondition, performance, safety, remarks;

  factory AssetConditionAssessment.fromJson(Object? json) {
    final j = jMap(json);
    return AssetConditionAssessment(
      id: jStr(j['id']) ?? '',
      assetRegistrationId: jStr(j['assetRegistrationId']) ?? '',
      assessmentDate: jDate(j['assessmentDate']),
      assessedBy: jStr(j['assessedBy']) ?? '',
      overallCondition: jStr(j['overallCondition']) ?? '',
      healthScore: jNum(j['healthScore']) ?? 0,
      physicalCondition: jStr(j['physicalCondition']),
      performance: jStr(j['performance']),
      safety: jStr(j['safety']),
      remarks: jStr(j['remarks']),
      createdAt: jDate(j['createdAt']),
    );
  }
}

/// CreateAssetConditionAssessmentRequest (POST /api/asset-condition-assessments). Required:
/// assetRegistrationId, assessmentDate (not in the future), overallCondition (a rating),
/// healthScore 0–100. AssessedBy defaults to the signed-in user on the server.
class CreateConditionAssessmentRequest {
  const CreateConditionAssessmentRequest({
    required this.assetRegistrationId,
    required this.assessmentDate,
    required this.overallCondition,
    required this.healthScore,
    this.assessedBy,
    this.physicalCondition,
    this.performance,
    this.safety,
    this.remarks,
  });

  final String assetRegistrationId;
  final DateTime assessmentDate;
  final String overallCondition;
  final double healthScore;
  final String? assessedBy, physicalCondition, performance, safety, remarks;

  Map<String, dynamic> toJson() => {
    'assetRegistrationId': assetRegistrationId,
    'assessmentDate': jDay(assessmentDate),
    'assessedBy': assessedBy,
    'overallCondition': overallCondition,
    'healthScore': healthScore,
    'physicalCondition': physicalCondition,
    'performance': performance,
    'safety': safety,
    'remarks': remarks,
  };
}

// ------------------------------------------------------------------ criticality

class AssetCriticalityCriterion {
  const AssetCriticalityCriterion({
    required this.name,
    required this.weight,
    this.score,
    this.weightedScore,
    this.justification,
  });

  final String name;
  final double weight;
  final double? score, weightedScore;
  final String? justification;

  factory AssetCriticalityCriterion.fromJson(Object? json) {
    final j = jMap(json);
    return AssetCriticalityCriterion(
      name: jStr(j['name']) ?? '',
      weight: jNum(j['weight']) ?? 0,
      score: jNum(j['score']),
      weightedScore: jNum(j['weightedScore']),
      justification: jStr(j['justification']),
    );
  }
}

/// AssetCriticalityResponse (GET /api/asset-criticality/current?assetRegistrationId=).
class AssetCriticalityAssessment {
  const AssetCriticalityAssessment({
    required this.id,
    required this.assetRegistrationId,
    required this.criticalityLevel,
    required this.criticalityScore,
    this.isCurrent = true,
    this.assessmentDate,
    this.validUntil,
    this.nextReviewDate,
    this.assessedBy,
    this.approvedBy,
    this.likelihood,
    this.consequence,
    this.criteria = const [],
    this.remarks,
  });

  final String id, assetRegistrationId, criticalityLevel;
  final double criticalityScore;
  final bool isCurrent;
  final DateTime? assessmentDate, validUntil, nextReviewDate;
  final String? assessedBy, approvedBy, likelihood, consequence, remarks;
  final List<AssetCriticalityCriterion> criteria;

  factory AssetCriticalityAssessment.fromJson(Object? json) {
    final j = jMap(json);
    return AssetCriticalityAssessment(
      id: jStr(j['id']) ?? '',
      assetRegistrationId: jStr(j['assetRegistrationId']) ?? '',
      criticalityLevel: jStr(j['criticalityLevel']) ?? '',
      criticalityScore: jNum(j['criticalityScore']) ?? 0,
      isCurrent: jBool(j['isCurrent'], orElse: true),
      assessmentDate: jDate(j['assessmentDate']),
      validUntil: jDate(j['validUntil']),
      nextReviewDate: jDate(j['nextReviewDate']),
      assessedBy: jStr(j['assessedBy']),
      approvedBy: jStr(j['approvedBy']),
      likelihood: jStr(j['likelihood']),
      consequence: jStr(j['consequence']),
      criteria: [for (final c in jList(j['criteria'])) AssetCriticalityCriterion.fromJson(c)],
      remarks: jStr(j['remarks']),
    );
  }
}

/// AssetCriticalityOptionsResponse (GET /api/asset-criticality/options).
class CriticalityOptions {
  const CriticalityOptions({
    this.likelihoodRatings = const [],
    this.consequenceRatings = const [],
    this.criticalityLevels = const [],
    this.criteria = const [],
  });

  final List<String> likelihoodRatings, consequenceRatings, criticalityLevels;

  /// Default criteria with weights (no score).
  final List<AssetCriticalityCriterion> criteria;

  factory CriticalityOptions.fromJson(Object? json) {
    final j = jMap(json);
    return CriticalityOptions(
      likelihoodRatings: jStrings(j['likelihoodRatings']),
      consequenceRatings: jStrings(j['consequenceRatings']),
      criticalityLevels: jStrings(j['criticalityLevels']),
      criteria: [for (final c in jList(j['criteria'])) AssetCriticalityCriterion.fromJson(c)],
    );
  }
}

// ------------------------------------------------------------------ categories, types, models

/// AssetCategoryResponse (GET /api/asset-categories, a bare array). Top-level categories have no
/// [parentCategoryId]; their children are the Sub Categories.
class AssetCategoryItem {
  const AssetCategoryItem({
    required this.id,
    required this.name,
    required this.code,
    this.parentCategoryId,
    this.parentCategoryName,
    this.description,
    this.status,
    this.imageUrl,
    this.customFields = const [],
    this.attributes = const [],
  });

  final String id, name, code;
  final String? parentCategoryId, parentCategoryName, description, status, imageUrl;
  final List<AssetCategoryCustomField> customFields;
  final List<AssetCategoryAttribute> attributes;

  bool get isTopLevel => parentCategoryId == null;

  factory AssetCategoryItem.fromJson(Object? json) {
    final j = jMap(json);
    return AssetCategoryItem(
      id: jStr(j['id']) ?? '',
      name: jStr(j['name']) ?? '',
      code: jStr(j['code']) ?? '',
      parentCategoryId: jStr(j['parentCategoryId']),
      parentCategoryName: jStr(j['parentCategoryName']),
      description: jStr(j['description']),
      status: jStr(j['status']),
      imageUrl: jStr(j['imageUrl']),
      customFields: [for (final f in jList(j['customFields'])) AssetCategoryCustomField.fromJson(f)],
      attributes: [for (final a in jList(j['attributes'])) AssetCategoryAttribute.fromJson(a)],
    );
  }
}

class AssetCategoryCustomField {
  const AssetCategoryCustomField({
    required this.id,
    required this.fieldName,
    required this.type,
    this.required = false,
  });

  final String id, fieldName, type;
  final bool required;

  factory AssetCategoryCustomField.fromJson(Object? json) {
    final j = jMap(json);
    return AssetCategoryCustomField(
      id: jStr(j['id']) ?? '',
      fieldName: jStr(j['fieldName']) ?? '',
      type: jStr(j['type']) ?? 'Text',
      required: jBool(j['required']),
    );
  }
}

class AssetCategoryAttribute {
  const AssetCategoryAttribute({required this.id, required this.attribute, this.unit, this.exampleValue});

  final String id, attribute;
  final String? unit, exampleValue;

  factory AssetCategoryAttribute.fromJson(Object? json) {
    final j = jMap(json);
    return AssetCategoryAttribute(
      id: jStr(j['id']) ?? '',
      attribute: jStr(j['attribute']) ?? '',
      unit: jStr(j['unit']),
      exampleValue: jStr(j['exampleValue']),
    );
  }
}

/// AssetCategoryTypeResponse (GET /api/asset-category-types?categoryId=, a bare array).
class AssetCategoryType {
  const AssetCategoryType({
    required this.id,
    required this.categoryId,
    required this.typeName,
    required this.typeCode,
    this.categoryName,
    this.description,
    this.status,
    this.imageUrl,
    this.modelCount = 0,
  });

  final String id, categoryId, typeName, typeCode;
  final String? categoryName, description, status, imageUrl;
  final int modelCount;

  factory AssetCategoryType.fromJson(Object? json) {
    final j = jMap(json);
    return AssetCategoryType(
      id: jStr(j['id']) ?? '',
      categoryId: jStr(j['categoryId']) ?? '',
      typeName: jStr(j['typeName']) ?? '',
      typeCode: jStr(j['typeCode']) ?? '',
      categoryName: jStr(j['categoryName']),
      description: jStr(j['description']),
      status: jStr(j['status']),
      imageUrl: jStr(j['imageUrl']),
      modelCount: jInt(j['modelCount']) ?? 0,
    );
  }
}

/// AssetModelResponse (GET /api/asset-models?assetTypeId=, a bare array).
class AssetModelItem {
  const AssetModelItem({
    required this.id,
    required this.assetTypeId,
    required this.modelName,
    required this.modelCode,
    required this.manufacturerName,
    this.assetTypeName,
    this.manufacturerId,
    this.status,
  });

  final String id, assetTypeId, modelName, modelCode, manufacturerName;
  final String? assetTypeName, manufacturerId, status;

  factory AssetModelItem.fromJson(Object? json) {
    final j = jMap(json);
    return AssetModelItem(
      id: jStr(j['id']) ?? '',
      assetTypeId: jStr(j['assetTypeId']) ?? '',
      modelName: jStr(j['modelName']) ?? '',
      modelCode: jStr(j['modelCode']) ?? '',
      manufacturerName: jStr(j['manufacturerName']) ?? '',
      assetTypeName: jStr(j['assetTypeName']),
      manufacturerId: jStr(j['manufacturerId']),
      status: jStr(j['status']),
    );
  }
}

// ------------------------------------------------------------------ registration options

/// AssetRegistrationOptionsResponse (GET /api/asset-registrations/options): the fixed dropdowns of
/// the five steps, by section → list name ("purchaseWarranty" → "currencies" → [...]).
class RegistrationOptions {
  const RegistrationOptions(this.sections);

  final Map<String, Map<String, List<String>>> sections;

  static const empty = RegistrationOptions({});

  /// The list [name] of [section] (camelCase as sent), empty when missing.
  List<String> list(String section, String name) => sections[section]?[name] ?? const [];

  // Step 1
  List<String> get statuses => list('basicInformation', 'statuses');
  // Step 2
  List<String> get functionPurposes => list('classification', 'functionPurposes');
  List<String> get taggingMethods => list('classification', 'taggingMethods');
  List<String> get complianceCategories => list('classification', 'complianceCategories');
  List<String> get lifecycleStages => list('classification', 'lifecycleStages');
  // Step 3
  List<String> get ownershipTypes => list('locationAssignment', 'ownershipTypes');
  // Step 4
  List<String> get quantityUnits => list('purchaseWarranty', 'quantityUnits');
  List<String> get currencies => list('purchaseWarranty', 'currencies');
  List<String> get paymentTerms => list('purchaseWarranty', 'paymentTerms');
  List<String> get procurementMethods => list('purchaseWarranty', 'procurementMethods');
  List<String> get warrantyTypes => list('purchaseWarranty', 'warrantyTypes');
  List<String> get warrantyPeriodUnits => list('purchaseWarranty', 'warrantyPeriodUnits');
  List<String> get supportCoverages => list('purchaseWarranty', 'supportCoverages');
  // Step 5
  List<String> additional(String name) => list('additionalInformation', name);

  factory RegistrationOptions.fromJson(Object? json) => RegistrationOptions({
    for (final MapEntry(:key, :value) in jMap(json).entries)
      if (value is Map)
        key: {
          for (final MapEntry(key: k, value: v) in value.entries)
            if (k is String && v is List) k: jStrings(v),
        },
  });
}
