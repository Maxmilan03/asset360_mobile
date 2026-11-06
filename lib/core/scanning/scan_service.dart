import 'dart:async';
import 'dart:io' show Platform;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/platform/app_launcher.dart';
import 'package:asset360_mobile/core/scanning/live_asset_lookup.dart';
import 'package:asset360_mobile/core/scanning/scan_event.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_repository.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';

export 'package:asset360_mobile/core/scanning/live_asset_lookup.dart' show LiveLookup, LiveLookupStatus;
export 'package:asset360_mobile/core/scanning/scan_event.dart';
export 'package:asset360_mobile/data/db/location_seed.dart' show DbLocationX, DbLocationPath;

/// Prefix of a printed location label: "LOC:BLD-A-F2" (a location code). "LOC:Building / Floor – Zone"
/// (the older demo tags) still works.
const locPrefix = 'LOC:';

/// A thing a code can point at: (id, label).
typedef ScanMatch = ({String id, String label});

/// Every scan from any source goes through here: duplicate guard, match, ScanLog row.
///
/// Match order: 1) TagLinks by tag key, 2) "LOC:" + location code, 3) asset ID / barcode / tag
/// (then part number), 4) none. API mode: step 3 asks the Asset service ([lookupAsset]:
/// GET /api/asset-registrations/lookup) instead of the mock register, and locations come from the
/// Master Data tree ([findMasterLocation]): a location tag link holds the Master Data location id,
/// and "LOC:<code>" matches the location's `code`.
class ScanService {
  ScanService(
    this.db, {
    required this.findAsset,
    this.findPart,
    this.lookupAsset,
    this.findMasterLocation,
    DateTime Function()? clock,
    String? deviceInfo,
    this.duplicateWindow = const Duration(seconds: 2),
  }) : clock = clock ?? DateTime.now,
       _deviceInfo = deviceInfo;

  final AppDatabase db;
  final ScanMatch? Function(String code) findAsset;
  final ScanMatch? Function(String code)? findPart;

  /// API mode: the live asset lookup (wins over [findAsset]).
  final Future<LiveLookup> Function(ScanEvent e)? lookupAsset;

  /// API mode: the Master Data location with this id or code (path from the country down), or an
  /// empty path when there is none. Throws when the tree cannot be loaded.
  final Future<MdLocationPath> Function({String? id, String? code})? findMasterLocation;
  final DateTime Function() clock;
  final String? _deviceInfo;
  final Duration duplicateWindow;

  /// Saved on every ScanLog row: the fixed test value, else the device's model and OS.
  String get deviceInfo => _deviceInfo ?? deviceLabel;

  (String, DateTime)? _last;

  /// Saves and resolves [e]. Null when the same value was scanned less than [duplicateWindow] ago.
  Future<ScanResult?> submit(ScanEvent e) async {
    final value = e.value.trim();
    if (value.isEmpty) return null;
    final now = clock();
    final last = _last;
    if (last != null && last.$1 == value && now.difference(last.$2) < duplicateWindow) return null;
    _last = (value, now);
    final r = await resolve(e);
    final id = await db.addScan(
      ScanLogCompanion.insert(
        value: value,
        format: e.format,
        source: e.source,
        nfcUid: Value(e.nfcUid),
        nfcRecords: Value(e.nfcRecords == null ? null : NdefRecordInfo.encodeList(e.nfcRecords!)),
        matchType: r.matchType,
        matchId: Value(r.matchId),
        matchLabel: Value(r.matchLabel),
        scannedAt: now,
        deviceInfo: deviceInfo,
      ),
    );
    return ScanResult(
      event: e,
      matchType: r.matchType,
      matchId: r.matchId,
      matchLabel: r.matchLabel,
      location: r.location,
      masterLocation: r.masterLocation,
      logId: id,
      viaLink: r.viaLink,
      problem: r.problem,
      candidates: r.candidates,
    );
  }

