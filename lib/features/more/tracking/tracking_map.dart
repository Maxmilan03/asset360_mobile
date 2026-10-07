import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';

/// Map pin look per kind (design 06: blue people, green equipment, orange forklifts, red alerts).
(IconData, Color) pinLook(TrackedKind k) => switch (k) {
  TrackedKind.person => (Icons.person_rounded, AppColors.iconBlue),
  TrackedKind.equipment => (Icons.shopping_cart_rounded, AppColors.iconGreen),
  TrackedKind.vehicle => (Icons.forklift, AppColors.iconOrange),
  TrackedKind.alert => (Icons.warning_rounded, AppColors.red),
};

/// Round badge pin: white ring around a coloured disc with the kind's icon.
class TrackPin extends StatelessWidget {
  const TrackPin({super.key, required this.entity, this.size = 30, this.selected = false});

  final TrackedEntity entity;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = pinLook(entity.kind);
    final vehicle = entity.kind == TrackedKind.vehicle;
    final offline = !entity.online;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(vehicle ? 2.5 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: vehicle ? color : Colors.white,
        boxShadow: [
          BoxShadow(
            color: (selected ? color : Colors.black).withValues(alpha: selected ? .55 : .25),
            blurRadius: selected ? 10 : 4,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: vehicle ? Colors.white : (offline ? AppColors.textMuted : color),
        ),
        child: Icon(icon, size: size * .55, color: vehicle ? AppColors.text : Colors.white),
      ),
    );
  }
}

/// Floor plan with pins, optional geofences / route trail, a callout for the selected pin,
/// pinch-zoom, + / − buttons, a 2D ⇄ 3D toggle and an optional Layers button.
class TrackingMap extends StatefulWidget {
  const TrackingMap({
    super.key,
    required this.entities,
    this.geofences = const [],
    this.trail = const [],
    this.selectedId,
    this.onPinTap,
    this.onCalloutTap,
    this.onLayers,
    this.bubble,
    this.calloutDetail,
    this.pinSize = 30,
    this.draft,
    this.interactive = true,
  });

  final List<TrackedEntity> entities;
  final List<Geofence> geofences;

  /// Dotted route trail (0–1 fractions), oldest first.
  final List<TrendPoint> trail;
  final String? selectedId;
  final ValueChanged<TrackedEntity>? onPinTap;
  final ValueChanged<TrackedEntity>? onCalloutTap;
  final VoidCallback? onLayers;

  /// Small label pinned above the selected entity instead of a callout ("Moving · 5 km/h").
  final String? bubble;

  /// Callout's last line, e.g. "Main Warehouse · 1 min ago" (defaults to zone + time).
  final String Function(TrackedEntity)? calloutDetail;
  final double pinSize;

  /// Rectangle being drawn (Add Zone), 0–1 fractions.
  final Rect? draft;

  /// False for the Add Zone canvas: no zoom / pan, no controls.
  final bool interactive;

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  final _zoom = TransformationController();
  bool _tilted = false;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _zoomBy(double f, Size size) {
    final current = _zoom.value.getMaxScaleOnAxis();
    final target = (current * f).clamp(1.0, 4.0);
    final s = target / current;
    final c = Offset(size.width / 2, size.height / 2);
    _zoom.value = _zoom.value.clone()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    if (target == 1) _zoom.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final plan = TweenAnimationBuilder<double>(
          tween: Tween(end: _tilted ? 1 : 0),
          duration: const Duration(milliseconds: 350),
          builder: (context, t, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0013)
              ..rotateX(-.62 * t)
              ..scaleByDouble(1 - .08 * t, 1 - .08 * t, 1, 1),
            child: child,
          ),
          child: _PlanLayer(widget: widget, size: size),
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.interactive
                    ? InteractiveViewer(transformationController: _zoom, maxScale: 4, child: plan)
                    : plan,
              ),
              if (widget.interactive) ...[
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      if (widget.onLayers != null) ...[
                        _MapButton(icon: Icons.layers_outlined, tooltip: 'Layers', onTap: widget.onLayers!),
                        const SizedBox(height: 8),
                      ],
                      _MapButton(
                        label: _tilted ? '3D' : '2D',
                        tooltip: _tilted ? 'Switch to 2D' : 'Switch to 3D',
                        onTap: () => setState(() => _tilted = !_tilted),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 2,
                    child: Column(
                      children: [
                        IconButton(
                          tooltip: 'Zoom in',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _zoomBy(1.5, size),
                          icon: const Icon(Icons.add_rounded),
                        ),
                        const SizedBox(width: 28, child: Divider(height: 1)),
                        IconButton(
                          tooltip: 'Zoom out',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _zoomBy(1 / 1.5, size),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PlanLayer extends StatelessWidget {
  const _PlanLayer({required this.widget, required this.size});

  final TrackingMap widget;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final w = size.width, h = size.height, pin = widget.pinSize;
    final selected = widget.entities.firstWhereOrNull((e) => e.id == widget.selectedId);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: FloorPlanPainter(showZoneLabels: true))),
          Positioned.fill(
            child: CustomPaint(
              painter: _OverlayPainter(geofences: widget.geofences, trail: widget.trail, draft: widget.draft),
            ),
          ),
          for (final e in widget.entities)
            Positioned(
              left: e.x * w - pin / 2,
              top: e.y * h - pin / 2,
              child: Semantics(
                button: true,
                label: e.label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onPinTap == null ? null : () => widget.onPinTap!(e),
                  child: TrackPin(entity: e, size: pin, selected: e.id == widget.selectedId),
                ),
              ),
            ),
          if (selected != null && widget.bubble != null)
            Positioned(
              left: (selected.x * w + pin / 2 - 8).clamp(0, w - 90),
              top: (selected.y * h - pin / 2 - 40).clamp(0, h - 40),
              child: _Bubble(text: widget.bubble!),
            ),
          if (selected != null && widget.bubble == null)
            Positioned(
              left: _calloutLeft(selected.x * w, w, pin),
              top: (selected.y * h - 34).clamp(4, h - 84),
              child: _Callout(
                entity: selected,
                detail: widget.calloutDetail?.call(selected) ?? _defaultDetail(selected),
                onTap: widget.onCalloutTap == null ? null : () => widget.onCalloutTap!(selected),
              ),
            ),
        ],
      ),
    );
  }

  /// Right of the pin when it fits, else left of it, so the callout never covers its own pin.
  static double _calloutLeft(double x, double w, double pin) {
    const width = 176.0, gap = 4.0;
    final right = x + pin / 2 + gap;
    if (right + width <= w - 4) return right;
    final left = x - pin / 2 - gap - width;
    return left >= 4 ? left : (w - width) / 2;
  }

  static String _defaultDetail(TrackedEntity e) =>
      e.lastSeen == null ? e.zone : '${e.zone} · ${DemoClock.timeAgo(e.lastSeen!)}';
}

