import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/movements_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/mock/people_mock.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';

class MovementsNotifier extends Notifier<List<MovementRequest>> {
  @override
  List<MovementRequest> build() => seedMovements();

  String get _me => ref.read(currentUserProvider).name;
  LogEntry _log(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  MovementRequest? byId(String id) => state.firstWhereOrNull((m) => m.id == id);
  void _update(String id, MovementRequest Function(MovementRequest) f) {
    state = replaceWhere(state, id, (m) => m.id, f);
    _q(id);
  }

  /// Offline: the movement goes into the sync queue as an asset update.
  void _q(String id) {
    final m = byId(id);
    if (m != null) ref.queueOffline(SyncKind.asset, m.assetId, '${m.type} ${m.id} · ${m.status}', refId: m.assetId);
  }

  String get nextMovId => nextId('MOV-2026-', state.map((m) => m.id));

  /// Submits a request. Transfers wait for approval; other types complete at once.
  String submit({
    required String assetId,
    required String type,
    required MovePlace from,
    required MovePlace to,
    String? newCustodian,
    DateTime? requiredDate,
    String? reason,
    String? remarks,
    List<Attachment> attachments = const [],
    String approverId = PersonIds.ahmed,
    String? condition,
    List<String> photos = const [],
  }) {
    final id = nextMovId;
    final asset = ref.read(assetByIdProvider(assetId));
    final needsApproval = type == MoveType.transfer;
    state = [
      MovementRequest(
        id: id,
        assetId: assetId,
        type: type,
        status: needsApproval ? MoveStatus.pending : MoveStatus.completed,
        from: from,
        to: to,
        requesterId: ref.read(currentUserProvider).id,
        approverId: needsApproval ? approverId : null,
        fromCustodian: asset?.custodian,
        newCustodian: newCustodian,
        createdAt: DemoClock.now,
        requiredDate: requiredDate,
        reason: reason,
        remarks: remarks,
        attachments: attachments,
        condition: condition,
        photos: photos,
        timeline: [_log('Submitted'), if (!needsApproval) _log('Completed')],
      ),
      ...state,
    ];
    if (!needsApproval) _applyToAsset(id);
    _q(id);
    for (final p in photos) {
      ref.queueOffline(SyncKind.photo, syncFileName(p), 'Movement Photo', refId: assetId);
    }
    return id;
  }

  void approve(String id) =>
      _update(id, (m) => m.copyWith(status: MoveStatus.approved, timeline: [...m.timeline, _log('Approved')]));

  void reject(String id, String reason) => _update(
    id,
    (m) => m.copyWith(
      status: MoveStatus.rejected,
      rejectReason: reason,
      timeline: [...m.timeline, _log('Rejected', reason)],
    ),
  );

  void cancel(String id) =>
      _update(id, (m) => m.copyWith(status: MoveStatus.cancelled, timeline: [...m.timeline, _log('Cancelled')]));

  /// Approved → In Transit (the asset shows In Transit until received).
  void dispatch(String id) {
    _update(id, (m) => m.copyWith(status: MoveStatus.inTransit, timeline: [...m.timeline, _log('In Transit')]));
    final m = byId(id)!;
    ref.read(assetsProvider.notifier).setStatus(m.assetId, AssetStatus.inTransit);
  }

  /// "Mark as Received": completes the move and updates the asset.
  void markReceived(String id) {
    _update(id, (m) => m.copyWith(status: MoveStatus.completed, timeline: [...m.timeline, _log('Completed')]));
    _applyToAsset(id);
  }

  void _applyToAsset(String id) {
    final m = byId(id)!;
    final assets = ref.read(assetsProvider.notifier);
    final place = m.to.assetLocation ?? [m.to.name, ...m.to.lines].join(' – ');
    // A check-out at the asset's current place changes the custodian only.
    final current = ref.read(assetByIdProvider(m.assetId))?.location;
    if (m.type != MoveType.assign && place.isNotEmpty && place != current) assets.setLocation(m.assetId, place);
    if (m.condition != null) {
      final a = ref.read(assetByIdProvider(m.assetId));
      if (a != null) assets.update(a.copyWith(condition: m.condition, photos: [...a.photos, ...m.photos]));
    }
    if (m.type == MoveType.checkIn || m.type == MoveType.returnAsset) {
      assets.setCustodian(m.assetId, 'Unassigned');
    } else if (m.newCustodian != null) {
      assets.setCustodian(m.assetId, m.newCustodian!);
    }
    final asset = ref.read(assetByIdProvider(m.assetId));
    if (asset?.status == AssetStatus.inTransit) assets.setStatus(m.assetId, AssetStatus.active);
  }
}

final movementsProvider = NotifierProvider<MovementsNotifier, List<MovementRequest>>(MovementsNotifier.new);

final movementByIdProvider = Provider.family<MovementRequest?, String>(
  (ref, id) => ref.watch(movementsProvider).firstWhereOrNull((m) => m.id == id),
);

extension MovementQueries on List<MovementRequest> {
  List<MovementRequest> mine(String userId) => where((m) => m.requesterId == userId).toList();
  List<MovementRequest> get pending => where((m) => m.status == MoveStatus.pending).toList();

  /// Home "Approvals – Pending" and My Approvals.
  List<MovementRequest> toApprove(String userId) =>
      where((m) => m.status == MoveStatus.pending && m.approverId == userId).toList();
  List<MovementRequest> get completed => where((m) => m.status == MoveStatus.completed).toList();

  /// Search by asset ID, asset name ([nameOf]) or request number.
  List<MovementRequest> search(String q, String Function(String assetId) nameOf) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return this;
    return where(
      (m) =>
          m.id.toLowerCase().contains(s) ||
          m.assetId.toLowerCase().contains(s) ||
          nameOf(m.assetId).toLowerCase().contains(s),
    ).toList();
  }

  List<MovementRequest> forAsset(String assetId) => where((m) => m.assetId == assetId).toList();

  /// Assets currently checked out (latest record per asset is a Check Out).
  List<String> get checkedOutAssetIds {
    final latest = <String, MovementRequest>{};
    for (final m in [...this]..sort((a, b) => a.createdAt.compareTo(b.createdAt))) {
      if (m.status == MoveStatus.completed) latest[m.assetId] = m;
    }
    return [
      for (final e in latest.entries)
        if (e.value.type == MoveType.checkOut) e.key,
    ];
  }
}
