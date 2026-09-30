import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../demo_clock.dart';

/// Two-line due time: "Due in / 1h 20m" (red when under 2 h), "Due Today / 4:00 PM"
/// (amber), "Overdue / 1h 30m" (red) or "Due / 27 Sep".
class DueLabel extends StatelessWidget {
  const DueLabel(this.due, {super.key, this.done = false});

  final DateTime? due;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final d = due;
    if (d == null) return const SizedBox.shrink();
    final (String top, String bottom, Color color) = switch (d) {
      _ when done => ('Completed', DemoClock.formatShort(d), AppColors.green),
      _ when DemoClock.isOverdue(d) => ('Overdue', DemoClock.timeLeft(d), AppColors.red),
      _ when d.difference(DemoClock.now).inMinutes < 120 => ('Due in', DemoClock.timeLeft(d), AppColors.red),
      _ when DemoClock.isToday(d) => ('Due Today', DemoClock.formatTime(d), AppColors.orange),
      _ => ('Due', DemoClock.formatShort(d), AppColors.text),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(top, style: TextStyle(fontSize: 11.5, color: color == AppColors.text ? AppColors.textSecondary : color)),
        const SizedBox(height: 2),
        Text(
          bottom,
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
