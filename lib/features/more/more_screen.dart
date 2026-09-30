import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/session_actions.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/alerts_repository.dart';

/// More tab root: the remaining modules, account items and Logout.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'More',
            subtitle: 'Modules, account and app settings',
            help:
                'Open the remaining Asset360 modules, your profile and settings. '
                'Logout ends the demo session and returns to the sign-in screen.',
          ),
          const SizedBox(height: 16),
          _MenuGroup(
            title: 'Modules',
            items: [
              _MenuItem(
                Icons.location_on_outlined,
                'Tracking & IoT',
                'Live location, sensors and telemetry',
                TileTone.sky,
                () => context.go(Routes.tracking),
              ),
              _MenuItem(
                Icons.inventory_2_outlined,
                'Inventory / Spare Parts',
                'Stock levels, issues and receipts',
                TileTone.peach,
                () => context.go(Routes.inventory),
              ),
              _MenuItem(
                Icons.description_outlined,
                'Documents',
                'Manuals, certificates and warranties',
                TileTone.lavender,
                () => context.go(Routes.documents),
              ),
              _MenuItem(
                Icons.add_box_outlined,
                'Asset Registration',
                'Register new assets one by one or in bulk',
                TileTone.mint,
                () => context.go(Routes.registration),
              ),
              _MenuItem(
                Icons.notifications_active_outlined,
                'Alerts & Notifications',
                'Alarms, thresholds and messages',
                TileTone.pink,
                () => context.go(Routes.alerts),
                badge: unread,
              ),
              _MenuItem(
                Icons.cloud_sync_outlined,
                'Offline Sync',
                'Pending changes and sync status',
                TileTone.cyan,
                () => context.go(Routes.offlineSync),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuGroup(
            title: 'Account',
            items: [
              _MenuItem(
                Icons.person_outline_rounded,
                'Profile',
                'Your details and password',
                TileTone.lavender,
                () => context.push(Routes.profileFrom(Routes.more)),
              ),
              _MenuItem(
                Icons.settings_outlined,
                'Settings',
                'Language, notifications and preferences',
                TileTone.grey,
                () => context.go(Routes.settings),
              ),
              _MenuItem(
                Icons.help_outline_rounded,
                'Help & Support',
                'FAQs, contact support and report a bug',
                TileTone.sky,
                () => context.go(Routes.help),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuGroup(
            items: [
              _MenuItem(
                Icons.logout_rounded,
                'Logout',
                null,
                TileTone.pink,
                () => confirmLogout(context, ref),
                destructive: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _VersionLabel(),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(
    this.icon,
    this.title,
    this.subtitle,
    this.tone,
    this.onTap, {
    this.badge = 0,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final TileTone tone;
  final VoidCallback onTap;
  final int badge;
  final bool destructive;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items, this.title});

  final String? title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!.toUpperCase(),
              style: AppText.caption.copyWith(fontWeight: FontWeight.w600, letterSpacing: .6),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(indent: 68),
                _MenuRow(item: items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconSquare(icon: item.icon, tone: item.tone),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppText.bodyStrong.copyWith(color: item.destructive ? AppColors.red : null)),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(item.subtitle!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            if (item.badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.badge, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${item.badge}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            if (!item.destructive) const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final v = snap.data == null ? '' : ' v${snap.data!.version} (${snap.data!.buildNumber})';
        return Text(
          'Purple IQ Asset360$v',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        );
      },
    );
  }
}
