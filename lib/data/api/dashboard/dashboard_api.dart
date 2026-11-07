import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/assets/json_read.dart';
import 'package:asset360_mobile/data/api/dashboard/dashboard_models.dart';

export 'package:asset360_mobile/data/api/dashboard/dashboard_models.dart';

/// The read-only endpoints of the Dashboard service (DASHBOARD_BASE_URL, port 5470) the app uses.
/// Paths and query parameters: docs/backend_ref/Services/Dashboard/Api/A360.Dashboard.Api/Endpoints/
/// MobileDashboardEndpoints.cs and NetworkStatusEndpoints.cs. Only the parameters each endpoint
/// reads are sent; null / empty values are left out.
class DashboardApi {
  const DashboardApi(this.client, {this.utcOffsetMinutes});

  final ApiClient client;

  /// The phone's UTC offset ("today", calendar days, greeting). Sent to the endpoints that read it:
  /// home, maintenance-performance and upcoming-activities. Null = the device's current offset.
  final int? utcOffsetMinutes;

  static const mobile = '/api/dashboards/mobile';
  static const home = '$mobile/home';
  static const assetOverview = '$mobile/asset-overview';
  static const maintenancePerformance = '$mobile/maintenance-performance';
  static const upcomingActivities = '$mobile/upcoming-activities';
  static const recentAlerts = '$mobile/recent-alerts';
  static const assetLocations = '$mobile/asset-locations';
  static const assetHealth = '$mobile/asset-health';
  static const costSummary = '$mobile/cost-summary';
  static const recentAssets = '$mobile/recent-assets';
  static const networkStatus = '/api/dashboards/network-status';
  static const networkStatusTags = '$networkStatus/tags';

  /// WebSocket path: the counts on connect, then again whenever they change.
  static const networkStatusLive = '$networkStatus/live';

  /// Server limits (validation in the endpoints).
  static const maxPageSize = 100;
  static const maxTop = 50;

  int get _offset => utcOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;

  Future<Object?> _get(String path, [Map<String, Object?> query = const {}]) async {
    final q = <String, dynamic>{
      for (final e in query.entries)
        if (e.value != null && !(e.value is String && (e.value as String).trim().isEmpty)) e.key: e.value,
    };
    return (await client.get<Object?>(path, query: q.isEmpty ? null : q)).data;
  }

  /// `utcOffsetMinutes` only.
  Future<DashHome> getHome() async => DashHome.fromJson(await _get(home, {'utcOffsetMinutes': _offset}));

  /// `search` filters the group labels.
  Future<DashAssetOverview> getAssetOverview({String? search}) async =>
      DashAssetOverview.fromJson(await _get(assetOverview, {'search': search}));

  /// `months` (1–24, default 6), `assetType`, `site` (exact, case-insensitive), `utcOffsetMinutes`.
  Future<DashMaintenance> getMaintenancePerformance({int? months, String? assetType, String? site}) async =>
      DashMaintenance.fromJson(
        await _get(maintenancePerformance, {
          'months': months,
          'assetType': assetType,
          'site': site,
          'utcOffsetMinutes': _offset,
        }),
      );

  /// `from` / `to` (yyyy-MM-dd; default today + 29 days, at most a year), `type` (WorkOrder,
  /// Inspection, Approval; comma separated; null = all), `utcOffsetMinutes`.
  Future<DashActivities> getUpcomingActivities({DateTime? from, DateTime? to, String? type}) async =>
      DashActivities.fromJson(
        await _get(upcomingActivities, {'from': jDay(from), 'to': jDay(to), 'type': type, 'utcOffsetMinutes': _offset}),
      );

  /// `severity` (Critical / Warning / Info; null = all), `days` (1–90, default 7), `page`, `pageSize` (≤ 100).
  Future<DashRecentAlerts> getRecentAlerts({String? severity, int? days, int page = 1, int pageSize = 20}) async =>
      DashRecentAlerts.fromJson(
        await _get(recentAlerts, {'severity': severity, 'days': days, 'page': page, 'pageSize': pageSize}),
      );

  /// `status` (a status group key or a raw status), `search`.
  Future<DashAssetLocations> getAssetLocations({String? status, String? search}) async =>
      DashAssetLocations.fromJson(await _get(assetLocations, {'status': status, 'search': search}));

  /// `top` (1–50, default 5) critical assets.
  Future<DashAssetHealth> getAssetHealth({int? top}) async =>
      DashAssetHealth.fromJson(await _get(assetHealth, {'top': top}));

  /// `period` ([DashCostPeriod]), `year` (2000–2100).
  Future<DashCostSummary> getCostSummary({String? period, int? year}) async =>
      DashCostSummary.fromJson(await _get(costSummary, {'period': period, 'year': year}));

  /// `status` (group key; null / all = every status), `search`, `assetType`, `site`, `page`, `pageSize` (≤ 100).
  Future<DashRecentAssets> getRecentAssets({
    String? status,
    String? search,
    String? assetType,
    String? site,
    int page = 1,
    int pageSize = 20,
  }) async => DashRecentAssets.fromJson(
    await _get(recentAssets, {
      'status': status,
      'search': search,
      'assetType': assetType,
      'site': site,
      'page': page,
      'pageSize': pageSize,
    }),
  );

  Future<NetworkStatusCounts> getNetworkStatus() async => NetworkStatusCounts.fromJson(await _get(networkStatus));

  Future<List<TagRecordCount>> getNetworkStatusTags() async => TagRecordCount.list(await _get(networkStatusTags));

  /// ws:// (or wss:// for an https base) URL of [networkStatusLive] on [baseUrl].
  static Uri liveUri(String baseUrl) {
    final base = Uri.parse(baseUrl);
    final path = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '$path$networkStatusLive');
  }
}
