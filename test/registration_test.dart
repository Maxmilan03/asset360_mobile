import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/csv.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:asset360_mobile/data/models/asset_registration_mapping.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/registration_drafts_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/validation/asset_registration_validator.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/more/registration/bulk_import.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _phones = {'small 360x640': Size(1080, 1920), 'large 430x932': Size(1290, 2796)};

/// A complete generator registration (the web screenshots' example), every section filled.
AssetRegistration _generator({String id = 'DRAFT-0001'}) => AssetRegistration(
  id: 'reg-1',
  assetRegistrationId: id,
  currentStep: 2,
  createdBy: 'Ahmed Ali',
  createdAt: DateTime(2026, 9, 25, 10, 30),
  updatedBy: 'Ahmed Ali',
  updatedAt: DateTime(2026, 9, 25, 10, 45),
  basicInformation: AssetBasicInformation(
    assetName: 'Diesel Generator 250 kVA',
    assetTag: 'GEN-00047',
    barcode: 'DG250-2026-00047',
    rfidTagId: 'E28011606000020B3C4F8E9A',
    model: 'C250D6E',
    manufacturer: 'Caterpillar',
    serialNumber: 'CAT2026G45001',
    status: AssetStatus.active,
    condition: 'Good',
    criticality: 'Critical',
    description: '250 kVA diesel generator for main plant backup power.',
    images: ['https://files.example/gen-1.jpg'],
  ),
  classification: AssetClassification(
    category: 'Machinery & Equipment',
    subCategory: 'Power Generation',
    assetType: 'Generator',
    assetSubType: 'Diesel Generator',
    functionPurpose: 'Backup Power',
    criticality: 'Critical',
    department: 'Facilities Management',
    costCenter: 'FM-001 - Building Operations',
    businessUnit: 'Head Office',
    taggingMethod: 'Barcode',
    complianceCategory: 'Safety Critical Equipment',
    lifecycleStage: 'In Use',
    keywords: ['generator', 'diesel'],
  ),
  locationAssignment: AssetLocationAssignment(
    location: AssetLocation(
      projectId: 'PRJ-1',
      countryId: 'AE',
      countryName: 'UAE',
      siteId: 'DF',
      siteName: 'Dubai Factory',
      buildingId: 'BLD-A',
      buildingName: 'Building A',
      floorId: 'BLD-A-GF',
      floorName: 'Ground Floor',
      zoneId: 'BLD-A-GF-GRG01',
      zoneName: 'Generator Room GR-01',
      roomId: 'R-1',
      roomName: 'Bay 1',
    ),
    assignment: AssetAssignment(
      custodianDepartment: 'Facilities Management',
      assignedToUserId: 'u-ahmed',
      assignedToName: 'Ahmed Basim',
      ownershipType: 'Company Owned',
      costCenter: 'FM-001 - Building Operations',
      responsibleTeam: 'MEP Team',
      assignmentStartDate: DateTime(2026, 9, 1),
      assignmentEndDate: DateTime(2027, 9, 1),
    ),
  ),
  purchaseWarranty: AssetPurchaseWarranty(
    purchase: AssetPurchase(
      purchaseOrderNumber: 'PO-2026-00458',
      invoiceNumber: 'INV-2026-0789',
      supplierVendor: 'Al-Futtaim Power Systems LLC',
      manufacturer: 'Caterpillar',
      purchaseDate: DateTime(2026, 6, 15),
      deliveryDate: DateTime(2026, 6, 28),
      purchaseCost: 250000,
      quantity: 1,
      quantityUnit: 'Unit(s)',
      currency: 'AED',
      taxPercent: 5,
      paymentTerms: '30 Days',
      procurementMethod: 'Direct Purchase',
      projectReference: 'Main Plant Expansion 2026',
      remarks: 'Includes commissioning and operator training.',
    ),
    documents: [
      AssetDocument(
        fileName: 'Purchase Invoice_INV-2026-0789.pdf',
        url: 'https://files.example/inv.pdf',
        contentType: 'application/pdf',
        fileSize: 1258291,
        uploadedAt: DateTime(2026, 6, 15),
      ),
    ],
    warranty: AssetWarranty(
      warrantyType: 'Manufacturer Warranty',
      warrantyStartDate: DateTime(2026, 6, 28),
      warrantyPeriod: 5,
      warrantyPeriodUnit: PeriodUnit.years,
      amcIncluded: true,
      supportCoverage: '24x7',
      serviceProvider: 'Caterpillar (UAE)',
      warrantyReference: 'WARR-2026-CAT-001',
    ),
  ),
  additionalInformation: AssetAdditionalInformation(
    technical: AssetTechnicalDetails(
      specifications: [
        const AssetSpecification(name: 'Power Rating', value: '250', unit: 'kVA'),
        const AssetSpecification(name: 'Phase', value: '3 Phase'),
      ],
      dimensionLength: 3200,
      dimensionWidth: 1100,
      dimensionHeight: 1800,
      dimensionUnit: 'mm',
      weight: 2500,
      weightUnit: 'kg',
      expectedLifespan: 20,
      expectedLifespanUnit: PeriodUnit.years,
      technicalRemarks: 'Air cooled, automatic transfer switch.',
    ),
    operational: AssetOperationalDetails(
      operatingHoursPerDay: 8,
      operatingHoursUnit: 'Hours',
      operatingShift: '24x7',
      utilization: 'Primary',
      maintenanceFrequency: 500,
      maintenanceFrequencyUnit: 'Hours',
      lastMaintenanceDate: DateTime(2026, 9, 1),
      nextMaintenanceDate: DateTime(2027, 3, 1),
      complianceStandards: ['ISO 8528', 'UAE Civil Defence'],
    ),
    customFields: [
      AssetCustomField(fieldName: 'Asset Color', fieldType: CustomFieldType.dropdown, value: 'Yellow'),
      AssetCustomField(fieldName: 'Installation Date', fieldType: CustomFieldType.date, value: '2026-06-15'),
    ],
    attachments: [AssetDocument(fileName: 'Manual.pdf', url: 'https://files.example/m.pdf', fileSize: 1024)],
  ),
  local: RegistrationLocalExtras(parentAssetId: 'CNC-00123', iotDeviceImei: '123'),
);

