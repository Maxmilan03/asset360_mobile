/// Typed, null-safe models of the Dashboard service's mobile endpoints (port 5470), field-for-field
/// the C# records in docs/backend_ref/Services/Dashboard/Api/A360.Dashboard.Api/Contracts/
/// MobileDashboardContracts.cs and NetworkStatusContracts.cs (System.Text.Json web defaults =
/// camelCase). A missing or wrongly typed value never throws: it reads as 0 / null / empty.
library;

import 'package:asset360_mobile/data/api/assets/json_read.dart';

double _d(Object? v) => jNum(v) ?? 0;
int _i(Object? v) => jInt(v) ?? 0;
String _s(Object? v) => jStr(v) ?? '';
List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) => [
  for (final e in jList(v))
    if (e is Map) parse(jMap(e)),
];

/// A server DateOnly ("2026-11-07") as a local calendar day.
DateTime? _day(Object? v) {
  final d = jDate(v);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

// ---------------------------------------------------------------- shared

/// MobileBreakdownItem: one slice of a breakdown (donut / legend row). [percent] is 0–100.
class DashBreakdownItem {
  const DashBreakdownItem({required this.key, required this.label, required this.count, required this.percent});

  factory DashBreakdownItem.fromJson(Map<String, dynamic> j) =>
      DashBreakdownItem(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), percent: _d(j['percent']));

  final String key;
  final String label;
  final int count;
  final double percent;

  static List<DashBreakdownItem> list(Object? v) => _list(v, DashBreakdownItem.fromJson);
}

/// MobileMetricValue: a value with its change against the previous period.
class DashMetricValue {
  const DashMetricValue({required this.value, required this.unit, this.changePercent, this.isImprovement});

  factory DashMetricValue.fromJson(Map<String, dynamic> j) => DashMetricValue(
    value: _d(j['value']),
    unit: _s(j['unit']),
    changePercent: jNum(j['changePercent']),
    isImprovement: j['isImprovement'] is bool ? j['isImprovement'] as bool : null,
  );

  final double value;
  final String unit;

  /// Null when there is nothing to compare.
  final double? changePercent;
  final bool? isImprovement;
}

/// MobileGeoPoint.
class DashGeoPoint {
  const DashGeoPoint(this.latitude, this.longitude);

  static DashGeoPoint? fromJson(Object? v) {
    if (v is! Map) return null;
    final lat = jNum(v['latitude']), lng = jNum(v['longitude']);
    return lat == null || lng == null ? null : DashGeoPoint(lat, lng);
  }

  final double latitude;
  final double longitude;
}

/// MobilePeriod.
class DashPeriod {
  const DashPeriod({required this.label, this.fromUtc, this.toUtc});

  factory DashPeriod.fromJson(Map<String, dynamic> j) =>
      DashPeriod(label: _s(j['label']), fromUtc: jDate(j['fromUtc']), toUtc: jDate(j['toUtc']));

  final String label;
  final DateTime? fromUtc;
  final DateTime? toUtc;
}

// ---------------------------------------------------------------- Home

/// GET /api/dashboards/mobile/home (MobileHomeResponse).
class DashHome {
  const DashHome({
    required this.greeting,
    required this.quickActions,
    required this.assetOverview,
    required this.maintenancePerformance,
    required this.upcomingActivities,
    required this.recentAlerts,
    required this.assetLocation,
    required this.assetHealth,
  });

  factory DashHome.fromJson(Object? body) {
    final j = jMap(body);
    return DashHome(
      greeting: DashGreeting.fromJson(jMap(j['greeting'])),
      quickActions: DashQuickActionCounts.fromJson(jMap(j['quickActions'])),
      assetOverview: DashAssetOverviewCard.fromJson(jMap(j['assetOverview'])),
      maintenancePerformance: DashMaintenanceCard.fromJson(jMap(j['maintenancePerformance'])),
      upcomingActivities: _list(j['upcomingActivities'], DashUpcomingSummary.fromJson),
      recentAlerts: _list(j['recentAlerts'], DashAlertItem.fromJson),
      assetLocation: DashAssetLocationCard.fromJson(jMap(j['assetLocation'])),
      assetHealth: DashAssetHealthCard.fromJson(jMap(j['assetHealth'])),
    );
  }

