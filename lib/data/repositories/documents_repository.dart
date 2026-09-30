import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/documents_mock.dart';
import '../models/document.dart';
import 'assets_repository.dart';
import 'repo_utils.dart';
import 'session_repository.dart';

class DocumentsState {
  const DocumentsState({required this.summary, required this.docs});

  /// Org-wide counts (tabs and tiles).
  final DocumentSummary summary;

  /// Detailed sample documents.
  final List<AssetDocument> docs;

  AssetDocument? doc(String id) => docs.firstWhereOrNull((d) => d.id == id);
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
    final doc = AssetDocument(
      id: id,
      name: name,
      type: type,
      assetId: assetId,
      sizeMb: sizeMb,
      uploadedAt: DemoClock.now,
      uploadedBy: ref.read(currentUserProvider).name,
      category: category,
      version: version,
      description: description,
      expiry: expiry,
      filePath: filePath,
    );
    state = state.copyWith(docs: [doc, ...state.docs]);
    _bucket(type, 1);
    ref.read(assetsProvider.notifier).addEvent(assetId, 'Document uploaded', note: name);
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
  }

  void delete(String id) {
    final old = state.doc(id);
    if (old == null) return;
    state = state.copyWith(docs: state.docs.where((d) => d.id != id).toList());
    _bucket(old.type, -1);
  }
}

final documentsProvider = NotifierProvider<DocumentsNotifier, DocumentsState>(DocumentsNotifier.new);
