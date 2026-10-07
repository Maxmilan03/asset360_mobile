import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../data/models/common.dart';

/// Curved line chart with a soft fill, axis labels and a touch tooltip.
/// [xLabel] formats the bottom axis and tooltip time; by default x is hours (0–24).
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.unit,
    this.xLabel,
    this.tooltipTime,
    this.xInterval = 4,
    this.minY,
    this.maxY,
    this.color = AppColors.purple,
    this.zoomable = false,
    this.decimals,
    this.highlightLast = false,
  });

  final List<TrendPoint> points;
  final String unit;
  final String Function(double x)? xLabel;

  /// Time line of the tooltip (defaults to [xLabel]).
  final String Function(double x)? tooltipTime;
  final double xInterval;

  /// Fixed axis range (e.g. 0–100 for battery); padded around the data when null.
  final double? minY;
  final double? maxY;
  final Color color;

  /// Pinch / scroll to zoom the time axis.
  final bool zoomable;
  final int? decimals;

  /// Draws a dot on the last point (e.g. the reading that raised an alert).
  final bool highlightLast;

  static String hourLabel(double x) => '${x.toInt().toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return Center(child: Text('No data', style: AppText.secondary));
    final ys = points.map((p) => p.y);
    final lo = ys.reduce(math.min), hi = ys.reduce(math.max);
    final pad = (hi - lo) * .35 + (hi.abs() * .02) + .1;
    final label = xLabel ?? hourLabel;
    final time = tooltipTime ?? label;
    String value(double y) => y.toStringAsFixed(decimals ?? (y.abs() >= 100 ? 0 : 1));
    return LineChart(
      transformationConfig: zoomable
          ? const FlTransformationConfig(scaleAxis: FlScaleAxis.horizontal, minScale: 1, maxScale: 12)
          : const FlTransformationConfig(),
      LineChartData(
        minX: points.first.x,
        maxX: points.last.x,
        minY: minY ?? lo - pad,
        maxY: maxY ?? hi + pad,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: AppColors.border),
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (v, meta) => Text(meta.formattedValue, style: AppText.caption.copyWith(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: xInterval,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(label(v), style: AppText.caption.copyWith(fontSize: 10)),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${value(s.y)}${unit.isEmpty ? '' : ' $unit'}\n${time(s.x)}',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final p in points) FlSpot(p.x, p.y)],
            isCurved: true,
            curveSmoothness: .25,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              show: highlightLast,
              checkToShowDot: (spot, _) => spot.x == points.last.x,
              getDotPainter: (_, _, _, _) =>
                  FlDotCirclePainter(radius: 5, color: color, strokeWidth: 2, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: .22), color.withValues(alpha: .02)],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}

/// Tiny line with no axes, for tiles.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.color = AppColors.purple, this.height = 22});

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _SparkPainter(values, color)),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(size.width * i / (values.length - 1), size.height * (1 - (values[i] - lo) / span) * .9 + 1);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}

/// Simple bar chart with a label under each bar and the value in the tooltip.
class BarSeriesChart extends StatelessWidget {
  const BarSeriesChart({super.key, required this.values, required this.labels, this.color, this.unit = ''});

  final List<double> values;
  final List<String> labels;
  final Color? color;
  Color get _color => color ?? AppColors.primary;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final hi = values.isEmpty ? 1.0 : values.reduce(math.max);
    return BarChart(
      BarChartData(
        maxY: hi == 0 ? 1 : hi * 1.25,
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
              reservedSize: 32,
              getTitlesWidget: (v, meta) => Text(meta.formattedValue, style: AppText.caption.copyWith(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  v.toInt() < labels.length ? labels[v.toInt()] : '',
                  style: AppText.caption.copyWith(fontSize: 10),
                ),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${labels[group.x]}\n${rod.toY.toStringAsFixed(0)}${unit.isEmpty ? '' : ' $unit'}',
              const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        barGroups: [
          for (final (i, v) in values.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: v,
                  width: 18,
                  color: _color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
