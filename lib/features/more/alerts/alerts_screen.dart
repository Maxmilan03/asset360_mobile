import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/features/more/alerts/alert_widgets.dart';

/// How often a simulated live alert arrives while Alerts is open.
const liveAlertEvery = Duration(seconds: 60);

/// Alerts & Notifications (left screen of design/11_alerts_notifications.jpg).
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key, this.initialTab});

  /// all, critical, high, medium or low.
  final String? initialTab;

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  static const _tabs = ['all', 'critical', 'high', 'medium', 'low'];
  late int _tab = _index(widget.initialTab);
  String _query = '';
  FilterSelection _filters = const {};
  final _search = TextEditingController();
  final _selected = <String>{};
  bool _selecting = false;
  Timer? _live;
  Timer? _bannerTimer;
  ScaffoldMessengerState? _messenger;

  static int _index(String? t) => _tabs.contains(t?.toLowerCase()) ? _tabs.indexOf(t!.toLowerCase()) : 0;

  static const _dates = {'Today': 1, 'Last 7 days': 7};

  @override
  void initState() {
    super.initState();
    _live = Timer.periodic(liveAlertEvery, (_) => _onLive());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void didUpdateWidget(AlertsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) _tab = _index(widget.initialTab);
  }

  @override
  void dispose() {
    _live?.cancel();
    _bannerTimer?.cancel();
    _messenger?.hideCurrentMaterialBanner();
    _search.dispose();
    super.dispose();
  }

  /// A new live alert: in-app banner at the top (the bell badge goes up with its notification).
  void _onLive() {
    if (!mounted || !TickerMode.of(context)) return; // only while Alerts is on screen
    final a = ref.read(alertsProvider.notifier).raiseLive();
    final messenger = _messenger;
    if (messenger == null) return;
    final tone = severityTone(a.severity);
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: tone.background,
          leading: Icon(alertIcon(a.type), color: tone.foreground),
          content: Text(
            'New ${a.severity.toLowerCase()} alert: ${a.type} · ${a.assetId}',
            style: AppText.bodyStrong.copyWith(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => messenger.hideCurrentMaterialBanner(), child: const Text('Dismiss')),
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                context.push(Routes.alertDetail(a.id));
              },
              child: const Text('View'),
            ),
          ],
        ),
      );
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 8), () => messenger.hideCurrentMaterialBanner());
  }

  Future<bool> _acknowledge(AlertItem a) async {
    if (!a.requiresAction) {
      context.showSnack('${a.id} is already ${AlertStatus.label(a.status).toLowerCase()}');
      return false;
    }
    ref.read(alertsProvider.notifier).acknowledge(a.id);
    context.showSnack('${a.type} on ${a.assetId} acknowledged');
    return false;
  }

  void _bulk(bool resolve) {
    final n = ref.read(alertsProvider.notifier);
    final alerts = ref.read(alertsProvider).where((a) => _selected.contains(a.id) && !a.isResolved).toList();
    for (final a in alerts) {
      resolve ? n.resolve(a.id, note: 'Bulk resolve') : (a.requiresAction ? n.acknowledge(a.id) : null);
    }
    context.showSnack(
      '${alerts.length} alert${alerts.length == 1 ? '' : 's'} ${resolve ? 'resolved' : 'acknowledged'}',
    );
    setState(() {
      _selected.clear();
      _selecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(alertsProvider).latest;
    final counts = {for (final s in Severity.all) s: all.withSeverity(s).length};
    final base = _tab == 0 ? all : all.withSeverity(Severity.all[_tab - 1]);
    final types = {for (final a in all) a.type}.toList()..sort();
    final rows = base
        .search(_query)
        .where(
          (a) =>
              (_filters['Type']?.contains(a.type) ?? true) &&
              (_filters['Status']?.contains(AlertStatus.label(a.status)) ?? true) &&
              (_filters['Date']?.every((d) => DemoClock.now.difference(a.at).inDays < _dates[d]!) ?? true),
        )
        .toList();
    final tiles = [
      (Severity.critical, Icons.warning_rounded, TileTone.pink),
      (Severity.high, Icons.error_rounded, TileTone.peach),
      (Severity.medium, Icons.notifications_rounded, TileTone(AppColors.amberBg, AppColors.amber)),
      (Severity.low, Icons.check_circle_rounded, TileTone.mint),
    ];
    return AppScaffold(
      bottomActions: !_selecting
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${_selected.length} selected', style: AppText.bodyStrong)),
                    TextButton(
                      onPressed: () => setState(() {
                        _selecting = false;
                        _selected.clear();
                      }),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selected.isEmpty ? null : () => _bulk(false),
                        child: const Text('Acknowledge'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _selected.isEmpty ? null : () => _bulk(true),
                        child: const Text('Resolve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: LazyListPage(
        padding: _selecting ? const EdgeInsets.fromLTRB(16, 16, 16, 24) : null,
        header: [
          PageTitle(
            title: 'Alerts & Notifications',
            subtitle: 'Stay updated with real-time asset events and actions',
            trailing: IconButton(
              tooltip: 'Open Notifications',
              onPressed: () => context.push(Routes.notificationsFrom(GoRouterState.of(context).uri.path)),
              icon: Icon(Icons.notifications_none_rounded, color: AppColors.text),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (n, (sev, icon, tone)) in tiles.indexed) ...[
                if (n > 0) const SizedBox(width: 8),
                Expanded(
                  child: KpiTile(
                    icon: icon,
                    value: '${counts[sev]}',
                    label: sev,
                    tone: TileTone(tone.background, severityTone(sev).foreground),
                    onTap: () => setState(() => _tab = n + 1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SegmentTabs(
            tabs: [
              SegmentTab('All', count: all.length),
              for (final s in Severity.all) SegmentTab(s, count: counts[s]),
            ],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search alerts by asset, type or location...',
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            filterGroups: [
              FilterGroup(title: 'Type', options: types),
              FilterGroup(title: 'Status', options: [for (final s in AlertStatus.all) AlertStatus.label(s)]),
              FilterGroup(title: 'Date', options: _dates.keys.toList(), multiSelect: false),
            ],
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 6),
          Text(
            _selecting ? 'Tap alerts to select them' : 'Swipe left to acknowledge · long-press to select several',
            style: AppText.caption,
          ),
          const SizedBox(height: 8),
        ],
        list: SliverLoadingGate(
          rows: 5,
          sliver: rows.isEmpty
              ? SliverToBoxAdapter(
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.notifications_off_outlined,
                      title: 'No alerts',
                      message: _query.isEmpty && _filters.isEmpty
                          ? 'Nothing at this severity right now.'
                          : 'No alerts match your search or filters.',
                      actionLabel: _query.isEmpty && _filters.isEmpty ? null : 'Clear filters',
                      onAction: () => setState(() {
                        _search.clear();
                        _query = '';
                        _filters = const {};
                      }),
                    ),
                  ),
                )
              : SliverCardList(itemCount: rows.length, indent: 120, itemBuilder: (_, n) => _row(rows[n])),
        ),
      ),
    );
  }

  Widget _row(AlertItem a) {
    void toggle() => setState(() => _selected.contains(a.id) ? _selected.remove(a.id) : _selected.add(a.id));
    final row = AlertRow(
      alert: a,
      selecting: _selecting,
      selected: _selected.contains(a.id),
      onTap: _selecting ? toggle : () => context.push(Routes.alertDetail(a.id)),
      onLongPress: () => setState(() {
        _selecting = true;
        _selected.add(a.id);
      }),
    );
    if (_selecting) return row;
    return Dismissible(
      key: ValueKey('ack-${a.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.primary,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Acknowledge',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.done_all_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (_) => _acknowledge(a),
      child: row,
    );
  }
}
