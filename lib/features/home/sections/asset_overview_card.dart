import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/home/home_style.dart';
import 'package:asset360_mobile/features/home/sections/live_home.dart';

final _n = NumberFormat('#,###');

class AssetOverviewCard extends ConsumerWidget {
  const AssetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Asset Overview',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, Routes.assetOverview),
      // API mode: the server's status summary (GET /api/asset-registrations?pageSize=1).
      child: apiMode
          ? LiveCardBody(provider: assetSummaryProvider, builder: (s) => _content(context, s.statusCounts))
          : _content(context, ref.watch(orgSummaryProvider).statusCounts),
    );
  }

  Widget _content(BuildContext context, Map<String, int> counts) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Row(
      children: [
        DonutChart(
          values: [for (final s in AssetStatus.all) (counts[s] ?? 0).toDouble()],
          colors: [for (final s in AssetStatus.all) assetStatusColors[s]!],
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_n.format(total), style: AppText.cardTitle.copyWith(fontSize: 19)),
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
                  value: _n.format(counts[s] ?? 0),
                  pct: '(${total == 0 ? 0 : ((counts[s] ?? 0) * 100 / total).round()}%)',
                  onTap: DemoGuard.tap(DemoAction.homeLegendFilters, DemoGuard.go(context, Routes.assetsWithStatus(s))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
