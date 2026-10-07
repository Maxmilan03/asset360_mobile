import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/work/maintenance/maintenance_hub_screen.dart';
import 'package:asset360_mobile/features/work/maintenance/wo_widgets.dart';

/// Preventive Maintenance: PM schedules with "Generate WO now".
class PmSchedulesScreen extends ConsumerWidget {
  const PmSchedulesScreen({super.key});

  Future<void> _generate(BuildContext context, WidgetRef ref, PmSchedule pm) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Generate work order?',
      message: 'A preventive work order for ${pm.assetId} – ${pm.title} is created now and the next due date moves on.',
      confirmLabel: 'Generate WO',
    );
    if (!ok || !context.mounted) return;
    final id = ref.read(pmSchedulesProvider.notifier).generateWorkOrder(pm.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          margin: context.snackMargin,
          content: Text('$id created'),
          action: SnackBarAction(label: 'View', onPressed: () => context.push(Routes.workOrder(id))),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = [...ref.watch(pmSchedulesProvider)]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    return AppScaffold(
      body: LazyListPage(
        padding: context.pagePadding,
        header: [
          PageTitle(title: 'Preventive Maintenance', subtitle: '${schedules.length} PM schedules'),
          const SizedBox(height: 12),
        ],
        list: GatedSliverList(
          inCard: false,
          itemCount: schedules.length,
          empty: const EmptyState(icon: Icons.event_repeat_rounded, title: 'No PM schedules'),
          itemBuilder: (context, n) {
            final pm = schedules[n];
            final asset = ref.watch(assetByIdProvider(pm.assetId));
            final overdue = DemoClock.isOverdue(pm.nextDue);
            return AppCard(
              onTap: () => context.push(Routes.assetDetail(pm.assetId)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      AssetThumb(
                        imagePath: asset?.imagePath,
                        fallbackIcon: asset == null ? Icons.build_outlined : assetIcon(asset),
                        size: 52,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pm.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                            Text(
                              '${pm.assetId} · ${asset?.name ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(pm.frequency, tone: ChipTone.purple),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InfoRow(
                    label: 'Next due',
                    value: '${DemoClock.formatDate(pm.nextDue)}${overdue ? ' (overdue)' : ''}',
                    valueColor: overdue ? AppColors.red : null,
                    labelWidth: 80,
                  ),
                  InfoRow(label: 'Last done', value: DemoClock.formatDate(pm.lastDone), labelWidth: 80),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _generate(context, ref, pm),
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Generate WO now'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Breakdown Requests (type Breakdown) and Service History (completed / closed) share this list.
class WoListScreen extends ConsumerStatefulWidget {
  const WoListScreen.breakdowns({super.key}) : history = false;
  const WoListScreen.history({super.key}) : history = true;

  final bool history;

  @override
  ConsumerState<WoListScreen> createState() => _WoListScreenState();
}

class _WoListScreenState extends ConsumerState<WoListScreen> {
  String _query = '';

  /// Breakdowns: Active / All. History: All / Corrective / Preventive.
  String _chip = 'All';
  String _period = 'All time';

  static const _periods = {'Last 7 days': 7, 'Last 30 days': 30, 'All time': 0};

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(workOrdersProvider);
    final base = widget.history ? all.serviceHistory : all.breakdowns;
    final chips = widget.history ? const ['All', 'Corrective', 'Preventive'] : const ['Active', 'All'];
    final days = _periods[_period]!;
    final rows = searchWorkOrders(base, _query, ref).where((w) {
      final chipOk = switch (_chip) {
        'Active' => w.isActive,
        'Corrective' => !w.isPreventive,
        'Preventive' => w.isPreventive,
        _ => true,
      };
      final at = w.completedAt ?? w.dueAt;
      final periodOk = !widget.history || days == 0 || DemoClock.now.difference(at).inDays < days;
      return chipOk && periodOk;
    }).toList()..sort((a, b) => (b.completedAt ?? b.openedAt).compareTo(a.completedAt ?? a.openedAt));
    return AppScaffold(
      body: LazyListPage(
        padding: context.pagePadding,
        header: [
          PageTitle(
            title: widget.history ? 'Service History' : 'Breakdown Requests',
            subtitle: widget.history
                ? '${base.length} completed and closed work orders'
                : '${base.where((w) => w.isActive).length} open breakdowns · ${base.length} in total',
          ),
          const SizedBox(height: 12),
          SearchFilterBar(hint: 'Search by WO No., Asset, Location...', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in chips)
                IconFilterChip(label: c, selected: _chip == c, onTap: () => setState(() => _chip = c)),
              if (widget.history)
                for (final p in _periods.keys)
                  IconFilterChip(
                    label: p,
                    icon: Icons.date_range_rounded,
                    selected: _period == p,
                    onTap: () => setState(() => _period = p),
                  ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        list: GatedSliverList(
          itemCount: rows.length,
          empty: const EmptyState(
            icon: Icons.build_outlined,
            title: 'No work orders',
            message: 'Nothing matches this search and filter.',
          ),
          itemBuilder: (_, i) {
            final w = rows[i];
            if (!widget.history || w.completedAt == null) return WoRow(wo: w);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WoRow(wo: w),
                Padding(
                  padding: const EdgeInsets.fromLTRB(90, 0, 14, 10),
                  child: Text(
                    [
                      'Closed ${DemoClock.formatDateTime(w.completedAt!)}',
                      if (w.labourHours != null) '${w.labourHours} h labour',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
