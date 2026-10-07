import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';

/// Four rounded violet corner brackets around the scan area.
class ScanCornerFrame extends StatelessWidget {
  const ScanCornerFrame({super.key, this.size = 250});

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(size: Size.square(size), painter: const _CornerFramePainter()),
  );
}

class _CornerFramePainter extends CustomPainter {
  const _CornerFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 36.0, r = 18.0;
    final paint = Paint()
      ..color = AppColors.illustration
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    // Top-left corner drawn once, then mirrored to the other three.
    final corner = Path()
      ..moveTo(0, len)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(len, 0);
    for (final (sx, sy) in [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)]) {
      canvas.save();
      canvas.translate(sx > 0 ? 0 : w, sy > 0 ? 0 : h);
      canvas.scale(sx, sy);
      canvas.drawPath(corner, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CornerFramePainter old) => false;
}

/// Round dark button on the camera (flash, gallery).
class ScanRoundButton extends StatelessWidget {
  const ScanRoundButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .55),
      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: onPressed == null ? Colors.white38 : Colors.white),
      ),
    );
  }
}

/// Flash button; follows the camera's real torch state.
class TorchButton extends StatelessWidget {
  const TorchButton({super.key, required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final on = state.torchState == TorchState.on;
        return ScanRoundButton(
          icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          tooltip: on ? 'Flash off' : 'Flash on',
          onPressed: state.torchState == TorchState.unavailable ? null : controller.toggleTorch,
        );
      },
    );
  }
}

/// Translucent rounded button with an icon over a label ("Manual Entry", "Multi Scan").
class ScanSideButton extends StatelessWidget {
  const ScanSideButton({super.key, required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Filled violet while a mode is on (Multi Scan).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: active ? AppColors.primary : Colors.black.withValues(alpha: .45),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: active ? AppColors.illustration : Colors.white54),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          width: 88,
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big violet circle with a white ring and a label under it ("Tap to Scan").
class ScanShutterButton extends StatelessWidget {
  const ScanShutterButton({super.key, required this.label, required this.onTap, this.icon, this.busy = false});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Shows a spinner in the circle (e.g. while looking for a code).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: Center(
                  child: busy
                      ? const SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : Icon(icon ?? Icons.qr_code_scanner_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