  /// Matches [e] without saving it.
  Future<ScanResult> resolve(ScanEvent e) async {
    final value = e.value.trim();
    // 1) A linked tag.
    for (final key in {e.tagKey, value}) {
      final link = await db.linkByKey(key);
      if (link == null) continue;
      switch (link.targetType) {
        case LinkTarget.location:
          if (findMasterLocation case final find?) {
            final r = await _master(e, () => find(id: link.targetId), viaLink: true);
            if (r != null) return r;
            continue;
          }
          final loc = await db.locationByCode(link.targetId);
          if (loc != null) return _location(e, loc, viaLink: true);
        case LinkTarget.asset:
          final a = findAsset(link.targetId);
          return ScanResult(
            event: e,
            matchType: MatchType.asset,
            matchId: a?.id ?? link.targetId,
            matchLabel: a?.label ?? link.label,
            viaLink: true,
          );
      }
    }
    // 2) A printed location label.
    if (value.toUpperCase().startsWith(locPrefix)) {
      final rest = value.substring(locPrefix.length).trim();
      if (findMasterLocation case final find?) {
        final r = await _master(e, () => find(code: rest));
        if (r != null) return r;
      } else {
        final loc = await db.locationByCode(rest) ?? await _locationByPath(rest);
        if (loc != null) return _location(e, loc);
      }
    }
    // 3) An asset, then a spare part.
    if (lookupAsset case final lookup?) {
      try {
        final r = await lookup(e);
        switch (r.status) {
          case LiveLookupStatus.found:
            return ScanResult(event: e, matchType: MatchType.asset, matchId: r.id, matchLabel: r.label);
          case LiveLookupStatus.ambiguous:
            return ScanResult(event: e, matchType: MatchType.none, problem: r.message, candidates: r.ids);
          case LiveLookupStatus.notFound:
            break;
        }
      } catch (x) {
        return ScanResult(
          event: e,
          matchType: MatchType.none,
          problem: 'Could not look up this code: ${ApiException.from(x).message}',
        );
      }
    } else if (findAsset(value) case final a?) {
      return ScanResult(event: e, matchType: MatchType.asset, matchId: a.id, matchLabel: a.label);
    }
    if (findPart?.call(value) case final p?) {
      return ScanResult(event: e, matchType: MatchType.part, matchId: p.id, matchLabel: p.label);
    }
    // 4) Unknown.
    return ScanResult(event: e, matchType: MatchType.none);
  }

  ScanResult _location(ScanEvent e, DbLocation loc, {bool viaLink = false}) => ScanResult(
    event: e,
    matchType: MatchType.location,
    matchId: loc.code,
    matchLabel: loc.label,
    location: loc,
    viaLink: viaLink,
  );

  /// A Master Data location match, null when [find] found nothing, or a problem result when the
  /// location tree could not be loaded.
  Future<ScanResult?> _master(ScanEvent e, Future<MdLocationPath> Function() find, {bool viaLink = false}) async {
    try {
      final path = await find();
      return path.isEmpty ? null : _masterResult(e, path, viaLink: viaLink);
    } catch (x) {
      return ScanResult(
        event: e,
        matchType: MatchType.none,
        problem: 'Could not load the locations: ${ApiException.from(x).message}',
      );
    }
  }

  ScanResult _masterResult(ScanEvent e, MdLocationPath path, {bool viaLink = false}) => ScanResult(
    event: e,
    matchType: MatchType.location,
    matchId: path.deepest!.id,
    matchLabel: path.label,
    masterLocation: path,
    viaLink: viaLink,
  );

  /// API mode: links the tag of [r] to a Master Data location (its real id) and updates the ScanLog row.
  Future<ScanResult> linkToMasterLocation(ScanResult r, MdLocationPath path) async {
    await db.linkTag(
      tagKey: r.event.tagKey,
      tagType: r.event.tagType,
      targetType: LinkTarget.location,
      targetId: path.deepest!.id,
      label: path.label,
      createdAt: clock(),
    );
    return _relink(r, _masterResult(r.event, path, viaLink: true));
  }

  Future<DbLocation?> _locationByPath(String path) async {
    final p = path.toLowerCase();
    return (await db.allLocations()).firstWhereOrNull((l) => l.path.toLowerCase() == p);
  }

  /// Links the tag of [e] to a location and updates its ScanLog row. Returns the new result.
  Future<ScanResult> linkToLocation(ScanResult r, DbLocation loc) async {
    await db.linkTag(
      tagKey: r.event.tagKey,
      tagType: r.event.tagType,
      targetType: LinkTarget.location,
      targetId: loc.code,
      label: loc.label,
      createdAt: clock(),
    );
    return _relink(r, _location(r.event, loc, viaLink: true));
  }

