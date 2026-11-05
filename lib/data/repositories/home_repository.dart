import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/widgets/floor_plan.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/mock/home_mock.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/inspection.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/models/disposal.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/models/scan_record.dart';
import 'package:asset360_mobile/data/repositories/audits_repository.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:asset360_mobile/data/repositories/disposals_repository.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';

// ---------------------------------------------------------------- Quick actions

class QuickActionSetting {
  const QuickActionSetting(this.id, this.enabled);

  final String id;
  final bool enabled;
}

class QuickActionsNotifier extends Notifier<List<QuickActionSetting>> {
  @override
  List<QuickActionSetting> build() => [for (final a in defaultQuickActions) QuickActionSetting(a.$1, a.$2)];

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    state = list;
  }

  void toggle(String id) => state = [for (final a in state) a.id == id ? QuickActionSetting(a.id, !a.enabled) : a];

  void reset() => state = build();
}

final quickActionsProvider = NotifierProvider<QuickActionsNotifier, List<QuickActionSetting>>(QuickActionsNotifier.new);

/// How many quick actions fit on Home before "More Actions".
const homeQuickActionSlots = 7;

// ---------------------------------------------------------------- Recent assets

class RecentAssetsNotifier extends Notifier<List<String>> {
  /// API mode: none (Home → Recent Assets reads the server's newest assets).
  @override
  List<String> build() => apiMode ? [] : [...seedRecentAssetIds];

  /// Call when an asset is opened.
  void viewed(String id) => state = [id, ...state.where((x) => x != id)].take(5).toList();
}

final recentAssetsProvider = NotifierProvider<RecentAssetsNotifier, List<String>>(RecentAssetsNotifier.new);

// ---------------------------------------------------------------- Maintenance KPIs

class MaintenanceKpi {
  const MaintenanceKpi({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.description,
    required this.trend,
    required this.higherIsBetter,
  });

  final String key;
  final String label;
  final num value;

  /// "%" or "hrs".
  final String unit;
  final String description;
  final List<double> trend;
  final bool higherIsBetter;

  String get valueText => unit == '%' ? '$value%' : '$value';
}

final maintenanceKpisProvider = Provider<List<MaintenanceKpi>>((ref) {
  final o = ref.watch(orgSummaryProvider);
  return [
    MaintenanceKpi(
      key: 'pm',
      label: 'PM Compliance',
      value: o.pmCompliancePct,
      unit: '%',
      higherIsBetter: true,
      trend: kpiTrends['pm']!,
      description: 'Share of preventive maintenance work orders completed on or before their due date this month.',
    ),
    MaintenanceKpi(
      key: 'mttr',
      label: 'MTTR',
      value: o.mttrHours,
      unit: 'hrs',
      higherIsBetter: false,
      trend: kpiTrends['mttr']!,
      description: 'Mean Time To Repair: the average time from a breakdown being reported to the asset running again.',
    ),
    MaintenanceKpi(
      key: 'closure',
      label: 'WO Closure Rate',
      value: o.woClosurePct,
      unit: '%',
      higherIsBetter: true,
      trend: kpiTrends['closure']!,
      description: 'Share of work orders opened this month that were completed and closed.',
    ),
    MaintenanceKpi(
      key: 'downtime',
      label: 'Avg. Downtime',
      value: o.avgDowntimeHours,
      unit: 'hrs',
      higherIsBetter: false,
      trend: kpiTrends['downtime']!,
      description: 'Average unplanned downtime per critical asset this month.',
    ),
  ];
});

// ---------------------------------------------------------------- My Tasks

enum TaskKind { workOrder, inspection, approval }

/// One row in Home "My Tasks" (a WO, an inspection or an approval).
class MyTask {
  const MyTask({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.priority,
    this.due,
    this.assetId,
  });

  final TaskKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String location;
  final String priority;
  final DateTime? due;
  final String? assetId;
}

/// Everything Home shows, computed from the repositories and filtered by the selected site.
class HomeData {
  const HomeData({
    required this.site,
    required this.myWorkOrders,
    required this.inspectionsDueToday,
    required this.pendingApprovals,
    required this.criticalAlerts,
    required this.workOrderTasks,
    required this.inspectionTasks,
    required this.approvalTasks,
    required this.recentAlerts,
    required this.recentAssets,
  });

