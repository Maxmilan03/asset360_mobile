import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/sync_mock.dart';
import '../models/sync_item.dart';
import 'inspections_repository.dart';
import 'maintenance_repository.dart';
import 'network_repository.dart';
import 'repo_utils.dart';

/// The sync queue and the upload engine. A run uploads its items one at a time
/// (0.6–1.0 s each, photos and files 1.2–1.5 s); it keeps going while the user
/// leaves Syncing Data, and starts by itself when the app comes back online.
class SyncNotifier extends Notifier<SyncState> {
  static const _tick = Duration(milliseconds: 50);
  Timer? _timer;
  Random _random = Random(18);
  int _runSynced = 0;
  int _runFailed = 0;

  @override
  SyncState build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(networkProvider, (prev, next) {
      if (prev != null && !prev.online && next.online && autoSyncAllowed(next.type) && state.pending.isNotEmpty) {
        startRun();
      }
    });
    return seedSyncState();
  }

  /// Tests: fixed failure rolls.
  set debugRandom(Random r) => _random = r;

  bool autoSyncAllowed(NetType t) =>
      state.autoSync && ((t == NetType.wifi && state.wifiAutoSync) || (t == NetType.mobile && state.mobileDataSync));

  void _update(String id, SyncItem Function(SyncItem) f) =>
      state = state.copyWith(items: replaceWhere(state.items, id, (i) => i.id, f));

  void setAutoSync(bool v) => state = state.copyWith(autoSync: v);
  void setWifiAutoSync(bool v) => state = state.copyWith(wifiAutoSync: v);
  void setMobileDataSync(bool v) => state = state.copyWith(mobileDataSync: v);
  void setSimulateFailures(bool v) => state = state.copyWith(simulateFailures: v);

  /// Adds a change made while offline to the queue. A newer change to the same record
  /// replaces its waiting item (moved to the top); photos and files are always separate.
  void enqueue({
    required SyncKind kind,
    required String title,
    required String subtitle,
    String? refId,
    String? route,
  }) {
    final item = SyncItem(
      id: nextId('SYN-', state.items.map((i) => i.id), width: 2),
      kind: kind,
      title: title,
      subtitle: subtitle,
      savedAt: DemoClock.now,
      refId: refId,
      route: route,
    );
    final same = state.items.firstWhereOrNull((i) => i.key == item.key && i.status == SyncStatus.pending);
    state = state.copyWith(
      items: [
        same == null ? item : same.copyWith(subtitle: subtitle, savedAt: DemoClock.now),
        ...state.items.where((i) => i.id != same?.id),
      ],
    );
  }

  /// Discard: the change is dropped from the queue (it stays applied on this device).
  void remove(String id) {
    if (state.item(id)?.status == SyncStatus.syncing) return;
    state = state.copyWith(items: state.items.where((i) => i.id != id).toList());
  }

  /// Clear All: drops every waiting item (not while a sync is running).
  void clearAll() {
    if (state.running) return;
    state = state.copyWith(items: state.items.where((i) => i.status == SyncStatus.synced).toList(), clearRun: true);
  }

  /// Starts a run with [ids] (default: everything pending). False when nothing to do or already running.
  bool startRun({List<String>? ids}) {
    if (state.running) return false;
    final keep = state.items.where((i) => i.status != SyncStatus.synced).toList();
    final targets = ids ?? [for (final i in keep) i.id];
    final runIds = targets.where((id) => keep.any((i) => i.id == id)).toList();
    if (runIds.isEmpty) return false;
    state = state.copyWith(
      items: [
        for (final i in keep)
          runIds.contains(i.id) && i.status == SyncStatus.failed ? i.copyWith(status: SyncStatus.pending) : i,
      ],
      run: ActiveRun(ids: runIds, startedAt: DemoClock.now),
    );
    _runSynced = 0;
    _runFailed = 0;
    _next();
    return true;
  }

  /// Retry a failed item: joins the running sync, or restarts the finished one with it.
  void retry(String id) {
    if (state.item(id)?.status != SyncStatus.failed) return;
    _update(id, (i) => i.copyWith(status: SyncStatus.pending, progress: 0));
    final run = state.run;
    if (run != null && run.running) {
      if (!run.ids.contains(id)) state = state.copyWith(run: run.copyWith(ids: [...run.ids, id]));
      return;
    }
    state = state.copyWith(
      run: run == null || !run.ids.contains(id)
          ? ActiveRun(ids: [id], startedAt: DemoClock.now)
          : run.copyWith(running: true, cancelRequested: false, cancelled: false),
    );
    _runSynced = 0;
    _runFailed = 0;
    _next();
  }

  /// Cancel Sync: the item being uploaded finishes, the rest stay pending.
  void cancelRun() {
    final run = state.run;
    if (run == null || !run.running) return;
    state = state.copyWith(run: run.copyWith(cancelRequested: true));
  }

  /// Done on Syncing Data: synced items leave the list.
  void dismissRun() {
    if (state.running) return;
    state = state.copyWith(items: state.items.where((i) => i.status != SyncStatus.synced).toList(), clearRun: true);
  }

  void _next() {
    _timer?.cancel();
    final run = state.run;
    if (run == null || !run.running) return;
    final id = run.cancelRequested
        ? null
        : run.ids.firstWhereOrNull((x) => state.item(x)?.status == SyncStatus.pending);
    if (id == null) {
      _finish(cancelled: run.cancelRequested && run.ids.any((x) => state.item(x)?.status == SyncStatus.pending));
      return;
    }
    final item = state.item(id)!;
    final ms = item.isAttachment ? 1200 + _random.nextInt(301) : 600 + _random.nextInt(401);
    final failAt = state.simulateFailures && _random.nextDouble() < .1 ? .3 + _random.nextDouble() * .5 : null;
    var p = 0.0;
    _update(id, (i) => i.copyWith(status: SyncStatus.syncing, progress: 0));
    _timer = Timer.periodic(_tick, (t) {
      p = (p + _tick.inMilliseconds / ms).clamp(0, 1).toDouble();
      if (failAt != null && p >= failAt) {
        t.cancel();
        _update(id, (i) => i.copyWith(status: SyncStatus.failed, progress: 0));
        _runFailed++;
        _next();
      } else if (p >= 1) {
        t.cancel();
        markSynced(id);
        _runSynced++;
        _next();
      } else {
        _update(id, (i) => i.copyWith(progress: p));
      }
    });
  }

  void _finish({required bool cancelled}) {
    final run = state.run!;
    state = state.copyWith(
      run: run.copyWith(running: false, cancelled: cancelled, cancelRequested: false),
      lastSync: _runSynced > 0 ? DemoClock.now : null,
      lastSyncCount: _runSynced > 0 ? _runSynced : null,
      history: [
        SyncRun(
          at: DemoClock.now,
          total:
              _runSynced +
              _runFailed +
              (cancelled ? run.ids.where((x) => state.item(x)?.status == SyncStatus.pending).length : 0),
          synced: _runSynced,
          failed: _runFailed,
          cancelled: cancelled,
        ),
        ...state.history,
      ],
    );
  }

  void markSynced(String id) {
    final item = state.item(id);
    if (item == null || item.status == SyncStatus.synced) return;
    _update(id, (i) => i.copyWith(status: SyncStatus.synced, progress: 1, syncedAt: DemoClock.now));
    state = state.copyWith(syncedCount: state.syncedCount + 1);
    final ref0 = item.refId;
    final others = state.items.any(
      (i) => i.refId == ref0 && i.status != SyncStatus.synced && (i.kind == item.kind || i.isAttachment),
    );
    if (ref0 != null && !others && item.kind == SyncKind.workOrder) {
      ref.read(workOrdersProvider.notifier).markSynced(ref0);
    }
    if (ref0 != null && !others && item.kind == SyncKind.inspection) {
      ref.read(inspectionsProvider.notifier).markSynced(ref0);
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Every module calls this after a create / update: while offline the change (already applied
/// on the device) also goes into the sync queue.
extension OfflineQueue on Ref {
  bool queueOffline(SyncKind kind, String title, String subtitle, {String? refId, String? route}) {
    if (read(networkProvider).online) return false;
    read(syncProvider.notifier).enqueue(kind: kind, title: title, subtitle: subtitle, refId: refId, route: route);
    return true;
  }
}

/// "Site_Photo_01.jpg" from a file path.
String syncFileName(String path) => path.split(RegExp(r'[/\\]')).last;
