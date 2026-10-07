import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/scans_mock.dart';
import 'package:asset360_mobile/data/models/scan_record.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/assets/scan/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

Future<ProviderContainer> _openScan(WidgetTester tester, {Size size = const Size(1170, 2532)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // ProviderScope (not an uncontrolled container) so the clock timer is disposed with the tree.
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Scan'));
  await tester.pumpAndSettle();
  expect(find.text('Scan & Identify'), findsOneWidget);
  return ProviderScope.containerOf(tester.element(find.byType(ScanScreen)));
}

void main() {
  setUp(() => DemoClock.frozen = true);

  test('scan codes resolve to assets (ID, tag, barcode), parts and locations', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final h = c.read(scanHistoryProvider.notifier);
    expect(h.resolve('mtr-00123'), (kind: ScanKind.asset, refId: 'MTR-00123'));
    expect(h.resolve('RFID-A360-000456'), (kind: ScanKind.asset, refId: 'MTR-00123'));
    expect(h.resolve('BR-6205'), (kind: ScanKind.part, refId: 'BR-6205'));
    expect(h.resolve('${locationCodePrefix}Main Plant / Production Floor 1 – Line 1')?.kind, ScanKind.location);
    expect(h.resolve(demoUnregisteredTag), isNull);

    final seed = c.read(scanHistoryProvider);
    expect(seed.map((s) => s.refId), ['MTR-00123', 'FL-012', 'FP-0021', 'LAP-0098', 'AHU-03', 'GEN-00045']);
    expect(seed.count(ScanKind.asset), 6);
    expect(c.read(nearbyBeaconsProvider).length, 4);
  });

  testWidgets('Simulate scan → Asset Identified (added to history) → every action tile opens', (tester) async {
    final c = await _openScan(tester);
    final before = c.read(scanHistoryProvider).length;
    await tester.tap(find.text('Simulate scan'));
    await tester.pumpAndSettle();
    expect(find.text('Asset Identified'), findsOneWidget);
    expect(find.text('MTR-00123'), findsOneWidget);
    expect(c.read(scanHistoryProvider).length, before + 1);
    expect(c.read(scanHistoryProvider).first.refId, 'MTR-00123');

    final router = c.read(routerProvider);
    final expected = {
      'View Details': Routes.assetDetail('MTR-00123'),
      'Create Work Order': Routes.createWorkOrder(assetId: 'MTR-00123'),
      'Create Inspection': Routes.withAsset(Routes.createInspection, 'MTR-00123'),
      'Move Asset': Routes.withAsset(Routes.transferAsset, 'MTR-00123'),
      'Report Issue': Routes.withAsset(Routes.reportIssue, 'MTR-00123'),
      'View on Map': Routes.trackAsset('MTR-00123'),
    };
    for (final e in expected.entries) {
      await tester.tap(find.text(e.key));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), e.value, reason: e.key);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Asset Identified'), findsOneWidget);
    }
    for (final (tile, sheet) in [('Check Out', 'Check Out MTR-00123'), ('More Actions', 'Print QR Tag')]) {
      await tester.tap(find.text(tile));
      await tester.pumpAndSettle();
      expect(find.text(sheet), findsOneWidget, reason: tile);
      await tester.tapAt(const Offset(20, 120));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Add Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Choose from gallery'), findsOneWidget);
  });

  testWidgets('Manual Entry autocompletes; an unknown code offers Register this asset', (tester) async {
    final c = await _openScan(tester);
    await tester.tap(find.text('Manual Entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'FL-01');
    await tester.pumpAndSettle();
    await tester.tap(find.text('FL-012'));
    await tester.pumpAndSettle();
    expect(find.text('Asset Identified'), findsOneWidget);
    expect(c.read(scanHistoryProvider).first.method, 'Manual');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual Entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'XYZ-999');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find Asset'));
    await tester.pumpAndSettle();
    expect(find.text('Tag not registered'), findsOneWidget);
    await tester.tap(find.text('Register this asset'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, Routes.newRegistration);
  });

  testWidgets('NFC reads a tag after 2 s; BLE lists 4 beacons over 3 s', (tester) async {
    final c = await _openScan(tester);
    await tester.tap(find.text('NFC'));
    await tester.pump();
    expect(find.text('Hold your phone near the tag'), findsOneWidget);
    await tester.pump(ScanScreen.tagReadTime);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Asset Identified'), findsOneWidget);
    expect(c.read(scanHistoryProvider).first.method, 'NFC');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BLE'));
    await tester.pump();
    expect(find.text('Searching nearby beacons…'), findsOneWidget);
    await tester.pump(ScanScreen.bleSearchTime);
    await tester.pumpAndSettle();
    expect(find.text('4 beacons found nearby'), findsOneWidget);
    await tester.tap(find.text('CNC-00123'));
    await tester.pumpAndSettle();
    expect(find.text('Asset Identified'), findsOneWidget);
    expect(c.read(scanHistoryProvider).first.method, 'BLE');
  });

  testWidgets('Multi Scan collects scans, Done shows the list with Move / Audit', (tester) async {
    final c = await _openScan(tester);
    await tester.tap(find.text('Multi Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual Entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'GEN-00045');
    await tester.pump();
    await tester.tap(find.text('Find Asset'));
    await tester.pumpAndSettle();
    expect(find.text('Asset Identified'), findsNothing);
    expect(find.widgetWithText(InputChip, 'MTR-00123'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'GEN-00045'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('2 assets scanned. Choose a bulk action.'), findsOneWidget);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(
      c.read(routerProvider).state.uri.toString(),
      Routes.withAssets(Routes.transferAsset, ['MTR-00123', 'GEN-00045']),
    );
  });

  testWidgets('Scan History: counted filters, swipe to remove, Clear All', (tester) async {
    final c = await _openScan(tester);
    await tester.tap(find.byTooltip('Scan History (6)'));
    await tester.pumpAndSettle();
    expect(find.text('Assets (6)'), findsOneWidget);
    expect(find.text('Parts (0)'), findsOneWidget);
    expect(find.text('Locations (0)'), findsOneWidget);
    expect(find.text('FP-0021'), findsOneWidget);

    await tester.drag(find.text('FP-0021'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('FP-0021'), findsNothing);
    expect(find.text('Assets (5)'), findsOneWidget);

    await tester.tap(find.text('LAP-0098'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, Routes.assetDetail('LAP-0098'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear All'));
    await tester.pumpAndSettle();
    expect(c.read(scanHistoryProvider), isEmpty);
    expect(find.text('No scans yet'), findsOneWidget);
  });

  testWidgets('Developer → Print demo tags shows a QR per asset', (tester) async {
    final c = await _openScan(tester);
    c.read(routerProvider).go(Routes.demoTags);
    await tester.pumpAndSettle();
    expect(find.text('Print demo tags'), findsOneWidget);
    expect(find.textContaining('Assets ('), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Not registered'));
    await tester.tap(find.textContaining('Not registered'));
    await tester.pumpAndSettle();
    expect(find.text(demoUnregisteredTag), findsOneWidget);
  });

  for (final (name, size) in [('small 360x640', const Size(1080, 1920)), ('large 430x932', const Size(1290, 2796))]) {
    testWidgets('$name phone: scan screens lay out without overflow', (tester) async {
      final c = await _openScan(tester, size: size);
      for (final mode in ['NFC', 'RFID', 'BLE', 'QR / Barcode']) {
        await tester.tap(find.text(mode));
        await tester.pump(ScanScreen.bleSearchTime);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        if (find.text('Asset Identified').evaluate().isNotEmpty) {
          expect(tester.takeException(), isNull, reason: '$mode result');
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: mode);
      }
      await tester.tap(find.text('Multi Scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate scan'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Multi Scan strip');
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Multi Scan summary');
      await tester.tapAt(const Offset(20, 120));
      await tester.pumpAndSettle();

      final router = c.read(routerProvider);
      for (final route in [Routes.scanResultFrom(Routes.home, 'MTR-00123'), Routes.scanHistoryFrom(Routes.home)]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      expect(find.text('MTR-00123'), findsWidgets);
    });
  }

  testWidgets('Scan History shows a loading skeleton, then the scans', (tester) async {
    await _openScan(tester);
    await tester.tap(find.byTooltip('Scan History (6)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
    expect(find.text('FL-012'), findsOneWidget);
  });
}
