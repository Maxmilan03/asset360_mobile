import 'package:asset360_mobile/data/models/common.dart';

abstract final class AssetStatus {
  static const active = 'Active';
  static const underMaintenance = 'Under Maintenance';
  static const inactive = 'Inactive';
  static const retired = 'Retired';
  static const disposed = 'Disposed';
  static const inTransit = 'In Transit';

  /// The five statuses of the org-wide summary, in legend order.
  static const summary = [active, underMaintenance, inactive, retired, disposed];
}

class IotDevice {
  const IotDevice({
    required this.model,
    required this.type,
    required this.imei,
    required this.iccid,
    required this.batteryPct,
    required this.signalDbm,
    required this.firmware,
    required this.online,
    required this.lastSeen,
  });

  final String model;
  final String type;
  final String imei;
  final String iccid;
  final int batteryPct;
  final int signalDbm;
  final String firmware;
  final bool online;
  final DateTime lastSeen;

  IotDevice copyWith({int? batteryPct, int? signalDbm, bool? online, DateTime? lastSeen}) => IotDevice(
    model: model,
    type: type,
    imei: imei,
    iccid: iccid,
    batteryPct: batteryPct ?? this.batteryPct,
    signalDbm: signalDbm ?? this.signalDbm,
    firmware: firmware,
    online: online ?? this.online,
    lastSeen: lastSeen ?? this.lastSeen,
  );
}

/// One live telemetry value, e.g. Spindle Speed 1,200 rpm.
class TelemetryReading {
  const TelemetryReading({required this.key, required this.label, required this.value, required this.unit});

  final String key;
  final String label;
  final double value;
  final String unit;

  TelemetryReading copyWith({double? value}) =>
      TelemetryReading(key: key, label: label, value: value ?? this.value, unit: unit);
}

/// Lifetime running costs (AED), used by the Financial tab and TCO.
class AssetCosts {
  const AssetCosts({this.maintenance = 0, this.spares = 0, this.labor = 0, this.energy = 0});

  final double maintenance;
  final double spares;
  final double labor;
  final double energy;

  double get total => maintenance + spares + labor + energy;
}

class LocationRecord {
  const LocationRecord({required this.at, required this.location, required this.by});

  final DateTime at;
  final String location;
  final String by;
}

class Asset {
  const Asset({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.manufacturer,
    required this.location,
    required this.site,
    required this.custodian,
    required this.status,
    required this.purchaseDate,
    required this.warrantyExpiry,
    required this.healthScore,
    required this.criticality,
    required this.purchaseCost,
    this.model,
    this.serialNo,
    this.tagId,
    this.barcode,
    this.condition = 'Good',
    this.operationalStatus = 'Running',
    this.commissionedDate,
    this.amc,
    this.amcCost,
    this.amcExpiry,
    this.usefulLifeYears = 10,
    this.salvageValue = 0,
    this.imagePath,
    this.photos = const [],
    this.favorite = false,
    this.iot,
    this.telemetry = const [],
    this.trends = const {},
    this.locationHistory = const [],
    this.events = const [],
    this.costs = const AssetCosts(),
    this.parentId,
    this.tags = const [],
    this.department,
    this.supplier,
    this.poNumber,
  });

  final String id;
  final String name;
  final String type;
  final String category;
  final String manufacturer;
  final String? model;
  final String? serialNo;
  final String? tagId;
  final String? barcode;
  final String location;

  /// Dubai Factory, Dubai Office or Education City (Home site filter).
  final String site;

  /// Person or department, e.g. "Ramesh Kumar (Production)" or "Unassigned".
  final String custodian;
  final String status;
  final String condition;
  final String operationalStatus;
  final String criticality;
  final int healthScore;
  final DateTime purchaseDate;
  final DateTime? commissionedDate;
  final DateTime warrantyExpiry;

  /// "ABC Engineering" when under AMC, null otherwise.
  final String? amc;
  final double? amcCost;

  /// End of the current AMC period (null when there is no AMC).
  final DateTime? amcExpiry;

  /// AED.
  final double purchaseCost;
  final int usefulLifeYears;
  final double salvageValue;
  final String? imagePath;

  /// Extra photos added by users (the main photo is [imagePath]).
  final List<String> photos;
  final bool favorite;
  final IotDevice? iot;
  final List<TelemetryReading> telemetry;

