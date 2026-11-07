import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/dashboard/dashboard_api.dart';
import 'package:asset360_mobile/data/api/dashboard/network_status_live.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';

export 'package:asset360_mobile/data/api/dashboard/dashboard_api.dart';
export 'package:asset360_mobile/data/api/dashboard/network_status_live.dart' show LiveConnection;

/// API mode Home dashboard: one provider per Dashboard service endpoint (DASHBOARD_BASE_URL).
/// Every Home card and drill-down watches its own provider, so one failing endpoint only breaks
/// its own section. [refreshDashboard] reloads them all (Home pull-to-refresh).

final dashboardApiProvider = Provider<DashboardApi>((ref) => DashboardApi(ref.watch(dashboardClientProvider)));

// ------------------------------------------------------------------ site filter

/// The Home site selector in API mode: null = All Sites, else a site name from the server's
/// asset overview (`byLocation` = asset site names). Every mobile endpoint accepts `site=`, so every
/// Home card and drill-down follows it.
class DashSiteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? site) => state = (site == null || site == allSites) ? null : site;

  static const allSites = 'All Sites';
}

final dashSiteProvider = NotifierProvider<DashSiteNotifier, String?>(DashSiteNotifier.new);

/// "All Sites" + the site names the server knows (from /asset-overview `byLocation`, "Others" left out).
final dashSitesProvider = FutureProvider<List<String>>((ref) async {
  final o = await ref.watch(dashAssetOverviewProvider((search: null, site: null)).future);
  return [
    DashSiteNotifier.allSites,
    for (final l in o.byLocation)
      if (l.label.isNotEmpty && l.label.toLowerCase() != 'others') l.label,
  ];
});

// ------------------------------------------------------------------ one call each

/// GET /mobile/home?site=: greeting, quick-action counts and the summary cards (null site = all).
final dashHomeProvider = FutureProvider.family<DashHome, String?>(
  (ref, site) => ref.watch(dashboardApiProvider).getHome(site: site),
);

/// GET /mobile/my-tasks?site=: the signed-in user's open tasks (all types; tabs filter on the phone).
final dashMyTasksProvider = FutureProvider.family<DashMyTasks, String?>(
  (ref, site) => ref.watch(dashboardApiProvider).getMyTasks(site: site),
);

/// Query of GET /mobile/asset-overview.
typedef DashOverviewQuery = ({String? search, String? site});

final dashAssetOverviewProvider = FutureProvider.family<DashAssetOverview, DashOverviewQuery>(
  (ref, q) => ref.watch(dashboardApiProvider).getAssetOverview(search: q.search, site: q.site),
);

/// Query of GET /mobile/maintenance-performance.
typedef DashMaintenanceQuery = ({int months, String? assetType, String? site});

final dashMaintenanceProvider = FutureProvider.autoDispose.family<DashMaintenance, DashMaintenanceQuery>(
  (ref, q) =>
      ref.watch(dashboardApiProvider).getMaintenancePerformance(months: q.months, assetType: q.assetType, site: q.site),
);

/// Query of GET /mobile/upcoming-activities (null = the server default: today + 29 days, every type).
typedef DashActivitiesQuery = ({DateTime? from, DateTime? to, String? type, String? site});

final dashActivitiesProvider = FutureProvider.autoDispose.family<DashActivities, DashActivitiesQuery>(
  (ref, q) =>
      ref.watch(dashboardApiProvider).getUpcomingActivities(from: q.from, to: q.to, type: q.type, site: q.site),
);

/// Query of GET /mobile/asset-locations.
typedef DashLocationsQuery = ({String? status, String? search, String? site});

final dashAssetLocationsProvider = FutureProvider.autoDispose.family<DashAssetLocations, DashLocationsQuery>(
  (ref, q) => ref.watch(dashboardApiProvider).getAssetLocations(status: q.status, search: q.search, site: q.site),
);

/// Query of GET /mobile/asset-health (top critical assets, 1–50).
typedef DashHealthQuery = ({int top, String? site});

