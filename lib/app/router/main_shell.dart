import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

/// Hosts the five tab branches and the bottom bar:
/// Home, Assets, [raised Scan button], Work, More.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    // Re-tapping the active tab returns to that tab's first screen.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final onHome = navigationShell.currentIndex == 0;
    return PopScope(
      // Android back at the root of another tab goes to Home first; at Home it exits.
      canPop: onHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !onHome) navigationShell.goBranch(0);
      },
      child: Scaffold(
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: AppBottomBar(currentIndex: navigationShell.currentIndex, onTap: _onTap),
      ),
    );
  }
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const barHeight = 66.0;
  static const scanSize = 62.0;
  static const rise = 22.0; // how far the Scan button sticks out above the bar

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Labels must stay on one line, so very large system text sizes are capped here.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: SizedBox(
        height: barHeight + rise + safeBottom,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _BarPainter(top: rise)),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: rise + barHeight,
              child: Row(
                children: [
                  _NavItem(
                    label: 'Home',
                    active: currentIndex == 0,
                    onTap: () => onTap(0),
                    icon: (c, a) => Icon(a ? Icons.home_rounded : Icons.home_outlined, color: c, size: 27),
                  ),
                  _NavItem(
                    label: 'Assets',
                    active: currentIndex == 1,
                    onTap: () => onTap(1),
                    icon: (c, _) => CustomPaint(size: const Size(26, 26), painter: _AssetsIconPainter(c)),
                  ),
                  _ScanItem(active: currentIndex == 2, onTap: () => onTap(2)),
                  _NavItem(
                    label: 'Work',
                    active: currentIndex == 3,
                    onTap: () => onTap(3),
                    icon: (c, a) =>
                        Icon(a ? Icons.assignment_turned_in_rounded : Icons.content_paste_rounded, color: c, size: 26),
                  ),
                  _NavItem(
                    label: 'More',
                    active: currentIndex == 4,
                    onTap: () => onTap(4),
                    icon: (c, _) => Icon(Icons.more_horiz_rounded, color: c, size: 28),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.active, required this.onTap, required this.icon});

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Widget Function(Color color, bool active) icon;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.navInactive;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Column(
          children: [
            const SizedBox(height: AppBottomBar.rise), // transparent, taps pass through to the page
            Expanded(
              child: InkResponse(
                onTap: onTap,
                radius: 36,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(height: 28, child: Center(child: icon(color, active))),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanItem extends StatelessWidget {
  const _ScanItem({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        label: 'Scan',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                child: Container(
                  width: AppBottomBar.scanSize,
                  height: AppBottomBar.scanSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    border: active ? Border.all(color: Colors.white, width: 2) : null,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 30),
                ),
              ),
              Positioned(
                top: AppBottomBar.scanSize + 5,
                child: Text(
                  'Scan',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White bar with a soft hump around the Scan button and a light top shadow.
class _BarPainter extends CustomPainter {
  _BarPainter({required this.top});

  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const half = 58.0;
    const hump = 14.0;
    final path = Path()
      ..moveTo(0, top)
      ..lineTo(cx - half, top)
      ..cubicTo(cx - half * .6, top, cx - half * .62, top - hump, cx, top - hump)
      ..cubicTo(cx + half * .62, top - hump, cx + half * .6, top, cx + half, top)
      ..lineTo(size.width, top)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0x552B1270), 6, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  // Only the white bar takes taps; the strip above it belongs to the page.
  @override
  bool? hitTest(Offset position) => position.dy >= top;

  @override
  bool shouldRepaint(_BarPainter old) => old.top != top;
}

/// The design's Assets icon: a ring with a centre dot and a magnifier handle.
class _AssetsIconPainter extends CustomPainter {
  _AssetsIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(11 * s, 11 * s), 7.5 * s, stroke);
    canvas.drawCircle(Offset(11 * s, 11 * s), 2.4 * s, Paint()..color = color);
    canvas.drawLine(Offset(16.6 * s, 16.6 * s), Offset(21 * s, 21 * s), stroke);
  }

  @override
  bool shouldRepaint(_AssetsIconPainter old) => old.color != color;
}
