import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/reports_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/audits_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';

(IconData, TileTone) _look(String id) => switch (id) {
  'asset-status' => (Icons.inventory_2_outlined, TileTone.lavender),
  'maintenance' => (Icons.build_circle_outlined, TileTone.peach),
  'inventory' => (Icons.category_outlined, TileTone.sky),
  'inspection' => (Icons.fact_check_outlined, TileTone.mint),
  _ => (Icons.verified_user_outlined, TileTone.cyan),
};

List<Color> get _seriesColors => [AppColors.primary, AppColors.iconOrange];

/// Three headline figures per report, from the live repositories.
List<(String, String)> _kpis(WidgetRef ref, String id) {
  switch (id) {
    case 'asset-status':
      final org = ref.watch(orgSummaryProvider);
      return [
        ('Total', formatCount(org.totalAssets)),
        ('Active', formatCount(org.statusCounts[AssetStatus.active] ?? 0)),
        ('Under Maint.', formatCount(org.statusCounts[AssetStatus.underMaintenance] ?? 0)),
      ];
    case 'maintenance':
      final wos = ref.watch(workOrdersProvider);
      return [
        ('Active WOs', '${wos.active.length}'),
        ('Overdue', '${wos.overdue.length}'),
        ('PM Compliance', '${ref.watch(orgSummaryProvider).pmCompliancePct}%'),
      ];
    case 'inventory':
      final inv = ref.watch(inventoryProvider);
      return [
        ('Items', '${inv.totalItems}'),
        ('Low Stock', '${inv.lowStock.length}'),
        ('Out of Stock', '${inv.outOfStock.length}'),
      ];
    case 'inspection':
      final ins = ref.watch(inspectionsProvider);
      return [
        ('Due Today', '${ins.dueToday.length}'),
        ('Overdue', '${ins.overdue.length}'),
        ('Completed', '${ins.completed.length}'),
      ];
    default:
      final audits = ref.watch(auditsProvider);
      return [
        ('Audits', '${audits.length}'),
        ('Verified', formatCount(audits.fold(0, (s, a) => s + a.verified))),
        ('Not Found', formatCount(audits.fold(0, (s, a) => s + a.notFound))),
      ];
  }
}

/// Reports & Analytics: one card per report.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Reports & Analytics',
            subtitle: 'Charts and exports for every module',
            help:
                'Open a report to see its chart for a date range. Export saves the chart data as CSV or copies a summary.',
          ),
          const SizedBox(height: 14),
          LoadingGate(
            rows: 5,
            child: reportDefs.isEmpty
                ? const EmptyState(icon: Icons.bar_chart_rounded, title: 'No reports yet')
                : Column(children: [for (final r in reportDefs) _ReportCard(def: r)]),
          ),
        ],
      ),
    );
  }
}

