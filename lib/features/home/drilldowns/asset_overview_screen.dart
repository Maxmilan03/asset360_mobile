import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/drilldowns/live/live_asset_overview_screen.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

final _n = NumberFormat('#,###');

/// Colours for the type / location donuts (cycled).
const _palette = [
  Color(0xFF6C3CE9),
  Color(0xFF2F80ED),
  Color(0xFF22B35E),
  Color(0xFFF5B800),
  Color(0xFFF2711C),
  Color(0xFFEF4444),
  Color(0xFF14A89A),
  Color(0xFFC04BE8),
  Color(0xFF7C8595),
];

enum _Tab { status, type, location }

/// One donut slice / list row of a tab.
class OverviewRowData {
  const OverviewRowData(this.label, this.count, this.color, this.icon, this.route, {this.onTap});

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  /// Filtered Assets list.
  final String route;

  /// Replaces opening [route] (API mode: rows without a filter value).
  final VoidCallback? onTap;
}

/// Home "Asset Overview" → View All: the 12,458 assets by status, type and site / building.
class AssetOverviewScreen extends ConsumerStatefulWidget {
  const AssetOverviewScreen({super.key});

  @override
  ConsumerState<AssetOverviewScreen> createState() => _AssetOverviewScreenState();
}

class _AssetOverviewScreenState extends ConsumerState<AssetOverviewScreen> {
  _Tab _tab = _Tab.status;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<OverviewRowData> _rows() {
    final org = ref.watch(orgSummaryProvider);
    final breakdown = ref.watch(assetBreakdownProvider);
    return switch (_tab) {
      _Tab.status => [
        for (final s in AssetStatus.all)
          OverviewRowData(
            s,
            org.statusCounts[s] ?? 0,
            assetStatusColors[s]!,
            assetStatusIcon(s),
            Routes.assetsWithStatus(s),
          ),
      ],
      _Tab.type => [
        for (var i = 0; i < breakdown.byType.length; i++)
          for (final s in [breakdown.byType[i]])
            OverviewRowData(
              s.name,
              s.total,
              _palette[i % _palette.length],
              assetTypeIcon(s.name),
              Routes.assetsWithType(s.name),
            ),
      ],
      _Tab.location => [
        for (var i = 0; i < breakdown.byLocation.length; i++)
          for (final s in [breakdown.byLocation[i]])
            OverviewRowData(
              s.name,
              s.total,
              _palette[i % _palette.length],
              Icons.location_on_rounded,
              Routes.assetsWithLocation(s.name),
            ),
      ],
    };
  }

  Widget _tabs() => SegmentTabs(
    tabs: const [SegmentTab('By Status'), SegmentTab('By Type'), SegmentTab('By Location')],
    selected: _tab.index,
    onChanged: (i) => setState(() => _tab = _Tab.values[i]),
  );

  @override
  Widget build(BuildContext context) {
    if (apiMode) return const LiveAssetOverviewScreen();
    final rows = _rows();
    final total = rows.fold(0, (a, r) => a + r.count);
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? rows : rows.where((r) => r.label.toLowerCase().contains(q)).toList();
    final noun = switch (_tab) {
      _Tab.status => 'status',
      _Tab.type => 'asset type',
      _Tab.location => 'location',
    };

    return DrilldownPage(
      title: 'Asset Overview',
      subtitle: 'All ${_n.format(total)} assets across every site',
      children: [
        _tabs(),
        const SizedBox(height: 12),
        AppCard(
          child: DonutWithLegend(
            size: 132,
            center: DonutCenter(value: _n.format(total), caption: 'Total Assets'),
            slices: [
              for (final r in rows)
                DonutSlice(
                  label: r.label.split(' · ').last,
                  value: r.count.toDouble(),
                  color: r.color,
                  onTap: () => context.push(r.route),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          style: AppText.body.copyWith(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Search $noun',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.text, size: 22),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No $noun matches "$_query"',
            message: 'Try another search.',
            actionLabel: 'Clear search',
            onAction: () => setState(() {
              _search.clear();
              _query = '';
            }),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 62),
                  OverviewRow(row: shown[i], total: total),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class OverviewRow extends StatelessWidget {
  const OverviewRow({super.key, required this.row, required this.total});

  final OverviewRowData row;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (row.count * 100 / total).round();
    return InkWell(
      onTap: row.onTap ?? () => context.push(row.route),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: row.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(row.icon, size: 20, color: row.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                row.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(fontSize: 13.5),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_n.format(row.count), style: AppText.bodyStrong),
                Text('$pct%', style: AppText.caption),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
