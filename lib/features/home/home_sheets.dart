import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/home_mock.dart';
import '../../data/models/asset.dart';
import '../../data/repositories/home_repository.dart';

final _n = NumberFormat('#,###');

Widget _sheet(BuildContext context, String title, List<Widget> children) => SafeArea(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppText.sectionTitle),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  ),
);

/// Maintenance KPI explanation with a 6-month trend.
Future<void> showKpiSheet(BuildContext context, MaintenanceKpi kpi) {
  final first = kpi.trend.first, last = kpi.trend.last;
  final improved = kpi.higherIsBetter ? last >= first : last <= first;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _sheet(ctx, kpi.label, [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            kpi.valueText,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.green),
          ),
          if (kpi.unit != '%')
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                kpi.unit,
                style: const TextStyle(fontSize: 15, color: AppColors.green, fontWeight: FontWeight.w600),
              ),
            ),
          const Spacer(),
          StatusChip(
            improved ? 'Improving' : 'Worsening',
            tone: improved ? ChipTone.green : ChipTone.red,
            icon: improved ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(kpi.description, style: AppText.secondary.copyWith(fontSize: 13.5, height: 1.4)),
      const SizedBox(height: 18),
      const Text('Last 6 months', style: AppText.bodyStrong),
      const SizedBox(height: 10),
      SizedBox(
        height: 170,
        child: _TrendChart(values: kpi.trend, labels: kpiMonths),
      ),
    ]),
  );
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final lo = values.reduce((a, b) => a < b ? a : b), hi = values.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) * .3 + .5;
    return LineChart(
      LineChartData(
        minY: lo - pad,
        maxY: hi + pad,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) => Text(meta.formattedValue, style: AppText.caption.copyWith(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  labels[v.toInt().clamp(0, labels.length - 1)],
                  style: AppText.caption.copyWith(fontSize: 10.5),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem('${labels[s.x.toInt()]}: ${s.y}', const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: .08)),
          ),
        ],
      ),
    );
  }
}

const healthColors = {
  'Condition': AppColors.green,
  'Utilization': Color(0xFF34C77B),
  'Maintenance': Color(0xFFF5B800),
  'Inspection': Color(0xFFC04BE8),
  'IoT Status': Color(0xFF2563EB),
};

const _healthHelp = {
  'Condition': 'Physical condition from the latest inspections.',
  'Utilization': 'Running hours against planned hours.',
  'Maintenance': 'PM done on time and open breakdowns.',
  'Inspection': 'Checklists passed without findings.',
  'IoT Status': 'Devices online and reporting.',
};

String healthLabel(int pct) => pct >= 80 ? 'Good' : (pct >= 60 ? 'Fair' : 'Poor');

Future<void> showHealthSheet(BuildContext context, OrgSummary org) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _sheet(ctx, 'Asset Health – ${org.health}% ${healthLabel(org.health)}', [
      Text(
        'Asset health is the average of five scores across all ${_n.format(org.totalAssets)} assets.',
        style: AppText.secondary,
      ),
      const SizedBox(height: 14),
      for (final e in org.healthBreakdown.entries) ...[
        Row(
          children: [
            Expanded(child: Text(e.key, style: AppText.bodyStrong)),
            Text('${e.value}%', style: AppText.bodyStrong),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: e.value / 100,
            minHeight: 8,
            color: healthColors[e.key],
            backgroundColor: AppColors.divider,
          ),
        ),
        const SizedBox(height: 4),
        Text(_healthHelp[e.key] ?? '', style: AppText.caption),
        const SizedBox(height: 12),
      ],
    ]),
  );
}

const costColors = [
  Color(0xFF2F80ED),
  Color(0xFF22B35E),
  Color(0xFFF5B800),
  Color(0xFFB74CE8),
  Color(0xFFF2711C),
  Color(0xFF7C8595),
];

/// "1.25M", "480K".
String compactAed(int v) {
  if (v >= 1000000) {
    final s = (v / 1000000).toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return '${s}M';
  }
  if (v >= 1000) return '${(v / 1000).round()}K';
  return '$v';
}

Future<void> showCostSheet(BuildContext context, OrgSummary org) {
  final entries = org.costs.entries.toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _sheet(ctx, 'Cost Breakdown (AED)', [
      Text('Year to date across all sites. Total AED ${_n.format(org.totalCost)}.', style: AppText.secondary),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 14,
          child: Row(
            children: [
              for (var i = 0; i < entries.length; i++)
                Expanded(
                  flex: entries[i].value,
                  child: Container(color: costColors[i % costColors.length]),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < entries.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: costColors[i % costColors.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(entries[i].key, style: AppText.body)),
              Text(_n.format(entries[i].value), style: AppText.bodyStrong),
              SizedBox(
                width: 52,
                child: Text(
                  '${org.costPct(entries[i].key).round()}%',
                  textAlign: TextAlign.right,
                  style: AppText.secondary,
                ),
              ),
            ],
          ),
        ),
      const Divider(height: 20),
      Row(
        children: [
          const Expanded(child: Text('Total', style: AppText.cardTitle)),
          Text('AED ${_n.format(org.totalCost)}', style: AppText.cardTitle),
        ],
      ),
    ]),
  );
}
