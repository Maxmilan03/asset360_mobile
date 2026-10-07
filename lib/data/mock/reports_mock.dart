import 'dart:math' as math;

enum ReportRange {
  week('Last 7 days', 7),
  month('Last 30 days', 4),
  quarter('Last 90 days', 3),
  year('Last 12 months', 12);

  const ReportRange(this.label, this.points);

  final String label;

  /// Chart points: days, weeks, months or months.
  final int points;
}

enum ReportChart { bar, line }

class ReportDef {
  const ReportDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.chart,
    required this.series,
    required this.unit,
    required this.base,
  });

  final String id;
  final String title;
  final String subtitle;
  final ReportChart chart;

  /// Series names, e.g. Opened / Completed.
  final List<String> series;
  final String unit;

  /// Typical value per series for one day (scaled up for weeks / months). For
  /// percentage series the value is used as-is.
  final List<double> base;
}

const reportDefs = [
  ReportDef(
    id: 'asset-status',
    title: 'Asset Status',
    subtitle: 'Registrations and retirements over time',
    chart: ReportChart.bar,
    series: ['Registered', 'Retired / Disposed'],
    unit: 'assets',
    base: [9, 3],
  ),
  ReportDef(
    id: 'maintenance',
    title: 'Maintenance Performance',
    subtitle: 'Work orders opened vs completed',
    chart: ReportChart.bar,
    series: ['Opened', 'Completed'],
    unit: 'work orders',
    base: [14, 13],
  ),
  ReportDef(
    id: 'inventory',
    title: 'Inventory Usage',
    subtitle: 'Spare parts issued and received',
    chart: ReportChart.line,
    series: ['Issued', 'Received'],
    unit: 'units',
    base: [42, 38],
  ),
  ReportDef(
    id: 'inspection',
    title: 'Inspection Compliance',
    subtitle: 'Inspections completed on time',
    chart: ReportChart.line,
    series: ['On-time %'],
    unit: '%',
    base: [93],
  ),
  ReportDef(
    id: 'audit',
    title: 'Audit Results',
    subtitle: 'Assets verified vs not found',
    chart: ReportChart.bar,
    series: ['Verified', 'Not Found'],
    unit: 'assets',
    base: [120, 4],
  ),
];

/// Deterministic demo series for a report: one list per series, [range.points] values each.
List<List<double>> reportSeries(ReportDef def, ReportRange range) {
  final daysPerPoint = switch (range) {
    ReportRange.week => 1,
    ReportRange.month => 7,
    ReportRange.quarter || ReportRange.year => 30,
  };
  final seed = def.id.codeUnits.fold<int>(0, (s, c) => s + c) + range.index * 7;
  return [
    for (var s = 0; s < def.series.length; s++)
      [
        for (var i = 0; i < range.points; i++)
          () {
            final wave = 1 + .18 * math.sin((i + seed + s * 3) * 1.3) + .08 * math.cos((i * 2 + seed) * .7);
            if (def.unit == '%') return (def.base[s] + 4 * math.sin((i + seed) * 1.1)).clamp(0, 100).roundToDouble();
            return (def.base[s] * daysPerPoint * wave).roundToDouble();
          }(),
      ],
  ];
}
