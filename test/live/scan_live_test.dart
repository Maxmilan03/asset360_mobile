import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/scanning/live_asset_lookup.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/data/models/scan_record.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';
import 'package:asset360_mobile/features/assets/scan/scan_flow.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_asset_backend.dart';

/// API mode scans: ScanService → GET /api/asset-registrations/lookup (fallback: search + exact match).
void main() {
  late FakeAssetBackend backend;
  late ProviderContainer c;

  setUp(() {
    debugApiMode = true;
    backend = FakeAssetBackend();
    c = ProviderContainer(retry: (_, _) => null, overrides: backend.overrides);
  });
  tearDown(() {
    c.dispose();
    debugApiMode = null;
  });

  List<Map<String, String>> lookups() => [
    for (final r in backend.calls('GET', '/api/asset-registrations/lookup')) r.uri.queryParameters,
  ];
  List<Map<String, String>> searches() => [
    for (final r in backend.calls('GET', '/api/asset-registrations')) r.uri.queryParameters,
  ];

  ScanEvent qr(String v) => ScanEvent(value: v, format: 'qr', source: ScanSource.camera);

  test('asset tag found: the assetRegistrationId, all types (no type for a QR)', () async {
    final r = (await c.read(scanServiceProvider).submit(qr('TAG-0001')))!;
    expect(r.matchType, MatchType.asset);
    expect(r.matchId, 'AR000001');
    expect(r.matchLabel, 'AR000001 – Diesel Generator 500 kVA');
    expect(lookups().single, {'code': 'TAG-0001'});
    // Saved in ScanLog (SQLite) with the assetRegistrationId.
    final row = (await c.read(appDatabaseProvider).watchScans().first).single;
    expect(row.matchId, 'AR000001');
  });

  test('RFID: looked up as rfidTagId (type=rfid), matchedBy rfid', () async {
    final r = await c
        .read(scanServiceProvider)
        .resolve(const ScanEvent(value: 'E2000017221101441890ABCD', format: 'rfid', source: ScanSource.manual));
    expect(r.matchId, 'AR000001');
    expect(lookups().single, {'code': 'E2000017221101441890ABCD', 'type': 'rfid'});
    final direct = await c.read(liveAssetLookupProvider).find('E2000017221101441890ABCD', type: 'rfid');
    expect(direct.matchedBy, 'rfid');
  });

  test('NFC: the NDEF text first (all types), then the UID as nfcUid, compact and as read', () {
    final attempts = LiveAssetLookup.attemptsFor(
      const ScanEvent(value: 'TAG-9', format: 'nfc', source: ScanSource.nfc, nfcUid: '04:A2:24'),
    );
    expect(attempts, [('TAG-9', null), ('04A224', 'nfc'), ('04:A2:24', 'nfc')]);
    expect(
      LiveAssetLookup.attemptsFor(
        const ScanEvent(value: 'NFC:04:A2:24', format: 'nfc', source: ScanSource.nfc, nfcUid: '04:A2:24'),
      ),
      [('04A224', 'nfc'), ('04:A2:24', 'nfc')],
    );
  });

  test('not found: no match, no fallback search (the server said "No asset matches…")', () async {
    final r = (await c.read(scanServiceProvider).submit(qr('NOPE-1')))!;
    expect(r.matchType, MatchType.none);
    expect(r.problem, isNull);
    expect(searches(), isEmpty);
  });

  test('409: the server message and the assetRegistrationIds', () async {
    backend.on(
      'GET',
      '/api/asset-registrations/lookup',
      (_) => const FakeReply(409, {
        'message': "The scanned code 'DUP-1' matches more than one asset.",
        'assetRegistrationIds': ['AR000001', 'AR000002'],
      }),
    );
    final r = (await c.read(scanServiceProvider).submit(qr('DUP-1')))!;
    expect(r.matchType, MatchType.none);
    expect(r.problem, "The scanned code 'DUP-1' matches more than one asset.");
    expect(r.candidates, ['AR000001', 'AR000002']);
  });

  test('older server without /lookup (404 route, other message): search + exact asset tag match', () async {
    backend.on(
      'GET',
      '/api/asset-registrations/lookup',
      (_) => const FakeReply(404, {'message': "Asset registration 'lookup' was not found."}),
    );
    final r = (await c.read(scanServiceProvider).submit(qr('tag-0001')))!;
    expect(r.matchId, 'AR000001');
    expect(searches().single['search'], 'tag-0001');

    // A partial match is not a match.
    final none = await c.read(scanServiceProvider).resolve(qr('TAG-00'));
    expect(none.matchType, MatchType.none);
  });

  test('fallback (405): barcode found through the candidates\' detail', () async {
    backend
      ..on('GET', '/api/asset-registrations/lookup', (_) => const FakeReply(405))
      // The search finds the asset by its barcode (a server that searches barcodes).
      ..on(
        'GET',
        '/api/asset-registrations',
        (_) => const FakeReply(200, {
          'items': [sampleAssets0],
          'totalCount': 1,
          'page': 1,
          'pageSize': 20,
          'summary': sampleSummary,
        }),
      );
    final r = await c.read(liveAssetLookupProvider).find('8901234567890');
    expect(r.status, LiveLookupStatus.found);
    expect(r.id, 'AR000001');
    expect(backend.calls('GET', '/api/asset-registrations/AR000001'), hasLength(1));
  });

  test('Link Tag stores the assetRegistrationId in TagLinks; the next scan resolves through it', () async {
    final service = c.read(scanServiceProvider);
    final unknown = (await service.submit(qr('LBL-77')))!;
    expect(unknown.matchType, MatchType.none);
    final linked = await service.linkToAsset(unknown, 'AR000001', label: 'AR000001 – Diesel Generator 500 kVA');
    expect(linked.matchId, 'AR000001');
    final link = (await c.read(appDatabaseProvider).linkByKey('LBL-77'))!;
    expect(link.targetId, 'AR000001');
    expect(link.label, 'AR000001 – Diesel Generator 500 kVA');
    final before = lookups().length;
    final again = await service.resolve(qr('LBL-77'));
    expect(again.matchId, 'AR000001');
    expect(again.viaLink, isTrue);
    expect(lookups().length, before, reason: 'a linked tag needs no server call');
  });

  group('on screen', () {
    Future<GoRouter> pump(WidgetTester tester, Widget Function(BuildContext, WidgetRef, Widget?) home) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: Consumer(builder: home)),
          ),
          GoRoute(
            path: '/assets/detail/:id',
            builder: (_, s) => Scaffold(body: Text('Live detail ${s.pathParameters['id']}')),
          ),
          GoRoute(
            path: '/more/registration/new',
            builder: (_, s) => Scaffold(body: Text('Register ${(s.extra as RegistrationPrefill?)?.barcode}')),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(theme: AppTheme.current, routerConfig: router),
        ),
      );
      return router;
    }

    Future<ScanResult> scan(String code) async => (await c.read(scanServiceProvider).submit(qr(code)))!;

    testWidgets('found → the live detail of the assetRegistrationId, saved in Scan History', (tester) async {
      final r = await tester.runAsync(() => scan('TAG-0001'));
      final router = await pump(
        tester,
        (context, ref, _) =>
            TextButton(onPressed: () => openScanFromScanScreen(context, ref, r!), child: const Text('Open')),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/assets/detail/AR000001');
      expect(find.text('Live detail AR000001'), findsOneWidget);
      final h = c.read(scanHistoryProvider).first;
      expect((h.kind, h.refId, h.label), (ScanKind.asset, 'AR000001', 'AR000001 – Diesel Generator 500 kVA'));
    });

    testWidgets('not found → "Tag not registered" with Register (prefilled) and Link', (tester) async {
      final r = await tester.runAsync(() => scan('NEW-123'));
      await pump(
        tester,
        (context, ref, _) =>
            TextButton(onPressed: () => openScanFromScanScreen(context, ref, r!), child: const Text('Open')),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Tag not registered'), findsOneWidget);
      expect(find.text('Link to an asset'), findsOneWidget);
      await tester.ensureVisible(find.text('Register as new asset'));
      await tester.tap(find.text('Register as new asset'));
      await tester.pumpAndSettle();
      expect(find.text('Register NEW-123'), findsOneWidget);
    });

    testWidgets('409 → the server message and the ids, each opens the asset', (tester) async {
      backend.on(
        'GET',
        '/api/asset-registrations/lookup',
        (_) => const FakeReply(409, {
          'message': "The scanned code 'DUP-1' matches more than one asset.",
          'assetRegistrationIds': ['AR000001', 'AR000002'],
        }),
      );
      final r = await tester.runAsync(() => scan('DUP-1'));
      await pump(
        tester,
        (context, ref, _) => TextButton(onPressed: () => deliverScan(context, ref, r!), child: const Text('Open')),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Several assets use this code'), findsOneWidget);
      expect(find.text("The scanned code 'DUP-1' matches more than one asset."), findsOneWidget);
      await tester.tap(find.text('AR000002'));
      await tester.pumpAndSettle();
      expect(find.text('Live detail AR000002'), findsOneWidget);
    });
  });
}

/// The first sample list item.
const sampleAssets0 = {
  'id': '6650a1b2c3d4e5f600000001',
  'assetRegistrationId': 'AR000001',
  'assetName': 'Diesel Generator 500 kVA',
  'assetTag': 'TAG-0001',
  'status': 'Active',
};
