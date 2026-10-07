import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';

/// Icon in a filled circle with two rings pulsing outwards ("hold the tag near
/// the phone", "searching nearby beacons"). The rings stop when [active] is false.
class PulseRings extends StatefulWidget {
  const PulseRings({
    super.key,
    required this.icon,
    this.active = true,
    this.size = 150,
    this.color,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final bool active;
  final double size;
  final Color? color;
  Color get _color => color ?? AppColors.primary;
  final Color iconColor;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat();
  }

  @override
  void didUpdateWidget(PulseRings old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) _pulse.repeat();
    if (!widget.active && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.size * .43;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.active)
              for (final offset in [0.0, .5])
                Builder(
                  builder: (_) {
                    final t = (_pulse.value + offset) % 1;
                    final d = core + (widget.size - core) * t;
                    return Container(
                      width: d,
                      height: d,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget._color.withValues(alpha: .25 * (1 - t)),
                      ),
                    );
                  },
                ),
            Container(
              width: core,
              height: core,
              decoration: BoxDecoration(color: widget._color, shape: BoxShape.circle),
              child: Icon(widget.icon, color: widget.iconColor, size: core * .53),
            ),
          ],
        ),
      ),
    );
  }
}
