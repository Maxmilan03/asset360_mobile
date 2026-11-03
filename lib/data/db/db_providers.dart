import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/db/app_database.dart';

export 'package:asset360_mobile/data/db/app_database.dart';
export 'package:asset360_mobile/data/db/location_seed.dart' show DbLocationX, DbLocationPath;

/// The on-device database, opened once for the app's lifetime.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Every location, in tree order (site, its buildings, their floors, their rooms).
final locationsProvider = StreamProvider<List<DbLocation>>((ref) => ref.watch(appDatabaseProvider).watchLocations());

final tagLinksProvider = StreamProvider<List<TagLink>>((ref) => ref.watch(appDatabaseProvider).watchTagLinks());

/// Saved scans for the Local Data filters, newest first.
final scanLogProvider = StreamProvider.family<List<ScanLogEntry>, ScanFilter>(
  (ref, filter) => ref.watch(appDatabaseProvider).watchScans(filter),
);

final scanLogEntryProvider = StreamProvider.family<ScanLogEntry?, int>(
  (ref, id) => ref.watch(appDatabaseProvider).watchScan(id),
);

final scanFormatsProvider = StreamProvider<List<String>>((ref) => ref.watch(appDatabaseProvider).watchFormats());

/// Total scans, today, NFC, QR / barcode and linked tags. "Today" is the device's real day
/// (scans carry real timestamps; DemoClock is for the demo data only).
final scanStatsProvider = StreamProvider<ScanStats>((ref) {
  final now = DateTime.now();
  return ref.watch(appDatabaseProvider).watchStats(DateTime(now.year, now.month, now.day));
});
