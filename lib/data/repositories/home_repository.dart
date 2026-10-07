import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/home_mock.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/inspection.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
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
  @override
  List<String> build() => [...seedRecentAssetIds];

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
    pendingApprovals: approvals.length,
    criticalAlerts: alerts.criticalRequiringAction.length,
    workOrderTasks: [for (final w in myWos) woTask(w)],
    inspectionTasks: [for (final i in myIns) insTask(i)],
    approvalTasks: [for (final m in approvals) apprTask(m)],
    recentAlerts: alerts.latest.take(3).toList(),
    recentAssets: recent,
  );
});
