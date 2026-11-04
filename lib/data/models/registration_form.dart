import 'package:asset360_mobile/data/reference/asset_options.dart';

/// Register Asset form data, named and grouped like the backend request DTOs (swagger.json), so
/// each step maps 1:1 to a draft endpoint later:
///   step 1 [basicInformation]      → PUT /api/asset-registrations/drafts/{id}/basic-information     (AssetBasicInformationDto)
///   step 2 [classification]        → PUT …/classification          (AssetClassificationDto)
///   step 3 [locationAssignment]    → PUT …/location-assignment     (AssetLocationAssignmentDto)
///   step 4 [purchaseWarranty]      → PUT …/purchase-warranty       (AssetPurchaseWarrantyDto)
///   step 5 [additionalInformation] → PUT …/additional-information  (AssetAdditionalInformationDto)
/// The first save is POST /api/asset-registrations/drafts (CreateAssetRegistrationDraftRequest =
/// basicInformation + createdBy / clientId / tenantId). Each section's toJson() is that request body.
/// Fields are mutable: the form edits them in place.
class RegistrationForm {
  RegistrationForm({
    required this.draftId,
    AssetBasicInformation? basicInformation,
    AssetClassification? classification,
    AssetLocationAssignment? locationAssignment,
    AssetPurchaseWarranty? purchaseWarranty,
    AssetAdditionalInformation? additionalInformation,
    this.criticalityAssessment,
    this.savedAt,
    this.step = 0,
  }) : basicInformation = basicInformation ?? AssetBasicInformation(),
       classification = classification ?? AssetClassification(),
       locationAssignment = locationAssignment ?? AssetLocationAssignment(),
       purchaseWarranty = purchaseWarranty ?? AssetPurchaseWarranty(),
       additionalInformation = additionalInformation ?? AssetAdditionalInformation();

  /// Local draft key (becomes assetRegistrationId once the backend creates the draft).
  final String draftId;
  final AssetBasicInformation basicInformation;
  final AssetClassification classification;
  final AssetLocationAssignment locationAssignment;
  final AssetPurchaseWarranty purchaseWarranty;
  final AssetAdditionalInformation additionalInformation;

  /// Assess sheet ratings → POST /api/asset-criticality after the asset exists (not a draft step).
  CriticalityAssessment? criticalityAssessment;

  /// Last Save as Draft (DemoClock); null for a new form.
  DateTime? savedAt;

  /// Step the user was on when the draft was saved (0 … 5).
  int step;

  /// Criticality appears in steps 1 and 2 (both DTOs carry it); one value is kept in both.
  String? get criticality => basicInformation.criticality ?? classification.criticality;
  set criticality(String? v) {
    basicInformation.criticality = v;
    classification.criticality = v;
  }

  /// Title in My Drafts: name, else tag, else "Untitled asset".
  String get title => _orNull(basicInformation.assetName) ?? _orNull(basicInformation.assetTag) ?? 'Untitled asset';

  Map<String, dynamic> toJson() => {
    'draftId': draftId,
    'savedAt': savedAt?.toIso8601String(),
    'step': step,
    'basicInformation': basicInformation.toJson(),
    'classification': classification.toJson(),
    'locationAssignment': locationAssignment.toJson(),
    'purchaseWarranty': purchaseWarranty.toJson(),
    'additionalInformation': additionalInformation.toJson(),
    'criticalityAssessment': criticalityAssessment?.toJson(),
  };

  factory RegistrationForm.fromJson(Map<String, dynamic> j) => RegistrationForm(
    draftId: _str(j['draftId']) ?? 'draft',
    savedAt: _date(j['savedAt']),
    step: _int(j['step']) ?? 0,
    basicInformation: AssetBasicInformation.fromJson(_map(j['basicInformation'])),
    classification: AssetClassification.fromJson(_map(j['classification'])),
    locationAssignment: AssetLocationAssignment.fromJson(_map(j['locationAssignment'])),
    purchaseWarranty: AssetPurchaseWarranty.fromJson(_map(j['purchaseWarranty'])),
    additionalInformation: AssetAdditionalInformation.fromJson(_map(j['additionalInformation'])),
    criticalityAssessment: CriticalityAssessment.fromJson(j['criticalityAssessment']),
  );

  /// Deep copy (Save as Draft stores a snapshot, the form keeps editing its own).
  RegistrationForm copy() => RegistrationForm.fromJson(toJson());
}

