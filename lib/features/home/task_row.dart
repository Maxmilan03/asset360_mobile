import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';

String taskRoute(MyTask t) => switch (t.kind) {
  TaskKind.workOrder => Routes.workOrder(t.id),
  TaskKind.inspection => Routes.inspectionDetail(t.id),
  TaskKind.approval => Routes.approvals,
};

/// Priority chip · ID, subtitle, location · due time · chevron.
class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.task});

  final MyTask task;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: DemoGuard.push(context, taskRoute(task)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Align(alignment: Alignment.topLeft, child: PriorityChip(task.priority)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 3),
                  IconLine(icon: Icons.location_on_outlined, text: task.location),
                ],
              ),
            ),
            const SizedBox(width: 8),
            task.kind == TaskKind.approval
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Awaiting', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      const Text(
                        'You',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.purple),
                      ),
                    ],
                  )
                : DueLabel(task.due),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