  final String site;

  /// Same number as Maintenance "My Work Orders" (the tile opens that tab).
  final int myWorkOrders;
  final int inspectionsDueToday;
  final int pendingApprovals;
  final int criticalAlerts;
  final List<MyTask> workOrderTasks;
  final List<MyTask> inspectionTasks;
  final List<MyTask> approvalTasks;
  final List<AlertItem> recentAlerts;
  final List<Asset> recentAssets;

  bool get filtered => site != 'All Sites';

  /// All = Work Orders + Inspections + Approvals, sorted by due time.
  List<MyTask> get allTasks {
    final all = [...workOrderTasks, ...inspectionTasks, ...approvalTasks];
    all.sort((a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)));
    return all;
  }
}

String _inspectionPriority(Inspection i) =>
    DemoClock.isOverdue(i.dueAt) || DemoClock.isToday(i.dueAt) ? 'High' : 'Medium';

final homeDataProvider = Provider<HomeData>((ref) {
  ref.watch(clockTickProvider); // "Due in …" and overdue status move with the clock
  final me = ref.watch(currentUserProvider).id;
  final site = ref.watch(sessionProvider.select((s) => s.site));
  final assets = ref.watch(assetsProvider);
  final byId = {for (final a in assets) a.id: a};
  bool atSite(String assetId) => site == 'All Sites' || byId[assetId]?.site == site;

  final wos = ref.watch(workOrdersProvider).where((w) => atSite(w.assetId)).toList();
  final inspections = ref.watch(inspectionsProvider).where((i) => atSite(i.assetId)).toList();
  final approvals = ref.watch(movementsProvider).toApprove(me).where((m) => atSite(m.assetId)).toList();
  final disposals = ref.watch(disposalsProvider).toApprove(me).where((d) => atSite(d.assetId)).toList();
  final alerts = ref.watch(alertsProvider).where((a) => atSite(a.assetId)).toList();

  MyTask woTask(WorkOrder w) => MyTask(
    kind: TaskKind.workOrder,
    id: w.id,
    title: w.id,
    subtitle: w.title,
    location: byId[w.assetId]?.location ?? '—',
    priority: w.priority,
    due: w.dueAt,
    assetId: w.assetId,
  );
  MyTask insTask(Inspection i) => MyTask(
    kind: TaskKind.inspection,
    id: i.id,
    title: i.id,
    subtitle: i.title,
    location: byId[i.assetId]?.location ?? '—',
    priority: _inspectionPriority(i),
    due: i.dueAt,
    assetId: i.assetId,
  );
  MyTask apprTask(MovementRequest m) => MyTask(
    kind: TaskKind.approval,
    id: m.id,
    title: m.id,
    subtitle: '${m.type} approval – ${byId[m.assetId]?.name ?? m.assetId}',
    location: '${m.from.name} → ${m.to.name}',
    priority: 'Medium',
    due: m.requiredDate,
    assetId: m.assetId,
  );

  MyTask disposalTask(DisposalRequest d) => MyTask(
    kind: TaskKind.approval,
    id: d.id,
    title: d.id,
    subtitle: 'Disposal approval – ${byId[d.assetId]?.name ?? d.assetId}',
    location: byId[d.assetId]?.location ?? '—',
    priority: 'Medium',
    due: d.requestedDate,
    assetId: d.assetId,
  );

  final myWos = wos.mine(me)..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  final myIns = inspections.mine(me)..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  final recent = [
    for (final id in ref.watch(recentAssetsProvider))
      if (byId[id] != null && atSite(id)) byId[id]!,
  ];

  return HomeData(
    site: site,
    myWorkOrders: wos.mine(me).length,
    inspectionsDueToday: inspections.dueToday.length,
    pendingApprovals: approvals.length + disposals.length,
    criticalAlerts: alerts.criticalRequiringAction.length,
    workOrderTasks: [for (final w in myWos) woTask(w)],
    inspectionTasks: [for (final i in myIns) insTask(i)],
    approvalTasks: [for (final m in approvals) apprTask(m), for (final d in disposals) disposalTask(d)],
    recentAlerts: alerts.latest.take(3).toList(),
    recentAssets: recent,
  );
});

