import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/master_data/location_index.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_api.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_models.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';

export 'package:asset360_mobile/data/api/master_data/location_index.dart';
export 'package:asset360_mobile/data/api/master_data/master_data_api.dart';
export 'package:asset360_mobile/data/api/master_data/master_data_models.dart';

/// Loads Master Data lists. Each good reply is also written to the drift CachedResponses table;
/// when the device cannot reach the service (no network / timeout) the last saved reply is used
/// instead. Any other failure (4xx / 5xx / not configured) is passed on, and nothing local is
/// ever substituted.
class MasterDataRepository {
  MasterDataRepository(this.api, this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final MasterDataApi api;
  final AppDatabase db;
  final DateTime Function() _clock;

  /// The cache key of a request: the path plus its sorted query.
  static String keyOf(String path, Map<String, String> query) {
    if (query.isEmpty) return path;
    final keys = query.keys.toList()..sort();
    return '$path?${[for (final k in keys) '$k=${query[k]}'].join('&')}';
  }

  /// The JSON body of GET [path] (from the server, or the saved copy when offline).
  Future<Object?> fetch(String path, {Map<String, String> query = MasterDataApi.active}) async {
    final key = keyOf(path, query);
    try {
      final body = await api.get(path, query: query);
      try {
        await db.putCachedResponse(key, jsonEncode(body), _clock());
      } catch (_) {
        // The cache is best effort.
      }
      return body;
    } on ApiException catch (e) {
      if (e.kind != ApiErrorKind.noNetwork && e.kind != ApiErrorKind.timeout) rethrow;
      final cached = await _cached(key);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<Object?> _cached(String key) async {
    try {
      final row = await db.cachedResponse(key);
      return row == null ? null : jsonDecode(row.body);
    } catch (_) {
      return null;
    }
  }

  Future<List<T>> list<T extends MdEntry>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, String> query = MasterDataApi.active,
  }) async => mdParseList(await fetch(path, query: query), parse);
}

final masterDataApiProvider = Provider<MasterDataApi>((ref) => MasterDataApi(ref.watch(masterDataClientProvider)));

final masterDataRepositoryProvider = Provider<MasterDataRepository>(
  (ref) => MasterDataRepository(ref.watch(masterDataApiProvider), ref.watch(appDatabaseProvider)),
);

// ------------------------------------------------------------------ the lists
//
// Kept for the session (not auto-disposed). [refreshMasterData] reloads them: the Register Asset
// form calls it when it opens and on pull-to-refresh.

FutureProvider<List<T>> _listProvider<T extends MdEntry>(String path, T Function(Map<String, dynamic>) parse) =>
    FutureProvider<List<T>>((ref) => ref.watch(masterDataRepositoryProvider).list(path, parse));

/// Every active category (all levels; [MdCategory.isTopLevel] for the Category dropdown).
final mdCategoriesProvider = _listProvider(MasterDataApi.categories, MdCategory.fromJson);

/// The sub categories of a category id.
final mdSubCategoriesProvider = FutureProvider.family<List<MdSubCategory>, String>(
  (ref, categoryId) =>
      ref.watch(masterDataRepositoryProvider).list(MasterDataApi.subCategories(categoryId), MdSubCategory.fromJson),
);

/// Asset types of a (top-level) category id; null = every type.
final mdAssetTypesProvider = FutureProvider.family<List<MdAssetType>, String?>(
  (ref, categoryId) => ref
      .watch(masterDataRepositoryProvider)
      .list(
        MasterDataApi.assetTypes,
        MdAssetType.fromJson,
        query: {...MasterDataApi.active, 'categoryId': ?categoryId},
      ),
);

/// Asset models of an asset type id; null = every model.
final mdAssetModelsProvider = FutureProvider.family<List<MdAssetModel>, String?>(
  (ref, assetTypeId) => ref
      .watch(masterDataRepositoryProvider)
      .list(
        MasterDataApi.assetModels,
        MdAssetModel.fromJson,
        query: {...MasterDataApi.active, 'assetTypeId': ?assetTypeId},
      ),
);

final mdManufacturersProvider = _listProvider(MasterDataApi.manufacturers, MdManufacturer.fromJson);
final mdConditionsProvider = _listProvider(MasterDataApi.conditions, MdCondition.fromJson);
final mdCriticalitiesProvider = _listProvider(MasterDataApi.criticalities, MdCriticality.fromJson);
final mdDepartmentsProvider = _listProvider(MasterDataApi.departments, MdDepartment.fromJson);
final mdBusinessUnitsProvider = _listProvider(MasterDataApi.businessUnits, MdBusinessUnit.fromJson);
final mdSuppliersProvider = _listProvider(MasterDataApi.suppliers, MdSupplier.fromJson);
final mdAmcVendorsProvider = _listProvider(MasterDataApi.amcVendors, MdAmcVendor.fromJson);
final mdServiceProvidersProvider = _listProvider(MasterDataApi.serviceProviders, MdServiceProvider.fromJson);
final mdTeamsProvider = _listProvider(MasterDataApi.teams, MdTeam.fromJson);
final mdShiftsProvider = _listProvider(MasterDataApi.shifts, MdShift.fromJson);
final mdUomsProvider = _listProvider(MasterDataApi.uoms, MdUom.fromJson);

/// People for every person picker (Assigned To, custodian, check out): see MdEmployee.
final mdEmployeesProvider = _listProvider(MasterDataApi.employees, MdEmployee.fromJson);

/// GET /api/master-data-items/type/{masterType}, sorted by sortOrder then name.
final mdListItemsProvider = FutureProvider.family<List<MdListItem>, String>((ref, masterType) async {
  final items = await ref
      .watch(masterDataRepositoryProvider)
      .list(MasterDataApi.itemsOfType(masterType), MdListItem.fromJson, query: const {});
  return items..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder - b.sortOrder : a.name.compareTo(b.name));
});

