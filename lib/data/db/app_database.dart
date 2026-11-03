import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:asset360_mobile/data/db/location_seed.dart';

part 'app_database.g.dart';

/// How a scan reached the app.
enum ScanSource { camera, nfc, hht, manual }

/// What a scan resolved to. [part] keeps the inventory part lookup the scanner already had.
enum MatchType { asset, location, part, none }

/// Level of a row in [Locations].
enum LocationLevel { site, building, floor, room }

/// What kind of tag a [TagLinks] row describes.
enum TagType { qr, barcode, nfc }

/// What a tag is linked to.
enum LinkTarget { location, asset }

/// Every scan from any source (camera, NFC, HHT, manual entry), newest last.
@DataClassName('ScanLogEntry')
class ScanLog extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Raw text: the barcode / QR value, the first NDEF text or URI record, or "NFC:" + the UID.
  TextColumn get value => text()();

  /// qr, code128, ean13, datamatrix, nfc, manual …
  TextColumn get format => text()();
  TextColumn get source => textEnum<ScanSource>()();
  TextColumn get nfcUid => text().nullable()();

  /// JSON list of the decoded NDEF records (see `NdefRecordInfo`).
  TextColumn get nfcRecords => text().nullable()();
  TextColumn get matchType => textEnum<MatchType>()();
  TextColumn get matchId => text().nullable()();
  TextColumn get matchLabel => text().nullable()();
  DateTimeColumn get scannedAt => dateTime()();
  TextColumn get deviceInfo => text()();
}

/// Site → Building → Floor → Room, one row per node, each with a printable [code].
@DataClassName('DbLocation')
class Locations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get site => text()();
  TextColumn get building => text().nullable()();
  TextColumn get floor => text().nullable()();
  TextColumn get room => text().nullable()();
  TextColumn get level => textEnum<LocationLevel>()();
}

/// A tag (barcode / QR value or "NFC:" + UID) linked to a location or an asset.
@DataClassName('TagLink')
class TagLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tagKey => text().unique()();
  TextColumn get tagType => textEnum<TagType>()();
  TextColumn get targetType => textEnum<LinkTarget>()();
  TextColumn get targetId => text()();
  TextColumn get label => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Local Data filters (all optional).
class ScanFilter {
  const ScanFilter({
    this.query = '',
    this.nfcOnly,
    this.sources = const {},
    this.formats = const {},
    this.matches = const {},
    this.from,
    this.to,
  });

  final String query;

  /// true = NFC tab, false = QR & Barcode tab, null = all.
  final bool? nfcOnly;
  final Set<ScanSource> sources;
  final Set<String> formats;
  final Set<MatchType> matches;
  final DateTime? from;

  /// Exclusive end.
  final DateTime? to;

  bool get isFiltered => sources.isNotEmpty || formats.isNotEmpty || matches.isNotEmpty || from != null || to != null;

  @override
  bool operator ==(Object other) =>
      other is ScanFilter &&
      other.query == query &&
      other.nfcOnly == nfcOnly &&
      _setEq.equals(other.sources, sources) &&
      _setEq.equals(other.formats, formats) &&
      _setEq.equals(other.matches, matches) &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode =>
      Object.hash(query, nfcOnly, _setEq.hash(sources), _setEq.hash(formats), _setEq.hash(matches), from, to);

  static const _setEq = SetEquality<Object>();