// ---------------------------------------------------------------- swagger field-name check

final _swagger = jsonDecode(File('docs/api_samples/swagger.json').readAsStringSync()) as Map<String, dynamic>;
Map<String, dynamic> get _schemas => (_swagger['components'] as Map)['schemas'] as Map<String, dynamic>;

/// Every key of [json] is a property of the swagger schema [dto] and vice versa, recursively
/// for nested DTOs and lists of DTOs.
/// Fields the backend added after docs/api_samples/swagger.json was saved (read from the source in
/// docs/backend_ref/Services/Asset/Api/…/Contracts/AssetRegistrationDraftContracts.cs).
const _addedSinceSwagger = {
  'AssetBasicInformationDto': {'nfcUid'},
  'AssetLocationDto': {'latitude', 'longitude'},
};

void _expectMatchesSchema(Object? json, String dto, String path) {
  final props = (_schemas[dto] as Map)['properties'] as Map<String, dynamic>;
  expect(json, isA<Map<String, dynamic>>(), reason: path);
  final map = json! as Map<String, dynamic>;
  expect(map.keys.toSet(), {...props.keys, ...?_addedSinceSwagger[dto]}, reason: '$path ($dto) field names');
  for (final MapEntry(:key, :value) in props.entries) {
    final p = value as Map<String, dynamic>;
    final ref = p[r'$ref'] as String? ?? (p['items'] as Map?)?[r'$ref'] as String?;
    if (ref == null) continue;
    final child = ref.split('/').last;
    final v = map[key];
    if (p['type'] == 'array') {
      for (final (i, item) in (v as List).indexed) {
        _expectMatchesSchema(item, child, '$path.$key[$i]');
      }
    } else {
      _expectMatchesSchema(v, child, '$path.$key');
    }
  }
}

// ---------------------------------------------------------------- widget helpers