  final DashGreeting greeting;
  final DashQuickActionCounts quickActions;
  final DashAssetOverviewCard assetOverview;
  final DashMaintenanceCard maintenancePerformance;
  final List<DashUpcomingSummary> upcomingActivities;
  final List<DashAlertItem> recentAlerts;
  final DashAssetLocationCard assetLocation;
  final DashAssetHealthCard assetHealth;
}

/// MobileGreeting: "Good Morning, Raj — Here's what's happening today".
class DashGreeting {
  const DashGreeting({required this.salutation, this.userName, required this.message, this.generatedAtUtc});

  factory DashGreeting.fromJson(Map<String, dynamic> j) => DashGreeting(
    salutation: _s(j['salutation']),
    userName: jStr(j['userName']),
    message: _s(j['message']),
    generatedAtUtc: jDate(j['generatedAtUtc']),
  );

  final String salutation;
  final String? userName;
  final String message;
  final DateTime? generatedAtUtc;
}

/// MobileQuickActionCounts: badge counts for the four top tiles.
class DashQuickActionCounts {
  const DashQuickActionCounts({
    required this.openWorkOrders,
    required this.pendingInspections,
    required this.pendingApprovals,
    required this.criticalAlerts,
  });

  factory DashQuickActionCounts.fromJson(Map<String, dynamic> j) => DashQuickActionCounts(
    openWorkOrders: _i(j['openWorkOrders']),
    pendingInspections: _i(j['pendingInspections']),
    pendingApprovals: _i(j['pendingApprovals']),
    criticalAlerts: _i(j['criticalAlerts']),
  );

  final int openWorkOrders;
  final int pendingInspections;
  final int pendingApprovals;
  final int criticalAlerts;
}

/// MobileAssetOverviewCard.
class DashAssetOverviewCard {
  const DashAssetOverviewCard({required this.totalAssets, required this.breakdown});

  factory DashAssetOverviewCard.fromJson(Map<String, dynamic> j) =>
      DashAssetOverviewCard(totalAssets: _i(j['totalAssets']), breakdown: DashBreakdownItem.list(j['breakdown']));

  final int totalAssets;
  final List<DashBreakdownItem> breakdown;
}

/// MobileMaintenancePerformanceCard: planned share of work orders in the last [months] months.
class DashMaintenanceCard {
  const DashMaintenanceCard({required this.plannedPercent, required this.months, required this.breakdown});

  factory DashMaintenanceCard.fromJson(Map<String, dynamic> j) => DashMaintenanceCard(
    plannedPercent: _d(j['plannedPercent']),
    months: _i(j['months']),
    breakdown: DashBreakdownItem.list(j['breakdown']),
  );

  final double plannedPercent;
  final int months;
  final List<DashBreakdownItem> breakdown;

  int get total => breakdown.fold(0, (a, b) => a + b.count);
}

/// MobileUpcomingActivitySummary: "5 Work Orders — Today". [type] is WorkOrder, Inspection or Approval.
class DashUpcomingSummary {
  const DashUpcomingSummary({required this.type, required this.label, required this.count, required this.when});

  factory DashUpcomingSummary.fromJson(Map<String, dynamic> j) =>
      DashUpcomingSummary(type: _s(j['type']), label: _s(j['label']), count: _i(j['count']), when: _s(j['when']));

  final String type;
  final String label;
  final int count;
  final String when;
}

/// MobileAssetLocationCard: up to 50 pins of assets with coordinates.
class DashAssetLocationCard {
  const DashAssetLocationCard({required this.assetsWithLocation, this.center, required this.assets});

  factory DashAssetLocationCard.fromJson(Map<String, dynamic> j) => DashAssetLocationCard(
    assetsWithLocation: _i(j['assetsWithLocation']),
    center: DashGeoPoint.fromJson(j['center']),
    assets: _list(j['assets'], DashLocatedAsset.fromJson),
  );

  final int assetsWithLocation;
  final DashGeoPoint? center;
  final List<DashLocatedAsset> assets;
}

/// MobileAssetHealthCard.
class DashAssetHealthCard {
  const DashAssetHealthCard({required this.totalAssets, required this.healthyPercent, required this.breakdown});

