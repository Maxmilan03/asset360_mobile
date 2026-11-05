import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset_registration_mapping.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/validation/asset_registration_validator.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/live_registration_repository.dart';
import 'package:asset360_mobile/data/repositories/registration_drafts_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/print_tag_screen.dart';
import 'package:asset360_mobile/features/more/registration/registration_logic.dart';
import 'package:asset360_mobile/features/more/registration/registration_review.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';
import 'package:asset360_mobile/features/more/registration/step_additional.dart';
import 'package:asset360_mobile/features/more/registration/step_basic.dart';
import 'package:asset360_mobile/features/more/registration/step_classification.dart';
import 'package:asset360_mobile/features/more/registration/step_location.dart';
import 'package:asset360_mobile/features/more/registration/step_purchase.dart';

/// Register Asset, the web form on a phone: Basic Information → Classification → Location &
/// Assignment → Purchase & Warranty → Additional Information → Review. Every step has Back,
/// Cancel, Save as Draft and Next; Review has Submit.
///
/// Mock mode: drafts are kept on the phone (RegistrationDraftsNotifier) and Submit adds the asset
/// to the mock register. API mode (LiveRegistrationService): Next saves the step on the server
/// (step 1 creates the draft "AR000123"), Save as Draft sends ?saveAsDraft=true, Submit posts the
/// draft; server errors are shown under the fields, the form keeps what the user typed.
class RegisterAssetScreen extends ConsumerStatefulWidget {
  const RegisterAssetScreen({super.key, this.prefill});

  final RegistrationPrefill? prefill;

  @override
  ConsumerState<RegisterAssetScreen> createState() => _RegisterAssetScreenState();
}