/// One report in the list: icon, title, subtitle and its three live figures.
class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.def});

  final ReportDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, tone) = _look(def.id);
    final kpis = _kpis(ref, def.id);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push(Routes.report(def.id)),
      child: Row(
        children: [
          IconSquare(icon: icon, tone: tone, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(def.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                const SizedBox(height: 4),
                Text(
                  kpis.map((k) => '${k.$1}: ${k.$2}').join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// Export: save the chart data as CSV (system save dialog) or copy a text summary.
Future<void> _exportReport(
  BuildContext context, {
  required ReportDef def,
  required ReportRange range,
  required List<String> labels,
  required List<List<double>> series,
  required List<(String, String)> kpis,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => sheetFrame(context, [
      SheetTitle('Export ${def.title}', subtitle: '${range.label} · ${def.series.join(' vs ')}'),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: IconSquare(icon: Icons.table_chart_outlined, tone: TileTone.mint, size: 40),
        title: Text('Save as CSV', style: AppText.bodyStrong),
        subtitle: Text('Opens the system save dialog', style: AppText.caption),
        onTap: () => Navigator.pop(context, 'csv'),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: IconSquare(icon: Icons.copy_rounded, tone: TileTone.lavender, size: 40),
        title: Text('Copy summary', style: AppText.bodyStrong),
        subtitle: Text('Key figures and totals as text', style: AppText.caption),
        onTap: () => Navigator.pop(context, 'copy'),
      ),
    ]),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'copy') {
    final text = [
      '${def.title} – ${range.label} (${DemoClock.formatDate(DemoClock.now)})',
      for (final (label, value) in kpis) '$label: $value',
      for (final (i, name) in def.series.indexed)
        '$name: ${formatCount(series[i].fold<double>(0, (a, b) => a + b))}${def.unit == '%' ? ' (sum of %)' : ' ${def.unit}'}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) context.showSnack('${def.title} summary copied');
    return;
  }
  final csv = StringBuffer('Period,${def.series.join(',')}\n');
  for (var i = 0; i < labels.length; i++) {
    csv.writeln([labels[i], for (final s in series) s[i].round()].join(','));
  }
  final name = '${def.id}-${range.name}-${DemoClock.now.toIso8601String().substring(0, 10)}.csv';
  try {
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(csv.toString())),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (uri == null || !context.mounted) return; // cancelled
    context.showSnack('Saved $name');
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (context.mounted) context.showSnack('Could not open the save dialog; the CSV was copied to the clipboard');
  }
}

/// One report: KPIs, date range, chart (fl_chart) and Export.
class ReportChartScreen extends ConsumerStatefulWidget {
  const ReportChartScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<ReportChartScreen> createState() => _ReportChartScreenState();
}

class _ReportChartScreenState extends ConsumerState<ReportChartScreen> {
  ReportRange _range = ReportRange.month;

  List<String> _labels() {
    final now = DemoClock.today;
    return switch (_range) {
      ReportRange.week => [for (var i = 6; i >= 0; i--) DateFormat('E').format(now.subtract(Duration(days: i)))],
      ReportRange.month => [for (var i = 1; i <= 4; i++) 'W$i'],
      _ => [for (var i = _range.points - 1; i >= 0; i--) DateFormat('MMM').format(DateTime(now.year, now.month - i))],
    };
  }

  @override
  Widget build(BuildContext context) {
    final def = reportDefs.where((r) => r.id == widget.reportId).firstOrNull;
    if (def == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'Report not found',
          actionLabel: 'All Reports',
          onAction: () => context.go(Routes.reports),
        ),
      );
    }
    final series = reportSeries(def, _range);
    final labels = _labels();
    final kpis = _kpis(ref, def.id);
    final totals = [for (final s in series) s.fold<double>(0, (a, b) => a + b)];
    void export() => _exportReport(context, def: def, range: _range, labels: labels, series: series, kpis: kpis);

    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(
            title: def.title,
            subtitle: def.subtitle,
            trailing: IconButton(
              tooltip: 'Export',
              onPressed: export,
              icon: Icon(Icons.ios_share_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (i, (label, value)) in kpis.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    child: Column(
                      children: [
                        FittedBox(child: Text(value, style: AppText.kpiNumber.copyWith(fontSize: 19))),
                        const SizedBox(height: 2),
                        FittedBox(child: Text(label, style: AppText.caption)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(def.series.join(' vs '), style: AppText.bodyStrong)),
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<ReportRange>(
                        value: _range,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        items: [
                          for (final r in ReportRange.values)
                            DropdownMenuItem(
                              value: r,
                              child: Text(r.label, style: AppText.body.copyWith(fontSize: 12)),
                            ),
                        ],
                        onChanged: (v) => setState(() => _range = v ?? _range),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: def.chart == ReportChart.bar
                      ? _Bars(series: series, labels: labels, unit: def.unit)
                      : _Lines(series: series, labels: labels, unit: def.unit),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    for (final (i, name) in def.series.indexed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _seriesColors[i % _seriesColors.length],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            def.unit == '%'
                                ? '$name (avg ${(totals[i] / series[i].length).round()}%)'
                                : '$name (${formatCount(totals[i])})',
                            style: AppText.caption.copyWith(color: AppColors.text),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: export, icon: const Icon(Icons.download_rounded), label: const Text('Export')),
        ],
      ),
    );
  }
}

FlTitlesData _titles(List<String> labels) => FlTitlesData(
  topTitles: const AxisTitles(),
  rightTitles: const AxisTitles(),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 40,
      minIncluded: false,
      maxIncluded: false,
      getTitlesWidget: (v, meta) => Text(meta.formattedValue, style: AppText.caption.copyWith(fontSize: 10)),
    ),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      interval: 1,
      reservedSize: 24,
      getTitlesWidget: (v, _) {
        final i = v.round();
        if (i < 0 || i >= labels.length || (labels.length > 7 && i.isOdd)) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(labels[i], style: AppText.caption.copyWith(fontSize: 10)),
        );
      },
    ),
  ),
);

FlGridData get _grid => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
);

class _Bars extends StatelessWidget {
  const _Bars({required this.series, required this.labels, required this.unit});

  final List<List<double>> series;
  final List<String> labels;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final width = series.length == 1 ? 14.0 : (labels.length > 7 ? 7.0 : 11.0);
    return BarChart(
      BarChartData(
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _titles(labels),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${labels[group.x]}\n${rod.toY.round()} $unit',
              const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < labels.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                for (var s = 0; s < series.length; s++)
                  BarChartRodData(
                    toY: series[s][i],
                    width: width,
                    color: _seriesColors[s % _seriesColors.length],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.series, required this.labels, required this.unit});

  final List<List<double>> series;
  final List<String> labels;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final all = series.expand((s) => s);
    final lo = all.reduce((a, b) => a < b ? a : b), hi = all.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) * .25 + 1;
    return LineChart(
      LineChartData(
        minY: (lo - pad).clamp(0, double.infinity).toDouble(),
        maxY: unit == '%' ? (hi + pad).clamp(0, 100).toDouble() : hi + pad,
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _titles(labels),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${labels[s.x.toInt()]}: ${s.y.round()}${unit == '%' ? '%' : ' $unit'}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (var s = 0; s < series.length; s++)
            LineChartBarData(
              spots: [for (var i = 0; i < series[s].length; i++) FlSpot(i.toDouble(), series[s][i])],
              isCurved: true,
              curveSmoothness: .25,
              color: _seriesColors[s % _seriesColors.length],
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: series.length == 1,
                color: _seriesColors[s % _seriesColors.length].withValues(alpha: .08),
              ),
            ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}