/// AssetBasicInformationDto.
class AssetBasicInformation {
  AssetBasicInformation({
    this.assetName,
    this.assetTag,
    this.barcode,
    this.rfidTagId,
    this.model,
    this.manufacturer,
    this.serialNumber,
    this.status = AssetStatus.active,
    this.condition,
    this.criticality,
    this.description,
    List<String>? images,
  }) : images = images ?? [];

  String? assetName, assetTag, barcode, rfidTagId, model, manufacturer, serialNumber;
  String? status, condition, criticality, description;

  /// Photo paths; the first is the primary image.
  List<String> images;

  Map<String, dynamic> toJson() => {
    'assetName': assetName,
    'assetTag': assetTag,
    'barcode': barcode,
    'rfidTagId': rfidTagId,
    'model': model,
    'manufacturer': manufacturer,
    'serialNumber': serialNumber,
    'status': status,
    'condition': condition,
    'criticality': criticality,
    'description': description,
    'images': images,
  };

  factory AssetBasicInformation.fromJson(Map<String, dynamic> j) => AssetBasicInformation(
    assetName: _str(j['assetName']),
    assetTag: _str(j['assetTag']),
    barcode: _str(j['barcode']),
    rfidTagId: _str(j['rfidTagId']),
    model: _str(j['model']),
    manufacturer: _str(j['manufacturer']),
    serialNumber: _str(j['serialNumber']),
    status: _str(j['status']),
    condition: _str(j['condition']),
    criticality: _str(j['criticality']),
    description: _str(j['description']),
    images: _strings(j['images']),
  );
}

/// AssetClassificationDto.
class AssetClassification {
  AssetClassification({
    this.category,
    this.subCategory,
    this.assetType,
    this.assetSubType,
    this.functionPurpose,
    this.criticality,
    this.department,
    this.costCenter,
    this.businessUnit,
    this.taggingMethod,
    this.complianceCategory,
    this.lifecycleStage,
    List<String>? keywords,
  }) : keywords = keywords ?? [];

  String? category, subCategory, assetType, assetSubType, functionPurpose, criticality;
  String? department, costCenter, businessUnit, taggingMethod, complianceCategory, lifecycleStage;
  List<String> keywords;

  /// "Machinery & Equipment › Power Generation › Generator".
  List<String> get path => [?category, ?subCategory, ?assetType, ?assetSubType];

  Map<String, dynamic> toJson() => {
    'category': category,
    'subCategory': subCategory,
    'assetType': assetType,
    'assetSubType': assetSubType,
    'functionPurpose': functionPurpose,
    'criticality': criticality,
    'department': department,
    'costCenter': costCenter,
    'businessUnit': businessUnit,
    'taggingMethod': taggingMethod,
    'complianceCategory': complianceCategory,
    'lifecycleStage': lifecycleStage,
    'keywords': keywords,
  };

  factory AssetClassification.fromJson(Map<String, dynamic> j) => AssetClassification(
    category: _str(j['category']),
    subCategory: _str(j['subCategory']),
    assetType: _str(j['assetType']),
    assetSubType: _str(j['assetSubType']),
    functionPurpose: _str(j['functionPurpose']),
    criticality: _str(j['criticality']),
    department: _str(j['department']),
    costCenter: _str(j['costCenter']),
    businessUnit: _str(j['businessUnit']),
    taggingMethod: _str(j['taggingMethod']),
    complianceCategory: _str(j['complianceCategory']),
    lifecycleStage: _str(j['lifecycleStage']),
    keywords: _strings(j['keywords']),
  );
}

/// AssetLocationAssignmentDto = location + assignment.
class AssetLocationAssignment {
  AssetLocationAssignment({AssetLocation? location, AssetAssignment? assignment})
    : location = location ?? AssetLocation(),
      assignment = assignment ?? AssetAssignment();

  final AssetLocation location;
  final AssetAssignment assignment;

  Map<String, dynamic> toJson() => {'location': location.toJson(), 'assignment': assignment.toJson()};

  factory AssetLocationAssignment.fromJson(Map<String, dynamic> j) => AssetLocationAssignment(
    location: AssetLocation.fromJson(_map(j['location'])),
    assignment: AssetAssignment.fromJson(_map(j['assignment'])),
  );
}

/// AssetLocationDto. The app's location tree has names only, so the *Id fields stay null until
/// the location lookups come from the API.
class AssetLocation {
  AssetLocation({
    this.projectId,
    this.countryId,
    this.countryName = 'United Arab Emirates',
    this.siteId,
    this.siteName,
    this.buildingId,
    this.buildingName,
    this.floorId,
    this.floorName,
    this.zoneId,
    this.zoneName,
    this.roomId,
    this.roomName,
  });

