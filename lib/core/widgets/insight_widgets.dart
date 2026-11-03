import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/chips.dart';

/// Donut (fl_chart) with a widget in the hole, e.g. the total.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.values, required this.colors, required this.center, this.size = 124});

  final List<double> values;
  final List<Color> colors;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = values.every((v) => v <= 0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 1.5,
              centerSpaceRadius: size * .34,
              sections: empty
                  ? [PieChartSectionData(value: 1, color: AppColors.divider, radius: size * .14, showTitle: false)]
                  : [
                      for (var i = 0; i < values.length; i++)
                        if (values[i] > 0)
                          PieChartSectionData(value: values[i], color: colors[i], radius: size * .14, showTitle: false),
                    ],
            ),
          ),
          center,
        ],
      ),
    );
  }
}

/// Two-line donut centre: big value + caption.
class DonutCenter extends StatelessWidget {
  const DonutCenter({super.key, required this.value, required this.caption, this.fontSize = 19});

  final String value;
  final String caption;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: AppText.cardTitle.copyWith(fontSize: fontSize)),
      Text(caption, style: AppText.caption),
    ],
  );
}

/// Legend line: colour square, label, value and an optional "(87%)".
class LegendRow extends StatelessWidget {
  const LegendRow({super.key, required this.color, required this.label, required this.value, this.pct, this.onTap});

  final Color color;
  final String label;
  final String value;
  final String? pct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(
          children: [
            ColorDot(color: color, size: 10, square: true),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, maxLines: 1, style: AppText.body.copyWith(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: AppText.bodyStrong.copyWith(fontSize: 12.5)),
              ),
            ),
            if (pct != null)
              SizedBox(
                width: 44,
                child: Text(pct!, textAlign: TextAlign.right, style: AppText.caption.copyWith(fontSize: 11.5)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Donut on the left, legend rows on the right (the Home overview layout).
class DonutWithLegend extends StatelessWidget {
  const DonutWithLegend({super.key, required this.slices, required this.center, this.size = 124});

  final List<DonutSlice> slices;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    return Row(
      children: [
        DonutChart(
          size: size,
          values: [for (final s in slices) s.value],
          colors: [for (final s in slices) s.color],
          center: center,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              for (final s in slices)
                LegendRow(
                  color: s.color,
                  label: s.label,
                  value: s.valueLabel ?? NumberFormat('#,###').format(s.value),
                  pct: total == 0 ? null : '(${(s.value * 100 / total).round()}%)',
                  onTap: s.onTap,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class DonutSlice {
  const DonutSlice({required this.label, required this.value, required this.color, this.valueLabel, this.onTap});

  final String label;
  final double value;
  final Color color;

  /// Shown instead of the formatted [value] (e.g. "480K").
  final String? valueLabel;
  final VoidCallback? onTap;
}

/// Small colour marker for legends.
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color, this.size = 8, this.square = false});

  final Color color;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: square ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: square ? BorderRadius.circular(size * .3) : null,
    ),
  );
}

/// Horizontal chart legend: "● Planned  ● Unplanned  ● Overdue".
class SeriesLegend extends StatelessWidget {
  const SeriesLegend({super.key, required this.items});

  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 6,
    children: [
      for (final (label, color) in items)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorDot(color: color),
            const SizedBox(width: 6),
            Text(label, style: AppText.caption.copyWith(fontSize: 12, color: AppColors.text)),
          ],
        ),
    ],
  );
}

/// "▲ 12%" / "▼ 5%" chip; green when the change is good ([higherIsBetter] decides which way is good).
class ChangeChip extends StatelessWidget {
  const ChangeChip({super.key, required this.pct, this.higherIsBetter = true, this.suffix});

  /// Change in percent (positive = went up).
  final double pct;
  final bool higherIsBetter;

  /// e.g. "vs last year".
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    final good = up == higherIsBetter;
    final text = '${pct.abs().toStringAsFixed(pct.abs() < 10 && pct.abs() % 1 != 0 ? 1 : 0)}%';
    return StatusChip(
      suffix == null ? text : '$text $suffix',
      tone: good ? ChipTone.green : ChipTone.red,
      icon: up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
    );
  }
}

/// Tappable count card: icon, big number, label (e.g. "236 · Planned WOs").
class CountCard extends StatelessWidget {
  const CountCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.caption,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const Spacer(),
                  if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: AppText.cardTitle.copyWith(fontSize: 20, color: color)),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin stacked bar: one segment per value (e.g. Healthy / Warning / Critical of one type).
class StackedMiniBar extends StatelessWidget {
  const StackedMiniBar({super.key, required this.values, required this.colors, this.height = 8, this.fraction = 1});

  final List<num> values;
  final List<Color> colors;
  final double height;

  /// Share of the full width the bar fills (to compare rows against the largest one).
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<num>(0, (a, b) => a + b);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: AppColors.divider,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: total == 0 ? 0 : fraction.clamp(0, 1).toDouble(),
            child: Row(
              children: [
                for (var i = 0; i < values.length; i++)
                  if (values[i] > 0)
                    Expanded(
                      flex: (values[i] * 1000 / total).round().clamp(1, 1000000),
                      child: ColoredBox(color: colors[i]),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sun–Sat strip of one week: day letters, dates, coloured dots per day, today ringed,
/// the selected day filled violet.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.weekStart,
    required this.selected,
    required this.today,
    required this.dotsFor,
    required this.onSelect,
  });

  /// The Sunday of the week.
  final DateTime weekStart;
  final DateTime selected;
  final DateTime today;

  /// Dot colours of a day (one per activity type present).
  final List<Color> Function(DateTime day) dotsFor;
  final ValueChanged<DateTime> onSelect;

  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          for (final day in [DateTime(weekStart.year, weekStart.month, weekStart.day + i)])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: _same(day, selected) ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: ValueKey('week-day-${day.month}-${day.day}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: _same(day, today) && !_same(day, selected)
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary, width: 1.4),
                            )
                          : null,
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEE').format(day),
                            style: AppText.caption.copyWith(
                              fontSize: 11,
                              color: _same(day, selected) ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: AppText.bodyStrong.copyWith(
                              fontSize: 15,
                              color: _same(day, selected) ? Colors.white : AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 6,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final c in dotsFor(day).take(4))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 1),
                                    child: ColorDot(color: _same(day, selected) ? Colors.white : c, size: 5),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
