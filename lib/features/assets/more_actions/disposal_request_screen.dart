import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/disposals_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Reason (Other → text), requested date and notes → a Pending disposal request,
/// approved or rejected in Home → Approvals. One pending request per asset.
class DisposalRequestScreen extends ConsumerStatefulWidget {
  const DisposalRequestScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<DisposalRequestScreen> createState() => _DisposalRequestScreenState();
}

class _DisposalRequestScreenState extends ConsumerState<DisposalRequestScreen> {
  String? _reason;
  final _other = TextEditingController();
  DateTime? _date;
  final _notes = TextEditingController();
  final _errors = <String, String>{};

  @override
  void dispose() {
    _other.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit(Asset a) async {
    _errors.clear();
    if (_reason == null) _errors['reason'] = 'Choose the disposal reason';
    if (_reason == disposalOtherReason && _other.text.trim().isEmpty) _errors['other'] = 'Describe the reason';
    if (_date == null) {
      _errors['date'] = 'Choose the requested date';
    } else if (_date!.isBefore(DemoClock.today)) {
      _errors['date'] = 'The date cannot be in the past';
    }
    setState(() {});
    if (_errors.isNotEmpty) return;
    final reason = _reason == disposalOtherReason ? 'Other: ${_other.text.trim()}' : _reason!;
    final notes = _notes.text.trim();
    final id = ref
        .read(disposalsProvider.notifier)
        .submit(assetId: a.id, reason: reason, requestedDate: _date!, notes: notes.isEmpty ? null : notes);
    if (id == null) {
      context.showSnack('${a.id} already has a pending disposal request');
      return;
    }
    final openApprovals = await showSuccessSheet(
      context,
      title: 'Disposal request submitted',
      message: '$id for ${a.id} is Pending approval. Approve or reject it in Home → Approvals.',
      primaryLabel: 'Done',
      secondaryLabel: 'Open Approvals',
    );
    if (!mounted) return;
    if (openApprovals) {
      finishAction(context, 'Disposal request $id submitted');
    } else {
      context.go(Routes.approvals);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disposals = ref.watch(disposalsProvider);
    return MoreActionPage(
      action: MoreAction.disposal,
      assetId: widget.assetId,
      button: (a) {
        final blocked = disposals.pendingFor(a.id) != null || a.status == AssetStatus.disposed;
        return FilledButton(onPressed: blocked ? null : () => _submit(a), child: const Text('Submit Request'));
      },
      builder: (context, a) {
        final pending = disposals.pendingFor(a.id);
        return [
          if (pending != null || a.status == AssetStatus.disposed)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pending != null
                          ? '${pending.id} (${pending.reason}) is waiting for approval. '
                                'A second request cannot be made.'
                          : '${a.id} is already disposed.',
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          formField(
            'Disposal Reason',
            required: true,
            SelectField(
              value: _reason,
              options: disposalReasons,
              error: _errors['reason'],
              onChanged: (v) => setState(() {
                _reason = v;
                _errors.remove('reason');
              }),
            ),
          ),
          if (_reason == disposalOtherReason)
            formField(
              'Other reason',
              required: true,
              TextField(
                controller: _other,
                style: inputStyle,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: 'Why should it be disposed?', errorText: _errors['other']),
              ),
            ),
          formField(
            'Requested Date',
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
              style: inputStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Disposal method, data wiping, buyer …'),
            ),
          ),
        ];
      },
    );
  }
}
