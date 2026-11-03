import 'dart:convert';

import 'package:asset360_mobile/core/scanning/hht_scanner.dart';
import 'package:asset360_mobile/core/scanning/scan_service.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/data/db/location_seed.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

/// A ScanService over a fresh in-memory database (test/flutter_test_config.dart) with a fake clock.
({AppDatabase db, ScanService service, void Function(Duration) advance}) _service() {
  final db = AppDatabase();
  addTearDown(db.close);
  var now = DateTime(2026, 10, 12, 9);
  final service = ScanService(
    db,
    clock: () => now,
    deviceInfo: 'test',
    findAsset: (c) => switch (c.trim().toUpperCase()) {
      'CNC-00123' || 'QR-A360-000123' => (id: 'CNC-00123', label: 'CNC-00123 – CNC Machine'),
      'MTR-00123' => (id: 'MTR-00123', label: 'MTR-00123 – Motor'),
      _ => null,
    },
    findPart: (c) => c.trim().toUpperCase() == 'BR-6205' ? (id: 'BR-6205', label: 'BR-6205 – Bearing') : null,
  );
  return (db: db, service: service, advance: (d) => now = now.add(d));
}

ScanEvent _qr(String v) => ScanEvent(value: v, format: 'qr', source: ScanSource.camera);