  factory DashAssetHealthCard.fromJson(Map<String, dynamic> j) => DashAssetHealthCard(
    totalAssets: _i(j['totalAssets']),
    healthyPercent: _d(j['healthyPercent']),
    breakdown: DashBreakdownItem.list(j['breakdown']),
  );

  final int totalAssets;
  final double healthyPercent;

  /// healthy / warning / critical.
  final List<DashBreakdownItem> breakdown;
}

// ---------------------------------------------------------------- Asset overview

/// GET /api/dashboards/mobile/asset-overview?search= (MobileAssetOverviewResponse).
class DashAssetOverview {
  const DashAssetOverview({
    required this.totalAssets,
    required this.byStatus,
    required this.byType,
    required this.byLocation,
  });

  factory DashAssetOverview.fromJson(Object? body) {
    final j = jMap(body);
    return DashAssetOverview(
      totalAssets: _i(j['totalAssets']),
      byStatus: DashBreakdownItem.list(j['byStatus']),
      byType: DashBreakdownItem.list(j['byType']),
      byLocation: DashBreakdownItem.list(j['byLocation']),
    );
  }

  final int totalAssets;
  final List<DashBreakdownItem> byStatus;
  final List<DashBreakdownItem> byType;

  /// Grouped by the asset's site name.
  final List<DashBreakdownItem> byLocation;
}

// ---------------------------------------------------------------- Maintenance performance

/// GET /api/dashboards/mobile/maintenance-performance?months=&assetType=&site= .
class DashMaintenance {
  const DashMaintenance({
    required this.period,
    required this.plannedPercent,
    required this.counts,
    required this.breakdown,
    required this.trend,
    required this.mttr,
    required this.mtbf,
    required this.byAssetType,
  });

  factory DashMaintenance.fromJson(Object? body) {
    final j = jMap(body);
    return DashMaintenance(
      period: DashPeriod.fromJson(jMap(j['period'])),
      plannedPercent: _d(j['plannedPercent']),
      counts: DashWorkOrderCounts.fromJson(jMap(j['counts'])),
      breakdown: DashBreakdownItem.list(j['breakdown']),
      trend: _list(j['trend'], DashWorkOrderTrendPoint.fromJson),
      mttr: DashMetricValue.fromJson(jMap(j['mttr'])),
      mtbf: DashMetricValue.fromJson(jMap(j['mtbf'])),
      byAssetType: _list(j['byAssetType'], DashAssetTypeMaintenance.fromJson),
    );
  }

  final DashPeriod period;
  final double plannedPercent;
  final DashWorkOrderCounts counts;
  final List<DashBreakdownItem> breakdown;
  final List<DashWorkOrderTrendPoint> trend;
  final DashMetricValue mttr;
  final DashMetricValue mtbf;
  final List<DashAssetTypeMaintenance> byAssetType;
}

class DashWorkOrderCounts {
  const DashWorkOrderCounts({
    required this.total,
    required this.planned,
    required this.unplanned,
    required this.overdue,
  });

  factory DashWorkOrderCounts.fromJson(Map<String, dynamic> j) => DashWorkOrderCounts(
    total: _i(j['total']),
    planned: _i(j['planned']),
    unplanned: _i(j['unplanned']),
    overdue: _i(j['overdue']),
  );

  final int total, planned, unplanned, overdue;
}

/// One month of the Work Order Trend chart; [month] is yyyy-MM, [label] e.g. "Jan".
class DashWorkOrderTrendPoint {
  const DashWorkOrderTrendPoint({
    required this.month,
    required this.label,
    required this.planned,
    required this.unplanned,
    required this.overdue,
  });

  factory DashWorkOrderTrendPoint.fromJson(Map<String, dynamic> j) => DashWorkOrderTrendPoint(
    month: _s(j['month']),
    label: _s(j['label']),
    planned: _i(j['planned']),
    unplanned: _i(j['unplanned']),
    overdue: _i(j['overdue']),
  );

  final String month, label;
  final int planned, unplanned, overdue;
}

class DashAssetTypeMaintenance {
  const DashAssetTypeMaintenance({
    required this.assetType,
    required this.total,
    required this.planned,
    required this.unplanned,
    required this.overdue,
    required this.plannedPercent,
  });

