import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/assets/assets_api.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';

export 'package:asset360_mobile/data/api/assets/assets_api.dart';

/// The live Asset service data (apiMode = true). Screens read these providers; nothing here holds
/// mock data. Every provider is cheap to invalidate (pull-to-refresh = `ref.invalidate(...)`).

// ------------------------------------------------------------------ the asset list

/// One loaded list: the rows so far plus the server's paging and status summary.
class LiveAssetList {
  const LiveAssetList({
    required this.query,
    this.items = const [],
    this.totalCount = 0,
    this.page = 0,
    this.summary = AssetStatusSummary.empty,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final AssetListQuery query;
  final List<AssetListItem> items;
  final int totalCount;

  /// Last page loaded (0 = none).
  final int page;
  final AssetStatusSummary summary;
  final bool loadingMore;

  /// Why the last "load more" failed (the list keeps what it has; show Retry at the bottom).
  final Object? loadMoreError;

  bool get hasMore => items.length < totalCount;

  LiveAssetList copyWith({
    List<AssetListItem>? items,
    int? totalCount,
    int? page,
    AssetStatusSummary? summary,
    bool? loadingMore,
    Object? Function()? loadMoreError,
  }) => LiveAssetList(
    query: query,
    items: items ?? this.items,
    totalCount: totalCount ?? this.totalCount,
    page: page ?? this.page,
    summary: summary ?? this.summary,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError == null ? this.loadMoreError : loadMoreError(),
  );
}

/// GET /api/asset-registrations with infinite scroll: [AssetListQuery.pageSize] (20) per page.
/// `ref.watch(liveAssetListProvider(query))`; `.notifier.loadMore()` near the end of the list;
/// `ref.invalidate(liveAssetListProvider(query))` (or `refresh()`) for pull-to-refresh.
class LiveAssetListNotifier extends AsyncNotifier<LiveAssetList> {
  LiveAssetListNotifier(this.query);

  final AssetListQuery query;

  @override
  Future<LiveAssetList> build() async {
    final first = await ref.read(assetsApiProvider).list(query);
    return LiveAssetList(
      query: query,
      items: first.items,
      totalCount: first.totalCount,
      page: 1,
      summary: first.summary,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Loads the next page (no-op while loading or when everything is loaded).
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.loadingMore || !s.hasMore || state.isLoading) return;
    state = AsyncData(s.copyWith(loadingMore: true, loadMoreError: () => null));
    try {
      final next = await ref.read(assetsApiProvider).list(query, page: s.page + 1);
      final seen = {for (final i in s.items) i.assetRegistrationId};
      state = AsyncData(
        s.copyWith(
          items: [...s.items, ...next.items.where((i) => seen.add(i.assetRegistrationId))],
          totalCount: next.totalCount,
          page: s.page + 1,
          summary: next.summary,
          loadingMore: false,
          loadMoreError: () => null,
        ),
      );
    } catch (e) {
      state = AsyncData(s.copyWith(loadingMore: false, loadMoreError: () => ApiException.from(e)));
    }
  }
}

final liveAssetListProvider = AsyncNotifierProvider.autoDispose
    .family<LiveAssetListNotifier, LiveAssetList, AssetListQuery>(LiveAssetListNotifier.new);

/// Org-wide status summary (GET /api/asset-registrations?pageSize=1 → `summary`), for Home.
final assetSummaryProvider = FutureProvider<AssetStatusSummary>(
  (ref) async => (await ref.watch(assetsApiProvider).list(const AssetListQuery(), pageSize: 1)).summary,
);

/// The newest assets (createdAt desc), for Home → Recent Assets and pickers' first page.
final recentLiveAssetsProvider = FutureProvider<List<AssetListItem>>(
  (ref) async => (await ref.watch(assetsApiProvider).list(const AssetListQuery(), pageSize: 10)).items,
);

/// GET /api/asset-registrations/filters.
final assetListFiltersProvider = FutureProvider<AssetListFilters>((ref) => ref.watch(assetsApiProvider).filters());

/// The signed-in user's id from /me (custodianUserId for "My Assets"); null when /me sent none.
final myUserIdProvider = Provider<String?>((ref) {
  final s = ref.watch(authProvider);
  return s is AuthSignedIn ? s.user.id : null;
});

// ------------------------------------------------------------------ one asset

/// GET /api/asset-registrations/{assetRegistrationId}: all five sections.
final liveAssetProvider = FutureProvider.autoDispose.family<AssetRegistration, String>(
  (ref, id) => ref.watch(assetsApiProvider).get(id),
);

final liveAssetImagesProvider = FutureProvider.autoDispose.family<List<AssetImageRecord>, String>(
  (ref, id) async => (await ref.watch(assetsApiProvider).images(id)).items,
);

final liveAssetDocumentsProvider = FutureProvider.autoDispose.family<List<AssetDocumentRecord>, String>(
  (ref, id) async => (await ref.watch(assetsApiProvider).documents(id)).items,
);

final liveComponentTreeProvider = FutureProvider.autoDispose.family<List<AssetComponentNode>, String>(
  (ref, id) => ref.watch(assetsApiProvider).componentTree(id),
);

/// Null = no condition assessment yet.
final liveConditionProvider = FutureProvider.autoDispose.family<AssetConditionAssessment?, String>(
  (ref, id) => ref.watch(assetsApiProvider).currentCondition(id),
);

/// Null = no criticality assessment yet.
final liveCriticalityProvider = FutureProvider.autoDispose.family<AssetCriticalityAssessment?, String>(
  (ref, id) => ref.watch(assetsApiProvider).currentCriticality(id),
);

/// Everything shown for one asset; invalidate them all after an upload / condition update:
/// `for (final p in liveAssetProviders(id)) ref.invalidate(p);`
List<ProviderOrFamily> liveAssetProviders(String id) => [
  liveAssetProvider(id),
  liveAssetImagesProvider(id),
  liveAssetDocumentsProvider(id),
  liveComponentTreeProvider(id),
  liveConditionProvider(id),
  liveCriticalityProvider(id),
];

// ------------------------------------------------------------------ dropdowns

/// GET /api/asset-registrations/options (kept for the session).
final registrationOptionsProvider = FutureProvider<RegistrationOptions>(
  (ref) => ref.watch(assetsApiProvider).options(),
);

// Categories, types, models, criticality levels and the Master Management lists come from the
// Master Data service: lib/data/api/master_data/master_data_repository.dart.

/// GET /api/asset-condition-assessments/ratings: the values the Asset service VALIDATES for a
/// condition assessment (Update Condition), which may differ from Master Data /conditions.
final conditionRatingsProvider = FutureProvider<List<String>>((ref) => ref.watch(assetsApiProvider).conditionRatings());

// ------------------------------------------------------------------ favorites (device only)

/// Favorite assetRegistrationIds, kept on this device (shared_preferences); the backend has no
/// favorites. Survives a restart.
class LiveFavoritesNotifier extends Notifier<Set<String>> {
  static const storageKey = 'assets.favorites.v1';

  late Future<void> loaded;

  @override
  Set<String> build() {
    loaded = _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final ids = (await SharedPreferences.getInstance()).getStringList(storageKey);
      if (ids != null) state = {...ids, ...state};
    } catch (_) {
      // No storage: start empty.
    }
  }

  bool isFavorite(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
    try {
      await (await SharedPreferences.getInstance()).setStringList(storageKey, state.toList());
    } catch (_) {
      // Kept in memory only.
    }
  }
}

final liveFavoritesProvider = NotifierProvider<LiveFavoritesNotifier, Set<String>>(LiveFavoritesNotifier.new);
