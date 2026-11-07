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
import 'package:asset360_mobile/data/mock/home_mock.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/drilldowns/live/live_maintenance_screen.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

const _allSites = 'All Sites';
const _periods = [3, 6, 12];
final _month = DateFormat('MMM');

/// Home "Maintenance Performance" drill-down: Overview / Trends / By Asset Type for the
/// last 3, 6 or 12 months, filtered by site and asset type.
class MaintenancePerformanceScreen extends ConsumerStatefulWidget {
  const MaintenancePerformanceScreen({super.key});

  @override
  ConsumerState<MaintenancePerformanceScreen> createState() => _MaintenancePerformanceScreenState();
}

class _MaintenancePerformanceScreenState extends ConsumerState<MaintenancePerformanceScreen> {
  int _tab = 0;
  int _months = 6;
  String _site = _allSites;
  String? _type;

  bool _rowMatches(MaintenanceMonth r, {bool byType = true}) =>
      (_site == _allSites || r.site == _site) && (!byType || _type == null || r.type == _type);

  Future<void> _openFilters() async {
    final sites = ref.read(sitesProvider);
    final result = await showModalBottomSheet<(String, String?)>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (_) => MaintenanceFilterSheet(sites: sites, types: homeAssetTypes, site: _site, type: _type),
    );
    if (result != null) {
      setState(() {
        _site = result.$1;
        _type = result.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (apiMode) return const LiveMaintenanceScreen();
    final all = ref.watch(maintenanceMonthsProvider);
    final months = lastMonths(_months);
    final inPeriod = all.where((r) => months.contains(r.month)).toList();
    final rows = inPeriod.where(_rowMatches).toList();
    final mix = WoMix.of(rows);
    final perMonth = [for (final m in months) WoMix.of(rows.where((r) => r.month == m))];
    final labels = [for (final m in months) _month.format(m)];

    final Widget content;
    if (mix.total == 0) {
      content = EmptyState(
        icon: Icons.build_circle_outlined,
        title: 'No work orders',
        message: 'Nothing matches these filters in the selected period.',
        actionLabel: 'Reset filters',
        onAction: () => setState(() {
          _site = _allSites;
          _type = null;
        }),
      );
    } else {
      content = switch (_tab) {
        0 => _Overview(mix: mix, perMonth: perMonth, labels: labels),
        1 => _Trends(perMonth: perMonth, labels: labels, months: _months),
        _ => _ByType(
          rows: inPeriod.where((r) => _rowMatches(r, byType: false)).toList(),
          selected: _type,
          onTap: (t) => setState(() {
            _type = t;
            _tab = 0;
          }),
        ),
      };
    }

    return DrilldownPage(
      title: 'Maintenance Performance',
      subtitle: 'Work orders, MTTR and MTBF',
      skeletonRows: 4,
      children: [
        SegmentTabs(
          tabs: const [SegmentTab('Overview'), SegmentTab('Trends'), SegmentTab('By Asset Type')],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PopupMenuButton<int>(
              key: const ValueKey('period'),
              tooltip: 'Period',
              initialValue: _months,
              onSelected: (m) => setState(() => _months = m),
              itemBuilder: (_) => [for (final m in _periods) PopupMenuItem(value: m, child: Text('Last $m Months'))],
              child: PeriodDropdown(label: 'Last $_months Months'),
            ),
            const Spacer(),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openFilters,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Badge(
                    isLabelVisible: _site != _allSites || _type != null,
                    smallSize: 8,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.filter_alt_outlined, size: 20, color: AppColors.text, semanticLabel: 'Filters'),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_site != _allSites || _type != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_site != _allSites) FilterInputChip(label: _site, onDeleted: () => setState(() => _site = _allSites)),
              if (_type != null) FilterInputChip(label: _type!, onDeleted: () => setState(() => _type = null)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        content,
      ],
    );
  }
}

class PeriodDropdown extends StatelessWidget {
  const PeriodDropdown({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label, style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.text),
      ],
    ),
  );
}

class FilterInputChip extends StatelessWidget {
  const FilterInputChip({super.key, required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) => InputChip(
    label: Text(label),
    labelStyle: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
    backgroundColor: AppColors.primarySoft,
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
    deleteIconColor: AppColors.primary,
    onDeleted: onDeleted,
  );
}

/// Site + Asset Type filter; pops (site, type) — "All Sites" / null = no filter.
class MaintenanceFilterSheet extends StatefulWidget {
  const MaintenanceFilterSheet({
    super.key,
    required this.sites,
    required this.types,
    required this.site,
    required this.type,
  });

  final List<String> sites;
  final List<String> types;
  final String site;
  final String? type;

