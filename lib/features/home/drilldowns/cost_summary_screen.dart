import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

final _n = NumberFormat('#,###');
const _monthLetters = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Home "Cost Summary (AED)" drill-down: total vs last year, the three cost cards,
/// the monthly trend and cost by asset type, for YTD 2026 or 2025.
class CostSummaryScreen extends ConsumerStatefulWidget {
  const CostSummaryScreen({super.key});

  @override
  ConsumerState<CostSummaryScreen> createState() => _CostSummaryScreenState();
}

class _CostSummaryScreenState extends ConsumerState<CostSummaryScreen> {
  int _year = 0;

  void _showTop(String title, double Function(Asset a) cost, {bool Function(Asset a)? where}) {
    final assets = [
      for (final a in ref.read(assetsProvider))
        if ((where?.call(a) ?? true) && cost(a) > 0) a,
    ]..sort((a, b) => cost(b).compareTo(cost(a)));
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (ctx) => sheetFrame(ctx, [
        SheetTitle('Top assets – $title', subtitle: 'Lifetime running cost (AED)'),
        if (assets.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No detailed assets',
            message: 'None of the sample asset records fall in this group.',
          )
        else
          for (final (i, a) in assets.take(5).indexed) ...[
            if (i > 0) const Divider(height: 1),
            AssetListTile(
              title: a.id,
              subtitle: a.name,
              imagePath: a.imagePath,
              fallbackIcon: assetIcon(a),
              trailingTop: Text('AED ${_n.format(cost(a).round())}', style: AppText.bodyStrong.copyWith(fontSize: 13)),
              onTap: () {
                Navigator.pop(ctx);
                context.push(Routes.assetDetail(a.id));
              },
            ),
          ],
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ]),
    );
  }

  void _showGroup(CostGroup g) => _showTop(
    g.label,
    (a) => switch (g) {
      CostGroup.maintenance => a.costs.maintenance,
      CostGroup.spareParts => a.costs.spares,
      CostGroup.operations => a.costs.labor + a.costs.energy,
    },
  );

  void _showType(String type) => _showTop(type, (a) => a.costs.total, where: (a) => assetTypeGroup(a) == type);

  @override
  Widget build(BuildContext context) {
    if (apiMode) return const NotAvailableDrilldown(title: 'Cost Summary (AED)', feature: 'Cost summary');
    final years = ref.watch(costYearsProvider);
    final y = years[_year.clamp(0, years.length - 1)];
    return DrilldownPage(
      title: 'Cost Summary (AED)',
      subtitle: 'Running costs across all sites',
      trailing: PopupMenuButton<int>(
        key: const ValueKey('year'),
        tooltip: 'Year',
        initialValue: _year,
        onSelected: (i) => setState(() => _year = i),
        itemBuilder: (_) => [for (final (i, yr) in years.indexed) PopupMenuItem(value: i, child: Text(yr.label))],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(y.label, style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.text),
            ],
          ),
        ),
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Cost', style: AppText.secondary),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'AED ${_n.format(y.total)}',
                  style: AppText.pageTitle.copyWith(fontSize: 28, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              ChangeChip(pct: y.changePct, higherIsBetter: false, suffix: 'vs last year'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, g) in CostGroup.values.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _GroupCard(
                  group: g,
                  amount: y.groupTotal(g),
                  pct: y.pct(y.groupTotal(g)),
                  onTap: () => _showGroup(g),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Monthly Cost Trend',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SeriesLegend(items: [for (final g in CostGroup.values) (g.label, costGroupColors[g]!)]),
              const SizedBox(height: 12),
              SizedBox(height: 200, child: _StackedBars(year: y)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Cost by Asset Type',
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('Asset Type', style: AppText.caption)),
                    SizedBox(
                      width: 92,
                      child: Text('Amount', textAlign: TextAlign.right, style: AppText.caption),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text('%', textAlign: TextAlign.right, style: AppText.caption),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final (i, e) in y.byType.entries.indexed) ...[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: () => _showType(e.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Row(
                      children: [
                        Icon(assetTypeIcon(e.key), size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(fontSize: 13),
                          ),
                        ),
                        SizedBox(
                          width: 92,
                          child: Text(
                            _n.format(e.value),
                            textAlign: TextAlign.right,
                            style: AppText.bodyStrong.copyWith(fontSize: 13),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '${y.pct(e.value).round()}%',
                            textAlign: TextAlign.right,
                            style: AppText.secondary.copyWith(fontSize: 12.5),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text('Total', style: AppText.cardTitle)),
                    Text('AED ${_n.format(y.byType.values.fold(0, (a, b) => a + b))}', style: AppText.cardTitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.amount, required this.pct, required this.onTap});

  final CostGroup group;
  final int amount;
  final double pct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = costGroupColors[group]!;
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColorDot(color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  group.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11.5, color: AppColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_n.format(amount), style: AppText.cardTitle.copyWith(fontSize: 16)),
          ),
          Text('${pct.round()}%', style: AppText.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 4,
              color: color,
              backgroundColor: AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedBars extends StatelessWidget {
  const _StackedBars({required this.year});

  final CostYear year;

  @override
  Widget build(BuildContext context) {
    final n = year.months;
    final hi = [for (var i = 0; i < n; i++) year.monthTotal(i)].reduce(math.max);
    return BarChart(
      BarChartData(
        maxY: hi * 1.15,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, meta) => Text(compactAed(v.round()), style: AppText.caption.copyWith(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_monthLetters[v.toInt() % 12], style: AppText.caption.copyWith(fontSize: 10)),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${_monthLetters[group.x]} ${year.year}: AED ${_n.format(year.monthTotal(group.x))}\n'
              '${[for (final g in CostGroup.values) '${g.label} ${compactAed(year.monthly[g]![group.x])}'].join('\n')}',
              const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < n; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: year.monthTotal(i).toDouble(),
                  width: n > 9 ? 12 : 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  rodStackItems: [
                    for (final (from, g) in _stack(i))
                      BarChartRodStackItem(from, from + year.monthly[g]![i], costGroupColors[g]!),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// (start, group) of each stack segment of month [i], bottom first.
  List<(double, CostGroup)> _stack(int i) {
    final out = <(double, CostGroup)>[];
    var from = 0.0;
    for (final g in CostGroup.values) {
      out.add((from, g));
      from += year.monthly[g]![i];
    }
    return out;
  }
}
