import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/assets/asset_api_models.dart';
import 'package:asset360_mobile/data/api/assets/json_read.dart';

export 'package:asset360_mobile/data/api/assets/asset_api_models.dart';

/// Every Asset service call (API_BASE_URL, docs/backend_ref/Services/Asset/Api/…/Endpoints).
/// Errors come out as [ApiException]: 400 → `fieldErrors` keyed by the server's path
/// ("AssetName", "Purchase.PurchaseCost", on submit "BasicInformation.AssetName"), 404 / 409 →
/// the server's `{"message"}`.
class AssetsApi {
  const AssetsApi(this.client);

  final ApiClient client;

  static const registrations = '/api/asset-registrations';
  static const drafts = '$registrations/drafts';

  /// Draft step endpoints, by the app's step index (0 = Basic Information … 4 = Additional).
  static const stepPaths = [
    'basic-information',
    'classification',
    'location-assignment',
    'purchase-warranty',
    'additional-information',
  ];

  // ---------------------------------------------------------------- registered assets

  /// GET /api/asset-registrations (page from 1; pageSize ≤ 200).
  Future<AssetListPage> list(AssetListQuery query, {int page = 1, int pageSize = AssetListQuery.pageSize}) async {
    final res = await client.get<Object?>(
      registrations,
      query: query.toQuery(page: page, pageSize: pageSize),
    );
    return AssetListPage.fromJson(res.data);
  }

  /// GET /api/asset-registrations/filters.
  Future<AssetListFilters> filters() async =>
      AssetListFilters.fromJson((await client.get<Object?>('$registrations/filters')).data);

  /// GET /api/asset-registrations/{assetRegistrationId} (404 when unknown).
  Future<AssetRegistration> get(String assetRegistrationId) async => AssetRegistration.fromJson(
    jMap((await client.get<Object?>('$registrations/${Uri.encodeComponent(assetRegistrationId)}')).data),
  );