class _RegisterAssetScreenState extends ConsumerState<RegisterAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late AssetRegistration f;
  int _step = 0;

  /// API mode: loading a draft to resume (GET /drafts/{id}) and why it failed.
  bool _loading = false;
  Object? _loadError;

  /// API mode: steps changed since they were last saved on the server.
  final _unsaved = <int>{};

  /// Bumped when code sets a text field (scan, suggested ID), so the field shows the new value.
  int _rev = 0;
  bool _dirty = false, _busy = false, _idAuto = false;

  /// The form was saved to My Drafts at least once (Submit then removes the draft).
  bool _saved = false;

  /// RegistrationValidator errors of the current step, by backend field path. Once shown they
  /// update as the user types ([_mandatory] = the rules of the last check: Next or Save as Draft).
  Map<String, String> _errors = const {};
  bool _mandatory = true;

  RegistrationDraftsNotifier get _drafts => ref.read(registrationDraftsProvider.notifier);
  AssetsNotifier get _assets => ref.read(assetsProvider.notifier);

  /// Saved at least once: on the phone (mock mode) or on the server (API mode).
  bool get _isSaved => apiMode ? LiveRegistrationService.isOnServer(f) : _saved;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (apiMode && p?.draftId != null) {
      f = AssetRegistration(assetRegistrationId: p!.draftId!);
      _loading = true;
      _loadDraft();
      return;
    }
    final draft = p?.draftId == null || apiMode ? null : _drafts.byId(p!.draftId!);
    if (draft != null) {
      f = draft.copy();
      _step = draft.currentStep.clamp(0, registrationSteps.length - 1);
      _saved = true;
      return;
    }
    // Defaults as on the web form. API mode: the server assigns the ID on the first save, and
    // the unit / currency defaults are the first values of its lists.
    f = AssetRegistration(assetRegistrationId: apiMode ? '' : _drafts.newDraftId());
    f.basicInformation
      ..status = AssetStatus.active
      ..condition = 'Good'
      ..barcode = p?.barcode
      ..rfidTagId = p?.tagId
      ..images = [?p?.photo];
    f.locationAssignment.location
      ..countryId = countries.keys.first
      ..countryName = countries.values.first.name;
    f.purchaseWarranty.purchase
      ..quantity = 1
      ..taxPercent = 5;
    f.purchaseWarranty.warranty.warrantyPeriodUnit = PeriodUnit.years;
    f.additionalInformation.technical.expectedLifespanUnit = PeriodUnit.years;
    if (apiMode) {
      ref.listenManual(registrationOptionsProvider, (_, next) {
        if (next.value case final o?) _applyServerDefaults(o);
      }, fireImmediately: true);
      return;
    }
    f.purchaseWarranty.purchase
      ..quantityUnit = AssetOptions.quantityUnits.first
      ..currency = AssetOptions.currencies.keys.first;
    f.additionalInformation.technical
      ..dimensionUnit = AssetOptions.dimensionUnits.first
      ..weightUnit = AssetOptions.weightUnits.first;
    f.additionalInformation.operational
      ..operatingHoursUnit = AssetOptions.operatingHoursUnits.first
      ..maintenanceFrequencyUnit = AssetOptions.maintenanceFrequencyUnits.first;
  }

  /// API mode, new form: unit and currency defaults = the first value of the server's lists.
  void _applyServerDefaults(RegistrationOptions o) {
    final p = f.purchaseWarranty.purchase;
    final t = f.additionalInformation.technical, op = f.additionalInformation.operational;
    void apply() {
      p
        ..quantityUnit ??= o.quantityUnits.firstOrNull
        ..currency ??= o.currencies.firstOrNull;
      t
        ..dimensionUnit ??= o.additional('dimensionUnits').firstOrNull
        ..weightUnit ??= o.additional('weightUnits').firstOrNull;
      op
        ..operatingHoursUnit ??= o.additional('operatingHoursUnits').firstOrNull
        ..maintenanceFrequencyUnit ??= o.additional('maintenanceFrequencyUnits').firstOrNull;
    }

    mounted ? setState(apply) : apply();
  }

  /// API mode: GET /drafts/{id}, then resume on the step after the last one saved.
  Future<void> _loadDraft() async {
    try {
      final draft = await ref.read(liveRegistrationProvider).load(f.assetRegistrationId);
      if (!mounted) return;
      setState(() {
        f = draft;
        _step = resumeStepOf(draft);
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _loadDraft();
  }

  /// Mock mode only: the asset already using a tag / barcode / RFID value. API mode: null (the
  /// server answers a taken asset tag with 409).
  String? Function(String)? get _tagOwner => apiMode ? null : (code) => _assets.ownerOf(code)?.id;

  Map<String, String> _check(int step, {required bool mandatory}) =>
      RegistrationValidator.validateStep(f, step, requireMandatory: mandatory, tagOwner: _tagOwner);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change, {bool bump = false}) => setState(() {
    change();
    _dirty = true;
    if (apiMode && _step < RegistrationValidator.formSteps) _unsaved.add(_step);
    if (bump) _rev++;
    if (_errors.isNotEmpty) _errors = _check(_step, mandatory: _mandatory);
  });

  void _goTo(int step) {
    setState(() {
      _step = step;
      _errors = const {};
      // Steps 3 and 4 start from what earlier steps already know.
      final p = f.purchaseWarranty.purchase, a = f.locationAssignment.assignment;
      if (step == 2) {
        a.custodianDepartment ??= f.classification.department;
        a.costCenter ??= f.classification.costCenter;
      }
      if (step == 3) p.manufacturer ??= f.basicInformation.manufacturer;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Shows [errors] on the current step (format errors from the text fields too); true when none.
  bool _show(Map<String, String> errors, {required bool mandatory}) {
    final formatOk = _formKey.currentState?.validate() ?? true;
    setState(() {
      _errors = errors;
      _mandatory = mandatory;
    });
    final ok = formatOk && errors.isEmpty;
    // Errors are shown inline; bring the top of the step into view (a SnackBar would cover Next).
    if (!ok && _scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    return ok;
  }

  /// Errors on screen are `forceErrorText`, which makes `FormState.validate` fail; a server error
  /// (400 / 409) stays until the next check, so clear them and rebuild before validating again.
  Future<void> _clearShownErrors() async {
    if (_errors.isEmpty) return;
    setState(() => _errors = const {});
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Next: the step's required fields and rules; API mode then saves the step on the server.
  Future<void> _next() async {
    await _clearShownErrors();
    if (!mounted) return;
    if (!_show(_check(_step, mandatory: true), mandatory: true)) return;
    if (!apiMode) return _goTo(_step + 1);
    if (_uploadsRunning()) return;
    if (await _saveSteps([_step], saveAsDraft: false)) _goTo(_step + 1);
  }

  // ---------------------------------------------------------------- server (API mode)

  /// True (with a message) while photos or documents are still uploading.
  bool _uploadsRunning() {
    if (ref.read(registrationUploadsProvider) == 0) return false;
    context.showSnack('Wait until the uploads finish');
    return true;
  }

  /// Saves [steps] in order (creating the draft first when needed). False after an error, which
  /// is shown under the fields of the step it belongs to (or as a SnackBar).
  Future<bool> _saveSteps(Iterable<int> steps, {required bool saveAsDraft}) async {
    final service = ref.read(liveRegistrationProvider);
    setState(() => _busy = true);
    var step = _step;
    try {
      for (final s in steps.toSet().toList()..sort()) {
        step = s;
        await service.saveStep(f, s, saveAsDraft: saveAsDraft);
        _unsaved.remove(s);
      }
      return true;
    } catch (e) {
      if (mounted) _showServerError(ApiException.from(e), step: step, mandatory: !saveAsDraft);
      return false;
    } finally {
      if (LiveRegistrationService.isOnServer(f)) ref.invalidate(liveDraftsProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A failed server call: field errors (400) and a taken asset tag (409) under the fields of
  /// [step], anything else (no network, 404, 500 …) as a SnackBar. The input is kept.
  void _showServerError(ApiException e, {required int step, required bool mandatory}) {
    final fields = stepFieldErrors(e);
    if (fields.isEmpty) {
      context.showSnack(e.message);
      return;
    }
    final target = e.kind == ApiErrorKind.conflict ? 0 : step;
    if (target == _step) {
      _show(fields, mandatory: mandatory);
    } else {
      _showStep(target, fields, mandatory: mandatory);
    }
    context.showSnack('${registrationStepTitles[target]}: ${fields.values.first}');
  }

  /// Opens [step] with [errors] shown (Save as Draft / Submit found a problem there).
  void _showStep(int step, Map<String, String> errors, {required bool mandatory}) {
    _goTo(step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(errors, mandatory: mandatory);
    });
  }

  /// Save as Draft skips required fields, but every value entered must be valid.
  Future<void> _saveDraft() async {
    await _clearShownErrors();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? true)) {
      _show(_check(_step, mandatory: false), mandatory: false);
      context.showSnack('Fix the highlighted values, then Save as Draft');
      return;
    }
    final invalid = RegistrationValidator.firstInvalid(f, requireMandatory: false, tagOwner: _tagOwner);
    if (invalid != null) {
      _showStep(invalid.step, invalid.errors, mandatory: false);
      context.showSnack('Fix the highlighted values, then Save as Draft');
      return;
    }
    if (apiMode) return _saveDraftOnServer();
    await _drafts.save(f, step: _step, by: ref.read(currentUserProvider).name);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _dirty = false;
      _errors = const {};
    });
    context.showSnack('Draft ${f.assetRegistrationId} saved · resume it from My Drafts on the Registration page');
  }

  /// API mode Save as Draft: every changed step (and the current one) with ?saveAsDraft=true.
  Future<void> _saveDraftOnServer() async {
    if (_uploadsRunning()) return;
    final steps = {..._unsaved, if (_step < RegistrationValidator.formSteps) _step};
    if (steps.isEmpty && !LiveRegistrationService.isOnServer(f)) steps.add(0);
    if (!await _saveSteps(steps, saveAsDraft: true) || !mounted) return;
    setState(() {
      _dirty = false;
      _errors = const {};
    });
    context.showSnack('Draft ${f.assetRegistrationId} saved · resume it from My Drafts on the Registration page');
  }

  Future<void> _cancel() async {
    if (_dirty) {
      final discard = await showConfirmDialog(
        context,
        title: 'Discard changes?',
        message: _isSaved
            ? 'Changes since the last Save as Draft will be lost.'
            : 'The details you entered will be lost. Use Save as Draft to keep them.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    context.pop();
  }

  /// Picking a type suggests the next free asset tag for it (while the tag is empty or suggested).
  void _typePicked(String type) {
    if (apiMode) return; // The next free ID comes from the mock register.
    final tag = (f.basicInformation.assetTag ?? '').trim();
    _edit(() {
      if (tag.isEmpty || _idAuto) {
        f.basicInformation.assetTag = _nextId(type);
        _idAuto = true;
      }
    }, bump: true);
  }

  String _nextId(String type) {
    final listed = _assets.prefixFor(type);
    return _assets.nextAssetId(listed == 'AST' ? (assetTypeOption(type)?.prefix ?? 'AST') : listed);
  }

  void _suggestId() {
    if (apiMode) return showNotAvailableYet(context, 'Suggest next ID');
    final type = f.classification.assetType;
    if (type == null) {
      context.showSnack('Choose the Asset Type first, then tap Suggest next ID');
      return;
    }
    _edit(() {
      f.basicInformation.assetTag = _nextId(type);
      _idAuto = true;
    }, bump: true);
  }

  Future<void> _generateQr() async {
    final tag = (f.basicInformation.assetTag ?? '').trim().toUpperCase();
    if (tag.isEmpty) {
      context.showSnack('Enter the Asset Tag first; the QR code encodes it');
      return;
    }
    if ((f.basicInformation.barcode ?? '').trim().isEmpty) _edit(() => f.basicInformation.barcode = tag, bump: true);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => sheetFrame(context, [
        SheetTitle('QR Code', subtitle: 'Encodes the asset tag $tag'),
        Center(child: QrCode(data: tag, size: 200)),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ]),
    );
  }

  /// Print Asset Tag's label for the asset being registered.
  Future<void> _printLabel() async {
    final b = f.basicInformation;
    if ((b.assetTag ?? '').trim().isEmpty || (b.assetName ?? '').trim().isEmpty) {
      context.showSnack('Enter the asset name and tag first');
      return;
    }
    final asset = f.toAsset(by: ref.read(currentUserProvider).name);
    try {
      final printed = await printAssetTag(asset, type: tagTypes.first);
      if (mounted) context.showSnack(printed ? 'Label printed for ${asset.id}' : 'Printing cancelled');
    } catch (_) {
      if (mounted) context.showSnack('Printing is not available on this device');
    }
  }

  // ---------------------------------------------------------------- submit

  String _docType(String name) {
    final n = name.toLowerCase();
    if (n.contains('warrant')) return DocType.warranty;
    if (n.contains('cert') || n.contains('calib')) return DocType.certificate;
    if (n.contains('invoice') || n.contains('po')) return DocType.invoice;
    if (n.endsWith('.jpg') || n.endsWith('.png') || n.endsWith('.jpeg')) return DocType.photo;
    if (n.contains('drawing') || n.endsWith('.dwg')) return DocType.drawing;
    return DocType.manual;
  }

  Future<void> _submit() async {
    // A resumed draft may have skipped steps: send the user to the first step with a problem.
    final invalid = RegistrationValidator.firstInvalid(f, requireMandatory: true, tagOwner: _tagOwner);
    if (invalid != null) {
      _showStep(invalid.step, invalid.errors, mandatory: true);
      context.showSnack('${registrationStepTitles[invalid.step]}: ${invalid.errors.values.first}');
      return;
    }
    if (apiMode) return _submitToServer();
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final by = ref.read(currentUserProvider).name;
    final imei = f.local.iotDeviceImei;
    final iot = ref.read(unlinkedIotDevicesProvider).firstWhereOrNull((d) => d.imei == imei);
    final asset = f.toAsset(
      by: by,
      iot: iot?.copyWith(lastSeen: DemoClock.now),
    );
    _assets.add(asset);
    final docs = ref.read(documentsProvider.notifier);
    for (final d in [...f.purchaseWarranty.documents, ...f.additionalInformation.attachments]) {
      docs.add(
        assetId: asset.id,
        name: d.fileName,
        type: _docType(d.fileName),
        sizeMb: double.parse(d.sizeMb.toStringAsFixed(1)).clamp(.1, 999).toDouble(),
        filePath: d.url,
      );
    }
    if (_saved) await _drafts.delete(f.assetRegistrationId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _dirty = false;
    });
    await _registered(asset.id, asset.name);
  }

  /// API mode Submit: saves any changed step as a draft, then POST /drafts/{id}/submit. Submit
  /// errors ("Classification.Department" …) open the first step with a problem.
  Future<void> _submitToServer() async {
    if (_uploadsRunning()) return;
    final pending = {..._unsaved, if (!LiveRegistrationService.isOnServer(f)) 0};
    if (pending.isNotEmpty && !await _saveSteps(pending, saveAsDraft: true)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final AssetRegistration asset;
    try {
      asset = await ref.read(liveRegistrationProvider).submit(f);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final err = ApiException.from(e);
      final byStep = submitErrorsByStep(err.fieldErrors);
      if (err.kind == ApiErrorKind.validation && byStep.isNotEmpty) {
        final first = byStep.keys.reduce((a, b) => a < b ? a : b);
        _showStep(first, byStep[first]!, mandatory: true);
        context.showSnack('${registrationStepTitles[first]}: ${byStep[first]!.values.first}');
      } else {
        _showServerError(err, step: 0, mandatory: true);
      }
      return;
    }
    ref
      ..invalidate(liveDraftsProvider)
      ..invalidate(liveAssetListProvider)
      ..invalidate(recentLiveAssetsProvider)
      ..invalidate(assetSummaryProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _dirty = false;
      _unsaved.clear();
    });
    await _registered(asset.assetRegistrationId, asset.title);
  }

  /// The "Asset registered" sheet and what the user picked there.
  Future<void> _registered(String id, String name) async {
    final router = GoRouter.of(context);
    final action = await showRegisteredSheet(context, id: id, name: name);
    switch (action) {
      case RegisteredAction.view:
        router.pop();
        router.push(Routes.assetDetail(id));
      case RegisteredAction.another:
        router.pushReplacement(Routes.newRegistration);
      case RegisteredAction.done || null:
        router.pop();
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final isReview = _step == registrationSteps.length - 1;
    if (_loading || _loadError != null) {
      return AppScaffold(
        header: const AppHeader(showBack: true),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : LoadErrorState(error: _loadError!, title: 'Could not open the draft', onRetry: _retryLoad),
      );
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AppScaffold(
        header: AppHeader(showBack: true, onBack: _cancel),
        bottomActions: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(onPressed: _cancel, child: const Text('Cancel')),
                const Spacer(),
                TextButton.icon(
                  onPressed: _busy ? null : _saveDraft,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save as Draft'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _step == 0 ? null : () => _goTo(_step - 1),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : (isReview ? _submit : _next),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        // Scales down on a 360 px phone instead of overflowing.
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: isReview
                                  ? const [Icon(Icons.check_rounded, size: 20), SizedBox(width: 6), Text('Submit')]
                                  : const [
                                      Text('Next'),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              PageTitle(
                leading: Icon(Icons.radio_button_checked_rounded, color: AppColors.text, size: 22),
                title: 'Asset Registration',
                subtitle: isReview
                    ? 'Review details before submitting'
                    : 'Step ${_step + 1} of 5 · ${registrationStepSubtitles[_step]}',
              ),
              if (apiMode && LiveRegistrationService.isOnServer(f))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IconLine(
                    icon: Icons.cloud_done_outlined,
                    text: 'Draft ${f.assetRegistrationId} · saved on the server',
                  ),
                ),
              const SizedBox(height: 16),
              StepperHeader(steps: registrationSteps, current: _step, onStepTap: _goTo),
              const SizedBox(height: 18),
              RegSection(registrationStepTitles[_step]),
              switch (_step) {
                0 => StepBasic(
                  form: f,
                  edit: _edit,
                  revision: _rev,
                  errors: _errors,
                  onEditClassification: () => _goTo(1),
                  onSuggestId: _suggestId,
                  onGenerateQr: _generateQr,
                  onPrintLabel: _printLabel,
                ),
                1 => StepClassification(form: f, edit: _edit, onTypePicked: _typePicked, errors: _errors),
                2 => StepLocation(form: f, edit: _edit, errors: _errors),
                3 => StepPurchase(form: f, edit: _edit, errors: _errors),
                4 => StepAdditional(form: f, edit: _edit, errors: _errors),
                _ => RegistrationReview(form: f, onEdit: _goTo),
              },
            ],
          ),
        ),
      ),
    );
  }
}
