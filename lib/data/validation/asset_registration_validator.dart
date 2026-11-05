import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:asset360_mobile/data/models/asset_registration_mapping.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';

/// Register Asset validation, the same rules as the backend. Errors are keyed by the backend's
/// field path inside the step's request DTO (ASP.NET / FluentValidation style, e.g.
/// "Purchase.PurchaseCost" in AssetPurchaseWarrantyDto), so an API 400 response can later be
/// shown under the same field with no mapping.
///
/// - Next checks the step with [requireMandatory] = true.
/// - Save as Draft checks every step with [requireMandatory] = false: empty fields are fine, but
///   any value entered must be valid.
///
/// Rules = AssetRegistrationDraftValidationExtensions.cs (docs/backend_ref/Services/Asset/Api/
/// A360.Asset.Api/Validation); dates are compared by calendar day like the server. The duplicate
/// checks ([tagOwner]) are app-only and run only in mock mode: in API mode the server answers a
/// taken asset tag with 409.
abstract final class RegistrationValidator {
  /// Steps with fields (0 … 4); step 5 is Review.
  static const formSteps = 5;

  /// Max length of Purchase.Remarks and Technical.TechnicalRemarks (trimmed, like the server).
  static const remarksMax = 500;

  /// Documents / attachments need the Url returned by the upload (ValidateDocuments).
  static const documentsMessage = 'Each document needs a file name and the URL returned by the upload.';

  static bool _beforeDay(DateTime a, DateTime b) =>
      DateTime(a.year, a.month, a.day).isBefore(DateTime(b.year, b.month, b.day));

  static bool _badDocuments(List<AssetDocument> docs) =>
      docs.any((d) => d.fileName.trim().isEmpty || (d.url ?? '').trim().isEmpty);

  /// Error for a tag that another asset already has (the backend's own message).
  static String duplicateTag(String tag) => "An asset with tag '$tag' is already registered.";