void main() {
  group('Locations seed', () {
    test('every node of the mock location tree is seeded once, with a unique readable code', () async {
      final db = AppDatabase();
      addTearDown(db.close);
      final rows = await db.allLocations();
      var nodes = 0;
      for (final buildings in locationTree.values) {
        nodes++;
        for (final floors in buildings.values) {
          nodes++;
          for (final rooms in floors.values) {
            nodes += 1 + rooms.length;
          }
        }
      }
      expect(rows.length, nodes);
      expect(rows.map((r) => r.code).toSet().length, rows.length);
      final f2 = await db.locationByCode('bld-a-f2');
      expect(f2, isNotNull);
      expect(
        (f2!.site, f2.building, f2.floor, f2.room, f2.level),
        ('Dubai Factory', 'Building A', 'Floor 2', null, LocationLevel.floor),
      );
      expect(f2.label, 'Floor 2 – Building A');
      expect(f2.path, 'Building A / Floor 2');
      expect(locationAbbr('Production Floor 1'), 'PF1');
      expect(locationAbbr('2nd Floor'), 'F2');
      expect(locationAbbr('Ground Floor'), 'GF');
    });
  });

  group('ScanService', () {
    test('match order: tag link, then LOC: location, then asset, then part, then none', () async {
      final t = _service();
      final s = t.service;

      expect((await s.submit(_qr('CNC-00123')))!.matchType, MatchType.asset);
      t.advance(const Duration(seconds: 3));
      final loc = (await s.submit(_qr('LOC:BLD-A-F2')))!;
      expect((loc.matchType, loc.matchId, loc.matchLabel), (MatchType.location, 'BLD-A-F2', 'Floor 2 – Building A'));
      // The older demo labels ("LOC:" + path) still resolve.
      expect((await s.resolve(_qr('LOC:Building B / Ground Floor – Workshop'))).location?.room, 'Workshop');
      expect((await s.resolve(_qr('BR-6205'))).matchType, MatchType.part);
      expect((await s.resolve(_qr('LOC:NOPE'))).matchType, MatchType.none);
      final unknown = (await s.submit(_qr('XYZ-1')))!;
      expect(unknown.matchType, MatchType.none);

      // A link wins over everything: link the asset's own barcode to a location.
      final floor = (await t.db.locationByCode('BLD-B-GF'))!;
      await s.linkToLocation((await s.resolve(_qr('CNC-00123'))), floor);
      final linked = await s.resolve(_qr('CNC-00123'));
      expect((linked.matchType, linked.matchId, linked.viaLink), (MatchType.location, 'BLD-B-GF', true));

      // Linking an unknown scan updates its saved row.
      final r = await s.linkToAsset(unknown, 'MTR-00123');
      expect((r.matchType, r.matchId), (MatchType.asset, 'MTR-00123'));
      final row = (await t.db.watchScan(unknown.logId!).first)!;
      expect((row.matchType, row.matchId), (MatchType.asset, 'MTR-00123'));
      expect((await s.resolve(_qr('XYZ-1'))).matchId, 'MTR-00123');
    });

    test('NFC tags resolve by "NFC:" + UID, even blank ones', () async {
      final t = _service();
      final blank = ScanEvent(value: nfcTagKey('04:A2:3B'), format: 'nfc', source: ScanSource.nfc, nfcUid: '04:A2:3B');
      final r = (await t.service.submit(blank))!;
      expect(r.matchType, MatchType.none);
      await t.service.linkToLocation(r, (await t.db.locationByCode('BLD-A-F2'))!);
      final link = (await t.db.linkByKey('NFC:04:A2:3B'))!;
      expect((link.tagType, link.targetType, link.targetId), (TagType.nfc, LinkTarget.location, 'BLD-A-F2'));
      // A tag with a text record still resolves through its UID link first.
      const withText = ScanEvent(value: 'hello', format: 'nfc', source: ScanSource.nfc, nfcUid: '04:A2:3B');
      expect((await t.service.resolve(withText)).matchId, 'BLD-A-F2');
    });

    test('the same value within 2 seconds is ignored (not saved); after 2 s it counts again', () async {
      final t = _service();
      expect(await t.service.submit(_qr('CNC-00123')), isNotNull);
      t.advance(const Duration(milliseconds: 1500));
      expect(await t.service.submit(_qr('CNC-00123')), isNull);
      expect(await t.service.submit(_qr('MTR-00123')), isNotNull, reason: 'a different value is not a duplicate');
      t.advance(const Duration(milliseconds: 100));
      expect(await t.service.submit(_qr('MTR-00123')), isNull);
      t.advance(const Duration(seconds: 2));
      expect(await t.service.submit(_qr('MTR-00123')), isNotNull);
      expect((await t.db.watchScans().first).length, 3);
    });
  });

  group('drift queries', () {
    test('TagLinks.tagKey is unique: linking again replaces the link; a raw duplicate insert fails', () async {
      final db = AppDatabase();
      addTearDown(db.close);
      final at = DateTime(2026, 10, 12);
      await db.linkTag(
        tagKey: 'QR-1',
        tagType: TagType.qr,
        targetType: LinkTarget.asset,
        targetId: 'CNC-00123',
        label: 'CNC',
        createdAt: at,
      );
      await db.linkTag(
        tagKey: 'QR-1',
        tagType: TagType.qr,
        targetType: LinkTarget.location,
        targetId: 'BLD-A-F2',
        label: 'Floor 2 – Building A',
        createdAt: at,
      );
      final links = await db.watchTagLinks().first;
      expect(links.length, 1);
      expect((links.single.targetType, links.single.targetId), (LinkTarget.location, 'BLD-A-F2'));
      await expectLater(
        db
            .into(db.tagLinks)
            .insert(
              TagLinksCompanion.insert(
                tagKey: 'QR-1',
                tagType: TagType.qr,
                targetType: LinkTarget.asset,
                targetId: 'X',
                label: 'X',
                createdAt: at,
              ),
            ),
        throwsA(anything),
      );
      await db.unlinkTag(links.single.id);
      expect(await db.watchTagLinks().first, isEmpty);
    });

    test('watchScans filters, newest first; stats; delete + restore; clear', () async {
      final db = AppDatabase();
      addTearDown(db.close);
      final now = DateTime.now();
      Future<int> add(String v, String format, ScanSource src, MatchType m, DateTime at, {String? label}) => db.addScan(
        ScanLogCompanion.insert(
          value: v,
          format: format,
          source: src,
          matchType: m,
          matchLabel: Value(label),
          scannedAt: at,
          deviceInfo: 'test',
        ),
      );
      await add('CNC-00123', 'qr', ScanSource.camera, MatchType.asset, now, label: 'CNC-00123 – CNC Machine');
      await add('NFC:04:AA', 'nfc', ScanSource.nfc, MatchType.none, now.subtract(const Duration(minutes: 5)));
      final old = await add('4006381333931', 'ean13', ScanSource.hht, MatchType.none, DateTime(2026, 1, 1));

      expect((await db.watchScans().first).map((s) => s.value), ['CNC-00123', 'NFC:04:AA', '4006381333931']);
      expect((await db.watchScans(const ScanFilter(nfcOnly: true)).first).single.value, 'NFC:04:AA');
      expect((await db.watchScans(const ScanFilter(nfcOnly: false)).first).length, 2);
      expect((await db.watchScans(const ScanFilter(query: 'cnc machine')).first).single.value, 'CNC-00123');
      expect((await db.watchScans(const ScanFilter(sources: {ScanSource.hht})).first).single.format, 'ean13');
      expect((await db.watchScans(const ScanFilter(matches: {MatchType.none})).first).length, 2);
      expect((await db.watchScans(const ScanFilter(formats: {'qr', 'ean13'})).first).length, 2);
      final today = DateTime(now.year, now.month, now.day);
      expect((await db.watchScans(ScanFilter(from: today)).first).length, 2);
      expect(await db.watchFormats().first, ['ean13', 'nfc', 'qr']);

      final stats = await db.watchStats(today).first;
      expect((stats.total, stats.today, stats.nfc, stats.codes, stats.links), (3, 2, 1, 2, 0));

      final row = (await db.watchScan(old).first)!;
      await db.deleteScan(old);
      expect((await db.watchScans().first).length, 2);
      await db.restoreScan(row);
      expect((await db.watchScans().first).last.id, old);
      await db.clearScans();
      expect(await db.watchScans().first, isEmpty);
    });
  });

  group('keyboard wedge', () {
    final t0 = DateTime(2026, 10, 12, 9);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    test('fast characters ending with Enter are one scan', () {
      final d = KeyboardWedgeDetector();
      for (final (i, c) in 'CNC-00123'.split('').indexed) {
        d.addChar(c, at(i * 10));
      }
      expect(d.enter(at(95)), 'CNC-00123');
      expect(d.enter(at(200)), isNull, reason: 'the buffer is cleared');
    });

    test('slow typing, short codes and a late Enter are not scans', () {
      final d = KeyboardWedgeDetector();
      for (final (i, c) in 'CNC'.split('').indexed) {
        d.addChar(c, at(i * 120));
      }
      expect(d.enter(at(250)), isNull);
      d
        ..addChar('A', at(1000))
        ..addChar('B', at(1010));
      expect(d.enter(at(1020)), isNull, reason: 'shorter than 3');
      for (final (i, c) in 'XYZ1'.split('').indexed) {
        d.addChar(c, at(2000 + i * 10));
      }
      expect(d.enter(at(2200)), isNull, reason: 'Enter came too late');
    });

    test('a slow keystroke before a fast burst is dropped from the scan', () {
      final d = KeyboardWedgeDetector()..addChar('q', at(0));
      for (final (i, c) in 'LOC:BLD-A-F2'.split('').indexed) {
        d.addChar(c, at(300 + i * 8));
      }
      expect(d.enter(at(400)), 'LOC:BLD-A-F2');
    });

    test('scanner label types map to formats', () {
      expect(formatFromLabelType('LABEL-TYPE-QRCODE'), 'qr');
      expect(formatFromLabelType('LABEL-TYPE-EAN13'), 'ean13');
      expect(formatFromLabelType('Code 128'), 'code128');
      expect(formatFromLabelType(null), 'barcode');
    });
  });

  group('NDEF decoding', () {
    Uint8List b(List<int> x) => Uint8List.fromList(x);

    test('text, URI, MIME JSON and unknown records; value = first text/URI else NFC:UID', () {
      final text = decodeNdefRecord(
        tnf: 1,
        type: b('T'.codeUnits),
        payload: b([2, ...'en'.codeUnits, ...utf8.encode('Pump Room')]),
      );
      expect((text.kind, text.value, text.language), (NdefKind.text, 'Pump Room', 'en'));
      final uri = decodeNdefRecord(tnf: 1, type: b('U'.codeUnits), payload: b([4, ...'purpleiq.ai'.codeUnits]));
      expect((uri.kind, uri.value), (NdefKind.uri, 'https://purpleiq.ai'));
      final json = decodeNdefRecord(tnf: 2, type: b('application/json'.codeUnits), payload: b(utf8.encode('{"a":1}')));
      expect((json.kind, json.value), (NdefKind.mime, '{"a":1}'));
      final raw = decodeNdefRecord(tnf: 5, type: b([]), payload: b([0xDE, 0xAD]));
      expect((raw.kind, raw.value), (NdefKind.unknown, 'DE AD'));
      expect(formatUid([4, 0xa2, 0x3b]), '04:A2:3B');

      expect(nfcValue('04:A2', [json, uri, text]), 'https://purpleiq.ai');
      expect(nfcValue('04:A2', [json, raw]), 'NFC:04:A2');
      final round = NdefRecordInfo.decodeList(NdefRecordInfo.encodeList([text, uri]));
      expect(round.map((r) => (r.kind, r.value, r.language)), [
        (NdefKind.text, 'Pump Room', 'en'),
        (NdefKind.uri, 'https://purpleiq.ai', null),
      ]);
    });
  });
}
