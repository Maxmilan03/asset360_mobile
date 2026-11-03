import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/work/maintenance/wo_widgets.dart';

/// Due-date windows used by the work-order filters.
const woDateFilters = ['Due today', 'Next 7 days', 'Past due'];

bool woMatchesDate(WorkOrder w, String f) => switch (f) {
  'Due today' => DemoClock.isToday(w.dueAt),
  'Next 7 days' => !DemoClock.isOverdue(w.dueAt) && DemoClock.daysUntil(w.dueAt) <= 7,
  _ => DemoClock.isOverdue(w.dueAt),
};

/// Search by WO number, asset ID / name or location.
List<WorkOrder> searchWorkOrders(List<WorkOrder> list, String q, WidgetRef ref) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return list;
  final assets = ref.read(assetsProvider);
  return list.where((w) {
    final a = assets.byCode(w.assetId);
    return '${w.id} ${w.title} ${w.assetId} ${a?.name ?? ''} ${a?.location ?? ''}'.toLowerCase().contains(s);
  }).toList();
}

/// Maintenance hub (left screen of design/08_maintenance.jpg).
class MaintenanceHubScreen extends ConsumerStatefulWidget {
  const MaintenanceHubScreen({super.key, this.initialTab});

  /// mine, pm, overdue or all.
  final String? initialTab;

  @override
  ConsumerState<MaintenanceHubScreen> createState() => _MaintenanceHubScreenState();
}

class _MaintenanceHubScreenState extends ConsumerState<MaintenanceHubScreen> {
  static const _tabKeys = ['mine', 'pm', 'overdue', 'all'];
  late int _tab = _indexOf(widget.initialTab);
  String _query = '';
  FilterSelection _filters = const {};

  static int _indexOf(String? key) => _tabKeys.contains(key) ? _tabKeys.indexOf(key!) : 0;

  static const _filterGroups = [
    FilterGroup(title: 'Priority', options: ['Critical', 'High', 'Medium', 'Low']),
    FilterGroup(title: 'Status', options: WoStatus.all),
    FilterGroup(
      title: 'Type',
      options: ['Breakdown', 'Corrective', 'Scheduled', 'Inspection', 'Service', 'Calibration'],
    ),
    FilterGroup(title: 'Date', options: woDateFilters, multiSelect: false),
  ];

  @override
  void didUpdateWidget(MaintenanceHubScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) _tab = _indexOf(widget.initialTab);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final me = ref.watch(currentUserProvider).id;
    final all = ref.watch(workOrdersProvider);
    final tabs = [all.mine(me), all.pmDue, all.overdue, all];
    final rows = searchWorkOrders(tabs[_tab], _query, ref)
        .where(
          (w) =>
              (_filters['Priority']?.contains(w.priority) ?? true) &&
              (_filters['Status']?.contains(w.status) ?? true) &&
              (_filters['Type']?.contains(w.workType) ?? true) &&
              (_filters['Date']?.every((f) => woMatchesDate(w, f)) ?? true),
        )
        .toList();
    final tiles = [
      (Icons.assignment_outlined, 'My Work Orders', TileTone.lavender, tabs[0].length, () => setState(() => _tab = 0)),
      (
        Icons.event_repeat_rounded,
        'Preventive Maintenance',
        TileTone.sky,
        null,
        DemoGuard.push(context, Routes.pmSchedules),
      ),
      (Icons.warning_rounded, 'Breakdown Requests', TileTone.pink, null, DemoGuard.push(context, Routes.breakdowns)),
      (
        Icons.history_edu_rounded,
        'Service History',
        TileTone.sky,
        null,
        DemoGuard.push(context, Routes.serviceHistory),
      ),
      (Icons.inventory_2_rounded, 'Spare Parts', TileTone.sky, null, DemoGuard.go(context, Routes.inventory)),
      (
        Icons.calendar_month_rounded,
        'Maintenance Calendar',
        TileTone.lavender,
        null,
        DemoGuard.push(context, Routes.maintenanceCalendar),
      ),
    ];
    return AppScaffold(
      floatingActionButton: DemoGuard(
        route: Routes.createWorkOrder(),
        child: FloatingActionButton(
          tooltip: 'Create Work Order',
          onPressed: () => context.push(Routes.createWorkOrder()),
          child: const Icon(Icons.add_rounded),
        ),
      ),
      body: LazyListPage(
        padding: context.pagePadding.copyWith(bottom: context.pagePadding.bottom + 64),
        header: [
          const PageTitle(
            title: 'Maintenance',
            subtitle: 'Manage work orders, preventive maintenance and asset service',
            help:
                'My Work Orders are active work orders assigned to or coordinated by you. PM Due are preventive '
                'work orders not yet overdue; Overdue are active work orders past their due time.',
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              for (final (icon, label, tone, badge, onTap) in tiles)
                ActionTile(icon: icon, label: label, tone: tone, badge: badge, onTap: onTap),
            ],
          ),
          const SizedBox(height: 14),
          SegmentTabs(
            tabs: [
              SegmentTab('My Work Orders', count: tabs[0].length),
              SegmentTab('PM Due', count: tabs[1].length),
              SegmentTab('Overdue', count: tabs[2].length),
              const SegmentTab('All'),
            ],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search by WO No., Asset, Location...',
            onChanged: (v) => setState(() => _query = v),
            filterGroups: _filterGroups,
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 12),
        ],
        list: GatedSliverList(
          itemCount: rows.length,
          itemBuilder: (_, i) => WoRow(wo: rows[i]),
          empty: const EmptyState(
            icon: Icons.build_outlined,
            title: 'No work orders',
            message: 'Nothing matches this tab, search and filter.',
          ),
        ),
        footer: [
          const SizedBox(height: 8),
          Text(
            '${rows.length} of ${tabs[_tab].length} work orders',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
