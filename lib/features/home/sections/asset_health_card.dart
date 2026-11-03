import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

class AssetHealthCard extends ConsumerWidget {
  const AssetHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgSummaryProvider);
    return SectionCard(
      title: 'Asset Health',
      actionLabel: 'View Details',
      onAction: DemoGuard.push(context, Routes.assetHealth),
      child: InkWell(
        onTap: DemoGuard.push(context, Routes.assetHealth),
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
                    LegendRow(color: healthColors[e.key] ?? AppColors.green, label: e.key, value: '${e.value}%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
