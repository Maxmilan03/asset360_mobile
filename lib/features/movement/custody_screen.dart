import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/movement.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/movements_repository.dart';
import '../../data/repositories/scans_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../assets/asset_ui.dart';
import 'movement_widgets.dart';

enum CustodyAction {
  checkOut(MoveType.checkOut, 'Check Out', 'Hand an asset to a person until a return date', Icons.person_rounded),
  checkIn(MoveType.checkIn, 'Check In', 'Take back a checked-out asset', Icons.download_rounded),
  assign(MoveType.assign, 'Assign Custodian', 'Make a person responsible for an asset', Icons.groups_rounded),
  returnAsset(MoveType.returnAsset, 'Return Asset', 'Send an asset back to a store or location', Icons.undo_rounded);

  const CustodyAction(this.type, this.title, this.subtitle, this.icon);
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Check Out, Check In, Assign Custodian and Return Asset: pick the asset, fill the details, confirm.
/// Each creates a completed movement record and updates the asset straight away.
class CustodyScreen extends ConsumerStatefulWidget {
  const CustodyScreen({super.key, required this.action, this.assetId});

  final CustodyAction action;
  final String? assetId;

  @override
  ConsumerState<CustodyScreen> createState() => _CustodyScreenState();
}

class _CustodyScreenState extends ConsumerState<CustodyScreen> {
  late String? _assetId = widget.assetId == null ? null : ref.read(assetsProvider).byCode(widget.assetId!)?.id;
  String? _custodian;
  String? _personId;
  DateTime? _date;
  String? _location;
  String? _condition;
  final _text = TextEditingController();
  List<String> _photos = [];
  final _errors = <String, String>{};

  CustodyAction get _a => widget.action;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<String>? get _candidates => switch (_a) {
    CustodyAction.checkIn => ref.read(movementsProvider).checkedOutAssetIds,
    _ => null,
  };

  bool _validate() {
    _errors.clear();
    final asset = _assetId == null ? null : ref.read(assetByIdProvider(_assetId!));
    if (asset == null) _errors['asset'] = 'Select an asset';
    switch (_a) {
      case CustodyAction.checkOut:
        if (asset != null && ref.read(movementsProvider).checkedOutAssetIds.contains(asset.id)) {
          _errors['asset'] = '${asset.id} is already checked out. Check it in first.';
        }
        if (_custodian == null) _errors['custodian'] = 'Choose who takes the asset';
        if (_date == null) _errors['date'] = 'Choose the expected return date';
        if (_text.text.trim().isEmpty) _errors['text'] = 'Enter the purpose';
      case CustodyAction.checkIn:
        if (_condition == null) _errors['condition'] = 'Choose the condition';
      case CustodyAction.assign:
        if (_personId == null) _errors['person'] = 'Choose a person';
        if (_date == null) _errors['date'] = 'Choose the effective date';
        final p = ref.read(personByIdProvider(_personId));
        if (asset != null && p != null && asset.custodian == p.labelWithRole) {
          _errors['person'] = '${p.name} is already the custodian';
        }
      case CustodyAction.returnAsset:
        if (_location == null) _errors['location'] = 'Choose where it is returned to';
        if (_condition == null) _errors['condition'] = 'Choose the condition';
    }
    if (_date != null && _date!.isBefore(DemoClock.today)) _errors['date'] = 'The date cannot be in the past';
    setState(() {});
    return _errors.isEmpty;
  }

