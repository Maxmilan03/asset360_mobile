import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/features/home/sections/live_devices_card.dart';
import 'package:asset360_mobile/features/home/sections/live_home.dart';
import 'package:asset360_mobile/features/home/sections/top_section.dart';
import 'package:asset360_mobile/features/home/sections/quick_actions_card.dart';
import 'package:asset360_mobile/features/home/sections/my_tasks_card.dart';
import 'package:asset360_mobile/features/home/sections/asset_overview_card.dart';
import 'package:asset360_mobile/features/home/sections/maintenance_performance_card.dart';
import 'package:asset360_mobile/features/home/sections/upcoming_activities_card.dart';
import 'package:asset360_mobile/features/home/sections/recent_alerts_card.dart';
import 'package:asset360_mobile/features/home/sections/asset_location_card.dart';
import 'package:asset360_mobile/features/home/sections/asset_health_card.dart';
import 'package:asset360_mobile/features/home/sections/cost_summary_card.dart';
import 'package:asset360_mobile/features/home/sections/recent_assets_card.dart';

/// Home dashboard (design/02_home_dashboard.jpg): one long scrolling page.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    // API mode: every section reloads its own endpoint and shows its own shimmer.
    if (apiMode) {
      refreshLiveHome(ref);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return;
    }
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final sections = <Widget>[
      const HomeTopSection(),
      const QuickActionsCard(),
      const MyTasksCard(),
      const AssetOverviewCard(),
      const MaintenancePerformanceCard(),
      const UpcomingActivitiesCard(),
      const RecentAlertsCard(),
      const AssetLocationCard(),
      // API mode only: online / offline devices, live over a WebSocket.
      if (apiMode) const LiveDevicesCard(),
      const AssetHealthCard(),
      const CostSummaryCard(),
      const RecentAssetsCard(),
    ];
    return Scaffold(
      backgroundColor: AppColors.headerBottom,
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: top + _HomeHeaderDelegate.barHeight,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(pinned: true, delegate: _HomeHeaderDelegate(top)),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: AppColors.headerBottom, // shows behind the sheet's rounded corners
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                  child: ColoredBox(
                    color: AppColors.background,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(10, 12, 10, 24 + context.bottomInset),
                      child: Column(
                        children: [
                          for (final s in sections) ...[
                            if (_refreshing && s is! HomeTopSection) const ListSkeleton(rows: 2, card: true) else s,
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Header

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeHeaderDelegate(this.topPadding);

  final double topPadding;
  static const barHeight = 66.0;
  static const heroHeight = 84.0;

  @override
  double get minExtent => topPadding + barHeight;
  @override
  double get maxExtent => topPadding + barHeight + heroHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 1 - t * .6,
            child: CustomPaint(painter: _SkylinePainter()),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(showProduct: t > .7),
              Expanded(
                child: ClipRect(
                  child: Opacity(
                    opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asset360',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Asset Lifecycle, Maintenance & Operations',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: Color(0xE6FFFFFF)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HomeHeaderDelegate old) => old.topPadding != topPadding;
}

/// Subtle factory skyline: chimneys, tanks, towers and a few lights on the right.
class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h;
    final fill = Paint()..color = Colors.white.withValues(alpha: .07);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .10)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final left = w * .42;
    final unit = (w - left) / 20;
    final rng = math.Random(7);
    // buildings
    for (var i = 0; i < 20; i++) {
      final bh = h * (.18 + rng.nextDouble() * .32);
      canvas.drawRect(Rect.fromLTWH(left + i * unit, base - bh, unit * .92, bh), fill);
    }
    // chimneys with a little smoke
    for (final cx in [.55, .68, .86]) {
      final x = w * cx, ch = h * .78;
      canvas.drawRect(Rect.fromLTWH(x, base - ch, unit * .55, ch), fill);
      canvas.drawCircle(Offset(x + unit * .3, base - ch - 8), 6, Paint()..color = Colors.white.withValues(alpha: .05));
    }
    // tanks
    for (final cx in [.62, .78]) {
      final r = unit * 1.6;
      canvas.drawOval(Rect.fromLTWH(w * cx, base - r * 2.2, r * 2, r * 2.2), fill);
    }
    // lattice tower
    final tx = w * .93;
    final tower = Path()
      ..moveTo(tx - unit, base)
      ..lineTo(tx, base - h * .9)
      ..lineTo(tx + unit, base);
    canvas.drawPath(tower, line);
    for (var y = .2; y < .9; y += .14) {
      canvas.drawLine(Offset(tx - unit * (1 - y), base - h * y), Offset(tx + unit * (1 - y), base - h * y), line);
    }
    // pipes
    canvas.drawLine(Offset(left, base - h * .22), Offset(w, base - h * .22), line);
    // lights
    final light = Paint()..color = const Color(0xFFFFD27A).withValues(alpha: .35);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(Offset(left + rng.nextDouble() * (w - left), base - rng.nextDouble() * h * .45), 1.3, light);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
