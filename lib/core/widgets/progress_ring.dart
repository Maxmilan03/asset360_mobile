import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class RingSegment {
  const RingSegment(this.value, this.color);

  final double value;
  final Color color;
}

/// Circular progress (one value 0…1) or a donut of colored segments,
/// with any widget in the centre.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required double value,
    this.size = 120,
    this.strokeWidth = 12,
    this.color = AppColors.green,
    this.trackColor = AppColors.divider,
    this.center,
  }) : _value = value,
       segments = null;

  const ProgressRing.segments({
    super.key,
    required List<RingSegment> this.segments,
    this.size = 120,
    this.strokeWidth = 14,
    this.trackColor = AppColors.divider,
    this.center,
  }) : _value = 0,
       color = AppColors.primary;

  final double _value;
  final List<RingSegment>? segments;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => CustomPaint(
          painter: _RingPainter(
            value: _value.clamp(0, 1) * t,
            segments: segments,
            progress: t,
            strokeWidth: strokeWidth,
            color: color,
            trackColor: trackColor,
          ),
          child: child,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.segments,
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final List<RingSegment>? segments;
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.shortestSide - strokeWidth) / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);

    const start = -math.pi / 2;
    if (segments == null) {
      canvas.drawArc(
        rect,
        start,
        math.pi * 2 * value,
        false,
        paint
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    final total = segments!.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    var angle = start;
    for (final s in segments!) {
      final sweep = math.pi * 2 * (s.value / total) * progress;
      canvas.drawArc(rect, angle, sweep, false, paint..color = s.color);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.progress != progress || old.segments != segments || old.color != color;
}
