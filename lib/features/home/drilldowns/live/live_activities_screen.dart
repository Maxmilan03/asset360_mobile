import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/activities_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Sunday of [d]'s week.
DateTime _sunday(DateTime d) => DateTime(d.year, d.month, d.day - d.weekday % 7);

/// A server activity in the shape the shared [ActivityRow] shows.
PlannedActivity _planned(DashActivityItem i) {
  final start = (i.startUtc?.toLocal()) ?? i.date ?? DateTime.now();
  final end = i.endUtc?.toLocal();
  return PlannedActivity(
    kind: switch (i.type) {
      DashActivityType.workOrder => ActivityKind.workOrder,
      DashActivityType.inspection => ActivityKind.inspection,
      _ => ActivityKind.approval,
    },
    refId: i.reference,
    title: i.title,
    start: start,
    end: end != null && end.isAfter(start) ? end : start,
    status: i.status,
    route: '',
    assetId: i.assetName == null ? i.assetId : '${i.assetId ?? ''} ${i.assetName}'.trim(),
    location: i.location,
  );
}

/// API mode Upcoming Activities: GET /api/dashboards/mobile/upcoming-activities with `from` / `to`
/// = this week's Sunday + [weeks] weeks (List View and Calendar View read the same reply; the
/// calendar dots come from `days`). Work orders, inspections and approvals are not connected yet,
/// so a row says so.
class LiveActivitiesScreen extends ConsumerStatefulWidget {
  const LiveActivitiesScreen({super.key, this.calendar = false});

  final bool calendar;

  /// Weeks loaded from this week's Sunday.
  static const weeks = 8;

  @override
  ConsumerState<LiveActivitiesScreen> createState() => _LiveActivitiesScreenState();
}

class _LiveActivitiesScreenState extends ConsumerState<LiveActivitiesScreen> {
  late bool _calendar = widget.calendar;
  final DateTime _today = _day(DateTime.now());
  late final DateTime _from = _sunday(_today);
  late final DateTime _to = DateTime(_from.year, _from.month, _from.day + LiveActivitiesScreen.weeks * 7 - 1);
  late DateTime _selected = _today;
  late DateTime _week = _from;

  /// List View type filter (null = all).
  String? _type;

  @override
  void didUpdateWidget(LiveActivitiesScreen old) {
    super.didUpdateWidget(old);
    if (old.calendar != widget.calendar) _calendar = widget.calendar;
  }

  DashActivitiesQuery get _q => (from: _from, to: _to, type: null, site: ref.watch(dashSiteProvider));

  void _moveWeek(int by) {
    final i = _weekIndex + by;
    if (i < 0 || i >= LiveActivitiesScreen.weeks) return;
    final next = DateTime(_from.year, _from.month, _from.day + i * 7);
    setState(() {
      _week = next;
      _selected = DateTime(next.year, next.month, next.day + _selected.weekday % 7);
    });
  }

  int get _weekIndex => _week.difference(_from).inDays ~/ 7;

  String _monthTitle() {
    final end = DateTime(_week.year, _week.month, _week.day + 6);
    if (end.month == _week.month) return DateFormat('MMMM yyyy').format(_week);
    return '${DateFormat('MMM').format(_week)} – ${DateFormat('MMM yyyy').format(end)}';
  }

  void _open(DashActivityItem i) => showNotAvailableYet(context, dashModuleOf(i.type));

  @override
  Widget build(BuildContext context) {
    final provider = dashActivitiesProvider(_q);
    return DrilldownPage(
      title: 'Upcoming Activities',
      subtitle:
          '${DemoClock.formatShort(_from)} – ${DemoClock.formatDate(_to)} · ${dashSiteLabel(ref.watch(dashSiteProvider))}',
      skeletonRows: 5,
      onRefresh: () => ref.invalidate(provider),
      children: [
        ActivityViewToggle(calendar: _calendar, onChanged: (v) => setState(() => _calendar = v)),
        const SizedBox(height: 14),
        DashSection<DashActivities>(
          provider: provider,
          onRetry: (ref) => ref.invalidate(provider),
          rows: 4,
          builder: (a) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _calendar ? _calendarView(a) : _listView(a),
          ),
        ),
      ],
    );
  }

  Widget _rows(List<DashActivityItem> items) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Column(
      children: [
        for (var j = 0; j < items.length; j++) ...[
          if (j > 0) const Divider(),
          ActivityRow(activity: _planned(items[j]), onTap: () => _open(items[j])),
        ],
      ],
    ),
  );

  List<Widget> _calendarView(DashActivities a) {
    final byDay = {
      for (final d in a.days)
        if (d.date != null) d.date!: d,
    };
    final dayList = a.items.where((i) => i.date != null && _day(i.date!) == _selected).toList();
    return [
      AppCard(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: _weekIndex > 0 ? () => _moveWeek(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(_monthTitle(), textAlign: TextAlign.center, style: AppText.cardTitle),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: _weekIndex < LiveActivitiesScreen.weeks - 1 ? () => _moveWeek(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            WeekStrip(
              weekStart: _week,
              selected: _selected,
              today: _today,
              dotsFor: (day) {
                final d = byDay[_day(day)];
                return [
                  if ((d?.workOrders ?? 0) > 0) dashActivityLook(DashActivityType.workOrder).$3,
                  if ((d?.inspections ?? 0) > 0) dashActivityLook(DashActivityType.inspection).$3,
                  if ((d?.approvals ?? 0) > 0) dashActivityLook(DashActivityType.approval).$3,
                ];
              },
              onSelect: (d) => setState(() => _selected = d),
            ),
            const SizedBox(height: 10),
            SeriesLegend(items: [for (final t in DashActivityType.all) (dashActivityLabel(t), dashActivityLook(t).$3)]),
          ],
        ),
      ),
      const SizedBox(height: 16),
      ActivityDayHeader(day: _selected, today: _today, count: dayList.length),
      const SizedBox(height: 8),
      if (dayList.isEmpty)
        const EmptyState(
          icon: Icons.event_available_rounded,
          title: 'Nothing scheduled',
          message: 'No work orders, inspections or approvals on this day.',
        )
      else
        _rows(dayList),
    ];
  }

  List<Widget> _listView(DashActivities a) {
    final shown = a.items.where((i) => _type == null || i.type == _type).toList();
    final days = <DateTime, List<DashActivityItem>>{};
    for (final i in shown) {
      (days[_day(i.date ?? i.startUtc?.toLocal() ?? _today)] ??= []).add(i);
    }
    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (t, label) in [
              (null, 'All'),
              (DashActivityType.workOrder, 'Work Orders'),
              (DashActivityType.inspection, 'Inspections'),
              (DashActivityType.approval, 'Approvals'),
            ]) ...[
              PillChip(
                label: '$label (${a.items.where((i) => t == null || i.type == t).length})',
                selected: _type == t,
                onTap: () => setState(() => _type = t),
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
          title: a.items.isEmpty ? 'No upcoming activities' : 'Nothing scheduled',
          message: a.items.isEmpty
              ? 'No work orders, inspections or approvals between these dates.'
              : 'No activities of this type between these dates.',
          actionLabel: a.items.isEmpty ? null : 'Show all',
          onAction: a.items.isEmpty ? null : () => setState(() => _type = null),
        ),
      for (final e in days.entries) ...[
        ActivityDayHeader(day: e.key, today: _today, count: e.value.length),
        const SizedBox(height: 8),
        _rows(e.value),
        const SizedBox(height: 14),
      ],
    ];
  }
}
