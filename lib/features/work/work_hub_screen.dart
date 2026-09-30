import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';

/// Work tab root. Not in the designs; built in the style of the module hubs.
class WorkHubScreen extends StatelessWidget {
  const WorkHubScreen({super.key});

  static const _modules = [
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
                ActionTile(icon: icon, label: label, tone: tone, onTap: () => context.go(route)),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'My Tasks',
            actionLabel: 'View All',
            onAction: () => context.go(Routes.maintenance),
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'No tasks to show yet',
              message: 'Your assigned work orders, inspections and approvals will be listed here.',
              actionLabel: 'Open Maintenance',
              onAction: () => context.go(Routes.maintenance),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tip: tap Work again at any time to come back to this hub.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
