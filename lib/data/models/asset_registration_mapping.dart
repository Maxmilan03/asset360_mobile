import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/db/location_seed.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';

/// Mapping between the backend [AssetRegistration] and the app's register [Asset], so the other
/// screens (asset list, Asset 360°, Home …) keep working on [Asset].

String? _blank(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

/// "Ramesh Kumar (Production)" (assigned person) or the custodian department.
String registrationCustodian(AssetAssignment a) {
  final name = _blank(a.assignedToName);
  if (name == null) return a.custodianDepartment ?? 'Unassigned';
  return a.custodianDepartment == null ? name : '$name (${a.custodianDepartment})';
}

extension AssetRegistrationToAsset on AssetRegistration {
  /// The register's Asset. Fields the registration does not have keep the Asset defaults
  /// (health 100); a missing warranty end date means no warranty (expiry = purchase date).
  /// [iot] is the store device picked in step 5 (local extra).
  Asset toAsset({required String by, IotDevice? iot}) {
    final b = basicInformation, c = classification;
    final l = locationAssignment.location, a = locationAssignment.assignment;
    final p = purchaseWarranty.purchase, w = purchaseWarranty.warranty;
    final t = additionalInformation.technical;
    final id = AssetTag.normalize(b.assetTag) ?? '';
    final purchaseDate = p.purchaseDate ?? DemoClock.today;
    final cost = p.purchaseCost ?? 0;
    final lifeYears = switch (t.expectedLifespan) {
      final n? when t.expectedLifespanUnit == PeriodUnit.months => (n / 12).ceil(),
      final n? => n,
      null => 10,
    };
    final location = l.assetLocation;
    final warrantyEnd = w.warrantyEndPreview;
    return Asset(
      id: id,
      name: _blank(b.assetName) ?? id,
      type: c.assetType ?? '—',
      // Sub categories carry the register's category names (IT Equipment, HVAC …).
      category: c.subCategory ?? c.category ?? '—',
      manufacturer: _blank(b.manufacturer) ?? _blank(p.manufacturer) ?? '—',
      model: _blank(b.model),
      serialNo: _blank(b.serialNumber)?.toUpperCase(),
      tagId: AssetTag.normalize(b.rfidTagId),
      barcode: AssetTag.normalize(b.barcode) ?? id,
      location: location.isEmpty ? '—' : location,
      site: l.siteName ?? '—',
      custodian: registrationCustodian(a),
      status: b.status ?? AssetStatus.active,
      condition: b.condition ?? 'Good',
      criticality: criticality ?? 'Medium',
      healthScore: 100,
      purchaseDate: purchaseDate,
      warrantyExpiry: warrantyEnd ?? purchaseDate,
      amc: w.amcIncluded ? (_blank(w.serviceProvider) ?? 'AMC') : null,
      amcExpiry: w.amcIncluded ? warrantyEnd : null,
      purchaseCost: cost,
      usefulLifeYears: lifeYears < 1 ? 1 : lifeYears,
      salvageValue: (cost * .1).roundToDouble(),
      imagePath: b.images.firstOrNull,
      photos: b.images.skip(1).toList(),
      tags: c.keywords,
      department: c.department,
      supplier: _blank(p.supplierVendor),
      poNumber: _blank(p.purchaseOrderNumber),
      parentId: local.parentAssetId,
      iot: iot,
      locationHistory: [if (location.isNotEmpty) LocationRecord(at: DemoClock.now, location: location, by: by)],
    );
  }
}

extension AssetToRegistration on Asset {
  /// The backend registration for a register asset (what GET /api/asset-registrations/{id} would
  /// return). Location IDs are the local location codes; fields the Asset does not keep stay null.
  AssetRegistration toRegistration() {
    final path = classificationOf(type);
    final (building, floor, zone) = _splitLocation(location);
    final custodianMatch = RegExp(r'^(.*) \((.*)\)$').firstMatch(custodian);
    final assignedName = custodianMatch?[1];
    final custodianDept = custodianMatch?[2] ?? (AssetOptions.departments.contains(custodian) ? custodian : department);
    return AssetRegistration(
      id: id,
      assetRegistrationId: id,
      currentStep: 5,
      basicInformation: AssetBasicInformation(
        assetName: name,
        assetTag: id,
        barcode: barcode,
        rfidTagId: tagId,
        model: model,
        manufacturer: manufacturer,
        serialNumber: serialNo,
        status: status,
        condition: condition,
        criticality: criticality,
        images: gallery,
      ),
      classification: AssetClassification(
        category: path?.category,
        // The register's category is the sub category level (IT Equipment, HVAC …).
        subCategory: category,
        assetType: type,
        criticality: criticality,
        department: department,
        keywords: [...tags],
      ),
      locationAssignment: AssetLocationAssignment(
        location: AssetLocation(
          countryId: countries.keys.first,
          countryName: countries.values.first.name,
          siteId: locationCodeOf(site),
          siteName: site,
          buildingId: locationCodeOf(site, building),
          buildingName: building,
          floorId: locationCodeOf(site, building, floor),
          floorName: floor,
          zoneId: locationCodeOf(site, building, floor, zone),
          zoneName: zone,
        ),
        assignment: AssetAssignment(
          custodianDepartment: custodianDept,
          assignedToName: assignedName ?? (custodianDept == custodian ? null : custodian),
        ),
      ),
      purchaseWarranty: AssetPurchaseWarranty(
        purchase: AssetPurchase(
          purchaseOrderNumber: poNumber,
          supplierVendor: supplier,
          manufacturer: manufacturer,
          purchaseDate: purchaseDate,
          purchaseCost: purchaseCost,
          quantity: 1,
          currency: 'AED',
        ),
        warranty: AssetWarranty(
          warrantyStartDate: purchaseDate,
          warrantyEndDate: warrantyExpiry,
          amcIncluded: amc != null,
          serviceProvider: amc,
        ),
      ),
      additionalInformation: AssetAdditionalInformation(
        technical: AssetTechnicalDetails(expectedLifespan: usefulLifeYears, expectedLifespanUnit: PeriodUnit.years),
      ),
      local: RegistrationLocalExtras(parentAssetId: parentId, iotDeviceImei: iot?.imei),
    );
  }
}

/// "Building A / Ground Floor – Generator Room GR-01" → (Building A, Ground Floor, Generator Room GR-01).
(String?, String?, String?) _splitLocation(String location) {
  final parts = location.split(' / ');
  if (parts.length < 2) return (_blank(parts.first == '—' ? null : parts.first), null, null);
  final floorZone = parts[1].split(' – ');
  return (parts[0], floorZone[0], floorZone.length > 1 ? floorZone.sublist(1).join(' – ') : null);
}

/// Asset tag / barcode / RFID values are kept trimmed and upper-case.
abstract final class AssetTag {
  static String? normalize(String? v) {
    final s = (v ?? '').trim().toUpperCase();
    return s.isEmpty ? null : s;
  }
}
