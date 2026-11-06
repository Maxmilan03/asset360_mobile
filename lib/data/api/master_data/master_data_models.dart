/// Typed, null-safe models of the Master Data Management service (port 5500). Field names follow
/// the C# response records in docs/backend_ref/Services/MasterDataManagement/Api/…/Contracts
/// (System.Text.Json camelCase). Audit fields (createdBy, clientId …) are not read.
///
/// Every list endpoint returns a bare JSON array (no paging); `search` and `status` are query
/// parameters (status = case-insensitive exact match).
library;

import 'package:asset360_mobile/data/api/assets/json_read.dart';

/// `MasterDataReferenceDto`: a link to another master record (id may be null, name is a copy).
class MdRef {
  const MdRef({this.id, this.name = ''});

  final String? id;
  final String name;

  static MdRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = jMap(json);
    final id = jStr(j['id']), name = jStr(j['name']) ?? '';
    return id == null && name.isEmpty ? null : MdRef(id: id, name: name);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// What every master record has: an id, a display name, a code and a status.
abstract class MdEntry {
  const MdEntry();

  String get id;
  String get name;
  String get code;
  String? get status;

  /// Records without a status are kept (the service writes "Active" by default).
  bool get isActive => status == null || status!.trim().toLowerCase() == 'active';
}

/// Parses a list reply: entries with neither id nor name are skipped; inactive ones too.
List<T> mdParseList<T extends MdEntry>(Object? body, T Function(Map<String, dynamic>) parse) => [
  for (final e in jItems(body))
    if (e is Map) parse(jMap(e)),
].where((e) => (e.id.isNotEmpty || e.name.isNotEmpty) && e.isActive).toList();

String _s(Map<String, dynamic> j, String key) => jStr(j[key])?.trim() ?? '';

/// GET /api/master-data/asset-categories (`AssetCategoryResponse`).
class MdCategory extends MdEntry {
  const MdCategory({
    required this.id,
    required this.name,
    this.code = '',
    this.assetType,
    this.description,
    this.parentCategory,
    this.status,
  });

  @override
  final String id;

  /// `categoryName`.
  @override
  final String name;
  @override
  final String code;

  /// Free-text asset type name on the category (not a link).
  final String? assetType;
  final String? description;
  final MdRef? parentCategory;
  @override
  final String? status;

  bool get isTopLevel => parentCategory?.id == null;

