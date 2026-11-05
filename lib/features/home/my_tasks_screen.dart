import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/home/task_row.dart';

/// Full list behind Home "My Tasks → View All".
class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  late int _tab = widget.initialTab.clamp(0, 3);

  @override
  Widget build(BuildContext context) {
    // API mode: work orders, inspections and approvals have no backend in this phase.
    if (apiMode) {
      return AppScaffold(
        body: ListView(
          padding: context.pagePadding,
          children: const [
            PageTitle(title: 'My Tasks', subtitle: 'Work orders, inspections and approvals assigned to you'),
            SizedBox(height: 16),
            AppCard(child: NotAvailableYet(feature: 'My Tasks', icon: Icons.task_alt_rounded)),
          ],
        ),
      );
    }
    final home = ref.watch(homeDataProvider);
    final tabs = [
      ('All', home.allTasks),
      ('Work Orders', home.workOrderTasks),
      ('Inspections', home.inspectionTasks),
      ('Approvals', home.approvalTasks),
    ];
    final list = tabs[_tab].$2;
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'My Tasks',
            subtitle: 'Work orders, inspections and approvals assigned to you',
            help:
                'Everything waiting for you, sorted by due time. Work orders include the ones you coordinate; '
                'All is always the sum of the other tabs.',
          ),
          const SizedBox(height: 12),
          SegmentTabs(
            tabs: [for (final t in tabs) SegmentTab(t.$1, count: t.$2.length)],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          LoadingGate(
            rows: 5,
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Nothing here',
                      message: 'You are all caught up.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[if (i > 0) const Divider(), TaskRow(task: list[i])],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
