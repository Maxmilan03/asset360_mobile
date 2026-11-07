import 'dart:convert';
import 'dart:typed_data';

import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/assets/assets_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'dashboard_samples.dart';

/// A fake Asset + Media service for tests: answers by method + path with contract-shaped JSON
/// (docs/backend_ref/Services/Asset/Api/…/Contracts). Register replies with [on]; unknown routes
/// answer 404 `{"message"}`. Every request is kept in [requests].
class FakeAssetBackend implements HttpClientAdapter {
  FakeAssetBackend() {
    seedDefaults();
  }

  final requests = <RequestOptions>[];

  /// AR000001 as the server stores it: PUT replaces the sections sent (as UpdateAssetRegistrationAsync
  /// does), DELETE soft-deletes it (404 and out of the list afterwards).
  Map<String, dynamic> stored = sampleRegistration();
  final deleted = <String>{};
  final _routes = <String, FakeReply Function(RequestOptions o)>{};

  /// `on('GET', '/api/asset-registrations', (o) => FakeReply(200, {...}))`. [path] may end with
  /// `*` to match a prefix.
  void on(String method, String path, FakeReply Function(RequestOptions o) reply) => _routes['$method $path'] = reply;

  /// Requests to [path] (exact, no query) with [method].
  List<RequestOptions> calls(String method, String path) => [
    for (final r in requests)
      if (r.method == method && r.uri.path == path) r,
  ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(o);
    final key = '${o.method} ${o.uri.path}';
    var handler = _routes[key];
    if (handler == null) {
      for (final e in _routes.entries) {
        if (e.key.endsWith('*') && key.startsWith(e.key.substring(0, e.key.length - 1))) {
          handler = e.value;
          break;
        }
      }
    }
    final r = handler?.call(o) ?? FakeReply(404, {'message': 'No route for $key'});
    return ResponseBody.fromString(
      r.body == null ? '' : jsonEncode(r.body),
      r.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  /// Two assets, options, filters, ratings, categories … so every screen has something to show.
  void seedDefaults() {
    seedDashboard();
    on('GET', '/api/asset-registrations', (o) {
      final q = o.uri.queryParameters;
      final search = (q['search'] ?? '').toLowerCase();
      final status = q['status'];
      final items = [
        for (final a in sampleAssets)
          if (!deleted.contains(a['assetRegistrationId']) &&
              (search.isEmpty || '${a['assetName']} ${a['assetTag']}'.toLowerCase().contains(search)) &&
              (status == null || a['status'] == status))
            a,
      ];
      final pageSize = int.tryParse(q['pageSize'] ?? '') ?? 20;
      final page = int.tryParse(q['page'] ?? '') ?? 1;
      return FakeReply(200, {
        'items': items.skip((page - 1) * pageSize).take(pageSize).toList(),
        'totalCount': items.length,
        'page': page,
        'pageSize': pageSize,
        'summary': sampleSummary,
      });
    });
    on('GET', '/api/asset-registrations/filters', (_) => const FakeReply(200, sampleFilters));
    on('GET', '/api/asset-registrations/options', (_) => const FakeReply(200, sampleOptions));
    const ar1 = '/api/asset-registrations/AR000001';
    FakeReply gone() => const FakeReply(404, {'message': "Asset registration 'AR000001' was not found."});
    on('GET', ar1, (_) => deleted.contains('AR000001') ? gone() : FakeReply(200, stored));
    on('PUT', ar1, (o) {
      if (deleted.contains('AR000001')) return gone();
      final body = jsonDecode(jsonEncode(o.data)) as Map<String, dynamic>;
      stored = {
        ...stored,
        for (final k in UpdateAssetRegistrationRequest.sectionKeys)
          if (body[k] != null) k: body[k],
        'updatedBy': 'max.milan',
        'updatedAt': '2026-11-06T09:00:00Z',
      };
      return FakeReply(200, stored);
    });
    on('DELETE', ar1, (_) {
      if (!deleted.add('AR000001')) return gone();
      return const FakeReply(204);
    });
    on('GET', '/api/asset-assignments/options', (_) => const FakeReply(200, sampleAssignmentOptions));
    on('GET', '/api/asset-registrations/lookup', (o) {
      final code = (o.uri.queryParameters['code'] ?? '').toUpperCase();
      if (code == 'TAG-0001' || code == 'AR000001' || code == 'E2000017221101441890ABCD') {
        return FakeReply(200, {
          'code': o.uri.queryParameters['code'],
          'matchedBy': code == 'AR000001' ? 'assetRegistrationId' : (code.startsWith('E2') ? 'rfid' : 'assetTag'),
          'asset': sampleRegistration(),
        });
      }
      return FakeReply(404, {'message': "No asset matches the scanned code '${o.uri.queryParameters['code']}'."});
    });
    on(
      'GET',
      '/api/asset-images',
      (_) => const FakeReply(200, {
        'items': [sampleImage],
        'totalCount': 1,
        'page': 1,
        'pageSize': 200,
      }),
    );
    on(
      'GET',
      '/api/asset-documents',
      (_) => const FakeReply(200, {
        'items': [sampleDocument],
        'totalCount': 1,
        'page': 1,
        'pageSize': 200,
      }),
    );
    on('GET', '/api/asset-registrations/AR000001/components/tree', (_) => const FakeReply(200, sampleComponentTree));
    on('GET', '/api/asset-condition-assessments/current', (_) => const FakeReply(200, sampleCondition));
    on(
      'GET',
      '/api/asset-condition-assessments/ratings',
      (_) => const FakeReply(200, ['Excellent', 'Good', 'Fair', 'Poor', 'Critical']),
    );
    on(
      'POST',
      '/api/asset-condition-assessments',
      (o) => FakeReply(201, {...sampleCondition, ...jsonDecode(jsonEncode(o.data)) as Map}),
    );
    on(
      'GET',
      '/api/asset-criticality/current',
      (_) => const FakeReply(404, {'message': "Asset 'AR000001' has no criticality assessment yet."}),
    );
    on('GET', '/api/asset-criticality/options', (_) => const FakeReply(200, sampleCriticalityOptions));
    on('GET', '/api/asset-categories', (_) => const FakeReply(200, sampleCategories));
    on('GET', '/api/asset-category-types', (_) => const FakeReply(200, sampleTypes));
    on('GET', '/api/asset-models', (_) => const FakeReply(200, sampleModels));
    on('GET', '/api/asset-registrations/drafts', (_) => const FakeReply(200, []));
    seedMasterData();
    on('POST', '/api/media/upload', (o) {
      final form = o.data as FormData;
      final category = form.fields.firstWhere((f) => f.key == 'category').value;
      return FakeReply(200, {'url': 'http://localhost:5300/uploads/$category/${form.files.single.value.filename}'});
    });
  }

  /// Master Data Management (port 5500): every list the app reads, contract-shaped. Like the real
  /// repositories, `status` is a case-insensitive exact match and the link filters
  /// (categoryId, assetTypeId) narrow the list.
  void seedMasterData() {
    FakeReply list(RequestOptions o, List<Map<String, Object?>> rows, [Map<String, String> links = const {}]) {
      final q = o.uri.queryParameters;
      final status = q['status']?.toLowerCase();
      return FakeReply(200, [
        for (final r in rows)
          if ((status == null || '${r['status']}'.toLowerCase() == status) &&
              links.entries.every((l) {
                final want = q[l.key];
                if (want == null) return true;
                final ref = r[l.value];
                return ref is Map && ref['id'] == want;
              }))
            r,
      ]);
    }

    const md = '/api/master-data';
    on('GET', '$md/asset-categories', (o) => list(o, mdCategories));
    on('GET', '$md/asset-categories/md-cat-1/subcategories', (o) => list(o, mdSubCategories));
    on('GET', '$md/asset-categories/md-cat-2/subcategories', (o) => list(o, const []));
    on('GET', '$md/asset-types', (o) => list(o, mdAssetTypes, {'categoryId': 'category'}));
    on('GET', '$md/asset-models', (o) => list(o, mdAssetModels, {'assetTypeId': 'assetType'}));
    for (final (path, rows) in [
      ('manufacturers', mdManufacturers),
      ('conditions', mdConditions),
      ('criticalities', mdCriticalities),
      ('departments', mdDepartments),
      ('business-units', mdBusinessUnits),
      ('suppliers', mdSuppliers),
      ('amc-vendors', mdAmcVendors),
      ('service-providers', mdServiceProviders),
      ('teams', mdTeams),
      ('shifts', mdShifts),
      ('uoms', mdUoms),
      ('employees', mdEmployees),
    ]) {
      on('GET', '$md/$path', (o) => list(o, rows));
    }
    on('GET', '$md/locations/tree', (_) => FakeReply(200, mdLocationTree));
  }

  /// Dashboard service (5470): GET /api/dashboards/mobile/* and network status (dashboard_samples.dart).
  void seedDashboard() {
    const m = '/api/dashboards/mobile';
    on('GET', '$m/home', (_) => const FakeReply(200, dashHomeJson));
    on('GET', '$m/asset-overview', (o) {
      final q = (o.uri.queryParameters['search'] ?? '').toLowerCase();
      if (q.isEmpty) return const FakeReply(200, dashAssetOverviewJson);
      List<Object?> f(String k) => [
        for (final b in dashAssetOverviewJson[k]! as List)
          if ('${(b as Map)['label']}'.toLowerCase().contains(q)) b,
      ];
      return FakeReply(200, {
        ...dashAssetOverviewJson,
        'byStatus': f('byStatus'),
        'byType': f('byType'),
        'byLocation': f('byLocation'),
      });
    });
    on('GET', '$m/maintenance-performance', (_) => const FakeReply(200, dashMaintenanceJson));
    on('GET', '$m/upcoming-activities', (_) => const FakeReply(200, dashActivitiesJson));
    on('GET', '$m/recent-alerts', (o) => FakeReply(200, dashAlertsJson(o.uri.queryParameters['severity'])));
    on('GET', '$m/asset-locations', (_) => const FakeReply(200, dashLocationsJson));
    on('GET', '$m/asset-health', (_) => const FakeReply(200, dashHealthJson));
    on('GET', '$m/cost-summary', (_) => const FakeReply(200, dashCostJson));
    on('GET', '$m/recent-assets', (o) {
      final q = o.uri.queryParameters;
      return FakeReply(200, dashRecentAssetsJson(status: q['status'], assetType: q['assetType'], site: q['site']));
    });
    on('GET', '/api/dashboards/network-status', (_) => const FakeReply(200, dashNetworkStatusJson));
    on('GET', '/api/dashboards/network-status/tags', (_) => const FakeReply(200, dashTagsJson));
  }

  /// Containers / widget tests: route the Asset and Media clients here (config checks off).
  List<Override> get overrides {
    Dio dio(String base) => Dio(BaseOptions(baseUrl: base))..httpClientAdapter = this;
    return [
      apiClientProvider.overrideWithValue(ApiClient(dio('http://asset.test:5401'), checkConfig: false)),
      mediaClientProvider.overrideWithValue(
        ApiClient(dio('http://media.test:5300'), checkConfig: false, service: BackendService.media),
      ),
      masterDataClientProvider.overrideWithValue(
        ApiClient(dio('http://md.test:5500'), checkConfig: false, service: BackendService.masterData),
      ),
      dashboardClientProvider.overrideWithValue(
        ApiClient(dio('http://dash.test:5470'), checkConfig: false, service: BackendService.dashboard),
      ),
    ];
  }

  AssetsApi get api => AssetsApi(
    ApiClient(Dio(BaseOptions(baseUrl: 'http://asset.test:5401'))..httpClientAdapter = this, checkConfig: false),
  );
}

class FakeReply {
  const FakeReply(this.status, [this.body]);

  final int status;
  final Object? body;
}

/// Runs [body] with apiMode = true, then restores it.
Future<T> withApiMode<T>(Future<T> Function() body) async {
  debugApiMode = true;
  try {
    return await body();
  } finally {
    debugApiMode = null;
  }
}

ProviderContainer liveContainer(FakeAssetBackend backend, {List<Override> overrides = const []}) =>
    ProviderContainer(overrides: [...backend.overrides, ...overrides]);

// ------------------------------------------------------------------ contract-shaped samples

/// GET /api/asset-assignments/options (AssetAssignmentTargets, other entity types, selection modes).
const sampleAssignmentOptions = {
  'assignTo': ['Employee', 'Department', 'Location', 'Other Entity'],
  'otherEntityTypes': [
    'Vendor / Supplier',
    'Contractor',
    'Customer / Client',
    'Partner',
    'Project',
    'Cost Center',
    'Other',
  ],
  'selectionModes': ['Single', 'Multiple', 'Scan'],
};

const sampleSummary = {'total': 2, 'active': 1, 'underMaintenance': 1, 'inRepair': 0, 'disposed': 0, 'other': 0};

const sampleAssets = [
  {
    'id': '6650a1b2c3d4e5f600000001',
    'assetRegistrationId': 'AR000001',
    'assetName': 'Diesel Generator 500 kVA',
    'assetTag': 'TAG-0001',
    'imageUrl': 'http://localhost:5300/uploads/asset-images/gen.jpg',
    'category': 'Machinery & Equipment',
    'assetType': 'Generator',
    'siteName': 'Main Site',
    'buildingName': 'Block A',
    'floorName': 'Ground',
    'zoneName': null,
    'roomName': null,
    'locationPath': 'UAE > Main Site > Block A > Ground',
    'custodianUserId': 'u-100',
    'custodianName': 'Sara Ali',
    'department': 'Facilities',
    'status': 'Active',
    'criticality': 'High',
    'manufacturer': 'Cummins',
    'nextMaintenanceDate': '2026-12-01T00:00:00Z',
    'createdAt': '2026-10-01T08:00:00Z',
  },
  {
    'id': '6650a1b2c3d4e5f600000002',
    'assetRegistrationId': 'AR000002',
    'assetName': 'Chiller Unit 2',
    'assetTag': 'TAG-0002',
    'imageUrl': null,
    'category': 'HVAC',
    'assetType': 'Chiller',
    'siteName': 'Main Site',
    'buildingName': 'Block B',
    'floorName': 'Roof',
    'locationPath': 'UAE > Main Site > Block B > Roof',
    'custodianUserId': null,
    'custodianName': null,
    'department': 'Facilities',
    'status': 'Under Maintenance',
    'criticality': 'Critical',
    'manufacturer': 'Carrier',
    'createdAt': '2026-09-30T08:00:00Z',
  },
];

Map<String, dynamic> sampleRegistration() => {
  'id': '6650a1b2c3d4e5f600000001',
  'assetRegistrationId': 'AR000001',
  'basicInformation': {
    'assetName': 'Diesel Generator 500 kVA',
    'assetTag': 'TAG-0001',
    'barcode': '8901234567890',
    'rfidTagId': 'E2000017221101441890ABCD',
    'model': 'C500 D5',
    'manufacturer': 'Cummins',
    'serialNumber': 'SN-77821',
    'status': 'Active',
    'condition': 'Good',
    'criticality': 'High',
    'description': 'Standby generator',
    'images': ['http://localhost:5300/uploads/asset-images/gen.jpg'],
    'nfcUid': '04A224B2C35E80',
  },
  'classification': {
    'category': 'Machinery & Equipment',
    'subCategory': 'Power Generation',
    'assetType': 'Generator',
    'assetSubType': null,
    'functionPurpose': 'Backup Power',
    'criticality': 'High',
    'department': 'Facilities',
    'costCenter': 'CC-100',
    'businessUnit': null,
    'taggingMethod': 'RFID',
    'complianceCategory': 'Electrical Safety',
    'lifecycleStage': 'In Use',
    'keywords': ['power', 'standby'],
  },
  'locationAssignment': {
    'location': {
      'projectId': null,
      'countryId': 'AE',
      'countryName': 'UAE',
      'siteId': 'S1',
      'siteName': 'Main Site',
      'buildingId': 'B1',
      'buildingName': 'Block A',
      'floorId': 'F1',
      'floorName': 'Ground',
      'zoneId': null,
      'zoneName': null,
      'roomId': null,
      'roomName': null,
      'locationPath': 'UAE > Main Site > Block A > Ground',
      'latitude': 25.2,
      'longitude': 55.3,
    },
    'assignment': {
      'custodianDepartment': 'Facilities',
      'assignedToUserId': 'u-100',
      'assignedToName': 'Sara Ali',
      'ownershipType': 'Company Owned',
      'costCenter': 'CC-100',
      'responsibleTeam': 'Electrical',
      'assignmentStartDate': '2026-10-01T00:00:00Z',
      'assignmentEndDate': null,
      'isCurrent': true,
    },
  },
  'purchaseWarranty': {
    'purchase': {
      'purchaseOrderNumber': 'PO-2026-001',
      'invoiceNumber': 'INV-9',
      'supplierVendor': 'Al Futtaim',
      'manufacturer': 'Cummins',
      'purchaseDate': '2026-09-01T00:00:00Z',
      'deliveryDate': '2026-09-10T00:00:00Z',
      'purchaseCost': 100000,
      'quantity': 1,
      'quantityUnit': 'Unit(s)',
      'currency': 'AED - UAE Dirham',
      'taxPercent': 5,
      'totalCost': 105000,
      'paymentTerms': '30 Days',
      'procurementMethod': 'Tender',
      'projectReference': null,
      'remarks': null,
    },
    'documents': [
      {
        'fileName': 'invoice.pdf',
        'url': 'http://localhost:5300/uploads/asset-documents/invoice.pdf',
        'contentType': 'application/pdf',
        'fileSize': 12000,
        'uploadedAt': '2026-10-01T08:00:00Z',
      },
    ],
    'warranty': {
      'warrantyType': 'Manufacturer Warranty',
      'warrantyStartDate': '2026-09-10T00:00:00Z',
      'warrantyEndDate': '2028-09-09T00:00:00Z',
      'warrantyPeriod': 2,
      'warrantyPeriodUnit': 'Year(s)',
      'amcIncluded': false,
      'supportCoverage': '24x7',
      'serviceProvider': 'Cummins Service',
      'warrantyReference': 'W-1',
    },
  },
  'additionalInformation': {
    'technical': {
      'specifications': [
        {'name': 'Power Rating', 'value': '500', 'unit': 'kVA'},
      ],
      'dimensionLength': 4.2,
      'dimensionWidth': 1.6,
      'dimensionHeight': 2.1,
      'dimensionUnit': 'm',
      'weight': 4200,
      'weightUnit': 'kg',
      'expectedLifespan': 15,
      'expectedLifespanUnit': 'Year(s)',
      'technicalRemarks': null,
    },
    'operational': {
      'operatingHoursPerDay': 2,
      'operatingHoursUnit': 'Hours',
      'operatingShift': '24x7',
      'utilization': 'Standby',
      'maintenanceFrequency': 3,
      'maintenanceFrequencyUnit': 'Months',
      'lastMaintenanceDate': '2026-09-01T00:00:00Z',
      'nextMaintenanceDate': '2026-12-01T00:00:00Z',
      'complianceStandards': ['ISO 8528'],
    },
    'customFields': [
      {'fieldName': 'Fuel Tank', 'fieldType': 'Text', 'value': '1000 L'},
    ],
    'attachments': [],
  },
  'createdBy': 'sara.ali',
  'createdAt': '2026-10-01T08:00:00Z',
  'updatedBy': null,
  'updatedAt': null,
  'clientId': 'C1',
  'tenantId': 'T1',
};

const sampleFilters = {
  'categories': ['HVAC', 'Machinery & Equipment'],
  'assetTypes': [
    {'assetType': 'Chiller', 'category': 'HVAC'},
    {'assetType': 'Generator', 'category': 'Machinery & Equipment'},
  ],
  'statuses': ['Active', 'Inactive', 'In Storage', 'Under Maintenance', 'In Repair', 'Out of Service', 'Disposed'],
  'locations': [
    {'id': 'AE', 'name': 'UAE', 'level': 'Country', 'path': 'UAE'},
    {'id': 'S1', 'name': 'Main Site', 'level': 'Site', 'path': 'UAE > Main Site'},
  ],
  'departments': ['Facilities'],
  'custodians': [
    {'userId': 'u-100', 'name': 'Sara Ali'},
  ],
  'criticalities': ['High', 'Critical'],
  'manufacturers': ['Carrier', 'Cummins'],
  'conditions': ['Good'],
};

const sampleOptions = {
  'basicInformation': {
    'statuses': ['Active', 'Inactive', 'In Storage', 'Under Maintenance', 'In Repair', 'Out of Service', 'Disposed'],
  },
  'classification': {
    'functionPurposes': ['Backup Power', 'Primary Power', 'Other'],
    'taggingMethods': ['Barcode', 'RFID', 'BLE', 'QR Code'],
    'complianceCategories': ['Electrical Safety', 'Not Applicable'],
    'lifecycleStages': ['Planned', 'In Use', 'Retired'],
  },
  'locationAssignment': {
    'ownershipTypes': ['Company Owned', 'Leased'],
  },
  'purchaseWarranty': {
    'quantityUnits': ['Unit(s)', 'Set(s)'],
    'currencies': ['AED - UAE Dirham', 'USD - US Dollar'],
    'paymentTerms': ['Advance', '30 Days'],
    'procurementMethods': ['Direct Purchase', 'Tender'],
    'warrantyTypes': ['Manufacturer Warranty', 'No Warranty'],
    'warrantyPeriodUnits': ['Day(s)', 'Month(s)', 'Year(s)'],
    'supportCoverages': ['24x7', 'None'],
  },
  'additionalInformation': {
    'powerRatingUnits': ['kW', 'kVA'],
    'voltageUnits': ['V', 'kV'],
    'frequencyUnits': ['Hz'],
    'phases': ['Single Phase', '3 Phase'],
    'fuelTypes': ['Diesel', 'Electric'],
    'capacityUnits': ['Liters'],
    'dimensionUnits': ['mm', 'm'],
    'weightUnits': ['kg'],
    'temperatureUnits': ['°C'],
    'ipRatings': ['IP54'],
    'noiseLevelUnits': ['dB'],
    'lifespanUnits': ['Month(s)', 'Year(s)'],
    'operatingHoursUnits': ['Hours'],
    'operatingShifts': ['24x7'],
    'utilizations': ['Primary', 'Standby'],
    'maintenanceFrequencyUnits': ['Days', 'Months'],
    'complianceStandards': ['ISO 8528'],
    'impactLevels': ['Low', 'High'],
    'customFieldTypes': ['Text', 'Number', 'Date', 'Dropdown', 'Yes/No'],
  },
};

const sampleImage = {
  'id': 'img1',
  'assetRegistrationId': 'AR000001',
  'assetName': 'Diesel Generator 500 kVA',
  'assetTag': 'TAG-0001',
  'imageName': 'gen',
  'imageType': 'Front View',
  'tags': ['front'],
  'location': 'UAE > Main Site > Block A > Ground',
  'remarks': null,
  'description': null,
  'fileName': 'gen.jpg',
  'fileUrl': 'http://localhost:5300/uploads/asset-images/gen.jpg',
  'contentType': 'image/jpeg',
  'fileSize': 200000,
  'width': 1600,
  'height': 1200,
  'resolution': '1600 x 1200',
  'uploadedBy': 'sara.ali',
  'uploadDate': '2026-10-01T08:00:00Z',
};

const sampleDocument = {
  'id': 'doc1',
  'assetRegistrationId': 'AR000001',
  'documentName': 'Operation Manual',
  'documentType': 'Manual',
  'lifecycleStage': 'In Use',
  'version': '1.0',
  'expiryDate': null,
  'description': null,
  'tags': [],
  'status': 'Active',
  'fileName': 'manual.pdf',
  'fileUrl': 'http://localhost:5300/uploads/asset-documents/manual.pdf',
  'contentType': 'application/pdf',
  'fileSize': 512000,
  'uploadedBy': 'sara.ali',
  'uploadDate': '2026-10-01T08:00:00Z',
};

const sampleComponentTree = [
  {
    'id': 'c1',
    'componentName': 'Engine',
    'componentTag': 'CMP-001',
    'status': 'Active',
    'lifecyclePercent': 20.5,
    'expectedReplacementDate': '2036-01-01T00:00:00Z',
    'children': [
      {
        'id': 'c2',
        'componentName': 'Fuel Pump',
        'componentTag': 'CMP-002',
        'status': 'Active',
        'lifecyclePercent': 40,
        'children': [],
      },
    ],
  },
];

const sampleCondition = {
  'id': 'ca1',
  'assetRegistrationId': 'AR000001',
  'assetName': 'Diesel Generator 500 kVA',
  'assetTag': 'TAG-0001',
  'assessmentDate': '2026-10-15T00:00:00Z',
  'assessedBy': 'sara.ali',
  'overallCondition': 'Good',
  'healthScore': 86,
  'physicalCondition': 'Good',
  'performance': 'Excellent',
  'safety': 'Good',
  'remarks': null,
  'createdBy': 'sara.ali',
  'createdAt': '2026-10-15T08:00:00Z',
};

const sampleCriticalityOptions = {
  'likelihoodRatings': ['Very Low', 'Low', 'Medium', 'High', 'Very High'],
  'consequenceRatings': ['Very Low', 'Low', 'Medium', 'High', 'Very High'],
  'criticalityLevels': ['Low', 'Medium', 'High', 'Critical'],
  'criteria': [
    {'name': 'Operational Impact', 'weight': 25},
    {'name': 'Safety Impact', 'weight': 20},
  ],
};

const sampleCategories = [
  {
    'id': 'cat1',
    'parentCategoryId': null,
    'name': 'Machinery & Equipment',
    'code': 'ME',
    'status': 'Active',
    'customFields': [],
    'attributes': [],
  },
  {
    'id': 'cat2',
    'parentCategoryId': 'cat1',
    'parentCategoryName': 'Machinery & Equipment',
    'name': 'Power Generation',
    'code': 'PG',
    'status': 'Active',
    'customFields': [],
    'attributes': [],
  },
];

const sampleTypes = [
  {
    'id': 't1',
    'categoryId': 'cat2',
    'categoryName': 'Power Generation',
    'typeName': 'Generator',
    'typeCode': 'GEN',
    'status': 'Active',
    'modelCount': 1,
  },
];

const sampleModels = [
  {
    'id': 'm1',
    'assetTypeId': 't1',
    'assetTypeName': 'Generator',
    'modelName': 'C500 D5',
    'modelCode': 'C500',
    'manufacturerName': 'Cummins',
    'status': 'Active',
  },
];

// ------------------------------------------------------------------ Master Data samples
// Shapes: docs/backend_ref/Services/MasterDataManagement/Api/A360.MasterDataManagement.Api/Contracts.

Map<String, Object?> _audit(String status) => {
  'createdBy': 'admin',
  'createdAt': '2026-09-01T08:00:00Z',
  'updatedBy': null,
  'updatedAt': null,
  'clientId': 'C1',
  'tenantId': 'T1',
  'status': status,
  'isDeleted': false,
};

Map<String, Object?> _category(
  String id,
  String name,
  String code, {
  Map<String, String>? parent,
  String status = 'Active',
}) => {
  'id': id,
  'categoryName': name,
  'code': code,
  'assetType': null,
  'description': null,
  'parentCategory': parent,
  'assets': const <Object?>[],
  'assetCount': 0,
  ..._audit(status),
};

final mdCategories = [
  _category('md-cat-1', 'Machinery & Equipment', 'MCH'),
  _category('md-cat-2', 'HVAC', 'HVAC'),
  // A child category (not offered in the Category dropdown) and an inactive one.
  _category('md-cat-4', 'Diesel Sets', 'DSL', parent: {'id': 'md-cat-1', 'name': 'Machinery & Equipment'}),
  _category('md-cat-3', 'Retired Category', 'OLD', status: 'Inactive'),
];

final mdSubCategories = [
  {
    'subCategoryId': 'md-sub-1',
    'subCategoryName': 'Power Generation',
    'code': 'PG',
    'categoryId': 'md-cat-1',
    'categoryName': 'Machinery & Equipment',
    'assetType': null,
    'description': null,
    'assets': const <Object?>[],
    'assetCount': 0,
    ..._audit('Active'),
  },
  {
    'subCategoryId': 'md-sub-2',
    'subCategoryName': 'Pumping',
    'code': 'PMP',
    'categoryId': 'md-cat-1',
    'categoryName': 'Machinery & Equipment',
    'assetType': 'Pump',
    'description': null,
    'assets': const <Object?>[],
    'assetCount': 0,
    ..._audit('Active'),
  },
];

Map<String, Object?> _type(String id, String name, String categoryId, String categoryName) => {
  'id': id,
  'assetTypeName': name,
  'code': name.toUpperCase(),
  'category': {'id': categoryId, 'name': categoryName},
  'assetClass': 'Fixed',
  'description': null,
  'depreciationMethod': 'Straight Line',
  'defaultLifetime': 10,
  ..._audit('Active'),
};

final mdAssetTypes = [
  _type('md-type-1', 'Generator', 'md-cat-1', 'Machinery & Equipment'),
  _type('md-type-2', 'Pump', 'md-cat-1', 'Machinery & Equipment'),
  _type('md-type-3', 'Chiller', 'md-cat-2', 'HVAC'),
];

final mdAssetModels = [
  {
    'id': 'md-model-1',
    'modelName': 'C500 D5',
    'modelCode': 'C500',
    'manufacturer': {'id': 'md-man-1', 'name': 'Cummins'},
    'assetType': {'id': 'md-type-1', 'name': 'Generator'},
    'category': {'id': 'md-cat-1', 'name': 'Machinery & Equipment'},
    'description': null,
    'lifecycle': 'Active',
    ..._audit('Active'),
  },
];

Map<String, Object?> _named(String nameKey, String id, String name, [Map<String, Object?> extra = const {}]) => {
  'id': id,
  nameKey: name,
  'code': id.toUpperCase(),
  ...extra,
  ..._audit('Active'),
};

final mdManufacturers = [
  _named('manufacturerName', 'md-man-1', 'Cummins', {'country': 'USA', 'models': const <Object?>[], 'modelCount': 0}),
  _named('manufacturerName', 'md-man-2', 'Carrier', {'country': 'USA', 'models': const <Object?>[], 'modelCount': 0}),
];

final mdConditions = [
  _named('conditionName', 'md-con-1', 'Excellent', {
    'type': 'Operational',
    'color': '#16A34A',
    'defaultCondition': false,
    'healthScore': 95,
  }),
  _named('conditionName', 'md-con-2', 'Good', {
    'type': 'Operational',
    'color': '#22C55E',
    'defaultCondition': true,
    'healthScore': 80,
  }),
  _named('conditionName', 'md-con-3', 'Needs Attention', {
    'type': 'Operational',
    'color': '#F59E0B',
    'defaultCondition': false,
    'healthScore': 50,
  }),
];

final mdCriticalities = [
  _named('criticalityName', 'md-crit-1', 'Low', {
    'riskLevel': 'Low',
    'maintenancePriority': 'P4',
    'color': '#3B82F6',
    'defaultCriticality': false,
  }),
  _named('criticalityName', 'md-crit-2', 'High', {
    'riskLevel': 'High',
    'maintenancePriority': 'P2',
    'color': '#EF4444',
    'defaultCriticality': true,
  }),
];

final mdDepartments = [
  _named('departmentName', 'md-dep-1', 'Facilities Management', {
    'businessUnit': {'id': 'md-bu-1', 'name': 'Head Office'},
  }),
  _named('departmentName', 'md-dep-2', 'Production'),
];

final mdBusinessUnits = [_named('businessUnitName', 'md-bu-1', 'Head Office')];
final mdSuppliers = [
  _named('supplierName', 'md-sup-1', 'Gulf Power Supplies LLC', {'category': 'Equipment', 'country': 'UAE'}),
];
final mdAmcVendors = [
  _named('amcVendorName', 'md-amc-1', 'CoolCare AMC', {
    'startDate': '2026-01-01',
    'endDate': '2026-12-31',
    'contractType': 'Comprehensive',
  }),
];
final mdServiceProviders = [
  _named('serviceProviderName', 'md-sp-1', 'FixIt Services', {'serviceType': 'Maintenance'}),
];
final mdTeams = [
  _named('teamName', 'md-team-1', 'Electrical Team', {
    'department': {'id': 'md-dep-1', 'name': 'Facilities Management'},
  }),
];
final mdShifts = [
  _named('shiftName', 'md-shift-1', 'Day Shift', {
    'shiftTime': 'Day',
    'startTime': '08:00',
    'endTime': '16:00',
    'duration': 8,
    'workingDays': ['Mon'],
  }),
];
final mdUoms = [
  _named('uomName', 'md-uom-1', 'Each', {'type': 'Count', 'symbol': 'ea', 'conversionFactor': 1}),
  _named('uomName', 'md-uom-2', 'Set', {'type': 'Count', 'symbol': 'set', 'conversionFactor': 1}),
];

final mdEmployees = [
  {
    'id': '6650a1b2c3d4e5f600000e01',
    'employeeName': 'Sara Ali',
    'employeeId': 'EMP-0042',
    'department': {'id': 'md-dep-1', 'name': 'Facilities Management'},
    'designation': 'Facilities Technician',
    'email': 'sara.ali@example.com',
    'phoneNumber': '+971500000001',
    ..._audit('Active'),
  },
];

Map<String, Object?> _node(
  String id,
  String name,
  String code,
  String type,
  String? parent, [
  List<Object?> children = const [],
]) => {
  'id': id,
  'locationName': name,
  'code': code,
  'type': type,
  'parentLocationId': parent,
  'status': 'Active',
  'children': children,
};

/// UAE > Main Site > Block A > (Ground > Zone 1 > Room 101 | First).
final mdLocationTree = [
  _node('loc-ae', 'UAE', 'AE', 'Country', null, [
    _node('loc-ms', 'Main Site', 'MS', 'Site', 'loc-ae', [
      _node('loc-ba', 'Block A', 'BLD-A', 'Building', 'loc-ms', [
        _node('loc-gf', 'Ground', 'BLD-A-GF', 'Floor', 'loc-ba', [
          _node('loc-z1', 'Zone 1', 'BLD-A-GF-Z1', 'Zone', 'loc-gf', [
            _node('loc-r101', 'Room 101', 'R101', 'Room', 'loc-z1'),
          ]),
        ]),
        _node('loc-f1', 'First', 'BLD-A-F1', 'Floor', 'loc-ba'),
      ]),
    ]),
  ]),
];
