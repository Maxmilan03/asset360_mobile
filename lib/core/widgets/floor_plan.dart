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

    for (final (name, f) in zones) {
      final rect = r(f);
      if (name == 'Zone B' || name == 'Storage') canvas.drawRect(rect, zoneFill);
      canvas.drawRect(rect, wall);
      // shelving: short parallel lines inside each room
      final vertical = rect.height > rect.width;
      for (var i = 1; i < 6; i++) {
        if (vertical) {
          final x = rect.left + rect.width * i / 6;
          canvas.drawLine(Offset(x, rect.top + 6), Offset(x, rect.top + rect.height * .45), rack);
          canvas.drawLine(Offset(x, rect.top + rect.height * .55), Offset(x, rect.bottom - 6), rack);
        } else {
          final y = rect.top + rect.height * i / 6;
          canvas.drawLine(Offset(rect.left + 6, y), Offset(rect.left + rect.width * .45, y), rack);
          canvas.drawLine(Offset(rect.left + rect.width * .55, y), Offset(rect.right - 6, y), rack);
        }
      }
      if (showZoneLabels) {
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
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
