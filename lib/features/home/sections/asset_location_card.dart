import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';

class AssetLocationCard extends ConsumerWidget {
  const AssetLocationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trackingProvider);
    final s = t.summary;
    final legend = [
      (TrackedKind.vehicle, 'Vehicles', s.vehicles),
      (TrackedKind.person, 'People', s.people),
      (TrackedKind.equipment, 'Equipment', s.equipment),
      (TrackedKind.alert, 'Alerts', s.alerts),
    ];
    return SectionCard(
      title: 'Asset Location (Live)',
      actionLabel: 'View Map',
      onAction: DemoGuard.push(context, Routes.assetLocation),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: GestureDetector(
              onTap: DemoGuard.push(context, Routes.assetLocation),
              child: SizedBox(
                height: 128,
                child: Stack(
                  children: [
                    Positioned.fill(child: FloorPlan(entities: t.entities, pinSize: 20)),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Tooltip(
                        message: 'Open map',
                        child: InkWell(
                          onTap: DemoGuard.push(context, Routes.assetLocation),
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
                for (final (kind, label, count) in legend)
                  InkWell(
                    onTap: DemoGuard.push(context, Routes.assetLocation),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 17, color: trackedKindColor(kind)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(fontSize: 12.5),
                            ),
                          ),
                          Text(
                            '$count',
                            style: AppText.bodyStrong.copyWith(
                              fontSize: 12.5,
                              color: kind == TrackedKind.alert ? AppColors.red : AppColors.text,
                            ),
                          ),
                        ],
                      ),
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
