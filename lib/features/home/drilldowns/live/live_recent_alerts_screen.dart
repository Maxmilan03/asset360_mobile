import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/sections/live_dashboard_cards.dart';

/// Severity tabs: label + the `severity=` value (null = all).
const _tabs = [
  ('All', null),
  ('Critical', DashSeverity.critical),
  ('Warning', DashSeverity.warning),
  ('Info', DashSeverity.info),
];

/// `days=` choices (server: 1–90, default 7).
const _periods = [(1, 'Last 24 hours'), (7, 'Last 7 days'), (30, 'Last 30 days'), (90, 'Last 90 days')];

/// API mode Recent Alerts: GET /api/dashboards/mobile/recent-alerts — IoT alerts plus overdue work
/// orders, failed inspections, low stock and maintenance due soon. Tabs = `severity`, the period
/// menu = `days`; 20 per page, the next page loads at the end of the list. Alert details are not
/// connected yet (a row says so).
class LiveRecentAlertsScreen extends ConsumerStatefulWidget {
  const LiveRecentAlertsScreen({super.key, this.initialSeverity});

  /// Critical / Warning / Info (Home's Critical Alert tile opens Critical).
  final String? initialSeverity;

  @override
  ConsumerState<LiveRecentAlertsScreen> createState() => _LiveRecentAlertsScreenState();
}

class _LiveRecentAlertsScreenState extends ConsumerState<LiveRecentAlertsScreen> {
  late int _tab = _tabs.indexWhere((t) => t.$2 != null && t.$2 == widget.initialSeverity).clamp(0, _tabs.length);
  int _days = 7;

  DashAlertsQuery get _q => (severity: _tabs[_tab].$2, days: _days, site: ref.watch(dashSiteProvider));

  @override
  Widget build(BuildContext context) {
    final provider = dashAlertsProvider(_q);
    final v = ref.watch(provider);
    final page = v.value;
    final counts = page?.counts;
    int? countOf(int i) => counts == null
        ? null
        : switch (i) {
            0 => counts.all,
            1 => counts.critical,
            2 => counts.warning,
            _ => counts.info,
          };

    final Widget sliver;
    if (v.hasError && !v.isLoading) {
      sliver = SliverToBoxAdapter(
        child: LoadErrorState(error: v.error!, onRetry: () => ref.invalidate(provider)),
      );
    } else if (page == null || v.isLoading) {
      sliver = const SliverToBoxAdapter(child: ListSkeleton(rows: 6));
    } else if (page.items.isEmpty) {
      sliver = SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'No alerts',
          message: 'Nothing in this tab for the ${_label(_days).toLowerCase()}.',
          actionLabel: _days < 90 ? 'Show last 90 days' : null,
          onAction: _days < 90 ? () => setState(() => _days = 90) : null,
        ),
      );
    } else {
      sliver = SliverCardList(
        itemCount: page.items.length,
        indent: 62,
        itemBuilder: (_, i) {
          if (i == page.items.length - 1 && page.hasMore && page.loadMoreError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(provider.notifier).loadMore();
            });
          }
          return DashAlertRow(alert: page.items[i]);
        },
      );
    }

    return DrilldownPage(
      title: 'Recent Alerts',
      subtitle: '${dashSiteLabel(ref.watch(dashSiteProvider))} · ${_label(_days)}',
      skeletonRows: 6,
      onRefresh: () => ref.invalidate(provider),
      trailing: PopupMenuButton<int>(
        key: const ValueKey('alertDays'),
        tooltip: 'Period',
        initialValue: _days,
        onSelected: (d) => setState(() => _days = d),
        itemBuilder: (_) => [for (final (d, label) in _periods) PopupMenuItem(value: d, child: Text(label))],
        child: Icon(Icons.filter_alt_outlined, color: AppColors.primary, semanticLabel: 'Period'),
      ),
      sliver: sliver,
      footer: [
        if (page != null && page.items.isNotEmpty && !v.isLoading) ...[
          if (page.loadingMore) const Center(child: CircularProgressIndicator()),
          if (page.loadMoreError != null)
            Center(
              child: TextButton.icon(
                onPressed: () => ref.read(provider.notifier).loadMore(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Could not load more. Retry'),
              ),
            ),
          ShowingFooter(text: 'Showing ${page.items.length} of ${dashNumber.format(page.totalCount)}'),
        ],
      ],
      children: [
        SegmentTabs(
          tabs: [for (final (i, t) in _tabs.indexed) SegmentTab(t.$1, count: countOf(i))],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 8),
        Text(
          'Sources: IoT alerts, overdue work orders, failed inspections, low stock, maintenance due soon.',
          style: AppText.caption.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  static String _label(int days) =>
      _periods.firstWhere((p) => p.$1 == days, orElse: () => (days, 'Last $days days')).$2;
}