  /// Field path → message for [step]. [tagOwner] returns the asset ID already using a tag /
  /// barcode / RFID value, or null when it is free.
  static Map<String, String> validateStep(
    AssetRegistration r,
    int step, {
    required bool requireMandatory,
    String? Function(String code)? tagOwner,
  }) {
    final e = <String, String>{};
    void need(String key, String label, Object? value) {
      if (!requireMandatory || e.containsKey(key)) return;
      if (value == null || (value is String && value.trim().isEmpty)) e[key] = '$label is required.';
    }

    switch (step) {
      case 0:
        final b = r.basicInformation;
        need('AssetName', 'Asset Name', b.assetName);
        need('AssetTag', 'Asset Tag', b.assetTag);
        need('Status', 'Status', b.status);
        final tag = AssetTag.normalize(b.assetTag);
        if (tag != null && tagOwner?.call(tag) != null) e['AssetTag'] = duplicateTag(tag);
        // Barcode / RFID are matched by scans too, so the app keeps them unique (the asset's own
        // tag may double as its barcode).
        for (final (key, label, value) in [
          ('Barcode', 'Barcode', b.barcode),
          ('RfidTagId', 'RFID Tag ID', b.rfidTagId),
        ]) {
          final code = AssetTag.normalize(value);
          if (code == null || code == tag) continue;
          final owner = tagOwner?.call(code);
          if (owner != null) e[key] = "$label '$code' is already used by $owner.";
        }
      case 1:
        final c = r.classification;
        need('Category', 'Category', c.category);
        need('SubCategory', 'Sub Category', c.subCategory);
        need('AssetType', 'Asset Type', c.assetType);
        need('Criticality', 'Criticality', c.criticality);
        need('Department', 'Department', c.department);
        need('TaggingMethod', 'Tagging Method', c.taggingMethod);
        need('LifecycleStage', 'Lifecycle Stage', c.lifecycleStage);
        final method = c.taggingMethod?.trim().toLowerCase();
        if (method != null && method.isNotEmpty && !AssetOptions.taggingMethods.any((m) => m.toLowerCase() == method)) {
          e['TaggingMethod'] = 'Tagging Method must be one of: ${AssetOptions.taggingMethods.join(', ')}.';
        }
      case 2:
        final l = r.locationAssignment.location, a = r.locationAssignment.assignment;
        need('Location.CountryId', 'Country', l.countryId);
        need('Location.SiteId', 'Site', l.siteId);
        need('Location.BuildingId', 'Building', l.buildingId);
        need('Location.FloorId', 'Floor', l.floorId);
        need('Assignment.CustodianDepartment', 'Custodian / Department', a.custodianDepartment);
        if (a.assignmentStartDate != null &&
            a.assignmentEndDate != null &&
            _beforeDay(a.assignmentEndDate!, a.assignmentStartDate!)) {
          e['Assignment.AssignmentEndDate'] = 'Assignment End Date must be on or after the Assignment Start Date.';
        }
      case 3:
        final p = r.purchaseWarranty.purchase, w = r.purchaseWarranty.warranty;
        need('Purchase.PurchaseOrderNumber', 'Purchase Order Number', p.purchaseOrderNumber);
        need('Purchase.SupplierVendor', 'Supplier / Vendor', p.supplierVendor);
        need('Purchase.Manufacturer', 'Manufacturer', p.manufacturer);
        need('Purchase.PurchaseDate', 'Purchase Date', p.purchaseDate);
        need('Purchase.PurchaseCost', 'Purchase Cost', p.purchaseCost);
        need('Purchase.Quantity', 'Quantity', p.quantity);
        if (p.quantity != null && p.quantity! <= 0) e['Purchase.Quantity'] = 'Quantity must be greater than 0.';
        if (p.purchaseCost != null && p.purchaseCost! < 0) {
          e['Purchase.PurchaseCost'] = 'Purchase Cost must be 0 or more.';
        }
        if (p.taxPercent != null && (p.taxPercent! < 0 || p.taxPercent! > 100)) {
          e['Purchase.TaxPercent'] = 'Tax % must be between 0 and 100.';
        }
        if (p.purchaseDate != null && p.deliveryDate != null && _beforeDay(p.deliveryDate!, p.purchaseDate!)) {
          e['Purchase.DeliveryDate'] = 'Delivery Date must be on or after the Purchase Date.';
        }
        if ((p.remarks ?? '').trim().length > remarksMax) {
          e['Purchase.Remarks'] = 'Remarks must be $remarksMax characters or fewer.';
        }
        if (_badDocuments(r.purchaseWarranty.documents)) e['Documents'] = documentsMessage;
        if (w.warrantyPeriod != null && w.warrantyPeriod! <= 0) {
          e['Warranty.WarrantyPeriod'] = 'Warranty Period must be greater than 0.';
        }
        final unit = (w.warrantyPeriodUnit ?? '').trim();
        if (unit.isNotEmpty && PeriodUnit.normalize(unit) == null) {
          e['Warranty.WarrantyPeriodUnit'] = 'Warranty Period Unit must be one of: ${PeriodUnit.all.join(', ')}.';
        } else if (w.warrantyPeriod != null && unit.isEmpty) {
          e['Warranty.WarrantyPeriodUnit'] = 'Warranty Period Unit is required when a period is given.';
        }
        // With a period the end date is calculated; only a server-kept end date is checked.
        if (w.warrantyPeriod == null &&
            w.warrantyStartDate != null &&
            w.warrantyEndDate != null &&
            _beforeDay(w.warrantyEndDate!, w.warrantyStartDate!)) {
          e['Warranty.WarrantyEndDate'] = 'Warranty End Date must be on or after the Warranty Start Date.';
        }
      case 4:
        // Nothing is required; only the values given are checked.
        final info = r.additionalInformation, t = info.technical, o = info.operational;
        bool notPositive(num? v) => v != null && v <= 0;
        if ([t.dimensionLength, t.dimensionWidth, t.dimensionHeight].any(notPositive)) {
          e['Technical.Dimensions'] = 'Dimensions must be greater than 0.';
        }
        if (notPositive(t.weight)) e['Technical.Weight'] = 'Weight must be greater than 0.';
        if (notPositive(t.expectedLifespan)) {
          e['Technical.ExpectedLifespan'] = 'Expected Lifespan must be greater than 0.';
        }
        if ((t.technicalRemarks ?? '').trim().length > remarksMax) {
          e['Technical.TechnicalRemarks'] = 'Technical Remarks must be $remarksMax characters or fewer.';
        }
        final hours = o.operatingHoursPerDay;
        if (hours != null && (hours < 0 || hours > 24)) {
          e['Operational.OperatingHoursPerDay'] = 'Operating Hours (Per Day) must be between 0 and 24.';
        }
        if (notPositive(o.maintenanceFrequency)) {
          e['Operational.MaintenanceFrequency'] = 'Maintenance Frequency must be greater than 0.';
        }
        if (o.lastMaintenanceDate != null &&
            o.nextMaintenanceDate != null &&
            _beforeDay(o.nextMaintenanceDate!, o.lastMaintenanceDate!)) {
          e['Operational.NextMaintenanceDate'] = 'Next Maintenance Date must be on or after the Last Maintenance Date.';
        }
        final seen = <String>{}, duplicates = <String>{};
        for (final f in info.customFields) {
          final name = f.fieldName.trim();
          if (name.isNotEmpty && !seen.add(name.toLowerCase())) duplicates.add(name);
        }
        if (duplicates.isNotEmpty) e['CustomFields'] = 'Custom field names must be unique: ${duplicates.join(', ')}.';
        if (_badDocuments(info.attachments)) e['Attachments'] = documentsMessage;
      default:
        break; // Review has no fields.
    }
    return e;
  }

  /// First step (0 … 4) with an error and its errors, or null when the registration is valid.
  static ({int step, Map<String, String> errors})? firstInvalid(
    AssetRegistration r, {
    required bool requireMandatory,
    String? Function(String code)? tagOwner,
  }) {
    for (var s = 0; s < formSteps; s++) {
      final errors = validateStep(r, s, requireMandatory: requireMandatory, tagOwner: tagOwner);
      if (errors.isNotEmpty) return (step: s, errors: errors);
    }
    return null;
  }
}