  @override
  State<MaintenanceFilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<MaintenanceFilterSheet> {
  late String _site = widget.site;
  late String? _type = widget.type;

  Widget _choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    selectedColor: AppColors.primary,
    labelStyle: TextStyle(fontSize: 12.5, color: selected ? Colors.white : AppColors.text),
    onSelected: (_) => onTap(),
  );

  @override
  Widget build(BuildContext context) => sheetFrame(context, [
    const SheetTitle('Filters', subtitle: 'Narrow the work order figures'),
    Text('Site', style: AppText.bodyStrong),
    const SizedBox(height: 8),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final s in widget.sites) _choice(s, _site == s, () => setState(() => _site = s))],
    ),
    const SizedBox(height: 16),
    Text('Asset Type', style: AppText.bodyStrong),
    const SizedBox(height: 8),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _choice('All Types', _type == null, () => setState(() => _type = null)),
        for (final t in widget.types) _choice(t, _type == t, () => setState(() => _type = t)),
      ],
    ),
    const SizedBox(height: 20),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: () => Navigator.pop(context, (_allSites, null)), child: const Text('Reset')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(onPressed: () => Navigator.pop(context, (_site, _type)), child: const Text('Apply')),
        ),
      ],
    ),
  ]);
}

// ---------------------------------------------------------------- Overview

class _Overview extends StatelessWidget {
  const _Overview({required this.mix, required this.perMonth, required this.labels});

  final WoMix mix;
  final List<WoMix> perMonth;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final mttr = mttrPerMonth.last, mttrPrev = mttrPerMonth[mttrPerMonth.length - 2];
    final mtbf = mtbfPerMonth.last, mtbfPrev = mtbfPerMonth[mtbfPerMonth.length - 2];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: DonutWithLegend(
            center: DonutCenter(value: '${mix.pct(mix.planned).round()}%', caption: 'Planned'),
            slices: [
              DonutSlice(label: 'Planned', value: mix.planned.toDouble(), color: plannedColor),
              DonutSlice(label: 'Unplanned', value: mix.unplanned.toDouble(), color: unplannedColor),
              DonutSlice(label: 'Overdue', value: mix.overdue.toDouble(), color: overdueColor),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CountCard(
                icon: Icons.event_available_rounded,
                value: '${mix.planned}',
                label: 'Planned WOs',
                color: plannedColor,
                onTap: () => context.push(Routes.maintenanceTab('pm')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CountCard(
                icon: Icons.report_problem_rounded,
                value: '${mix.unplanned}',
                label: 'Unplanned WOs',
                color: unplannedColor,
                onTap: () => context.push(Routes.breakdowns),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CountCard(
                icon: Icons.schedule_rounded,
                value: '${mix.overdue}',
                label: 'Overdue WOs',
                color: overdueColor,
                onTap: () => context.push(Routes.maintenanceTab('overdue')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Work Order Trend',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SeriesLegend(
                items: [('Planned', plannedColor), ('Unplanned', unplannedColor), ('Overdue', overdueColor)],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: WoGroupedBars(perMonth: perMonth, labels: labels),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'MTTR',
                value: '$mttr',
                unit: 'hrs',
                caption: 'Mean Time To Repair',
                change: (mttr - mttrPrev) * 100 / mttrPrev,
                higherIsBetter: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'MTBF',
                value: mtbf.round().toString(),
                unit: 'days',
                caption: 'Mean Time Between Failures',
                change: (mtbf - mtbfPrev) * 100 / mtbfPrev,
                higherIsBetter: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.caption,
    required this.change,
    required this.higherIsBetter,
    this.changeSuffix = 'vs last month',
  });

  final String label;
  final String value;
  final String unit;
  final String caption;

  /// Change in percent against the previous period; null = nothing to compare.
  final double? change;
  final bool higherIsBetter;

  /// Text after the change ("vs last month").
  final String changeSuffix;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.bodyStrong),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          style: TextStyle(color: AppColors.text),
        ),
        const SizedBox(height: 2),
        Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: change == null
              ? Text('No previous period to compare', style: AppText.caption.copyWith(fontSize: 11))
              : ChangeChip(pct: change!, higherIsBetter: higherIsBetter, suffix: changeSuffix),
        ),
      ],
    ),
  );
}

FlTitlesData _titles(List<String> labels, {String Function(double)? left}) => FlTitlesData(
  topTitles: const AxisTitles(),
  rightTitles: const AxisTitles(),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 30,
      getTitlesWidget: (v, meta) =>
          Text(left?.call(v) ?? meta.formattedValue, style: AppText.caption.copyWith(fontSize: 10)),
    ),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      interval: 1,
      getTitlesWidget: (v, _) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          v == v.roundToDouble() && v >= 0 && v < labels.length ? labels[v.toInt()] : '',
          style: AppText.caption.copyWith(fontSize: 10),
        ),
      ),
    ),
  ),
);