  /// GET /api/asset-registrations/lookup?code=&type= — exact, case-insensitive match on asset tag,
  /// barcode (also QR), RFID tag ID, NFC UID or registration ID. Null when nothing matches (404).
  /// A code matching several assets is a 409 (thrown, with the server's message).
  Future<AssetLookupResult?> lookup(String code, {String? type}) async {
    try {
      final res = await client.get<Object?>('$registrations/lookup', query: {'code': code.trim(), 'type': ?type});
      return AssetLookupResult.fromJson(res.data);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }

  /// GET /api/asset-registrations/options (fixed dropdowns of the five steps).
  Future<RegistrationOptions> options() async =>
      RegistrationOptions.fromJson((await client.get<Object?>('$registrations/options')).data);

  // ---------------------------------------------------------------- drafts

  /// POST /api/asset-registrations/drafts (step 1). Returns the draft with its new
  /// assetRegistrationId ("AR000123"). 409 when the asset tag is taken.
  Future<AssetRegistration> createDraft(AssetBasicInformation basic, {bool saveAsDraft = false}) async {
    final res = await client.post<Object?>(
      drafts,
      data: {'basicInformation': basic.toJson()},
      query: {if (saveAsDraft) 'saveAsDraft': true},
    );
    return AssetRegistration.fromJson(jMap(res.data));
  }

  /// PUT `/api/asset-registrations/drafts/{id}/<step>` for the app's [step] (0 … 4) with that
  /// section's DTO. [saveAsDraft] skips the required-field checks on the server.
  Future<AssetRegistration> saveStep(String id, int step, AssetRegistration r, {bool saveAsDraft = false}) async {
    final body = switch (step) {
      0 => r.basicInformation.toJson(),
      1 => r.classification.toJson(),
      2 => r.locationAssignment.toJson(),
      3 => r.purchaseWarranty.toJson(),
      _ => r.additionalInformation.toJson(),
    };
    final res = await client.put<Object?>(
      '$drafts/${Uri.encodeComponent(id)}/${stepPaths[step.clamp(0, 4)]}',
      data: body,
      query: {if (saveAsDraft) 'saveAsDraft': true},
    );
    return AssetRegistration.fromJson(jMap(res.data));
  }

  /// GET /api/asset-registrations/drafts (the signed-in user's, newest first).
  Future<List<AssetRegistration>> listDrafts() async => [
    for (final d in jItems((await client.get<Object?>(drafts)).data)) AssetRegistration.fromJson(jMap(d)),
  ];

  Future<AssetRegistration> getDraft(String id) async =>
      AssetRegistration.fromJson(jMap((await client.get<Object?>('$drafts/${Uri.encodeComponent(id)}')).data));

  Future<void> deleteDraft(String id) => client.delete<Object?>('$drafts/${Uri.encodeComponent(id)}');

  /// POST …/drafts/{id}/submit → the registered asset (same id). 400 errors are keyed
  /// `<Step>.<Field>` (e.g. "Classification.Department").
  Future<AssetRegistration> submitDraft(String id) async =>
      AssetRegistration.fromJson(jMap((await client.post<Object?>('$drafts/${Uri.encodeComponent(id)}/submit')).data));

  // ---------------------------------------------------------------- images & documents

  /// GET /api/asset-images?assetRegistrationId= (pageSize ≤ 200).
  Future<PagedResult<AssetImageRecord>> images(String assetRegistrationId, {int pageSize = 200}) async =>
      PagedResult.fromJson(
        (await client.get<Object?>(
          '/api/asset-images',
          query: {'assetRegistrationId': assetRegistrationId, 'pageSize': pageSize},
        )).data,
        AssetImageRecord.fromJson,
      );

  /// POST /api/asset-images (one record per image per asset). Returns the created images.
  Future<List<AssetImageRecord>> createImages(CreateAssetImagesRequest request) async => [
    for (final i in jItems((await client.post<Object?>('/api/asset-images', data: request.toJson())).data))
      AssetImageRecord.fromJson(i),
  ];

  /// GET /api/asset-documents?assetRegistrationId= (also search, documentType, lifecycleStage, status).
  Future<PagedResult<AssetDocumentRecord>> documents(String assetRegistrationId, {int pageSize = 200}) async =>
      PagedResult.fromJson(
        (await client.get<Object?>(
          '/api/asset-documents',
          query: {'assetRegistrationId': assetRegistrationId, 'pageSize': pageSize},
        )).data,
        AssetDocumentRecord.fromJson,
      );

  /// POST /api/asset-documents.
  Future<List<AssetDocumentRecord>> createDocument(CreateAssetDocumentRequest request) async => [
    for (final d in jItems((await client.post<Object?>('/api/asset-documents', data: request.toJson())).data))
      AssetDocumentRecord.fromJson(d),
  ];

  // ---------------------------------------------------------------- components, condition, criticality

  /// GET /api/asset-registrations/{id}/components/tree (top-level components with children).
  Future<List<AssetComponentNode>> componentTree(String assetRegistrationId) async => [
    for (final n in jItems(
      (await client.get<Object?>('$registrations/${Uri.encodeComponent(assetRegistrationId)}/components/tree')).data,
    ))
      AssetComponentNode.fromJson(n),
  ];

  /// GET /api/asset-condition-assessments/current?assetRegistrationId= (null when none yet: 404).
  Future<AssetConditionAssessment?> currentCondition(String assetRegistrationId) => _orNull(
    () async => AssetConditionAssessment.fromJson(
      (await client.get<Object?>(
        '/api/asset-condition-assessments/current',
        query: {'assetRegistrationId': assetRegistrationId},
      )).data,
    ),
  );

  /// GET /api/asset-condition-assessments/ratings (Excellent … Critical).
  Future<List<String>> conditionRatings() async =>
      jStrings((await client.get<Object?>('/api/asset-condition-assessments/ratings')).data);

  /// POST /api/asset-condition-assessments.
  Future<AssetConditionAssessment> createConditionAssessment(CreateConditionAssessmentRequest request) async =>
      AssetConditionAssessment.fromJson(
        (await client.post<Object?>('/api/asset-condition-assessments', data: request.toJson())).data,
      );

  /// GET /api/asset-criticality/current?assetRegistrationId= (null when none yet: 404).
  Future<AssetCriticalityAssessment?> currentCriticality(String assetRegistrationId) => _orNull(
    () async => AssetCriticalityAssessment.fromJson(
      (await client.get<Object?>(
        '/api/asset-criticality/current',
        query: {'assetRegistrationId': assetRegistrationId},
      )).data,
    ),
  );

  /// GET /api/asset-criticality/options.
  Future<CriticalityOptions> criticalityOptions() async =>
      CriticalityOptions.fromJson((await client.get<Object?>('/api/asset-criticality/options')).data);

  // ---------------------------------------------------------------- categories, types, models

  /// GET /api/asset-categories (every level; Sub Categories have a parentCategoryId).
  Future<List<AssetCategoryItem>> categories() async => [
    for (final c in jItems((await client.get<Object?>('/api/asset-categories')).data)) AssetCategoryItem.fromJson(c),
  ];

  /// GET /api/asset-category-types (optionally of one category).
  Future<List<AssetCategoryType>> categoryTypes({String? categoryId}) async => [
    for (final t in jItems(
      (await client.get<Object?>('/api/asset-category-types', query: {'categoryId': ?categoryId})).data,
    ))
      AssetCategoryType.fromJson(t),
  ];

  /// GET /api/asset-models (optionally of one asset type).
  Future<List<AssetModelItem>> models({String? assetTypeId}) async => [
    for (final m in jItems((await client.get<Object?>('/api/asset-models', query: {'assetTypeId': ?assetTypeId})).data))
      AssetModelItem.fromJson(m),
  ];

  static Future<T?> _orNull<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }
}

final assetsApiProvider = Provider<AssetsApi>((ref) => AssetsApi(ref.watch(apiClientProvider)));
