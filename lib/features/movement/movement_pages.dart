import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/movement.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/movements_repository.dart';
import '../../data/repositories/session_repository.dart';
import 'movement_hub_screen.dart';
import 'movement_widgets.dart';

/// Request detail: the Review layout read-only, the status timeline and the actions allowed now.
class MovementRequestScreen extends ConsumerWidget {
  const MovementRequestScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(movementByIdProvider(id));
    final asset = m == null ? null : ref.watch(assetByIdProvider(m.assetId));
    if (m == null || asset == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Request not found', message: '$id does not exist.'),
      );
    }
    final me = ref.watch(currentUserProvider).id;
    final requester = ref.watch(personByIdProvider(m.requesterId));
    final approver = ref.watch(personByIdProvider(m.approverId));
    final notifier = ref.read(movementsProvider.notifier);
    final isApprover = m.status == MoveStatus.pending && m.approverId == me;
    final canCancel = m.status == MoveStatus.pending && m.requesterId == me;

    Future<void> cancel() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Cancel ${m.id}?',
        message: 'The transfer request is withdrawn and the approver is told.',
        confirmLabel: 'Cancel Request',
        cancelLabel: 'Keep',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      notifier.cancel(m.id);
      context.showSnack('${m.id} cancelled');
    }

    final actions = <Widget>[
      if (isApprover) ...[
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
            onPressed: () => rejectMovement(context, ref, m),
            child: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () {
              notifier.approve(m.id);
              context.showSnack('${m.id} approved');
            },
            child: const Text('Approve'),
          ),
        ),
      ] else if (canCancel)
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
            onPressed: cancel,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel Request'),
          ),
        )
      else if (m.status == MoveStatus.approved)
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              notifier.dispatch(m.id);
              context.showSnack('${m.id} is in transit');
            },
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Mark In Transit'),
          ),
        )
      else if (m.status == MoveStatus.inTransit)
        Expanded(
          child: FilledButton.icon(
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Mark as Received?',
                message: '${asset.id} arrived at ${m.to.name}. Its location and custodian are updated.',
                confirmLabel: 'Received',
              );
              if (!ok || !context.mounted) return;
              notifier.markReceived(m.id);
              context.showSnack('${m.id} completed – ${asset.id} received');
            },
            icon: const Icon(Icons.inventory_rounded),
            label: const Text('Mark as Received'),
          ),
        ),
    ];

    return AppScaffold(
      bottomActions: actions.isEmpty ? null : Row(children: actions),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          PageTitle(
            title: m.id,
            subtitle: '${m.type} · ${DemoClock.formatDateTime(m.createdAt)}',
            trailing: StatusChip(m.status),
          ),
          const SizedBox(height: 14),
          MovementSummary(request: m, asset: asset),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Status',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoveStatusTimeline(request: m),
                const Divider(),
                InfoRow(label: 'Requested by', value: requester?.labelWithRole ?? '—'),
                if (approver != null) InfoRow(label: 'Approver', value: approver.labelWithRole),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Movement History: every movement record as a timeline, newest first, filtered by type and date.
class MovementHistoryScreen extends ConsumerStatefulWidget {
  const MovementHistoryScreen({super.key});

  @override
  ConsumerState<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends ConsumerState<MovementHistoryScreen> {
  String? _type;
  DateTimeRange? _range;

  static const _types = [
    MoveType.transfer,
    MoveType.checkOut,
    MoveType.checkIn,
    MoveType.assign,
    MoveType.returnAsset,
    MoveType.auditCorrection,
  ];

  static IconData _icon(String type) => switch (type) {
    MoveType.checkOut => Icons.person_rounded,
    MoveType.checkIn => Icons.download_rounded,
    MoveType.assign => Icons.groups_rounded,
    MoveType.returnAsset => Icons.undo_rounded,
    MoveType.auditCorrection => Icons.fact_check_rounded,
    _ => Icons.swap_horiz_rounded,
  };

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      useRootNavigator: false,
      firstDate: DateTime(2026),
      lastDate: DemoClock.today,
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final records = [
      for (final m in [...ref.watch(movementsProvider)]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        if ((_type == null || m.type == _type) &&
            (_range == null ||
                (!m.createdAt.isBefore(_range!.start) &&
                    m.createdAt.isBefore(_range!.end.add(const Duration(days: 1))))))
          m,
    ];
    final byDay = <DateTime, List<MovementRequest>>{};
    for (final m in records) {
      byDay.putIfAbsent(DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day), () => []).add(m);
    }
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(title: 'Movement History', subtitle: '${records.length} movement records'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in [null, ..._types])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconFilterChip(
                      label: t ?? 'All',
                      selected: _type == t,
                      onTap: () => setState(() => _type = t),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    _range == null
                        ? 'All dates'
                        : '${DemoClock.formatShort(_range!.start)} – ${DemoClock.formatShort(_range!.end)}',
                  ),
                ),
              ),
              if (_range != null)
                IconButton(
                  tooltip: 'Clear dates',
                  onPressed: () => setState(() => _range = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final d in moveDateRanges.keys)
                ActionChip(
                  label: Text(d),
                  onPressed: () => setState(
                    () => _range = DateTimeRange(
                      start: DemoClock.today.subtract(
                        Duration(days: moveDateRanges[d] == 0 ? 0 : moveDateRanges[d]! - 1),
                      ),
                      end: DemoClock.today,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LoadingGate(
            rows: 5,
            card: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (records.isEmpty)
                  const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No movements',
                    message: 'Try another type or date.',
                  ),
                for (final e in byDay.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(DemoClock.formatLong(e.key), style: AppText.bodyStrong),
                  ),
                  for (final (i, m) in e.value.indexed)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              IconSquare(icon: _icon(m.type), tone: TileTone.lavender, size: 34),
                              if (i < e.value.length - 1)
                                Expanded(child: Container(width: 2, color: AppColors.divider)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => context.push(Routes.movementRequest(m.id)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${m.type} · ${m.assetId}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                                          ),
                                        ),
                                        StatusChip(m.status),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      m.from.name == m.to.name ? m.to.name : '${m.from.name} → ${m.to.name}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption.copyWith(color: AppColors.text),
                                    ),
                                    Text(
                                      [
                                        m.id,
                                        DemoClock.formatTime(m.createdAt),
                                        if (m.newCustodian != null) 'Custodian: ${m.newCustodian}',
                                      ].join(' · '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
