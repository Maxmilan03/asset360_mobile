import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/asset_overview_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

enum _Tab { status, type, location }

/// API mode Asset Overview: GET /api/dashboards/mobile/asset-overview?search= — By Status / By
/// Type / By Location (site). The search box filters the group names on the server. A row opens
/// Recent Assets narrowed to that status group, asset type or site.
class LiveAssetOverviewScreen extends ConsumerStatefulWidget {
  const LiveAssetOverviewScreen({super.key});

  @override
  ConsumerState<LiveAssetOverviewScreen> createState() => _LiveAssetOverviewScreenState();
}

class _LiveAssetOverviewScreenState extends ConsumerState<LiveAssetOverviewScreen> {
  _Tab _tab = _Tab.status;
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  String? get _searchParam => _query.trim().isEmpty ? null : _query.trim();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {}); // the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v);
    });
  }

  void _clear() => setState(() {
    _debounce?.cancel();
    _search.clear();
    _query = '';
  });

  String get _noun => switch (_tab) {
    _Tab.status => 'status',
    _Tab.type => 'asset type',
    _Tab.location => 'site',
  };

  List<OverviewRowData> _rows(DashAssetOverview o) {
    OverviewRowData row(DashBreakdownItem b, Color color, IconData icon, String route) {
      final missing = b.label.toLowerCase() == 'others';
      return OverviewRowData(
        b.label,
        b.count,
        color,
        icon,
        route,
        onTap: missing ? () => context.showSnack('These ${b.count} assets have no $_noun recorded') : null,
      );
    }

    return switch (_tab) {
      _Tab.status => [
        for (final b in o.byStatus)
          row(b, dashStatusColor(b.key), dashStatusIcon(b.key), Routes.recentAssetsFiltered(status: b.key)),
      ],
      _Tab.type => [
        for (final (i, b) in o.byType.indexed)
          row(
            b,
            dashPalette[i % dashPalette.length],
            assetTypeIcon(b.label),
            Routes.recentAssetsFiltered(type: b.label),
          ),
      ],
      _Tab.location => [
        for (final (i, b) in o.byLocation.indexed)
          row(
            b,
            dashPalette[i % dashPalette.length],
            Icons.location_on_rounded,
            Routes.recentAssetsFiltered(site: b.label),
          ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final site = ref.watch(dashSiteProvider);
    final all = dashAssetOverviewProvider((search: null, site: site));
    final searched = dashAssetOverviewProvider((search: _searchParam, site: site));
    final total = ref.watch(all).value?.totalAssets;
    final empty = total == 0;
    return DrilldownPage(
      title: 'Asset Overview',
      subtitle: total == null
          ? 'Live asset summary'
          : site == null
          ? 'All ${dashNumber.format(total)} assets across every site'
          : '${dashNumber.format(total)} assets at $site',
      onRefresh: () => ref.invalidate(dashAssetOverviewProvider),
      children: [
        SegmentTabs(
          tabs: const [SegmentTab('By Status'), SegmentTab('By Type'), SegmentTab('By Location')],
          selected: _tab.index,
          onChanged: (i) => setState(() => _tab = _Tab.values[i]),
        ),
        const SizedBox(height: 12),
        // The donut: every group of the tab (not narrowed by the search).
        DashSection<DashAssetOverview>(
          provider: all,
          onRetry: (ref) => ref.invalidate(all),
          rows: 3,
          isEmpty: (o) => o.totalAssets == 0,
          emptyIcon: Icons.inventory_2_outlined,
          emptyTitle: 'No assets yet',
          emptyMessage: 'Registered assets appear here.',
          builder: (o) {
            final rows = _rows(o);
            return AppCard(
              child: DonutWithLegend(
                size: 132,
                center: DonutCenter(value: dashNumber.format(o.totalAssets), caption: 'Total Assets'),
                slices: [
                  for (final r in rows)
                    DonutSlice(
                      label: r.label,
                      value: r.count.toDouble(),
                      color: r.color,
                      onTap: r.onTap ?? DemoGuard.push(context, r.route),
                    ),
                ],
              ),
            );
          },
        ),
        if (!empty) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            style: AppText.body.copyWith(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Search $_noun',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.text, size: 22),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _clear,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // The rows: GET /asset-overview?search= (group names matching the search).
          DashSection<DashAssetOverview>(
            provider: searched,
            onRetry: (ref) => ref.invalidate(searched),
            rows: 4,
            builder: (o) {
              final rows = _rows(o);
              final sum = o.totalAssets;
              if (rows.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No $_noun matches "$_query"',
                  message: 'Try another search.',
                  actionLabel: 'Clear search',
                  onAction: _clear,
                );
              }
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 62),
                      OverviewRow(row: rows[i], total: sum),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
