import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/features/more/sync/sync_widgets.dart';

/// Syncing Data (right screen of design/16_offline_sync.jpg). The run itself lives in
/// `SyncNotifier`, so it keeps going if the user leaves this screen.
class SyncingScreen extends ConsumerWidget {
  const SyncingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncProvider);
    final n = ref.read(syncProvider.notifier);
    final run = s.run;
    if (run == null) {
      return AppScaffold(
        body: ListView(
          padding: context.pagePadding,
          children: [
            const PageTitle(title: 'Syncing Data', subtitle: 'Please keep the app open while syncing'),
            const SizedBox(height: 24),
            EmptyState(
              icon: Icons.cloud_done_outlined,
              title: 'Nothing is syncing',
              message: s.pending.isEmpty
                  ? 'Everything is on the server.'
                  : '${s.pending.length} items are waiting to be synced.',
              actionLabel: s.pending.isEmpty ? null : 'Sync All (${s.pending.length})',
              onAction: s.pending.isEmpty ? null : () => startSync(context, ref),
            ),
          ],
        ),
      );
    }
    final items = [for (final id in run.ids) ?s.item(id)];
    final total = items.length;
    final synced = items.where((i) => i.status == SyncStatus.synced).length;
    final failed = items.where((i) => i.status == SyncStatus.failed).length;
    final current = items.where((i) => i.status == SyncStatus.syncing).firstOrNull;
    final overall = total == 0 ? 0.0 : (synced + (current?.progress ?? 0)) / total;
    final finished = !run.running;
    final (title, subtitle) = !finished
        ? (
            run.cancelRequested ? 'Stopping…' : 'Syncing…',
            run.cancelRequested ? 'Finishing the current item' : 'Uploading data to server',
          )
        : run.cancelled
        ? ('Sync cancelled', '$synced synced · the rest stay pending')
        : failed > 0
        ? ('Sync finished with errors', '$failed item${failed == 1 ? '' : 's'} failed – tap Retry')
        : ('All items synced', 'Your offline changes are on the server');
    final ringColor = finished && failed > 0
        ? AppColors.red
        : finished && !run.cancelled
        ? AppColors.green
        : AppColors.primary;

    return AppScaffold(
      bottomActions: finished
          ? Row(
              children: [
                if (failed > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        for (final i in items.where((i) => i.status == SyncStatus.failed)) {
                          n.retry(i.id);
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Failed'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      n.dismissRun();
                      context.go(Routes.offlineSync);
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            )
          : OutlinedButton.icon(
              onPressed: run.cancelRequested ? null : n.cancelRun,
              icon: const Icon(Icons.close_rounded),
              label: Text(run.cancelRequested ? 'Stopping after this item…' : 'Cancel Sync'),
            ),
      body: LazyListPage(
        header: [
          const PageTitle(title: 'Syncing Data', subtitle: 'Please keep the app open while syncing'),
          const SizedBox(height: 16),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: finished && !run.cancelled && failed == 0 ? 1 : overall),
              duration: const Duration(milliseconds: 300),
              builder: (context, v, _) => ProgressRing(
                value: v,
                size: 128,
                strokeWidth: 10,
                color: ringColor,
                trackColor: AppColors.tileLavender,
                center: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.tileLavender,
                  child: Icon(
                    finished && !run.cancelled && failed == 0
                        ? Icons.cloud_done_rounded
                        : finished && failed > 0
                        ? Icons.sync_problem_rounded
                        : Icons.cloud_upload_rounded,
                    color: ringColor,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.sectionTitle),
          Text(subtitle, textAlign: TextAlign.center, style: AppText.secondary),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(overall * 100).floor()}%',
                style: AppText.kpiNumber.copyWith(color: AppColors.primary, fontSize: 22),
              ),
              const Spacer(),
              Text('$synced of $total items synced', style: AppText.secondary),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(value: overall, minHeight: 8, backgroundColor: AppColors.divider),
          ),
          const SizedBox(height: 12),
        ],
        // Live progress of a run, not a fetched list: no loading skeleton.
        list: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => _RunRow(item: items[i], cancelled: run.cancelled),
        ),
      ),
    );
  }
}

class _RunRow extends ConsumerWidget {
  const _RunRow({required this.item, required this.cancelled});

  final SyncItem item;
  final bool cancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = syncKindLook(item.kind);
    final (sub, trailing) = switch (item.status) {
      SyncStatus.synced => (
        item.subtitle,
        _State(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
          label: 'Synced',
          detail: item.syncedAt == null ? null : DemoClock.formatTime(item.syncedAt!),
          color: AppColors.green,
        ),
      ),
      SyncStatus.syncing => (
        'Uploading...',
        _State(
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              value: item.progress,
              strokeWidth: 2.5,
              backgroundColor: AppColors.tileLavender,
            ),
          ),
          label: '${(item.progress * 100).round()}%',
          color: AppColors.primary,
        ),
      ),
      SyncStatus.failed => (
        'Upload failed',
        _State(
          icon: const Icon(Icons.error_rounded, color: AppColors.red, size: 20),
          label: 'Failed',
          color: AppColors.red,
          action: TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => ref.read(syncProvider.notifier).retry(item.id),
            child: const Text('Retry'),
          ),
        ),
      ),
      _ => (
        cancelled ? 'Not synced' : 'Pending...',
        _State(
          icon: Icon(Icons.schedule_rounded, color: AppColors.textSecondary, size: 20),
          label: cancelled ? 'Pending' : 'Waiting',
          color: AppColors.textSecondary,
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconSquare(icon: look.icon, tone: look.tone, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _State extends StatelessWidget {
  const _State({required this.icon, required this.label, required this.color, this.detail, this.action});

  final Widget icon;
  final String label;
  final String? detail;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 6),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          if (detail != null) Text(detail!, style: AppText.caption),
        ],
      ),
      ?action,
    ],
  );
}
