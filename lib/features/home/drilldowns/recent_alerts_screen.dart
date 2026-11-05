import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';

const _type = 'Type';
const _asset = 'Asset';
const _date = 'Date';
const _dates = ['Any time', 'Today', 'Last 7 days', 'Last 30 days'];

/// Recent Alerts tabs. Warning = High + Medium, Info = Low.
enum _Tab {
  all('All', Severity.all),
  critical('Critical', [Severity.critical]),
  warning('Warning', [Severity.high, Severity.medium]),
  info('Info', [Severity.low]);

  const _Tab(this.label, this.severities);

  final String label;
  final List<String> severities;
}

(IconData, TileTone) _severityLook(String s) => switch (s) {
  Severity.critical => (Icons.warning_rounded, TileTone.pink),
  Severity.high || Severity.medium => (Icons.warning_rounded, TileTone.peach),
  _ => (Icons.info_rounded, TileTone.sky),
};

ChipTone _severityTone(String s) => switch (s) {
  Severity.critical => ChipTone.red,
  Severity.high => ChipTone.orange,
  Severity.medium => ChipTone.amber,
  _ => ChipTone.blue,
};

/// Home "Recent Alerts" drill-down: every alert at the Home site, newest first, by severity tab.
class RecentAlertsScreen extends ConsumerStatefulWidget {
  const RecentAlertsScreen({super.key});

  @override
  ConsumerState<RecentAlertsScreen> createState() => _RecentAlertsScreenState();
}

class _RecentAlertsScreenState extends ConsumerState<RecentAlertsScreen> {
  _Tab _tab = _Tab.all;
  FilterSelection _filters = {};

  bool _matches(AlertItem a) {
    bool ok(String group, String value) => _filters[group]?.contains(value) ?? true;
    final days = DemoClock.today.difference(DateTime(a.at.year, a.at.month, a.at.day)).inDays;
    final dateOk = switch (_filters[_date]?.firstOrNull) {
      'Today' => days == 0,
      'Last 7 days' => days < 7,
      'Last 30 days' => days < 30,
      _ => true,
    };
    return ok(_type, a.type) && ok(_asset, a.assetId) && dateOk;
  }

  Future<void> _openFilters(List<AlertItem> siteAlerts) async {
    final result = await showFilterSheet(
      context,
      groups: [
        FilterGroup(title: _type, options: {...siteAlerts.map((a) => a.type)}.toList()..sort()),
        FilterGroup(title: _asset, options: {...siteAlerts.map((a) => a.assetId)}.toList()..sort()),
        const FilterGroup(title: _date, options: _dates, multiSelect: false),
      ],
      selection: _filters,
    );
    if (result != null) setState(() => _filters = result);
  }

  void _remove(String group, String value) => setState(() {
    final next = {
      for (final e in _filters.entries) e.key: {...e.value},
    };
    next[group]!.remove(value);
    if (next[group]!.isEmpty) next.remove(group);
    _filters = next;
  });

  @override
  Widget build(BuildContext context) {
    if (apiMode) return const NotAvailableDrilldown(title: 'Recent Alerts', feature: 'Alerts');
    ref.watch(clockTickProvider); // "5 mins ago" moves with the clock
    final site = ref.watch(sessionProvider.select((s) => s.site));
    final byId = {for (final a in ref.watch(assetsProvider)) a.id: a};
    final siteAlerts = [
      for (final a in ref.watch(alertsProvider))
        if (site == 'All Sites' || byId[a.assetId]?.site == site) a,
    ]..sort((a, b) => b.at.compareTo(a.at));
    final filtered = siteAlerts.where(_matches).toList();
    List<AlertItem> inTab(_Tab t) => filtered.where((a) => t.severities.contains(a.severity)).toList();
    final shown = inTab(_tab);
    final active = [
      for (final e in _filters.entries)
        for (final v in e.value)
          if (!(e.key == _date && v == _dates.first)) (e.key, v),
    ];

    return DrilldownPage(
      title: 'Recent Alerts',
      subtitle: site == 'All Sites' ? 'All sites' : site,
      skeletonRows: 6,
      trailing: IconButton(
        tooltip: 'Filter alerts',
        onPressed: () => _openFilters(siteAlerts),
        icon: Badge(
          isLabelVisible: active.isNotEmpty,
          label: Text('${active.length}'),
          child: Icon(Icons.filter_alt_outlined, color: AppColors.primary),
        ),
      ),
      sliver: shown.isEmpty
          ? SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'No alerts',
                message: active.isEmpty ? 'Nothing in this tab.' : 'Try another filter.',
                actionLabel: active.isEmpty ? null : 'Clear filters',
                onAction: active.isEmpty ? null : () => setState(() => _filters = {}),
              ),
            )
          : SliverCardList(
              itemCount: shown.length,
              indent: 62,
              itemBuilder: (_, i) => _AlertRow(alert: shown[i], assetName: byId[shown[i].assetId]?.name),
            ),
      footer: [
        if (shown.isNotEmpty) ShowingFooter(text: 'Showing ${shown.length} ${shown.length == 1 ? 'alert' : 'alerts'}'),
      ],
      children: [
        SegmentTabs(
          tabs: [for (final t in _Tab.values) SegmentTab(t.label, count: inTab(t).length)],
          selected: _tab.index,
          onChanged: (i) => setState(() => _tab = _Tab.values[i]),
        ),
        if (active.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (group, value) in active)
                InputChip(
                  label: Text(value),
                  labelStyle: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                  backgroundColor: AppColors.primarySoft,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  deleteIconColor: AppColors.primary,
                  tooltip: group,
                  onDeleted: () => _remove(group, value),
                  onPressed: () => _openFilters(siteAlerts),
                ),
              ActionChip(
                label: const Text('Clear all'),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _filters = {}),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, this.assetName});

  final AlertItem alert;
  final String? assetName;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = _severityLook(alert.severity);
    return InkWell(
      onTap: () => context.push(Routes.alertDetail(alert.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconSquare(icon: icon, tone: tone, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${alert.assetId} – ${assetName ?? alert.type}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: AppColors.textSecondary),
                      Text(DemoClock.timeAgo(alert.at), style: AppText.caption.copyWith(fontSize: 11.5)),
                      if (alert.status != AlertStatus.newAlert) ...[
                        Text(
                          '· ${AlertStatus.label(alert.status)}',
                          style: AppText.caption.copyWith(
                            fontSize: 11.5,
                            color: alert.status == AlertStatus.resolved ? AppColors.green : AppColors.amber,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(alert.severity, tone: _severityTone(alert.severity)),
          ],
        ),
      ),
    );
  }
}
