import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/issue.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/issues_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../assets/asset_ui.dart';

/// Report-date windows used by the issue filter.
const _dateFilters = {'Today': 0, 'Last 7 days': 7, 'Last 30 days': 30};

/// Issues / Defects list (left screen of design/10_issues_defects.jpg).
class IssuesScreen extends ConsumerStatefulWidget {
  const IssuesScreen({super.key, this.initialTab});

  /// all, mine, open or resolved.
  final String? initialTab;

  @override
  ConsumerState<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends ConsumerState<IssuesScreen> {
  static const _tabKeys = ['all', 'mine', 'open', 'resolved'];
  late int _tab = _index(widget.initialTab);

  /// The In Progress tile shows its own list (it is not a tab).
  bool _inProgress = false;
  String _query = '';
  FilterSelection _filters = const {};

  static int _index(String? k) => _tabKeys.contains(k) ? _tabKeys.indexOf(k!) : 0;

  static final _filterGroups = [
    const FilterGroup(title: 'Priority', options: ['Critical', 'High', 'Medium', 'Low']),
    const FilterGroup(title: 'Type', options: issueTypes),
    const FilterGroup(title: 'Status', options: IssueStatus.all),
    FilterGroup(title: 'Date', options: _dateFilters.keys.toList(), multiSelect: false),
  ];

  @override
  void didUpdateWidget(IssuesScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) _tab = _index(widget.initialTab);
  }

  bool _inDate(Issue i, String f) {
    final days = _dateFilters[f]!;
    final from = DemoClock.today.subtract(Duration(days: days == 0 ? 0 : days - 1));
    return !i.reportedAt.isBefore(from);
  }

  Future<bool> _markResolved(Issue i) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Mark ${i.id} resolved?',
      message: '"${i.title}" moves to the Resolved tab.',
      confirmLabel: 'Mark Resolved',
    );
    if (ok && mounted) {
      ref.read(issuesProvider.notifier).updateStatus(i.id, IssueStatus.resolved, note: 'Marked resolved from the list');
      context.showSnack('${i.id} resolved');
    }
    // The row is rebuilt (or leaves the tab) from the new state; never dismiss it here.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).id;
    final all = ref.watch(issuesProvider);
    final tabs = [all, all.mine(me), all.open, all.resolved];
    final base = _inProgress ? all.inProgress : tabs[_tab];
    final rows =
        base
            .search(_query)
            .where(
              (i) =>
                  (_filters['Priority']?.contains(i.priority) ?? true) &&
                  (_filters['Type']?.contains(i.type) ?? true) &&
                  (_filters['Status']?.contains(i.status) ?? true) &&
                  (_filters['Date']?.every((d) => _inDate(i, d)) ?? true),
            )
            .toList()
          ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    final tiles = [
      (
        Icons.warning_rounded,
        'Report Issue',
        TileTone.pink,
        null,
        AppColors.primary,
        () => context.push(Routes.reportIssue),
      ),
      (Icons.handyman_rounded, 'My Issues', TileTone.sky, tabs[1].length, AppColors.primary, () => _show(1)),
      (
        Icons.timelapse_rounded,
        'In Progress',
        TileTone.peach,
        all.inProgress.length,
        AppColors.orange,
        () => setState(() => _inProgress = true),
      ),
      (Icons.check_circle_rounded, 'Resolved', TileTone.mint, tabs[3].length, AppColors.green, () => _show(3)),
    ];
    return AppScaffold(
      body: LazyListPage(
        padding: context.pagePadding,
        header: [
          const PageTitle(
            title: 'Issues / Defects',
            subtitle: 'Report and track asset issues, breakdowns and incidents',
            help:
                'Open = Open, In Progress and On Hold. Resolved = Resolved and Closed. Swipe right on one of your '
                'own open issues to mark it resolved. Critical issues raise an alert for the control room.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (n, (icon, label, tone, badge, color, onTap)) in tiles.indexed) ...[
                if (n > 0) const SizedBox(width: 8),
                Expanded(
                  child: ActionTile(
                    icon: icon,
                    label: label,
                    tone: tone,
                    badge: badge,
                    badgeColor: color,
                    height: 88,
                    labelSize: 11.5,
                    onTap: onTap,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SegmentTabs(
            tabs: [
              SegmentTab('All Issues', count: tabs[0].length),
              SegmentTab('My Issues', count: tabs[1].length),
              SegmentTab('Open', count: tabs[2].length),
              SegmentTab('Resolved', count: tabs[3].length),
            ],
            selected: _inProgress ? -1 : _tab,
            onChanged: _show,
          ),
          if (_inProgress) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                InputChip(
                  label: Text('In Progress (${all.inProgress.length})'),
                  onDeleted: () => _show(0),
                  deleteButtonTooltipMessage: 'Show all',
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search by Issue No., Asset, Location or Description...',
            onChanged: (v) => setState(() => _query = v),
            filterGroups: _filterGroups,
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 12),
        ],
        list: GatedSliverList(
          itemCount: rows.length,
          empty: const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'No issues',
            message: 'Nothing matches this tab, search and filter.',
          ),
          itemBuilder: (_, n) {
            final issue = rows[n];
            if (issue.reporterId != me || !issue.isOpen) return IssueRow(issue: issue);
            return Dismissible(
              key: ValueKey('swipe-${issue.id}'),
              direction: DismissDirection.startToEnd,
              background: Container(
                color: AppColors.green,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Mark Resolved',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              confirmDismiss: (_) => _markResolved(issue),
              child: IssueRow(issue: issue),
            );
          },
        ),
        footer: [
          const SizedBox(height: 8),
          Text('${rows.length} of ${base.length} issues', textAlign: TextAlign.center, style: AppText.caption),
        ],
      ),
    );
  }

  void _show(int tab) => setState(() {
    _tab = tab;
    _inProgress = false;
  });
}

/// Issue row: photo, ISS number, priority chip, title, asset · location, reporter and date (ellipsized lines).
class IssueRow extends ConsumerWidget {
  const IssueRow({super.key, required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = issue;
    final asset = ref.watch(assetByIdProvider(i.assetId));
    final reporter = ref.watch(personByIdProvider(i.reporterId));
    return AssetListTile(
      title: i.id,
      subtitle: i.title,
      location: '${i.assetId} · ${i.location}',
      imagePath: i.photos.isNotEmpty ? i.photos.first : asset?.imagePath,
      fallbackIcon: asset == null ? Icons.report_problem_outlined : assetIcon(asset),
      details: [
        IconLine(icon: Icons.person_outline_rounded, text: reporter?.name ?? i.reporterId),
        IconLine(icon: Icons.schedule_rounded, text: DemoClock.formatDateTime(i.reportedAt)),
      ],
      titleTrailing: PriorityChip(i.priority),
      trailingBottom: i.isOpen ? null : i.status,
      onTap: () => context.push(Routes.issueDetail(i.id)),
    );
  }
}
