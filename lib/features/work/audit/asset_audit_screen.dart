import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/data/repositories/audits_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/work/audit/audit_widgets.dart';

/// Asset Audit (left screen of design/15_asset_audit.jpg).
class AssetAuditScreen extends ConsumerStatefulWidget {
  const AssetAuditScreen({super.key, this.initialTab});

  /// mine | assigned | completed, or a tile filter: inProgress | pending.
  final String? initialTab;

  @override
  ConsumerState<AssetAuditScreen> createState() => _AssetAuditScreenState();
}

class _AssetAuditScreenState extends ConsumerState<AssetAuditScreen> {
  static const _tabKeys = ['mine', 'assigned', 'completed'];
  int _tab = 0;

  /// In Progress / Pending tile filter (on top of My Audits).
  String? _status;
  String _query = '';
  FilterSelection _filters = const {};

  @override
  void initState() {
    super.initState();
    _apply(widget.initialTab);
  }

  @override
  void didUpdateWidget(AssetAuditScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) _apply(widget.initialTab);
  }

  void _apply(String? t) {
    _status = switch (t) {
      'inProgress' => AuditStatus.inProgress,
      'pending' => AuditStatus.pending,
      _ => null,
    };
    _tab = _status != null ? 0 : _tabKeys.indexOf(t ?? '').clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    // API mode: asset-audits are not in this phase (the mock audits list mock assets).
    if (apiMode) {
      return AppScaffold(
        body: ListView(
          padding: context.pagePadding,
          children: const [
            PageTitle(title: 'Asset Audit', subtitle: 'Physical verification and reconciliation of assets'),
            SizedBox(height: 16),
            AppCard(
              child: NotAvailableYet(feature: 'Asset Audit', icon: Icons.fact_check_outlined),
            ),
          ],
        ),
      );
    }
    final me = ref.watch(currentUserProvider).id;
    final all = ref.watch(auditsProvider);
    final mine = all.mine(me);
    final assigned = all.assigned(me);
    final completed = mine.completed;
    final inProgress = mine.withStatus(AuditStatus.inProgress);
    final pending = mine.withStatus(AuditStatus.pending);
    final base = _status != null ? mine.withStatus(_status!) : [mine, assigned, completed][_tab];
    final q = _query.trim().toLowerCase();
    final rows = base
        .where(
          (a) =>
              (q.isEmpty ||
                  a.name.toLowerCase().contains(q) ||
                  a.site.toLowerCase().contains(q) ||
                  a.scopeCategories.any((c) => c.toLowerCase().contains(q))) &&
              (_filters['Status']?.contains(a.status) ?? true) &&
              (_filters['Site']?.contains(a.site) ?? true),
        )
        .toList();

    Widget tile(IconData icon, String label, int value, TileTone tone, bool selected, VoidCallback onTap) => Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? tone.foreground : Colors.transparent, width: 1.5),
        ),
        child: KpiTile(icon: icon, value: '$value', label: label, tone: tone, onTap: onTap),
      ),
    );

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create Audit Campaign',
        onPressed: () => context.push(Routes.newAudit),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: context.pagePadding.copyWith(bottom: context.pagePadding.bottom + 64),
        children: [
          const PageTitle(
            title: 'Asset Audit',
            subtitle: 'Physical verification and reconciliation of assets',
            help:
                'My Audits = audits you lead or are an auditor on. Assigned = those not completed yet. '
                'In Progress / Pending / Completed split My Audits by status, and each tab count matches its tile. '
                'Open an audit to scan assets; every result updates the progress and the result tiles.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              tile(
                Icons.assignment_rounded,
                'My Audits',
                mine.length,
                TileTone.lavender,
                _status == null && _tab == 0,
                () => setState(() {
                  _tab = 0;
                  _status = null;
                }),
              ),
              const SizedBox(width: 8),
              tile(
                Icons.check_circle_rounded,
                'In Progress',
                inProgress.length,
                TileTone.mint,
                _status == AuditStatus.inProgress,
                () => setState(() => _status = AuditStatus.inProgress),
              ),
              const SizedBox(width: 8),
              tile(
                Icons.schedule_rounded,
                'Pending',
                pending.length,
                TileTone.peach,
                _status == AuditStatus.pending,
                () => setState(() => _status = AuditStatus.pending),
              ),
              const SizedBox(width: 8),
              tile(
                Icons.bar_chart_rounded,
                'Completed',
                completed.length,
                TileTone.sky,
                _status == null && _tab == 2,
                () => setState(() {
                  _tab = 2;
                  _status = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentTabs(
            tabs: [
              SegmentTab('My Audits', count: mine.length),
              SegmentTab('Assigned', count: assigned.length),
              SegmentTab('Completed', count: completed.length),
            ],
            selected: _status == null ? _tab : 0,
            onChanged: (i) => setState(() {
              _tab = i;
              _status = null;
            }),
          ),
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search by Audit Name, Site or Asset Type...',
            onChanged: (v) => setState(() => _query = v),
            filterGroups: [
              const FilterGroup(
                title: 'Status',
                options: [AuditStatus.inProgress, AuditStatus.pending, AuditStatus.paused, AuditStatus.completed],
              ),
              FilterGroup(title: 'Site', options: {for (final a in mine) a.site}.toList()..sort()),
            ],
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                InputChip(
                  label: Text('$_status (${mine.withStatus(_status!).length})'),
                  onDeleted: () => setState(() => _status = null),
                  deleteButtonTooltipMessage: 'Show all',
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          LoadingGate(
            rows: 3,
            child: rows.isEmpty
                ? AppCard(
                    child: EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'No audits match',
                      message: 'Try another tab, search or filter, or create an audit campaign.',
                      actionLabel: 'Create Audit Campaign',
                      onAction: () => context.push(Routes.newAudit),
                    ),
                  )
                : AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
                          AuditCard(audit: rows[i]),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => context.push(Routes.compliance),
            child: Row(
              children: [
                IconSquare(icon: Icons.verified_user_rounded, tone: TileTone.cyan, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Compliance', style: AppText.bodyStrong),
                      Text(
                        'Certificates and inspections that need attention',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