  Future<void> _confirm() async {
    if (!_validate()) return;
    final asset = ref.read(assetByIdProvider(_assetId!))!;
    final person = ref.read(personByIdProvider(_personId));
    final here = MovePlace(asset.location);
    final remarks = _text.text.trim().isEmpty ? null : _text.text.trim();
    final (to, custodian, summary) = switch (_a) {
      CustodyAction.checkOut => (here, _custodian, '${asset.id} checked out to $_custodian'),
      CustodyAction.checkIn => (here, null, '${asset.id} checked in (custodian cleared)'),
      CustodyAction.assign => (here, person!.labelWithRole, '${person.name} is now custodian of ${asset.id}'),
      CustodyAction.returnAsset => (
        MovePlace(_location!, null, null, _location),
        null,
        '${asset.id} returned to $_location',
      ),
    };
    final ok = await showConfirmDialog(
      context,
      title: '${_a.title}?',
      message: '$summary.\nA movement record is added to the history.',
      confirmLabel: 'Confirm',
    );
    if (!ok || !mounted) return;
    final id = ref
        .read(movementsProvider.notifier)
        .submit(
          assetId: asset.id,
          type: _a.type,
          from: here,
          to: to,
          newCustodian: custodian,
          requiredDate: _date,
          reason: _a == CustodyAction.checkOut ? remarks : _a.title,
          remarks: _a == CustodyAction.checkOut ? null : remarks,
          condition: _condition,
          photos: _photos,
        );
    await showSuccessSheet(context, title: '${_a.title} complete', message: '$summary. Record $id.');
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider);
    final candidates = _candidates;
    final asset = _assetId == null ? null : ref.watch(assetByIdProvider(_assetId!));
    var n = 0;
    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text('${++n}. $title', style: AppText.sectionTitle),
    );
    Widget error(String key) => _errors[key] == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_errors[key]!, style: AppText.caption.copyWith(color: AppColors.red)),
          );
    Widget dropdown(String key, String? value, List<(String, String)> items, ValueChanged<String?> onChanged) =>
        DropdownButtonFormField<String>(
          key: ValueKey(key),
          initialValue: value,
          isExpanded: true,
          hint: Text('Select', style: hintStyle),
          decoration: InputDecoration(errorText: _errors[key]),
          items: [
            for (final (v, label) in items)
              DropdownMenuItem(
                value: v,
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            _errors.remove(key);
            onChanged(v);
          }),
        );
    Widget conditionChips() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in moveConditions)
              IconFilterChip(
                label: c,
                selected: _condition == c,
                onTap: () => setState(() {
                  _condition = c;
                  _errors.remove('condition');
                }),
              ),
          ],
        ),
        error('condition'),
      ],
    );

    return AppScaffold(
      bottomActions: FilledButton(onPressed: _confirm, child: Text('Confirm ${_a.title}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          PageTitle(
            leading: Icon(_a.icon, color: AppColors.text, size: 22),
            title: _a.title,
            subtitle: _a.subtitle,
          ),
          if (_a == CustodyAction.checkIn) ...[
            section('Checked-out asset'),
            if (candidates!.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nothing is checked out',
                  message: 'Assets you check out appear here until they are checked in.',
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final id in candidates)
                      if (ref.watch(assetByIdProvider(id)) case final a?)
                        AssetListTile(
                          title: a.id,
                          subtitle: a.name,
                          location: a.location,
                          imagePath: a.imagePath,
                          fallbackIcon: assetIcon(a),
                          details: [IconLine(icon: Icons.person_outline_rounded, text: 'With ${a.custodian}')],
                          selected: _assetId == a.id,
                          trailingTop: Icon(
                            _assetId == a.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: AppColors.primary,
                          ),
                          showChevron: false,
                          onTap: () => setState(() {
                            _assetId = a.id;
                            _errors.remove('asset');
                          }),
                        ),
                  ],
                ),
              ),
            error('asset'),
          ] else ...[
            section('Asset'),
            AssetChooser(
              assetId: _assetId,
              candidates: candidates,
              error: _errors['asset'],
              onChanged: (id) => setState(() {
                _assetId = id;
                _errors.remove('asset');
              }),
            ),
          ],
          switch (_a) {
            CustodyAction.checkOut => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section('Custodian'),
                dropdown('custodian', _custodian, [
                  for (final c in custodianOptions(ref))
                    if (c == _custodian || (c != 'Unassigned' && c != asset?.custodian)) (c, c),
                ], (v) => _custodian = v),
                section('Expected return date'),
                DateBox(
                  value: _date,
                  firstDate: DemoClock.today,
                  error: _errors['date'],
                  onPicked: (d) => setState(() {
                    _date = d;
                    _errors.remove('date');
                  }),
                ),
                section('Purpose'),
                TextField(
                  controller: _text,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: 'e.g. Site visit at Building B', errorText: _errors['text']),
                ),
              ],
            ),
            CustodyAction.checkIn => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section('Condition'),
                conditionChips(),
                section('Remarks'),
                TextField(
                  controller: _text,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Anything missing or damaged?'),
                ),
                section('Photo'),
                PhotoStrip(
                  photos: _photos,
                  onAdd: (p) => setState(() => _photos = [..._photos, p]),
                  onRemove: (i) => setState(() => _photos = [..._photos]..removeAt(i)),
                ),
              ],
            ),
            CustodyAction.assign => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section('Person'),
                dropdown('person', _personId, [for (final p in people) (p.id, p.labelWithRole)], (v) => _personId = v),
                section('Effective date'),
                DateBox(
                  value: _date,
                  firstDate: DemoClock.today,
                  error: _errors['date'],
                  onPicked: (d) => setState(() {
                    _date = d;
                    _errors.remove('date');
                  }),
                ),
              ],
            ),
            CustodyAction.returnAsset => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section('Return to'),
                dropdown('location', _location, [
                  for (final l in scanLocations)
                    if (l != asset?.location) (l, l),
                ], (v) => _location = v),
                section('Condition'),
                conditionChips(),
                section('Remarks'),
                TextField(
                  controller: _text,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Optional'),
                ),
              ],
            ),
          },
          if (_a == CustodyAction.checkOut || _a == CustodyAction.assign)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Current custodian: ${asset?.custodian ?? '—'}', style: AppText.caption),
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => context.push(Routes.movementHistory),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Movement History'),
          ),
        ],
      ),
    );
  }
}