FlGridData get _grid => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
);

class WoGroupedBars extends StatelessWidget {
  const WoGroupedBars({super.key, required this.perMonth, required this.labels});

  final List<WoMix> perMonth;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final hi = perMonth.fold<int>(1, (a, m) => math.max(a, math.max(m.planned, math.max(m.unplanned, m.overdue))));
    final width = perMonth.length > 6 ? 3.5 : 6.0;
    const names = ['Planned', 'Unplanned', 'Overdue'];
    return BarChart(
      BarChartData(
        maxY: hi * 1.2,
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _titles(labels),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
              '${labels[group.x]} · ${names[rodIndex]}\n${rod.toY.toInt()} WOs',
              const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        barGroups: [
          for (final (i, m) in perMonth.indexed)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                for (final (v, c) in [
                  (m.planned, plannedColor),
                  (m.unplanned, unplannedColor),
                  (m.overdue, overdueColor),
                ])
                  BarChartRodData(
                    toY: v.toDouble(),
                    width: width,
                    color: c,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Trends

class _Trends extends StatelessWidget {
  const _Trends({required this.perMonth, required this.labels, required this.months});

  final List<WoMix> perMonth;
  final List<String> labels;
  final int months;

  @override
  Widget build(BuildContext context) {
    final mttr = mttrPerMonth.sublist(mttrPerMonth.length - months);
    final mtbf = mtbfPerMonth.sublist(mtbfPerMonth.length - months);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Work Orders per Month',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SeriesLegend(
                items: [('Planned', plannedColor), ('Unplanned', unplannedColor), ('Overdue', overdueColor)],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: WoLines(
                  labels: labels,
                  series: [
                    ('Planned', plannedColor, [for (final m in perMonth) m.planned.toDouble()]),
                    ('Unplanned', unplannedColor, [for (final m in perMonth) m.unplanned.toDouble()]),
                    ('Overdue', overdueColor, [for (final m in perMonth) m.overdue.toDouble()]),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'MTTR Trend (hrs)',
          child: SizedBox(
            height: 160,
            child: WoLines(labels: labels, unit: 'hrs', series: [('MTTR', AppColors.green, mttr)]),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'MTBF Trend (days)',
          child: SizedBox(
            height: 160,
            child: WoLines(labels: labels, unit: 'days', series: [('MTBF', AppColors.iconBlue, mtbf)]),
          ),
        ),
      ],
    );
  }
}

class WoLines extends StatelessWidget {
  const WoLines({super.key, required this.labels, required this.series, this.unit = 'WOs'});

  final List<String> labels;
  final List<(String, Color, List<double>)> series;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) ...s.$3];
    final lo = all.reduce(math.min), hi = all.reduce(math.max);
    final pad = math.max((hi - lo) * .2, .5);
    return LineChart(
      LineChartData(
        minY: math.max(0, lo - pad),
        maxY: hi + pad,
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _titles(labels, left: (v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1)),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${labels[s.x.toInt()]} · ${series[s.barIndex].$1}: '
                  '${s.y == s.y.roundToDouble() ? s.y.toInt() : s.y} $unit',
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (final (_, color, values) in series)
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: series.length == 1, color: color.withValues(alpha: .08)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- By asset type

class _ByType extends StatelessWidget {
  const _ByType({required this.rows, required this.selected, required this.onTap});

  final List<MaintenanceMonth> rows;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final mixes = {for (final t in homeAssetTypes) t: WoMix.of(rows.where((r) => r.type == t))};
    final hi = mixes.values.fold<int>(1, (a, m) => math.max(a, m.total));
    final types = homeAssetTypes.where((t) => mixes[t]!.total > 0).toList();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeriesLegend(
            items: [('Planned', plannedColor), ('Unplanned', unplannedColor), ('Overdue', overdueColor)],
          ),
          const SizedBox(height: 6),
          for (final (i, t) in types.indexed) ...[
            if (i > 0) const Divider(height: 1),
            InkWell(
              onTap: () => onTap(t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    IconSquare(icon: assetTypeIcon(t), tone: TileTone.lavender, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodyStrong.copyWith(
                                    fontSize: 13.5,
                                    color: t == selected ? AppColors.primary : null,
                                  ),
                                ),
                              ),
                              Text('${mixes[t]!.total} WOs', style: AppText.bodyStrong.copyWith(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          StackedMiniBar(
                            values: [mixes[t]!.planned, mixes[t]!.unplanned, mixes[t]!.overdue],
                            colors: const [plannedColor, unplannedColor, overdueColor],
                            fraction: mixes[t]!.total / hi,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${mixes[t]!.planned} planned · ${mixes[t]!.unplanned} unplanned · '
                            '${mixes[t]!.overdue} overdue',
                            style: AppText.caption.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
