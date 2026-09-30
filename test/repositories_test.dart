import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer c;
  setUp(() {
    DemoClock.frozen = true;
    c = ProviderContainer();
  });
  tearDown(() => c.dispose());

  test('closing WO-2026-0045 updates counts, asset status, org summary and stock', () {
    final active = c.read(orgSummaryProvider).statusCounts[AssetStatus.active]!;
    c.read(workOrdersProvider.notifier).close('WO-2026-0045', resolution: 'Bearings replaced', labourHours: 2);

    expect(c.read(workOrdersProvider).mine('rex').length, 7);
    expect(c.read(assetByIdProvider('GEN-00045'))!.status, AssetStatus.active);
    expect(c.read(orgSummaryProvider).statusCounts[AssetStatus.active], active + 1);
    final br = c.read(partByIdProvider('BR-6205'))!;
    expect(br.qty, 34); // 2 reserved bearings issued
    expect(c.read(inventoryProvider).historyFor('BR-6205').first.balanceAfter, 34);
  });

  test('completing a task advances progress and opens the next task', () {
    final n = c.read(workOrdersProvider.notifier);
    for (final id in ['WO45-T2-5', 'WO45-T2-6']) {
      n.toggleChecklistItem('WO-2026-0045', 'WO45-T2', id);
    }
    n.completeTask('WO-2026-0045', 'WO45-T2');
    final wo = c.read(workOrderByIdProvider('WO-2026-0045'))!;
    expect(wo.tasksDone, 2);
    expect(wo.tasks[2].status, 'In Progress');
  });

  test('approving a request lowers Home approvals', () {
    c.read(movementsProvider.notifier).approve('MOV-2026-0047');
    expect(c.read(movementsProvider).toApprove('rex').length, 1);
  });

  test('answering the empty flow-rate question moves INS-2026-0045 to 9/12', () {
    c.read(inspectionsProvider.notifier).answer('INS-2026-0045', '2.2', '850');
    expect(c.read(inspectionByIdProvider('INS-2026-0045'))!.answeredQuestions, 9);
  });

  test('marking all notifications read clears the bell badge', () {
    c.read(notificationsProvider.notifier).markAllRead();
    expect(c.read(unreadNotificationCountProvider), 0);
  });

  test('receiving stock keeps the running balance consistent', () {
    c.read(inventoryProvider.notifier).receive('VB-1120', 20, grn: 'GRN-2026-0050', from: 'SpareTech LLC');
    final inv = c.read(inventoryProvider);
    expect(inv.part('VB-1120')!.qty, 25);
    expect(inv.lowStock.length, 7);
    expect(inv.historyFor('VB-1120').first.balanceAfter, 25);
  });
}
