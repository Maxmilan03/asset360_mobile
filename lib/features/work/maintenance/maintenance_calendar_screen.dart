import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';

const _kindColors = {'workOrder': AppColors.iconBlue, 'inspection': AppColors.iconGreen, 'audit': AppColors.purple};
const _kindLabels = {'workOrder': 'Work Order', 'inspection': 'Inspection', 'audit': 'Audit'};

String calendarEventRoute(CalendarEvent e) => switch (e.kind) {
  'workOrder' => Routes.workOrder(e.id),
  'inspection' => Routes.inspectionDetail(e.id),
  _ => Routes.auditSession(e.id),
};

/// Month view with dots on days that have WOs, inspections or audits.
class MaintenanceCalendarScreen extends ConsumerStatefulWidget {
  const MaintenanceCalendarScreen({super.key});

  @override
  ConsumerState<MaintenanceCalendarScreen> createState() => _MaintenanceCalendarScreenState();
}

class _MaintenanceCalendarScreenState extends ConsumerState<MaintenanceCalendarScreen> {
  late DateTime _month = DateTime(DemoClock.now.year, DemoClock.now.month);
  late DateTime _selected = DemoClock.today;

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(calendarEventsProvider);
    final dayEvents = events[_selected] ?? const [];
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday first
    final cells = leading + daysInMonth;

    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Maintenance Calendar',
            subtitle: 'Work orders, inspections and audits by day',
            help:
                'Dots show what is planned each day: blue = work orders, green = inspections, purple = audits. '
                'Tap a day to see its items, then tap an item to open it.',
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_month),
                        textAlign: TextAlign.center,
                        style: AppText.cardTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                      Expanded(
                        child: Text(d, textAlign: TextAlign.center, style: AppText.caption),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: (cells / 7).ceil() * 7,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: .9,
                  ),
                  itemBuilder: (_, i) {
                    final dayNum = i - leading + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
                    final date = DateTime(_month.year, _month.month, dayNum);
                    final list = events[date] ?? const [];
                    final kinds = list.map((e) => e.kind).toSet();
                    final selected = date == _selected;
                    final today = date == DemoClock.today;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selected = date),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : null,
                          borderRadius: BorderRadius.circular(10),
                          border: today && !selected ? Border.all(color: AppColors.primary) : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: today || selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? Colors.white : AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final k in ['workOrder', 'inspection', 'audit'])
                                  if (kinds.contains(k))
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: selected ? Colors.white : _kindColors[k],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  children: [
                    for (final k in _kindColors.keys)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: _kindColors[k], shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(_kindLabels[k]!, style: AppText.caption),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '${DemoClock.formatLong(_selected)} (${dayEvents.length})',
            actionLabel: _selected == DemoClock.today ? null : 'Today',
            actionIcon: Icons.today_rounded,
            onAction: () => setState(() {
              _selected = DemoClock.today;
              _month = DateTime(_selected.year, _selected.month);
            }),
            child: dayEvents.isEmpty
                ? const EmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'Nothing planned',
                    message: 'Pick another day.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < dayEvents.length; i++) ...[
                        if (i > 0) const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 6,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _kindColors[dayEvents[i].kind],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          title: Text(
                            dayEvents[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong,
                          ),
                          subtitle: Text(
                            '${_kindLabels[dayEvents[i].kind]} · ${dayEvents[i].subtitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption,
                          ),
                          trailing: Text(DemoClock.formatTime(dayEvents[i].at), style: AppText.caption),
                          onTap: DemoGuard.push(context, calendarEventRoute(dayEvents[i])),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
