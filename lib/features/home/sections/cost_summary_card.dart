import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/features/home/sections/live_dashboard_cards.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

final _n = NumberFormat('#,###');

class CostSummaryCard extends ConsumerWidget {
  const CostSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apiMode) return const LiveCostSummaryCard();
    final org = ref.watch(orgSummaryProvider);
    final entries = org.costs.entries.toList();
    return SectionCard(
      title: 'Cost Summary (AED)',
      actionLabel: 'View Details',
      onAction: DemoGuard.push(context, Routes.costSummary),
      child: Row(
        children: [
          DonutChart(
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
                  LegendRow(
                    color: costColors[i % costColors.length],
                    label: entries[i].key,
                    value: _n.format(entries[i].value),
                    pct: '(${org.costPct(entries[i].key).round()}%)',
                    onTap: DemoGuard.push(context, Routes.costSummary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