  String? projectId, countryId, countryName, siteId, siteName, buildingId, buildingName;
  String? floorId, floorName, zoneId, zoneName, roomId, roomName;

  /// Country › Site › Building › Floor › Zone › Room.
  List<String> get parts => [?countryName, ?siteName, ?buildingName, ?floorName, ?zoneName, ?_orNull(roomName)];

  /// locationPath: "United Arab Emirates / Dubai Factory / Building A / Ground Floor / …".
  String? get locationPath => parts.isEmpty ? null : parts.join(' / ');

  /// The asset register's location format: "Building / Floor – Zone".
  String get assetLocation {
    final path = [?buildingName, ?floorName].join(' / ');
    return zoneName == null ? path : '$path – $zoneName';
  }

  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'countryId': countryId,
    'countryName': countryName,
    'siteId': siteId,
    'siteName': siteName,
    'buildingId': buildingId,
    'buildingName': buildingName,
    'floorId': floorId,
    'floorName': floorName,
    'zoneId': zoneId,
    'zoneName': zoneName,
    'roomId': roomId,
    'roomName': roomName,
    'locationPath': locationPath,
  };

  factory AssetLocation.fromJson(Map<String, dynamic> j) => AssetLocation(
    projectId: _str(j['projectId']),
    countryId: _str(j['countryId']),
    countryName: _str(j['countryName']),
    siteId: _str(j['siteId']),
    siteName: _str(j['siteName']),
    buildingId: _str(j['buildingId']),
    buildingName: _str(j['buildingName']),
    floorId: _str(j['floorId']),
    floorName: _str(j['floorName']),
    zoneId: _str(j['zoneId']),
    zoneName: _str(j['zoneName']),
    roomId: _str(j['roomId']),
    roomName: _str(j['roomName']),
  );
}

/// AssetAssignmentDto.
class AssetAssignment {
  AssetAssignment({
    this.custodianDepartment,
    this.assignedToUserId,
    this.assignedToName,
    this.ownershipType,
    this.costCenter,
    this.responsibleTeam,
    this.assignmentStartDate,
    this.assignmentEndDate,
    this.isCurrent = true,
  });

  String? custodianDepartment, assignedToUserId, assignedToName, ownershipType, costCenter, responsibleTeam;
  DateTime? assignmentStartDate, assignmentEndDate;
  bool isCurrent;

  Map<String, dynamic> toJson() => {
    'custodianDepartment': custodianDepartment,
    'assignedToUserId': assignedToUserId,
    'assignedToName': assignedToName,
    'ownershipType': ownershipType,
    'costCenter': costCenter,
    'responsibleTeam': responsibleTeam,
    'assignmentStartDate': assignmentStartDate?.toIso8601String(),
    'assignmentEndDate': assignmentEndDate?.toIso8601String(),
    'isCurrent': isCurrent,
  };

  factory AssetAssignment.fromJson(Map<String, dynamic> j) => AssetAssignment(
    custodianDepartment: _str(j['custodianDepartment']),
    assignedToUserId: _str(j['assignedToUserId']),
    assignedToName: _str(j['assignedToName']),
    ownershipType: _str(j['ownershipType']),
    costCenter: _str(j['costCenter']),
    responsibleTeam: _str(j['responsibleTeam']),
    assignmentStartDate: _date(j['assignmentStartDate']),
    assignmentEndDate: _date(j['assignmentEndDate']),
    isCurrent: j['isCurrent'] is bool ? j['isCurrent'] as bool : true,
  );
}

/// AssetPurchaseWarrantyDto = purchase + documents + warranty.
class AssetPurchaseWarranty {
  AssetPurchaseWarranty({AssetPurchase? purchase, List<AssetDocument>? documents, AssetWarranty? warranty})
    : purchase = purchase ?? AssetPurchase(),
      documents = documents ?? [],
      warranty = warranty ?? AssetWarranty();

  final AssetPurchase purchase;

  /// Invoice & Documents.
  List<AssetDocument> documents;
  final AssetWarranty warranty;

  Map<String, dynamic> toJson() => {
    'purchase': purchase.toJson(),
    'documents': [for (final d in documents) d.toJson()],
    'warranty': warranty.toJson(),
  };

