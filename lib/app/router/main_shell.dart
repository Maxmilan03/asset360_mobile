import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/core/widgets/demo_guard.dart';
import 'package:asset360_mobile/features/more/all_modules.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/router/routes.dart';

/// Hosts the four tab branches (Home, Assets, Work, More) and the bottom bar:
/// Home, Assets, [raised Scan button], Work, More.
///
/// The bar is visible on every signed-in screen. Scan opens Scan & Identify on top
/// of the current screen (back returns there); More opens the All Modules sheet.
/// Sheets and dialogs open on the current branch's navigator, which sits under the bar.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell, required this.location, required this.branchKeys});

  final StatefulNavigationShell navigationShell;
  final String location;
  final List<GlobalKey<NavigatorState>> branchKeys;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

/// Bar slot → branch index (the Scan slot has no branch).
const _branchOfSlot = {0: 0, 1: 1, 3: 2, 4: 3};

class _MainShellState extends ConsumerState<MainShell> {
  bool _modulesOpen = false;

  StatefulNavigationShell get _shell => widget.navigationShell;
  BuildContext? get _branchContext => widget.branchKeys[_shell.currentIndex].currentContext;
  bool get _onScan => widget.location.contains('/${Routes.scanSegment}');

  void _closeModules() {
    final ctx = _branchContext;
    if (_modulesOpen && ctx != null) Navigator.of(ctx).pop();
  }

  Future<void> _openModules() async {
    final ctx = _branchContext;
    if (ctx == null) return;
    setState(() => _modulesOpen = true);
    final picked = await showAllModulesSheet(ctx, location: widget.location);
    if (!mounted) return;
    setState(() => _modulesOpen = false);
    final c = _branchContext;
    if (picked != null && c != null && c.mounted) openModule(c, ref, picked, from: widget.location);
  }

  void _onTap(int slot) {
    if (slot == 4) {
      _modulesOpen ? _closeModules() : _openModules();
      return;
    }
    _closeModules();
    if (slot == 2) {
      if (!_onScan) GoRouter.of(context).push(Routes.scanFrom(widget.location));
      return;
    }
    final index = _branchOfSlot[slot]!;
    // Re-tapping the active tab returns to that tab's first screen.
    _shell.goBranch(index, initialLocation: index == _shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final onHome = _shell.currentIndex == 0;
    final int active;
    if (_modulesOpen) {
      active = 4;
    } else if (_onScan) {
      active = 2;
    } else {
      active = _branchOfSlot.entries.firstWhere((e) => e.value == _shell.currentIndex).key;
    }
    return PopScope(
      // Android back at the root of another tab goes to Home first; at Home it exits.
      canPop: onHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !onHome) _shell.goBranch(0);
      },
      child: Scaffold(
        extendBody: true,
        body: _shell,
        bottomNavigationBar: AppBottomBar(currentIndex: active, onTap: _onTap),
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
                    onTap: DemoGuard.open(Routes.assets, () => onTap(1)),
                    icon: (c, _) => CustomPaint(size: const Size(26, 26), painter: _AssetsIconPainter(c)),
                  ),
                  _ScanItem(
                    active: currentIndex == 2,
                    onTap: DemoGuard.open(Routes.scanFrom(Routes.home), () => onTap(2)),
                  ),
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

  /// Null keeps the item visible but inert (module switched off).
  final VoidCallback? onTap;
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
  final VoidCallback? onTap;

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
                    gradient: LinearGradient(
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
    canvas.drawPath(path, Paint()..color = AppColors.surface);
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
