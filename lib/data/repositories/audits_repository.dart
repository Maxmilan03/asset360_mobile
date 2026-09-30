import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/audits_mock.dart';
import '../models/audit.dart';
import 'assets_repository.dart';
import 'repo_utils.dart';

class AuditsNotifier extends Notifier<List<Audit>> {
  @override
  List<Audit> build() => seedAudits();

  Audit? byId(String id) => state.firstWhereOrNull((a) => a.id == id);
  void _update(String id, Audit Function(Audit) f) => state = replaceWhere(state, id, (a) => a.id, f);

  /// Saves an audit action for an asset; the matching counter goes up by one.
  /// A re-audit of the same asset replaces its earlier result.
  void record(String auditId, AuditEntry entry) {
    _update(auditId, (a) {
      final prev = a.entries.firstWhereOrNull((e) => e.assetId == entry.assetId);
      int bump(String result, int v) => v + (entry.result == result ? 1 : 0) - (prev?.result == result ? 1 : 0);
      return a.copyWith(
        status: a.status == AuditStatus.pending ? AuditStatus.inProgress : a.status,
        verified: bump(AuditResult.verified, a.verified),
        wrongLocation: bump(AuditResult.wrongLocation, a.wrongLocation),
        notFound: bump(AuditResult.notFound, a.notFound),
        unregistered: bump(AuditResult.unregistered, a.unregistered),
        entries: [entry, ...a.entries.where((e) => e.assetId != entry.assetId)],
      );
    });
    final audit = byId(auditId);
    if (entry.result != AuditResult.unregistered && audit != null) {
      ref.read(assetsProvider.notifier).addEvent(entry.assetId, 'Audited: ${entry.result}', note: audit.name);
    }
  }

  void start(String id) => _update(id, (a) => a.copyWith(status: AuditStatus.inProgress));
  void complete(String id) => _update(id, (a) => a.copyWith(status: AuditStatus.completed));

  /// Temporary tag for an unregistered asset found during an audit.
  String nextUnregisteredTag() => 'UNREG-${DemoClock.now.millisecondsSinceEpoch % 100000}';
}

final auditsProvider = NotifierProvider<AuditsNotifier, List<Audit>>(AuditsNotifier.new);

extension AuditQueries on List<Audit> {
  List<Audit> mine(String userId) => where((a) => a.auditorId == userId).toList();
  List<Audit> assigned(String userId) =>
      where((a) => a.auditorId == userId && a.status != AuditStatus.completed).toList();
  List<Audit> get completed => where((a) => a.status == AuditStatus.completed).toList();
  List<Audit> withStatus(String s) => where((a) => a.status == s).toList();
}
