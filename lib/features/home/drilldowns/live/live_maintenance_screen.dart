import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/drilldowns/maintenance_performance_screen.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

const _periods = [3, 6, 12];

/// API mode Maintenance Performance: GET /api/dashboards/mobile/maintenance-performance with
/// `months` (period menu), `site` and `assetType` (filter sheet; the site starts from Home's
/// selector). Overview / Trends / By Asset Type keep the mock layout.
class LiveMaintenanceScreen extends ConsumerStatefulWidget {
  const LiveMaintenanceScreen({super.key});

  @override
  ConsumerState<LiveMaintenanceScreen> createState() => _LiveMaintenanceScreenState();
}

class _LiveMaintenanceScreenState extends ConsumerState<LiveMaintenanceScreen> {
  int _tab = 0;
  int _months = 6;
  late String? _site = ref.read(dashSiteProvider);
  String? _type;

  DashMaintenanceQuery get _q => (months: _months, assetType: _type, site: _site);

  Future<void> _openFilters() async {
    final sites = ref.read(dashSitesProvider).value ?? const [DashSiteNotifier.allSites];
    final types = [
      for (final t in ref.read(dashAssetOverviewProvider(null)).value?.byType ?? const <DashBreakdownItem>[])
        if (t.label.toLowerCase() != 'others') t.label,
    ];
    final result = await showModalBottomSheet<(String, String?)>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (_) =>
          MaintenanceFilterSheet(sites: sites, types: types, site: _site ?? DashSiteNotifier.allSites, type: _type),
    );
    if (result != null) {
      setState(() {
        _site = result.$1 == DashSiteNotifier.allSites ? null : result.$1;
        _type = result.$2;
      });
    }
  }

  void _reset() => setState(() {
    _site = null;
    _type = null;
  });

  @override
  Widget build(BuildContext context) {
    final provider = dashMaintenanceProvider(_q);
    final filtered = _site != null || _type != null;
    return DrilldownPage(
      title: 'Maintenance Performance',
      subtitle: 'Work orders, MTTR and MTBF',
      onRefresh: () => ref.invalidate(provider),
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
                    isLabelVisible: filtered,
                    smallSize: 8,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.filter_alt_outlined, size: 20, color: AppColors.text, semanticLabel: 'Filters'),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (filtered) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_site != null) FilterInputChip(label: _site!, onDeleted: () => setState(() => _site = null)),
              if (_type != null) FilterInputChip(label: _type!, onDeleted: () => setState(() => _type = null)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        DashSection<DashMaintenance>(
          provider: provider,
          onRetry: (ref) => ref.invalidate(provider),
          rows: 4,
          builder: (m) {
            if (m.counts.total == 0) {
              return EmptyState(
                icon: Icons.build_circle_outlined,
                title: 'No work orders',
                message: filtered
                    ? 'Nothing matches these filters in ${m.period.label.toLowerCase()}.'
                    : 'No work orders in ${m.period.label.toLowerCase()}.',
                actionLabel: filtered ? 'Reset filters' : null,
                onAction: filtered ? _reset : null,
              );
            }
            return switch (_tab) {
              0 => _Overview(m: m),
              1 => _Trends(m: m),
              _ => _ByType(
                rows: m.byAssetType,
                selected: _type,
                onTap: (t) => setState(() {
                  _type = t;
                  _tab = 0;
                }),
              ),
            };
          },
        ),
      ],
    );
  }
}

List<WoMix> _perMonth(DashMaintenance m) => [for (final t in m.trend) WoMix(t.planned, t.unplanned, t.overdue)];

/// "12.5" / "12"; "—" when the server had nothing to measure (0 with no change).
String _value(DashMetricValue v) {
  if (v.value == 0 && v.changePercent == null) return '—';
  return v.value == v.value.roundToDouble() ? '${v.value.toInt()}' : v.value.toStringAsFixed(1);
}

class _Overview extends StatelessWidget {
  const _Overview({required this.m});

  final DashMaintenance m;

  @override
  Widget build(BuildContext context) {
    final c = m.counts;
    void notConnected() => showNotAvailableYet(context, 'Work orders');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: DonutWithLegend(
            center: DonutCenter(value: dashPct(m.plannedPercent), caption: 'Planned'),
            slices: [
              DonutSlice(label: 'Planned', value: c.planned.toDouble(), color: plannedColor),
              DonutSlice(label: 'Unplanned', value: c.unplanned.toDouble(), color: unplannedColor),
              DonutSlice(label: 'Overdue', value: c.overdue.toDouble(), color: overdueColor),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CountCard(
                icon: Icons.event_available_rounded,
                value: '${c.planned}',
                label: 'Planned WOs',
                color: plannedColor,
                onTap: notConnected,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CountCard(
                icon: Icons.report_problem_rounded,
                value: '${c.unplanned}',
                label: 'Unplanned WOs',
                color: unplannedColor,
                onTap: notConnected,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CountCard(
                icon: Icons.schedule_rounded,
                value: '${c.overdue}',
                label: 'Overdue WOs',
                color: overdueColor,
                onTap: notConnected,
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
                child: WoGroupedBars(perMonth: _perMonth(m), labels: [for (final t in m.trend) t.label]),
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
                value: _value(m.mttr),
                unit: m.mttr.unit,
                caption: 'Mean Time To Repair',
                change: m.mttr.changePercent,
                higherIsBetter: false,
                changeSuffix: 'vs previous period',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'MTBF',
                value: _value(m.mtbf),
                unit: m.mtbf.unit,
                caption: 'Mean Time Between Failures',
                change: m.mtbf.changePercent,
                higherIsBetter: true,
                changeSuffix: 'vs previous period',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Trends extends StatelessWidget {
  const _Trends({required this.m});

  final DashMaintenance m;

  @override
  Widget build(BuildContext context) {
    final perMonth = _perMonth(m);
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
                  labels: [for (final t in m.trend) t.label],
                  series: [
                    ('Planned', plannedColor, [for (final x in perMonth) x.planned.toDouble()]),
                    ('Unplanned', unplannedColor, [for (final x in perMonth) x.unplanned.toDouble()]),
                    ('Overdue', overdueColor, [for (final x in perMonth) x.overdue.toDouble()]),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'MTTR / MTBF Trend',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NotAvailableYetLine(),
              const SizedBox(height: 4),
              Text(
                'The server sends one MTTR and MTBF value per period (see Overview), not one per month.',
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ByType extends StatelessWidget {
  const _ByType({required this.rows, required this.selected, required this.onTap});

  final List<DashAssetTypeMaintenance> rows;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final hi = rows.fold<int>(1, (a, r) => r.total > a ? r.total : a);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SeriesLegend(
            items: [('Planned', plannedColor), ('Unplanned', unplannedColor), ('Overdue', overdueColor)],
          ),
          const SizedBox(height: 6),
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1),
            InkWell(
              onTap: () => onTap(r.assetType),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    IconSquare(icon: assetTypeIcon(r.assetType), tone: TileTone.lavender, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.assetType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodyStrong.copyWith(
                                    fontSize: 13.5,
                                    color: r.assetType == selected ? AppColors.primary : null,
                                  ),
                                ),
                              ),
                              Text('${r.total} WOs', style: AppText.bodyStrong.copyWith(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          StackedMiniBar(
                            values: [r.planned, r.unplanned, r.overdue],
                            colors: const [plannedColor, unplannedColor, overdueColor],
                            fraction: r.total / hi,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r.planned} planned · ${r.unplanned} unplanned · ${r.overdue} overdue · '
                            '${dashPct(r.plannedPercent)} planned',
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
