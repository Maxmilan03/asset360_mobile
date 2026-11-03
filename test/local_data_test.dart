import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/more/local_data/local_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

Future<ProviderContainer> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  // Three saved scans: a known QR, a blank NFC tag and an unknown EAN-13 from the HHT.
  await tester.runAsync(() async {
    final s = c.read(scanServiceProvider);
    await s.submit(const ScanEvent(value: 'CNC-00123', format: 'qr', source: ScanSource.camera));
    await s.submit(
      const ScanEvent(value: 'NFC:04:A2:3B', format: 'nfc', source: ScanSource.nfc, nfcUid: '04:A2:3B', nfcRecords: []),
    );
    await s.submit(const ScanEvent(value: '4006381333931', format: 'ean13', source: ScanSource.hht));
  });
  c.read(routerProvider).go(Routes.localData);
  await tester.pumpAndSettle();
  expect(find.text('Local Data'), findsWidgets);
  return c;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => DemoClock.frozen = true);

  testWidgets('stats and tabs come from SQLite; search; swipe delete + Undo', (tester) async {
    final c = await _open(tester);
    expect(find.text('Scans and tags saved on this device'), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('QR & Barcode (2)'), findsOneWidget);
    expect(find.text('NFC (1)'), findsOneWidget);
    expect(find.text('Linked Tags (0)'), findsOneWidget);
    expect(find.byType(ScanLogRow), findsNWidgets(3));
    expect(find.text('CNC-00123 – CNC Vertical Machining Center (VMC)'), findsOneWidget);
    expect(find.text('Unknown'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'machining');
    await tester.pumpAndSettle();
    expect(find.byType(ScanLogRow), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await _tap(tester, find.text('NFC (1)'));
    expect(find.byType(ScanLogRow), findsOneWidget);
    expect(find.text('NFC:04:A2:3B'), findsOneWidget);
    await _tap(tester, find.text('All (3)'));

    await tester.drag(find.text('4006381333931'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byType(ScanLogRow), findsNWidgets(2));
    expect(find.text('All (2)'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanLogRow), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('detail sheet: UID, no NDEF records, Copy; Link this tag → Linked Tags → Unlink; Clear all', (
    tester,
  ) async {
    final c = await _open(tester);
    await _tap(tester, find.text('NFC:04:A2:3B'));
    expect(find.text('Scan details'), findsOneWidget);
    expect(find.text('04:A2:3B'), findsOneWidget);
    expect(find.text('NDEF records: none (blank or non-NDEF tag)'), findsOneWidget);
    await _tap(tester, find.text('Copy'));
    expect(find.text('Copied to clipboard'), findsOneWidget);

    await _tap(tester, find.text('Link this tag'));
    await _tap(tester, find.text('Link to a location'));
    for (final option in ['Dubai Factory', 'Building A', 'Floor 2']) {
      await _tap(tester, find.text('Select').last);
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }
    await _tap(tester, find.text('Save'));
    // The sheet follows the row: now matched through the link.
    expect(find.text('Change the link'), findsOneWidget);
    expect(find.text('Location: Floor 2 – Building A'), findsOneWidget);
    Navigator.of(tester.element(find.text('Scan details'))).pop();
    await tester.pump(const Duration(seconds: 5)); // the "Tag linked" SnackBar goes away
    await tester.pumpAndSettle();

    expect(find.text('Linked Tags (1)'), findsOneWidget);
    await _tap(tester, find.text('Linked Tags (1)'));
    expect(find.text('Saved on this device: 3 scans'), findsOneWidget);
    await _tap(tester, find.text('NFC:04:A2:3B'));
    expect(find.text('Linked tag'), findsOneWidget);
    await _tap(tester, find.text('Unlink'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Unlink'));
    expect(find.text('No linked tags yet'), findsOneWidget);
    expect(await tester.runAsync(() => c.read(appDatabaseProvider).linkByKey('NFC:04:A2:3B')), isNull);

    await _tap(tester, find.byTooltip('More'));
    await _tap(tester, find.text('Clear all scans'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Clear all'));
    await _tap(tester, find.text('All (0)'));
    expect(find.text('No scans saved yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
