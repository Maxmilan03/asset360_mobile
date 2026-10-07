import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/tracking.dart';

Color trackedKindColor(TrackedKind k) => switch (k) {
  TrackedKind.vehicle => AppColors.iconBlue,
  TrackedKind.person => AppColors.iconGreen,
  TrackedKind.equipment => AppColors.purple,
  TrackedKind.alert => AppColors.red,
};

/// Indoor floor plan drawn with CustomPaint (light-grey rooms, racks and aisles)
/// with coloured pins for [entities]. Pin positions are 0–1 fractions.
class FloorPlan extends StatelessWidget {
  const FloorPlan({super.key, required this.entities, this.showZoneLabels = false, this.onPinTap, this.pinSize = 26});

  final List<TrackedEntity> entities;
  final bool showZoneLabels;
  final ValueChanged<TrackedEntity>? onPinTap;
  final double pinSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: FloorPlanPainter(showZoneLabels: showZoneLabels)),
            ),
            for (final e in entities)
              Positioned(
                left: e.x * c.maxWidth - pinSize / 2,
                top: e.y * c.maxHeight - pinSize,
                child: GestureDetector(
                  onTap: onPinTap == null ? null : () => onPinTap!(e),
                  child: Tooltip(
                    message: e.label,
                    child: Icon(
                      Icons.location_on_rounded,
                      size: pinSize,
                      color: trackedKindColor(e.kind),
                      shadows: const [Shadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Zones: Receiving (top-left), Storage (bottom-left), Zone B (middle), Dispatch (right).
class FloorPlanPainter extends CustomPainter {
  FloorPlanPainter({this.showZoneLabels = false});

  final bool showZoneLabels;

  static const zones = [
    ('Receiving', Rect.fromLTWH(.02, .04, .30, .38)),
    ('Storage', Rect.fromLTWH(.02, .48, .30, .48)),
    ('Zone B', Rect.fromLTWH(.36, .20, .36, .56)),
    ('Dispatch', Rect.fromLTWH(.76, .04, .22, .92)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Rect r(Rect f) => Rect.fromLTWH(f.left * w, f.top * h, f.width * w, f.height * h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xFFF1F2F6),
    );
    final wall = Paint()
      ..color = const Color(0xFFB9BDC9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rack = Paint()
      ..color = const Color(0xFFD5D8E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    final zoneFill = Paint()..color = AppColors.primary.withValues(alpha: .07);

    final rackFill = Paint()..color = const Color(0xFFE2E5EE);
    final rackSide = Paint()..color = const Color(0xFFC9CEDA);
    for (final (name, f) in zones) {
      final rect = r(f);
      canvas.drawRect(rect, Paint()..color = const Color(0xFFF8F9FC));
      if (name == 'Zone B' || name == 'Storage') canvas.drawRect(rect, zoneFill);
      canvas.drawRect(rect, wall);
      // Racks: rows of blocks with a darker lower-right edge (flat isometric look).
      final vertical = rect.height > rect.width;
      final inset = math.min(rect.width, rect.height) * .08;
      final inner = rect.deflate(inset);
      for (var i = 0; i < 4; i++) {
        for (final half in [0, 1]) {
          final Rect block;
          if (vertical) {
            final x = inner.left + inner.width * (i * 2 + .5) / 8;
            final y0 = inner.top + inner.height * (half == 0 ? 0 : .58);
            block = Rect.fromLTWH(x, y0, inner.width / 9, inner.height * .38);
          } else {
            final y = inner.top + inner.height * (i * 2 + .5) / 8;
            final x0 = inner.left + inner.width * (half == 0 ? 0 : .58);
            block = Rect.fromLTWH(x0, y, inner.width * .4, inner.height / 9);
          }
          canvas.drawRect(block.shift(const Offset(1.4, 1.4)), rackSide);
          canvas.drawRect(block, rackFill);
          canvas.drawRect(block, rack);
        }
      }
      if (showZoneLabels) {
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // aisles
    final aisle = Paint()
      ..color = Colors.white
      ..strokeWidth = 5;
    canvas.drawLine(Offset(.34 * w, .02 * h), Offset(.34 * w, .98 * h), aisle);
    canvas.drawLine(Offset(.74 * w, .02 * h), Offset(.74 * w, .98 * h), aisle);
    canvas.drawLine(Offset(.02 * w, .45 * h), Offset(.34 * w, .45 * h), aisle);
  }

  @override
  bool shouldRepaint(FloorPlanPainter old) => old.showZoneLabels != showZoneLabels;
}