final dashAssetHealthProvider = FutureProvider.autoDispose.family<DashAssetHealth, DashHealthQuery>(
  (ref, q) => ref.watch(dashboardApiProvider).getAssetHealth(top: q.top, site: q.site),
);

/// Query of GET /mobile/cost-summary.
typedef DashCostQuery = ({String period, int? year, String? site});

final dashCostSummaryProvider = FutureProvider.family<DashCostSummary, DashCostQuery>(
  (ref, q) => ref.watch(dashboardApiProvider).getCostSummary(period: q.period, year: q.year, site: q.site),
);

/// GET /network-status: the initial online / offline counts (the WebSocket updates them).
final networkStatusProvider = FutureProvider<NetworkStatusCounts>(
  (ref) => ref.watch(dashboardApiProvider).getNetworkStatus(),
);

/// GET /network-status/tags (Devices screen), highest record count first.
final networkTagsProvider = FutureProvider.autoDispose<List<TagRecordCount>>(
  (ref) => ref.watch(dashboardApiProvider).getNetworkStatusTags(),
);

// ------------------------------------------------------------------ paged lists

/// A paged list (Recent Alerts, Recent Assets): the pages loaded so far plus the reply's counts.
class DashPage<T, C> {
  const DashPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.counts,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<T> items;
  final int totalCount;
  final int page;

  /// The latest reply's tab counts.
  final C counts;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => items.length < totalCount;

  DashPage<T, C> copyWith({
    List<T>? items,
    int? totalCount,
    int? page,
    C? counts,
    bool? loadingMore,
    Object? Function()? loadMoreError,
  }) => DashPage(
    items: items ?? this.items,
    totalCount: totalCount ?? this.totalCount,
    page: page ?? this.page,
    counts: counts ?? this.counts,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError == null ? this.loadMoreError : loadMoreError(),
  );
}

/// Page 1 on build, [loadMore] appends the next page (de-duplicated by [keyOf]).
abstract class _DashPagedNotifier<T, C> extends AsyncNotifier<DashPage<T, C>> {
  static const pageSize = 20;

  Future<DashPage<T, C>> fetch(int page);
  String keyOf(T item);

  @override
  Future<DashPage<T, C>> build() => fetch(1);

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.loadingMore || !s.hasMore || state.isLoading) return;
    state = AsyncData(s.copyWith(loadingMore: true, loadMoreError: () => null));
    try {
      final next = await fetch(s.page + 1);
      final seen = {for (final i in s.items) keyOf(i)};
      state = AsyncData(
        s.copyWith(
          items: [...s.items, ...next.items.where((i) => seen.add(keyOf(i)))],
          totalCount: next.totalCount,
          page: s.page + 1,
          counts: next.counts,
          loadingMore: false,
          loadMoreError: () => null,
        ),
      );
    } catch (e) {
      state = AsyncData(s.copyWith(loadingMore: false, loadMoreError: () => e));
    }
  }
}

/// Query of GET /mobile/recent-alerts (severity null = all; days 1–90).
typedef DashAlertsQuery = ({String? severity, int days, String? site});

class DashAlertsNotifier extends _DashPagedNotifier<DashAlertItem, DashAlertCounts> {
  DashAlertsNotifier(this.query);

  final DashAlertsQuery query;

  @override
  Future<DashPage<DashAlertItem, DashAlertCounts>> fetch(int page) async {
    final r = await ref
        .read(dashboardApiProvider)
        .getRecentAlerts(
          severity: query.severity,
          days: query.days,
          site: query.site,
          page: page,
          pageSize: _DashPagedNotifier.pageSize,
        );
    return DashPage(items: r.items, totalCount: r.totalCount, page: page, counts: r.counts);
  }

  @override
  String keyOf(DashAlertItem item) => '${item.source}/${item.id}';
}

final dashAlertsProvider = AsyncNotifierProvider.autoDispose
    .family<DashAlertsNotifier, DashPage<DashAlertItem, DashAlertCounts>, DashAlertsQuery>(DashAlertsNotifier.new);

/// Query of GET /mobile/recent-assets (status = group key, null = all).
typedef DashRecentAssetsQuery = ({String? status, String? search, String? assetType, String? site});

