import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/checklist/checklist.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/inspection.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/work/inspection/inspection_widgets.dart';

/// Hub lists: the four tabs, plus the Due Today and Completed tiles.
enum InsView { mine, due, overdue, all, dueToday, completed }

/// Inspection hub (left screen of design/09_inspection.jpg).
class InspectionHubScreen extends ConsumerStatefulWidget {
  const InspectionHubScreen({super.key, this.initialView});

  /// InsView name, e.g. "overdue".
  final String? initialView;

  @override
  ConsumerState<InspectionHubScreen> createState() => _InspectionHubScreenState();
}

class _InspectionHubScreenState extends ConsumerState<InspectionHubScreen> {
  late InsView _view = _parse(widget.initialView);
  String _query = '';
  FilterSelection _filters = const {};

  static InsView _parse(String? v) => InsView.values.firstWhere((x) => x.name == v, orElse: () => InsView.mine);

  static const _filterGroups = [
    FilterGroup(title: 'Status', options: ['Overdue', 'Due Today', 'In Progress', 'Scheduled', 'Completed']),
    FilterGroup(title: 'Type', options: ['Routine', 'Safety', 'HVAC', 'Monthly', 'Compliance']),
  ];

  @override
  void didUpdateWidget(InspectionHubScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialView != old.initialView) _view = _parse(widget.initialView);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final me = ref.watch(currentUserProvider).id;
    final all = ref.watch(inspectionsProvider);
    final assets = ref.watch(assetsProvider);
    final lists = {
      InsView.mine: all.mine(me),
      InsView.due: all.dueSoon,
      InsView.overdue: all.overdue,
      InsView.all: all,
      InsView.dueToday: all.dueToday,
      InsView.completed: all.completed,
    };
    final openFindings = all.openFindings.length;
    final q = _query.trim().toLowerCase();
    final rows = lists[_view]!.where((i) {
      final a = assets.byCode(i.assetId);
      final text = '${i.id} ${i.title} ${i.assetId} ${a?.name ?? ''} ${a?.location ?? ''}'.toLowerCase();
      return (q.isEmpty || text.contains(q)) &&
          (_filters['Status']?.contains(InspectionQueries.displayStatus(i)) ?? true) &&
          (_filters['Type']?.contains(i.type) ?? true);
    }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final tiles = [
      (
        Icons.assignment_outlined,
        'My Inspections',
        TileTone.lavender,
        lists[InsView.mine]!.length,
        AppColors.primary,
        () => _show(InsView.mine),
      ),
      (
        Icons.event_available_rounded,
        'Due Today',
        TileTone.sky,
        lists[InsView.dueToday]!.length,
        AppColors.red,
        () => _show(InsView.dueToday),
      ),
      (
        Icons.warning_rounded,
        'Overdue',
        TileTone.pink,
        lists[InsView.overdue]!.length,
        AppColors.red,
        () => _show(InsView.overdue),
      ),
      (Icons.check_circle_rounded, 'Completed', TileTone.mint, null, AppColors.primary, () => _show(InsView.completed)),
      (
        Icons.report_problem_outlined,
        'Findings',
        TileTone.lavender,
        openFindings,
        AppColors.primary,
        () => context.push(Routes.inspectionFindings),
      ),
      (
        Icons.calendar_month_rounded,
        'Inspection Calendar',
        TileTone.lavender,
        null,
        AppColors.primary,
        () => context.push(Routes.maintenanceCalendar),
      ),
    ];
    final tabIndex = _view.index < 4 ? _view.index : -1;
    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create Inspection',
        onPressed: () => context.push(Routes.createInspection),
        child: const Icon(Icons.add_rounded),
      ),
      body: LazyListPage(
        padding: context.pagePadding.copyWith(bottom: context.pagePadding.bottom + 64),
        header: [
          const PageTitle(
            title: 'Inspection',
            subtitle: 'Conduct inspections, checklists and compliance',
            help:
                'My Inspections: open inspections assigned to you. Due: not overdue, due in the next 7 days. '
                'Due Today includes overdue ones still due today. Negative answers raise findings you can turn '
                'into work orders.',
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
              for (final (icon, label, tone, badge, badgeColor, onTap) in tiles)
                ActionTile(icon: icon, label: label, tone: tone, badge: badge, badgeColor: badgeColor, onTap: onTap),
            ],
          ),
          const SizedBox(height: 14),
          SegmentTabs(
            tabs: [
              SegmentTab('My Inspections', count: lists[InsView.mine]!.length),
              SegmentTab('Due', count: lists[InsView.due]!.length),
              SegmentTab('Overdue', count: lists[InsView.overdue]!.length),
              const SegmentTab('All'),
            ],
            selected: tabIndex,
            onChanged: (i) => _show(InsView.values[i]),
          ),
          if (tabIndex == -1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                InputChip(
                  label: Text('${_view == InsView.dueToday ? 'Due Today' : 'Completed'} (${lists[_view]!.length})'),
                  onDeleted: () => _show(InsView.all),
                  deleteButtonTooltipMessage: 'Show all',
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search by Asset, Inspection No. or Location...',
            onChanged: (v) => setState(() => _query = v),
            filterGroups: _filterGroups,
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 12),
        ],
        list: GatedSliverList(
          itemCount: rows.length,
          itemBuilder: (_, i) => InspectionRow(inspection: rows[i]),
          empty: const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No inspections',
            message: 'Nothing matches this tab, search and filter.',
          ),
        ),
        footer: [
          const SizedBox(height: 8),
          Text(
            '${rows.length} of ${lists[_view]!.length} inspections',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  void _show(InsView v) => setState(() => _view = v);
}

/// All findings with severity, asset and status; filter by status.
class FindingsScreen extends ConsumerStatefulWidget {
  const FindingsScreen({super.key});

  @override
  ConsumerState<FindingsScreen> createState() => _FindingsScreenState();
}

class _FindingsScreenState extends ConsumerState<FindingsScreen> {
  String? _status = FindingStatus.open;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(inspectionsProvider);
    final rows = [
      for (final i in all)
        for (final f in i.findings)
          if (_status == null || f.status == _status) (i, f),
    ]..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    int count(String s) => all.findings.where((f) => f.status == s).length;
    return AppScaffold(
      body: LazyListPage(
        padding: context.pagePadding,
        header: [
          PageTitle(title: 'Findings', subtitle: '${all.openFindings.length} open of ${all.findings.length}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in [null, ...FindingStatus.all])
                IconFilterChip(
                  label: s == null ? 'All (${all.findings.length})' : '$s (${count(s)})',
                  selected: _status == s,
                  onTap: () => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        list: GatedSliverList(
          itemCount: rows.length,
          itemBuilder: (_, n) => FindingRow(finding: rows[n].$2, inspection: rows[n].$1),
          empty: EmptyState(
            icon: Icons.verified_outlined,
            title: 'No findings',
            message: _status == null ? 'Negative checklist answers raise findings.' : 'No $_status findings.',
          ),
        ),
      ),
    );
  }
}

/// Finding detail with "Create Work Order" and "Close Finding".
class FindingDetailScreen extends ConsumerWidget {
  const FindingDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ins = ref.watch(inspectionsProvider).ofFinding(id);
    final f = ins?.findings.firstWhere((x) => x.id == id);
    if (ins == null || f == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Finding not found', message: id),
      );
    }
    final asset = ref.watch(assetByIdProvider(ins.assetId));
    final item = f.questionCode == null
        ? null
        : [for (final s in ins.sections) ...s.items].where((x) => x.code == f.questionCode).firstOrNull;
    return AppScaffold(
      bottomActions: f.isOpen
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Close ${f.id}?',
                        message: 'Close the finding when the problem is fixed or accepted.',
                        confirmLabel: 'Close Finding',
                      );
                      if (!ok || !context.mounted) return;
                      ref.read(inspectionsProvider.notifier).closeFinding(f.id);
                      context.showSnack('${f.id} closed');
                    },
                    child: const Text('Close Finding'),
                  ),
                ),
                if (f.workOrderId == null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => createWorkOrderForFinding(context, ins, f),
                      child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Create Work Order')),
                    ),
                  ),
                ],
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          PageTitle(title: f.title, subtitle: '${f.id} · ${DemoClock.formatDateTime(f.createdAt)}'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [PriorityChip(f.severity), StatusChip(f.status)]),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                InfoRow(label: 'Asset', value: '${ins.assetId} – ${asset?.name ?? ''}'),
                InfoRow(label: 'Location', value: asset?.location ?? '—'),
                InfoRow(label: 'Inspection', value: '${ins.id} · ${ins.title}'),
                if (item != null)
                  InfoRow(
                    label: 'Checklist item',
                    value:
                        '${item.code} ${item.label}: ${item.value ?? '—'} ${item.type == CheckType.number ? item.unit ?? '' : ''}',
                  ),
                InfoRow(label: 'Description', value: f.description.isEmpty ? '—' : f.description),
                if (f.closedAt != null) InfoRow(label: 'Closed', value: DemoClock.formatDateTime(f.closedAt!)),
              ],
            ),
          ),
          if (f.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: PhotoStrip(title: 'Photos', photos: f.photos),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(Routes.inspectionDetail(ins.id, tab: 'checklist')),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Open Inspection'),
                ),
              ),
              if (f.workOrderId != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(Routes.workOrder(f.workOrderId!)),
                    icon: const Icon(Icons.build_outlined),
                    label: Text(f.workOrderId!),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