  /// Links the tag of [e] to an asset and updates its ScanLog row. Returns the new result.
  /// API mode: [assetId] is the assetRegistrationId and [label] its "AR000001 – name".
  Future<ScanResult> linkToAsset(ScanResult r, String assetId, {String? label}) async {
    final a = findAsset(assetId);
    await db.linkTag(
      tagKey: r.event.tagKey,
      tagType: r.event.tagType,
      targetType: LinkTarget.asset,
      targetId: assetId,
      label: label ?? a?.label ?? assetId,
      createdAt: clock(),
    );
    return _relink(
      r,
      ScanResult(
        event: r.event,
        matchType: MatchType.asset,
        matchId: assetId,
        matchLabel: label ?? a?.label ?? assetId,
        viaLink: true,
      ),
    );
  }

  Future<ScanResult> _relink(ScanResult old, ScanResult next) async {
    if (old.logId case final id?) await db.setScanMatch(id, next.matchType, next.matchId, next.matchLabel);
    return ScanResult(
      event: next.event,
      matchType: next.matchType,
      matchId: next.matchId,
      matchLabel: next.matchLabel,
      location: next.location,
      masterLocation: next.masterLocation,
      logId: old.logId,
      viaLink: true,
    );
  }
}

/// This device, for ScanLog.deviceInfo: the platform name until [loadDeviceLabel] has asked the
/// platform for the model ("Zebra TC52 · Android 11").
String deviceLabel = kIsWeb ? 'web' : Platform.operatingSystem;

Future<void> loadDeviceLabel() async {
  if (await AppLauncher.deviceInfo() case final info? when info.isNotEmpty) deviceLabel = info;
}

/// A [ScanEvent] rebuilt from a saved row (Local Data → Link this tag).
ScanEvent scanEventOf(ScanLogEntry row) => ScanEvent(
  value: row.value,
  format: row.format,
  source: row.source,
  nfcUid: row.nfcUid,
  nfcRecords: row.nfcRecords == null ? null : NdefRecordInfo.decodeList(row.nfcRecords),
);

final scanServiceProvider = Provider<ScanService>(
  (ref) => ScanService(
    ref.watch(appDatabaseProvider),
    // API mode: never the mock register (assets come from the server lookup).
    findAsset: (code) => apiMode
        ? null
        : switch (ref.read(assetsProvider).byCode(code)) {
            final a? => (id: a.id, label: '${a.id} – ${a.name}'),
            null => null,
          },
    lookupAsset: apiMode ? (e) => ref.read(liveAssetLookupProvider).findEvent(e) : null,
    findMasterLocation: apiMode
        ? ({id, code}) async {
            final tree = await ref.read(mdLocationTreeProvider.future);
            return tree.pathTo(id != null ? tree.byId(id) : tree.byCode(code));
          }
        : null,
    findPart: (code) {
      final c = code.trim().toUpperCase();
      final p = ref.read(inventoryProvider).parts.firstWhereOrNull((p) => p.id.toUpperCase() == c);
      return p == null ? null : (id: p.id, label: '${p.id} – ${p.name}');
    },
  ),
);

// ---------------------------------------------------------------- Targets

/// A visible widget that wants scans of some match types (a LocationField, an asset field,
/// the Scan screen). The most recently registered one that accepts a result receives it.
class ScanTarget {
  ScanTarget({required this.accepts, required this.onScan, this.debugLabel});

  final Set<MatchType> accepts;
  final FutureOr<void> Function(ScanResult result) onScan;
  final String? debugLabel;

  static const all = {MatchType.asset, MatchType.location, MatchType.part, MatchType.none};
}

class ScanTargets {
  final _stack = <ScanTarget>[];

  void register(ScanTarget t) {
    _stack
      ..remove(t)
      ..add(t);
  }

  void unregister(ScanTarget t) => _stack.remove(t);

  bool get isEmpty => _stack.isEmpty;

  /// The topmost target that accepts [type].
  ScanTarget? topFor(MatchType type) => _stack.reversed.firstWhereOrNull((t) => t.accepts.contains(type));

  @visibleForTesting
  List<ScanTarget> get stack => List.unmodifiable(_stack);
}

final scanTargetsProvider = Provider<ScanTargets>((_) => ScanTargets());
