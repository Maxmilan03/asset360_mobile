import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/alert.dart';
import '../../data/models/common.dart';
import '../../data/repositories/alerts_repository.dart';
import '../../data/repositories/assets_repository.dart';
import '../assets/asset_ui.dart';
import '../maintenance/create_work_order_screen.dart';
import 'alert_widgets.dart';

enum AlertTab {
  details('Details'),
  history('History'),
  actions('Actions'),
  related('Related Assets');

  const AlertTab(this.label);
  final String label;
}

/// Alert Details (middle screen of design/11_alerts_notifications.jpg).
class AlertDetailScreen extends ConsumerStatefulWidget {
  const AlertDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends ConsumerState<AlertDetailScreen> {
  AlertTab _tab = AlertTab.details;

  /// Label of the reading row ("Battery Level", "Temperature" …).
  static String _readingLabel(String type) {
    final t = type.toLowerCase();
    if (t.contains('battery')) return 'Battery Level';
    if (t.contains('temperature')) return 'Temperature';
    if (t.contains('vibration')) return 'Vibration';
    if (t.contains('pressure')) return 'Pressure';
    return 'Reading';
  }

  Future<void> _acknowledge(AlertItem a) async {
    final note = await askAlertNote(context, title: 'Acknowledge ${a.type}?', action: 'Acknowledge');
    if (note == null || !mounted) return;
    ref.read(alertsProvider.notifier).acknowledge(a.id, note: note.isEmpty ? null : note);
    context.showSnack('Alert acknowledged');
  }

  Future<void> _resolve(AlertItem a) async {
    final note = await askAlertNote(context, title: 'Resolve ${a.type}?', action: 'Resolve');
    if (note == null || !mounted) return;
    ref.read(alertsProvider.notifier).resolve(a.id, note: note.isEmpty ? null : note);
    context.showSnack('Alert resolved');
  }

  void _createWorkOrder(AlertItem a) => context.push(
    Routes.createWorkOrder(assetId: a.assetId),
    extra: WoPrefill(
      title: a.type,
      description: 'Raised from alert ${a.id}: ${a.description.isEmpty ? a.message : a.description}',
      priority: a.severity,
      alertId: a.id,
      workType: 'Corrective',
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final a = ref.watch(alertByIdProvider(widget.id));
    if (a == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Alert not found', message: widget.id),
      );
    }
    final asset = ref.watch(assetByIdProvider(a.assetId));
    final tone = severityTone(a.severity);
    return AppScaffold(
      bottomActions: Row(
        children: [
          if (!a.isResolved) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: a.requiresAction ? () => _acknowledge(a) : () => _resolve(a),
                icon: Icon(a.requiresAction ? Icons.near_me_rounded : Icons.task_alt_rounded, size: 18),
                label: Text(a.requiresAction ? 'Acknowledge' : 'Resolve'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: a.workOrderId == null
                ? FilledButton.icon(
                    onPressed: () => _createWorkOrder(a),
                    icon: const Icon(Icons.build_rounded, size: 18),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Create Work Order')),
                  )
                : FilledButton.icon(
                    onPressed: () => context.push(Routes.workOrder(a.workOrderId!)),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(a.workOrderId!),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const PageTitle(title: 'Alert Details'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(alertIcon(a.type), color: tone.foreground, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.type, style: AppText.cardTitle.copyWith(color: tone.foreground)),
                      const SizedBox(height: 2),
                      Text(a.message, style: AppText.body.copyWith(fontSize: 12.5)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(a.severity, tone: tone),
                    const SizedBox(height: 6),
                    StatusChip(
                      AlertStatus.label(a.status),
                      tone: a.isResolved ? ChipTone.green : (a.requiresAction ? ChipTone.red : ChipTone.blue),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (asset != null)
            AppCard(
              onTap: () => context.push(Routes.assetDetail(asset.id)),
              child: Row(
                children: [
                  AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 84),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                asset.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.cardTitle,
                              ),
                            ),
                            Flexible(child: StatusChip(asset.status)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        InfoRow(label: 'Type', value: asset.name, labelWidth: 68),
                        InfoRow(label: 'Location', value: asset.location, labelWidth: 68),
                        InfoRow(label: 'Category', value: asset.category, labelWidth: 68),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SegmentTabs(
            tabs: [for (final t in AlertTab.values) SegmentTab(t.label)],
            selected: _tab.index,
            onChanged: (i) => setState(() => _tab = AlertTab.values[i]),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            AlertTab.details => _details(a),
            AlertTab.history => LoadingGate(key: const ValueKey('history'), rows: 3, child: _history(a)),
            AlertTab.actions => _actions(a),
            AlertTab.related => LoadingGate(key: const ValueKey('related'), rows: 3, child: _related(a)),
          },
        ],
      ),
    );
  }

  Widget _details(AlertItem a) {
    final tone = severityTone(a.severity);
    final start = DateTime(a.at.year, a.at.month, a.at.day);
    String hour(double x) => DateFormat('h a').format(start.add(Duration(minutes: (x * 60).round())));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              InfoRow(label: 'Alert Type', value: a.type),
              InfoRow(
                label: 'Severity',
                value: a.severity,
                valueWidget: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(a.severity, tone: tone),
                ),
              ),
              InfoRow(label: 'Asset ID', value: a.assetId),
              InfoRow(label: 'Alert Time', value: DemoClock.formatDateTime(a.at)),
              if (a.value != null) InfoRow(label: _readingLabel(a.type), value: a.value!, valueColor: AppColors.red),
              if (a.threshold != null) InfoRow(label: 'Threshold', value: a.threshold!),
              InfoRow(label: 'Current Location', value: a.location),
              InfoRow(label: 'Reported By', value: a.reportedBy),
              InfoRow(label: 'Description', value: a.description.isEmpty ? a.message : a.description),
            ],
          ),
        ),
        if (a.trend.length > 1) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(a.trendLabel ?? 'Trend', style: AppText.bodyStrong)),
                    if (a.value != null) StatusChip('${a.value} · ${DemoClock.formatTime(a.at)}', tone: ChipTone.red),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: TrendChart(
                    points: a.trend,
                    unit: a.value?.replaceAll(RegExp(r'[0-9.\s]'), '') ?? '',
                    xLabel: hour,
                    tooltipTime: (x) => DateFormat('hh:mm a').format(start.add(Duration(minutes: (x * 60).round()))),
                    xInterval: 3,
                    minY: a.type.toLowerCase().contains('battery') ? 0 : null,
                    maxY: a.type.toLowerCase().contains('battery') ? 100 : null,
                    color: AppColors.red,
                    highlightLast: true,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '12 AM → ${DemoClock.formatTime(a.at)} (alert time)',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _history(AlertItem a) {
    final earlier = ref.watch(alertsProvider).earlierOf(a);
    if (earlier.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.history_rounded,
          title: 'First occurrence',
          message: 'No earlier alerts like this.',
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final e in earlier)
            ListTile(
              leading: AlertIconSquare(alert: e, size: 36),
              title: Text(e.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body),
              subtitle: Text(
                '${DemoClock.formatDateTime(e.at)} · ${AlertStatus.label(e.status)}',
                style: AppText.caption,
              ),
              onTap: () => context.push(Routes.alertDetail(e.id)),
            ),
        ],
      ),
    );
  }

  Widget _actions(AlertItem a) {
    final log = [LogEntry(at: a.at, title: 'Raised', by: a.reportedBy), ...a.history].reversed.toList();
    return AppCard(
      child: Column(
        children: [
          for (final e in log)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (e.title) {
                'Acknowledged' => Icons.near_me_rounded,
                'Resolved' => Icons.task_alt_rounded,
                'Raised' => Icons.notifications_active_rounded,
                _ => Icons.build_rounded,
              }, color: AppColors.primary),
              title: Text(e.title, style: AppText.bodyStrong),
              subtitle: Text([DemoClock.formatDateTime(e.at), ?e.by, ?e.note].join(' · '), style: AppText.caption),
            ),
        ],
      ),
    );
  }

  Widget _related(AlertItem a) {
    final related = ref.watch(alertsProvider).relatedTo(a);
    if (related.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.verified_outlined,
          title: 'No other active alerts',
          message: 'Nothing else in ${a.location} needs attention.',
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [for (final r in related) AlertRow(alert: r, onTap: () => context.push(Routes.alertDetail(r.id)))],
      ),
    );
  }
}
