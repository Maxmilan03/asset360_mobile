import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';

class HomeTopSection extends ConsumerWidget {
  const HomeTopSection({super.key});

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
    return DemoGuard(
      action: DemoAction.homeSiteSelector,
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