  factory DashAssetTypeMaintenance.fromJson(Map<String, dynamic> j) => DashAssetTypeMaintenance(
    assetType: _s(j['assetType']),
    total: _i(j['total']),
    planned: _i(j['planned']),
    unplanned: _i(j['unplanned']),
    overdue: _i(j['overdue']),
    plannedPercent: _d(j['plannedPercent']),
  );

  final String assetType;
  final int total, planned, unplanned, overdue;
  final double plannedPercent;
}

// ---------------------------------------------------------------- Upcoming activities

/// GET /api/dashboards/mobile/upcoming-activities?from=&to=&type= (MobileUpcomingActivitiesResponse).
class DashActivities {
  const DashActivities({this.from, this.to, required this.totalCount, required this.days, required this.items});

  factory DashActivities.fromJson(Object? body) {
    final j = jMap(body);
    return DashActivities(
      from: _day(j['from']),
      to: _day(j['to']),
      totalCount: _i(j['totalCount']),
      days: _list(j['days'], DashActivityDay.fromJson),
      items: _list(j['items'], DashActivityItem.fromJson),
    );
  }

  final DateTime? from;
  final DateTime? to;
  final int totalCount;
  final List<DashActivityDay> days;
  final List<DashActivityItem> items;
}

/// One calendar day: activity counts per type.
class DashActivityDay {
  const DashActivityDay({
    required this.date,
    required this.workOrders,
    required this.inspections,
    required this.approvals,
    required this.total,
  });

  factory DashActivityDay.fromJson(Map<String, dynamic> j) => DashActivityDay(
    date: _day(j['date']),
    workOrders: _i(j['workOrders']),
    inspections: _i(j['inspections']),
    approvals: _i(j['approvals']),
    total: _i(j['total']),
  );

  final DateTime? date;
  final int workOrders, inspections, approvals, total;
}

/// The activity types the server sends ([DashActivityItem.type], `type=` filter values).
abstract final class DashActivityType {
  static const workOrder = 'WorkOrder';
  static const inspection = 'Inspection';
  static const approval = 'Approval';
  static const all = [workOrder, inspection, approval];
}

/// One activity in the list / calendar view.
class DashActivityItem {
  const DashActivityItem({
    required this.id,
    required this.type,
    required this.reference,
    required this.title,
    this.assetId,
    this.assetName,
    this.location,
    this.startUtc,
    this.endUtc,
    this.date,
    required this.status,
    this.priority,
    this.assignedTo,
  });

  factory DashActivityItem.fromJson(Map<String, dynamic> j) => DashActivityItem(
    id: _s(j['id']),
    type: _s(j['type']),
    reference: _s(j['reference']),
    title: _s(j['title']),
    assetId: jStr(j['assetId']),
    assetName: jStr(j['assetName']),
    location: jStr(j['location']),
    startUtc: jDate(j['startUtc']),
    endUtc: jDate(j['endUtc']),
    date: _day(j['date']),
    status: _s(j['status']),
    priority: jStr(j['priority']),
    assignedTo: jStr(j['assignedTo']),
  );

  final String id;

  /// [DashActivityType].
  final String type;
  final String reference;
  final String title;

  /// Asset tag (or the id the record holds).
  final String? assetId;
  final String? assetName;
  final String? location;
  final DateTime? startUtc;
  final DateTime? endUtc;

  /// The local day the server put it on (follows utcOffsetMinutes).
  final DateTime? date;
  final String status;
  final String? priority;
  final String? assignedTo;
}

// ---------------------------------------------------------------- Recent alerts

/// GET /api/dashboards/mobile/recent-alerts?severity=&days=&page=&pageSize= (MobileRecentAlertsResponse).
class DashRecentAlerts {
  const DashRecentAlerts({
    required this.counts,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.items,
  });

  factory DashRecentAlerts.fromJson(Object? body) {
    final j = jMap(body);
    return DashRecentAlerts(
      counts: DashAlertCounts.fromJson(jMap(j['counts'])),
      page: _i(j['page']),
      pageSize: _i(j['pageSize']),
      totalCount: _i(j['totalCount']),
      items: _list(j['items'], DashAlertItem.fromJson),
    );
  }

  final DashAlertCounts counts;
  final int page, pageSize, totalCount;
  final List<DashAlertItem> items;
}

class DashAlertCounts {
  const DashAlertCounts({required this.all, required this.critical, required this.warning, required this.info});

