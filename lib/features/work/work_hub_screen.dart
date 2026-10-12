import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/home/task_row.dart';

/// Work tab root. Not in the designs; built in the style of the module hubs.
class WorkHubScreen extends StatelessWidget {
  const WorkHubScreen({super.key});

  static List<(IconData, String, TileTone, String)> get _modules => [
    (Icons.build_rounded, 'Maintenance', TileTone.lavender, Routes.maintenance),
    (Icons.fact_check_outlined, 'Inspection', TileTone.mint, Routes.inspection),
    (Icons.warning_rounded, 'Issues / Defects', TileTone.pink, Routes.issues),
    (Icons.precision_manufacturing_outlined, 'WIP / Operations', TileTone.sky, Routes.wip),
    (Icons.swap_horiz_rounded, 'Movement & Custody', TileTone.peach, Routes.movement),
    (Icons.view_in_ar_rounded, 'Asset Audit', TileTone.cyan, Routes.audit),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Work',
            subtitle: 'Your work orders, inspections, issues and operations',
            help:
                'Work groups everything you do on assets in the field:\n\n'
                '• Maintenance: work orders, preventive maintenance and breakdowns\n'
                '• Inspection: checklists and compliance\n'
                '• Issues / Defects: report and follow up problems\n'
                '• WIP / Operations: production orders and station tracking\n'
                '• Movement & Custody: transfers, check-out and check-in\n'
                '• Asset Audit: physical verification of assets',
          ),
          const SizedBox(height: 16),
          GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (final (icon, label, tone, route) in _modules)
                ActionTile(icon: icon, label: label, tone: tone, onTap: DemoGuard.go(context, route)),
            ],
          ),
          const SizedBox(height: 20),
          const _WorkTasksCard(),
          const SizedBox(height: 8),
          Text(
            'Tip: tap Work again at any time to come back to this hub.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// "My Tasks" on the Work hub: the same task lists as Home (so the counts agree),
/// three rows at first, "View All" expands the list in place.
class _WorkTasksCard extends ConsumerStatefulWidget {
  const _WorkTasksCard();

  @override
  ConsumerState<_WorkTasksCard> createState() => _WorkTasksCardState();
}

class _WorkTasksCardState extends ConsumerState<_WorkTasksCard> {
  static const _preview = 3;
  int _tab = 0;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeDataProvider);
    final tabs = [
      ('All', home.allTasks),
      ('Work Orders', home.workOrderTasks),
      ('Inspections', home.inspectionTasks),
      ('Approvals', home.approvalTasks),
    ];
    final list = tabs[_tab].$2;
    final shown = _expanded ? list.length : list.length.clamp(0, _preview);
    final canExpand = list.length > _preview;
    return SectionCard(
      title: 'My Tasks',
      actionLabel: canExpand ? (_expanded ? 'Show Less' : 'View All') : null,
      onAction: canExpand ? () => setState(() => _expanded = !_expanded) : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  PillChip(
                    label: '${tabs[i].$1} (${tabs[i].$2.length})',
                    selected: i == _tab,
                    onTap: () => setState(() => _tab = i),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          LoadingGate(
            rows: 3,
            card: false,
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'Nothing here',
                    message: 'You are all caught up.',
                    actionLabel: 'Open Maintenance',
                    onAction: DemoGuard.go(context, Routes.maintenance),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < shown; i++) ...[if (i > 0) const Divider(), TaskRow(task: list[i])],
                    ],
                  ),
          ),
          if (canExpand)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Show less' : 'Show ${list.length - _preview} more'),
            ),
        ],
      ),
    );
  }
}