  factory AssetPurchaseWarranty.fromJson(Map<String, dynamic> j) => AssetPurchaseWarranty(
    purchase: AssetPurchase.fromJson(_map(j['purchase'])),
    documents: _documents(j['documents']),
    warranty: AssetWarranty.fromJson(_map(j['warranty'])),
  );
}

/// AssetPurchaseDto.
class AssetPurchase {
  AssetPurchase({
    this.purchaseOrderNumber,
    this.invoiceNumber,
    this.supplierVendor,
    this.manufacturer,
    this.purchaseDate,
    this.deliveryDate,
    this.purchaseCost,
    this.quantity = 1,
    this.quantityUnit = 'Nos',
    this.currency = 'AED',
    this.taxPercent = 5,
    this.paymentTerms,
    this.procurementMethod,
    this.projectReference,
    this.remarks,
  });

  String? purchaseOrderNumber, invoiceNumber, supplierVendor, manufacturer;
  DateTime? purchaseDate, deliveryDate;
  double? purchaseCost, quantity, taxPercent;
  String? quantityUnit, currency, paymentTerms, procurementMethod, projectReference, remarks;

  /// Total Cost = cost × quantity × (1 + VAT %); null until cost and quantity are given.
  double? get totalCost {
    final cost = purchaseCost, qty = quantity;
    if (cost == null || qty == null) return null;
    return cost * qty * (1 + (taxPercent ?? 0) / 100);
  }

  Map<String, dynamic> toJson() => {
    'purchaseOrderNumber': purchaseOrderNumber,
    'invoiceNumber': invoiceNumber,
    'supplierVendor': supplierVendor,
    'manufacturer': manufacturer,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'deliveryDate': deliveryDate?.toIso8601String(),
    'purchaseCost': purchaseCost,
    'quantity': quantity,
    'quantityUnit': quantityUnit,
    'currency': currency,
    'taxPercent': taxPercent,
    'totalCost': totalCost,
    'paymentTerms': paymentTerms,
    'procurementMethod': procurementMethod,
    'projectReference': projectReference,
    'remarks': remarks,
  };

  factory AssetPurchase.fromJson(Map<String, dynamic> j) => AssetPurchase(
    purchaseOrderNumber: _str(j['purchaseOrderNumber']),
    invoiceNumber: _str(j['invoiceNumber']),
    supplierVendor: _str(j['supplierVendor']),
    manufacturer: _str(j['manufacturer']),
    purchaseDate: _date(j['purchaseDate']),
    deliveryDate: _date(j['deliveryDate']),
    purchaseCost: _num(j['purchaseCost']),
    quantity: _num(j['quantity']),
    quantityUnit: _str(j['quantityUnit']),
    currency: _str(j['currency']),
    taxPercent: _num(j['taxPercent']),
    paymentTerms: _str(j['paymentTerms']),
    procurementMethod: _str(j['procurementMethod']),
    projectReference: _str(j['projectReference']),
    remarks: _str(j['remarks']),
  );
}

/// AssetWarrantyDto.
class AssetWarranty {
  AssetWarranty({
    this.warrantyType,
    this.warrantyStartDate,
    this.warrantyPeriod,
    this.warrantyPeriodUnit = 'Years',
    this.amcIncluded = false,
    this.supportCoverage,
    this.serviceProvider,
    this.warrantyReference,
  });

  String? warrantyType;
  DateTime? warrantyStartDate;
  int? warrantyPeriod;
  String? warrantyPeriodUnit;
  bool amcIncluded;
  String? supportCoverage, serviceProvider, warrantyReference;

  /// Warranty End Date = start + period (Days / Months / Years); null until both are given.
  DateTime? get warrantyEndDate => warrantyEnd(warrantyStartDate, warrantyPeriod, warrantyPeriodUnit);

  Map<String, dynamic> toJson() => {
    'warrantyType': warrantyType,
    'warrantyStartDate': warrantyStartDate?.toIso8601String(),
    'warrantyEndDate': warrantyEndDate?.toIso8601String(),
    'warrantyPeriod': warrantyPeriod,
    'warrantyPeriodUnit': warrantyPeriodUnit,
    'amcIncluded': amcIncluded,
    'supportCoverage': supportCoverage,
    'serviceProvider': serviceProvider,
    'warrantyReference': warrantyReference,
  };

  factory AssetWarranty.fromJson(Map<String, dynamic> j) => AssetWarranty(
    warrantyType: _str(j['warrantyType']),
    warrantyStartDate: _date(j['warrantyStartDate']),
    warrantyPeriod: _int(j['warrantyPeriod']),
    warrantyPeriodUnit: _str(j['warrantyPeriodUnit']),
    amcIncluded: j['amcIncluded'] == true,
    supportCoverage: _str(j['supportCoverage']),
    serviceProvider: _str(j['serviceProvider']),
    warrantyReference: _str(j['warrantyReference']),
  );
}