  factory DashAlertCounts.fromJson(Map<String, dynamic> j) =>
      DashAlertCounts(all: _i(j['all']), critical: _i(j['critical']), warning: _i(j['warning']), info: _i(j['info']));

  final int all, critical, warning, info;
}

/// Severities of [DashAlertItem.severity] (also the `severity=` filter).
abstract final class DashSeverity {
  static const critical = 'Critical';
  static const warning = 'Warning';
  static const info = 'Info';
}

/// One alert in the feed. [source] is IoT, WorkOrder, Inspection, SparePart or Maintenance.
class DashAlertItem {
  const DashAlertItem({
    required this.id,
    required this.source,
    required this.title,
    this.reference,
    this.assetId,
    this.assetName,
    required this.severity,
    this.status,
    this.occurredAtUtc,
  });

  factory DashAlertItem.fromJson(Map<String, dynamic> j) => DashAlertItem(
    id: _s(j['id']),
    source: _s(j['source']),
    title: _s(j['title']),
    reference: jStr(j['reference']),
    assetId: jStr(j['assetId']),
    assetName: jStr(j['assetName']),
    severity: _s(j['severity']),
    status: jStr(j['status']),
    occurredAtUtc: jDate(j['occurredAtUtc']),
  );

  final String id;
  final String source;
  final String title;
  final String? reference;

  /// Asset tag (or the registration id when the asset has no tag).
  final String? assetId;
  final String? assetName;

  /// [DashSeverity].
  final String severity;
  final String? status;
  final DateTime? occurredAtUtc;
}

// ---------------------------------------------------------------- Asset location

/// GET /api/dashboards/mobile/asset-locations?status=&search= (MobileAssetLocationResponse).
class DashAssetLocations {
  const DashAssetLocations({required this.totalCount, this.center, required this.byStatus, required this.assets});

  factory DashAssetLocations.fromJson(Object? body) {
    final j = jMap(body);
    return DashAssetLocations(
      totalCount: _i(j['totalCount']),
      center: DashGeoPoint.fromJson(j['center']),
      byStatus: DashBreakdownItem.list(j['byStatus']),
      assets: _list(j['assets'], DashLocatedAsset.fromJson),
    );
  }

  final int totalCount;
  final DashGeoPoint? center;
  final List<DashBreakdownItem> byStatus;
  final List<DashLocatedAsset> assets;
}

/// MobileAssetLocationItem: an asset with coordinates (map pin).
class DashLocatedAsset {
  const DashLocatedAsset({
    required this.assetRegistrationId,
    this.assetTag,
    this.assetName,
    this.model,
    this.assetType,
    this.status,
    required this.statusGroup,
    this.locationLabel,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });

  factory DashLocatedAsset.fromJson(Map<String, dynamic> j) => DashLocatedAsset(
    assetRegistrationId: _s(j['assetRegistrationId']),
    assetTag: jStr(j['assetTag']),
    assetName: jStr(j['assetName']),
    model: jStr(j['model']),
    assetType: jStr(j['assetType']),
    status: jStr(j['status']),
    statusGroup: _s(j['statusGroup']),
    locationLabel: jStr(j['locationLabel']),
    latitude: _d(j['latitude']),
    longitude: _d(j['longitude']),
    imageUrl: jStr(j['imageUrl']),
  );

  final String assetRegistrationId;
  final String? assetTag, assetName, model, assetType, status;

  /// operational / under-maintenance / out-of-service / retired / other.
  final String statusGroup;
  final String? locationLabel;
  final double latitude, longitude;
  final String? imageUrl;
}

// ---------------------------------------------------------------- Asset health

/// GET /api/dashboards/mobile/asset-health?top= (MobileAssetHealthResponse).
class DashAssetHealth {
  const DashAssetHealth({
    required this.totalAssets,
    required this.healthyPercent,
    required this.breakdown,
    required this.byAssetType,
    required this.byLocation,
    required this.criticalAssets,
  });

  factory DashAssetHealth.fromJson(Object? body) {
    final j = jMap(body);
    return DashAssetHealth(
      totalAssets: _i(j['totalAssets']),
      healthyPercent: _d(j['healthyPercent']),
      breakdown: DashBreakdownItem.list(j['breakdown']),
      byAssetType: _list(j['byAssetType'], DashHealthGroup.fromJson),
      byLocation: _list(j['byLocation'], DashHealthGroup.fromJson),
      criticalAssets: _list(j['criticalAssets'], DashCriticalAsset.fromJson),
    );
  }

