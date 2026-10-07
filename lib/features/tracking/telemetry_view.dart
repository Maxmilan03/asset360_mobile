import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/common.dart';
import '../../data/models/tracking.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/repo_utils.dart';
import '../../data/repositories/tracking_repository.dart';
import 'tracking_widgets.dart';

/// Chart-ready history: x = hours since the first point, with axis / tooltip formatters.
class ChartSeries {
  ChartSeries(List<TimedValue> history, this.range)
    : start = history.first.at,
      points = [for (final p in history) TrendPoint(p.at.difference(history.first.at).inMinutes / 60, p.value)];

  final DateTime start;
  final TelemetryRange range;
  final List<TrendPoint> points;

  DateTime timeAt(double x) => start.add(Duration(minutes: (x * 60).round()));

  String axisLabel(double x) => switch (range) {
    TelemetryRange.week => DateFormat('EEE').format(timeAt(x)),
    _ => DateFormat('HH:mm').format(timeAt(x)),
  };

  String tooltipTime(double x) => switch (range) {
    TelemetryRange.week => DateFormat('EEE d MMM, hh:mm a').format(timeAt(x)),
    _ => DateFormat('hh:mm a').format(timeAt(x)),
  };

  double get interval => switch (range) {
    TelemetryRange.hour => 1 / 6,
    TelemetryRange.day => 4,
    TelemetryRange.week => 24,
  };
}

/// Dropdown: Last 1 Hour / Last 24 Hours / Last 7 Days.
class RangeDropdown extends StatelessWidget {
  const RangeDropdown({super.key, required this.value, required this.onChanged});

  final TelemetryRange value;
  final ValueChanged<TelemetryRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TelemetryRange>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: AppText.body.copyWith(fontSize: 12.5, color: AppColors.text),
          selectedItemBuilder: (_) => [
            for (final r in TelemetryRange.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(r.label),
                  ],
                ),
              ),
          ],
          items: [for (final r in TelemetryRange.values) DropdownMenuItem(value: r, child: Text(r.label))],
          onChanged: (r) => r == null ? null : onChanged(r),
        ),
      ),
    );
  }
}

/// Telemetry tab of Asset Tracking (right screen of design 06): range, 3×3 metric tiles with
/// sparklines, and the Sensor History chart of the selected tile.
class TelemetryView extends ConsumerStatefulWidget {
  const TelemetryView({super.key, required this.assetId});

  final String assetId;

  @override
  ConsumerState<TelemetryView> createState() => _TelemetryViewState();
}

class _TelemetryViewState extends ConsumerState<TelemetryView> {
  TelemetryRange _range = TelemetryRange.day;
  String _metric = 'battery';

