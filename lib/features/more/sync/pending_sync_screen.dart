import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/features/more/sync/sync_widgets.dart';

/// Pending Sync (middle screen of design/16_offline_sync.jpg).
class PendingSyncScreen extends ConsumerStatefulWidget {
  const PendingSyncScreen({super.key, this.initialTab});

  /// A `SyncKind` name, or null for All.
  final String? initialTab;

  @override
  ConsumerState<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends ConsumerState<PendingSyncScreen> {
  /// Always shown (design); Issues / Other appear when they have items.
  static const _fixed = [SyncKind.workOrder, SyncKind.inspection, SyncKind.asset, SyncKind.photo, SyncKind.document];
  late SyncKind? _kind = SyncKind.values.where((k) => k.name == widget.initialTab).firstOrNull;

  @override
  void didUpdateWidget(PendingSyncScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) {
      _kind = SyncKind.values.where((k) => k.name == widget.initialTab).firstOrNull;
    }
  }

  Future<void> _clearAll(int n) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear all pending items?',
      message:
          '$n local change${n == 1 ? '' : 's'} will be removed from the queue and never reach the server. '
          'Other users will not see them. This cannot be undone.',
      confirmLabel: 'Clear All',
      destructive: true,
    );
    if (!ok || !mounted) return;
    ref.read(syncProvider.notifier).clearAll();
    context.showSnack('Sync queue cleared');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(syncProvider);
    final kinds = [
      for (final k in SyncKind.values)
        if (_fixed.contains(k) || s.pendingOf(k).isNotEmpty || k == _kind) k,
    ];
    final rows = _kind == null ? s.pending : s.pendingOf(_kind!);
    final all = s.pending.length;
    return AppScaffold(
      bottomActions: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: all == 0 || s.running ? null : () => _clearAll(all),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Clear All'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: all == 0 ? null : () => startSync(context, ref),
              icon: const Icon(Icons.cloud_upload_rounded),
              label: Text(s.running ? 'Syncing…' : 'Sync All ($all)'),
            ),
          ),
        ],
      ),
      body: LazyListPage(
        header: [
          const PageTitle(title: 'Pending Sync', subtitle: 'Items saved offline and waiting to be synced'),
          const SizedBox(height: 8),
          SegmentTabs(
            tabs: [
              SegmentTab('All', count: all),
              for (final k in kinds) SegmentTab(k.label, count: s.pendingOf(k).length),
            ],
            selected: _kind == null ? 0 : kinds.indexOf(_kind!) + 1,
            onChanged: (i) => setState(() => _kind = i == 0 ? null : kinds[i - 1]),
          ),
          const SizedBox(height: 8),
        ],
        list: SliverLoadingGate(
          rows: 5,
          card: false,
          sliver: rows.isEmpty
              ? SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.cloud_done_outlined,
                    title: 'Nothing waiting',
                    message: 'Changes made offline appear here until they are synced.',
                    actionLabel: _kind == null || all == 0 ? null : 'Show all ($all)',
                    onAction: () => setState(() => _kind = null),
                  ),
                )
              : SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                  itemBuilder: (_, i) => SyncItemRow(item: rows[i]),
                ),
        ),
        footer: [
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${rows.length} item${rows.length == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }
}