// ---------------------------------------------------------------- Home drill-downs

/// The breakdown type of a detailed asset (one of [homeAssetTypes]).
String assetTypeGroup(Asset a) {
  final t = a.type.toLowerCase();
  return switch (a.category) {
    'IT Equipment' => 'IT Equipment',
    'HVAC' => 'HVAC',
    'Fire Safety' || 'Safety' => 'Fire Safety',
    'Electrical' => 'Electrical',
    'Plumbing' => 'Plumbing',
    'Production Equipment' => 'Production Equipment',
    'Material Handling Equipment' || 'Vehicles' => 'Vehicles',
    _ when t.contains('generator') => 'Generator',
    _ when t.contains('forklift') || t.contains('vehicle') => 'Vehicles',
    _ => 'Others',
  };
}

/// The site / building of a detailed asset (one of the [seedAssetsByLocation] names).
String assetLocationGroup(Asset a) {
  final l = a.location.toLowerCase();
  return switch (a.site) {
    'Dubai Office' => 'Dubai Office · Head Office',
    'Education City' when l.contains('admin building') => 'Education City · Admin Building',
    'Education City' => 'Education City · Admin Block',
    _ when l.contains('building a') => 'Dubai Factory · Building A',
    _ when l.contains('building b') => 'Dubai Factory · Building B',
    _ when l.contains('warehouse') || l.contains('storage') || l.contains('utility') =>
      'Dubai Factory · Main Warehouse',
    _ => 'Dubai Factory · Main Plant',
  };
}

/// Org-wide assets by type and by site / building (summary figures, kept in step with
/// registrations and deletions like [orgSummaryProvider]).
class AssetBreakdown {
  const AssetBreakdown({required this.byType, required this.byLocation});

  final List<AssetGroupStat> byType;
  final List<AssetGroupStat> byLocation;

  int get total => byType.fold(0, (a, s) => a + s.total);
  int band(HealthBand b) => byType.fold(0, (a, s) => a + s.count(b));
  double bandPct(HealthBand b) => total == 0 ? 0 : band(b) * 100 / total;
  AssetGroupStat? type(String name) => byType.firstWhereOrNull((s) => s.name == name);
  AssetGroupStat? location(String name) => byLocation.firstWhereOrNull((s) => s.name == name);
}

class AssetBreakdownNotifier extends Notifier<AssetBreakdown> {
  /// API mode: empty (the server has no by-type / by-location breakdown yet).
  @override
  AssetBreakdown build() => apiMode
      ? const AssetBreakdown(byType: [], byLocation: [])
      : const AssetBreakdown(byType: seedAssetsByType, byLocation: seedAssetsByLocation);

  void _bump(Asset a, int by) {
    final band = HealthBand.of(a.healthScore);
    List<AssetGroupStat> up(List<AssetGroupStat> l, String name) => [
      for (final s in l) s.name == name ? s.bump(band, by) : s,
    ];
    state = AssetBreakdown(
      byType: up(state.byType, assetTypeGroup(a)),
      byLocation: up(state.byLocation, assetLocationGroup(a)),
    );
  }

  void addAsset(Asset a) => _bump(a, 1);
  void removeAsset(Asset a) => _bump(a, -1);
}

final assetBreakdownProvider = NotifierProvider<AssetBreakdownNotifier, AssetBreakdown>(AssetBreakdownNotifier.new);

/// Detailed assets below Healthy with a known reason, worst first (Asset Health "Top Assets with Critical Health").
final criticalHealthAssetsProvider = Provider<List<(Asset, String)>>((ref) {
  final list = [
    for (final a in ref.watch(assetsProvider))
      if (healthReasons[a.id] != null && HealthBand.of(a.healthScore) != HealthBand.healthy) (a, healthReasons[a.id]!),
  ];
  list.sort((x, y) => x.$1.healthScore.compareTo(y.$1.healthScore));
  return list;
});

final maintenanceMonthsProvider = Provider<List<MaintenanceMonth>>((ref) => seedMaintenanceMonths());

/// "Last N Months" of [maintenanceMonthStarts] ending with the DemoClock month.
List<DateTime> lastMonths(int n) => maintenanceMonthStarts.sublist(maintenanceMonthStarts.length - n);

