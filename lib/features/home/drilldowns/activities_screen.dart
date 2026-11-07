import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/drilldowns/live/live_activities_screen.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

final _dayTitle = DateFormat('EEE, d MMM yyyy');

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Sunday of [d]'s week.
DateTime _sunday(DateTime d) => DateTime(d.year, d.month, d.day - d.weekday % 7);

ChipTone activityStatusTone(String status) => switch (status) {
  'Planned' => ChipTone.blue,
  'Scheduled' => ChipTone.purple,
  'Pending' => ChipTone.amber,
  'In Progress' => ChipTone.orange,
  'Completed' => ChipTone.green,
  _ => ChipTone.forStatus(status),
};

/// Home "Upcoming Activities" drill-down: List View (grouped by date) and Calendar View
/// (week strip + the selected day's activities), from [plannedActivitiesProvider].
class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key, this.calendar = false});

  /// Opens on Calendar View (Home "View Calendar").
  final bool calendar;

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  late bool _calendar = widget.calendar;
  late DateTime _selected = DemoClock.today;
  late DateTime _week = _sunday(DemoClock.today);

  /// List View kind filter (null = all).
  ActivityKind? _kind;

  @override
  void didUpdateWidget(ActivitiesScreen old) {
    super.didUpdateWidget(old);
    if (old.calendar != widget.calendar) _calendar = widget.calendar;
  }

  /// Sundays of the weeks that overlap the activity window.
  List<DateTime> get _weeks => [
    for (var w = _sunday(activityWindowStart); w.isBefore(activityWindowEnd); w = DateTime(w.year, w.month, w.day + 7))
      w,
  ];

  void _moveWeek(int by) {
    final weeks = _weeks;
    final i = weeks.indexWhere((w) => w == _week);
    final next = weeks[(i + by).clamp(0, weeks.length - 1)];
    setState(() {
      _week = next;
      // Keep the same weekday selected in the new week.
      _selected = DateTime(next.year, next.month, next.day + _selected.weekday % 7);
    });
  }

  String _monthTitle() {
    final end = DateTime(_week.year, _week.month, _week.day + 6);
    if (end.month == _week.month) return DateFormat('MMMM yyyy').format(_week);
    return '${DateFormat('MMM').format(_week)} – ${DateFormat('MMM yyyy').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    if (apiMode) return LiveActivitiesScreen(calendar: widget.calendar);
    final all = ref.watch(plannedActivitiesProvider);
    final today = DemoClock.today;
    return DrilldownPage(
      title: 'Upcoming Activities',
      subtitle:
          '${DemoClock.formatShort(activityWindowStart)} – '
          '${DemoClock.formatDate(activityWindowEnd.subtract(const Duration(days: 1)))}',
      skeletonRows: 5,
      children: [
        ActivityViewToggle(calendar: _calendar, onChanged: (v) => setState(() => _calendar = v)),
        const SizedBox(height: 14),
        if (_calendar) ..._calendarView(all, today) else ..._listView(all, today),
      ],
    );
  }

  List<Widget> _calendarView(List<PlannedActivity> all, DateTime today) {
    final weeks = _weeks;
    final i = weeks.indexOf(_week);
    final dayList = all.where((a) => _day(a.start) == _selected).toList();
    return [
      AppCard(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: i > 0 ? () => _moveWeek(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(_monthTitle(), textAlign: TextAlign.center, style: AppText.cardTitle),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: i < weeks.length - 1 ? () => _moveWeek(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            WeekStrip(
              weekStart: _week,
              selected: _selected,
              today: today,
              dotsFor: (day) => [
                for (final k in ActivityKind.values)
                  if (all.any((a) => a.kind == k && _day(a.start) == day)) activityLook(k).$3,
              ],
              onSelect: (d) => setState(() => _selected = d),
            ),
            const SizedBox(height: 10),
            SeriesLegend(items: [for (final k in ActivityKind.values) (k.label, activityLook(k).$3)]),
          ],
        ),
      ),
      const SizedBox(height: 16),
      ActivityDayHeader(day: _selected, today: today, count: dayList.length),
      const SizedBox(height: 8),
      if (dayList.isEmpty)
        const EmptyState(
          icon: Icons.event_available_rounded,
          title: 'Nothing scheduled',
          message: 'No work orders, inspections, audits or approvals on this day.',
        )
      else
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (var j = 0; j < dayList.length; j++) ...[
                if (j > 0) const Divider(),
                ActivityRow(activity: dayList[j]),
              ],
            ],
          ),
        ),
    ];
  }

  List<Widget> _listView(List<PlannedActivity> all, DateTime today) {
    final shown = all.where((a) => _kind == null || a.kind == _kind).toList();
    final days = <DateTime, List<PlannedActivity>>{};
    for (final a in shown) {
      (days[_day(a.start)] ??= []).add(a);
    }
    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (k, label) in [
              (null, 'All'),
              (ActivityKind.workOrder, 'Work Orders'),
              (ActivityKind.inspection, 'Inspections'),
              (ActivityKind.audit, 'Audits'),
              (ActivityKind.approval, 'Approvals'),
            ]) ...[
              PillChip(
                label: '$label (${all.where((a) => k == null || a.kind == k).length})',
                selected: _kind == k,
                onTap: () => setState(() => _kind = k),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (shown.isEmpty)
        EmptyState(
          icon: Icons.event_available_rounded,
          title: 'Nothing scheduled',
          message: 'No activities of this type between these dates.',
          actionLabel: 'Show all',
          onAction: () => setState(() => _kind = null),
        ),
      for (final e in days.entries) ...[
        ActivityDayHeader(day: e.key, today: today, count: e.value.length),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (var j = 0; j < e.value.length; j++) ...[
                if (j > 0) const Divider(),
                ActivityRow(activity: e.value[j]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    ];
  }
}

class ActivityViewToggle extends StatelessWidget {
  const ActivityViewToggle({super.key, required this.calendar, required this.onChanged});

  final bool calendar;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(String label, IconData icon, bool value) {
      final on = calendar == value;
      return Expanded(
        child: Material(
          color: on ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: on ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(fontSize: 13.5, color: on ? Colors.white : AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          button('List View', Icons.view_list_rounded, false),
          const SizedBox(width: 4),
          button('Calendar View', Icons.calendar_month_rounded, true),
        ],
      ),
    );
  }
}

class ActivityDayHeader extends StatelessWidget {
  const ActivityDayHeader({super.key, required this.day, required this.today, required this.count});

  final DateTime day;
  final DateTime today;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(
          _dayTitle.format(day),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.cardTitle.copyWith(fontSize: 15),
        ),
      ),
      if (day == today) ...[const SizedBox(width: 8), const StatusChip('Today', tone: ChipTone.purple)],
      const SizedBox(width: 8),
      const Spacer(),
      Text('$count ${count == 1 ? 'activity' : 'activities'}', style: AppText.caption),
    ],
  );
}

class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.activity, this.onTap});

  final PlannedActivity activity;

  /// Replaces opening [PlannedActivity.route] (API mode: modules not connected yet).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final (icon, tone, _) = activityLook(a.kind);
    return InkWell(
      onTap: onTap ?? () => context.push(a.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconSquare(icon: icon, tone: tone, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      Text(a.kind.label, style: AppText.caption.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        a.end == a.start
                            ? DemoClock.formatTime(a.start)
                            : '${DemoClock.formatTime(a.start)} – ${DemoClock.formatTime(a.end)}',
                        style: AppText.caption.copyWith(color: AppColors.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [a.refId, ?a.assetId].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                  if (a.location != null)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            a.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(a.status, tone: activityStatusTone(a.status)),
          ],
        ),
      ),
    );
  }
}
