import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/data/models/tracking.dart';

Color trackedKindColor(TrackedKind k) => switch (k) {
  TrackedKind.vehicle => AppColors.iconBlue,
  TrackedKind.person => AppColors.iconGreen,
  TrackedKind.equipment => AppColors.purple,
  TrackedKind.alert => AppColors.red,
};

/// Indoor floor plan drawn with CustomPaint (light-grey rooms, racks and aisles)
/// with coloured pins for [entities]. Pin positions are 0–1 fractions.
class FloorPlan extends StatelessWidget {
  const FloorPlan({
    super.key,
    required this.entities,
    this.showZoneLabels = false,
    this.onPinTap,
    this.pinSize = 26,
    this.variant = 0,
    this.showLabels = false,
  });

  final List<TrackedEntity> entities;
  final bool showZoneLabels;
  final ValueChanged<TrackedEntity>? onPinTap;
  final double pinSize;

  /// Room layout ([FloorPlanPainter.layouts]); e.g. one per floor of a building.
  final int variant;

  /// A label chip above each pin.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: FloorPlanPainter(showZoneLabels: showZoneLabels, variant: variant)),
            ),
            if (showLabels)
              for (final e in entities)
                Positioned(
                  left: e.x * c.maxWidth - 60,
                  width: 120,
                  top: e.y * c.maxHeight - pinSize - 24,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: trackedKindColor(e.kind),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
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

/// Zones (layout 0): Receiving (top-left), Storage (bottom-left), Zone B (middle), Dispatch (right).
/// Layout 1 is the mirror image; layout 2 is an office floor.
class FloorPlanPainter extends CustomPainter {
  FloorPlanPainter({this.showZoneLabels = false, this.variant = 0});

  final bool showZoneLabels;
  final int variant;

  static const zones = [
    ('Receiving', Rect.fromLTWH(.02, .04, .30, .38)),
    ('Storage', Rect.fromLTWH(.02, .48, .30, .48)),
    ('Zone B', Rect.fromLTWH(.36, .20, .36, .56)),
    ('Dispatch', Rect.fromLTWH(.76, .04, .22, .92)),
  ];

  static const _office = [
    ('Offices', Rect.fromLTWH(.02, .04, .46, .40)),
    ('Meeting', Rect.fromLTWH(.52, .04, .46, .40)),
    ('Open Area', Rect.fromLTWH(.02, .52, .62, .44)),
    ('Store', Rect.fromLTWH(.68, .52, .30, .44)),
  ];

  static const layoutCount = 3;

  static Rect _mirror(Rect f) => Rect.fromLTWH(1 - f.left - f.width, f.top, f.width, f.height);

  /// Rooms of layout [variant] (0–2, wraps).
  static List<(String, Rect)> layouts(int variant) => switch (variant % layoutCount) {
    0 => zones,
    1 => [for (final (n, f) in zones) (n, _mirror(f))],
    _ => _office,
  };

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
    for (final (name, f) in layouts(variant)) {
      final rect = r(f);
      canvas.drawRect(rect, Paint()..color = const Color(0xFFF8F9FC));
      if (name == 'Zone B' || name == 'Storage' || name == 'Open Area') canvas.drawRect(rect, zoneFill);
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
    switch (variant % layoutCount) {
      case 2:
        canvas.drawLine(Offset(.02 * w, .48 * h), Offset(.98 * w, .48 * h), aisle);
        canvas.drawLine(Offset(.50 * w, .02 * h), Offset(.50 * w, .46 * h), aisle);
        canvas.drawLine(Offset(.66 * w, .50 * h), Offset(.66 * w, .98 * h), aisle);
      default:
        double x(double v) => (variant % layoutCount == 1 ? 1 - v : v) * w;
        canvas.drawLine(Offset(x(.34), .02 * h), Offset(x(.34), .98 * h), aisle);
        canvas.drawLine(Offset(x(.74), .02 * h), Offset(x(.74), .98 * h), aisle);
        canvas.drawLine(Offset(x(.02), .45 * h), Offset(x(.34), .45 * h), aisle);
    }
  }

  @override
  bool shouldRepaint(FloorPlanPainter old) => old.showZoneLabels != showZoneLabels || old.variant != variant;
}
