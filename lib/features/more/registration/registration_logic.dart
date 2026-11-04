import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';

/// Register Asset steps (stepper labels) — the web form's 5 steps plus Review.
const registrationSteps = ['Basic', 'Classification', 'Location', 'Purchase', 'Additional', 'Review'];

/// Step titles above each step's fields.
const registrationStepTitles = [
  'Basic Information',
  'Classification',
  'Location & Assignment',
  'Purchase & Warranty',
  'Additional Information',
  'Review',
];

String? _blank(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

/// The required (*) fields of [step] that are still empty, by label. Next checks the step's own
/// form; Submit checks every step with this (a resumed draft may skip earlier steps).
List<String> registrationMissing(RegistrationForm f, int step) {
  final b = f.basicInformation, c = f.classification;
  final l = f.locationAssignment.location, a = f.locationAssignment.assignment;
  final p = f.purchaseWarranty.purchase;
  final classification = [
    if (c.category == null) 'Category',
    if (c.subCategory == null) 'Sub Category',
    if (c.assetType == null) 'Asset Type',
  ];
  return switch (step) {
    0 => [
      if (_blank(b.assetName) == null) 'Asset Name',
      if (_blank(b.assetTag) == null) 'Asset Tag / Asset ID',
      ...classification,
      if (b.status == null) 'Status',
    ],
    1 => [
      ...classification,
      if (f.criticality == null) 'Criticality',
      if (c.department == null) 'Department',
      if (c.taggingMethod == null) 'Tagging Method',
      if (c.lifecycleStage == null) 'Lifecycle Stage',
    ],
    2 => [
      if (l.countryName == null) 'Country',
      if (l.siteName == null) 'Site',
      if (l.buildingName == null) 'Building',
      if (l.floorName == null) 'Floor',
      if (a.custodianDepartment == null) 'Custodian / Department',
    ],
    3 => [
      if (_blank(p.purchaseOrderNumber) == null) 'Purchase Order Number',
      if (_blank(p.supplierVendor) == null) 'Supplier / Vendor',
      if (_blank(p.manufacturer) == null) 'Manufacturer',
      if (p.purchaseDate == null) 'Purchase Date',
      if (p.purchaseCost == null) 'Purchase Cost',
      if (p.quantity == null) 'Quantity',
    ],
    _ => const [],
  };
}

/// Date rules of [step] (shown under the fields); null when fine.
String? registrationDateError(RegistrationForm f, int step) {
  final p = f.purchaseWarranty.purchase, a = f.locationAssignment.assignment;
  final o = f.additionalInformation.operational;
  return switch (step) {
    2 when a.assignmentStartDate != null &&
        a.assignmentEndDate != null &&
        a.assignmentEndDate!.isBefore(a.assignmentStartDate!) =>
      'Assignment end date cannot be before the start date',
    3 when p.purchaseDate != null && p.purchaseDate!.isAfter(DemoClock.now) => 'Purchase date cannot be in the future',
    3 when p.purchaseDate != null && p.deliveryDate != null && p.deliveryDate!.isBefore(p.purchaseDate!) =>
      'Delivery date cannot be before the purchase date',
    4 when o.lastMaintenanceDate != null &&
        o.nextMaintenanceDate != null &&
        o.nextMaintenanceDate!.isBefore(o.lastMaintenanceDate!) =>
      'Next maintenance date cannot be before the last one',
    _ => null,
  };
}

/// "Ramesh Kumar (Production)" (assigned person) or the custodian department.
String registrationCustodian(AssetAssignment a) {
  final name = _blank(a.assignedToName);
  if (name == null) return a.custodianDepartment ?? 'Unassigned';
  return a.custodianDepartment == null ? name : '$name (${a.custodianDepartment})';
}

/// The register's Asset for the form. Fields the form does not have keep the Asset defaults
/// (operational status Running, health 100); a missing warranty end date means no warranty
/// (expiry = purchase date).
Asset registrationToAsset(RegistrationForm f, {required String by}) {
  final b = f.basicInformation, c = f.classification;
  final l = f.locationAssignment.location, a = f.locationAssignment.assignment;
  final p = f.purchaseWarranty.purchase, w = f.purchaseWarranty.warranty;
  final t = f.additionalInformation.technical;
  final id = (_blank(b.assetTag) ?? '').toUpperCase();
  final purchaseDate = p.purchaseDate ?? DemoClock.today;
  final cost = p.purchaseCost ?? 0;
  final lifeYears = switch (t.expectedLifespan) {
    final n? when t.expectedLifespanUnit == 'Months' => (n / 12).ceil(),
    final n? => n,
    null => 10,
  };
  final location = l.assetLocation;
  return Asset(
    id: id,
    name: _blank(b.assetName) ?? id,
    type: c.assetType ?? '—',
    // Sub categories carry the register's category names (IT Equipment, HVAC …).
    category: c.subCategory ?? c.category ?? '—',
    manufacturer: _blank(b.manufacturer) ?? _blank(p.manufacturer) ?? '—',
    model: _blank(b.model),
    serialNo: _blank(b.serialNumber)?.toUpperCase(),
    tagId: _blank(b.rfidTagId)?.toUpperCase(),
    barcode: _blank(b.barcode)?.toUpperCase() ?? id,
    location: location.isEmpty ? '—' : location,
    site: l.siteName ?? '—',
    custodian: registrationCustodian(a),
    status: b.status ?? AssetStatus.active,
    condition: b.condition ?? 'Good',
    criticality: f.criticality ?? 'Medium',
    healthScore: 100,
    purchaseDate: purchaseDate,
    warrantyExpiry: w.warrantyEndDate ?? purchaseDate,
    amc: w.amcIncluded ? (_blank(w.serviceProvider) ?? 'AMC') : null,
    amcExpiry: w.amcIncluded ? w.warrantyEndDate : null,
    purchaseCost: cost,
    usefulLifeYears: lifeYears < 1 ? 1 : lifeYears,
    salvageValue: (cost * .1).roundToDouble(),
    imagePath: b.images.firstOrNull,
    photos: b.images.skip(1).toList(),
    tags: c.keywords,
    department: c.department,
    supplier: _blank(p.supplierVendor),
    poNumber: _blank(p.purchaseOrderNumber),
    locationHistory: [
      if (location.isNotEmpty) LocationRecord(at: DemoClock.now, location: location, by: by),
    ],
  );
}
