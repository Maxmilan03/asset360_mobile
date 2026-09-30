import 'package:flutter_riverpod/misc.dart';

import '../core/demo_clock.dart';
import 'mock/inventory_mock.dart';
import 'models/alert.dart';
import 'models/asset.dart';
import 'models/audit.dart';
import 'models/issue.dart';
import 'models/sync_item.dart';
import 'repositories/alerts_repository.dart';
import 'repositories/assets_repository.dart';
import 'repositories/audits_repository.dart';
import 'repositories/documents_repository.dart';
import 'repositories/inspections_repository.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/issues_repository.dart';
import 'repositories/maintenance_repository.dart';
import 'repositories/movements_repository.dart';
import 'repositories/scans_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/sync_repository.dart';
import 'repositories/tracking_repository.dart';
import 'repositories/wip_repository.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// One line of the Data check. [expected] null = informational count.
class DataCheck {
  const DataCheck(this.label, this.actual, {this.expected, bool? ok})
    : ok = ok ?? (expected == null || expected == actual);

  final String label;
  final String actual;
  final String? expected;
  final bool ok;
}

class DataCheckGroup {
  const DataCheckGroup(this.title, this.checks);

  final String title;
  final List<DataCheck> checks;

  int get failures => checks.where((c) => !c.ok).length;
}

DataCheck _eq(String label, num actual, num expected) => DataCheck(label, '$actual', expected: '$expected');
DataCheck _info(String label, Object actual) => DataCheck(label, '$actual');
DataCheck _rule(String label, bool ok, String detail) => DataCheck(label, detail, ok: ok);

/// Every count used by the screens, computed from the repositories, plus the
/// rules that must always hold ("All = sum of the tabs", balances add up …).
///
/// "Expected" values are the seed figures from Prompt 02; they are checked at
/// DemoClock start (25 Sep 2026 10:30 AM) and will change as the demo is used.
List<DataCheckGroup> runDataChecks(Reader read) {
  final wasFrozen = DemoClock.frozen;
  DemoClock.frozen = true;
  try {
    return _run(read);
  } finally {
    DemoClock.frozen = wasFrozen;
  }
}

