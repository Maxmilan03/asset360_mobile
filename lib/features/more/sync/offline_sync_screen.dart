import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/features/more/sync/sync_widgets.dart';

/// Offline Sync (left screen of design/16_offline_sync.jpg).
class OfflineSyncScreen extends ConsumerWidget {
  const OfflineSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final net = ref.watch(networkProvider);
    final s = ref.watch(syncProvider);
    final n = ref.read(syncProvider.notifier);
    final offline = !net.online;
    final waiting = s.pending.length - s.failed;
    final groups = [
      (SyncKind.workOrder, 'Work Orders', s.pendingOf(SyncKind.workOrder).length, [SyncKind.workOrder]),
      (SyncKind.inspection, 'Inspections', s.pendingOf(SyncKind.inspection).length, [SyncKind.inspection]),
      (SyncKind.asset, 'Asset Updates', s.pendingOf(SyncKind.asset).length, [SyncKind.asset]),
      (
        SyncKind.photo,
        'Photos & Attachments',
        s.pendingOf(SyncKind.photo).length + s.pendingOf(SyncKind.document).length,
        [SyncKind.photo, SyncKind.document],
      ),
      (SyncKind.issue, 'Issues', s.pendingOf(SyncKind.issue).length, [SyncKind.issue]),
      (SyncKind.other, 'Other Changes', s.pendingOf(SyncKind.other).length, [SyncKind.other]),
    ].where((g) => g.$3 > 0 || g.$1.index < SyncKind.issue.index).toList();

    Widget tile(IconData icon, int value, String label, TileTone tone, VoidCallback onTap) => Expanded(
      child: KpiTile(icon: icon, value: '$value', label: label, tone: tone, onTap: onTap),
    );

    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Offline Sync',
            subtitle: 'Work offline and sync your data when connected',
            help:
                'While offline every change is saved on this device and queued here. Pending Sync = changes not '
                'on the server yet; Completed Locally = records (not photos or files) among them. The ring is '
                'synced ÷ all local items. Sync starts by itself when you are back online and Automatic Sync '
                'allows the connection (Wi-Fi or mobile data).',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: offline ? AppColors.tileLavender : AppColors.greenBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: offline ? AppColors.primary : AppColors.green,
                  child: Icon(
                    offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offline ? "You're Offline" : "You're Online", style: AppText.sectionTitle),
                      const SizedBox(height: 2),
                      Text(
                        offline
                            ? 'Data will be saved locally on this device and synced automatically when internet '
                                  'is available.'
                            : 'Connected via ${net.type == NetType.mobile ? 'mobile data' : 'Wi-Fi'}. '
                                  '${n.autoSyncAllowed(net.type) ? 'Changes sync automatically.' : 'Automatic sync is off for this connection – use Sync Now.'}',
                        style: AppText.secondary.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              tile(
                Icons.description_rounded,
                s.pending.length,
                'Pending Sync',
                TileTone.mint,
                () => context.push(Routes.pendingSync),
              ),
              const SizedBox(width: 8),
              tile(
                Icons.assignment_turned_in_rounded,
                s.completedLocally,
                'Completed Locally',
                TileTone.lavender,
                () => context.push(Routes.pendingSync),
              ),
              const SizedBox(width: 8),
              tile(
                Icons.photo_camera_rounded,
                s.photosToSync,
                'Photos to Sync',
                TileTone.peach,
                () => context.push(Routes.pendingSyncTab(SyncKind.photo.name)),
              ),
              const SizedBox(width: 8),
              tile(Icons.cloud_upload_rounded, s.syncingNow, 'Syncing Now', TileTone.sky, () {
                if (s.run != null) {
                  context.push(Routes.syncProgress);
                } else {
                  context.showSnack('Nothing is syncing right now');
                }
              }),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => showSyncHistory(context, ref),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Sync Status', style: AppText.sectionTitle)),
                    Tooltip(
                      message: 'Sync history',
                      child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ProgressRing.segments(
                      size: 92,
                      strokeWidth: 10,
                      segments: [
                        RingSegment(s.syncedCount.toDouble(), AppColors.green),
                        RingSegment(waiting.toDouble(), AppColors.blue),
                        RingSegment(s.failed.toDouble(), AppColors.red),
                      ],
                      center: Text('${(s.syncedFraction * 100).round()}%', style: AppText.sectionTitle),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Local Data', style: AppText.bodyStrong),
                          Text('${s.syncedCount} of ${s.localItems} items synced', style: AppText.secondary),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _Legend(color: AppColors.green, label: 'Synced', value: s.syncedCount),
                              _Legend(color: AppColors.blue, label: 'Pending', value: waiting),
                              _Legend(color: AppColors.red, label: 'Failed', value: s.failed),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  dense: true,
                  title: Text('Automatic Sync', style: AppText.sectionTitle),
                  value: s.autoSync,
                  onChanged: n.setAutoSync,
                ),
                SwitchListTile(
                  dense: true,
                  secondary: const Icon(Icons.wifi_rounded, size: 20),
                  title: Text('Sync when connected to Wi-Fi', style: AppText.body),
                  value: s.wifiAutoSync,
                  onChanged: s.autoSync ? n.setWifiAutoSync : null,
                ),
                SwitchListTile(
                  dense: true,
                  secondary: const Icon(Icons.signal_cellular_alt_rounded, size: 20),
                  title: Text('Sync when connected to Mobile Data', style: AppText.body),
                  value: s.mobileDataSync,
                  onChanged: s.autoSync ? n.setMobileDataSync : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.text),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last Sync', style: AppText.bodyStrong),
                      Text(syncTime(s.lastSync), style: AppText.secondary),
                      Text(
                        offline ? 'No internet connection' : 'Synced ${s.lastSyncCount} items successfully',
                        style: AppText.caption.copyWith(color: offline ? AppColors.red : null),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => startSync(context, ref),
                  icon: Icon(s.running ? Icons.cloud_upload_rounded : Icons.sync_rounded, size: 18),
                  label: Text(s.running ? 'Syncing…' : 'Sync Now'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Pending Items (${s.pending.length})',
            actionLabel: 'View All',
            onAction: () => context.push(Routes.pendingSync),
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Column(
              children: [
                for (final (kind, label, count, kinds) in groups)
                  ListTile(
                    dense: true,
                    leading: IconSquare(icon: syncKindLook(kind).icon, tone: syncKindLook(kind).tone, size: 34),
                    title: Text(label, style: AppText.bodyStrong),
                    subtitle: Text('$count item${count == 1 ? '' : 's'}', style: AppText.caption),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.amberBg,
                          child: Text(
                            '$count',
                            style: const TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                    onTap: () => context.push(
                      Routes.pendingSyncTab(
                        (kinds.firstWhere((k) => s.pendingOf(k).isNotEmpty, orElse: () => kinds.first)).name,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: AppColors.text),
              ),
            ),
          ],
        ),
        Text('$value items', style: AppText.caption),
      ],
    ),
  );
}
