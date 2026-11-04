import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

final _n = NumberFormat('#,###');

class AssetOverviewCard extends ConsumerWidget {
  const AssetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgSummaryProvider);
    return SectionCard(
      title: 'Asset Overview',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, Routes.assetOverview),
      child: Row(
        children: [
          DonutChart(
            values: [for (final s in AssetStatus.all) (org.statusCounts[s] ?? 0).toDouble()],
            colors: [for (final s in AssetStatus.all) assetStatusColors[s]!],
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
                for (final s in AssetStatus.all)
                  LegendRow(
                    color: assetStatusColors[s]!,
                    label: s,
                    value: _n.format(org.statusCounts[s] ?? 0),
                    pct: '(${org.statusPct(s).round()}%)',
                    onTap: DemoGuard.tap(
                      DemoAction.homeLegendFilters,
                      DemoGuard.go(context, Routes.assetsWithStatus(s)),
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
