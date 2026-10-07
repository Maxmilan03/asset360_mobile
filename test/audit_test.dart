import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/audits_repository.dart';
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

const _aud = 'AUD-2026-001';
const _gen = 'GEN-00045';

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

  test('create, start, record, relocate, unregistered and complete keep every count in sync', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(auditsProvider.notifier);
    Audit a() => c.read(auditByIdProvider(_aud))!;
    final me = c.read(currentUserProvider).id;
    expect(c.read(auditsProvider).mine(me), hasLength(3));
    expect(c.read(auditsProvider).assigned(me), hasLength(2));
    expect(c.read(auditsProvider).mine(me).completed, hasLength(1));
    expect([a().verified, a().wrongLocation, a().notFound, a().unregistered], [850, 25, 15, 10]);
    expect(a().done, 900);
    expect((a().progress * 100).round(), 60);
    expect(a().entryFor(_gen), isNull);

    // Create → Pending; total = registered assets in scope.
    final id = n.create(
      name: 'Warehouse Audit',
      site: 'Dubai Factory',
      start: DemoClock.today,
      end: DemoClock.today.add(const Duration(days: 5)),
      scopeLocations: const ['Main Warehouse'],
      auditorIds: const ['rafi'],
    );
    final created = c.read(auditByIdProvider(id))!;
    expect(id, 'AUD-2026-004');
    expect(created.status, AuditStatus.pending);
    expect(created.totalAssets, auditScope(created, c.read(assetsProvider)).length);
    expect(created.totalAssets, greaterThan(0));
    expect(c.read(auditsProvider).mine(me), hasLength(4));
    n.start(id);
    expect(c.read(auditByIdProvider(id))!.status, AuditStatus.inProgress);

    // Verified, then re-audited as Wrong Location with a location update + movement record.
    n.record(_aud, AuditEntry(assetId: _gen, result: AuditResult.verified, at: DemoClock.now));
    expect(a().verified, 851);
    expect(a().done, 901);
    const found = 'Building B / Ground Floor – Workshop';
    final moves = c.read(movementsProvider).length;
    n.record(
      _aud,
      AuditEntry(assetId: _gen, result: AuditResult.wrongLocation, at: DemoClock.now, location: found),
      updateLocation: true,
    );
    expect(a().verified, 850);
    expect(a().wrongLocation, 26);
    expect(a().done, 901);
    expect(a().entryFor(_gen)!.locationUpdated, isTrue);
    expect(c.read(assetByIdProvider(_gen))!.location, found);
    expect(c.read(movementsProvider), hasLength(moves + 1));
    expect(c.read(movementsProvider).first.type, MoveType.auditCorrection);
    expect(c.read(movementsProvider).first.status, MoveStatus.completed);

    final tag = n.recordUnregistered(_aud, code: '', description: 'Ladder', location: found);
    expect(tag, startsWith('UNREG-'));
    expect(a().unregistered, 11);

    n.pause(_aud);
    expect(a().status, AuditStatus.paused);
    final remaining = a().remaining;
    n.complete(_aud);
    expect(a().status, AuditStatus.completed);
    expect(a().notFound, 15 + remaining);
    expect(a().done, 1500);
    expect(a().progress, 1);
    expect(a().entriesFor(AuditResult.notFound).any((e) => e.method == AuditMethod.auto), isTrue);
    expect(c.read(auditsProvider).mine(me).completed, hasLength(2));
  });

  testWidgets('Asset Audit: tiles = tabs, tile filters, Start Audit, search', (tester) async {
    final c = await _open(tester, Routes.audit);
    expect(find.text('Physical verification and reconciliation of assets'), findsOneWidget);
    expect(find.text('My Audits (3)'), findsOneWidget);
    expect(find.text('Assigned (2)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Total Assets 1,500'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('01 Sep – 30 Sep 2026'), findsOneWidget);

    await _tap(tester, find.text('Pending').first);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('IT Equipment Audit'), findsOneWidget);
    expect(find.text('Annual Asset Audit 2026'), findsNothing);
    await _tap(tester, find.text('Start Audit'));
    expect(c.read(auditByIdProvider('AUD-2026-002'))!.status, AuditStatus.inProgress);
    expect(find.text('No audits match'), findsOneWidget);
    await _tap(tester, find.byTooltip('Show all'));
    await _settleSnack(tester);

    await _tap(tester, find.text('Completed (1)'));
    expect(find.text('Campus Asset Audit'), findsOneWidget);
    expect(find.text('Annual Asset Audit 2026'), findsNothing);
    await _tap(tester, find.text('My Audits (3)'));

    await tester.enterText(find.byType(TextField).first, 'IT Equipment');
    await tester.pumpAndSettle();
    expect(find.text('IT Equipment Audit'), findsOneWidget);
    expect(find.text('Campus Asset Audit'), findsNothing);
  });

  testWidgets('session: scan → Asset Found → Wrong Location + update → Save & Next; re-scan asks', (tester) async {
    final c = await _open(tester, Routes.auditSession(_aud));
    expect(find.text('Annual Asset Audit 2026'), findsOneWidget);
    expect(find.text('900 / 1,500'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('850'), findsOneWidget);
    expect(find.text('Position the QR / Barcode within the frame'), findsOneWidget);

    await _tap(tester, find.text('Simulate scan'));
    expect(find.text('Asset Found'), findsOneWidget);
    expect(find.text('Tag ID (QR)'), findsOneWidget);
    expect(find.text('DG2023-4587'), findsOneWidget);

    await _tap(tester, find.text('Wrong\nLocation'));
    expect(find.text('Update asset location to scanned location'), findsOneWidget);
    await _tap(tester, find.byTooltip('Pick from location tree'));
    await _tap(tester, find.text('Building B'));
    await _tap(tester, find.text('Ground Floor'));
    await _tap(tester, find.text('Workshop'));
    expect(find.text('Building B / Ground Floor – Workshop'), findsOneWidget);
    await _tap(tester, find.text('Update asset location to scanned location'));
    await _tap(tester, find.text('Save & Next'));

    final a = c.read(auditByIdProvider(_aud))!;
    expect(a.wrongLocation, 26);
    expect(a.done, 901);
    expect(c.read(assetByIdProvider(_gen))!.location, 'Building B / Ground Floor – Workshop');
    expect(find.text('901 / 1,500'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);

    await _settleSnack(tester);
    await _tap(tester, find.text('Simulate scan'));
    expect(find.textContaining('Already wrong location at'), findsOneWidget);
    expect(find.textContaining('re-audit?'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));

    // Result tile → list of those assets.
    await _tap(tester, find.text('Wrong Location').first);
    expect(find.text('Wrong Location (26)'), findsOneWidget);
    expect(find.textContaining('GEN-00045 · '), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Showing 3 of 26'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Showing 3 of 26'), findsOneWidget);
  });

  testWidgets('manual entry of an unknown tag records an Unregistered asset and offers Register now', (tester) async {
    final c = await _open(tester, Routes.auditSession(_aud));
    await _tap(tester, find.text('Manual Entry'));
    await tester.enterText(find.byType(TextField).first, 'TAG-77777');
    await _tap(tester, find.text('Find Asset'));
    expect(find.text('Unregistered asset found'), findsOneWidget);
    await _tap(tester, find.text('Save as Unregistered'));
    expect(find.text('Describe the asset'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'What is it? e.g. Portable welding set'), 'Pallet jack');
    await _tap(tester, find.text('Select location'));
    await _tap(tester, find.text('Main Warehouse'));
    await _tap(tester, find.text('Ground Floor'));
    await _tap(tester, find.text('Zone A'));
    await _tap(tester, find.text('Save as Unregistered'));
    expect(c.read(auditByIdProvider(_aud))!.unregistered, 11);
    expect(c.read(auditByIdProvider(_aud))!.entryFor('TAG-77777')!.description, 'Pallet jack');
    expect(find.text('Unregistered asset recorded'), findsOneWidget);
    await _tap(tester, find.text('Register now'));
    expect(find.text('Asset Registration'), findsWidgets);
  });

  testWidgets('Complete Audit shows the unscanned summary, then the report with Share', (tester) async {
    final c = await _open(tester, Routes.auditSession(_aud));
    await _tap(tester, find.byTooltip('Audit actions'));
    await _tap(tester, find.text('Complete Audit'));
    expect(find.textContaining('600 unscanned assets will be marked Not Found'), findsOneWidget);
    expect(find.textContaining('GEN-00045'), findsWidgets);
    await _tap(tester, find.widgetWithText(FilledButton, 'Complete Audit'));
    final a = c.read(auditByIdProvider(_aud))!;
    expect(a.status, AuditStatus.completed);
    expect(a.notFound, 615);
    expect(find.text('Audit Report'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Not Found (615)'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Not Found (615)'), findsOneWidget);
    await _settleSnack(tester);
    await _tap(tester, find.text('Share'));
    expect(find.textContaining('Report summary copied'), findsOneWidget);
  });

  testWidgets('Create Audit Campaign validates and adds a Pending audit with Start Audit', (tester) async {
    final c = await _open(tester, Routes.audit);
    await _tap(tester, find.byTooltip('Create Audit Campaign'));
    await _tap(tester, find.text('Create Audit'));
    expect(find.text('Enter the audit name'), findsOneWidget);
    expect(find.text('Select the site'), findsOneWidget);
    await _settleSnack(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Warehouse Spot Check');
    await _tap(tester, find.byType(DropdownButtonFormField<String>).first);
    await _tap(tester, find.text('Dubai Factory').last);
    await _tap(tester, find.text('Main Warehouse'));
    expect(find.textContaining('in scope'), findsOneWidget);
    await _tap(tester, find.text('Select date').first);
    await _tap(tester, find.text('OK'));
    await _tap(tester, find.text('Select date'));
    await _tap(tester, find.text('OK'));
    await _tap(tester, find.text('Blind count'));
    await _tap(tester, find.text('Create Audit'));

    final created = c.read(auditsProvider).first;
    expect(created.name, 'Warehouse Spot Check');
    expect(created.status, AuditStatus.pending);
    expect(created.blindCount, isTrue);
    expect(created.scopeLocations, ['Main Warehouse']);
    expect(find.text('My Audits (4)'), findsOneWidget);
    expect(find.text('Warehouse Spot Check'), findsOneWidget);
  });

  for (final (label, size) in _phones) {
    testWidgets('$label: audit screens lay out without overflow', (tester) async {
      final c = await _open(tester, Routes.audit, size: size);
      for (final route in [
        Routes.audit,
        Routes.auditTab('completed'),
        Routes.auditTab('assigned'),
        Routes.auditTab('inProgress'),
        Routes.newAudit,
        Routes.compliance,
        Routes.auditSession(_aud),
        Routes.auditSession('AUD-2026-002'),
        Routes.auditSession('AUD-2026-003'),
        Routes.auditAsset(_aud, _gen, method: AuditMethod.qr),
        Routes.auditAsset(_aud, 'CNC-00123', method: AuditMethod.rfid),
        Routes.auditResults(_aud, AuditResult.wrongLocation),
        Routes.auditResults(_aud, AuditResult.unregistered),
        Routes.auditReport(_aud),
      ]) {
        c.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }
}