  factory MdCategory.fromJson(Map<String, dynamic> j) => MdCategory(
    id: _s(j, 'id'),
    name: _s(j, 'categoryName'),
    code: _s(j, 'code'),
    assetType: jStr(j['assetType']),
    description: jStr(j['description']),
    parentCategory: MdRef.fromJson(j['parentCategory']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/asset-categories/{categoryId}/subcategories (`AssetSubCategoryResponse`).
class MdSubCategory extends MdEntry {
  const MdSubCategory({
    required this.id,
    required this.name,
    this.code = '',
    this.categoryId = '',
    this.categoryName = '',
    this.assetType,
    this.status,
  });

  /// `subCategoryId`.
  @override
  final String id;

  /// `subCategoryName`.
  @override
  final String name;
  @override
  final String code;
  final String categoryId;
  final String categoryName;

  /// Free-text asset type name (the only link from a sub category to asset types).
  final String? assetType;
  @override
  final String? status;

  factory MdSubCategory.fromJson(Map<String, dynamic> j) => MdSubCategory(
    id: _s(j, 'subCategoryId'),
    name: _s(j, 'subCategoryName'),
    code: _s(j, 'code'),
    categoryId: _s(j, 'categoryId'),
    categoryName: _s(j, 'categoryName'),
    assetType: jStr(j['assetType']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/asset-types (`AssetTypeResponse`). Linked to a top-level category.
class MdAssetType extends MdEntry {
  const MdAssetType({
    required this.id,
    required this.name,
    this.code = '',
    this.category,
    this.assetClass,
    this.depreciationMethod,
    this.defaultLifetime,
    this.status,
  });

  @override
  final String id;

  /// `assetTypeName`.
  @override
  final String name;
  @override
  final String code;
  final MdRef? category;
  final String? assetClass;
  final String? depreciationMethod;
  final int? defaultLifetime;
  @override
  final String? status;

  factory MdAssetType.fromJson(Map<String, dynamic> j) => MdAssetType(
    id: _s(j, 'id'),
    name: _s(j, 'assetTypeName'),
    code: _s(j, 'code'),
    category: MdRef.fromJson(j['category']),
    assetClass: jStr(j['assetClass']),
    depreciationMethod: jStr(j['depreciationMethod']),
    defaultLifetime: jInt(j['defaultLifetime']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/asset-models (`AssetModelResponse`).
class MdAssetModel extends MdEntry {
  const MdAssetModel({
    required this.id,
    required this.name,
    this.code = '',
    this.manufacturer,
    this.assetType,
    this.category,
    this.lifecycle,
    this.status,
  });

  @override
  final String id;

  /// `modelName`.
  @override
  final String name;

  /// `modelCode`.
  @override
  final String code;
  final MdRef? manufacturer;
  final MdRef? assetType;
  final MdRef? category;
  final String? lifecycle;
  @override
  final String? status;

  factory MdAssetModel.fromJson(Map<String, dynamic> j) => MdAssetModel(
    id: _s(j, 'id'),
    name: _s(j, 'modelName'),
    code: _s(j, 'modelCode'),
    manufacturer: MdRef.fromJson(j['manufacturer']),
    assetType: MdRef.fromJson(j['assetType']),
    category: MdRef.fromJson(j['category']),
    lifecycle: jStr(j['lifecycle']),
    status: jStr(j['status']),
  );
}

/// A record whose only interesting fields are id, name, code and status, plus a few extras kept
/// as typed fields by the subclasses below.
class _Simple extends MdEntry {
  const _Simple(this.id, this.name, this.code, this.status);

  @override
  final String id;
  @override
  final String name;
  @override
  final String code;
  @override
  final String? status;
}

/// GET /api/master-data/manufacturers (`ManufacturerResponse`).
class MdManufacturer extends _Simple {
  const MdManufacturer({required String id, required String name, String code = '', this.country, String? status})
    : super(id, name, code, status);

  final String? country;

  factory MdManufacturer.fromJson(Map<String, dynamic> j) => MdManufacturer(
    id: _s(j, 'id'),
    name: _s(j, 'manufacturerName'),
    code: _s(j, 'code'),
    country: jStr(j['country']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/conditions (`ConditionResponse`).
class MdCondition extends _Simple {
  const MdCondition({
    required String id,
    required String name,
    String code = '',
    this.type,
    this.color,
    this.isDefault = false,
    this.healthScore,
    String? status,
  }) : super(id, name, code, status);

  final String? type;

  /// e.g. "#22C55E".
  final String? color;

  /// `defaultCondition`.
  final bool isDefault;
  final int? healthScore;

  factory MdCondition.fromJson(Map<String, dynamic> j) => MdCondition(
    id: _s(j, 'id'),
    name: _s(j, 'conditionName'),
    code: _s(j, 'code'),
    type: jStr(j['type']),
    color: jStr(j['color']),
    isDefault: jBool(j['defaultCondition']),
    healthScore: jInt(j['healthScore']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/criticalities (`CriticalityResponse`).
class MdCriticality extends _Simple {
  const MdCriticality({
    required String id,
    required String name,
    String code = '',
    this.riskLevel,
    this.maintenancePriority,
    this.color,
    this.isDefault = false,
    String? status,
  }) : super(id, name, code, status);

  final String? riskLevel;
  final String? maintenancePriority;
  final String? color;

  /// `defaultCriticality`.
  final bool isDefault;

  factory MdCriticality.fromJson(Map<String, dynamic> j) => MdCriticality(
    id: _s(j, 'id'),
    name: _s(j, 'criticalityName'),
    code: _s(j, 'code'),
    riskLevel: jStr(j['riskLevel']),
    maintenancePriority: jStr(j['maintenancePriority']),
    color: jStr(j['color']),
    isDefault: jBool(j['defaultCriticality']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/departments (`DepartmentResponse`).
class MdDepartment extends _Simple {
  const MdDepartment({required String id, required String name, String code = '', this.businessUnit, String? status})
    : super(id, name, code, status);

  final MdRef? businessUnit;

  factory MdDepartment.fromJson(Map<String, dynamic> j) => MdDepartment(
    id: _s(j, 'id'),
    name: _s(j, 'departmentName'),
    code: _s(j, 'code'),
    businessUnit: MdRef.fromJson(j['businessUnit']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/business-units (`BusinessUnitResponse`).
class MdBusinessUnit extends _Simple {
  const MdBusinessUnit({required String id, required String name, String code = '', String? status})
    : super(id, name, code, status);

  factory MdBusinessUnit.fromJson(Map<String, dynamic> j) =>
      MdBusinessUnit(id: _s(j, 'id'), name: _s(j, 'businessUnitName'), code: _s(j, 'code'), status: jStr(j['status']));
}

/// GET /api/master-data/suppliers (`SupplierResponse`).
class MdSupplier extends _Simple {
  const MdSupplier({
    required String id,
    required String name,
    String code = '',
    this.category,
    this.country,
    String? status,
  }) : super(id, name, code, status);

  final String? category;
  final String? country;

  factory MdSupplier.fromJson(Map<String, dynamic> j) => MdSupplier(
    id: _s(j, 'id'),
    name: _s(j, 'supplierName'),
    code: _s(j, 'code'),
    category: jStr(j['category']),
    country: jStr(j['country']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/amc-vendors (`AmcVendorResponse`).
class MdAmcVendor extends _Simple {
  const MdAmcVendor({
    required String id,
    required String name,
    String code = '',
    this.startDate,
    this.endDate,
    this.contractType,
    this.assetType,
    String? status,
  }) : super(id, name, code, status);

  final DateTime? startDate;
  final DateTime? endDate;
  final String? contractType;
  final MdRef? assetType;

  factory MdAmcVendor.fromJson(Map<String, dynamic> j) => MdAmcVendor(
    id: _s(j, 'id'),
    name: _s(j, 'amcVendorName'),
    code: _s(j, 'code'),
    startDate: jDate(j['startDate']),
    endDate: jDate(j['endDate']),
    contractType: jStr(j['contractType']),
    assetType: MdRef.fromJson(j['assetType']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/service-providers (`ServiceProviderResponse`).
class MdServiceProvider extends _Simple {
  const MdServiceProvider({
    required String id,
    required String name,
    String code = '',
    this.serviceType,
    String? status,
  }) : super(id, name, code, status);

  final String? serviceType;

  factory MdServiceProvider.fromJson(Map<String, dynamic> j) => MdServiceProvider(
    id: _s(j, 'id'),
    name: _s(j, 'serviceProviderName'),
    code: _s(j, 'code'),
    serviceType: jStr(j['serviceType']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/teams (`TeamResponse`).
class MdTeam extends _Simple {
  const MdTeam({required String id, required String name, String code = '', this.department, String? status})
    : super(id, name, code, status);

  final MdRef? department;

  factory MdTeam.fromJson(Map<String, dynamic> j) => MdTeam(
    id: _s(j, 'id'),
    name: _s(j, 'teamName'),
    code: _s(j, 'code'),
    department: MdRef.fromJson(j['department']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/shifts (`ShiftResponse`).
class MdShift extends _Simple {
  const MdShift({
    required String id,
    required String name,
    String code = '',
    this.shiftTime,
    this.startTime,
    this.endTime,
    String? status,
  }) : super(id, name, code, status);

  final String? shiftTime;

  /// "HH:mm" as sent.
  final String? startTime;
  final String? endTime;

  factory MdShift.fromJson(Map<String, dynamic> j) => MdShift(
    id: _s(j, 'id'),
    name: _s(j, 'shiftName'),
    code: _s(j, 'code'),
    shiftTime: jStr(j['shiftTime']),
    startTime: jStr(j['startTime']),
    endTime: jStr(j['endTime']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/uoms (`UomResponse`).
class MdUom extends _Simple {
  const MdUom({required String id, required String name, String code = '', this.type, this.symbol, String? status})
    : super(id, name, code, status);

  final String? type;
  final String? symbol;

  factory MdUom.fromJson(Map<String, dynamic> j) => MdUom(
    id: _s(j, 'id'),
    name: _s(j, 'uomName'),
    code: _s(j, 'code'),
    type: jStr(j['type']),
    symbol: jStr(j['symbol']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data-items/type/{masterType} (`MasterDataItemResponse`): generic code lists.
class MdListItem extends _Simple {
  const MdListItem({
    required String id,
    required String name,
    String code = '',
    this.masterType = '',
    this.sortOrder = 0,
    String? status,
  }) : super(id, name, code, status);

  final String masterType;
  final int sortOrder;

  factory MdListItem.fromJson(Map<String, dynamic> j) => MdListItem(
    id: _s(j, 'id'),
    name: _s(j, 'name'),
    code: _s(j, 'code'),
    masterType: _s(j, 'masterType'),
    sortOrder: jInt(j['sortOrder']) ?? 0,
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/employees (`EmployeeResponse`). The Asset service's
/// `assignment.assignedToUserId` holds [id] (the Mongo id), see docs/questions_for_backend.md.
class MdEmployee extends _Simple {
  const MdEmployee({
    required String id,
    required String name,
    this.employeeCode = '',
    this.department,
    this.designation,
    this.email,
    this.phone,
    String? status,
  }) : super(id, name, employeeCode, status);

  /// `employeeId`: the organisation's employee number ("EMP-0042"), not the record id.
  final String employeeCode;
  final MdRef? department;
  final String? designation;
  final String? email;

  /// `phoneNumber`.
  final String? phone;

  factory MdEmployee.fromJson(Map<String, dynamic> j) => MdEmployee(
    id: _s(j, 'id'),
    name: _s(j, 'employeeName'),
    employeeCode: _s(j, 'employeeId'),
    department: MdRef.fromJson(j['department']),
    designation: jStr(j['designation']),
    email: jStr(j['email']),
    phone: jStr(j['phoneNumber']),
    status: jStr(j['status']),
  );
}

// ------------------------------------------------------------------ locations

/// One node of GET /api/master-data/locations/tree (`LocationTreeNodeResponse`). [type] is free
/// text on the server ("Country", "Site", "Building" …); the levels are taken from the tree depth.
/// The tree has no coordinates, floor plans or zone shapes (none exist in the service).
class MdLocationNode extends MdEntry {
  const MdLocationNode({
    required this.id,
    required this.name,
    this.code = '',
    this.type = '',
    this.parentId,
    this.status,
    this.children = const [],
  });

  @override
  final String id;

  /// `locationName`.
  @override
  final String name;

  /// Printed on location labels: a "LOC:<code>" scan resolves through it.
  @override
  final String code;
  final String type;

  /// `parentLocationId`.
  final String? parentId;
  @override
  final String? status;
  final List<MdLocationNode> children;

  factory MdLocationNode.fromJson(Map<String, dynamic> j) => MdLocationNode(
    id: _s(j, 'id'),
    name: _s(j, 'locationName'),
    code: _s(j, 'code'),
    type: _s(j, 'type'),
    parentId: jStr(j['parentLocationId']),
    status: jStr(j['status']),
    children: [
      for (final c in jList(j['children']))
        if (c is Map) MdLocationNode.fromJson(jMap(c)),
    ].where((n) => n.id.isNotEmpty && n.isActive).toList(),
  );

  static List<MdLocationNode> parseTree(Object? body) => mdParseList(body, MdLocationNode.fromJson);
}

/// GET /api/master-data/sites (`SiteResponse`): extra site facts for the map phase.
class MdSite extends _Simple {
  const MdSite({
    required String id,
    required String name,
    String code = '',
    this.siteType,
    this.city,
    this.country,
    this.businessUnit,
    this.department,
    String? status,
  }) : super(id, name, code, status);

  final String? siteType;
  final String? city;

  /// Country NAME (the service has no country records).
  final String? country;
  final MdRef? businessUnit;
  final MdRef? department;

  factory MdSite.fromJson(Map<String, dynamic> j) => MdSite(
    id: _s(j, 'id'),
    name: _s(j, 'siteName'),
    code: _s(j, 'code'),
    siteType: jStr(j['siteType']),
    city: jStr(j['city']),
    country: jStr(j['country']),
    businessUnit: MdRef.fromJson(j['businessUnit']),
    department: MdRef.fromJson(j['department']),
    status: jStr(j['status']),
  );
}

/// GET /api/master-data/buildings | floors | zones (`BuildingResponse`, `FloorResponse`,
/// `ZoneResponse`): the "space" records, with capacity and area (no geometry).
class MdSpace extends _Simple {
  const MdSpace({
    required String id,
    required String name,
    String code = '',
    this.site,
    this.buildingId,
    this.buildingName,
    this.floorId,
    this.floorName,
    this.capacity,
    this.area,
    String? status,
  }) : super(id, name, code, status);

  final MdRef? site;
  final String? buildingId, buildingName, floorId, floorName;
  final int? capacity;

  /// Square metres as entered.
  final double? area;

  factory MdSpace.fromJson(Map<String, dynamic> j) => MdSpace(
    id: _s(j, 'id'),
    name: _s(j, 'name'),
    code: _s(j, 'code'),
    site: MdRef.fromJson(j['site']),
    buildingId: jStr(j['buildingId']),
    buildingName: jStr(j['buildingName']),
    floorId: jStr(j['floorId']),
    floorName: jStr(j['floorName']),
    capacity: jInt(j['capacity']),
    area: jNum(j['area']),
    status: jStr(j['status']),
  );
}