/// "Forklift FL-012 / Moving / Main Warehouse · 1 min ago  ›".
class _Callout extends StatelessWidget {
  const _Callout({required this.entity, required this.detail, this.onTap});

  final TrackedEntity entity;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 176,
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    StatusChip(entity.status),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.greenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.green.withValues(alpha: .35)),
        boxShadow: AppShadows.card,
      ),
      child: Text(
        text.replaceAll(' · ', '\n'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green, height: 1.25),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.tooltip, required this.onTap, this.icon, this.label});

  final String tooltip;
  final VoidCallback onTap;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 38,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 20, color: AppColors.text)
                  : Text(label!, style: AppText.bodyStrong.copyWith(fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Geofences (violet; restricted red), the dotted route trail and the rectangle being drawn.
class _OverlayPainter extends CustomPainter {
  _OverlayPainter({required this.geofences, required this.trail, this.draft});

  final List<Geofence> geofences;
  final List<TrendPoint> trail;
  final Rect? draft;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final g in geofences) {
      final color = g.restricted ? AppColors.red : AppColors.primary;
      final rect = Rect.fromLTWH(g.left * w, g.top * h, g.width * w, g.height * h);
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: .07));
      _dashedRect(
        canvas,
        rect,
        Paint()
          ..color = color.withValues(alpha: .7)
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: g.name,
          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: rect.width - 6);
      tp.paint(canvas, rect.topLeft + const Offset(3, 2));
    }
    if (draft != null) {
      final rect = Rect.fromLTRB(draft!.left * w, draft!.top * h, draft!.right * w, draft!.bottom * h);
      canvas.drawRect(rect, Paint()..color = AppColors.primary.withValues(alpha: .18));
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    if (trail.length > 1) {
      final pts = [for (final p in trail) Offset(p.x * w, p.y * h)];
      final dash = Paint()
        ..color = AppColors.iconBlue
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i], b = pts[i + 1];
        final len = (b - a).distance;
        for (var d = 0.0; d < len; d += 9) {
          final t1 = d / len, t2 = ((d + 4.5) / len).clamp(0.0, 1.0);
          canvas.drawLine(Offset.lerp(a, b, t1)!, Offset.lerp(a, b, t2)!, dash);
        }
      }
      for (final p in pts.take(pts.length - 1)) {
        canvas.drawCircle(p, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(p, 3.2, Paint()..color = AppColors.iconBlue);
      }
    }
  }

  void _dashedRect(Canvas canvas, Rect r, Paint p) {
    for (final (a, b) in [
      (r.topLeft, r.topRight),
      (r.topRight, r.bottomRight),
      (r.bottomRight, r.bottomLeft),
      (r.bottomLeft, r.topLeft),
    ]) {
      final len = (b - a).distance;
      for (var d = 0.0; d < len; d += 8) {
        canvas.drawLine(Offset.lerp(a, b, d / len)!, Offset.lerp(a, b, ((d + 4) / len).clamp(0.0, 1.0))!, p);
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.geofences != geofences || old.trail != trail || old.draft != draft;
}
