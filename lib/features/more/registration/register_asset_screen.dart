import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
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
class RegisterAssetScreen extends ConsumerStatefulWidget {
  const RegisterAssetScreen({super.key, this.prefill});

  final RegistrationPrefill? prefill;

  @override
  ConsumerState<RegisterAssetScreen> createState() => _RegisterAssetScreenState();
}

class _RegisterAssetScreenState extends ConsumerState<RegisterAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final RegistrationForm f;
  int _step = 0;

  /// Bumped when code sets a text field (scan, suggested ID), so the field shows the new value.
  int _rev = 0;
  bool _dirty = false, _busy = false, _idAuto = false;

  /// The form was saved to My Drafts at least once (Submit then removes the draft).
  bool _saved = false;
  String? _locationError, _dateError;

  RegistrationDraftsNotifier get _drafts => ref.read(registrationDraftsProvider.notifier);
  AssetsNotifier get _assets => ref.read(assetsProvider.notifier);

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    final draft = p?.draftId == null ? null : _drafts.byId(p!.draftId!);
    if (draft != null) {
      f = draft.copy();
      _step = draft.step.clamp(0, registrationSteps.length - 1);
      _saved = true;
      return;
    }
    f = RegistrationForm(draftId: _drafts.newDraftId());
    f.basicInformation
      ..condition = 'Good'
      ..barcode = p?.barcode
      ..rfidTagId = p?.tagId
      ..images = [?p?.photo];
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change, {bool bump = false}) => setState(() {
    change();
    _dirty = true;
    if (bump) _rev++;
  });

  void _goTo(int step) {
    setState(() {
      _step = step;
      _locationError = _dateError = null;
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

  bool _validateStep() {
    final formOk = _formKey.currentState?.validate() ?? true;
    final l = f.locationAssignment.location;
    setState(() {
      _locationError = _step == 2 && (l.siteName == null || l.buildingName == null || l.floorName == null)
          ? 'Choose the site, building and floor'
          : null;
      _dateError = registrationDateError(f, _step);
    });
    final ok = formOk && _locationError == null && _dateError == null && registrationMissing(f, _step).isEmpty;
    // Errors are shown inline; bring the top of the step into view (a SnackBar would cover Next).
    if (!ok && _scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    return ok;
  }

  void _next() {
    if (_validateStep()) _goTo(_step + 1);
  }

  Future<void> _saveDraft() async {
    await _drafts.save(f, step: _step);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _dirty = false;
    });
    context.showSnack('Draft saved · find it under My Drafts on the Registration page');
  }

  Future<void> _cancel() async {
    if (_dirty) {
      final discard = await showConfirmDialog(
        context,
        title: 'Discard changes?',
        message: _saved
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

  /// Picking a type fills the category path and suggests the next free ID for it.
  void _typePicked(String type) {
    final path = classificationOf(type);
    final tag = (f.basicInformation.assetTag ?? '').trim();
    _edit(() {
      if (path != null) {
        f.classification
          ..category ??= path.category
          ..subCategory ??= path.subCategory;
      }
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
    final asset = registrationToAsset(f, by: ref.read(currentUserProvider).name);
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
    // A resumed draft may have skipped steps: send the user to the first incomplete one.
    for (var s = 0; s < registrationSteps.length - 1; s++) {
      final missing = registrationMissing(f, s);
      final dateError = registrationDateError(f, s);
      if (missing.isNotEmpty || dateError != null) {
        _goTo(s);
        context.showSnack(dateError ?? 'Complete ${missing.join(', ')}');
        WidgetsBinding.instance.addPostFrameCallback((_) => _validateStep());
        return;
      }
    }
    final b = f.basicInformation;
    final tag = b.assetTag!.trim().toUpperCase();
    for (final (v, except) in [(tag, null), (b.barcode, tag), (b.rfidTagId, null)]) {
      final s = (v ?? '').trim().toUpperCase();
      if (s.isNotEmpty && s != except && _assets.ownerOf(s) != null) {
        _goTo(0);
        WidgetsBinding.instance.addPostFrameCallback((_) => _formKey.currentState?.validate());
        return;
      }
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final asset = registrationToAsset(f, by: ref.read(currentUserProvider).name);
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
    if (_saved) await _drafts.delete(f.draftId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _dirty = false;
    });
    final router = GoRouter.of(context);
    final action = await showRegisteredSheet(context, asset);
    switch (action) {
      case RegisteredAction.view:
        router.pop();
        router.push(Routes.assetDetail(asset.id));
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
                  child: OutlinedButton(onPressed: _step == 0 ? null : () => _goTo(_step - 1), child: const Text('Back')),
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
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: isReview
                                ? const [Icon(Icons.check_rounded, size: 20), SizedBox(width: 6), Text('Submit')]
                                : const [Text('Next'), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: 20)],
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
                subtitle: isReview ? 'Review details before submitting' : 'Step ${_step + 1} of 5',
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
                  onTypePicked: _typePicked,
                  onSuggestId: _suggestId,
                  onGenerateQr: _generateQr,
                  onPrintLabel: _printLabel,
                ),
                1 => StepClassification(form: f, edit: _edit, onTypePicked: _typePicked),
                2 => StepLocation(form: f, edit: _edit, locationError: _locationError, dateError: _dateError),
                3 => StepPurchase(form: f, edit: _edit, dateError: _dateError),
                4 => StepAdditional(form: f, edit: _edit, dateError: _dateError),
                _ => RegistrationReview(form: f, onEdit: _goTo),
              },
            ],
          ),
        ),
      ),
    );
  }
}
