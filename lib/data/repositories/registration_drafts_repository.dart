import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';

/// Register Asset "Save as Draft" (Registration hub → My Drafts), newest first. Unlike the rest of
/// the demo data, drafts are kept on the device (shared_preferences) so they survive a restart.
/// Mock mode only: in API mode drafts live on the server (live_registration_repository.dart:
/// POST / PUT /api/asset-registrations/drafts…, GET …/drafts, DELETE …/drafts/{id}).
class RegistrationDraftsNotifier extends Notifier<List<AssetRegistration>> {
  static const storageKey = 'registration.drafts.v2';

  /// Completes when the stored drafts are loaded (tests await it after a "restart").
  late Future<void> loaded;

  @override
  List<AssetRegistration> build() {
    loaded = _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      state = [
        for (final j in list)
          if (j is Map) AssetRegistration.fromStorageJson(Map<String, dynamic>.from(j)),
      ];
    } catch (_) {
      // No storage or unreadable data: start empty.
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(storageKey, jsonEncode([for (final r in state) r.toStorageJson()]));
    } catch (_) {
      // Kept in memory only.
    }
  }

  AssetRegistration? byId(String assetRegistrationId) =>
      state.firstWhereOrNull((r) => r.assetRegistrationId == assetRegistrationId);

  /// Next free local assetRegistrationId: DRAFT-0001, DRAFT-0002 …
  String newDraftId() => nextId('DRAFT-', state.map((r) => r.assetRegistrationId), width: 4);

  /// Saves a snapshot of [registration] on [step] (replacing an earlier save of the same draft).
  Future<void> save(AssetRegistration registration, {required int step, required String by}) {
    final now = DemoClock.now;
    registration
      ..currentStep = step
      ..createdBy ??= by
      ..createdAt ??= now
      ..updatedBy = by
      ..updatedAt = now;
    final snapshot = registration.copy();
    state = [snapshot, ...state.where((r) => r.assetRegistrationId != registration.assetRegistrationId)];
    return _persist();
  }

  Future<void> delete(String assetRegistrationId) {
    state = state.where((r) => r.assetRegistrationId != assetRegistrationId).toList();
    return _persist();
  }
}

final registrationDraftsProvider = NotifierProvider<RegistrationDraftsNotifier, List<AssetRegistration>>(
  RegistrationDraftsNotifier.new,
);
