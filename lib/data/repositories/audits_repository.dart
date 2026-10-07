import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/audits_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';

class AuditsNotifier extends Notifier<List<Audit>> {
  @override
  List<Audit> build() => seedAudits();

  Audit? byId(String id) => state.firstWhereOrNull((a) => a.id == id);
  void _update(String id, Audit Function(Audit) f, {String change = 'Updated'}) {
    state = replaceWhere(state, id, (a) => a.id, f);
    // Offline: audit results also go into the sync queue.
    final a = byId(id);
    if (a != null) ref.queueOffline(SyncKind.other, id, 'Asset Audit · $change', refId: id);
  }

  String get _me => ref.read(currentUserProvider).name;

  /// Create Audit Campaign: a Pending audit whose total is the number of assets in scope.
  String create({
    required String name,
    required String site,
    required DateTime start,
    required DateTime end,
    List<String> scopeLocations = const [],
    List<String> scopeCategories = const [],
    List<String> auditorIds = const [],
    bool blindCount = false,
  }) {
    final id = nextId('AUD-2026-', state.map((a) => a.id), width: 3);
    final me = ref.read(currentUserProvider).id;
    final draft = Audit(
      id: id,
      name: name,
      site: site,
      start: start,
      end: end,
      totalAssets: 0,
      status: AuditStatus.pending,
      auditorId: me,
      auditorIds: auditorIds.where((a) => a != me).toList(),
      scopeLocations: scopeLocations,
      scopeCategories: scopeCategories,
      blindCount: blindCount,
      imagePath: auditSiteImages[site],
    );
    state = [draft.copyWith(totalAssets: auditScope(draft, ref.read(assetsProvider)).length), ...state];
    return id;
  }

  /// Saves an audit action for an asset; the matching counter goes up by one.
  /// A re-audit of the same asset replaces its earlier result. With [updateLocation] the asset
  /// moves to the scanned location and a completed "Audit Correction" movement is recorded.
  void record(String auditId, AuditEntry entry, {bool updateLocation = false}) {
    var e = entry;
    final asset = ref.read(assetByIdProvider(entry.assetId));
    if (updateLocation && asset != null && entry.location != null && entry.location != asset.location) {
      ref
          .read(movementsProvider.notifier)
          .submit(
            assetId: asset.id,
            type: MoveType.auditCorrection,
            from: MovePlace(asset.location, asset.site, null, asset.location),
            to: MovePlace(entry.location!, asset.site, null, entry.location),
            reason: 'Asset audit',
            remarks: '${byId(auditId)?.name ?? auditId}: found at ${entry.location}',
          );
      e = AuditEntry(
        assetId: entry.assetId,
        result: entry.result,
        at: entry.at,
        location: entry.location,
        expectedLocation: entry.expectedLocation,
        condition: entry.condition,
        remarks: entry.remarks,
        photos: entry.photos,
        method: entry.method,
        by: entry.by,
        description: entry.description,
        locationUpdated: true,
      );
    }
    _update(auditId, (a) {
      final prev = a.entryFor(e.assetId);
      int bump(String result, int v) => v + (e.result == result ? 1 : 0) - (prev?.result == result ? 1 : 0);
      return a.copyWith(
        status: a.status == AuditStatus.pending || a.status == AuditStatus.paused ? AuditStatus.inProgress : a.status,
        verified: bump(AuditResult.verified, a.verified),
        wrongLocation: bump(AuditResult.wrongLocation, a.wrongLocation),
        notFound: bump(AuditResult.notFound, a.notFound),
        unregistered: bump(AuditResult.unregistered, a.unregistered),
        entries: [e, ...a.entries.where((x) => x.assetId != e.assetId)],
      );
    }, change: '${e.assetId} ${e.result}');
    final audit = byId(auditId);
    if (e.result != AuditResult.unregistered && asset != null && audit != null) {
      ref.read(assetsProvider.notifier).addEvent(e.assetId, 'Audited: ${e.result}', note: audit.name);
    }
  }

  /// "Unregistered asset found": records it under a temporary tag and returns the tag.
  String recordUnregistered(
    String auditId, {
    required String code,
    required String description,
    String? location,
    List<String> photos = const [],
    String? method,
  }) {
    final tag = code.trim().isEmpty ? nextUnregisteredTag() : code.trim();
    record(
      auditId,
      AuditEntry(
        assetId: tag,
        result: AuditResult.unregistered,
        at: DemoClock.now,
        location: location,
        description: description,
        photos: photos,
        method: method,
        by: _me,
      ),
    );
    return tag;
  }

  void start(String id) => _update(id, (a) => a.copyWith(status: AuditStatus.inProgress));
  void pause(String id) => _update(id, (a) => a.copyWith(status: AuditStatus.paused));

  /// Complete Audit: every unscanned asset becomes Not Found (detailed ones get an entry).
  void complete(String id) {
    final a = byId(id);
    if (a == null) return;
    final unscanned = unscannedAssets(a, ref.read(assetsProvider)).take(a.remaining);
    _update(
      id,
      (a) => a.copyWith(
        status: AuditStatus.completed,
        completedAt: DemoClock.now,
        notFound: a.notFound + a.remaining,
        entries: [
          for (final asset in unscanned)
            AuditEntry(
              assetId: asset.id,
              result: AuditResult.notFound,
              at: DemoClock.now,
              expectedLocation: asset.location,
              method: AuditMethod.auto,
              by: _me,
              remarks: 'Not scanned before the audit was completed',
            ),
          ...a.entries,
        ],
      ),
    );
  }

  /// Temporary tag for an unregistered asset found during an audit.
  String nextUnregisteredTag() {
    final used = {for (final a in state) ...a.entries.map((e) => e.assetId)};
    var n = 10022;
    while (used.contains('UNREG-$n')) {
      n++;
    }
    return 'UNREG-$n';
  }
}

final auditsProvider = NotifierProvider<AuditsNotifier, List<Audit>>(AuditsNotifier.new);

final auditByIdProvider = Provider.family<Audit?, String>(
  (ref, id) => ref.watch(auditsProvider).firstWhereOrNull((a) => a.id == id),
);

/// Detailed asset records inside an audit's scope (site, then buildings / categories when set).
List<Asset> auditScope(Audit a, List<Asset> assets) => assets
    .where(
      (x) =>
          x.site == a.site &&
          (a.scopeLocations.isEmpty || a.scopeLocations.any((l) => x.location.contains(l))) &&
          (a.scopeCategories.isEmpty || a.scopeCategories.contains(x.category)),
    )
    .toList();

/// In-scope detailed assets that have no result yet.
List<Asset> unscannedAssets(Audit a, List<Asset> assets) =>
    auditScope(a, assets).where((x) => a.entryFor(x.id) == null).toList();

extension AuditQueries on List<Audit> {
  /// Audits the user leads or is an auditor on (tile "My Audits", tab "My Audits").
  List<Audit> mine(String userId) => where((a) => a.isAssignedTo(userId)).toList();

  /// Not completed yet (tab "Assigned").
  List<Audit> assigned(String userId) =>
      where((a) => a.isAssignedTo(userId) && a.status != AuditStatus.completed).toList();
  List<Audit> get completed => where((a) => a.status == AuditStatus.completed).toList();
  List<Audit> withStatus(String s) => where((a) => a.status == s).toList();
}
