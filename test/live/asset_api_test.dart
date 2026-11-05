import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/data/repositories/live_uploads.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_asset_backend.dart';

/// Contract-shaped JSON (docs/backend_ref/Services/Asset/Api/…/Contracts) → typed models.
void main() {
  late FakeAssetBackend backend;
  late AssetsApi api;

  setUp(() {
    backend = FakeAssetBackend();
    api = backend.api;
  });

  test('list: items, totalCount, paging and the status summary; query parameters as the server reads them', () async {
    final page = await api.list(
      const AssetListQuery(search: ' gen ', status: 'Active', sortBy: 'assetName', sortDirection: 'asc'),
    );
    expect(page.items.single.assetRegistrationId, 'AR000001');
    expect(page.items.single.locationPath, 'UAE > Main Site > Block A > Ground');
    expect(page.items.single.nextMaintenanceDate, DateTime.utc(2026, 12));
    expect(page.totalCount, 1);
    expect(page.summary.underMaintenance, 1);
    final q = backend.requests.last.uri.queryParameters;
    expect(q, {
      'search': 'gen',
      'status': 'Active',
      'sortBy': 'assetName',
      'sortDirection': 'asc',
      'page': '1',
      'pageSize': '20',
    });
  });

  test('registration response: all five sections, nfcUid, coordinates and server totals', () async {
    final r = await api.get('AR000001');
    expect(r.assetRegistrationId, 'AR000001');
    expect(r.basicInformation.nfcUid, '04A224B2C35E80');
    expect(r.classification.subCategory, 'Power Generation');
    expect(r.locationAssignment.location.latitude, 25.2);
    expect(r.locationAssignment.assignment.assignedToUserId, 'u-100');
    expect(r.purchaseWarranty.purchase.totalCost, 105000);
    expect(r.purchaseWarranty.purchase.totalCostPreview, 105000, reason: 'cost × (1 + tax %), quantity not a factor');
    expect(r.purchaseWarranty.documents.single.url, contains('/uploads/asset-documents/'));
    expect(r.additionalInformation.technical.specifications.single.unit, 'kVA');
    expect(r.additionalInformation.customFields.single.fieldName, 'Fuel Tank');
    // Sent back unchanged (the step DTOs).
    expect(r.basicInformation.toJson()['nfcUid'], '04A224B2C35E80');
    expect(r.locationAssignment.location.toJson()['longitude'], 55.3);
  });

  test('filters, options, categories, types, models, ratings, criticality options', () async {
    final f = await api.filters();
    expect(f.assetTypes.first.category, 'HVAC');
    expect(f.locations.last.path, 'UAE > Main Site');
    expect(f.custodians.single.userId, 'u-100');
    final o = await api.options();
    expect(o.taggingMethods, contains('QR Code'));
    expect(o.warrantyPeriodUnits, ['Day(s)', 'Month(s)', 'Year(s)']);
    expect(o.additional('fuelTypes'), contains('Diesel'));
    expect((await api.categories()).last.parentCategoryId, 'cat1');
    expect((await api.categoryTypes(categoryId: 'cat2')).single.typeName, 'Generator');
    expect(backend.requests.last.uri.queryParameters['categoryId'], 'cat2');
    expect((await api.models()).single.manufacturerName, 'Cummins');
    expect(await api.conditionRatings(), hasLength(5));
    expect((await api.criticalityOptions()).criteria.first.weight, 25);
  });

  test('images, documents, component tree, current condition; 404 "none yet" reads as null', () async {
    expect((await api.images('AR000001')).items.single.resolution, '1600 x 1200');
    expect(backend.requests.last.uri.queryParameters['assetRegistrationId'], 'AR000001');
    expect((await api.documents('AR000001')).items.single.documentType, 'Manual');
    final tree = await api.componentTree('AR000001');
    expect(tree.single.children.single.componentName, 'Fuel Pump');
    expect(tree.single.count, 2);
    expect((await api.currentCondition('AR000001'))!.healthScore, 86);
    expect(await api.currentCriticality('AR000001'), isNull);
  });

  test('lookup: found → asset + matchedBy (RFID too); not found → null; ambiguous → 409 message', () async {
    final hit = await api.lookup('e2000017221101441890abcd');
    expect(hit!.matchedBy, 'rfid');
    expect(hit.asset.assetRegistrationId, 'AR000001');
    expect(await api.lookup('NOPE'), isNull);
    backend.on(
      'GET',
      '/api/asset-registrations/lookup',
      (_) => const FakeReply(409, {
        'message': "The scanned code 'X' matches more than one asset.",
        'assetRegistrationIds': ['AR1', 'AR2'],
      }),
    );
    await expectLater(
      api.lookup('X'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('more than one'))),
    );
  });

  test('drafts: create → step PUT (?saveAsDraft) → submit; 400 field errors and 409 duplicate tag', () async {
    backend.on(
      'POST',
      '/api/asset-registrations/drafts',
      (o) => FakeReply(201, {...sampleRegistration(), 'assetRegistrationId': 'AR000009', 'currentStep': 1}),
    );
    backend.on(
      'PUT',
      '/api/asset-registrations/drafts/AR000009/classification',
      (o) => FakeReply(200, {...sampleRegistration(), 'assetRegistrationId': 'AR000009', 'currentStep': 2}),
    );
    final d = await api.createDraft(AssetBasicInformation(assetName: 'X', assetTag: 'T-1'));
    expect(d.assetRegistrationId, 'AR000009');
    expect(d.currentStep, 1);
    expect((backend.requests.last.data as Map)['basicInformation']['assetTag'], 'T-1');
    final saved = await api.saveStep('AR000009', 1, d, saveAsDraft: true);
    expect(saved.currentStep, 2);
    expect(backend.requests.last.uri.queryParameters['saveAsDraft'], 'true');
    expect((backend.requests.last.data as Map).containsKey('taggingMethod'), isTrue);

    backend.on(
      'PUT',
      '/api/asset-registrations/drafts/AR000009/purchase-warranty',
      (_) => const FakeReply(400, {
        'title': 'One or more validation errors occurred.',
        'errors': {
          'Purchase.PurchaseCost': ['PurchaseCost is required'],
        },
      }),
    );
    await expectLater(
      api.saveStep('AR000009', 3, d),
      throwsA(
        isA<ApiException>().having((e) => e.fieldErrors['Purchase.PurchaseCost'], 'field', 'PurchaseCost is required'),
      ),
    );
    backend.on(
      'POST',
      '/api/asset-registrations/drafts',
      (_) => const FakeReply(409, {'message': "An asset with tag 'T-1' is already registered."}),
    );
    await expectLater(
      api.createDraft(AssetBasicInformation(assetTag: 'T-1')),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.conflict)
            .having((e) => e.message, 'm', contains("'T-1'")),
      ),
    );
  });

  test('uploader: rejects other types before any request; uploads file + category, then the record', () async {
    final c = liveContainer(backend);
    addTearDown(c.dispose);
    final up = c.read(assetUploaderProvider);
    await expectLater(
      up.upload('/tmp/x.docx', category: AssetFileRules.documentCategory),
      throwsA(isA<ApiException>().having((e) => e.message, 'm', contains('JPG, PNG, WEBP or PDF'))),
    );
    expect(backend.calls('POST', '/api/media/upload'), isEmpty);
    expect(AssetFileRules.check('a.PNG', imageOnly: true), isNull);
    expect(AssetFileRules.check('a.pdf', imageOnly: true), isNotNull);
    expect(AssetFileRules.check('a.gif'), isNotNull, reason: 'the Media service accepts only jpg/jpeg/png/webp/pdf');
  });

  test('live list notifier: first page, load more appends, summary kept', () async {
    final many = [
      for (var i = 0; i < 25; i++) {...sampleAssets.first, 'assetRegistrationId': 'AR${i.toString().padLeft(6, '0')}'},
    ];
    backend.on('GET', '/api/asset-registrations', (o) {
      final page = int.parse(o.uri.queryParameters['page']!);
      return FakeReply(200, {
        'items': many.skip((page - 1) * 20).take(20).toList(),
        'totalCount': 25,
        'page': page,
        'pageSize': 20,
        'summary': sampleSummary,
      });
    });
    final c = liveContainer(backend);
    addTearDown(c.dispose);
    const q = AssetListQuery();
    final sub = c.listen(liveAssetListProvider(q), (_, _) {});
    addTearDown(sub.close);
    final first = await c.read(liveAssetListProvider(q).future);
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);
    await c.read(liveAssetListProvider(q).notifier).loadMore();
    final all = c.read(liveAssetListProvider(q)).value!;
    expect(all.items, hasLength(25));
    expect(all.hasMore, isFalse);
    expect(all.summary.total, 2);
  });

  test('ApiException keeps a 404 {"message"}', () {
    final e = ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/api/asset-registrations/X'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 404,
          data: {'message': "Asset registration 'X' was not found."},
        ),
      ),
    );
    expect(e.message, "Asset registration 'X' was not found.");
  });
}