/// Cost Summary years, newest first: YTD 2026 (the org summary's 1.25M) and 2025.
final costYearsProvider = Provider<List<CostYear>>((ref) {
  final org = ref.watch(orgSummaryProvider);
  final prev2025Ytd = [
    for (final l in costMonthly2025.values) l.take(costMonthly2026.values.first.length).fold(0, (a, b) => a + b),
  ].fold(0, (a, b) => a + b);
  return [
    CostYear(
      label: 'YTD ${DemoClock.start.year}',
      year: DemoClock.start.year,
      categories: org.costs,
      monthly: costMonthly2026,
      byType: costByType2026,
      previousTotal: prev2025Ytd,
    ),
    CostYear(
      label: '2025',
      year: 2025,
      categories: costCategories2025,
      monthly: costMonthly2025,
      byType: costByType2025,
      previousTotal: costTotal2024,
    ),
  ];
});

/// First and last day shown in Upcoming Activities (21 Sep – 4 Oct 2026, around DemoClock).
final activityWindowStart = DateTime(2026, 9, 21);
final activityWindowEnd = DateTime(2026, 10, 5); // exclusive

bool _inWindow(DateTime d) => !d.isBefore(activityWindowStart) && d.isBefore(activityWindowEnd);

/// Upcoming Activities: work orders, inspections, audits and the user's approvals in the window,
/// sorted by start time.
final plannedActivitiesProvider = Provider<List<PlannedActivity>>((ref) {
  final me = ref.watch(currentUserProvider).id;
  final byId = {for (final a in ref.watch(assetsProvider)) a.id: a};
  String? place(String assetId) => byId[assetId]?.location;
  final list = <PlannedActivity>[];

  for (final w in ref.watch(workOrdersProvider)) {
    final hours = switch (w.workType) {
      'Breakdown' || 'Corrective' => 3,
      'Inspection' || 'Calibration' => 1,
      _ => 2,
    };
    final start = w.scheduledAt ?? w.dueAt.subtract(Duration(hours: hours));
    if (!_inWindow(start)) continue;
    list.add(
      PlannedActivity(
        kind: ActivityKind.workOrder,
        refId: w.id,
        title: w.title,
        assetId: w.assetId,
        location: place(w.assetId),
        start: start,
        end: start.add(Duration(hours: hours)),
        status: switch (w.status) {
          WoStatus.inProgress => 'In Progress',
          WoStatus.onHold => 'Pending',
          _ when !w.isActive => 'Completed',
          _ when w.scheduledAt != null || w.assigneeId != null => 'Scheduled',
          _ => 'Planned',
        },
        route: Routes.workOrder(w.id),
      ),
    );
  }
  for (final i in ref.watch(inspectionsProvider)) {
    if (!_inWindow(i.dueAt)) continue;
    list.add(
      PlannedActivity(
        kind: ActivityKind.inspection,
        refId: i.id,
        title: i.title,
        assetId: i.assetId,
        location: place(i.assetId),
        start: i.dueAt,
        end: i.dueAt.add(const Duration(hours: 1)),
        status: i.status,
        route: Routes.inspectionDetail(i.id),
      ),
    );
  }
  final audits = ref.watch(auditsProvider);
  for (final u in ref.watch(upcomingActivitiesProvider).where((u) => u.kind == 'audit')) {
    if (!_inWindow(u.at)) continue;
    final audit = audits.firstWhereOrNull((a) => a.id == u.refId);
    list.add(
      PlannedActivity(
        kind: ActivityKind.audit,
        refId: u.refId,
        title: u.subtitle,
        location: u.location,
        start: u.at,
        end: u.at.add(const Duration(hours: 3)),
        status: audit?.status == AuditStatus.inProgress ? 'Scheduled' : 'Planned',
        route: Routes.auditSession(u.refId),
      ),
    );
  }
  for (final a in audits.where((a) => a.status != AuditStatus.completed)) {
    final closes = DateTime(a.end.year, a.end.month, a.end.day, 9);
    if (!_inWindow(closes)) continue;
    list.add(
      PlannedActivity(
        kind: ActivityKind.audit,
        refId: a.id,
        title: '${a.name} – closes',
        location: a.site,
        start: closes,
        end: closes.add(const Duration(hours: 8)),
        status: a.status == AuditStatus.inProgress ? 'In Progress' : 'Pending',
        route: Routes.auditSession(a.id),
      ),
    );
  }
  DateTime atWork(DateTime d) => d.hour == 0 && d.minute == 0 ? DateTime(d.year, d.month, d.day, 9) : d;
  for (final m in ref.watch(movementsProvider).toApprove(me)) {
    if (m.requiredDate == null) continue;
    final start = atWork(m.requiredDate!);
    if (!_inWindow(start)) continue;
    list.add(
      PlannedActivity(
        kind: ActivityKind.approval,
        refId: m.id,
        title: '${m.type} approval – ${byId[m.assetId]?.name ?? m.assetId}',
        assetId: m.assetId,
        location: '${m.from.name} → ${m.to.name}',
        start: start,
        end: start.add(const Duration(minutes: 30)),
        status: 'Pending',
        route: Routes.movementRequest(m.id),
      ),
    );
  }
  for (final d in ref.watch(disposalsProvider).toApprove(me)) {
    final start = atWork(d.requestedDate);
    if (!_inWindow(start)) continue;
    list.add(
      PlannedActivity(
        kind: ActivityKind.approval,
        refId: d.id,
        title: 'Disposal approval – ${byId[d.assetId]?.name ?? d.assetId}',
        assetId: d.assetId,
        location: place(d.assetId),
        start: start,
        end: start.add(const Duration(minutes: 30)),
        status: 'Pending',
        route: Routes.approvals,
      ),
    );
  }
  list.sort((a, b) => a.start.compareTo(b.start));
  return list;
});