  final int totalAssets;
  final double healthyPercent;
  final List<DashBreakdownItem> breakdown;
  final List<DashHealthGroup> byAssetType;
  final List<DashHealthGroup> byLocation;
  final List<DashCriticalAsset> criticalAssets;
}

class DashHealthGroup {
  const DashHealthGroup({
    required this.key,
    required this.total,
    required this.healthy,
    required this.warning,
    required this.critical,
    required this.healthyPercent,
  });

  factory DashHealthGroup.fromJson(Map<String, dynamic> j) => DashHealthGroup(
    key: _s(j['key']),
    total: _i(j['total']),
    healthy: _i(j['healthy']),
    warning: _i(j['warning']),
    critical: _i(j['critical']),
    healthyPercent: _d(j['healthyPercent']),
  );

  /// The asset type / site name.
  final String key;
  final int total, healthy, warning, critical;
  final double healthyPercent;
}

/// "Top Assets with Critical Health": the asset and the issue behind its score.
class DashCriticalAsset {
  const DashCriticalAsset({
    required this.assetRegistrationId,
    this.assetTag,
    this.assetName,
    this.assetType,
    this.healthScore,
    required this.issue,
  });

  factory DashCriticalAsset.fromJson(Map<String, dynamic> j) => DashCriticalAsset(
    assetRegistrationId: _s(j['assetRegistrationId']),
    assetTag: jStr(j['assetTag']),
    assetName: jStr(j['assetName']),
    assetType: jStr(j['assetType']),
    healthScore: jNum(j['healthScore']),
    issue: _s(j['issue']),
  );

  final String assetRegistrationId;
  final String? assetTag, assetName, assetType;
  final double? healthScore;
  final String issue;
}

// ---------------------------------------------------------------- Cost summary

/// Cost periods (`period=`): ytd (default; `year=` picks the year), year (`year=`), last-12-months.
abstract final class DashCostPeriod {
  static const ytd = 'ytd';
  static const year = 'year';
  static const last12Months = 'last-12-months';
}

/// GET /api/dashboards/mobile/cost-summary?period=&year= (MobileCostSummaryResponse).
class DashCostSummary {
  const DashCostSummary({
    required this.currency,
    required this.period,
    required this.totalCost,
    required this.previousPeriodCost,
    this.changePercent,
    required this.categories,
    required this.monthlyTrend,
    required this.byAssetType,
  });

  factory DashCostSummary.fromJson(Object? body) {
    final j = jMap(body);
    return DashCostSummary(
      currency: jStr(j['currency']) ?? 'AED',
      period: DashPeriod.fromJson(jMap(j['period'])),
      totalCost: _d(j['totalCost']),
      previousPeriodCost: _d(j['previousPeriodCost']),
      changePercent: jNum(j['changePercent']),
      categories: _list(j['categories'], DashCostCategory.fromJson),
      monthlyTrend: _list(j['monthlyTrend'], DashCostTrendPoint.fromJson),
      byAssetType: _list(j['byAssetType'], DashCostByAssetType.fromJson),
    );
  }

  final String currency;
  final DashPeriod period;
  final double totalCost;
  final double previousPeriodCost;
  final double? changePercent;
  final List<DashCostCategory> categories;
  final List<DashCostTrendPoint> monthlyTrend;
  final List<DashCostByAssetType> byAssetType;
}

/// [key] is maintenance (labour), operations (contractor / rental / freight) or spare-parts.
class DashCostCategory {
  const DashCostCategory({required this.key, required this.label, required this.amount, required this.percent});

  factory DashCostCategory.fromJson(Map<String, dynamic> j) =>
      DashCostCategory(key: _s(j['key']), label: _s(j['label']), amount: _d(j['amount']), percent: _d(j['percent']));

  final String key, label;
  final double amount, percent;
}

class DashCostTrendPoint {
  const DashCostTrendPoint({
    required this.month,
    required this.label,
    required this.maintenance,
    required this.operations,
    required this.spareParts,
    required this.total,
  });

