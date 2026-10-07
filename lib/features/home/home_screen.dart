import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:asset360_mobile/features/home/home_sheets.dart';
import 'package:asset360_mobile/features/home/quick_actions.dart';
import 'package:asset360_mobile/features/home/task_row.dart';

final _n = NumberFormat('#,###');

/// Home dashboard (design/02_home_dashboard.jpg): one long scrolling page.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    const sections = <Widget>[
      _TopSection(),
      _QuickActionsCard(),
      _MyTasksCard(),
      _AssetOverviewCard(),
      _MaintenancePerformanceCard(),
      _UpcomingActivitiesCard(),
      _RecentAlertsCard(),
      _AssetLocationCard(),
      _AssetHealthCard(),
      CostSummaryCard(),
      _RecentAssetsCard(),
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
                            if (_refreshing && s is! _TopSection) const ListSkeleton(rows: 2, card: true) else s,
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

// ---------------------------------------------------------------- Top section

class _TopSection extends ConsumerWidget {
  const _TopSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final user = ref.watch(currentUserProvider);
    final home = ref.watch(homeDataProvider);
    final hour = DemoClock.now.hour;
    final greeting = hour < 12 ? 'Good Morning' : (hour < 17 ? 'Good Afternoon' : 'Good Evening');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, ${user.firstName}!', style: AppText.pageTitle.copyWith(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text("Here's what's happening today.", style: AppText.pageSubtitle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DemoClock.formatLong(DemoClock.now), style: AppText.caption.copyWith(fontSize: 12)),
                  const SizedBox(height: 6),
                  const _SitePicker(),
                ],
              ),
            ],
          ),
          if (home.filtered) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text('Showing ${home.site} only'),
                avatar: Icon(Icons.filter_alt_rounded, size: 16, color: AppColors.primary),
                labelStyle: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                backgroundColor: AppColors.primarySoft,
                side: BorderSide.none,
                onDeleted: () => ref.read(sessionProvider.notifier).switchSite('All Sites'),
                deleteIconColor: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 128,
            child: Row(
              children: [
                Expanded(
                  child: KpiTile(
                    icon: Icons.assignment_rounded,
                    value: '${home.myWorkOrders}',
                    label: 'Work Orders',
                    caption: 'My Assigned',
                    tone: TileTone.sky,
                    onTap: DemoGate.tap(() => context.go(Routes.maintenanceTab('mine'))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KpiTile(
                    icon: Icons.fact_check_rounded,
                    value: '${home.inspectionsDueToday}',
                    label: 'Inspections',
                    caption: 'Due Today',
                    tone: TileTone.mint,
                    onTap: DemoGate.tap(() => context.go(Routes.inspectionTab('dueToday'))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KpiTile(
                    icon: Icons.check_box_rounded,
                    value: '${home.pendingApprovals}',
                    label: 'Approvals',
                    caption: 'Pending',
                    tone: TileTone.peach,
                    onTap: DemoGate.tap(() => context.push(Routes.approvals)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KpiTile(
                    icon: Icons.notifications_active_rounded,
                    value: '${home.criticalAlerts}',
                    label: 'Critical Alert',
                    caption: 'Requires Action',
                    tone: TileTone.pink,
                    onTap: DemoGate.tap(() => context.go(Routes.alertsTab('critical'))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SitePicker extends ConsumerWidget {
  const _SitePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = ref.watch(sessionProvider.select((s) => s.site));
    final sites = ref.watch(sitesProvider);
    return DemoGate(
      child: PopupMenuButton<String>(
        tooltip: 'Select site',
        initialValue: site,
        offset: const Offset(0, 40),
        onSelected: (s) {
          ref.read(sessionProvider.notifier).switchSite(s);
          context.showSnack(s == 'All Sites' ? 'Showing all sites' : 'Showing $s');
        },
        itemBuilder: (_) => [
          for (final s in sites)
            PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  Icon(
                    s == site ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: s == site ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(s),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: Text(
                  site,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.text),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Quick actions

class _QuickActionsCard extends ConsumerWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(quickActionsProvider).where((a) => a.enabled).take(homeQuickActionSlots).toList();
    return SectionCard(
      title: 'Quick Actions',
      actionLabel: 'Customize',
      actionIcon: null,
      onAction: DemoGate.tap(() => showCustomizeQuickActions(context)),
      child: GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .95,
        children: [
          for (final a in shown)
            DemoGate(
              child: ActionTile(
                icon: quickActionDefs[a.id]!.icon,
                label: quickActionDefs[a.id]!.label,
                tone: quickActionDefs[a.id]!.tone,
                labelSize: 11.5,
                onTap: () => openRoute(context, quickActionDefs[a.id]!.route),
              ),
            ),
          DemoGate(
            child: ActionTile(
              icon: Icons.more_horiz_rounded,
              label: 'More Actions',
              tone: TileTone.grey,
              labelSize: 11.5,
              onTap: () => showMoreActionsSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- My Tasks

class _MyTasksCard extends ConsumerStatefulWidget {
  const _MyTasksCard();

  @override
  ConsumerState<_MyTasksCard> createState() => _MyTasksCardState();
}

class _MyTasksCardState extends ConsumerState<_MyTasksCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeDataProvider);
    final tabs = [
      ('All', home.allTasks),
      ('Work Orders', home.workOrderTasks),
      ('Inspections', home.inspectionTasks),
      ('Approvals', home.approvalTasks),
    ];
    final list = tabs[_tab].$2;
    return SectionCard(
      title: 'My Tasks',
      actionLabel: 'View All',
      onAction: DemoGate.tap(() => context.push('${Routes.myTasks}?tab=$_tab')),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  DemoGate(
                    child: PillChip(
                      label: '${tabs[i].$1} (${tabs[i].$2.length})',
                      selected: i == _tab,
                      onTap: () => setState(() => _tab = i),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            const EmptyState(icon: Icons.task_alt_rounded, title: 'Nothing here', message: 'You are all caught up.')
          else
            for (var i = 0; i < math.min(3, list.length); i++) ...[
              if (i > 0) const Divider(),
              DemoGate(child: TaskRow(task: list[i])),
            ],
          if (list.length > 3)
            DemoGate(
              child: TextButton(
                onPressed: () => context.push('${Routes.myTasks}?tab=$_tab'),
                child: Text('Show ${list.length - 3} more'),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Asset overview

const assetStatusColors = {
  AssetStatus.active: Color(0xFF22B35E),
  AssetStatus.underMaintenance: Color(0xFFF5B800),
  AssetStatus.inactive: Color(0xFF3B82F6),
  AssetStatus.retired: Color(0xFF7C8595),
  AssetStatus.disposed: Color(0xFFEF4444),
};

class _Donut extends StatelessWidget {
  const _Donut({required this.values, required this.colors, required this.center});

  final List<double> values;
  final List<Color> colors;
  final Widget center;
  static const size = 124.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 1.5,
              centerSpaceRadius: size * .34,
              sections: [
                for (var i = 0; i < values.length; i++)
                  PieChartSectionData(value: values[i], color: colors[i], radius: size * .14, showTitle: false),
              ],
            ),
          ),
          center,
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.value, this.pct, this.onTap});

  final Color color;
  final String label;
  final String value;
  final String? pct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: DemoGate.tap(onTap),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, maxLines: 1, style: AppText.body.copyWith(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: AppText.bodyStrong.copyWith(fontSize: 12.5)),
              ),
            ),
            if (pct != null)
              SizedBox(
                width: 44,
                child: Text(pct!, textAlign: TextAlign.right, style: AppText.caption.copyWith(fontSize: 11.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssetOverviewCard extends ConsumerWidget {
  const _AssetOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgSummaryProvider);
    return SectionCard(
      title: 'Asset Overview',
      actionLabel: 'View All',
      onAction: DemoGate.tap(() => context.go(Routes.assets)),
      child: Row(
        children: [
          _Donut(
            values: [for (final s in AssetStatus.summary) (org.statusCounts[s] ?? 0).toDouble()],
            colors: [for (final s in AssetStatus.summary) assetStatusColors[s]!],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_n.format(org.totalAssets), style: AppText.cardTitle.copyWith(fontSize: 19)),
                Text('Assets', style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (final s in AssetStatus.summary)
                  _LegendRow(
                    color: assetStatusColors[s]!,
                    label: s,
                    value: _n.format(org.statusCounts[s] ?? 0),
                    pct: '(${org.statusPct(s).round()}%)',
                    onTap: () => context.go(Routes.assetsWithStatus(s)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Maintenance performance

class _MaintenancePerformanceCard extends ConsumerWidget {
  const _MaintenancePerformanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(maintenanceKpisProvider);
    return SectionCard(
      title: 'Maintenance Performance',
      actionLabel: 'View All',
      onAction: DemoGate.tap(() => context.go(Routes.maintenance)),
      child: Row(
        children: [
          for (var i = 0; i < kpis.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Material(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: DemoGate.tap(() => showKpiSheet(context, kpis[i])),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: kpis[i].valueText,
                                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                                ),
                                if (kpis[i].unit != '%')
                                  TextSpan(
                                    text: ' ${kpis[i].unit}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                            style: const TextStyle(color: AppColors.green),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            kpis[i].label,
                            maxLines: 1,
                            style: AppText.caption.copyWith(fontSize: 11, color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Upcoming activities

String activityRoute(UpcomingActivity a) => switch (a.kind) {
  'workOrder' => Routes.workOrder(a.refId),
  'inspection' => Routes.inspectionDetail(a.refId),
  _ => Routes.auditSession(a.refId),
};

(IconData, TileTone) activityIcon(String kind) => switch (kind) {
  'workOrder' => (Icons.build_rounded, TileTone.sky),
  'inspection' => (Icons.description_rounded, TileTone.mint),
  _ => (Icons.view_in_ar_rounded, TileTone.lavender),
};

class _UpcomingActivitiesCard extends ConsumerWidget {
  const _UpcomingActivitiesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(upcomingActivitiesProvider);
    return SectionCard(
      title: 'Upcoming Activities',
      actionLabel: 'View Calendar',
      onAction: DemoGate.tap(() => context.go(Routes.maintenanceCalendar)),
      child: Column(
        children: [
          if (list.isEmpty)
            EmptyState(
              icon: Icons.event_available_rounded,
              title: 'Nothing scheduled',
              message: 'No work orders, inspections or audits are coming up.',
              actionLabel: 'Open Calendar',
              onAction: DemoGate.tap(() => context.go(Routes.maintenanceCalendar)),
            ),
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: DemoGate.tap(() => context.push(activityRoute(a))),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            children: [
                              Text('${a.at.day}', style: AppText.cardTitle.copyWith(fontSize: 16)),
                              Text(DateFormat('MMM').format(a.at), style: AppText.caption),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconSquare(icon: activityIcon(a.kind).$1, tone: activityIcon(a.kind).$2, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                              ),
                              const SizedBox(height: 2),
                              Text(a.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 84),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(DemoClock.formatTime(a.at), style: AppText.body.copyWith(fontSize: 13)),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      a.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption.copyWith(fontSize: 10.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Recent alerts

(IconData, TileTone) severityIcon(String severity) => switch (severity) {
  Severity.critical => (Icons.warning_rounded, TileTone.pink),
  Severity.high => (Icons.warning_rounded, TileTone.peach),
  _ => (Icons.info_rounded, TileTone.sky),
};

class _RecentAlertsCard extends ConsumerWidget {
  const _RecentAlertsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDataProvider);
    return SectionCard(
      title: 'Recent Alerts',
      actionLabel: 'View All',
      onAction: DemoGate.tap(() => context.go(Routes.alerts)),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          if (home.recentAlerts.isEmpty)
            const EmptyState(icon: Icons.notifications_off_outlined, title: 'No alerts')
          else
            for (var i = 0; i < home.recentAlerts.length; i++) ...[
              if (i > 0) const Divider(),
              _AlertRow(alert: home.recentAlerts[i]),
            ],
        ],
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.alert});

  final AlertItem alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetByIdProvider(alert.assetId));
    final (icon, tone) = severityIcon(alert.severity);
    return InkWell(
      onTap: DemoGate.tap(() => context.go(Routes.alertDetail(alert.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            IconSquare(icon: icon, tone: tone, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${alert.assetId} - ${asset?.type ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DemoClock.isToday(alert.at) ? DemoClock.formatTime(alert.at) : DemoClock.formatShort(alert.at),
              style: AppText.caption.copyWith(fontSize: 12, color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Asset location

class _AssetLocationCard extends ConsumerWidget {
  const _AssetLocationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trackingProvider);
    final s = t.summary;
    final legend = [
      (TrackedKind.vehicle, 'Vehicles', s.vehicles),
      (TrackedKind.person, 'People', s.people),
      (TrackedKind.equipment, 'Equipment', s.equipment),
      (TrackedKind.alert, 'Alerts', s.alerts),
    ];
    return SectionCard(
      title: 'Asset Location (Live)',
      actionLabel: 'View Map',
      onAction: DemoGate.tap(() => context.go(Routes.tracking)),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: GestureDetector(
              onTap: DemoGate.tap(() => context.go(Routes.tracking)),
              child: SizedBox(
                height: 128,
                child: Stack(
                  children: [
                    Positioned.fill(child: FloorPlan(entities: t.entities, pinSize: 20)),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Tooltip(
                        message: 'Open map',
                        child: InkWell(
                          onTap: DemoGate.tap(() => context.go(Routes.tracking)),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: AppShadows.card,
                            ),
                            child: Icon(Icons.open_in_full_rounded, size: 16, color: AppColors.text),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 8,
            child: Column(
              children: [
                for (final (kind, label, count) in legend)
                  InkWell(
                    onTap: DemoGate.tap(() => context.go(Routes.tracking)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 17, color: trackedKindColor(kind)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(fontSize: 12.5),
                            ),
                          ),
                          Text(
                            '$count',
                            style: AppText.bodyStrong.copyWith(
                              fontSize: 12.5,
                              color: kind == TrackedKind.alert ? AppColors.red : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Asset health

class _AssetHealthCard extends ConsumerWidget {
  const _AssetHealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgSummaryProvider);
    return SectionCard(
      title: 'Asset Health',
      actionLabel: 'View Details',
      onAction: DemoGate.tap(() => showHealthSheet(context, org)),
      child: InkWell(
        onTap: DemoGate.tap(() => showHealthSheet(context, org)),
        child: Row(
          children: [
            ProgressRing(
              value: org.health / 100,
              size: 128,
              strokeWidth: 16,
              color: AppColors.green,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${org.health}%', style: AppText.cardTitle.copyWith(fontSize: 22)),
                  Text(healthLabel(org.health), style: AppText.caption.copyWith(fontSize: 13, color: AppColors.text)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  for (final e in org.healthBreakdown.entries)
                    _LegendRow(color: healthColors[e.key] ?? AppColors.green, label: e.key, value: '${e.value}%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Cost summary

class CostSummaryCard extends ConsumerWidget {
  const CostSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgSummaryProvider);
    final entries = org.costs.entries.toList();
    return SectionCard(
      title: 'Cost Summary (AED)',
      actionLabel: 'View Details',
      onAction: DemoGate.tap(() => showCostSheet(context, org)),
      child: Row(
        children: [
          _Donut(
            values: [for (final e in entries) e.value.toDouble()],
            colors: [for (var i = 0; i < entries.length; i++) costColors[i % costColors.length]],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(compactAed(org.totalCost), style: AppText.cardTitle.copyWith(fontSize: 19)),
                Text('Total Cost', style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _LegendRow(
                    color: costColors[i % costColors.length],
                    label: entries[i].key,
                    value: _n.format(entries[i].value),
                    pct: '(${org.costPct(entries[i].key).round()}%)',
                    onTap: () => showCostSheet(context, org),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Recent assets

class _RecentAssetsCard extends ConsumerWidget {
  const _RecentAssetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(homeDataProvider).recentAssets;
    return SectionCard(
      title: 'Recent Assets',
      actionLabel: 'View All',
      onAction: DemoGate.tap(() => context.go(Routes.assets)),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          if (assets.isEmpty)
            const EmptyState(icon: Icons.inventory_2_outlined, title: 'No recent assets')
          else
            for (var i = 0; i < assets.length; i++) ...[
              if (i > 0) const Divider(),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DemoGate(
                  child: AssetListTile(
                    title: assets[i].id,
                    subtitle: assets[i].name,
                    location: assets[i].location,
                    imagePath: assets[i].imagePath,
                    trailingTop: StatusChip(assets[i].status),
                    onTap: () {
                      ref.read(recentAssetsProvider.notifier).viewed(assets[i].id);
                      context.go(Routes.assetDetail(assets[i].id));
                    },
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
