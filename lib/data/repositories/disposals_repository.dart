import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/models/disposal.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';

/// Disposal requests (More Actions → Create Disposal Request). None are seeded.
/// The signed-in user approves their own requests in Home → Approvals (demo).
class DisposalsNotifier extends Notifier<List<DisposalRequest>> {
  @override
  List<DisposalRequest> build() => const [];

  String get _me => ref.read(currentUserProvider).name;
  LogEntry _log(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  DisposalRequest? byId(String id) => state.firstWhereOrNull((d) => d.id == id);

  void _update(String id, DisposalRequest Function(DisposalRequest) f) {
    state = replaceWhere(state, id, (d) => d.id, f);
    final d = byId(id)!;
    ref.queueOffline(SyncKind.asset, d.assetId, 'Disposal ${d.id} · ${d.status}', refId: d.assetId);
  }

  /// Creates a Pending request. Returns null when the asset already has one pending
  /// (or is already disposed).
  String? submit({required String assetId, required String reason, required DateTime requestedDate, String? notes}) {
    if (state.pendingFor(assetId) != null) return null;
    if (ref.read(assetByIdProvider(assetId))?.status == AssetStatus.disposed) return null;
    final id = nextId('DSP-2026-', state.map((d) => d.id));
    final me = ref.read(currentUserProvider).id;
    state = [
      DisposalRequest(
        id: id,
        assetId: assetId,
        reason: reason,
        requestedDate: requestedDate,
        requesterId: me,
        approverId: me,
        createdAt: DemoClock.now,
        notes: notes,
        timeline: [_log('Submitted', reason)],
      ),
      ...state,
    ];
    ref.read(assetsProvider.notifier).addEvent(assetId, 'Disposal requested ($id)', note: reason);
    ref.queueOffline(SyncKind.asset, assetId, 'Disposal Request $id', refId: assetId);
    return id;
  }

  /// Approve → the asset's status becomes Disposed (org summary and Home follow).
  void approve(String id) {
    _update(id, (d) => d.copyWith(status: DisposalStatus.approved, timeline: [...d.timeline, _log('Approved')]));
    final d = byId(id)!;
    ref.read(assetsProvider.notifier).setStatus(d.assetId, AssetStatus.disposed, note: 'Disposal $id approved');
  }

  void reject(String id, String reason) {
    _update(
      id,
      (d) => d.copyWith(
        status: DisposalStatus.rejected,
        rejectReason: reason,
        timeline: [...d.timeline, _log('Rejected', reason)],
      ),
    );
    ref.read(assetsProvider.notifier).addEvent(byId(id)!.assetId, 'Disposal $id rejected', note: reason);
  }
}

final disposalsProvider = NotifierProvider<DisposalsNotifier, List<DisposalRequest>>(DisposalsNotifier.new);

extension DisposalQueries on List<DisposalRequest> {
  /// The asset's pending request ("Disposal pending" chip), if any.
  DisposalRequest? pendingFor(String assetId) => firstWhereOrNull((d) => d.assetId == assetId && d.isPending);

  /// Home "Approvals" and My Approvals.
  List<DisposalRequest> toApprove(String userId) => where((d) => d.isPending && d.approverId == userId).toList();
  List<DisposalRequest> forAsset(String assetId) => where((d) => d.assetId == assetId).toList();
}
