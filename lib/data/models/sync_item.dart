/// What a queued change is. The Pending Sync tabs and Pending Items groups follow this.
enum SyncKind {
  workOrder('Work Orders'),
  inspection('Inspections'),
  asset('Assets'),
  issue('Issues'),
  photo('Photos'),
  document('Documents'),
  other('Other');

  const SyncKind(this.label);
  final String label;
}

abstract final class SyncStatus {
  static const pending = 'Pending Sync';
  static const syncing = 'Syncing';
  static const synced = 'Synced';
  static const failed = 'Failed';
}

class SyncItem {
  const SyncItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.savedAt,
    this.status = SyncStatus.pending,
    this.progress = 0,
    this.syncedAt,
    this.refId,
    this.route,
  });

  final String id;
  final SyncKind kind;

  /// "WO-2026-0142", "Site_Photo_01.jpg".
  final String title;

  /// "Preventive Maintenance", "Inspection Photos".
  final String subtitle;
  final DateTime savedAt;
  final String status;

  /// 0–1 while uploading.
  final double progress;
  final DateTime? syncedAt;

  /// The record this change belongs to (WO, inspection or asset ID).
  final String? refId;

  /// Where "View Item" goes (the real record); null = derived from [kind] and [refId].
  final String? route;

  /// A record completed on the device (not a photo or file attachment).
  bool get completedLocally => !isAttachment;
  bool get isAttachment => kind == SyncKind.photo || kind == SyncKind.document;

  /// Changes to the same record collapse into one queue item (attachments stay separate).
  String get key => '${kind.name}|${refId ?? title}|${isAttachment ? title : ''}';

  SyncItem copyWith({String? status, double? progress, DateTime? syncedAt, String? subtitle, DateTime? savedAt}) =>
      SyncItem(
        id: id,
        kind: kind,
        title: title,
        subtitle: subtitle ?? this.subtitle,
        savedAt: savedAt ?? this.savedAt,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        syncedAt: syncedAt ?? this.syncedAt,
        refId: refId,
        route: route,
      );
}

/// One sync run (Sync Status → history).
class SyncRun {
  const SyncRun({required this.at, required this.total, required this.synced, this.failed = 0, this.cancelled = false});

  final DateTime at;
  final int total;
  final int synced;
  final int failed;
  final bool cancelled;
}

/// The run shown on Syncing Data: its items in order and how it ended.
class ActiveRun {
  const ActiveRun({
    required this.ids,
    required this.startedAt,
    this.running = true,
    this.cancelRequested = false,
    this.cancelled = false,
  });

  final List<String> ids;
  final DateTime startedAt;
  final bool running;

  /// Cancel Sync was tapped: stop after the current item.
  final bool cancelRequested;
  final bool cancelled;

  ActiveRun copyWith({List<String>? ids, bool? running, bool? cancelRequested, bool? cancelled}) => ActiveRun(
    ids: ids ?? this.ids,
    startedAt: startedAt,
    running: running ?? this.running,
    cancelRequested: cancelRequested ?? this.cancelRequested,
    cancelled: cancelled ?? this.cancelled,
  );
}

class SyncState {
  const SyncState({
    required this.items,
    required this.syncedCount,
    required this.lastSync,
    required this.lastSyncCount,
    this.autoSync = true,
    this.wifiAutoSync = true,
    this.mobileDataSync = false,
    this.simulateFailures = false,
    this.history = const [],
    this.run,
  });

  /// The queue. Synced items stay (status Synced) until the run is dismissed, so Syncing Data can list them.
  final List<SyncItem> items;

  /// Local items already on the server.
  final int syncedCount;
  final DateTime lastSync;
  final int lastSyncCount;
  final bool autoSync;
  final bool wifiAutoSync;
  final bool mobileDataSync;

  /// Developer: each item has a 10% chance to fail.
  final bool simulateFailures;
  final List<SyncRun> history;
  final ActiveRun? run;

  bool get running => run?.running ?? false;

  /// Not on the server yet (pending, uploading or failed).
  List<SyncItem> get pending => items.where((i) => i.status != SyncStatus.synced).toList();
  List<SyncItem> pendingOf(SyncKind k) => pending.where((i) => i.kind == k).toList();
  int get localItems => syncedCount + pending.length;
  double get syncedFraction => localItems == 0 ? 1 : syncedCount / localItems;
  int get completedLocally => pending.where((i) => i.completedLocally).length;
  int get photosToSync => pending.where((i) => i.kind == SyncKind.photo).length;
  int get syncingNow => items.where((i) => i.status == SyncStatus.syncing).length;
  int get failed => items.where((i) => i.status == SyncStatus.failed).length;

  SyncItem? item(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  SyncState copyWith({
    List<SyncItem>? items,
    int? syncedCount,
    DateTime? lastSync,
    int? lastSyncCount,
    bool? autoSync,
    bool? wifiAutoSync,
    bool? mobileDataSync,
    bool? simulateFailures,
    List<SyncRun>? history,
    ActiveRun? run,
    bool clearRun = false,
  }) {
    return SyncState(
      items: items ?? this.items,
      syncedCount: syncedCount ?? this.syncedCount,
      lastSync: lastSync ?? this.lastSync,
      lastSyncCount: lastSyncCount ?? this.lastSyncCount,
      autoSync: autoSync ?? this.autoSync,
      wifiAutoSync: wifiAutoSync ?? this.wifiAutoSync,
      mobileDataSync: mobileDataSync ?? this.mobileDataSync,
      simulateFailures: simulateFailures ?? this.simulateFailures,
      history: history ?? this.history,
      run: clearRun ? null : run ?? this.run,
    );
  }
}
