import '../models/sync_item.dart';
import 'seed_utils.dart';

/// 8 pending items (times from design/16_offline_sync.jpg); 25 already synced → 33 local items.
SyncState seedSyncState() => SyncState(
  syncedCount: 25,
  lastSync: sep(22, 16, 18),
  lastSyncCount: 25,
  wifiAutoSync: true,
  mobileDataSync: false,
  items: [
    SyncItem(
      id: 'SYN-01',
      kind: SyncKind.workOrder,
      title: 'WO-2026-0142',
      subtitle: 'Preventive Maintenance',
      savedAt: sep(22, 15, 12),
      refId: 'WO-2026-0142',
    ),
    SyncItem(
      id: 'SYN-02',
      kind: SyncKind.inspection,
      title: 'INS-2026-0051',
      subtitle: 'Safety Inspection',
      savedAt: sep(22, 14, 45),
      refId: 'INS-2026-0051',
    ),
    SyncItem(
      id: 'SYN-03',
      kind: SyncKind.asset,
      title: 'GEN-00045',
      subtitle: 'Asset Location Update',
      savedAt: sep(22, 13, 30),
      refId: 'GEN-00045',
    ),
    SyncItem(
      id: 'SYN-04',
      kind: SyncKind.photo,
      title: 'Site_Photo_01.jpg',
      subtitle: 'Inspection Photos',
      savedAt: sep(22, 13, 15),
      refId: 'INS-2026-0051',
    ),
    SyncItem(
      id: 'SYN-05',
      kind: SyncKind.photo,
      title: 'Site_Photo_02.jpg',
      subtitle: 'Work Order Attachment',
      savedAt: sep(22, 13, 15),
      refId: 'WO-2026-0142',
    ),
    SyncItem(
      id: 'SYN-06',
      kind: SyncKind.workOrder,
      title: 'WO-2026-0141',
      subtitle: 'Breakdown Maintenance',
      savedAt: sep(22, 12, 10),
      refId: 'WO-2026-0141',
    ),
    SyncItem(
      id: 'SYN-07',
      kind: SyncKind.inspection,
      title: 'INS-2026-0050',
      subtitle: 'Quality Inspection',
      savedAt: sep(22, 11, 5),
      refId: 'INS-2026-0050',
    ),
    SyncItem(
      id: 'SYN-08',
      kind: SyncKind.document,
      title: 'Asset_Document.pdf',
      subtitle: 'Warranty Document',
      savedAt: sep(22, 10, 32),
      refId: 'GEN-00045',
    ),
  ],
);
