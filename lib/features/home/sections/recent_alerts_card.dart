import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/features/home/sections/live_home.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';

(IconData, TileTone) severityIcon(String severity) => switch (severity) {
  Severity.critical => (Icons.warning_rounded, TileTone.pink),
  Severity.high => (Icons.warning_rounded, TileTone.peach),
  _ => (Icons.info_rounded, TileTone.sky),
};

class RecentAlertsCard extends ConsumerWidget {
  const RecentAlertsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apiMode) return const HomeNotAvailableCard(title: 'Recent Alerts');
    final home = ref.watch(homeDataProvider);
    return SectionCard(
      title: 'Recent Alerts',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, Routes.recentAlerts),
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
      onTap: DemoGuard.go(context, Routes.alertDetail(alert.id)),
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
