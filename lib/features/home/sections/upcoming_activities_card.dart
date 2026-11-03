import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';

String activityRoute(UpcomingActivity a) => switch (a.kind) {
  'workOrder' => Routes.workOrder(a.refId),
  'inspection' => Routes.inspectionDetail(a.refId),
  _ => Routes.auditSession(a.refId),
};

(IconData, TileTone) activityIcon(String kind) => switch (kind) {
  'workOrder' => (Icons.build_rounded, TileTone.sky),
  'inspection' => (Icons.description_rounded, TileTone.mint),
  _ => (Icons.view_in_ar_rounded, TileTone.lavender),
};

class UpcomingActivitiesCard extends ConsumerWidget {
  const UpcomingActivitiesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(upcomingActivitiesProvider);
    return SectionCard(
      title: 'Upcoming Activities',
      actionLabel: 'View Calendar',
      onAction: DemoGuard.push(context, Routes.activitiesView('calendar')),
      child: Column(
        children: [
          if (list.isEmpty)
            EmptyState(
              icon: Icons.event_available_rounded,
              title: 'Nothing scheduled',
              message: 'No work orders, inspections or audits are coming up.',
              actionLabel: 'Open Calendar',
              onAction: DemoGuard.push(context, Routes.activitiesView('calendar')),
            ),
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: DemoGuard.tap(DemoAction.homeActivityRows, DemoGuard.push(context, activityRoute(a))),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            children: [
                              Text('${a.at.day}', style: AppText.cardTitle.copyWith(fontSize: 16)),
                              Text(DateFormat('MMM').format(a.at), style: AppText.caption),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconSquare(icon: activityIcon(a.kind).$1, tone: activityIcon(a.kind).$2, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                              ),
                              const SizedBox(height: 2),
                              Text(a.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 84),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(DemoClock.formatTime(a.at), style: AppText.body.copyWith(fontSize: 13)),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      a.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption.copyWith(fontSize: 10.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
