import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_actions.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/features/more/registration/registration_review.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

const _steps = ['Basic', 'Classification', 'Location & Custody', 'Additional', 'Review'];
const _suggestedTags = ['Rotating', 'Electrical', 'Critical Spare', 'Outdoor', 'Calibrated', 'Safety'];

/// A document picked in step 4, uploaded to Documents on Register.
class PickedDoc {
  const PickedDoc({required this.name, required this.sizeMb, this.path});

  final String name;
  final double sizeMb;
  final String? path;
}

/// Everything the form collects; read by the Review step.
class RegistrationDraft {
  String? photo;
  String id = '', name = '', serial = '', tagId = '', barcode = '';
  String status = AssetStatus.active, condition = 'Good', operationalStatus = 'Running', criticality = 'Medium';
  DateTime? purchase, commissioned;
  String? category, type;
  String manufacturer = '', model = '';
  String? parentId;
  List<String> tags = [];
  String? site, building, floor, zone;
  String custodian = 'Unassigned';
  String? department;
  double? cost;
  String supplier = '', po = '';
  DateTime? warranty;
  bool amc = false;
  String amcVendor = '';
  int life = 10;
  List<PickedDoc> docs = [];
  IotDevice? iot;

  /// "Main Plant / Production Floor 1 – Line 1".
  String get location {
    final path = [?building, ?floor].join(' / ');
    return zone == null ? path : '$path – $zone';
  }
}

/// Register New Asset: Basic → Classification → Location & Custody → Additional → Review.
class RegisterAssetScreen extends ConsumerStatefulWidget {
  const RegisterAssetScreen({super.key, this.prefill});

  final RegistrationPrefill? prefill;

  @override
  ConsumerState<RegisterAssetScreen> createState() => _RegisterAssetScreenState();
}