/// The active location tree (Country → Site → Building → Floor → Zone → Room).
final mdLocationTreeProvider = FutureProvider<MdLocationIndex>(
  (ref) async => MdLocationIndex(
    MdLocationNode.parseTree(await ref.watch(masterDataRepositoryProvider).fetch(MasterDataApi.locationTree)),
  ),
);

// Space records with the extra facts (city, capacity, area) the IoT map phase will need.
final mdSitesProvider = _listProvider(MasterDataApi.sites, MdSite.fromJson);
final mdBuildingsProvider = _listProvider(MasterDataApi.buildings, MdSpace.fromJson);
final mdFloorsProvider = _listProvider(MasterDataApi.floors, MdSpace.fromJson);
final mdZonesProvider = _listProvider(MasterDataApi.zones, MdSpace.fromJson);

/// Everything above, for [refreshMasterData].
final List<ProviderOrFamily> _all = [
  mdCategoriesProvider,
  mdSubCategoriesProvider,
  mdAssetTypesProvider,
  mdAssetModelsProvider,
  mdManufacturersProvider,
  mdConditionsProvider,
  mdCriticalitiesProvider,
  mdDepartmentsProvider,
  mdBusinessUnitsProvider,
  mdSuppliersProvider,
  mdAmcVendorsProvider,
  mdServiceProvidersProvider,
  mdTeamsProvider,
  mdShiftsProvider,
  mdUomsProvider,
  mdEmployeesProvider,
  mdListItemsProvider,
  mdLocationTreeProvider,
  mdSitesProvider,
  mdBuildingsProvider,
  mdFloorsProvider,
  mdZonesProvider,
];

/// Whether a Master Data form was already opened in this session (the first open loads the lists;
/// later opens reload them).
class MasterDataSession {
  bool _opened = false;

  /// Marks a form as opened; true when one was opened before.
  bool reopened() {
    final before = _opened;
    _opened = true;
    return before;
  }
}

final masterDataSessionProvider = Provider<MasterDataSession>((ref) => MasterDataSession());

/// Reloads every Master Data list (screens keep showing the old values until the new ones arrive).
void refreshMasterData(WidgetRef ref) {
  for (final p in _all) {
    ref.invalidate(p);
  }
}
