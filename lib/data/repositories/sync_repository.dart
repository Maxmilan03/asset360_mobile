import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/sync_mock.dart';
import '../models/sync_item.dart';
import 'inspections_repository.dart';
import 'maintenance_repository.dart';
import 'repo_utils.dart';

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => seedSyncState();

  void _update(String id, SyncItem Function(SyncItem) f) =>
      state = state.copyWith(items: replaceWhere(state.items, id, (i) => i.id, f));

  void setWifiAutoSync(bool v) => state = state.copyWith(wifiAutoSync: v);
  void setMobileDataSync(bool v) => state = state.copyWith(mobileDataSync: v);
  void setOffline(bool v) => state = state.copyWith(offline: v);

  /// Adds a change made while offline to the queue.
  void enqueue({required SyncKind kind, required String title, required String subtitle, String? refId}) {
    state = state.copyWith(
      items: [
        SyncItem(
          id: nextId('SYN-', state.items.map((i) => i.id), width: 2),
          kind: kind,
          title: title,
          subtitle: subtitle,
          savedAt: DemoClock.now,
          refId: refId,
        ),
        ...state.items,
      ],
    );
  }

  void remove(String id) => state = state.copyWith(items: state.items.where((i) => i.id != id).toList());
  void clearAll() => state = state.copyWith(items: state.items.where((i) => i.status == SyncStatus.synced).toList());

  void setProgress(String id, double progress) =>
      _update(id, (i) => i.copyWith(status: SyncStatus.syncing, progress: progress));

  void markFailed(String id) => _update(id, (i) => i.copyWith(status: SyncStatus.failed, progress: 0));

  void markSynced(String id) {
    final item = state.items.firstWhereOrNull((i) => i.id == id);
    if (item == null || item.status == SyncStatus.synced) return;
    _update(id, (i) => i.copyWith(status: SyncStatus.synced, progress: 1, syncedAt: DemoClock.now));
    state = state.copyWith(syncedCount: state.syncedCount + 1);
    final ref0 = item.refId;
    if (ref0 != null && item.kind == SyncKind.workOrder) ref.read(workOrdersProvider.notifier).markSynced(ref0);
    if (ref0 != null && item.kind == SyncKind.inspection) ref.read(inspectionsProvider.notifier).markSynced(ref0);
  }

  /// End of a sync run: synced items leave the queue and Last Sync is updated.
  void finishRun(int syncedInRun) => state = state.copyWith(
    items: state.items.where((i) => i.status != SyncStatus.synced).toList(),
    lastSync: DemoClock.now,
    lastSyncCount: syncedInRun,
  );

  /// Cancel Sync: items still uploading go back to pending.
  void cancelRun() => state = state.copyWith(
    items: [
      for (final i in state.items)
        i.status == SyncStatus.syncing ? i.copyWith(status: SyncStatus.pending, progress: 0) : i,
    ],
  );
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
