import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/models/person.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Custodian search → Custodian Details → Effective Date, Notes → Assign Custodian
/// (a completed "Assign Custodian" movement; the asset's custodian changes everywhere).
class AssignCustodianScreen extends ConsumerStatefulWidget {
  const AssignCustodianScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<AssignCustodianScreen> createState() => _AssignCustodianScreenState();
}

class _AssignCustodianScreenState extends ConsumerState<AssignCustodianScreen> {
  String? _personId;
  DateTime? _date = DemoClock.today;
  final _notes = TextEditingController();
  final _errors = <String, String>{};

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _assign(Asset a) {
    _errors.clear();
    final p = ref.read(personByIdProvider(_personId));
    if (p == null) {
      _errors['person'] = 'Choose the custodian';
    } else if (a.custodian == p.labelWithRole) {
      _errors['person'] = '${p.name} is already the custodian';
    }
    if (_date == null) {
      _errors['date'] = 'Choose the effective date';
    } else if (_date!.isBefore(DemoClock.today)) {
      _errors['date'] = 'The date cannot be in the past';
    }
    setState(() {});
    if (_errors.isNotEmpty) return;
    final here = MovePlace(a.location);
    final notes = _notes.text.trim();
    final id = ref
        .read(movementsProvider.notifier)
        .submit(
          assetId: a.id,
          type: MoveType.assign,
          from: here,
          to: here,
          newCustodian: p!.labelWithRole,
          requiredDate: _date,
          reason: MoveType.assign,
          remarks: notes.isEmpty ? null : notes,
        );
    finishAction(context, '${p.name} is now custodian of ${a.id} ($id)');
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(personByIdProvider(_personId));
    return MoreActionPage(
      action: MoreAction.assignCustodian,
      assetId: widget.assetId,
      button: (a) => FilledButton(onPressed: () => _assign(a), child: const Text('Assign Custodian')),
      builder: (context, a) => [
        formField(
          'Custodian',
          required: true,
          PersonField(
            personId: _personId,
            title: 'Select Custodian',
            hint: 'Search by name or employee ID',
            error: _errors['person'],
            onChanged: (id) => setState(() {
              _personId = id;
              _errors.remove('person');
            }),
          ),
        ),
        if (person != null) ...[_CustodianDetails(person: person), const SizedBox(height: 14)],
        formField(
          'Effective Date',
          required: true,
          DateBox(
            value: _date,
            firstDate: DemoClock.today,
            error: _errors['date'],
            onPicked: (d) => setState(() {
              _date = d;
              _errors.remove('date');
            }),
          ),
        ),
        formField(
          'Notes',
          TextField(
            controller: _notes,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: inputStyle,
            decoration: const InputDecoration(hintText: 'Optional'),
          ),
        ),
        Text('Current custodian: ${a.custodian}', style: AppText.caption),
      ],
    );
  }
}

class _CustodianDetails extends StatelessWidget {
  const _CustodianDetails({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Custodian Details',
      child: Row(
        children: [
          PersonAvatar(person: person, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(person.role, style: AppText.caption),
                const SizedBox(height: 6),
                InfoRow(label: 'Employee ID', value: employeeId(person), labelWidth: 96),
                InfoRow(label: 'Department', value: person.department ?? '—', labelWidth: 96),
                if (person.phone != null) InfoRow(label: 'Phone', value: person.phone!, labelWidth: 96),
              ],
            ),
          ),
          Icon(Icons.verified_user_outlined, color: AppColors.primary),
        ],
      ),
    );
  }
}
