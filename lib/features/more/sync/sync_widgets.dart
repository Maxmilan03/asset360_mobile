import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';

/// Icon and tone per queued change.
({IconData icon, TileTone tone}) syncKindLook(SyncKind k) => switch (k) {
  SyncKind.workOrder => (icon: Icons.build_rounded, tone: TileTone.peach),
  SyncKind.inspection => (icon: Icons.assignment_rounded, tone: TileTone.sky),
  SyncKind.asset => (icon: Icons.view_in_ar_rounded, tone: TileTone.lavender),
  SyncKind.issue => (icon: Icons.report_problem_rounded, tone: TileTone.pink),
  SyncKind.photo => (icon: Icons.image_rounded, tone: TileTone.sky),
  SyncKind.document => (icon: Icons.picture_as_pdf_rounded, tone: TileTone.pink),
  SyncKind.other => (icon: Icons.sync_alt_rounded, tone: TileTone.cyan),
};

/// "22 Sep 2026 03:12 PM".
String syncTime(DateTime d) => DemoClock.formatDateTime(d);

/// The real record behind a queued change (View Item), or null when it no longer exists.
String? syncItemRoute(WidgetRef ref, SyncItem item) {
  if (item.route != null) return item.route;
  final id = item.refId;
  if (id == null) return null;
  if (id.startsWith('WO-')) return Routes.workOrder(id);
  if (id.startsWith('INS-')) return Routes.inspectionDetail(id);
  if (id.startsWith('ISS-')) return Routes.issueDetail(id);
  if (id.startsWith('DOC-')) return Routes.documentDetail(id);
  if (id.startsWith('MO-')) return Routes.productionOrder(id);
  if (id.startsWith('AUD-')) return Routes.auditSession(id);
  if (ref.read(partByIdProvider(id)) != null) return Routes.partDetail(id);
  if (ref.read(assetByIdProvider(id)) != null) return Routes.assetDetail(id);
  return null;
}

void openSyncItem(BuildContext context, WidgetRef ref, SyncItem item) {
  final route = syncItemRoute(ref, item);
  if (route == null) {
    context.showSnack('${item.title} is no longer on this device');
    return;
  }
  context.push(route);
}

/// Sync Now / Sync All / Sync This Item. Offline → "No internet connection" with "Try anyway (demo)".
Future<void> startSync(BuildContext context, WidgetRef ref, {List<String>? ids}) async {
  final sync = ref.read(syncProvider);
  if (sync.running) {
    context.push(Routes.syncProgress);
    return;
  }
  if (sync.pending.isEmpty) {
    context.showSnack('Everything is synced');
    return;
  }
  if (ref.read(isOfflineProvider)) {
    final ok = await showConfirmDialog(
      context,
      title: 'No internet connection',
      message: 'Your changes are safe on this device and sync automatically when you are back online.',
      confirmLabel: 'Try anyway (demo)',
    );
    if (!ok || !context.mounted) return;
  }
  if (ref.read(syncProvider.notifier).startRun(ids: ids)) {
    context.push(Routes.syncProgress);
  } else {
    context.showSnack('Nothing to sync');
  }
}

/// Sync Status → chevron: earlier sync runs.
Future<void> showSyncHistory(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final runs = ref.watch(syncProvider).history;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SheetTitle('Sync History', subtitle: '${runs.length} sync runs'),
              if (runs.isEmpty)
                const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No sync runs yet',
                  message: 'Each sync appears here with how many items it uploaded.',
                ),
              for (final r in runs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconSquare(
                    icon: r.cancelled
                        ? Icons.cancel_outlined
                        : r.failed > 0
                        ? Icons.sync_problem_rounded
                        : Icons.cloud_done_rounded,
                    tone: r.cancelled
                        ? TileTone.grey
                        : r.failed > 0
                        ? TileTone.pink
                        : TileTone.mint,
                    size: 40,
                  ),
                  title: Text(syncTime(r.at), style: AppText.bodyStrong),
                  subtitle: Text(
                    [
                      'Synced ${r.synced} of ${r.total}',
                      if (r.failed > 0) '${r.failed} failed',
                      if (r.cancelled) 'cancelled',
                    ].join(' · '),
                    style: AppText.caption,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Pending Sync row: icon square, reference, subtitle, time, chip, ⋮.
class SyncItemRow extends ConsumerWidget {
  const SyncItemRow({super.key, required this.item});

  final SyncItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = syncKindLook(item.kind);
    final failed = item.status == SyncStatus.failed;
    return InkWell(
      onTap: () => openSyncItem(context, ref, item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
        child: Row(
          children: [
            IconSquare(icon: look.icon, tone: look.tone, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong,
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusChip(
                        failed ? 'Failed' : item.status,
                        tone: failed
                            ? ChipTone.red
                            : item.status == SyncStatus.syncing
                            ? ChipTone.blue
                            : ChipTone.orange,
                      ),
                    ],
                  ),
                  Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  Text(syncTime(item.savedAt), style: AppText.caption),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Item actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) async {
                switch (v) {
                  case 'view':
                    openSyncItem(context, ref, item);
                  case 'sync':
                    await startSync(context, ref, ids: [item.id]);
                  case 'discard':
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Discard ${item.title}?',
                      message: 'It is removed from the sync queue and will not be uploaded.',
                      confirmLabel: 'Discard',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    ref.read(syncProvider.notifier).remove(item.id);
                    context.showSnack('${item.title} discarded');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Text('View Item')),
                const PopupMenuItem(value: 'sync', child: Text('Sync This Item')),
                if (item.status != SyncStatus.syncing) const PopupMenuItem(value: 'discard', child: Text('Discard')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