class DashRecentAssetsNotifier extends _DashPagedNotifier<DashRecentAsset, List<DashBreakdownItem>> {
  DashRecentAssetsNotifier(this.query);

  final DashRecentAssetsQuery query;

  @override
  Future<DashPage<DashRecentAsset, List<DashBreakdownItem>>> fetch(int page) async {
    final r = await ref
        .read(dashboardApiProvider)
        .getRecentAssets(
          status: query.status,
          search: query.search,
          assetType: query.assetType,
          site: query.site,
          page: page,
          pageSize: _DashPagedNotifier.pageSize,
        );
    return DashPage(items: r.items, totalCount: r.totalCount, page: page, counts: r.counts);
  }

  @override
  String keyOf(DashRecentAsset item) => item.assetRegistrationId;
}

final dashRecentAssetsProvider = AsyncNotifierProvider.autoDispose
    .family<DashRecentAssetsNotifier, DashPage<DashRecentAsset, List<DashBreakdownItem>>, DashRecentAssetsQuery>(
      DashRecentAssetsNotifier.new,
    );

// ------------------------------------------------------------------ live devices

/// Live Devices card: the latest counts (REST first, then every WebSocket message) and the
/// connection state ("Live" dot while connected).
class LiveDevicesState {
  const LiveDevicesState({this.counts, this.connection = LiveConnection.stopped});

  final NetworkStatusCounts? counts;
  final LiveConnection connection;

  bool get live => connection == LiveConnection.connected;
}

/// Owns the [NetworkStatusSocket]; Home's Live Devices card calls [setActive] when it becomes
/// visible / hidden and when the app goes to the background / comes back.
class LiveDevicesNotifier extends Notifier<LiveDevicesState> {
  NetworkStatusSocket? _socket;

  /// Tests replace the connector / scheduler.
  static LiveSocketConnector? debugConnector;
  static LiveScheduler? debugScheduler;

  @override
  LiveDevicesState build() {
    ref.onDispose(() => _socket?.stop());
    // REST counts first; WebSocket messages replace them.
    ref.listen(networkStatusProvider, (_, next) {
      final v = next.value;
      if (v != null && state.counts == null) state = LiveDevicesState(counts: v, connection: state.connection);
    }, fireImmediately: true);
    return const LiveDevicesState();
  }

  NetworkStatusSocket _create() {
    final auth = ref.read(authProvider.notifier);
    return NetworkStatusSocket(
      uri: DashboardApi.liveUri(kDashboardBaseUrl),
      token: auth.validAccessToken,
      connect: debugConnector,
      schedule: debugScheduler,
      // The socket may still report while the provider is being disposed (stop() is async).
      onCounts: (c) {
        if (ref.mounted) state = LiveDevicesState(counts: c, connection: state.connection);
      },
      onConnection: (s) {
        if (ref.mounted) state = LiveDevicesState(counts: state.counts, connection: s);
      },
    );
  }

  void setActive(bool active) {
    if (!apiMode || dashboardConfigProblem != null) return;
    if (active) {
      (_socket ??= _create()).start();
    } else {
      _socket?.stop();
    }
  }
}

final liveDevicesProvider = NotifierProvider<LiveDevicesNotifier, LiveDevicesState>(LiveDevicesNotifier.new);

/// Every dashboard provider (family providers invalidate all their queries).
final List<ProviderOrFamily> dashboardProviders = [
  dashHomeProvider,
  dashMyTasksProvider,
  dashAssetOverviewProvider,
  dashMaintenanceProvider,
  dashActivitiesProvider,
  dashAssetHealthProvider,
  dashCostSummaryProvider,
  dashRecentAssetsProvider,
  dashAlertsProvider,
  dashAssetLocationsProvider,
  networkStatusProvider,
  networkTagsProvider,
];

/// Pull-to-refresh on Home: reload every dashboard section (each one shows its own shimmer).
void refreshDashboard(WidgetRef ref) {
  for (final p in dashboardProviders) {
    ref.invalidate(p);
  }
}