  factory DashCostTrendPoint.fromJson(Map<String, dynamic> j) => DashCostTrendPoint(
    month: _s(j['month']),
    label: _s(j['label']),
    maintenance: _d(j['maintenance']),
    operations: _d(j['operations']),
    spareParts: _d(j['spareParts']),
    total: _d(j['total']),
  );

  final String month, label;
  final double maintenance, operations, spareParts, total;
}

class DashCostByAssetType {
  const DashCostByAssetType({required this.assetType, required this.amount, required this.percent});

  factory DashCostByAssetType.fromJson(Map<String, dynamic> j) =>
      DashCostByAssetType(assetType: _s(j['assetType']), amount: _d(j['amount']), percent: _d(j['percent']));

  final String assetType;
  final double amount, percent;
}

// ---------------------------------------------------------------- Recent assets

/// GET /api/dashboards/mobile/recent-assets?status=&search=&assetType=&site=&page=&pageSize= .
class DashRecentAssets {
  const DashRecentAssets({
    required this.counts,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.items,
  });

  factory DashRecentAssets.fromJson(Object? body) {
    final j = jMap(body);
    return DashRecentAssets(
      counts: DashBreakdownItem.list(j['counts']),
      page: _i(j['page']),
      pageSize: _i(j['pageSize']),
      totalCount: _i(j['totalCount']),
      items: _list(j['items'], DashRecentAsset.fromJson),
    );
  }

  /// "all" first, then the status groups (counts ignore the status filter).
  final List<DashBreakdownItem> counts;
  final int page, pageSize, totalCount;
  final List<DashRecentAsset> items;
}

class DashRecentAsset {
  const DashRecentAsset({
    required this.assetRegistrationId,
    this.assetTag,
    this.assetName,
    this.model,
    this.manufacturer,
    this.category,
    this.assetType,
    this.status,
    required this.statusGroup,
    this.locationLabel,
    this.imageUrl,
    this.createdAtUtc,
  });

  factory DashRecentAsset.fromJson(Map<String, dynamic> j) => DashRecentAsset(
    assetRegistrationId: _s(j['assetRegistrationId']),
    assetTag: jStr(j['assetTag']),
    assetName: jStr(j['assetName']),
    model: jStr(j['model']),
    manufacturer: jStr(j['manufacturer']),
    category: jStr(j['category']),
    assetType: jStr(j['assetType']),
    status: jStr(j['status']),
    statusGroup: _s(j['statusGroup']),
    locationLabel: jStr(j['locationLabel']),
    imageUrl: jStr(j['imageUrl']),
    createdAtUtc: jDate(j['createdAtUtc']),
  );

  final String assetRegistrationId;
  final String? assetTag, assetName, model, manufacturer, category, assetType, status;
  final String statusGroup;
  final String? locationLabel, imageUrl;
  final DateTime? createdAtUtc;
}

// ---------------------------------------------------------------- Network status

/// GET /api/dashboards/network-status and every WebSocket message of /network-status/live.
class NetworkStatusCounts {
  const NetworkStatusCounts({required this.totalOnline, required this.totalOffline});

  factory NetworkStatusCounts.fromJson(Object? body) {
    final j = jMap(body);
    return NetworkStatusCounts(totalOnline: _i(j['totalOnline']), totalOffline: _i(j['totalOffline']));
  }

  final int totalOnline;
  final int totalOffline;

  int get total => totalOnline + totalOffline;

  @override
  bool operator ==(Object other) =>
      other is NetworkStatusCounts && other.totalOnline == totalOnline && other.totalOffline == totalOffline;

  @override
  int get hashCode => Object.hash(totalOnline, totalOffline);
}

/// GET /api/dashboards/network-status/tags: one tag and how many records it has (highest first).
class TagRecordCount {
  const TagRecordCount({required this.tagId, required this.count, this.assetId, this.assetName});

  factory TagRecordCount.fromJson(Map<String, dynamic> j) => TagRecordCount(
    tagId: _s(j['tagId']),
    count: _i(j['count']),
    assetId: jStr(j['assetId']),
    assetName: jStr(j['assetName']),
  );

  final String tagId;
  final int count;

  /// The asset mapped to the tag (asset registration id), if any.
  final String? assetId;
  final String? assetName;

  static List<TagRecordCount> list(Object? body) => _list(jItems(body), TagRecordCount.fromJson);
}