/// [start] + [period] [unit]; months / years keep the day of month, clamped to the month's last
/// day (31 Jan + 1 month = 28 Feb). The end date is the same calendar day (start 1 Jan 2026 +
/// 2 years = 1 Jan 2028).
DateTime? warrantyEnd(DateTime? start, int? period, String? unit) {
  if (start == null || period == null || period <= 0) return null;
  if (unit == 'Days') return DateTime(start.year, start.month, start.day + period);
  final months = unit == 'Months' ? period : period * 12;
  final first = DateTime(start.year, start.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, start.day > lastDay ? lastDay : start.day);
}

/// AssetDocumentDto (Invoice & Documents, Attachments). [url] is the local file path for now.
class AssetDocument {
  AssetDocument({required this.fileName, this.url, this.contentType, this.fileSize, this.uploadedAt});

  final String fileName;
  final String? url;
  final String? contentType;

  /// Bytes.
  final int? fileSize;
  final DateTime? uploadedAt;

  double get sizeMb => (fileSize ?? 0) / (1024 * 1024);

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'url': url,
    'contentType': contentType,
    'fileSize': fileSize,
    'uploadedAt': uploadedAt?.toIso8601String(),
  };

  static AssetDocument? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = _str(j['fileName']);
    if (name == null) return null;
    return AssetDocument(
      fileName: name,
      url: _str(j['url']),
      contentType: _str(j['contentType']),
      fileSize: _int(j['fileSize']),
      uploadedAt: _date(j['uploadedAt']),
    );
  }
}

/// AssetAdditionalInformationDto = technical + operational + customFields + attachments.
class AssetAdditionalInformation {
  AssetAdditionalInformation({
    AssetTechnicalDetails? technical,
    AssetOperationalDetails? operational,
    List<AssetCustomField>? customFields,
    List<AssetDocument>? attachments,
  }) : technical = technical ?? AssetTechnicalDetails(),
       operational = operational ?? AssetOperationalDetails(),
       customFields = customFields ?? [],
       attachments = attachments ?? [];

  final AssetTechnicalDetails technical;
  final AssetOperationalDetails operational;
  List<AssetCustomField> customFields;
  List<AssetDocument> attachments;

  Map<String, dynamic> toJson() => {
    'technical': technical.toJson(),
    'operational': operational.toJson(),
    'customFields': [for (final f in customFields) f.toJson()],
    'attachments': [for (final d in attachments) d.toJson()],
  };

  factory AssetAdditionalInformation.fromJson(Map<String, dynamic> j) => AssetAdditionalInformation(
    technical: AssetTechnicalDetails.fromJson(_map(j['technical'])),
    operational: AssetOperationalDetails.fromJson(_map(j['operational'])),
    customFields: [
      for (final f in _list(j['customFields'])) ?AssetCustomField.fromJson(f),
    ],
    attachments: _documents(j['attachments']),
  );
}

/// AssetTechnicalDetailsDto. Template fields (Power Rating, Voltage …) go into [specifications].
class AssetTechnicalDetails {
  AssetTechnicalDetails({
    Map<String, AssetSpecification>? specifications,
    this.dimensionLength,
    this.dimensionWidth,
    this.dimensionHeight,
    this.dimensionUnit = 'mm',
    this.weight,
    this.weightUnit = 'kg',
    this.expectedLifespan,
    this.expectedLifespanUnit = 'Years',
    this.technicalRemarks,
  }) : specifications = specifications ?? {};

  /// Spec name → value; serialised as a list of AssetSpecificationDto.
  final Map<String, AssetSpecification> specifications;
  double? dimensionLength, dimensionWidth, dimensionHeight, weight;
  String? dimensionUnit, weightUnit, expectedLifespanUnit, technicalRemarks;
  int? expectedLifespan;

  Map<String, dynamic> toJson() => {
    'specifications': [
      for (final s in specifications.values)
        if (_orNull(s.value) != null) s.toJson(),
    ],
    'dimensionLength': dimensionLength,
    'dimensionWidth': dimensionWidth,
    'dimensionHeight': dimensionHeight,
    'dimensionUnit': dimensionUnit,
    'weight': weight,
    'weightUnit': weightUnit,
    'expectedLifespan': expectedLifespan,
    'expectedLifespanUnit': expectedLifespanUnit,
    'technicalRemarks': technicalRemarks,
  };

