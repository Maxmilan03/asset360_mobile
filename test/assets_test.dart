import 'dart:math' as math;

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _phones = {'small 360x640': Size(1080, 1920), 'large 430x932': Size(1290, 2796)};

/// Scrolls the page's vertical scrollable to the end, checking for layout errors (overflow) at each step.
Future<void> _scrollThrough(WidgetTester tester, String reason) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: reason);
  final f = find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical);
  if (f.evaluate().isEmpty) return;
  final pos = tester.state<ScrollableState>(f.first).position;
  for (var i = 0; i < 60 && pos.pixels < pos.maxScrollExtent; i++) {
    pos.jumpTo(math.min(pos.pixels + 300, pos.maxScrollExtent));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$reason @ ${pos.pixels.round()}');
  }
  pos.jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => DemoClock.frozen = true);

  group('repository', () {
    late ProviderContainer c;
    setUp(() => c = ProviderContainer());
    tearDown(() => c.dispose());

    test('favorite, retire and duplicate update the register and org summary', () {
      final assets = c.read(assetsProvider.notifier);
      final retired = c.read(orgSummaryProvider).statusCounts[AssetStatus.retired]!;
      assets.toggleFavorite('CNC-00123');
      expect(c.read(assetsProvider).favorites.map((a) => a.id), contains('CNC-00123'));

      assets.setStatus('CNC-00123', AssetStatus.retired);
      expect(c.read(orgSummaryProvider).statusCounts[AssetStatus.retired], retired + 1);

      final id = assets.duplicate('CNC-00123');
      expect(id, 'CNC-00124');
      expect(c.read(assetsProvider).length, 22);
      expect(c.read(orgSummaryProvider).totalAssets, 12459);
    });

    test('editing key information changes location history and AMC', () {
      final a = c.read(assetByIdProvider('CNC-00123'))!;
      c
          .read(assetsProvider.notifier)
          .editKeyInfo(
            a.id,
            status: a.status,
            condition: 'Fair',
            operationalStatus: 'Idle',
            location: 'Main Warehouse / Zone B',
            custodian: a.custodian,
            purchaseDate: a.purchaseDate,
            commissionedDate: a.commissionedDate,
            warrantyExpiry: a.warrantyExpiry,
          );
      final b = c.read(assetByIdProvider('CNC-00123'))!;
      expect(b.condition, 'Fair');
      expect(b.location, 'Main Warehouse / Zone B');
      expect(b.locationHistory.first.location, 'Main Warehouse / Zone B');
      expect(b.amc, isNull);
    });

    test('check-out at the same place changes only the custodian', () {
      final a = c.read(assetByIdProvider('CNC-00123'))!;
      c
          .read(movementsProvider.notifier)
          .submit(
            assetId: a.id,
            type: MoveType.checkOut,
            from: MovePlace(a.location),
            to: MovePlace(a.location),
            newCustodian: 'Mohammed Rafi (Maintenance Technician)',
          );
      final b = c.read(assetByIdProvider('CNC-00123'))!;
      expect(b.custodian, 'Mohammed Rafi (Maintenance Technician)');
      expect(b.locationHistory.length, a.locationHistory.length);
    });

    test('financials: straight-line book value and TCO', () {
      final a = c.read(assetByIdProvider('CNC-00123'))!;
      expect(a.bookValue, lessThan(a.purchaseCost));
      expect(a.bookValue, greaterThanOrEqualTo(a.salvageValue));
      expect(a.tco, a.purchaseCost + a.costs.total - a.salvageValue);
      expect(a.ageLabel, endsWith('Years'));
    });
  });

  testWidgets('Assets list → CNC-00123 detail → IoT tab', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
    );
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Assets'));
    await tester.pumpAndSettle();
    expect(find.text('Total Assets (12,458)'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Showing 21 of 12,458'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'VF3YT');
    await tester.pumpAndSettle();
    expect(find.text('Showing 1 of 12,458'), findsOneWidget);

    await tester.tap(find.text('CNC-00123'));
    await tester.pumpAndSettle();
    expect(find.text('Health Score'), findsOneWidget);
    expect(find.text('Create Work Order'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Key Information'), findsOneWidget);
    expect(find.textContaining('28 Feb 2027 ('), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 700));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to Favorites'));
    await tester.pump();
    expect(find.byTooltip('Remove from Favorites'), findsOneWidget);

    await tester.tap(find.text('IoT'));
    await tester.pumpAndSettle();
    expect(find.text('Live Telemetry'), findsOneWidget);
    expect(find.text('Live Data Trend (Last 24 Hours)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // one live tick
    expect(find.text('Device Information'), findsOneWidget);

    for (final tab in ['Location', 'Maintenance', 'Inspection', 'Financial', 'Documents', 'History']) {
      await tester.tap(find.text(tab).first);
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  for (final MapEntry(key: name, value: size) in _phones.entries) {
    testWidgets('no overflow on a $name phone: Assets list (+ empty search) and every Asset 360° tab', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();

      c.read(routerProvider).go(Routes.assets);
      await _scrollThrough(tester, 'Assets list');
      await tester.enterText(find.byType(TextField).first, 'no-such-asset');
      await tester.pumpAndSettle();
      expect(find.text('No assets found'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Clear search & filters'));
      await tester.pumpAndSettle();

      for (final id in ['CNC-00123', 'LAP-0098']) {
        for (final tab in [
          'overview',
          'location',
          'iot',
          'maintenance',
          'inspection',
          'financial',
          'documents',
          'history',
        ]) {
          c.read(routerProvider).push('${Routes.assetDetail(id)}?tab=$tab');
          await _scrollThrough(tester, '$id $tab');
          c.read(routerProvider).pop();
          await tester.pumpAndSettle();
        }
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
