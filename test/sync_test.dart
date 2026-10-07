import 'dart:math';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

/// Every failure roll fails (simulate failures on).
class _AlwaysFail implements Random {
  @override
  double nextDouble() => .05;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => true;
}

Future<ProviderContainer> _open(WidgetTester tester, String route, {Size size = const Size(1170, 2532)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  c.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _settleSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Small (360×640 dp) and large (430×932 dp) phones.
const _phones = [('small 360x640 phone', Size(1080, 1920)), ('large 430x932 phone', Size(1290, 2796))];

void main() {
  setUp(() => DemoClock.frozen = true);

  testWidgets('offline changes from every module are queued; auto-sync on Wi-Fi uploads them', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    SyncState s() => c.read(syncProvider);
    expect(s().pending, hasLength(8));
    expect(s().completedLocally, 5);
    expect(s().photosToSync, 2);
    expect(s().syncedCount, 25);
    expect(s().localItems, 33);
    expect((s().syncedFraction * 100).round(), 76);

    // Online: nothing is queued.
    c.read(workOrdersProvider.notifier).updateDescription('WO-2026-0045', 'Online edit');
    expect(s().pending, hasLength(8));

    c.read(networkProvider.notifier).setSimulatedOffline(true);
    final wos = c.read(workOrdersProvider.notifier);
    wos.updateStatus('WO-2026-0045', WoStatus.inProgress);
    wos.updateDescription('WO-2026-0045', 'Offline edit');
    expect(s().pending, hasLength(9), reason: 'two changes to one WO collapse into one item');
    expect(s().pending.first.subtitle, endsWith('Description edited'));
    expect(c.read(workOrderByIdProvider('WO-2026-0045'))!.savedOffline, isTrue);
    expect(c.read(workOrderByIdProvider('WO-2026-0045'))!.description, 'Offline edit', reason: 'applied locally');
    wos.addPhoto('WO-2026-0045', '/photos/pump_seal.jpg');
    c.read(inspectionsProvider.notifier).setNotes('INS-2026-0045', 'Offline note');
    c.read(issuesProvider.notifier).addComment('ISS-2026-0056', 'Checked offline');
    c.read(assetsProvider.notifier).setLocation('GEN-00046', 'Building B / Floor 1 – Stores');
    c.read(documentsProvider.notifier).rename('DOC-2026-0045', 'Manual.pdf');
    final kinds = s().pending.take(6).map((i) => i.kind).toList();
    expect(kinds, [
      SyncKind.document,
      SyncKind.asset,
      SyncKind.issue,
      SyncKind.inspection,
      SyncKind.photo,
      SyncKind.workOrder,
    ]);
    expect(s().pending, hasLength(14));
    expect(s().photosToSync, 3);
    expect(s().completedLocally, 9, reason: '14 pending − 3 photos − 2 documents');

    // Back online on mobile data with mobile sync off: no auto-sync.
    c.read(networkProvider.notifier).debugSetReal(NetType.mobile);
    c.read(networkProvider.notifier).setSimulatedOffline(false);
    expect(s().running, isFalse);

    // Offline → Wi-Fi: auto-sync uploads everything one at a time.
    c.read(networkProvider.notifier).setSimulatedOffline(true);
    c.read(networkProvider.notifier).debugSetReal(NetType.wifi);
    c.read(networkProvider.notifier).setSimulatedOffline(false);
    expect(s().running, isTrue);
    expect(s().syncingNow, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(s().pending.where((i) => i.status == SyncStatus.syncing).single.progress, greaterThan(0));
    await tester.pump(const Duration(seconds: 30));
    expect(s().running, isFalse);
    expect(s().pending, isEmpty);
    expect(s().syncedCount, 25 + 14);
    expect(s().lastSync, DemoClock.now);
    expect(s().lastSyncCount, 14);
    expect(s().history.first.synced, 14);
    expect(c.read(workOrderByIdProvider('WO-2026-0045'))!.savedOffline, isFalse);
    c.read(syncProvider.notifier).dismissRun();
    expect(s().items, isEmpty);
  });

  testWidgets('cancel stops after the current item; failures can be retried', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(syncProvider.notifier);
    SyncState s() => c.read(syncProvider);

    expect(n.startRun(), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    n.cancelRun();
    await tester.pump(const Duration(seconds: 5));
    expect(s().running, isFalse);
    expect(s().run!.cancelled, isTrue);
    expect(s().syncedCount, 26);
    expect(s().pending, hasLength(7));
    expect(s().history.first.cancelled, isTrue);
    n.dismissRun();

    n.setSimulateFailures(true);
    n.debugRandom = _AlwaysFail();
    n.startRun(ids: [s().pending.first.id, s().pending[1].id]);
    await tester.pump(const Duration(seconds: 5));
    expect(s().failed, 2);
    expect(s().pending, hasLength(7), reason: 'failed items stay in the queue');
    expect(s().history.first.failed, 2);

    n.setSimulateFailures(false);
    n.retry(s().run!.ids.first);
    expect(s().running, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(s().failed, 1);
    expect(s().syncedCount, 27);
  });

  testWidgets('Offline Sync screen: tiles, ring, toggles, offline card, banner from Developer', (tester) async {
    final c = await _open(tester, Routes.offlineSync);
    expect(find.text("You're Online"), findsOneWidget);
    expect(find.text('76%'), findsOneWidget);
    expect(find.text('25 of 33 items synced'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pending Items (8)'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Pending Items (8)'), findsOneWidget);
    expect(find.text('Synced 25 items successfully'), findsOneWidget);

    await _tap(tester, find.text('Sync when connected to Mobile Data'));
    expect(c.read(syncProvider).mobileDataSync, isTrue);
    await _tap(tester, find.text('Automatic Sync'));
    expect(c.read(syncProvider).autoSync, isFalse);

    // Sync Status chevron → history.
    await tester.scrollUntilVisible(find.text('Sync Status'), -300, scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.text('Sync Status'));
    expect(find.text('Sync History'), findsOneWidget);
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();

    // Developer → Simulate offline.
    c.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Simulate offline'), 300, scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.text('Simulate offline'));
    expect(find.text("You're offline – changes will sync later"), findsOneWidget);
    await _tap(tester, find.text("You're offline – changes will sync later"));
    expect(find.text("You're Offline"), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No internet connection'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No internet connection'), findsOneWidget);

    // Sync Now offline → "Try anyway (demo)".
    await _tap(tester, find.text('Sync Now'));
    expect(find.text('Try anyway (demo)'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(c.read(syncProvider).running, isFalse);
  });

  testWidgets('Pending Sync: tabs, row ⋮ view / discard, Clear All', (tester) async {
    final c = await _open(tester, Routes.pendingSync);
    expect(find.text('All (8)'), findsOneWidget);
    expect(find.text('Work Orders (2)'), findsOneWidget);
    expect(find.text('Photos (2)'), findsOneWidget);
    expect(find.text('Sync All (8)'), findsOneWidget);

    await _tap(tester, find.text('Inspections (2)'));
    expect(find.text('INS-2026-0051'), findsOneWidget);
    expect(find.text('WO-2026-0142'), findsNothing);
    await _tap(tester, find.text('All (8)'));

    await _tap(tester, find.byTooltip('Item actions').first);
    await _tap(tester, find.text('View Item'));
    expect(find.text('WO-2026-0142'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('Item actions').first);
    await _tap(tester, find.text('Discard'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Discard'));
    expect(c.read(syncProvider).pending, hasLength(7));
    expect(find.text('Sync All (7)'), findsOneWidget);
    await _settleSnack(tester);

    await _tap(tester, find.text('Clear All'));
    expect(find.textContaining('never reach the server'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Clear All'));
    expect(c.read(syncProvider).pending, isEmpty);
    expect(find.text('Nothing waiting'), findsOneWidget);
  });

  testWidgets('Sync All → Syncing Data: per-item states, cancel, then sync the rest to Done', (tester) async {
    final c = await _open(tester, Routes.pendingSync);
    await tester.tap(find.text('Sync All (8)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Syncing Data'), findsOneWidget);
    expect(find.text('Uploading data to server'), findsOneWidget);
    expect(find.text('0 of 8 items synced'), findsOneWidget);
    expect(find.text('Uploading...'), findsOneWidget);
    expect(find.text('Waiting'), findsWidgets);

    await tester.tap(find.text('Cancel Sync'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Sync cancelled'), findsOneWidget);
    expect(find.text('1 of 8 items synced'), findsOneWidget);
    expect(c.read(syncProvider).pending, hasLength(7));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Offline Sync'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pending Items (7)'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Pending Items (7)'), findsOneWidget);

    await tester.ensureVisible(find.text('Sync Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync Now'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('All items synced'), findsOneWidget);
    expect(find.text('7 of 7 items synced'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    await _tap(tester, find.text('Done'));
    await tester.scrollUntilVisible(find.text('Pending Items (0)'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Synced 7 items successfully'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('100%'), -300, scrollable: find.byType(Scrollable).first);
    expect(find.text('33 of 33 items synced'), findsOneWidget);
  });

  for (final (label, size) in _phones) {
    testWidgets('$label: sync screens lay out without overflow', (tester) async {
      final c = await _open(tester, Routes.offlineSync, size: size);
      c.read(networkProvider.notifier).setSimulatedOffline(true);
      for (final route in [
        Routes.offlineSync,
        Routes.pendingSync,
        Routes.pendingSyncTab('photo'),
        Routes.syncProgress,
        Routes.settings,
      ]) {
        c.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      c.read(networkProvider.notifier).setSimulatedOffline(false);
      c.read(syncProvider.notifier).setSimulateFailures(true);
      c.read(syncProvider.notifier).debugRandom = _AlwaysFail();
      c.read(syncProvider.notifier).startRun();
      c.read(routerProvider).go(Routes.syncProgress);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'running');
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('Sync finished with errors'), findsOneWidget);
      expect(find.text('Retry Failed'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'failed');
    });
  }
}