Future<void> _scrollThrough(WidgetTester tester, String reason) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: reason);
  final f = find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical);
  if (f.evaluate().isEmpty) return;
  final pos = tester.state<ScrollableState>(f.first).position;
  for (var i = 0; i < 80 && pos.pixels < pos.maxScrollExtent; i++) {
    pos.jumpTo(math.min(pos.pixels + 300, pos.maxScrollExtent));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$reason @ ${pos.pixels.round()}');
  }
  pos.jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// The field whose key starts with "[label]#" (RegTextField / RegNumberField / RegDropdown /
/// RegAutocomplete key their inner field by label).
Finder _field(String label) => find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> && k.value.startsWith('$label#') && (w is FormField || w is Autocomplete);
});

Future<void> _enter(WidgetTester tester, String label, String text) async {
  var f = _field(label);
  if (tester.widget(f.first) is Autocomplete) f = find.descendant(of: f.first, matching: find.byType(TextFormField));
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.enterText(f.first, text);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String label, String option) async {
  await _tapVisible(tester, _field(label).first);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _launch(WidgetTester tester) async {
  final c = ProviderContainer(overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  return c;
}

Future<void> _close(WidgetTester tester, ProviderContainer c) async {
  // Unmount and dispose now so the provider timers (clock tick) stop before the test ends.
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  setUp(() {
    DemoClock.frozen = true;
    SharedPreferences.setMockInitialValues({});
  });

  test('CSV parser handles quotes and escaped quotes', () {
    expect(parseCsv('a,"b, c","say ""hi"""\r\n\n1,2,3'), [
      ['a', 'b, c', 'say "hi"'],
      ['1', '2', '3'],
    ]);
  });

  test('sample bulk CSV: 3 valid rows, the reused CNC-00123 tag is rejected', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final rows = validateBulkCsv(sampleBulkCsv, (v) => c.read(assetsProvider.notifier).ownerOf(v)?.id);
    expect(rows.where((r) => r.valid).length, 3);
    final bad = rows.singleWhere((r) => !r.valid);
    expect(bad.id, 'UPS-00001');
    expect(bad.errors, contains('tag_id already used by CNC-00123'));
  });

  group('AssetRegistration JSON = backend', () {
    test('every section uses exactly the swagger DTO field names (camelCase)', () {
      final j = _generator().toJson();
      expect(j.keys.toSet(), {
        'id',
        'assetRegistrationId',
        'currentStep',
        'basicInformation',
        'classification',
        'locationAssignment',
        'purchaseWarranty',
        'additionalInformation',
        'createdBy',
        'createdAt',
        'updatedBy',
        'updatedAt',
      });
      for (final (key, dto) in [
        ('basicInformation', 'AssetBasicInformationDto'),
        ('classification', 'AssetClassificationDto'),
        ('locationAssignment', 'AssetLocationAssignmentDto'),
        ('purchaseWarranty', 'AssetPurchaseWarrantyDto'),
        ('additionalInformation', 'AssetAdditionalInformationDto'),
      ]) {
        _expectMatchesSchema(j[key], dto, key);
      }
      // The create-draft request body is basicInformation + createdBy (+ client / tenant).
      final create = (_schemas['CreateAssetRegistrationDraftRequest'] as Map)['properties'] as Map;
      expect(create.keys, containsAll(['basicInformation', 'createdBy']));
    });

    test('toJson → fromJson → toJson round trip keeps every value', () {
      final j = _generator().toJson();
      final back = AssetRegistration.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>).toJson();
      expect(back, j);
      expect(j['basicInformation']['criticality'], 'Critical');
      expect(j['classification']['criticality'], 'Critical');
      expect(
        j['locationAssignment']['location']['locationPath'],
        'UAE > Dubai Factory > Building A > Ground Floor > Generator Room GR-01 > Bay 1',
      );
      expect(j['purchaseWarranty']['purchase']['totalCost'], 262500);
      expect(j['purchaseWarranty']['warranty']['warrantyEndDate'], DateTime(2031, 6, 27).toIso8601String());
      expect(j['additionalInformation']['technical']['specifications'], [
        {'name': 'Power Rating', 'value': '250', 'unit': 'kVA'},
        {'name': 'Phase', 'value': '3 Phase', 'unit': null},
      ]);
      // Local extras are not part of the backend entity, but survive device storage.
      expect(jsonEncode(j), isNot(contains('parentAssetId')));
      final stored = AssetRegistration.fromStorageJson(
        jsonDecode(jsonEncode(_generator().toStorageJson())) as Map<String, dynamic>,
      );
      expect(stored.local.parentAssetId, 'CNC-00123');
      expect(stored.local.iotDeviceImei, '123');
      expect(stored.toJson(), j);
    });

    test('reads a server response: server totals are kept until the inputs change', () {
      final r = AssetRegistration.fromJson({
        'assetRegistrationId': 'AR-1',
        'purchaseWarranty': {
          'purchase': {'totalCost': 99.5},
          'warranty': {'warrantyEndDate': '2030-01-01T00:00:00.000'},
        },
        'basicInformation': {'assetTag': 7, 'images': null},
      });
      expect(r.purchaseWarranty.purchase.totalCostPreview, 99.5);
      expect(r.purchaseWarranty.warranty.warrantyEndPreview, DateTime(2030));
      expect(r.basicInformation.assetTag, isNull, reason: 'wrong types are ignored, never thrown');
      r.purchaseWarranty.purchase
        ..purchaseCost = 100
        ..quantity = 2
        ..taxPercent = 5;
      // The server's rule: cost × (1 + tax %), quantity is not a factor.
      expect(r.purchaseWarranty.purchase.totalCostPreview, 105);
    });

    test('warranty end like the web: start + period − 1 day; month ends are clamped', () {
      // The web: 28 Jun 2026 + 5 Year(s) → 27 Jun 2031 (start + period − 1 day).
      expect(warrantyEnd(DateTime(2026, 6, 28), 5, PeriodUnit.years), DateTime(2031, 6, 27));
      expect(warrantyEnd(DateTime(2026, 1, 31), 1, PeriodUnit.months), DateTime(2026, 2, 27));
      expect(warrantyEnd(DateTime(2026, 6, 28), 10, PeriodUnit.days), DateTime(2026, 7, 7));
      expect(warrantyEnd(DateTime(2026, 3, 1), 1, PeriodUnit.months), DateTime(2026, 3, 31));
      expect(warrantyEnd(DateTime(2026, 6, 28), 5, null), isNull);
    });

    test('Asset ↔ AssetRegistration mapping keeps the register fields', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final gen = c.read(assetByIdProvider('GEN-00045'))!;
      final reg = gen.toRegistration();
      expect(reg.classification.category, 'Machinery & Equipment');
      expect(reg.locationAssignment.location.siteId, isNotNull);
      expect(reg.locationAssignment.location.buildingId, isNotNull);
      final back = reg.toAsset(by: 'test');
      for (final (name, a, b) in [
        ('id', gen.id, back.id),
        ('name', gen.name, back.name),
        ('type', gen.type, back.type),
        ('category', gen.category, back.category),
        ('location', gen.location, back.location),
        ('site', gen.site, back.site),
        ('status', gen.status, back.status),
        ('condition', gen.condition, back.condition),
        ('criticality', gen.criticality, back.criticality),
        ('purchaseCost', gen.purchaseCost, back.purchaseCost),
        ('warrantyExpiry', gen.warrantyExpiry, back.warrantyExpiry),
      ]) {
        expect(b, a, reason: name);
      }
      final asset = _generator().toAsset(by: 'test');
      expect(asset.id, 'GEN-00047');
      expect(asset.location, 'Building A / Ground Floor – Generator Room GR-01');
      expect(asset.category, 'Power Generation');
      expect(asset.parentId, 'CNC-00123');
      expect(asset.warrantyExpiry, DateTime(2031, 6, 27));
    });
  });

  group('RegistrationValidator = backend rules', () {
    String? owner(String code) => code == 'CNC-00123' ? 'CNC-00123' : null;
    Map<String, String> check(AssetRegistration r, int step, {bool mandatory = true}) =>
        RegistrationValidator.validateStep(r, step, requireMandatory: mandatory, tagOwner: owner);

    test('required fields per step (Next), keyed by backend field path', () {
      final empty = AssetRegistration(assetRegistrationId: 'DRAFT-0001')..basicInformation.status = null;
      expect(check(empty, 0).keys, {'AssetName', 'AssetTag', 'Status'});
      expect(check(empty, 1).keys, {
        'Category',
        'SubCategory',
        'AssetType',
        'Criticality',
        'Department',
        'TaggingMethod',
        'LifecycleStage',
      });
      expect(check(empty, 2).keys, {
        'Location.CountryId',
        'Location.SiteId',
        'Location.BuildingId',
        'Location.FloorId',
        'Assignment.CustodianDepartment',
      });
      expect(check(empty, 3).keys, {
        'Purchase.PurchaseOrderNumber',
        'Purchase.SupplierVendor',
        'Purchase.Manufacturer',
        'Purchase.PurchaseDate',
        'Purchase.PurchaseCost',
        'Purchase.Quantity',
      });
      expect(check(empty, 4), isEmpty);
      expect(check(empty, 0)['AssetName'], 'Asset Name is required.');
      for (var s = 0; s < 5; s++) {
        expect(check(empty, s, mandatory: false), isEmpty, reason: 'Save as Draft skips required fields');
        expect(check(_generator(), s), isEmpty, reason: 'complete registration, step $s');
      }
    });

    test('value rules apply on Next and on Save as Draft', () {
      final r = _generator();
      final p = r.purchaseWarranty.purchase, w = r.purchaseWarranty.warranty, a = r.locationAssignment.assignment;
      p
        ..quantity = 0
        ..purchaseCost = -1
        ..taxPercent = 101
        ..deliveryDate = DateTime(2026, 6, 1)
        ..remarks = 'x' * 501;
      w
        ..warrantyPeriod = 0
        ..warrantyPeriodUnit = null;
      a.assignmentEndDate = DateTime(2026, 8, 1);
      r.basicInformation.assetTag = ' cnc-00123 ';
      for (final mandatory in [true, false]) {
        expect(check(r, 3, mandatory: mandatory), {
          'Purchase.Quantity': 'Quantity must be greater than 0.',
          'Purchase.PurchaseCost': 'Purchase Cost must be 0 or more.',
          'Purchase.TaxPercent': 'Tax % must be between 0 and 100.',
          'Purchase.DeliveryDate': 'Delivery Date must be on or after the Purchase Date.',
          'Purchase.Remarks': 'Remarks must be 500 characters or fewer.',
          'Warranty.WarrantyPeriod': 'Warranty Period must be greater than 0.',
          'Warranty.WarrantyPeriodUnit': 'Warranty Period Unit is required when a period is given.',
        });
        expect(check(r, 2, mandatory: mandatory), {
          'Assignment.AssignmentEndDate': 'Assignment End Date must be on or after the Assignment Start Date.',
        });
        expect(check(r, 0, mandatory: mandatory)['AssetTag'], "An asset with tag 'CNC-00123' is already registered.");
      }
      p
        ..quantity = .5
        ..purchaseCost = 0
        ..taxPercent = 0
        ..deliveryDate = p.purchaseDate
        ..remarks = 'x' * 500;
      w.warrantyPeriod = null;
      expect(check(r, 3), isEmpty, reason: 'boundaries: cost 0, tax 0, same-day delivery, 500 chars, no period');
      expect(RegistrationValidator.firstInvalid(r, requireMandatory: false, tagOwner: owner)?.step, 0);
    });

    test('server rules: tagging method list, period unit list, documents need a URL, step 5 values', () {
      final r = _generator();
      final w = r.purchaseWarranty.warranty, info = r.additionalInformation;
      final t = info.technical, o = info.operational;
      r.classification.taggingMethod = 'NFC';
      w
        ..warrantyPeriodUnit = 'Decade'
        ..warrantyPeriod = 2;
      r.purchaseWarranty.documents = [AssetDocument(fileName: 'Invoice.pdf')];
      t
        ..dimensionWidth = 0
        ..weight = -1
        ..expectedLifespan = 0
        ..technicalRemarks = 'x' * 501;
      o
        ..operatingHoursPerDay = 25
        ..maintenanceFrequency = 0
        ..lastMaintenanceDate = DateTime(2026, 9, 10)
        ..nextMaintenanceDate = DateTime(2026, 9, 9);
      info
        ..customFields = [
          AssetCustomField(fieldName: 'Colour'),
          AssetCustomField(fieldName: ' colour '),
        ]
        ..attachments = [AssetDocument(fileName: 'Manual.pdf', url: ' ')];
      for (final mandatory in [true, false]) {
        expect(check(r, 1, mandatory: mandatory), {
          'TaggingMethod': 'Tagging Method must be one of: Barcode, RFID, BLE, QR Code.',
        });
        expect(check(r, 3, mandatory: mandatory), {
          'Documents': RegistrationValidator.documentsMessage,
          'Warranty.WarrantyPeriodUnit': 'Warranty Period Unit must be one of: Day(s), Month(s), Year(s).',
        });
        expect(check(r, 4, mandatory: mandatory), {
          'Technical.Dimensions': 'Dimensions must be greater than 0.',
          'Technical.Weight': 'Weight must be greater than 0.',
          'Technical.ExpectedLifespan': 'Expected Lifespan must be greater than 0.',
          'Technical.TechnicalRemarks': 'Technical Remarks must be 500 characters or fewer.',
          'Operational.OperatingHoursPerDay': 'Operating Hours (Per Day) must be between 0 and 24.',
          'Operational.MaintenanceFrequency': 'Maintenance Frequency must be greater than 0.',
          'Operational.NextMaintenanceDate': 'Next Maintenance Date must be on or after the Last Maintenance Date.',
          'CustomFields': 'Custom field names must be unique: colour.',
          'Attachments': RegistrationValidator.documentsMessage,
        });
      }
      // Aliases the server accepts, and a manually kept end date before the start.
      w
        ..warrantyPeriodUnit = 'years'
        ..warrantyPeriod = null
        ..warrantyStartDate = DateTime(2026, 7, 1)
        ..warrantyEndDate = DateTime(2026, 6, 30);
      r.classification.taggingMethod = 'qr code';
      r.purchaseWarranty.documents = [AssetDocument(fileName: 'Invoice.pdf', url: '/uploads/asset-documents/i.pdf')];
      expect(check(r, 1), isEmpty);
      expect(check(r, 3), {
        'Warranty.WarrantyEndDate': 'Warranty End Date must be on or after the Warranty Start Date.',
      });
      o
        ..operatingHoursPerDay = 24
        ..nextMaintenanceDate = DateTime(2026, 9, 10, 8);
      expect(check(r, 4).keys, isNot(contains('Operational.OperatingHoursPerDay')));
      expect(check(r, 4).keys, isNot(contains('Operational.NextMaintenanceDate')), reason: 'same day');
    });

    test('duplicate tag checks are app-only: no tagOwner (API mode) → none', () {
      final r = _generator()..basicInformation.assetTag = 'CNC-00123';
      expect(RegistrationValidator.validateStep(r, 0, requireMandatory: true), isEmpty);
    });
  });

  test('drafts survive an app restart (shared_preferences) and resume at currentStep', () async {
    final c1 = ProviderContainer();
    final draft = _generator(id: c1.read(registrationDraftsProvider.notifier).newDraftId());
    await c1.read(registrationDraftsProvider.notifier).save(draft, step: 2, by: 'Ahmed Ali');
    expect(draft.assetRegistrationId, 'DRAFT-0001');
    c1.dispose();

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final drafts = c2.read(registrationDraftsProvider.notifier);
    await drafts.loaded;
    final back = c2.read(registrationDraftsProvider).single;
    expect(back.assetRegistrationId, 'DRAFT-0001');
    expect(back.currentStep, 2);
    expect(back.updatedBy, 'Ahmed Ali');
    expect(back.toJson()..remove('updatedAt'), draft.toJson()..remove('updatedAt'));
    expect(drafts.newDraftId(), 'DRAFT-0002');
    await drafts.delete('DRAFT-0001');
    expect(c2.read(registrationDraftsProvider), isEmpty);
  });

  test('statuses: 4 values + Other bucket; raw Inactive / Retired count as Other', () {
    expect(AssetOptions.statuses, ['Active', 'Under Maintenance', 'In Repair', 'Disposed']);
    expect(AssetStatus.bucketOf('Retired'), AssetStatus.other);
    expect(AssetStatus.bucketOf('Inactive'), AssetStatus.other);
    expect(AssetStatus.bucketOf('In Repair'), 'In Repair');
    expect(AssetOptions.toneOf('Retired'), OptionTone.grey);
    expect(AssetOptions.toneOf('High'), OptionTone.red);
    expect(AssetOptions.toneOf('In Repair'), OptionTone.amber);
    expect(AssetOptions.warrantyPeriodUnits, ['Day(s)', 'Month(s)', 'Year(s)']);
    expect(AssetOptions.taggingMethods, ['Barcode', 'RFID', 'BLE', 'QR Code']);
  });

  testWidgets('register a generator end to end: required rules, validation, duplicate tag, '
      'Save as Draft on step 3 → restart → resume → Submit', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var c = await _launch(tester);
    c.read(routerProvider).go(Routes.registration);
    await tester.pumpAndSettle();
    expect(find.text('My Drafts (0)'), findsOneWidget);
    c.read(routerProvider).push(Routes.newRegistration);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 5 · Asset details and identification'), findsOneWidget);

    // Step 1: required fields only on Next.
    await _next(tester);
    expect(find.text('Asset Name is required.'), findsOneWidget);
    expect(find.text('Asset Tag is required.'), findsOneWidget);
    await _enter(tester, 'Asset Name', 'Diesel Generator 250 kVA');
    await _enter(tester, 'Asset Tag / Asset ID', 'cnc-00123');
    await _next(tester);
    expect(find.text("An asset with tag 'CNC-00123' is already registered."), findsOneWidget);
    await _enter(tester, 'Asset Tag / Asset ID', 'GEN-00047');
    expect(find.text("An asset with tag 'CNC-00123' is already registered."), findsNothing, reason: 'live re-check');
    expect(find.text('Chosen in step 2 (Classification) · tap to open'), findsOneWidget);
    await _next(tester);

    // Step 2: classification + criticality.
    expect(find.text('Step 2 of 5 · Category and type'), findsOneWidget);
    await _next(tester);
    for (final m in [
      'Category',
      'Sub Category',
      'Asset Type',
      'Criticality',
      'Department',
      'Tagging Method',
      'Lifecycle Stage',
    ]) {
      expect(find.text('$m is required.'), findsOneWidget, reason: m);
    }
    await _pick(tester, 'Category', 'Machinery & Equipment');
    await _pick(tester, 'Sub Category', 'Power Generation');
    await _pick(tester, 'Asset Type', 'Generator');
    await _tapVisible(tester, find.text('Diesel Generator'));
    await _pick(tester, 'Function / Purpose', 'Backup Power');
    await _pick(tester, 'Criticality', 'Critical');
    await _pick(tester, 'Department', 'Facilities Management');
    await _tapVisible(tester, find.text('Barcode'));
    await _pick(tester, 'Lifecycle Stage', 'In Use');
    await _next(tester);

    // Step 3: location (stored as IDs + names); custodian came from the department.
    expect(find.text('Step 3 of 5 · Where and with whom'), findsOneWidget);
    for (final option in ['Dubai Factory', 'Building A', 'Ground Floor']) {
      await _tapVisible(
        tester,
        find.ancestor(of: find.text('Select').first, matching: find.byType(DropdownButtonFormField<String>)),
      );
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('UAE > Dubai Factory > Building A > Ground Floor'), findsWidgets);
    await _tapVisible(tester, find.text('Save as Draft'));
    expect(find.textContaining('Draft DRAFT-0001 saved'), findsOneWidget);
    await c.read(registrationDraftsProvider.notifier).loaded;
    expect(c.read(registrationDraftsProvider).single.currentStep, 2);

    // "Reopen the app": a new container reads the drafts from the device.
    await _close(tester, c);
    c = await _launch(tester);
    await c.read(registrationDraftsProvider.notifier).loaded;
    c.read(routerProvider).go(Routes.registration);
    await tester.pumpAndSettle();
    expect(find.text('My Drafts (1)'), findsOneWidget);
    await _tapVisible(tester, find.text('Diesel Generator 250 kVA'));
    expect(find.text('Step 3 of 5 · Where and with whom'), findsOneWidget, reason: 'resumed at currentStep');
    final l = c.read(registrationDraftsProvider).single.locationAssignment.location;
    expect([l.countryId, l.siteId, l.buildingId, l.floorId], ['AE', 'DF', 'BLD-A', 'BLD-A-GF']);
    await _next(tester);

    // Step 4: required fields, then the backend's value rules.
    expect(find.text('Step 4 of 5 · Cost and warranty details'), findsOneWidget);
    await _next(tester);
    for (final m in ['Purchase Order Number', 'Supplier / Vendor', 'Manufacturer', 'Purchase Date', 'Purchase Cost']) {
      expect(find.text('$m is required.'), findsOneWidget, reason: m);
    }
    await _enter(tester, 'Purchase Order Number', 'PO-2026-00458');
    await _enter(tester, 'Supplier / Vendor', 'Al-Futtaim Power Systems LLC');
    await _enter(tester, 'Manufacturer', 'Caterpillar');
    await _tapVisible(tester, find.text('Select date').first);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _enter(tester, 'Purchase Cost (AED)', '250000');
    await _enter(tester, 'Tax (VAT %)', '150');
    await _enter(tester, 'Quantity', '0');
    await _next(tester);
    expect(find.text('Tax % must be between 0 and 100.'), findsOneWidget);
    expect(find.text('Quantity must be greater than 0.'), findsOneWidget);
    await _enter(tester, 'Tax (VAT %)', '5');
    await _enter(tester, 'Quantity', '1');
    expect(find.text('AED 262,500.00'), findsOneWidget);
    expect(find.text('Total Cost (AED) · calculated'), findsOneWidget);
    await _enter(tester, 'Warranty Period', '5');
    expect(find.text('Warranty End Date · calculated'), findsOneWidget);
    await _next(tester);

    // Step 5: nothing required → Review → Submit.
    expect(find.text('Step 5 of 5 · Custom fields and attachments'), findsOneWidget);
    await _next(tester);
    expect(find.text('Asset details are ready to be submitted'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Asset registered'), findsOneWidget);
    final a = c.read(assetByIdProvider('GEN-00047'))!;
    expect(a.name, 'Diesel Generator 250 kVA');
    expect(a.type, 'Generator');
    expect(a.category, 'Power Generation');
    expect(a.criticality, 'Critical');
    expect(a.location, 'Building A / Ground Floor');
    expect(a.site, 'Dubai Factory');
    expect(a.custodian, 'Facilities Management');
    expect(a.status, AssetStatus.active);
    expect(a.purchaseCost, 250000);
    expect(c.read(orgSummaryProvider).totalAssets, 12459);
    expect(c.read(orgSummaryProvider).statusCounts[AssetStatus.active], 10843);
    expect(c.read(registrationDraftsProvider), isEmpty, reason: 'Submit removes the draft');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await _close(tester, c);
  });

  for (final MapEntry(key: name, value: size) in _phones.entries) {
    testWidgets('no overflow on a $name phone: hub, bulk preview, all 6 steps of a full draft', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = await _launch(tester);
      await c.read(registrationDraftsProvider.notifier).save(_generator()..currentStep = 0, step: 0, by: 'Ahmed Ali');

      c.read(routerProvider).go(Routes.registration);
      await _scrollThrough(tester, 'Hub · Single');
      await _tapVisible(tester, find.text('Bulk Registration'));
      await _tapVisible(tester, find.text('No file? Use the sample CSV'));
      expect(find.textContaining('3. Preview'), findsOneWidget);
      await _scrollThrough(tester, 'Hub · Bulk preview');

      c.read(routerProvider).push(Routes.newRegistration, extra: const RegistrationPrefill(draftId: 'DRAFT-0001'));
      for (var step = 1; step <= 5; step++) {
        await _scrollThrough(tester, 'Step $step');
        await _next(tester);
      }
      expect(find.text('Asset details are ready to be submitted'), findsOneWidget);
      await _scrollThrough(tester, 'Review');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Asset registered'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Registered sheet');
      await _close(tester, c);
    });
  }
}
