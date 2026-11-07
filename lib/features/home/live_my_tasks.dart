import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';

/// API mode My Tasks (Home card + "View All" screen): GET /api/dashboards/mobile/my-tasks?site= —
/// open work orders, inspections and approvals assigned to the signed-in user (the bearer token
/// decides who; there is no user parameter and no paging). Tab counts are the server's `counts`;
/// the tabs filter the one reply by `type`. Work orders, inspections and approvals have no module
/// connected yet, so a row says "Not available yet"; the asset tag opens the live asset.

/// Tabs: label, task type (null = all), count.
List<(String, String?, int)> _tabs(DashMyTaskCounts c) => [
  ('All', null, c.total),
  ('Work Orders', DashActivityType.workOrder, c.workOrders),
  ('Inspections', DashActivityType.inspection, c.inspections),
  ('Approvals', DashActivityType.approval, c.approvals),
];

List<DashTaskItem> _ofType(DashMyTasks t, String? type) => type == null
    ? t.items
    : [
        for (final i in t.items)
          if (i.type == type) i,
      ];

/// "2 overdue · 1 due today" (empty when neither).
String _summary(DashMyTaskCounts c) =>
    [if (c.overdue > 0) '${c.overdue} overdue', if (c.dueToday > 0) '${c.dueToday} due today'].join(' · ');

class LiveMyTasksCard extends ConsumerStatefulWidget {
  const LiveMyTasksCard({super.key});

  static const rows = 3;

  @override
  ConsumerState<LiveMyTasksCard> createState() => _LiveMyTasksCardState();
}

class _LiveMyTasksCardState extends ConsumerState<LiveMyTasksCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final site = ref.watch(dashSiteProvider);
    final provider = dashMyTasksProvider(site);
    final viewAll = DemoGuard.push(context, '${Routes.myTasks}?tab=$_tab');
    return SectionCard(
      title: 'My Tasks',
      actionLabel: 'View All',
      onAction: viewAll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: DashSection<DashMyTasks>(
        provider: provider,
        onRetry: (ref) => ref.invalidate(provider),
        builder: (t) {
          final tabs = _tabs(t.counts);
          final list = _ofType(t, tabs[_tab].$2);
          final summary = _summary(t.counts);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (i, tab) in tabs.indexed) ...[
                      PillChip(
                        label: '${tab.$1} (${tab.$3})',
                        selected: i == _tab,
                        onTap: () => setState(() => _tab = i),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  summary,
                  style: AppText.caption.copyWith(color: AppColors.red, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 6),
              if (list.isEmpty)
                const DashEmpty(icon: Icons.task_alt_rounded, title: 'No open tasks', message: 'You are all caught up.')
              else
                for (final (i, task) in list.take(LiveMyTasksCard.rows).indexed) ...[
                  if (i > 0) const Divider(),
                  DashTaskRow(task: task),
                ],
              if (list.length > LiveMyTasksCard.rows)
                TextButton(onPressed: viewAll, child: Text('Show ${list.length - LiveMyTasksCard.rows} more')),
            ],
          );
        },
      ),
    );
  }
}

/// Home → My Tasks → View All (`/home/tasks?tab=`).
class LiveMyTasksScreen extends ConsumerStatefulWidget {
  const LiveMyTasksScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<LiveMyTasksScreen> createState() => _LiveMyTasksScreenState();
}

class _LiveMyTasksScreenState extends ConsumerState<LiveMyTasksScreen> {
  late int _tab = widget.initialTab.clamp(0, 3);

  @override
  Widget build(BuildContext context) {
    final site = ref.watch(dashSiteProvider);
    final provider = dashMyTasksProvider(site);
    final t = ref.watch(provider).value;
    final tabs = t == null ? null : _tabs(t.counts);
    return DrilldownPage(
      title: 'My Tasks',
      subtitle: 'Assigned to you · ${dashSiteLabel(site)}',
      skeletonRows: 5,
      onRefresh: () => ref.invalidate(provider),
      children: [
        SegmentTabs(
          tabs: [
            for (final (i, label) in ['All', 'Work Orders', 'Inspections', 'Approvals'].indexed)
              SegmentTab(label, count: tabs?[i].$3),
          ],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 12),
        DashSection<DashMyTasks>(
          provider: provider,
          onRetry: (ref) => ref.invalidate(provider),
          rows: 5,
          builder: (t) {
            final list = _ofType(t, _tabs(t.counts)[_tab].$2);
            final summary = _summary(t.counts);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary.isNotEmpty) ...[
                  Text(
                    summary,
                    style: AppText.caption.copyWith(color: AppColors.red, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                ],
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: list.isEmpty
                      ? const DashEmpty(
                          icon: Icons.task_alt_rounded,
                          title: 'No open tasks',
                          message: 'You are all caught up.',
                        )
                      : Column(
                          children: [
                            for (final (i, task) in list.indexed) ...[
                              if (i > 0) const Divider(),
                              DashTaskRow(task: task),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                ShowingFooter(text: '${list.length} ${list.length == 1 ? 'task' : 'tasks'}'),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One task: type icon, title, reference · asset tag link · asset, due line, status chip.
class DashTaskRow extends StatelessWidget {
  const DashTaskRow({super.key, required this.task});

  final DashTaskItem task;

  String get _due {
    final d = task.dueDate ?? task.dueUtc?.toLocal();
    if (d == null) return 'No due date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final text = day == today ? 'today' : DateFormat('d MMM').format(d);
    return task.isOverdue ? 'Overdue · due $text' : 'Due $text';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tone, _) = dashActivityLook(task.type);
    final tag = task.assetId;
    return InkWell(
      onTap: () => showNotAvailableYet(context, dashModuleOf(task.type)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            IconSquare(icon: icon, tone: tone, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        '${dashActivityLabel(task.type)} · ${task.reference}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                      if (tag != null) AssetTagLink(tag: tag),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _due,
                    style: AppText.caption.copyWith(
                      fontSize: 11.5,
                      color: task.isOverdue ? AppColors.red : null,
                      fontWeight: task.isOverdue ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(task.status),
          ],
        ),
      ),
    );
  }
}
