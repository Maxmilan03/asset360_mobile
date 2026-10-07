import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/people_mock.dart';
import '../../data/mock/registration_mock.dart';
import '../../data/models/asset.dart';
import '../../data/models/common.dart';
import '../../data/models/movement.dart';
import '../../data/models/person.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/movements_repository.dart';
import '../../data/repositories/repo_utils.dart';
import '../../data/repositories/session_repository.dart';
import '../assets/asset_ui.dart';
import '../common/scan_capture.dart';
import '../scan/scan_flow.dart';
import 'movement_widgets.dart';

enum _Pick { scan, search, mine }

enum DestKind { location, department, person }

/// Transfer Asset (middle and right screens of design/07_movement_custody.jpg):
/// Asset → From → To → Details → Review, then Submit for Approval.
class TransferAssetScreen extends ConsumerStatefulWidget {
  const TransferAssetScreen({super.key, this.assetIds = const []});

  /// Preselected assets (`?asset=` or `?assets=` from Multi Scan); one request is created for each.
  final List<String> assetIds;

  @override
  ConsumerState<TransferAssetScreen> createState() => _TransferAssetScreenState();
}

class _TransferAssetScreenState extends ConsumerState<TransferAssetScreen> {
  static const _steps = ['Asset', 'From', 'To', 'Details', 'Review'];

  int _step = 0;
  final _scroll = ScrollController();
  late List<String> _assetIds = [
    for (final id in widget.assetIds)
      if (ref.read(assetsProvider).byCode(id) != null) ref.read(assetsProvider).byCode(id)!.id,
  ];

  // Step 1
  _Pick _pick = _Pick.scan;
  String _query = '';
  String? _assetError;

  // Step 2
  bool _editFrom = false;
  String? _fromLocation;
  String? _fromCustodian;

  // Step 3
  DestKind _dest = DestKind.location;
  String? _site, _building, _floor, _zone, _department, _personId;
  String? _toError;

  // Step 4
  String? _newCustodian;
  DateTime? _requiredDate;
  String? _reason;

  /// Who approves the transfer. The demo has one login, so the signed-in user may pick themselves to try My Approvals.
  String _approverId = PersonIds.ahmed;
  final _remarks = TextEditingController();
  List<Attachment> _attachments = [];
  String? _custodianError, _dateError, _reasonError;

  Asset? get _asset => _assetIds.isEmpty ? null : ref.read(assetByIdProvider(_assetIds.first));

  @override
  void dispose() {
    _remarks.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- selection

  void _select(String id) => setState(() {
    _assetIds = [id];
    _assetError = null;
    _fromLocation = null;
    _fromCustodian = null;
    _editFrom = false;
  });

  Future<void> _scan() async {
    final code = await showScanCapture(
      context,
      title: 'Scan QR / Barcode / RFID',
      suggestions: const ['LAP-0098', 'CAM-0044', 'PRJ-0042'],
    );
    if (code == null || !mounted) return;
    final id = assetIdForCode(context, ref, code);
    if (id != null) _select(id);
  }

  Future<void> _manual() async {
    final code = await showManualEntrySheet(context);
    if (code == null || !mounted) return;
    final id = assetIdForCode(context, ref, code);
    if (id != null) _select(id);
  }

  // ---------------------------------------------------------------- places

  MovePlace get _from {
    final a = _asset!;
    return MovePlace(_fromLocation ?? a.location);
  }

  String get _fromCust => _fromCustodian ?? _asset!.custodian;

  Person? get _person => _personId == null ? null : ref.read(personByIdProvider(_personId));

  MovePlace? get _to => switch (_dest) {
    DestKind.location =>
      _floor == null
          ? null
          : MovePlace(_zone ?? _floor!, _building, _site, '$_building / $_floor${_zone == null ? '' : ' – $_zone'}'),
    DestKind.department => _department == null ? null : MovePlace.party('$_department Department', 'Department'),
    DestKind.person => _person == null ? null : MovePlace.party(_person!.name, _person!.department ?? _person!.role),
  };

  /// New custodian suggested by the destination (a person, or someone in the department).
  String? get _suggestedCustodian => switch (_dest) {
    DestKind.person => _person?.labelWithRole,
    DestKind.department =>
      ref.read(peopleProvider).firstWhereOrNull((p) => p.department == _department)?.labelWithRole ??
          (_department == null ? null : '$_department Department'),
    DestKind.location => _fromCust,
  };

  List<String> get _custodianChoices {
    final people = ref.read(peopleProvider).map((p) => p.labelWithRole);
    return {?_suggestedCustodian, ...people, ...custodianOptions(ref)}.toList();
  }

  MovementRequest get _draft => MovementRequest(
    id: 'Draft',
    assetId: _asset!.id,
    type: MoveType.transfer,
    status: MoveStatus.pending,
    from: _from,
    to: _to ?? const MovePlace('—'),
    requesterId: ref.read(currentUserProvider).id,
    createdAt: DemoClock.now,
    fromCustodian: _fromCust,
    newCustodian: _newCustodian,
    requiredDate: _requiredDate,
    reason: _reason,
    remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
    attachments: _attachments,
    approverId: _approverId,
  );

  // ---------------------------------------------------------------- navigation

  bool _validate() {
    switch (_step) {
      case 0:
        setState(() => _assetError = _assetIds.isEmpty ? 'Select an asset to transfer' : null);
        return _assetIds.isNotEmpty;
      case 2:
        final to = _to;
        setState(
          () => _toError = to == null
              ? switch (_dest) {
                  DestKind.location => 'Choose the site, building and floor',
                  DestKind.department => 'Choose a department',
                  DestKind.person => 'Choose a person',
                }
              : (to.assetLocation != null && to.assetLocation == _from.name && _dest == DestKind.location)
              ? 'The destination is the asset\'s current location'
              : null,
        );
        if (_toError == null) _newCustodian ??= _suggestedCustodian;
        return _toError == null;
      case 3:
        setState(() {
          _custodianError = _newCustodian == null ? 'Choose the new custodian' : null;
          _dateError = _requiredDate == null
              ? 'Choose the required date'
              : _requiredDate!.isBefore(DemoClock.today)
              ? 'The date cannot be in the past'
              : null;
          _reasonError = _reason == null ? 'Choose a reason' : null;
        });
        return _custodianError == null && _dateError == null && _reasonError == null;
    }
    return true;
  }

  /// Every step opens at its top.
  void _goTo(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    if (!_validate()) return;
    _goTo(_step + 1);
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      _goTo(_step - 1);
    }
  }