  factory AssetTechnicalDetails.fromJson(Map<String, dynamic> j) => AssetTechnicalDetails(
    specifications: {
      for (final spec in _list(j['specifications']).map(AssetSpecification.fromJson).nonNulls) spec.name: spec,
    },
    dimensionLength: _num(j['dimensionLength']),
    dimensionWidth: _num(j['dimensionWidth']),
    dimensionHeight: _num(j['dimensionHeight']),
    dimensionUnit: _str(j['dimensionUnit']),
    weight: _num(j['weight']),
    weightUnit: _str(j['weightUnit']),
    expectedLifespan: _int(j['expectedLifespan']),
    expectedLifespanUnit: _str(j['expectedLifespanUnit']),
    technicalRemarks: _str(j['technicalRemarks']),
  );
}

/// AssetSpecificationDto.
class AssetSpecification {
  const AssetSpecification({required this.name, this.value, this.unit});

  final String name;
  final String? value;
  final String? unit;

  Map<String, dynamic> toJson() => {'name': name, 'value': value, 'unit': unit};

  static AssetSpecification? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = _str(j['name']);
    return name == null ? null : AssetSpecification(name: name, value: _str(j['value']), unit: _str(j['unit']));
  }
}

/// AssetOperationalDetailsDto.
class AssetOperationalDetails {
  AssetOperationalDetails({
    this.operatingHoursPerDay,
    this.operatingHoursUnit = 'Hours',
    this.operatingShift,
    this.utilization,
    this.maintenanceFrequency,
    this.maintenanceFrequencyUnit = 'Months',
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    List<String>? complianceStandards,
  }) : complianceStandards = complianceStandards ?? [];

  double? operatingHoursPerDay;
  String? operatingHoursUnit, operatingShift, utilization, maintenanceFrequencyUnit;
  int? maintenanceFrequency;
  DateTime? lastMaintenanceDate, nextMaintenanceDate;
  List<String> complianceStandards;

  Map<String, dynamic> toJson() => {
    'operatingHoursPerDay': operatingHoursPerDay,
    'operatingHoursUnit': operatingHoursUnit,
    'operatingShift': operatingShift,
    'utilization': utilization,
    'maintenanceFrequency': maintenanceFrequency,
    'maintenanceFrequencyUnit': maintenanceFrequencyUnit,
    'lastMaintenanceDate': lastMaintenanceDate?.toIso8601String(),
    'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String(),
    'complianceStandards': complianceStandards,
  };

  factory AssetOperationalDetails.fromJson(Map<String, dynamic> j) => AssetOperationalDetails(
    operatingHoursPerDay: _num(j['operatingHoursPerDay']),
    operatingHoursUnit: _str(j['operatingHoursUnit']),
    operatingShift: _str(j['operatingShift']),
    utilization: _str(j['utilization']),
    maintenanceFrequency: _int(j['maintenanceFrequency']),
    maintenanceFrequencyUnit: _str(j['maintenanceFrequencyUnit']),
    lastMaintenanceDate: _date(j['lastMaintenanceDate']),
    nextMaintenanceDate: _date(j['nextMaintenanceDate']),
    complianceStandards: _strings(j['complianceStandards']),
  );
}

/// AssetCustomFieldDto.
class AssetCustomField {
  AssetCustomField({required this.fieldName, this.fieldType = 'Text', this.value});

  String fieldName;
  String? fieldType;
  String? value;

  Map<String, dynamic> toJson() => {'fieldName': fieldName, 'fieldType': fieldType, 'value': value};

  static AssetCustomField? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = _str(j['fieldName']);
    return name == null ? null : AssetCustomField(fieldName: name, fieldType: _str(j['fieldType']), value: _str(j['value']));
  }
}

// ---- null-safe JSON readers (a missing or wrongly typed field never throws)

String? _orNull(String? s) => s == null || s.trim().isEmpty ? null : s;
String? _str(Object? v) => v is String ? v : null;
int? _int(Object? v) => v is num ? v.toInt() : null;
double? _num(Object? v) => v is num ? v.toDouble() : null;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};
List<Object?> _list(Object? v) => v is List ? v : const [];
List<String> _strings(Object? v) => v is List ? v.whereType<String>().toList() : [];
List<AssetDocument> _documents(Object? v) => [
  for (final d in _list(v)) ?AssetDocument.fromJson(d),
];