  @override
  Widget build(BuildContext context) {
    final asset = ref.watch(assetsProvider).firstWhereOrNull((a) => a.id == widget.assetId);
    if (asset == null) return const SizedBox.shrink();
    final metrics = metricsFor(
      asset,
      ref.watch(trackingProvider).vehicle(asset.id),
      sensors: ref.watch(sensorsProvider),
    );
    final chartable = metrics.where((m) => m.chartable).toList();
    if (chartable.isEmpty) {
      return const EmptyState(
        icon: Icons.sensors_off_rounded,
        title: 'No telemetry',
        message: 'This asset has no IoT sensors. Link a device from the asset’s More Actions.',
      );
    }
    final selected = chartable.firstWhereOrNull((m) => m.key == _metric) ?? chartable.first;
    final series = ChartSeries(telemetryHistory(asset.id, selected, _range), _range);
    final (_, color) = metricLook(selected.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: RangeDropdown(value: _range, onChanged: (r) => setState(() => _range = r)),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: .98,
          children: [
            for (final m in metrics)
              _MetricTile(
                metric: m,
                history: m.chartable ? [for (final p in telemetryHistory(asset.id, m, _range)) p.value] : const [],
                selected: m.key == selected.key,
                onTap: () {
                  if (!m.chartable) {
                    context.showSnack('${m.label}: ${m.display.replaceAll('\n', ' / ')}');
                    return;
                  }
                  setState(() => _metric = m.key);
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Sensor History',
          actionLabel: 'View All',
          actionIcon: null,
          onAction: () => context.push(Routes.trackChart(asset.id, selected.key, range: _range.name)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${selected.label}${selected.unit.isEmpty ? '' : ' (${selected.unit})'}', style: AppText.secondary),
              const SizedBox(height: 10),
              SizedBox(
                height: 170,
                child: TrendChart(
                  key: ValueKey('${selected.key}/${_range.name}'),
                  points: series.points,
                  unit: selected.unit,
                  xLabel: series.axisLabel,
                  tooltipTime: series.tooltipTime,
                  xInterval: series.interval,
                  minY: selected.key == 'battery' ? 0 : null,
                  maxY: selected.key == 'battery' ? 100 : null,
                  decimals: selected.decimals,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.history, required this.selected, required this.onTap});

  final TrackMetric metric;
  final List<double> history;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = metricLook(metric.key);
    final m = metric;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      m.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 10.5, color: AppColors.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (m.chartable)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(m.display, style: AppText.bodyStrong.copyWith(fontSize: 16)),
                )
              else
                Expanded(
                  child: Text(
                    m.display,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(fontSize: 11, color: AppColors.text),
                  ),
                ),
              if (m.chartable) const Spacer(),
              if (m.key == 'battery')
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: m.value / 100,
                    minHeight: 6,
                    color: AppColors.green,
                    backgroundColor: AppColors.greyBg,
                  ),
                )
              else if (m.key == 'signal')
                SignalBars(rssi: m.value.round(), height: 16)
              else if (history.length > 1)
                Sparkline(values: history, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen chart of one metric with a pinch-zoomable timeline (Sensor History → View All).
class TelemetryChartScreen extends ConsumerStatefulWidget {
  const TelemetryChartScreen({super.key, required this.assetId, required this.metric, this.range});

  final String assetId;
  final String metric;
  final String? range;

  @override
  ConsumerState<TelemetryChartScreen> createState() => _TelemetryChartScreenState();
}

class _TelemetryChartScreenState extends ConsumerState<TelemetryChartScreen> {
  late TelemetryRange _range = TelemetryRange.values.firstWhere(
    (r) => r.name == widget.range,
    orElse: () => TelemetryRange.day,
  );

  @override
  Widget build(BuildContext context) {
    final asset = ref.watch(assetsProvider).firstWhereOrNull((a) => a.id == widget.assetId);
    final metric = asset == null
        ? null
        : metricsFor(
            asset,
            ref.watch(trackingProvider).vehicle(asset.id),
            sensors: ref.watch(sensorsProvider),
          ).firstWhereOrNull((m) => m.key == widget.metric && m.chartable);
    if (asset == null || metric == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.sensors_off_rounded,
          title: 'No data',
          message: '${widget.assetId} does not report ${widget.metric}.',
        ),
      );
    }
    final history = telemetryHistory(asset.id, metric, _range);
    final series = ChartSeries(history, _range);
    final values = history.map((p) => p.value);
    final avg = values.reduce((a, b) => a + b) / values.length;
    final (_, color) = metricLook(metric.key);
    String fmt(double v) => '${v.toStringAsFixed(metric.decimals)} ${metric.unit}'.trim();
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(title: metric.label, subtitle: '${asset.id} · ${asset.name}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final r in TelemetryRange.values)
                IconFilterChip(label: r.label, selected: r == _range, onTap: () => setState(() => _range = r)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (label, v) in [
                ('Now', metric.value),
                ('Min', values.reduce(math.min)),
                ('Avg', avg),
                ('Max', values.reduce(math.max)),
              ]) ...[
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      children: [
                        Text(label, style: AppText.caption),
                        const SizedBox(height: 4),
                        FittedBox(child: Text(fmt(v), style: AppText.bodyStrong)),
                      ],
                    ),
                  ),
                ),
                if (label != 'Max') const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 340,
              child: TrendChart(
                key: ValueKey(_range),
                points: series.points,
                unit: metric.unit,
                xLabel: series.axisLabel,
                tooltipTime: series.tooltipTime,
                xInterval: series.interval,
                decimals: metric.decimals,
                color: color,
                zoomable: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pinch or scroll to zoom the timeline, drag to pan, touch the line for values.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
