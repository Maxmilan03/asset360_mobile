enum SyncKind { workOrder, inspection, asset, photo, document }

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

  /// A record completed on the device (not a photo or file attachment).
  bool get completedLocally => kind == SyncKind.workOrder || kind == SyncKind.inspection || kind == SyncKind.asset;
  bool get isAttachment => kind == SyncKind.photo || kind == SyncKind.document;

  SyncItem copyWith({String? status, double? progress, DateTime? syncedAt}) => SyncItem(
    id: id,
    kind: kind,
    title: title,
    subtitle: subtitle,
    savedAt: savedAt,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    syncedAt: syncedAt ?? this.syncedAt,
    refId: refId,
  );
}

class SyncState {
  const SyncState({
    required this.items,
    required this.syncedCount,
    required this.lastSync,
    required this.lastSyncCount,
    this.wifiAutoSync = true,
    this.mobileDataSync = false,
    this.offline = false,
  });

  /// Items waiting (or being) uploaded.
  final List<SyncItem> items;

  /// Local items already on the server.
  final int syncedCount;
  final DateTime lastSync;
  final int lastSyncCount;
  final bool wifiAutoSync;
  final bool mobileDataSync;

  /// App-wide offline mode (Prompt 18).
  final bool offline;

  List<SyncItem> get pending => items.where((i) => i.status != SyncStatus.synced).toList();
  int get localItems => syncedCount + pending.length;
  double get syncedFraction => localItems == 0 ? 1 : syncedCount / localItems;
  int get completedLocally => pending.where((i) => i.completedLocally).length;
  int get photosToSync => pending.where((i) => i.kind == SyncKind.photo).length;
  int get failed => items.where((i) => i.status == SyncStatus.failed).length;

  SyncState copyWith({
    List<SyncItem>? items,
    int? syncedCount,
    DateTime? lastSync,
    int? lastSyncCount,
    bool? wifiAutoSync,
    bool? mobileDataSync,
    bool? offline,
  }) {
    return SyncState(
      items: items ?? this.items,
      syncedCount: syncedCount ?? this.syncedCount,
      lastSync: lastSync ?? this.lastSync,
      lastSyncCount: lastSyncCount ?? this.lastSyncCount,
      wifiAutoSync: wifiAutoSync ?? this.wifiAutoSync,
      mobileDataSync: mobileDataSync ?? this.mobileDataSync,
      offline: offline ?? this.offline,
    );
  }
}
