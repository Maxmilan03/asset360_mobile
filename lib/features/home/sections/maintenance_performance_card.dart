import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/features/home/sections/live_dashboard_cards.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';

class MaintenancePerformanceCard extends ConsumerWidget {
  const MaintenancePerformanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apiMode) return const LiveMaintenanceCard();
    final kpis = ref.watch(maintenanceKpisProvider);
    return SectionCard(
      title: 'Maintenance Performance',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, Routes.maintenancePerformance),
      child: Row(
        children: [
          for (var i = 0; i < kpis.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: MaintenanceKpiTile(
                value: kpis[i].valueText,
                unit: kpis[i].unit == '%' ? null : kpis[i].unit,
                label: kpis[i].label,
                onTap: DemoGuard.push(context, Routes.maintenancePerformance),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One KPI box of the Maintenance Performance card: green value (+ unit) over a label.
class MaintenanceKpiTile extends StatelessWidget {
  const MaintenanceKpiTile({super.key, required this.value, this.unit, required this.label, this.onTap});

  final String value;
  final String? unit;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF8F9FC),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
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
                      text: value,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
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
              child: Text(label, maxLines: 1, style: AppText.caption.copyWith(fontSize: 11, color: AppColors.text)),
            ),
          ],
        ),
      ),
    ),
  );
}