/// Latest activity per detailed asset (work orders, inspections, alerts, movements, scans,
/// asset events), for Recent Assets "sorted by last activity".
final assetLastActivityProvider = Provider<Map<String, DateTime>>((ref) {
  final last = <String, DateTime>{};
  void see(String id, DateTime? at) {
    if (at == null || at.isAfter(DemoClock.now)) return;
    final cur = last[id];
    if (cur == null || at.isAfter(cur)) last[id] = at;
  }

  for (final a in ref.watch(assetsProvider)) {
    for (final e in a.events) {
      see(a.id, e.at);
    }
    for (final l in a.locationHistory) {
      see(a.id, l.at);
    }
  }
  for (final w in ref.watch(workOrdersProvider)) {
    see(w.assetId, w.openedAt);
    for (final h in w.history) {
      see(w.assetId, h.at);
    }
  }
  for (final i in ref.watch(inspectionsProvider)) {
    see(i.assetId, i.completedAt);
    for (final h in i.history) {
      see(i.assetId, h.at);
    }
  }
  for (final a in ref.watch(alertsProvider)) {
    see(a.assetId, a.at);
  }
  for (final m in ref.watch(movementsProvider)) {
    see(m.assetId, m.requiredDate);
  }
  for (final s in ref.watch(scanHistoryProvider).where((s) => s.kind == ScanKind.asset)) {
    see(s.refId, s.at);
  }
  return last;
});

/// One asset pin on the live map.
class MapPin {
  const MapPin({required this.asset, required this.floor, required this.x, required this.y});

  final Asset asset;
  final MapFloor floor;
  final double x;
  final double y;

  /// Room of the floor plan under the pin ("Zone B", "Offices" …).
  String get zone {
    for (final (name, r) in FloorPlanPainter.layouts(floor.variant)) {
      if (r.contains(Offset(x, y))) return name;
    }
    return 'Aisle';
  }
}

/// Every detailed asset on the live map; tracked assets follow [trackingProvider].
final mapPinsProvider = Provider<List<MapPin>>((ref) {
  final tracking = ref.watch(trackingProvider);
  final floors = {for (final f in mapFloors) f.id: f};
  return [
    for (final a in ref.watch(assetsProvider))
      if (mapPins[a.id] case final p?)
        for (final live in [tracking.entityFor(a.id)])
          MapPin(
            asset: a,
            floor: floors[p.$1]!,
            x: p.$1 == 'wh' && live != null ? live.x : p.$2,
            y: p.$1 == 'wh' && live != null ? live.y : p.$3,
          ),
  ];
});
