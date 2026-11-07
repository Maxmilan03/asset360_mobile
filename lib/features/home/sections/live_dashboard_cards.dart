import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_map.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/home_style.dart';
import 'package:asset360_mobile/features/home/sections/maintenance_performance_card.dart';
import 'package:asset360_mobile/features/home/sections/upcoming_activities_card.dart';

/// API mode (apiMode = true) Home cards. Each card reads its own Dashboard endpoint, so one failing
/// endpoint shows its own error + Retry while the others still show. The site selector
/// ([dashSiteProvider]) narrows the cards whose endpoint accepts `site=` (Maintenance Performance,
/// Recent Assets).

// ---------------------------------------------------------------- Asset Overview

class LiveAssetOverviewCard extends ConsumerWidget {
  const LiveAssetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = (search: null, site: ref.watch(dashSiteProvider));
    return SectionCard(
      title: 'Asset Overview',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, Routes.assetOverview),
      child: DashSection<DashAssetOverview>(
        provider: dashAssetOverviewProvider(q),
        onRetry: (ref) => ref.invalidate(dashAssetOverviewProvider(q)),
        isEmpty: (o) => o.totalAssets == 0,
        emptyIcon: Icons.inventory_2_outlined,
        emptyTitle: 'No assets yet',
        emptyMessage: 'Registered assets appear here.',
        builder: (o) => Row(
          children: [
            DonutChart(
              values: [for (final s in o.byStatus) s.count.toDouble()],
              colors: [for (final s in o.byStatus) dashStatusColor(s.key)],
              center: DonutCenter(value: dashNumber.format(o.totalAssets), caption: 'Assets'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final s in o.byStatus)
                    LegendRow(
                      color: dashStatusColor(s.key),
                      label: s.label,
                      value: dashNumber.format(s.count),
                      pct: '(${dashPct(s.percent)})',
                      onTap: DemoGuard.tap(
                        DemoAction.homeLegendFilters,
                        DemoGuard.push(context, Routes.recentAssetsFiltered(status: s.key)),
                      ),
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

// ---------------------------------------------------------------- Maintenance Performance

/// Last 6 months (the server default window), narrowed by the Home site.
class LiveMaintenanceCard extends ConsumerWidget {
  const LiveMaintenanceCard({super.key});

  static const months = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = ref.watch(dashSiteProvider);
    final q = (months: months, assetType: null, site: site);
    final open = DemoGuard.push(context, Routes.maintenancePerformance);
    return SectionCard(
      title: 'Maintenance Performance',
      actionLabel: 'View All',
      onAction: open,
      child: DashSection<DashMaintenance>(
        provider: dashMaintenanceProvider(q),
        onRetry: (ref) => ref.invalidate(dashMaintenanceProvider(q)),
        isEmpty: (m) => m.counts.total == 0,
        emptyIcon: Icons.build_circle_outlined,
        emptyTitle: 'No work orders',
        emptyMessage: 'None in the last $months months${site == null ? '' : ' at $site'}.',
        builder: (m) => Row(
          children: [
            Expanded(
              child: MaintenanceKpiTile(value: dashPct(m.plannedPercent), label: 'Planned', onTap: open),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: MaintenanceKpiTile(value: '${m.counts.overdue}', label: 'Overdue WOs', onTap: open),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: MaintenanceKpiTile(
                value: _metric(m.mttr),
                unit: m.mttr.unit.isEmpty ? null : m.mttr.unit,
                label: 'MTTR',
                onTap: open,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A metric value; "—" when the server had nothing to measure (it sends 0 with no change).
String _metric(DashMetricValue v) {
  if (v.value == 0 && v.changePercent == null) return '—';
  return v.value == v.value.roundToDouble() ? '${v.value.toInt()}' : v.value.toStringAsFixed(1);
}

// ---------------------------------------------------------------- Upcoming Activities

class LiveUpcomingActivitiesCard extends ConsumerWidget {
  const LiveUpcomingActivitiesCard({super.key});

  static const rows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashActivitiesQuery query = (from: null, to: null, type: null, site: ref.watch(dashSiteProvider));
    return SectionCard(
      title: 'Upcoming Activities',
      actionLabel: 'View Calendar',
      onAction: DemoGuard.push(context, Routes.activitiesView('calendar')),
      child: DashSection<DashActivities>(
        provider: dashActivitiesProvider(query),
        onRetry: (ref) => ref.invalidate(dashActivitiesProvider(query)),
        isEmpty: (a) => a.items.isEmpty,
        emptyIcon: Icons.event_available_rounded,
        emptyTitle: 'No upcoming activities',
        emptyMessage: 'Nothing scheduled in the next 30 days.',
        builder: (a) => Column(
          children: [
            for (final i in a.items.take(rows))
              UpcomingActivityRow(
                day: i.date ?? i.startUtc?.toLocal() ?? DateTime.now(),
                icon: dashActivityLook(i.type).$1,
                tone: dashActivityLook(i.type).$2,
                title: i.title,
                subtitle: [i.reference, ?i.assetName].where((s) => s.isNotEmpty).join(' · '),
                time: i.startUtc == null ? '' : DemoClock.formatTime(i.startUtc!.toLocal()),
                location: i.location,
                onTap: () => showNotAvailableYet(context, dashModuleOf(i.type)),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Recent Alerts

class LiveRecentAlertsCard extends ConsumerWidget {
  const LiveRecentAlertsCard({super.key});

  static const rows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashAlertsQuery query = (severity: null, days: 7, site: ref.watch(dashSiteProvider));
    return SectionCard(
      title: 'Recent Alerts',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, Routes.recentAlerts),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: DashSection<DashPage<DashAlertItem, DashAlertCounts>>(
        provider: dashAlertsProvider(query),
        onRetry: (ref) => ref.invalidate(dashAlertsProvider(query)),
        isEmpty: (p) => p.items.isEmpty,
        emptyIcon: Icons.notifications_off_outlined,
        emptyTitle: 'No recent alerts',
        emptyMessage: 'Nothing in the last 7 days.',
        builder: (p) => Column(
          children: [
            for (final (i, a) in p.items.take(rows).indexed) ...[
              if (i > 0) const Divider(),
              DashAlertRow(alert: a, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

/// One dashboard alert (Home card and Recent Alerts drill-down). Alert details are not connected
/// yet, so a tap says so.
class DashAlertRow extends ConsumerWidget {
  const DashAlertRow({super.key, required this.alert, this.compact = false});

  final DashAlertItem alert;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, tone, chip) = dashSeverityLook(alert.severity);
    // assetId is the ASSET TAG ("CHL-30002"): a link that looks the asset up (type=assetTag).
    final tag = alert.assetId;
    final sub = [?(tag == null ? alert.reference : null), ?alert.assetName].join(' – ');
    return InkWell(
      onTap: () => showNotAvailableYet(context, dashModuleOf(alert.source)),
      child: Padding(
        padding: compact
            ? const EdgeInsets.symmetric(vertical: 8, horizontal: 2)
            : const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            IconSquare(icon: icon, tone: tone, size: compact ? 36 : 38),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: compact ? AppText.body.copyWith(fontSize: 13) : AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (tag != null) ...[
                        Flexible(child: AssetTagLink(tag: tag)),
                        if (sub.isNotEmpty) Text(' – ', style: AppText.caption),
                      ],
                      Flexible(
                        child: Text(
                          sub.isEmpty && tag == null ? alert.source : sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: AppColors.textSecondary),
                        Text(dashTimeAgo(alert.occurredAtUtc), style: AppText.caption.copyWith(fontSize: 11.5)),
                        if (alert.status != null)
                          Text('· ${alert.status}', style: AppText.caption.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (compact)
              Text(
                dashTimeAgo(alert.occurredAtUtc),
                style: AppText.caption.copyWith(fontSize: 12, color: AppColors.text),
              )
            else
              StatusChip(alert.severity, tone: chip),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Asset Location

class LiveAssetLocationCard extends ConsumerWidget {
  const LiveAssetLocationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashLocationsQuery query = (status: null, search: null, site: ref.watch(dashSiteProvider));
    final open = DemoGuard.push(context, Routes.assetLocation);
    return SectionCard(
      title: 'Asset Location (Live)',
      actionLabel: 'View Map',
      onAction: open,
      child: DashSection<DashAssetLocations>(
        provider: dashAssetLocationsProvider(query),
        onRetry: (ref) => ref.invalidate(dashAssetLocationsProvider(query)),
        isEmpty: (l) => l.assets.isEmpty,
        emptyIcon: Icons.location_off_outlined,
        emptyTitle: 'No assets on the map yet',
        emptyMessage: 'Assets appear here once their location has latitude and longitude.',
        builder: (l) => Row(
          children: [
            Expanded(
              flex: 11,
              child: SizedBox(
                height: 128,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DashAssetMap(assets: l.assets, center: l.center, interactive: false, onMapTap: open),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Tooltip(
                          message: 'Open map',
                          child: InkWell(
                            onTap: open,
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
                  for (final s in l.byStatus)
                    InkWell(
                      onTap: open,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 17, color: dashStatusColor(s.key)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(fontSize: 12.5),
                              ),
                            ),
                            Text('${s.count}', style: AppText.bodyStrong.copyWith(fontSize: 12.5)),
                          ],
                        ),
                      ),
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

// ---------------------------------------------------------------- Asset Health

class LiveAssetHealthCard extends ConsumerWidget {
  const LiveAssetHealthCard({super.key});

  /// Critical assets the drill-down lists (the card itself does not show them).
  static const top = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashHealthQuery q = (top: top, site: ref.watch(dashSiteProvider));
    final open = DemoGuard.push(context, Routes.assetHealth);
    return SectionCard(
      title: 'Asset Health',
      actionLabel: 'View Details',
      onAction: open,
      child: DashSection<DashAssetHealth>(
        provider: dashAssetHealthProvider(q),
        onRetry: (ref) => ref.invalidate(dashAssetHealthProvider(q)),
        isEmpty: (h) => h.totalAssets == 0,
        emptyIcon: Icons.health_and_safety_outlined,
        emptyTitle: 'No assets to score yet',
        builder: (h) => InkWell(
          onTap: open,
          child: Row(
            children: [
              ProgressRing(
                value: h.healthyPercent / 100,
                size: 128,
                strokeWidth: 16,
                color: AppColors.green,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dashPct(h.healthyPercent), style: AppText.cardTitle.copyWith(fontSize: 22)),
                    Text('Healthy', style: AppText.caption.copyWith(fontSize: 13, color: AppColors.text)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (final b in h.breakdown)
                      LegendRow(
                        color: dashHealthColor(b.key),
                        label: b.label,
                        value: dashNumber.format(b.count),
                        pct: '(${dashPct(b.percent)})',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Cost Summary

class LiveCostSummaryCard extends ConsumerWidget {
  const LiveCostSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashCostQuery query = (period: DashCostPeriod.ytd, year: null, site: ref.watch(dashSiteProvider));
    final currency = ref.watch(dashCostSummaryProvider(query)).value?.currency ?? 'AED';
    final open = DemoGuard.push(context, Routes.costSummary);
    return SectionCard(
      title: 'Cost Summary ($currency)',
      actionLabel: 'View Details',
      onAction: open,
      child: DashSection<DashCostSummary>(
        provider: dashCostSummaryProvider(query),
        onRetry: (ref) => ref.invalidate(dashCostSummaryProvider(query)),
        isEmpty: (c) => c.totalCost == 0,
        emptyIcon: Icons.payments_outlined,
        emptyTitle: 'No costs recorded',
        emptyMessage: 'No work order costs in this period yet.',
        builder: (c) => Row(
          children: [
            DonutChart(
              values: [for (final g in c.categories) g.amount],
              colors: [for (var i = 0; i < c.categories.length; i++) costColors[i % costColors.length]],
              center: DonutCenter(value: compactAed(c.totalCost.round()), caption: c.period.label),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final (i, g) in c.categories.indexed)
                    LegendRow(
                      color: costColors[i % costColors.length],
                      label: g.label,
                      value: dashMoney(g.amount),
                      pct: '(${dashPct(g.percent)})',
                      onTap: open,
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

// ---------------------------------------------------------------- Recent Assets

class LiveRecentAssetsCard extends ConsumerWidget {
  const LiveRecentAssetsCard({super.key});

  static const rows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = ref.watch(dashSiteProvider);
    final q = (status: null, search: null, assetType: null, site: site);
    return SectionCard(
      title: 'Recent Assets',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, Routes.recentAssetsFiltered(site: site)),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: DashSection<DashPage<DashRecentAsset, List<DashBreakdownItem>>>(
        provider: dashRecentAssetsProvider(q),
        onRetry: (ref) => ref.invalidate(dashRecentAssetsProvider(q)),
        isEmpty: (p) => p.items.isEmpty,
        emptyIcon: Icons.inventory_2_outlined,
        emptyTitle: 'No assets yet',
        emptyMessage: site == null ? 'Registered assets appear here.' : 'No assets at $site.',
        builder: (p) => Column(
          children: [
            for (final (i, a) in p.items.take(rows).indexed) ...[
              if (i > 0) const Divider(),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LiveAssetTile(
                  item: dashAssetItem(a),
                  statusChip: a.status == null ? null : DashStatusChip(label: a.status!, groupKey: a.statusGroup),
                  onTap: DemoGuard.open(
                    Routes.assetDetail(a.assetRegistrationId),
                    () => context.go(Routes.assetDetail(a.assetRegistrationId)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