List<DataCheckGroup> _run(Reader read) {
  final me = read(currentUserProvider).id;
  final assets = read(assetsProvider);
  final org = read(orgSummaryProvider);
  final tracking = read(trackingProvider);
  final wos = read(workOrdersProvider);
  final inspections = read(inspectionsProvider);
  final issues = read(issuesProvider);
  final alerts = read(alertsProvider);
  final notifications = read(notificationsProvider);
  final inventory = read(inventoryProvider);
  final moves = read(movementsProvider);
  final wip = read(wipProvider);
  final docs = read(documentsProvider);
  final audits = read(auditsProvider);
  final sync = read(syncProvider);
  final scans = read(scanHistoryProvider);
  final people = read(peopleProvider);

  final assetIds = assets.map((a) => a.id).toSet();
  final peopleIds = people.map((p) => p.id).toSet();

  // ---- Assets
  final statusSum = AssetStatus.summary.fold<int>(0, (int s, k) => s + (org.statusCounts[k] ?? 0));
  final cnc = assets.firstWhere((a) => a.id == 'CNC-00123');
  final assetGroup = DataCheckGroup('Assets', [
    _eq('Detailed asset records', assets.length, 21),
    _eq('Org total assets', org.totalAssets, 12458),
    _rule(
      'Org total = Active + Under Maint. + Inactive + Retired + Disposed',
      statusSum == org.totalAssets,
      '$statusSum = ${org.totalAssets}',
    ),
    for (final s in AssetStatus.summary)
      _info('  $s', '${org.statusCounts[s]} (${org.statusPct(s).toStringAsFixed(0)}%)'),
    _eq('Asset health %', org.health, 87),
    _eq('Total cost (AED)', org.totalCost, 1250000),
    _info('Favorites', assets.favorites.length),
    _info('Nearby (Main Plant)', assets.nearby.length),
    _info('With IoT device', assets.where((a) => a.hasIot).length),
    _eq('CNC-00123 health score', cnc.healthScore, 87),
    _info('CNC-00123 age (years)', DemoClock.yearsSince(cnc.purchaseDate).toStringAsFixed(1)),
    _eq('CNC-00123 warranty days left', DemoClock.daysUntil(cnc.warrantyExpiry), 156),
    _info('Showing', 'Showing ${assets.length} of ${org.totalAssets}'),
  ]);

  // ---- Tracking
  final ts = tracking.summary;
  final fl012 = tracking.vehicle('FL-012')!;
  final trackingGroup = DataCheckGroup('Tracking & IoT', [
    _eq('Tracked (People + Equipment + Vehicles)', ts.tracked, 178),
    _rule(
      'Online + Offline = Tracked',
      ts.online + ts.offline == ts.tracked,
      '${ts.online} + ${ts.offline} = ${ts.tracked}',
    ),
    _eq('People', ts.people, 24),
    _eq('Equipment', ts.equipment, 142),
    _eq('Vehicles', ts.vehicles, 12),
    _eq('Low battery', ts.lowBattery, 8),
    _eq('Alerts', ts.alerts, 6),
    _eq('FL-012 battery %', fl012.batteryPct, 78),
    _rule('FL-012 load status', fl012.loadStatus == 'Loaded', fl012.loadStatus),
    _eq('FL-015 battery %', tracking.vehicle('FL-015')!.batteryPct, 18),
  ]);

  // ---- Maintenance
  final wo45 = wos.firstWhere((w) => w.id == 'WO-2026-0045');
  final t2 = wo45.tasks[1];
  final maintGroup = DataCheckGroup('Maintenance', [
    _eq('My Work Orders', wos.mine(me).length, 8),
    _eq('PM Due', wos.pmDue.length, 12),
    _eq('Overdue', wos.overdue.length, 3),
    _info('All', wos.length),
    _info('Assigned directly to me', wos.assignedTo(me).length),
    _info('Breakdown requests', wos.breakdowns.length),
    _info('Service history (completed/closed)', wos.serviceHistory.length),
    _info('Saved offline', wos.where((w) => w.savedOffline).length),
    _rule('WO-2026-0045 time left', DemoClock.timeLeft(wo45.dueAt) == '1h 20m', DemoClock.dueLabel(wo45.dueAt)),
    _eq('WO-2026-0045 tasks done (of 6)', wo45.tasksDone, 1),
    _eq('WO-2026-0045 checklist done (of 6)', t2.checklistDone, 4),
    _rule(
      'WO-2026-0045 Close disabled until all tasks done',
      !wo45.allTasksDone,
      '${wo45.tasksDone} / ${wo45.tasks.length}',
    ),
  ]);

  // ---- Inspections
  final ins45 = inspections.firstWhere((i) => i.id == 'INS-2026-0045');
  final inspGroup = DataCheckGroup('Inspections', [
    _info('My Inspections', inspections.mine(me).length),
    _info('Due (next 7 days)', inspections.dueSoon.length),
    _info('Due Today', inspections.dueToday.length),
    _info('Overdue', inspections.overdue.length),
    _info('Completed', inspections.completed.length),
    _info('Findings', inspections.findings.length),
    _info('All', inspections.length),
    _eq('INS-2026-0045 answered (of 12)', ins45.answeredQuestions, 8),
    _rule(
      'INS-2026-0045 sections 4/4, 3/4, 1/3, 0/1',
      ins45.sections.map((s) => '${s.answered}/${s.questions.length}').join(', ') == '4/4, 3/4, 1/3, 0/1',
      ins45.sections.map((s) => '${s.answered}/${s.questions.length}').join(', '),
    ),
    _rule('INS-2026-0045 is overdue', DemoClock.isOverdue(ins45.dueAt), InspectionQueries.displayStatus(ins45)),
  ]);

  // ---- Issues
  final issueGroup = DataCheckGroup('Issues / Defects', [
    _eq('All Issues', issues.length, 22),
    _eq('My Issues', issues.mine(me).length, 6),
    _eq('Open (Open + In Progress)', issues.open.length, 10),
    _eq('In Progress', issues.inProgress.length, 4),
    _eq('Resolved', issues.resolved.length, 12),
    _rule(
      'All = Open + Resolved',
      issues.length == issues.open.length + issues.resolved.length,
      '${issues.length} = ${issues.open.length} + ${issues.resolved.length}',
    ),
    _rule(
      'Open = Open status + In Progress',
      issues.open.length == issues.where((i) => i.status == IssueStatus.open).length + issues.inProgress.length,
      '${issues.open.length}',
    ),
  ]);

  // ---- Alerts & notifications
  final sevSum = Severity.all.fold<int>(0, (int s, v) => s + alerts.withSeverity(v).length);
  final alertGroup = DataCheckGroup('Alerts & Notifications', [
    _eq('All alerts', alerts.length, 45),
    _eq('Critical', alerts.withSeverity(Severity.critical).length, 8),
    _eq('High', alerts.withSeverity(Severity.high).length, 12),
    _eq('Medium', alerts.withSeverity(Severity.medium).length, 18),
    _eq('Low', alerts.withSeverity(Severity.low).length, 7),
    _rule('All = Critical + High + Medium + Low', sevSum == alerts.length, '$sevSum = ${alerts.length}'),
    _info('Critical requiring action (Home)', alerts.criticalRequiringAction.length),
    _eq('Notifications', notifications.length, 18),
    _eq('Unread (bell badge)', notifications.unread.length, 12),
    _eq('System', notifications.inCategory(NotificationCategory.system).length, 18),
    _eq('Work Orders', notifications.inCategory(NotificationCategory.workOrders).length, 6),
  ]);

  // ---- Inventory
  final chain = <String>[];
  for (final p in inventory.parts) {
    final h = inventory.historyFor(p.id).reversed.toList(); // oldest first
    if (h.isEmpty) continue;
    var bal = p.id == 'BR-6205' ? br6205OpeningBalance : h.first.balanceAfter - h.first.qtyChange;
    for (final t in h) {
      bal += t.qtyChange;
      if (bal != t.balanceAfter) chain.add('${p.id} ${t.ref}: $bal ≠ ${t.balanceAfter}');
    }
    if (bal != p.qty) chain.add('${p.id}: last balance $bal ≠ stock ${p.qty}');
  }
  final br = inventory.part('BR-6205')!;
  final invGroup = DataCheckGroup('Inventory', [
    _eq('All Items', inventory.totalItems, 124),
    _eq('Detailed part records', inventory.parts.length, 20),
    _eq('Low Stock', inventory.lowStock.length, 8),
    _eq('Reorder', inventory.reorder.length, 12),
    _eq('Reserved', inventory.reserved.length, 6),
    _rule(
      'Reorder = Low Stock + Out of Stock',
      inventory.reorder.length == inventory.lowStock.length + inventory.outOfStock.length,
      '${inventory.reorder.length} = ${inventory.lowStock.length} + ${inventory.outOfStock.length}',
    ),
    _eq('BR-6205 current stock', br.qty, 36),
    _eq('BR-6205 available (stock − reserved)', br.available, 32),
    _rule('Stock history balances add up', chain.isEmpty, chain.isEmpty ? 'All balances OK' : chain.join('; ')),
  ]);

  // ---- Movement
  final moveGroup = DataCheckGroup('Movement & Custody', [
    _eq('My Requests', moves.mine(me).length, 8),
    _eq('Pending Approval', moves.pending.length, 4),
    _eq('Approvals for Rex (Home)', moves.toApprove(me).length, 2),
    _info('Completed', moves.completed.length),
  ]);

  // ---- WIP
  final w = wip.summary;
  final mo18 = wip.order('MO-2026-0018')!;
  final wipGroup = DataCheckGroup('WIP / Operations', [
    _eq('All WIP', w.allWip, 124),
    _rule(
      'All WIP = In Process + Delayed + On Hold + Queued',
      w.allWip == w.inProcess + w.delayed + w.onHold + w.queued,
      '${w.inProcess} + ${w.delayed} + ${w.onHold} + ${w.queued} = ${w.allWip}',
    ),
    _eq('In Process', w.inProcess, 78),
    _eq('Completed Today', w.completedToday, 82),
    _eq('Delayed', w.delayed, 16),
    _eq('On Hold', w.onHold, 6),
    _eq('MO-2026-0018 progress %', (mo18.progress * 100).round(), 64),
    _rule(
      'Production orders use MO- prefix',
      wip.orders.every((o) => o.id.startsWith('MO-')),
      '${wip.orders.length} orders',
    ),
    _info('Showing', 'Showing ${wip.orders.length} of ${w.allWip}'),
  ]);

  // ---- Documents
  final ds = docs.summary;
  final bucketSum = ds.byBucket.values.fold<int>(0, (a, b) => a + b);
  final docGroup = DataCheckGroup('Documents', [
    _eq('All Documents', ds.total, 64),
    _rule(
      'All = Manuals + Warranty + Certificates + Others',
      bucketSum == ds.total,
      ds.byBucket.entries.map((e) => '${e.key} ${e.value}').join(', '),
    ),
    _eq('Expiring Soon', ds.expiringSoon, 8),
    _eq('Compliant', ds.compliant, 42),
    _eq('Pending', ds.pending, 6),
    _eq('GEN-00045 documents', docs.forAsset('GEN-00045').length, 6),
    _rule(
      'Every detailed document can be opened',
      docs.docs.every((d) => d.filePath != null),
      '${docs.docs.length} documents',
    ),
  ]);

  // ---- Audits
  final annual = audits.firstWhere((a) => a.id == 'AUD-2026-001');
  final auditGroup = DataCheckGroup('Asset Audit', [
    _eq('My Audits', audits.mine(me).length, 3),
    _eq('Assigned', audits.assigned(me).length, 2),
    _eq('Completed', audits.completed.length, 1),
    _eq('Annual audit done (of 1,500)', annual.done, 900),
    _eq('Annual audit progress %', (annual.progress * 100).round(), 60),
    _rule(
      'Done = Verified + Wrong Location + Not Found + Unregistered',
      annual.done == annual.verified + annual.wrongLocation + annual.notFound + annual.unregistered,
      '${annual.verified} + ${annual.wrongLocation} + ${annual.notFound} + ${annual.unregistered}',
    ),
    _rule(
      'Campus audit 100%',
      audits.firstWhere((a) => a.id == 'AUD-2026-003').progress == 1 &&
          audits.firstWhere((a) => a.id == 'AUD-2026-003').status == AuditStatus.completed,
      'Completed',
    ),
  ]);

  // ---- Offline sync
  final pendingByKind = {for (final k in SyncKind.values) k: sync.pending.where((i) => i.kind == k).length};
  final syncGroup = DataCheckGroup('Offline Sync', [
    _eq('Pending items', sync.pending.length, 8),
    _eq('Synced', sync.syncedCount, 25),
    _eq('Local items', sync.localItems, 33),
    _rule(
      'Local = Synced + Pending',
      sync.localItems == sync.syncedCount + sync.pending.length,
      '${sync.syncedCount} + ${sync.pending.length} = ${sync.localItems}',
    ),
    _eq('Completed Locally', sync.completedLocally, 5),
    _eq('Photos to Sync', sync.photosToSync, 2),
    _info('By type', pendingByKind.entries.map((e) => '${e.key.name} ${e.value}').join(', ')),
    _info('Synced %', '${(sync.syncedFraction * 100).round()}%'),
    _info('Last sync', DemoClock.formatDateTime(sync.lastSync)),
  ]);

  // ---- Referential integrity: every ID points at a real record.
  final missing = <String>{
    for (final x in wos)
      if (!assetIds.contains(x.assetId)) '${x.id} → ${x.assetId}',
    for (final x in inspections)
      if (!assetIds.contains(x.assetId)) '${x.id} → ${x.assetId}',
    for (final x in issues)
      if (!assetIds.contains(x.assetId)) '${x.id} → ${x.assetId}',
    for (final x in alerts)
      if (!assetIds.contains(x.assetId)) '${x.id} → ${x.assetId}',
    for (final x in moves)
      if (!assetIds.contains(x.assetId)) '${x.id} → ${x.assetId}',
    for (final x in docs.docs)
      if (!assetIds.contains(x.assetId)) '${x.id} → ${x.assetId}',
    for (final x in scans)
      if (x.kind.name == 'asset' && !assetIds.contains(x.refId)) '${x.id} → ${x.refId}',
    for (final x in wos)
      for (final p in x.parts)
        if (inventory.part(p.partId) == null) '${x.id} → ${p.partId}',
    for (final x in wos)
      for (final id in [x.assigneeId, x.reporterId, x.coordinatorId].whereType<String>())
        if (!peopleIds.contains(id)) '${x.id} → $id',
    for (final x in issues)
      for (final id in x.workOrderIds)
        if (!wos.any((w) => w.id == id)) '${x.id} → $id',
  };
  final ids = [
    ...wos.map((x) => x.id),
    ...inspections.map((x) => x.id),
    ...issues.map((x) => x.id),
    ...moves.map((x) => x.id),
  ];
  final dupes = ids.where((id) => ids.where((x) => x == id).length > 1).toSet();
  final integrity = DataCheckGroup('Consistency', [
    _rule(
      'Every referenced asset / part / person exists',
      missing.isEmpty,
      missing.isEmpty ? 'OK' : missing.join(', '),
    ),
    _rule('No duplicate record IDs', dupes.isEmpty, dupes.isEmpty ? 'OK' : dupes.join(', ')),
    _rule('Scan history seeded with 6 design scans', scans.length >= 6, '${scans.length} scans'),
  ]);

  return [
    assetGroup,
    trackingGroup,
    maintGroup,
    inspGroup,
    issueGroup,
    alertGroup,
    invGroup,
    moveGroup,
    wipGroup,
    docGroup,
    auditGroup,
    syncGroup,
    integrity,
  ];
}
