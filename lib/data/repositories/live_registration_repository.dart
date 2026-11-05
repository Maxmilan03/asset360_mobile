import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';

export 'package:asset360_mobile/data/repositories/live_assets_repository.dart';

/// Register Asset against the Asset service (apiMode = true). Drafts live on the server
/// (AssetRegistrationEndpoints.cs): step 1 Next = POST /drafts (new "AR000123"), later saves =
/// PUT /drafts/{id}/{step}, Save as Draft = the same call with ?saveAsDraft=true, Review =
/// POST /drafts/{id}/submit. The form keeps the user's input; only the values the server derives
/// are copied back ([applyServerReply]).
class LiveRegistrationService {
  const LiveRegistrationService(this.api);

  final AssetsApi api;

  /// True once the draft exists on the server (the server's database id came back).
  static bool isOnServer(AssetRegistration form) => form.id != null;

  /// Saves the app's [step] (0 … 4) of [form]. A draft that is not on the server yet is first
  /// created with step 1 (POST; with saveAsDraft when [step] is a later one, so the later step's
  /// rules decide). Copies the server's derived values into [form] after every call, so a POST
  /// that succeeded is kept even when the following PUT fails.
  Future<void> saveStep(AssetRegistration form, int step, {required bool saveAsDraft}) async {
    if (!isOnServer(form)) {
      final created = await api.createDraft(form.basicInformation, saveAsDraft: step == 0 ? saveAsDraft : true);
      applyServerReply(form, created);
      if (step == 0) return;
    }
    applyServerReply(form, await api.saveStep(form.assetRegistrationId, step, form, saveAsDraft: saveAsDraft));
  }

  /// POST …/drafts/{id}/submit → the registered asset.
  Future<AssetRegistration> submit(AssetRegistration form) => api.submitDraft(form.assetRegistrationId);

  Future<AssetRegistration> load(String assetRegistrationId) => api.getDraft(assetRegistrationId);

  Future<void> delete(String assetRegistrationId) => api.deleteDraft(assetRegistrationId);
}

final liveRegistrationProvider = Provider<LiveRegistrationService>(
  (ref) => LiveRegistrationService(ref.watch(assetsApiProvider)),
);

/// GET /api/asset-registrations/drafts (My Drafts on the Registration page). Invalidate after a
/// save, submit or delete.
final liveDraftsProvider = FutureProvider.autoDispose<List<AssetRegistration>>(
  (ref) => ref.watch(assetsApiProvider).listDrafts(),
);

/// Copies what the server owns or derives from [reply] into [form]: ids, step, audit fields,
/// Total Cost, Warranty End Date and the location path. Everything the user typed stays.
void applyServerReply(AssetRegistration form, AssetRegistration reply) {
  form
    ..id = reply.id ?? form.id
    ..assetRegistrationId = reply.assetRegistrationId
    ..currentStep = reply.currentStep
    ..createdBy = reply.createdBy ?? form.createdBy
    ..createdAt = reply.createdAt ?? form.createdAt
    ..updatedBy = reply.updatedBy ?? form.updatedBy
    ..updatedAt = reply.updatedAt ?? form.updatedAt;
  form.purchaseWarranty.purchase.totalCost = reply.purchaseWarranty.purchase.totalCost;
  form.purchaseWarranty.warranty.warrantyEndDate = reply.purchaseWarranty.warranty.warrantyEndDate;
  form.locationAssignment.location.serverLocationPath = reply.locationAssignment.location.serverLocationPath;
  // The server spells the tagging method as listed ("qr code" → "QR Code").
  form.classification.taggingMethod = reply.classification.taggingMethod ?? form.classification.taggingMethod;
}

/// The app's step index (0 … 4) to resume a server draft on: the server's currentStep is the
/// step number last saved (1 … 5).
int resumeStepOf(AssetRegistration draft) => (draft.currentStep - 1).clamp(0, 4);

/// Prefixes of the submit validator's keys, by the app's step index
/// (ValidateForSubmit: "BasicInformation.AssetName", "PurchaseWarranty.Purchase.PurchaseCost" …).
const submitStepPrefixes = [
  'BasicInformation',
  'Classification',
  'LocationAssignment',
  'PurchaseWarranty',
  'AdditionalInformation',
];

/// Submit 400 errors split by step with the step prefix removed (the keys the step screens show).
/// Keys without a known prefix are left out.
Map<int, Map<String, String>> submitErrorsByStep(Map<String, String> errors) {
  final out = <int, Map<String, String>>{};
  for (final MapEntry(:key, :value) in errors.entries) {
    for (final (i, prefix) in submitStepPrefixes.indexed) {
      if (key.toLowerCase().startsWith('${prefix.toLowerCase()}.')) {
        (out[i] ??= {})[_pascal(key.substring(prefix.length + 1))] = value;
        break;
      }
    }
  }
  return out;
}

/// "purchase.purchaseCost" → "Purchase.PurchaseCost" (ASP.NET may camelCase the keys).
String _pascal(String key) => key.split('.').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join('.');

/// Server error keys of one step → the keys the step screen shows; a 409 (duplicate asset tag)
/// becomes an Asset Tag error. Empty when the error is not about a field.
Map<String, String> stepFieldErrors(ApiException e) => switch (e.kind) {
  ApiErrorKind.conflict => {'AssetTag': e.message},
  ApiErrorKind.validation => {for (final MapEntry(:key, :value) in e.fieldErrors.entries) _pascal(key): value},
  _ => const {},
};

/// Uploads in progress on the Register Asset form (photos, documents, attachments). Next, Save as
/// Draft and Submit wait until it is 0.
class RegistrationUploadsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void started() => state++;
  void finished() => state = state > 0 ? state - 1 : 0;
}

final registrationUploadsProvider = NotifierProvider<RegistrationUploadsNotifier, int>(RegistrationUploadsNotifier.new);