class _RegisterAssetScreenState extends ConsumerState<RegisterAssetScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final d = RegistrationDraft();
  int _step = 0;
  bool _idAuto = false; // the ID was suggested, so changing the type may re-suggest it
  bool _registering = false;
  String? _dateError, _warrantyError, _classError, _locationError;

  late final _id = TextEditingController();
  late final _name = TextEditingController();
  late final _serial = TextEditingController();
  late final _tag = TextEditingController(text: widget.prefill?.tagId ?? '');
  late final _barcode = TextEditingController(text: widget.prefill?.barcode ?? '');
  late final _model = TextEditingController();
  late final _tagInput = TextEditingController();
  late final _cost = TextEditingController();
  late final _po = TextEditingController();
  late final _amcVendor = TextEditingController();
  late final _life = TextEditingController(text: '10');
  late final _controllers = [_id, _name, _serial, _tag, _barcode, _model, _tagInput, _cost, _po, _amcVendor];

  @override
  void initState() {
    super.initState();
    d.photo = widget.prefill?.photo;
  }

  @override
  void dispose() {
    for (final c in [..._controllers, _life]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _controllers.any((c) => c.text.trim().isNotEmpty) ||
      d.photo != null ||
      d.category != null ||
      d.site != null ||
      d.docs.isNotEmpty ||
      d.manufacturer.isNotEmpty;

  AssetsNotifier get _assets => ref.read(assetsProvider.notifier);

  /// Copies the text fields into the draft.
  void _sync() {
    d
      ..id = _id.text.trim().toUpperCase()
      ..name = _name.text.trim()
      ..serial = _serial.text.trim()
      ..tagId = _tag.text.trim().toUpperCase()
      ..barcode = _barcode.text.trim().toUpperCase()
      ..model = _model.text.trim()
      ..cost = double.tryParse(_cost.text.replaceAll(',', '').trim())
      ..po = _po.text.trim()
      ..amcVendor = _amcVendor.text.trim()
      ..life = int.tryParse(_life.text.trim()) ?? 10;
  }

  String? _unique(String? v) {
    final owner = _assets.ownerOf(v ?? '');
    return owner == null ? null : 'Already used by ${owner.id}';
  }

  void _goTo(int step) {
    _sync();
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool _validateStep() {
    _sync();
    final formOk = _form.currentState?.validate() ?? true;
    var ok = formOk;
    setState(() {
      _dateError = _classError = _locationError = _warrantyError = null;
      switch (_step) {
        case 0:
          if (d.purchase != null && d.purchase!.isAfter(DemoClock.now)) {
            _dateError = 'Purchase date cannot be in the future';
          } else if (d.purchase != null && d.commissioned != null && d.commissioned!.isBefore(d.purchase!)) {
            _dateError = 'Commissioned date cannot be before the purchase date';
          }
          ok &= _dateError == null;
        case 1:
          if (d.category == null || d.type == null) _classError = 'Choose the category and asset type';
          ok &= _classError == null;
        case 2:
          if (d.site == null || d.building == null || d.floor == null) {
            _locationError = 'Choose the site, building and floor';
          }
          ok &= _locationError == null;
        case 3:
          final from = d.purchase ?? DemoClock.today;
          if (d.warranty == null) {
            _warrantyError = 'Choose the warranty expiry';
          } else if (d.warranty!.isBefore(from)) {
            _warrantyError = 'Warranty expiry cannot be before the purchase date';
          }
          ok &= _warrantyError == null;
      }
    });
    // Errors are shown inline; bring the top of the step into view (a SnackBar would cover Next).
    if (!ok && _scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    return ok;
  }

  void _next() {
    if (!_validateStep()) return;
    _goTo(_step + 1);
  }

  Future<void> _cancel() async {
    if (_step > 0) {
      _goTo(_step - 1);
      return;
    }
    await _leave();
  }

  Future<void> _leave() async {
    if (_dirty) {
      final discard = await showConfirmDialog(
        context,
        title: 'Discard this asset?',
        message: 'The details you entered will be lost.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    context.pop();
  }

  Future<void> _scanInto(TextEditingController c, String title) async {
    final code = await showScanCapture(context, title: title, suggestions: const ['MTR-00123', 'QR-A360-000901']);
    if (code == null || !mounted) return;
    setState(() => c.text = code.toUpperCase());
    _form.currentState?.validate();
  }

  void _suggestId(String type) {
    final category = ref.read(assetTypesProvider)[type];
    setState(() {
      _id.text = _assets.nextAssetId(_assets.prefixFor(type));
      _idAuto = true;
      d.type = type;
      d.category ??= category;
    });
  }

  Future<void> _pickDocs() async {
    try {
      final files = await FilePicker.pickFiles();
      final picked = <PickedDoc>[];
      for (final f in files) {
        final bytes = await f.length() ?? 0;
        picked.add(PickedDoc(name: f.name, sizeMb: bytes / (1024 * 1024), path: f.path));
      }
      if (picked.isNotEmpty) setState(() => d.docs = [...d.docs, ...picked]);
    } catch (_) {
      if (mounted) context.showSnack('Could not open files. Allow file access and try again.');
    }
  }

  // ---------------------------------------------------------------- register

  String _docType(String name) {
    final n = name.toLowerCase();
    if (n.contains('warrant')) return DocType.warranty;
    if (n.contains('cert') || n.contains('calib')) return DocType.certificate;
    if (n.contains('invoice') || n.contains('po')) return DocType.invoice;
    if (n.endsWith('.jpg') || n.endsWith('.png') || n.endsWith('.jpeg')) return DocType.photo;
    if (n.contains('drawing') || n.endsWith('.dwg')) return DocType.drawing;
    return DocType.manual;
  }

  Future<void> _register() async {
    _sync();
    // Re-check uniqueness in case another asset took the ID meanwhile.
    for (final v in [d.id, d.tagId, d.barcode]) {
      if (_unique(v) != null) {
        _goTo(0);
        WidgetsBinding.instance.addPostFrameCallback((_) => _form.currentState?.validate());
        return;
      }
    }
    setState(() => _registering = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final purchase = d.purchase ?? DemoClock.today;
    final cost = d.cost ?? 0;
    final asset = Asset(
      id: d.id,
      name: d.name,
      type: d.type!,
      category: d.category!,
      manufacturer: d.manufacturer.isEmpty ? '—' : d.manufacturer,
      model: d.model.isEmpty ? null : d.model,
      serialNo: d.serial.isEmpty ? null : d.serial,
      tagId: d.tagId.isEmpty ? null : d.tagId,
      barcode: d.barcode.isEmpty ? d.id : d.barcode,
      location: d.location,
      site: d.site!,
      custodian: d.custodian,
      status: d.status,
      condition: d.condition,
      operationalStatus: d.operationalStatus,
      criticality: d.criticality,
      healthScore: 100,
      purchaseDate: purchase,
      commissionedDate: d.commissioned,
      warrantyExpiry: d.warranty!,
      amc: d.amc ? d.amcVendor : null,
      amcExpiry: d.amc ? DateTime(DemoClock.today.year + 1, DemoClock.today.month, DemoClock.today.day) : null,
      purchaseCost: cost,
      usefulLifeYears: d.life,
      salvageValue: (cost * .1).roundToDouble(),
      imagePath: d.photo,
      iot: d.iot?.copyWith(lastSeen: DemoClock.now),
      parentId: d.parentId,
      tags: d.tags,
      department: d.department,
      supplier: d.supplier.isEmpty ? null : d.supplier,
      poNumber: d.po.isEmpty ? null : d.po,
      locationHistory: [
        LocationRecord(at: DemoClock.now, location: d.location, by: ref.read(currentUserProvider).name),
      ],
    );
    _assets.add(asset);
    final docs = ref.read(documentsProvider.notifier);
    for (final f in d.docs) {
      docs.add(
        assetId: asset.id,
        name: f.name,
        type: _docType(f.name),
        sizeMb: double.parse(f.sizeMb.toStringAsFixed(1)).clamp(.1, 999).toDouble(),
        filePath: f.path,
      );
    }
    setState(() => _registering = false);
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
    final isReview = _step == _steps.length - 1;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AppScaffold(
        header: AppHeader(showBack: true, onBack: _leave),
        bottomActions: Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _cancel, child: Text(_step == 0 ? 'Cancel' : 'Back')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _registering ? null : (isReview ? _register : _next),
                child: _registering
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: isReview
                              ? const [Icon(Icons.check_rounded, size: 20), SizedBox(width: 6), Text('Register Asset')]
                              : const [Text('Next'), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: 20)],
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              PageTitle(
                leading: Icon(Icons.radio_button_checked_rounded, color: AppColors.text, size: 22),
                title: 'Asset Registration',
                subtitle: isReview ? 'Review details before saving' : 'Add asset details and classification',
              ),
              const SizedBox(height: 16),
              StepperHeader(steps: _steps, current: _step, onStepTap: _goTo),
              const SizedBox(height: 18),
              switch (_step) {
                0 => _basic(),
                1 => _classification(),
                2 => _locationStep(),
                3 => _additional(),
                _ => RegistrationReview(draft: d, onEdit: _goTo),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: AppText.bodyStrong.copyWith(fontSize: 15)),
  );

  Widget _error(String? text) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(text, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
        );

  // ---------------------------------------------------------------- step 1

  Widget _basic() {
    final types = ref.watch(assetTypesProvider).keys.toList();
    Color statusColor(String s) => ChipTone.forStatus(s).foreground;
    Color critColor(String s) => switch (s) {
      'Critical' || 'High' => AppColors.red,
      'Medium' => AppColors.amber,
      _ => AppColors.green,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Basic Information'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Asset Photo',
                child: _PhotoBox(path: d.photo, onPicked: (p) => setState(() => d.photo = p)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabeledField(
                    label: 'Asset ID',
                    required: true,
                    child: TextFormField(
                      controller: _id,
                      style: inputStyle,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => _idAuto = false,
                      decoration: InputDecoration(
                        hintText: 'e.g. MTR-00124',
                        suffixIcon: ScanSuffix(onTap: () => _scanInto(_id, 'Scan Asset ID')),
                        errorMaxLines: 2,
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim().toUpperCase();
                        if (s.isEmpty) return 'Enter the Asset ID';
                        if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{2,19}$').hasMatch(s)) return 'Use letters, digits and -';
                        return _unique(s);
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PopupMenuButton<String>(
                      tooltip: 'Suggest the next ID',
                      onSelected: _suggestId,
                      itemBuilder: (_) => [
                        for (final t in types)
                          PopupMenuItem(value: t, child: Text('$t  ·  ${_assets.nextAssetId(_assets.prefixFor(t))}')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text('Suggest next ID', overflow: TextOverflow.ellipsis, style: AppText.link),
                            ),
                            Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  LabeledField(
                    label: 'Asset Name',
                    required: true,
                    child: TextFormField(
                      controller: _name,
                      style: inputStyle,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'e.g. Main Motor - Line 1'),
                      validator: (v) => (v ?? '').trim().length < 3 ? 'Enter the asset name' : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'Serial Number',
                    child: TextFormField(
                      controller: _serial,
                      style: inputStyle,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: 'Manufacturer serial'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FieldPair(
          LabeledField(
            label: 'Tag ID (RFID)',
            child: TextFormField(
              controller: _tag,
              style: inputStyle,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'RFID-A360-…',
                errorMaxLines: 2,
                suffixIcon: ScanSuffix(
                  tooltip: 'Read RFID / NFC',
                  onTap: () async {
                    final tag = await showRfidReadSheet(context, ref);
                    if (tag != null) setState(() => _tag.text = tag);
                  },
                ),
              ),
              validator: _unique,
            ),
          ),
          LabeledField(
            label: 'Barcode / QR',
            child: TextFormField(
              controller: _barcode,
              style: inputStyle,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Defaults to Asset ID',
                errorMaxLines: 2,
                suffixIcon: ScanSuffix(onTap: () => _scanInto(_barcode, 'Scan Barcode / QR')),
              ),
              validator: (v) {
                final s = (v ?? '').trim().toUpperCase();
                // The new asset may carry its own ID as barcode.
                return s.isNotEmpty && s == _id.text.trim().toUpperCase() ? null : _unique(s);
              },
            ),
          ),
        ),
        FieldPair(
          LabeledField(
            label: 'Status',
            required: true,
            child: DotDropdown(
              value: d.status,
              options: const [...AssetStatus.summary, AssetStatus.inTransit],
              colorOf: statusColor,
              onChanged: (v) => setState(() => d.status = v),
            ),
          ),
          LabeledField(
            label: 'Condition',
            child: DotDropdown(
              value: d.condition,
              options: assetConditions,
              colorOf: statusColor,
              onChanged: (v) => setState(() => d.condition = v),
            ),
          ),
        ),
        FieldPair(
          LabeledField(
            label: 'Operational Status',
            child: DotDropdown(
              value: d.operationalStatus,
              options: operationalStatuses,
              colorOf: statusColor,
              onChanged: (v) => setState(() => d.operationalStatus = v),
            ),
          ),
          LabeledField(
            label: 'Criticality',
            child: DotDropdown(
              value: d.criticality,
              options: criticalities,
              colorOf: critColor,
              onChanged: (v) => setState(() => d.criticality = v),
            ),
          ),
        ),
        FieldPair(
          LabeledField(
            label: 'Purchase Date',
            child: DateBox(value: d.purchase, onPicked: (v) => setState(() => d.purchase = v)),
          ),
          LabeledField(
            label: 'Commissioned Date',
            child: DateBox(value: d.commissioned, onPicked: (v) => setState(() => d.commissioned = v)),
          ),
        ),
        _error(_dateError),
      ],
    );
  }

  // ---------------------------------------------------------------- step 2

  Widget _classification() {
    final typeMap = ref.watch(assetTypesProvider);
    final master = ref.watch(masterDataProvider);
    final categories = {...master.categories, ...typeMap.values}.toList()..sort();
    final types = typeMap.entries.where((e) => d.category == null || e.value == d.category).map((e) => e.key).toList();
    final manufacturers = master.manufacturers;
    final parent = d.parentId == null ? null : ref.watch(assetByIdProvider(d.parentId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Classification'),
        LabeledField(
          label: 'Category',
          required: true,
          child: DropdownButtonFormField<String>(
            initialValue: d.category,
            isExpanded: true,
            hint: Text('Select category', style: hintStyle),
            items: [
              for (final c in categories)
                DropdownMenuItem(
                  value: c,
                  child: Text(c, style: inputStyle),
                ),
            ],
            onChanged: (v) => setState(() {
              d.category = v;
              if (d.type != null && typeMap[d.type] != v) d.type = null;
            }),
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Asset Type',
          required: true,
          child: DropdownButtonFormField<String>(
            key: ValueKey('type-${d.category}'),
            initialValue: d.type,
            isExpanded: true,
            hint: Text('Select type', style: hintStyle),
            items: [
              for (final t in types)
                DropdownMenuItem(
                  value: t,
                  child: Text(t, style: inputStyle),
                ),
            ],
            onChanged: (v) => setState(() {
              d.type = v;
              d.category ??= typeMap[v];
              if (v != null && (_id.text.isEmpty || _idAuto)) {
                _id.text = _assets.nextAssetId(_assets.prefixFor(v));
                _idAuto = true;
              }
            }),
          ),
        ),
        const SizedBox(height: 14),
        _error(_classError),
        FieldPair(
          LabeledField(
            label: 'Manufacturer',
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: d.manufacturer),
              optionsBuilder: (v) => manufacturers.where((m) => m.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => d.manufacturer = v,
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextFormField(
                controller: controller,
                style: inputStyle,
                focusNode: focus,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => d.manufacturer = v.trim(),
                decoration: const InputDecoration(hintText: 'e.g. Siemens'),
              ),
            ),
          ),
          LabeledField(
            label: 'Model',
            child: TextFormField(
              controller: _model,
              style: inputStyle,
              decoration: const InputDecoration(hintText: 'e.g. IE3-315M'),
            ),
          ),
        ),
        LabeledField(
          label: 'Parent Asset',
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              side: BorderSide(color: AppColors.border),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.account_tree_outlined, color: AppColors.primary),
              title: Text(
                parent == null ? 'None (top-level asset)' : '${parent.id} – ${parent.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body,
              ),
              trailing: parent == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => d.parentId = null),
                    ),
              onTap: () async {
                final id = await showAssetPicker(context, title: 'Parent Asset', selectedId: d.parentId);
                if (id != null) setState(() => d.parentId = id);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Tags',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _tagInput,
                style: inputStyle,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Type a tag and press +',
                  suffixIcon: IconButton(tooltip: 'Add tag', icon: const Icon(Icons.add_rounded), onPressed: _addTag),
                ),
                onSubmitted: (_) => _addTag(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in d.tags)
                    InputChip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => setState(() => d.tags = [...d.tags]..remove(t)),
                    ),
                  for (final t in _suggestedTags.where((t) => !d.tags.contains(t)))
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => d.tags = [...d.tags, t]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addTag() {
    final t = _tagInput.text.trim();
    if (t.isEmpty) return;
    setState(() {
      if (!d.tags.contains(t)) d.tags = [...d.tags, t];
      _tagInput.clear();
    });
  }

  // ---------------------------------------------------------------- step 3

  Widget _locationStep() {
    final buildings = d.site == null ? const <String>[] : locationTree[d.site]!.keys.toList();
    final floors = d.building == null ? const <String>[] : locationTree[d.site]![d.building]!.keys.toList();
    final zones = d.floor == null ? const <String>[] : locationTree[d.site]![d.building]![d.floor]!;
    Widget dd(
      String label,
      String? value,
      List<String> options,
      ValueChanged<String?> onChanged, {
      bool required = true,
      String hint = 'Select',
    }) => LabeledField(
      label: label,
      required: required,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-${options.join()}'),
        initialValue: value,
        isExpanded: true,
        hint: Text(options.isEmpty ? '—' : hint, style: hintStyle),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: options.isEmpty ? null : onChanged,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Location & Custody'),
        FieldPair(
          dd(
            'Site',
            d.site,
            locationTree.keys.toList(),
            (v) => setState(() {
              d.site = v;
              d.building = d.floor = d.zone = null;
            }),
          ),
          dd(
            'Building',
            d.building,
            buildings,
            (v) => setState(() {
              d.building = v;
              d.floor = d.zone = null;
            }),
          ),
        ),
        FieldPair(
          dd(
            'Floor',
            d.floor,
            floors,
            (v) => setState(() {
              d.floor = v;
              d.zone = null;
            }),
          ),
          dd('Room / Zone', d.zone, zones, (v) => setState(() => d.zone = v), required: false),
        ),
        _error(_locationError),
        if (d.building != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: IconLine(
              icon: Icons.location_on_outlined,
              text: '${d.site} · ${d.location}',
              color: AppColors.primary,
            ),
          ),
        LabeledField(
          label: 'Custodian',
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              side: BorderSide(color: AppColors.border),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.person_outline_rounded, color: AppColors.primary),
              title: Text(d.custodian, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickCustodian,
            ),
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Department',
          child: DropdownButtonFormField<String>(
            key: ValueKey('dept-${d.department}'),
            initialValue: d.department,
            isExpanded: true,
            hint: Text('Select department', style: hintStyle),
            items: [
              for (final o in departments)
                DropdownMenuItem(
                  value: o,
                  child: Text(o, style: inputStyle),
                ),
            ],
            onChanged: (v) => setState(() => d.department = v),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustodian() async {
    final people = ref.read(peopleProvider);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Select Custodian', style: AppText.sectionTitle),
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Unassigned'),
                onTap: () => Navigator.pop(context, 'Unassigned'),
              ),
              for (final p in people)
                ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(p.initials, style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
                  title: Text(p.name),
                  subtitle: Text(p.role, style: AppText.caption),
                  selected: d.custodian == p.labelWithRole,
                  onTap: () => Navigator.pop(context, p.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    setState(() {
      if (chosen == 'Unassigned') {
        d.custodian = 'Unassigned';
        return;
      }
      final p = people.firstWhere((x) => x.id == chosen);
      d.custodian = p.labelWithRole;
      if (departments.contains(p.department)) d.department = p.department;
    });
  }

  // ---------------------------------------------------------------- step 4

  Widget _additional() {
    final unlinked = ref.watch(unlinkedIotDevicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Additional Information'),
        FieldPair(
          LabeledField(
            label: 'Purchase Cost (AED)',
            child: TextFormField(
              controller: _cost,
              style: inputStyle,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0'),
              validator: (v) {
                final s = (v ?? '').replaceAll(',', '').trim();
                if (s.isEmpty) return null;
                final n = double.tryParse(s);
                return n == null || n < 0 ? 'Enter an amount' : null;
              },
            ),
          ),
          LabeledField(
            label: 'Expected Life (years)',
            child: TextFormField(
              controller: _life,
              style: inputStyle,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return n == null || n < 1 || n > 50 ? '1 – 50 years' : null;
              },
            ),
          ),
        ),
        FieldPair(
          LabeledField(
            label: 'Supplier',
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: d.supplier),
              optionsBuilder: (v) => suppliers.where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => d.supplier = v,
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextFormField(
                controller: controller,
                style: inputStyle,
                focusNode: focus,
                onChanged: (v) => d.supplier = v.trim(),
                decoration: const InputDecoration(hintText: 'Supplier'),
              ),
            ),
          ),
          LabeledField(
            label: 'PO Number',
            child: TextFormField(
              controller: _po,
              style: inputStyle,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'PO-2026-…'),
            ),
          ),
        ),
        LabeledField(
          label: 'Warranty Expiry',
          required: true,
          child: DateBox(value: d.warranty, error: _warrantyError, onPicked: (v) => setState(() => d.warranty = v)),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: FieldLabel('Annual Maintenance Contract (AMC)')),
            Switch(value: d.amc, onChanged: (v) => setState(() => d.amc = v)),
          ],
        ),
        if (d.amc) ...[
          TextFormField(
            controller: _amcVendor,
            style: inputStyle,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'AMC vendor *'),
            validator: (v) => d.amc && (v ?? '').trim().isEmpty ? 'Enter the AMC vendor' : null,
          ),
          const SizedBox(height: 14),
        ],
        LabeledField(
          label: 'Documents (${d.docs.length})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, f) in d.docs.indexed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: IconSquare(icon: Icons.description_outlined, tone: TileTone.lavender, size: 34),
                  title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
                  subtitle: Text('${_docType(f.name)} · ${f.sizeMb.toStringAsFixed(1)} MB', style: AppText.caption),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => d.docs = [...d.docs]..removeAt(i)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _pickDocs,
                icon: const Icon(Icons.attach_file_rounded, size: 20),
                label: const Text('Add Documents'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Link IoT Device (optional)',
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              side: BorderSide(color: AppColors.border),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.sensors_rounded, color: AppColors.primary),
              title: Text(
                d.iot == null ? 'No device' : '${d.iot!.model} · ${d.iot!.type}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body,
              ),
              subtitle: Text(
                d.iot == null ? '${unlinked.length} unlinked devices available' : 'IMEI ${d.iot!.imei}',
                style: AppText.caption,
              ),
              trailing: d.iot == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Unlink',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => d.iot = null),
                    ),
              onTap: () async {
                if (unlinked.isEmpty) {
                  context.showSnack('No unlinked IoT devices in the store');
                  return;
                }
                final dev = await showIotDevicePicker(context, unlinked);
                if (dev != null) setState(() => d.iot = dev);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.path, required this.onPicked});

  final String? path;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    Future<void> pick() async {
      final p = await pickPhoto(context);
      if (p != null) onPicked(p);
    }

    return AspectRatio(
      aspectRatio: 1.05,
      child: GestureDetector(
        onTap: path == null ? pick : () => openPhotoViewer(context, [path!]),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.greyBg,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path == null)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.textMuted),
                    const SizedBox(height: 4),
                    Text('Add photo', style: AppText.caption),
                  ],
                )
              else
                Image(image: photoProvider(path!), fit: BoxFit.cover),
              Positioned(
                right: 6,
                bottom: 6,
                child: Material(
                  color: AppColors.text.withValues(alpha: .8),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: path == null ? 'Add photo' : 'Change photo',
                    visualDensity: VisualDensity.compact,
                    onPressed: pick,
                    icon: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
