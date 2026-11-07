import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';

class HomeTopSection extends ConsumerWidget {
  const HomeTopSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final user = ref.watch(currentUserProvider);
    final home = ref.watch(homeDataProvider);
    // API mode: greeting + the four counters from GET /api/dashboards/mobile/home.
    final live = apiMode ? ref.watch(dashHomeProvider) : null;
    final greet = live?.value?.greeting;
    final hour = DemoClock.now.hour;
    final greeting = greet != null && greet.salutation.isNotEmpty
        ? greet.salutation
        : (hour < 12 ? 'Good Morning' : (hour < 17 ? 'Good Afternoon' : 'Good Evening'));
    final message = greet != null && greet.message.isNotEmpty ? '${greet.message}.' : "Here's what's happening today.";
    final day = apiMode ? (greet?.generatedAtUtc?.toLocal() ?? DateTime.now()) : DemoClock.now;
    final site = apiMode ? ref.watch(dashSiteProvider) : (home.filtered ? home.site : null);

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
                    Text(message, style: AppText.pageSubtitle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DemoClock.formatLong(day), style: AppText.caption.copyWith(fontSize: 12)),
                  const SizedBox(height: 6),
                  if (apiMode) const _LiveSitePicker() else const _SitePicker(),
                ],
              ),
            ],
          ),
          if (site != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text('Showing $site only'),
                avatar: Icon(Icons.filter_alt_rounded, size: 16, color: AppColors.primary),
                labelStyle: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                backgroundColor: AppColors.primarySoft,
                side: BorderSide.none,
                onDeleted: () => apiMode
                    ? ref.read(dashSiteProvider.notifier).select(null)
                    : ref.read(sessionProvider.notifier).switchSite('All Sites'),
                deleteIconColor: AppColors.primary,
              ),
            ),
            if (apiMode) ...[
              const SizedBox(height: 4),
              Text(
                'Applies to Maintenance Performance and Recent Assets; the other cards cover all sites.',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(height: 128, child: apiMode ? _LiveCounters(live!) : _counters(context, home)),
        ],
      ),
    );
  }

  Widget _counters(BuildContext context, HomeData home) => Row(
    children: [
      Expanded(
        child: KpiTile(
          icon: Icons.assignment_rounded,
          value: '${home.myWorkOrders}',
          label: 'Work Orders',
          caption: 'My Assigned',
          tone: TileTone.sky,
          onTap: DemoGuard.go(context, Routes.maintenanceTab('mine')),
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
          onTap: DemoGuard.go(context, Routes.inspectionTab('dueToday')),
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
          onTap: DemoGuard.push(context, Routes.approvals),
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
          onTap: DemoGuard.go(context, Routes.alertsTab('critical')),
        ),
      ),
    ],
  );
}

/// API mode counters: GET /mobile/home `quickActions`. Work orders, inspections and approvals
/// have no module connected yet (a tap says so); Critical opens Recent Alerts on its Critical tab.
class _LiveCounters extends ConsumerWidget {
  const _LiveCounters(this.home);

  final AsyncValue<DashHome> home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (home.hasError && !home.isLoading) {
      return Center(
        child: InlineRetry(
          text: 'Could not load the summary: ${ApiException.from(home.error!).message}',
          onRetry: () => ref.invalidate(dashHomeProvider),
          error: true,
        ),
      );
    }
    final q = home.isLoading ? null : home.value?.quickActions;
    if (q == null) return const ListSkeleton(rows: 1, card: false);
    return Row(
      children: [
        Expanded(
          child: KpiTile(
            icon: Icons.assignment_rounded,
            value: dashNumber.format(q.openWorkOrders),
            label: 'Work Orders',
            caption: 'Open',
            tone: TileTone.sky,
            onTap: () => showNotAvailableYet(context, 'Work orders'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KpiTile(
            icon: Icons.fact_check_rounded,
            value: dashNumber.format(q.pendingInspections),
            label: 'Inspections',
            caption: 'Open',
            tone: TileTone.mint,
            onTap: () => showNotAvailableYet(context, 'Inspections'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KpiTile(
            icon: Icons.check_box_rounded,
            value: dashNumber.format(q.pendingApprovals),
            label: 'Approvals',
            caption: 'Pending',
            tone: TileTone.peach,
            onTap: () => showNotAvailableYet(context, 'Approvals'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KpiTile(
            icon: Icons.notifications_active_rounded,
            value: dashNumber.format(q.criticalAlerts),
            label: 'Critical Alert',
            caption: 'Requires Action',
            tone: TileTone.pink,
            onTap: DemoGuard.push(context, Routes.recentAlertsSeverity(DashSeverity.critical)),
          ),
        ),
      ],
    );
  }
}

class _SitePicker extends ConsumerWidget {
  const _SitePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SiteMenu(
    site: ref.watch(sessionProvider.select((s) => s.site)),
    sites: ref.watch(sitesProvider),
    onSelected: (s) => ref.read(sessionProvider.notifier).switchSite(s),
  );
}

/// API mode: "All Sites" + the site names of the server's assets (GET /mobile/asset-overview).
class _LiveSitePicker extends ConsumerWidget {
  const _LiveSitePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = ref.watch(dashSiteProvider) ?? DashSiteNotifier.allSites;
    final sites = ref.watch(dashSitesProvider).value ?? const [DashSiteNotifier.allSites];
    return _SiteMenu(
      site: site,
      sites: sites.contains(site) ? sites : [...sites, site],
      onSelected: (s) => ref.read(dashSiteProvider.notifier).select(s),
    );
  }
}

class _SiteMenu extends StatelessWidget {
  const _SiteMenu({required this.site, required this.sites, required this.onSelected});

  final String site;
  final List<String> sites;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DemoGuard(
      action: DemoAction.homeSiteSelector,
      child: PopupMenuButton<String>(
        tooltip: 'Select site',
        initialValue: site,
        offset: const Offset(0, 40),
        onSelected: (s) {
          onSelected(s);
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
