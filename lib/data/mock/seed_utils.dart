import 'dart:math' as math;

import 'package:asset360_mobile/data/models/common.dart';

/// A date in September 2026 (or [month]) at [h]:[m], the demo's local time.
DateTime sep(int day, [int h = 0, int m = 0]) => DateTime(2026, 9, day, h, m);
DateTime on(int year, int month, int day, [int h = 0, int m = 0]) => DateTime(year, month, day, h, m);

/// 25 hourly points (00:00 … 24:00): [base] plus a smooth wave and optional bumps.
List<TrendPoint> hourly(double base, double wave, {Map<int, double> bumps = const {}, int seed = 1}) {
  return [
    for (var h = 0; h <= 24; h++)
      TrendPoint(
        h.toDouble(),
        double.parse(
          (base + wave * math.sin((h + seed) * .9) * .5 + wave * math.sin((h + seed * 2) * 2.3) * .2 + (bumps[h] ?? 0))
              .toStringAsFixed(2),
        ),
      ),
  ];
}