  /// Hourly 24-point series per telemetry key (e.g. 'temperature').
  final Map<String, List<TrendPoint>> trends;
  final List<LocationRecord> locationHistory;
  final List<LogEntry> events;
  final AssetCosts costs;

  /// Registration extras (step 2 – 4).
  final String? parentId;
  final List<String> tags;
  final String? department;
  final String? supplier;
  final String? poNumber;

  bool get hasIot => iot != null;
  String get manufacturerModel => model == null ? manufacturer : '$manufacturer $model';

  /// Main photo first, then the photos users added.
  List<String> get gallery => [?imagePath, ...photos];

  Asset copyWith({
    String? id,
    String? name,
    String? type,
    String? category,
    String? manufacturer,
    String? model,
    String? serialNo,
    String? tagId,
    String? barcode,
    String? location,
    String? site,
    String? custodian,
    String? status,
    String? condition,
    String? operationalStatus,
    String? criticality,
    int? healthScore,
    DateTime? purchaseDate,
    DateTime? commissionedDate,
    DateTime? warrantyExpiry,
    String? amc,
    bool clearAmc = false,
    double? amcCost,
    DateTime? amcExpiry,
    List<String>? photos,
    bool? favorite,
    IotDevice? iot,
    List<TelemetryReading>? telemetry,
    List<LocationRecord>? locationHistory,
    List<LogEntry>? events,
    AssetCosts? costs,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNo: serialNo ?? this.serialNo,
      tagId: tagId ?? this.tagId,
      barcode: barcode ?? this.barcode,
      location: location ?? this.location,
      site: site ?? this.site,
      custodian: custodian ?? this.custodian,
      status: status ?? this.status,
      condition: condition ?? this.condition,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      criticality: criticality ?? this.criticality,
      healthScore: healthScore ?? this.healthScore,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      commissionedDate: commissionedDate ?? this.commissionedDate,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      amc: clearAmc ? null : amc ?? this.amc,
      amcCost: clearAmc ? null : amcCost ?? this.amcCost,
      amcExpiry: clearAmc ? null : amcExpiry ?? this.amcExpiry,
      purchaseCost: purchaseCost,
      usefulLifeYears: usefulLifeYears,
      salvageValue: salvageValue,
      imagePath: imagePath,
      photos: photos ?? this.photos,
      favorite: favorite ?? this.favorite,
      iot: iot ?? this.iot,
      telemetry: telemetry ?? this.telemetry,
      trends: trends,
      locationHistory: locationHistory ?? this.locationHistory,
      events: events ?? this.events,
      costs: costs ?? this.costs,
      parentId: parentId,
      tags: tags,
      department: department,
      supplier: supplier,
      poNumber: poNumber,
    );
  }
}

/// Org-wide figures (12,458 assets etc.) kept as summary numbers.
class OrgSummary {
  const OrgSummary({
    required this.statusCounts,
    required this.health,
    required this.healthBreakdown,
    required this.pmCompliancePct,
    required this.mttrHours,
    required this.woClosurePct,
    required this.avgDowntimeHours,
    required this.costs,
  });

  /// Keys follow [AssetStatus.summary].
  final Map<String, int> statusCounts;
  final int health;
  final Map<String, int> healthBreakdown;
  final int pmCompliancePct;
  final double mttrHours;
  final int woClosurePct;
  final int avgDowntimeHours;

  /// AED per cost category.
  final Map<String, int> costs;

  int get totalAssets => statusCounts.values.fold(0, (a, b) => a + b);
  int get totalCost => costs.values.fold(0, (a, b) => a + b);

  double statusPct(String status) => totalAssets == 0 ? 0 : (statusCounts[status] ?? 0) * 100 / totalAssets;
  double costPct(String key) => totalCost == 0 ? 0 : (costs[key] ?? 0) * 100 / totalCost;

  OrgSummary copyWith({Map<String, int>? statusCounts}) => OrgSummary(
    statusCounts: statusCounts ?? this.statusCounts,
    health: health,
    healthBreakdown: healthBreakdown,
    pmCompliancePct: pmCompliancePct,
    mttrHours: mttrHours,
    woClosurePct: woClosurePct,
    avgDowntimeHours: avgDowntimeHours,
    costs: costs,
  );
}