  ScanFilter copyWith({
    String? query,
    bool? Function()? nfcOnly,
    Set<ScanSource>? sources,
    Set<String>? formats,
    Set<MatchType>? matches,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) => ScanFilter(
    query: query ?? this.query,
    nfcOnly: nfcOnly != null ? nfcOnly() : this.nfcOnly,
    sources: sources ?? this.sources,
    formats: formats ?? this.formats,
    matches: matches ?? this.matches,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
  );
}

/// Header figures of the Local Data screen.
typedef ScanStats = ({int total, int today, int nfc, int codes, int links});

@DriftDatabase(tables: [ScanLog, Locations, TagLinks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openAppDatabase());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // First launch: the location tree the mock data already uses.
      await batch((b) => b.insertAll(locations, seedLocationRows()));
    },
  );

  // ---------------------------------------------------------------- Scans

  Future<int> addScan(ScanLogCompanion row) => into(scanLog).insert(row);

  /// Puts a deleted row back with its old id (Undo).
  Future<void> restoreScan(ScanLogEntry row) => into(scanLog).insert(row, mode: InsertMode.insertOrReplace);

  Future<int> deleteScan(int id) => (delete(scanLog)..where((s) => s.id.equals(id))).go();

  Future<int> clearScans() => delete(scanLog).go();

  Future<void> setScanMatch(int id, MatchType type, String? matchId, String? label) =>
      (update(scanLog)..where((s) => s.id.equals(id))).write(
        ScanLogCompanion(matchType: Value(type), matchId: Value(matchId), matchLabel: Value(label)),
      );

  Stream<ScanLogEntry?> watchScan(int id) => (select(scanLog)..where((s) => s.id.equals(id))).watchSingleOrNull();

  /// Newest first.
  Stream<List<ScanLogEntry>> watchScans([ScanFilter f = const ScanFilter()]) {
    final q = select(scanLog)..orderBy([(s) => OrderingTerm.desc(s.scannedAt), (s) => OrderingTerm.desc(s.id)]);
    q.where((s) {
      Expression<bool> e = const Constant(true);
      final text = f.query.trim();
      if (text.isNotEmpty) {
        final like = '%${text.toLowerCase()}%';
        e = e & (s.value.lower().like(like) | s.matchLabel.lower().like(like) | s.nfcUid.lower().like(like));
      }
      final nfc = s.format.equals('nfc') | s.source.equalsValue(ScanSource.nfc);
      if (f.nfcOnly == true) e = e & nfc;
      if (f.nfcOnly == false) e = e & nfc.not();
      if (f.sources.isNotEmpty) e = e & s.source.isIn([for (final x in f.sources) x.name]);
      if (f.formats.isNotEmpty) e = e & s.format.isIn(f.formats);
      if (f.matches.isNotEmpty) e = e & s.matchType.isIn([for (final x in f.matches) x.name]);
      if (f.from case final from?) e = e & s.scannedAt.isBiggerOrEqualValue(from);
      if (f.to case final to?) e = e & s.scannedAt.isSmallerThanValue(to);
      return e;
    });
    return q.watch();
  }

  /// Distinct formats seen so far (Local Data filter options).
  Stream<List<String>> watchFormats() {
    final q = selectOnly(scanLog, distinct: true)
      ..addColumns([scanLog.format])
      ..orderBy([OrderingTerm.asc(scanLog.format)]);
    return q.map((r) => r.read(scanLog.format)!).watch();
  }

  /// One query over both tables, so it re-runs when either changes.
  Stream<ScanStats> watchStats(DateTime startOfToday) =>
      customSelect(
        'SELECT (SELECT COUNT(*) FROM scan_log) AS total, '
        '(SELECT COUNT(*) FROM scan_log WHERE scanned_at >= ?1) AS today, '
        "(SELECT COUNT(*) FROM scan_log WHERE format = 'nfc' OR source = 'nfc') AS nfc, "
        '(SELECT COUNT(*) FROM tag_links) AS links',
        variables: [Variable.withDateTime(startOfToday)],
        readsFrom: {scanLog, tagLinks},
      ).watchSingle().map((r) {
        final total = r.read<int>('total');
        final nfc = r.read<int>('nfc');
        return (total: total, today: r.read<int>('today'), nfc: nfc, codes: total - nfc, links: r.read<int>('links'));
      });

  // ---------------------------------------------------------------- Locations

  Future<List<DbLocation>> allLocations() => select(locations).get();

  Stream<List<DbLocation>> watchLocations() => (select(locations)..orderBy([(l) => OrderingTerm.asc(l.id)])).watch();

  Future<DbLocation?> locationByCode(String code) =>
      (select(locations)..where((l) => l.code.upper().equals(code.trim().toUpperCase()))).getSingleOrNull();

  Future<DbLocation?> locationById(int id) => (select(locations)..where((l) => l.id.equals(id))).getSingleOrNull();

  // ---------------------------------------------------------------- Tag links

  Stream<List<TagLink>> watchTagLinks() =>
      (select(tagLinks)..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)])).watch();

  Future<TagLink?> linkByKey(String tagKey) =>
      (select(tagLinks)..where((t) => t.tagKey.equals(tagKey))).getSingleOrNull();

  /// Links [tagKey] (replacing an existing link of the same tag).
  Future<void> linkTag({
    required String tagKey,
    required TagType tagType,
    required LinkTarget targetType,
    required String targetId,
    required String label,
    required DateTime createdAt,
  }) => into(tagLinks).insert(
    TagLinksCompanion.insert(
      tagKey: tagKey,
      tagType: tagType,
      targetType: targetType,
      targetId: targetId,
      label: label,
      createdAt: createdAt,
    ),
    onConflict: DoUpdate(
      (_) => TagLinksCompanion(
        targetType: Value(targetType),
        targetId: Value(targetId),
        label: Value(label),
        createdAt: Value(createdAt),
      ),
      target: [tagLinks.tagKey],
    ),
  );

  Future<int> unlinkTag(int id) => (delete(tagLinks)..where((t) => t.id.equals(id))).go();
}

/// Opens the on-device database (drift_flutter runs queries on a background isolate).
/// Tests replace it with an in-memory database (test/flutter_test_config.dart).
QueryExecutor Function() openAppDatabase = () => driftDatabase(name: 'asset360');
