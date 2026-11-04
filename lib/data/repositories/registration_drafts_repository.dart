import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';

/// Register Asset "Save as Draft" (Registration hub → My Drafts), newest first. Unlike the rest of
/// the demo data, drafts are kept on the device (shared_preferences) so they survive a restart.
class RegistrationDraftsNotifier extends Notifier<List<RegistrationForm>> {
  static const _key = 'registration.drafts';

  @override
  List<RegistrationForm> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      state = [
        for (final j in list)
          if (j is Map) RegistrationForm.fromJson(Map<String, dynamic>.from(j)),
      ];
    } catch (_) {
      // No storage (tests) or unreadable data: start empty.
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode([for (final f in state) f.toJson()]));
    } catch (_) {
      // Kept in memory only.
    }
  }

  RegistrationForm? byId(String draftId) => state.firstWhereOrNull((f) => f.draftId == draftId);

  /// Next free local key: DRAFT-0001, DRAFT-0002 …
  String newDraftId() => nextId('DRAFT-', state.map((f) => f.draftId), width: 4);

  /// Saves a snapshot of [form] on [step] (replacing an earlier save of the same draft).
  Future<void> save(RegistrationForm form, {required int step}) {
    final snapshot = form.copy()
      ..step = step
      ..savedAt = DemoClock.now;
    form.savedAt = snapshot.savedAt;
    state = [snapshot, ...state.where((f) => f.draftId != form.draftId)];
    return _persist();
  }

  Future<void> delete(String draftId) {
    state = state.where((f) => f.draftId != draftId).toList();
    return _persist();
  }
}

final registrationDraftsProvider = NotifierProvider<RegistrationDraftsNotifier, List<RegistrationForm>>(
  RegistrationDraftsNotifier.new,
);
