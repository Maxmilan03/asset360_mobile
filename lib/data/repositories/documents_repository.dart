import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/documents_mock.dart';
import '../models/document.dart';
import 'assets_repository.dart';
import 'repo_utils.dart';
import 'session_repository.dart';
import 'sync_repository.dart';
import '../models/sync_item.dart';

class DocumentsState {
  const DocumentsState({required this.summary, required this.docs});

  /// Org-wide counts (tabs and tiles).
  final DocumentSummary summary;

  /// Detailed sample documents.
  final List<AssetDocument> docs;

  AssetDocument? doc(String id) => docs.firstWhereOrNull((d) => d.id == id);

  /// Expiring Soon = expiry within 30 days of DemoClock (not yet expired).
  List<AssetDocument> get expiring => docs.where((d) => expiryState(d) == ExpiryState.expiring).toList();
  List<AssetDocument> get compliantDocs => docs.where((d) => expiryState(d) == ExpiryState.valid).toList();
  List<AssetDocument> get pendingDocs => docs.where((d) => d.pendingReview).toList();

  int get expiringSoon => summary.expiringSoon + expiring.length;
  int get compliant => summary.compliant + compliantDocs.length;
  int get pending => summary.pending + pendingDocs.length;

  /// Search by file name, type, asset ID or category.
  List<AssetDocument> search(List<AssetDocument> list, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return list;
    return list.where((d) => '${d.name} ${d.type} ${d.assetId} ${d.category ?? ''}'.toLowerCase().contains(s)).toList();
  }

  List<AssetDocument> forAsset(String assetId) => docs.where((d) => d.assetId == assetId).toList();
  List<AssetDocument> inBucket(String bucket) => docs.where((d) => DocType.bucket(d.type) == bucket).toList();

  DocumentsState copyWith({DocumentSummary? summary, List<AssetDocument>? docs}) =>
      DocumentsState(summary: summary ?? this.summary, docs: docs ?? this.docs);
}

class DocumentsNotifier extends Notifier<DocumentsState> {
  @override
  DocumentsState build() => DocumentsState(summary: seedDocumentSummary(), docs: seedDocuments());

  void _bucket(String type, int by) {
    final b = DocType.bucket(type);
    final m = {...state.summary.byBucket};
    m[b] = (m[b] ?? 0) + by;
    state = state.copyWith(summary: state.summary.copyWith(byBucket: m));
  }

  /// Upload Document. Returns the new ID.
  String add({
    required String assetId,
    required String name,
    required String type,
    required double sizeMb,
    String? category,
    String? version,
    String description = '',
    DateTime? expiry,
    String? filePath,
  }) {
    final id = nextId('DOC-2026-', state.docs.map((d) => d.id));
    final me = ref.read(currentUserProvider).name;
    final doc = AssetDocument(
      id: id,
      name: name,
      type: type,
      assetId: assetId,
      sizeMb: sizeMb,
      uploadedAt: DemoClock.now,
      uploadedBy: me,
      category: category,
      version: version ?? 'v1.0',
      description: description,
      expiry: expiry,
      filePath: filePath,
      versions: [DocVersion(version: version ?? 'v1.0', at: DemoClock.now, by: me, sizeMb: sizeMb, filePath: filePath)],
    );
    state = state.copyWith(docs: [doc, ...state.docs]);
    _bucket(type, 1);
    ref.read(assetsProvider.notifier).addEvent(assetId, 'Document uploaded', note: name);
    _q(id, 'Uploaded');
    return id;
  }

  void update(AssetDocument updated) {
    final old = state.doc(updated.id);
    if (old == null) return;
    state = state.copyWith(docs: replaceWhere(state.docs, updated.id, (d) => d.id, (_) => updated));
    if (DocType.bucket(old.type) != DocType.bucket(updated.type)) {
      _bucket(old.type, -1);
      _bucket(updated.type, 1);
    }
    _q(updated.id, 'Details edited');
  }

  void rename(String id, String name) {
    _edit(id, (d) => d.copyWith(name: name));
    _q(id, 'Renamed');
  }

  /// Replace Version: the new file becomes the next minor version (v2.1 → v2.2).
  String replaceVersion(String id, {required String fileName, required String path, required double sizeMb}) {
    final d = state.doc(id)!;
    final next = nextVersion(d.version);
    final me = ref.read(currentUserProvider).name;
    _edit(
      id,
      (x) => x.copyWith(
        version: next,
        sizeMb: sizeMb,
        filePath: path,
        uploadedAt: DemoClock.now,
        uploadedBy: me,
        versions: [
          DocVersion(version: next, at: DemoClock.now, by: me, sizeMb: sizeMb, filePath: path, note: fileName),
          ...x.versions,
        ],
      ),
    );
    ref.read(assetsProvider.notifier).addEvent(d.assetId, 'Document version $next uploaded', note: d.name);
    _q(id, 'Version $next');
    return next;
  }

  /// Restore an older version: it becomes the current one again.
  void restoreVersion(String id, String version) {
    _edit(id, (d) {
      final v = d.versions.firstWhere((x) => x.version == version);
      return d.copyWith(version: v.version, sizeMb: v.sizeMb, filePath: v.filePath ?? d.filePath);
    });
    _q(id, '$version restored');
  }

  /// Offline: the change also goes into the sync queue (Documents tab).
  void _q(String id, String change) {
    final d = state.doc(id);
    if (d != null) ref.queueOffline(SyncKind.document, d.name, '${d.type} · $change', refId: id);
  }

  void _edit(String id, AssetDocument Function(AssetDocument) f) =>
      state = state.copyWith(docs: replaceWhere(state.docs, id, (d) => d.id, f));

  void delete(String id) {
    final old = state.doc(id);
    if (old == null) return;
    ref.queueOffline(SyncKind.document, old.name, '${old.type} · Deleted', refId: id);
    state = state.copyWith(docs: state.docs.where((d) => d.id != id).toList());
    _bucket(old.type, -1);
  }
}

ExpiryState expiryState(AssetDocument d) {
  if (d.expiry == null) return ExpiryState.none;
  final days = DemoClock.daysUntil(d.expiry!);
  if (days < 0) return ExpiryState.expired;
  if (days <= expiringWithinDays) return ExpiryState.expiring;
  return ExpiryState.valid;
}

/// "v2.1" → "v2.2"; anything else → "v1.1".
String nextVersion(String? v) {
  final m = RegExp(r'^v?(\d+)\.(\d+)$').firstMatch(v ?? '');
  if (m == null) return 'v1.1';
  return 'v${m[1]}.${int.parse(m[2]!) + 1}';
}

final documentsProvider = NotifierProvider<DocumentsNotifier, DocumentsState>(DocumentsNotifier.new);
