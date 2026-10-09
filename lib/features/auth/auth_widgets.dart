import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';

/// Status bar with dark icons on the light sign-in screens.
const authOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.authBackground,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// Light page with an optional lavender wash at the top (Forgot / Authenticator).
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child, this.wash = true});

  final Widget child;
  final bool wash;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: authOverlay,
      child: Scaffold(
        backgroundColor: AppColors.authBackground,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: wash
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .32, .5],
                    colors: [AppColors.authTop, Color(0xFFF3F1FC), AppColors.authBackground],
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Round logo + "Purple IQ" word mark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44, this.fontSize = 24});

  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/logo_on_light.webp',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Purple IQ',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.brandText,
            letterSpacing: -.3,
          ),
        ),
      ],
    );
  }
}

/// Four-colour "G" drawn from arcs (not the brand image).
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * .2;
    final rect = Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2 - stroke / 2);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = math.pi / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335))); // red, top
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05))); // yellow, left
    canvas.drawArc(rect, -230 * deg, -100 * deg, false, p(const Color(0xFF34A853))); // green, bottom
    canvas.drawArc(rect, 30 * deg, -70 * deg, false, p(const Color(0xFF4285F4))); // blue, right
    canvas.drawRect(
      Rect.fromLTWH(s * .5, s * .42, s * .5 - stroke / 2 + stroke / 2, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Four coloured squares (not the brand image).
class MicrosoftMark extends StatelessWidget {
  const MicrosoftMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final q = size * .47;
    Widget sq(Color c) => Container(width: q, height: q, color: c);
    return SizedBox.square(
      dimension: size,
      child: Wrap(
        spacing: size * .06,
        runSpacing: size * .06,
        children: [
          sq(const Color(0xFFF25022)),
          sq(const Color(0xFF7FBA00)),
          sq(const Color(0xFF00A4EF)),
          sq(const Color(0xFFFFB900)),
        ],
      ),
    );
  }
}

/// Multicolour six-arm asterisk used for the authenticator app (drawn, no logo).
class AuthenticatorMark extends StatelessWidget {
  const AuthenticatorMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _AsteriskPainter());
}

class _AsteriskPainter extends CustomPainter {
  static const _colors = [
    Color(0xFF4285F4),
    Color(0xFF34A853),
    Color(0xFF34A853),
    Color(0xFFFBBC05),
    Color(0xFFEA4335),
    Color(0xFF4285F4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 * .92;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      canvas.drawLine(
        c,
        c + Offset(math.cos(a), math.sin(a)) * r,
        Paint()
          ..color = _colors[i]
          ..strokeWidth = size.width * .2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Soft translucent circle for the illustrations.
class SoftCircle extends StatelessWidget {
  const SoftCircle({super.key, required this.size, this.color = AppColors.illustration, this.opacity = .14});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: opacity),
      shape: BoxShape.circle,
    ),
  );
}

/// Violet circle holding a white icon (lock / person badges).
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.size = 56});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF6B2BFF), Color(0xFF4A14D8)]),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: .3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * .46),
    );
  }
}

/// Envelope + lock + person + paper plane (Forgot password).
class ForgotIllustration extends StatelessWidget {
  const ForgotIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      width: 300,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(left: 20, top: 60, child: SoftCircle(size: 130, opacity: .12)),
          const Positioned(left: 110, top: 30, child: SoftCircle(size: 150, opacity: .10)),
          const Positioned(right: 10, top: 80, child: SoftCircle(size: 110, opacity: .12)),
          Positioned(
            left: 70,
            top: 78,
            child: Container(
              width: 130,
              height: 92,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB9A4FB), Color(0xFF9676F3)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(painter: _EnvelopeFlapPainter()),
            ),
          ),
          const Positioned(left: 108, top: 36, child: IconBadge(icon: Icons.lock_rounded, size: 62)),
          const Positioned(left: 188, top: 104, child: IconBadge(icon: Icons.person_rounded, size: 50)),
          Positioned(
            right: 34,
            top: 6,
            child: Transform.rotate(
              angle: -.5,
              child: const Icon(Icons.send_rounded, color: Color(0xFF5B22E8), size: 38),
            ),
          ),
          Positioned(
            left: 176,
            top: 30,
            child: CustomPaint(size: const Size(80, 40), painter: _DashTrailPainter()),
          ),
          for (final d in const [(52.0, 40.0, 7.0), (206.0, 24.0, 16.0), (256.0, 72.0, 6.0), (30.0, 150.0, 5.0)])
            Positioned(
              left: d.$1,
              top: d.$2,
              child: Container(
                width: d.$3,
                height: d.$3,
                decoration: const BoxDecoration(color: Color(0xFF7B4DF2), shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _EnvelopeFlapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(
      Path()
        ..moveTo(6, 8)
        ..lineTo(size.width / 2, size.height * .58)
        ..lineTo(size.width - 6, 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7B4DF2)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * .5, size.height * .9, size.width, 0);
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 3.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shield with a lock and the multicolour badge (Authenticator).
class ShieldIllustration extends StatelessWidget {
  const ShieldIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      width: 280,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Positioned(left: 30, top: 50, child: SoftCircle(size: 110, opacity: .12)),
          const Positioned(left: 90, top: 20, child: SoftCircle(size: 140, opacity: .10)),
          const Positioned(right: 20, top: 70, child: SoftCircle(size: 90, opacity: .12)),
          const Positioned(left: 44, top: 116, child: SoftCircle(size: 26, opacity: .25)),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7A3BFF), Color(0xFF4A12D9)],
            ).createShader(r),
            child: const Icon(Icons.shield_rounded, size: 140, color: Colors.white),
          ),
          const Positioned(top: 58, child: Icon(Icons.lock_rounded, color: Colors.white, size: 46)),
          Positioned(
            right: 50,
            top: 8,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(child: AuthenticatorMark(size: 34)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary button content with a trailing arrow, or a spinner while [loading].
class ArrowLabel extends StatelessWidget {
  const ArrowLabel(this.label, {super.key, this.loading = false});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_forward_rounded, size: 20),
      ],
    );
  }
}
