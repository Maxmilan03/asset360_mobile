import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';

/// Check Out (to a person until a return date) or Check In (condition, notes, photo).
/// Both add a completed movement record through MovementsNotifier, which updates the custodian.
class CheckInOutScreen extends ConsumerStatefulWidget {
  const CheckInOutScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<CheckInOutScreen> createState() => _CheckInOutScreenState();
}

class _CheckInOutScreenState extends ConsumerState<CheckInOutScreen> {
  int? _tab; // 0 = Check Out, 1 = Check In; defaults from the asset's state
  String? _personId;
  DateTime? _returnDate;
  String? _purpose;
  String? _condition;
  List<String> _photos = [];
  final _outNotes = TextEditingController();
  final _inNotes = TextEditingController();
  final _errors = <String, String>{};

  @override
  void dispose() {
    _outNotes.dispose();
    _inNotes.dispose();
    super.dispose();
  }

  bool _checkedOut(Asset a) => ref.watch(movementsProvider).checkedOutAssetIds.contains(a.id);

  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  void _checkOut(Asset a) {
    _errors.clear();
    if (_personId == null) _errors['person'] = 'Choose who takes the asset';
    if (_returnDate != null && _returnDate!.isBefore(DemoClock.today)) {
      _errors['date'] = 'The return date cannot be in the past';
    }
    if (_purpose == null) _errors['purpose'] = 'Choose the purpose';
    setState(() {});
    if (_errors.isNotEmpty) return;
    final person = ref.read(personByIdProvider(_personId))!;
    final here = MovePlace(a.location);
    final id = ref
        .read(movementsProvider.notifier)
        .submit(
          assetId: a.id,
          type: MoveType.checkOut,
          from: here,
          to: here,
          newCustodian: person.labelWithRole,
          requiredDate: _returnDate,
          reason: _purpose,
          remarks: _text(_outNotes),
        );
    finishAction(
      context,
      '${a.id} checked out to ${person.name}'
      '${_returnDate == null ? '' : ' until ${DemoClock.formatDate(_returnDate!)}'} ($id)',
    );
  }

  void _checkIn(Asset a) {
    _errors.clear();
    if (_condition == null) _errors['condition'] = 'Choose the condition';
    setState(() {});
    if (_errors.isNotEmpty) return;
    final here = MovePlace(a.location);
    final id = ref
        .read(movementsProvider.notifier)
        .submit(
          assetId: a.id,
          type: MoveType.checkIn,
          from: here,
          to: here,
          reason: MoveType.checkIn,
          remarks: _text(_inNotes),
          condition: _condition,
          photos: _photos,
        );
    finishAction(context, '${a.id} checked in · condition $_condition ($id)');
  }

  @override
  Widget build(BuildContext context) {
    return MoreActionPage(
      action: MoreAction.checkInOut,
      assetId: widget.assetId,
      button: (a) {
        final out = _checkedOut(a);
        final tab = _tab ?? (out ? 1 : 0);
        return tab == 0
            ? FilledButton(onPressed: out ? null : () => _checkOut(a), child: const Text('Check Out'))
            : FilledButton(onPressed: out ? () => _checkIn(a) : null, child: const Text('Check In'));
      },
      builder: (context, a) {
        final out = _checkedOut(a);
        final tab = _tab ?? (out ? 1 : 0);
        return [
          SegmentTabs(
            tabs: const [SegmentTab('Check Out'), SegmentTab('Check In')],
            selected: tab,
            onChanged: (i) => setState(() {
              _tab = i;
              _errors.clear();
            }),
          ),
          const SizedBox(height: 14),
          if (tab == 0 && out) _Notice('${a.id} is checked out to ${a.custodian}. Check it in first.'),
          if (tab == 1 && !out) _Notice('${a.id} is not checked out. Check In is available after a Check Out.'),
          if (tab == 0) ..._checkOutForm(a, enabled: !out) else ..._checkInForm(enabled: out),
        ];
      },
    );
  }

  List<Widget> _checkOutForm(Asset a, {required bool enabled}) => [
    IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            formField(
              'Assign To',
              required: true,
              PersonField(
                personId: _personId,
                title: 'Assign To',
                error: _errors['person'],
                onChanged: (id) => setState(() {
                  _personId = id;
                  _errors.remove('person');
                }),
              ),
            ),
            formField(
              'Expected Return Date',
              DateBox(
                value: _returnDate,
                firstDate: DemoClock.today,
                error: _errors['date'],
                onPicked: (d) => setState(() {
                  _returnDate = d;
                  _errors.remove('date');
                }),
              ),
            ),
            formField(
              'Purpose',
              required: true,
              SelectField(
                value: _purpose,
                options: checkOutPurposes,
                error: _errors['purpose'],
                onChanged: (v) => setState(() {
                  _purpose = v;
                  _errors.remove('purpose');
                }),
              ),
            ),
            formField(
              'Notes',
              TextField(
                controller: _outNotes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: inputStyle,
                decoration: const InputDecoration(hintText: 'Accessories handed over, condition …'),
              ),
            ),
            Text('Current custodian: ${a.custodian}', style: AppText.caption),
          ],
        ),
      ),
    ),
  ];

  List<Widget> _checkInForm({required bool enabled}) => [
    IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Condition', required: true),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in AssetOptions.conditions)
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
            fieldError(_errors['condition']),
            const SizedBox(height: 14),
            formField(
              'Notes',
              TextField(
                controller: _inNotes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: inputStyle,
                decoration: const InputDecoration(hintText: 'Anything missing or damaged?'),
              ),
            ),
            const FieldLabel('Photo (optional)'),
            PhotoStrip(
              photos: _photos,
              onAdd: (p) => setState(() => _photos = [..._photos, p]),
              onRemove: (i) => setState(() => _photos = [..._photos]..removeAt(i)),
            ),
          ],
        ),
      ),
    ),
  ];
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(10)),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 13))),
      ],
    ),
  );
}
