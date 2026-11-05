import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/features/home/sections/live_home.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/home/task_row.dart';

class MyTasksCard extends ConsumerStatefulWidget {
  const MyTasksCard({super.key});

  @override
  ConsumerState<MyTasksCard> createState() => _MyTasksCardState();
}

class _MyTasksCardState extends ConsumerState<MyTasksCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    if (apiMode) return const HomeNotAvailableCard(title: 'My Tasks');
    final home = ref.watch(homeDataProvider);
    final tabs = [
      ('All', home.allTasks),
      ('Work Orders', home.workOrderTasks),
      ('Inspections', home.inspectionTasks),
      ('Approvals', home.approvalTasks),
    ];
    final list = tabs[_tab].$2;
    return SectionCard(
      title: 'My Tasks',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, '${Routes.myTasks}?tab=$_tab'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  PillChip(
                    label: '${tabs[i].$1} (${tabs[i].$2.length})',
                    selected: i == _tab,
                    onTap: () => setState(() => _tab = i),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            const EmptyState(icon: Icons.task_alt_rounded, title: 'Nothing here', message: 'You are all caught up.')
          else
            for (var i = 0; i < math.min(3, list.length); i++) ...[if (i > 0) const Divider(), TaskRow(task: list[i])],
          if (list.length > 3)
            TextButton(
              onPressed: DemoGuard.push(context, '${Routes.myTasks}?tab=$_tab'),
              child: Text('Show ${list.length - 3} more'),
            ),
        ],
      ),
    );
  }
}