  Future<void> _submit() async {
    final movements = ref.read(movementsProvider.notifier);
    final ids = <String>[];
    for (final (i, id) in _assetIds.indexed) {
      final a = ref.read(assetByIdProvider(id))!;
      ids.add(
        movements.submit(
          assetId: id,
          type: MoveType.transfer,
          from: i == 0 ? _from : MovePlace(a.location),
          to: _to!,
          newCustodian: _newCustodian,
          requiredDate: _requiredDate,
          reason: _reason,
          remarks: _draft.remarks,
          attachments: _attachments,
          approverId: _approverId,
        ),
      );
    }
    final self = _approverId == ref.read(currentUserProvider).id;
    final approver = self ? 'you' : ref.read(personByIdProvider(_approverId))?.name ?? 'the approver';
    await showSuccessSheet(
      context,
      title: ids.length == 1 ? 'Request ${ids.first} submitted' : '${ids.length} requests submitted',
      message:
          '${ids.join(', ')} ${ids.length == 1 ? 'is' : 'are'} waiting for approval by $approver.'
          '${self ? ' Approve it from Home → My Approvals.' : ''}',
      primaryLabel: 'Back to Movement & Custody',
    );
    if (mounted) context.go(Routes.movement);
  }

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles();
      final picked = <Attachment>[];
      for (final f in files) {
        final bytes = await f.length() ?? 0;
        picked.add(Attachment(name: f.name, sizeKb: (bytes / 1024).ceil(), path: f.path));
      }
      if (picked.isNotEmpty) setState(() => _attachments = [..._attachments, ...picked]);
    } catch (_) {
      if (mounted) context.showSnack('Could not open files. Allow file access and try again.');
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    ref.watch(assetsProvider);
    final review = _step == 4;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AppScaffold(
        backgroundColor: AppColors.surface,
        bottomActions: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(onPressed: _back, child: const Text('Back')),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: _step > 0 ? 3 : 1,
              child: review
                  ? FilledButton(onPressed: _submit, child: const Text('Submit for Approval'))
                  : FilledButton(
                      onPressed: _step == 0 && _assetIds.isEmpty ? null : _next,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text('Next'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 18)],
                      ),
                    ),
            ),
          ],
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            PageTitle(
              leading: Icon(Icons.swap_horizontal_circle_outlined, color: AppColors.text, size: 22),
              title: 'Transfer Asset',
              subtitle: review
                  ? 'Review the details and submit for approval'
                  : 'Move asset from one location or custodian to another',
            ),
            const SizedBox(height: 16),
            StepperHeader(steps: _steps, current: _step, onStepTap: _goTo),
            const SizedBox(height: 18),
            switch (_step) {
              0 => _assetStep(),
              1 => _fromStep(),
              2 => _toStep(),
              3 => _detailsStep(),
              _ => MovementSummary(
                request: _draft,
                asset: _asset!,
                extraAssets: [for (final id in _assetIds.skip(1)) ?ref.read(assetByIdProvider(id))],
                onEditAsset: () => _goTo(0),
                onEditDetails: () => _goTo(3),
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: AppText.sectionTitle),
  );

  // ---------------------------------------------------------------- step 1

  Widget _assetStep() {
    final asset = _asset;
    final all = ref.watch(assetsProvider);
    final list = switch (_pick) {
      _Pick.search => _query.trim().isEmpty ? const <Asset>[] : all.search(_query).take(6).toList(),
      _Pick.mine => ref.watch(myAssetsProvider),
      _Pick.scan => const <Asset>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('1. Select Asset'),
        Row(
          children: [
            for (final (p, label) in [
              (_Pick.scan, 'Scan Asset'),
              (_Pick.search, 'Search Asset'),
              (_Pick.mine, 'My Assets'),
            ]) ...[
              if (p != _Pick.scan) const SizedBox(width: 8),
              Expanded(
                child: _ToggleButton(label: label, selected: _pick == p, onTap: () => setState(() => _pick = p)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_pick == _Pick.scan)
          InkWell(
            onTap: _scan,
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: DashedBorderPainter(color: AppColors.illustration, radius: 12),
              child: Container(
                height: 150,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.crop_free_rounded, size: 56, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text('Tap to Scan QR / Barcode / RFID', style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text('Position the asset tag within the frame', style: AppText.caption),
                  ],
                ),
              ),
            ),
          )
        else ...[
          if (_pick == _Pick.search)
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by Asset ID, name, serial or location',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          if (_pick == _Pick.mine && list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('No assets are assigned to you', textAlign: TextAlign.center, style: AppText.secondary),
            ),
          if (_pick == _Pick.search && _query.trim().isNotEmpty && list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('No assets match', textAlign: TextAlign.center, style: AppText.secondary),
            ),
          for (final a in list)
            AssetListTile(
              title: a.id,
              subtitle: a.name,
              location: a.location,
              imagePath: a.imagePath,
              fallbackIcon: assetIcon(a),
              selected: _assetIds.contains(a.id),
              trailingTop: StatusChip(a.status),
              showChevron: false,
              onTap: () => _select(a.id),
            ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('OR', style: AppText.caption),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _manual,
          icon: const Icon(Icons.keyboard_alt_outlined),
          label: const Text('Enter Asset ID Manually'),
        ),
        const SizedBox(height: 18),
        if (asset != null) ...[
          Text('Selected Asset', style: AppText.bodyStrong),
          const SizedBox(height: 8),
          SelectedAssetCard(asset: asset),
          if (_assetIds.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${_assetIds.length - 1} more from Multi Scan: ${_assetIds.skip(1).join(', ')}',
                style: AppText.caption.copyWith(color: AppColors.primary),
              ),
            ),
        ] else
          Text(
            _assetError ?? 'No asset selected yet',
            textAlign: TextAlign.center,
            style: AppText.secondary.copyWith(color: _assetError == null ? null : AppColors.red),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- step 2

  Widget _fromStep() {
    final a = _asset!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _title('2. From')),
            TextButton.icon(
              onPressed: () => setState(() => _editFrom = !_editFrom),
              icon: Icon(_editFrom ? Icons.check_rounded : Icons.edit_outlined, size: 18),
              label: Text(_editFrom ? 'Done' : 'Change'),
            ),
          ],
        ),
        Text('Prefilled from the asset record. Change it only if it is wrong.', style: AppText.secondary),
        const SizedBox(height: 12),
        if (!_editFrom)
          AppCard(
            child: Column(
              children: [
                InfoRow(label: 'Asset', value: '${a.id} – ${a.name}'),
                InfoRow(label: 'Current Location', value: _from.name),
                InfoRow(label: 'Current Custodian', value: _fromCust),
                InfoRow(label: 'Site', value: a.site),
              ],
            ),
          )
        else ...[
          LabeledField(
            label: 'Current Location',
            child: DropdownButtonFormField<String>(
              initialValue: _from.name,
              isExpanded: true,
              items: [
                for (final l in {_from.name, ...locationOptions(ref)})
                  DropdownMenuItem(
                    value: l,
                    child: Text(l, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _fromLocation = v),
            ),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Current Custodian',
            child: DropdownButtonFormField<String>(
              initialValue: _fromCust,
              isExpanded: true,
              items: [
                for (final c in {_fromCust, ...custodianOptions(ref)})
                  DropdownMenuItem(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _fromCustodian = v),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- step 3

  Widget _dropdown(String label, String? value, List<String> options, ValueChanged<String?> onChanged) => LabeledField(
    label: label,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-${options.join()}'),
      initialValue: value,
      isExpanded: true,
      hint: Text(options.isEmpty ? '—' : 'Select', style: hintStyle),
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

  Widget _toStep() {
    final buildings = _site == null ? const <String>[] : locationTree[_site]!.keys.toList();
    final floors = _building == null ? const <String>[] : locationTree[_site]![_building]!.keys.toList();
    final zones = _floor == null ? const <String>[] : locationTree[_site]![_building]![_floor]!;
    final people = ref.watch(peopleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('3. To'),
        Text('Destination type', style: AppText.bodyStrong),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (k, label) in [
              (DestKind.location, 'Location'),
              (DestKind.department, 'Department'),
              (DestKind.person, 'Person'),
            ]) ...[
              if (k != DestKind.location) const SizedBox(width: 8),
              Expanded(
                child: _ToggleButton(
                  label: label,
                  selected: _dest == k,
                  onTap: () => setState(() {
                    _dest = k;
                    _toError = null;
                    _newCustodian = null;
                  }),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (_dest == DestKind.location) ...[
          FieldPair(
            _dropdown(
              'Site',
              _site,
              locationTree.keys.toList(),
              (v) => setState(() {
                _site = v;
                _building = _floor = _zone = null;
              }),
            ),
            _dropdown(
              'Building',
              _building,
              buildings,
              (v) => setState(() {
                _building = v;
                _floor = _zone = null;
              }),
            ),
          ),
          FieldPair(
            _dropdown(
              'Floor',
              _floor,
              floors,
              (v) => setState(() {
                _floor = v;
                _zone = null;
              }),
            ),
            _dropdown('Room / Zone', _zone, zones, (v) => setState(() => _zone = v)),
          ),
        ] else if (_dest == DestKind.department)
          _dropdown('Department', _department, departments, (v) => setState(() => _department = v))
        else
          LabeledField(
            label: 'Person',
            child: DropdownButtonFormField<String>(
              initialValue: _personId,
              isExpanded: true,
              hint: Text('Select', style: hintStyle),
              items: [
                for (final p in people)
                  if (p.id != PersonIds.rex)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.labelWithRole, overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: (v) => setState(() => _personId = v),
            ),
          ),
        if (_toError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_toError!, style: AppText.caption.copyWith(color: AppColors.red)),
          ),
        if (_to case final to?) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PlaceCard(place: _from, tone: TileTone.sky),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_circle_right_outlined, color: AppColors.primary),
              ),
              Expanded(
                child: PlaceCard(place: to, tone: TileTone.mint),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- step 4

  /// Line manager (default) and, for the single-login demo, the signed-in user.
  List<Person> get _approvers => [
    for (final id in [PersonIds.ahmed, ref.read(currentUserProvider).id]) ?ref.read(personByIdProvider(id)),
  ];

  Widget _detailsStep() {
    final choices = _custodianChoices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('4. Details'),
        LabeledField(
          label: 'New Custodian',
          required: true,
          child: DropdownButtonFormField<String>(
            key: ValueKey('cust-$_newCustodian'),
            initialValue: choices.contains(_newCustodian) ? _newCustodian : null,
            isExpanded: true,
            hint: Text('Select', style: hintStyle),
            decoration: InputDecoration(errorText: _custodianError),
            items: [
              for (final c in choices)
                DropdownMenuItem(
                  value: c,
                  child: Text(c, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _newCustodian = v;
              _custodianError = null;
            }),
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Required Date',
          required: true,
          child: DateBox(
            value: _requiredDate,
            firstDate: DemoClock.today,
            error: _dateError,
            onPicked: (d) => setState(() {
              _requiredDate = d;
              _dateError = null;
            }),
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Reason',
          required: true,
          child: DropdownButtonFormField<String>(
            initialValue: _reason,
            isExpanded: true,
            hint: Text('Select reason', style: hintStyle),
            decoration: InputDecoration(errorText: _reasonError),
            items: [for (final r in moveReasons) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() {
              _reason = v;
              _reasonError = null;
            }),
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Approver',
          required: true,
          child: DropdownButtonFormField<String>(
            initialValue: _approverId,
            isExpanded: true,
            items: [
              for (final p in _approvers)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.id == ref.read(currentUserProvider).id
                        ? '${p.labelWithRole} – self-approve (demo)'
                        : p.labelWithRole,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _approverId = v ?? _approverId),
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Remarks',
          child: TextField(
            controller: _remarks,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. For Finance team use'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Attachments (${_attachments.length})', style: AppText.bodyStrong)),
            TextButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Add File'),
            ),
          ],
        ),
        for (final f in _attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AttachmentTile(
              attachment: f,
              onRemove: () => setState(() => _attachments = [..._attachments]..remove(f)),
            ),
          ),
      ],
    );
  }
}

/// Segmented toggle button (Scan Asset / Search Asset / My Assets; Location / Department / Person).
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
