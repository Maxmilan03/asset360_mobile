import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/cost_summary_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

/// The category keys the server sends, as the mock's cost groups (same colours and cards).
CostGroup? _groupOf(String key) => switch (key) {
  'maintenance' => CostGroup.maintenance,
  'operations' => CostGroup.operations,
  'spare-parts' => CostGroup.spareParts,
  _ => null,
};

/// API mode Cost Summary: GET /api/dashboards/mobile/cost-summary with `period` + `year` (menu:
/// YTD this year, the whole of last year, last 12 months). Costs come from work orders (labour,
/// additional costs, parts); there is no site filter on the server.
class LiveCostSummaryScreen extends ConsumerStatefulWidget {
  const LiveCostSummaryScreen({super.key});

  @override
  ConsumerState<LiveCostSummaryScreen> createState() => _LiveCostSummaryScreenState();
}

class _LiveCostSummaryScreenState extends ConsumerState<LiveCostSummaryScreen> {
  static final _year = DateTime.now().year;

  /// Menu: label + query.
  static final _choices = <(String, DashCostQuery)>[
    ('YTD $_year', (period: DashCostPeriod.ytd, year: null)),
    ('${_year - 1}', (period: DashCostPeriod.year, year: _year - 1)),
    ('Last 12 Months', (period: DashCostPeriod.last12Months, year: null)),
  ];

  int _choice = 0;

  @override
  Widget build(BuildContext context) {
    final q = _choices[_choice].$2;
    final provider = dashCostSummaryProvider(q);
    final currency = ref.watch(provider).value?.currency ?? 'AED';
    return DrilldownPage(
      title: 'Cost Summary ($currency)',
      subtitle: 'Work order costs across all sites',
      onRefresh: () => ref.invalidate(provider),
      trailing: PopupMenuButton<int>(
        key: const ValueKey('costPeriod'),
        tooltip: 'Period',
        initialValue: _choice,
        onSelected: (i) => setState(() => _choice = i),
        itemBuilder: (_) => [for (final (i, c) in _choices.indexed) PopupMenuItem(value: i, child: Text(c.$1))],
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
              Text(_choices[_choice].$1, style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.text),
            ],
          ),
        ),
      ),
      children: [
        DashSection<DashCostSummary>(
          provider: provider,
          onRetry: (ref) => ref.invalidate(provider),
          rows: 4,
          isEmpty: (c) => c.totalCost == 0 && c.previousPeriodCost == 0,
          emptyIcon: Icons.payments_outlined,
          emptyTitle: 'No costs recorded',
          emptyMessage: 'No work order costs in ${_choices[_choice].$1} or the year before.',
          builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _content(c)),
        ),
      ],
    );
  }

  List<Widget> _content(DashCostSummary c) {
    final groups = [
      for (final g in c.categories)
        if (_groupOf(g.key) != null) (_groupOf(g.key)!, g),
    ];
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Cost · ${c.period.label}', style: AppText.secondary),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${c.currency} ${dashMoney(c.totalCost)}',
                style: AppText.pageTitle.copyWith(fontSize: 28, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            if (c.changePercent != null)
              ChangeChip(pct: c.changePercent!, higherIsBetter: false, suffix: 'vs same period last year')
            else
              Text(
                'Same period last year: ${c.currency} ${dashMoney(c.previousPeriodCost)}',
                style: AppText.caption.copyWith(fontSize: 12),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, (group, g)) in groups.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: CostGroupCard(group: group, amount: g.amount.round(), pct: g.percent),
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
            SizedBox(
              height: 200,
              child: _StackedBars(points: c.monthlyTrend, currency: c.currency),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Cost by Asset Type',
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: c.byAssetType.isEmpty
            ? const EmptyState(icon: Icons.category_outlined, title: 'No costs by asset type in this period')
            : Column(
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
                  for (final (i, t) in c.byAssetType.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    InkWell(
                      onTap: t.assetType.toLowerCase() == 'others'
                          ? () => context.showSnack('"Others" groups the smaller asset types and assets without one')
                          : () => context.push(Routes.recentAssetsFiltered(type: t.assetType)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        child: Row(
                          children: [
                            Icon(assetTypeIcon(t.assetType), size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.assetType,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 92,
                              child: Text(
                                dashMoney(t.amount),
                                textAlign: TextAlign.right,
                                style: AppText.bodyStrong.copyWith(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(
                                dashPct(t.percent),
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
                        Text('${c.currency} ${dashMoney(c.totalCost)}', style: AppText.cardTitle),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    ];
  }
}

/// Monthly stacked bars: maintenance / operations / spare parts per month.
class _StackedBars extends StatelessWidget {
  const _StackedBars({required this.points, required this.currency});

  final List<DashCostTrendPoint> points;
  final String currency;

  static List<double> _parts(DashCostTrendPoint p) => [p.maintenance, p.operations, p.spareParts];

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: NotAvailableYetLine());
    final hi = points.map((p) => p.total).fold<double>(0, math.max);
    return BarChart(
      BarChartData(
        maxY: hi <= 0 ? 1 : hi * 1.15,
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
                child: Text(
                  v.toInt() >= 0 && v.toInt() < points.length ? points[v.toInt()].label : '',
                  style: AppText.caption.copyWith(fontSize: 10),
                ),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, _, rod, _) {
              final p = points[group.x];
              return BarTooltipItem(
                '${p.label} ${p.month.split('-').first}: $currency ${dashMoney(p.total)}\n'
                '${[for (final (i, g) in CostGroup.values.indexed) '${g.label} ${compactAed(_parts(p)[i].round())}'].join('\n')}',
                const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
              );
            },
          ),
        ),
        barGroups: [
          for (final (i, p) in points.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: p.total,
                  width: points.length > 9 ? 12 : 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  rodStackItems: [
                    for (final (j, g) in CostGroup.values.indexed)
                      BarChartRodStackItem(
                        _parts(p).take(j).fold(0, (a, b) => a + b),
                        _parts(p).take(j + 1).fold(0, (a, b) => a + b),
                        costGroupColors[g]!,
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
