import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Condition (New / Good / Fair / Poor), date, comments and photos → a condition-history record.
class UpdateConditionScreen extends ConsumerStatefulWidget {
  const UpdateConditionScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<UpdateConditionScreen> createState() => _UpdateConditionScreenState();
}

class _UpdateConditionScreenState extends ConsumerState<UpdateConditionScreen> {
  String? _condition;
  bool _preset = false;
  DateTime? _date = DemoClock.today;
  final _comments = TextEditingController();
  List<String> _photos = [];
  final _errors = <String, String>{};

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  void _save(Asset a) {
    _errors.clear();
    if (_condition == null) _errors['condition'] = 'Choose the condition';
    if (_date == null) {
      _errors['date'] = 'Choose the condition date';
    } else if (_date!.isAfter(DemoClock.today)) {
      _errors['date'] = 'The date cannot be in the future';
    }
    setState(() {});
    if (_errors.isNotEmpty) return;
    final comments = _comments.text.trim();
    ref
        .read(assetsProvider.notifier)
        .updateCondition(
          a.id,
          condition: _condition!,
          date: _date!,
          comments: comments.isEmpty ? null : comments,
          photos: _photos,
        );
    finishAction(context, '${a.id} condition updated to $_condition');
  }

  @override
  Widget build(BuildContext context) {
    return MoreActionPage(
      action: MoreAction.updateCondition,
      assetId: widget.assetId,
      button: (a) => FilledButton(onPressed: () => _save(a), child: const Text('Update Condition')),
      builder: (context, a) {
        // The current condition is preselected once (when it is one of the choices).
        if (!_preset) {
          _preset = true;
          if (conditionChoices.contains(a.condition)) _condition = a.condition;
        }
        return [
          const FieldLabel('Condition', required: true),
          SegmentedButton<String>(
            segments: [for (final c in conditionChoices) ButtonSegment(value: c, label: Text(c))],
            selected: {?_condition},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onSelectionChanged: (s) => setState(() {
              if (s.isNotEmpty) _condition = s.first;
              _errors.remove('condition');
            }),
          ),
          fieldError(_errors['condition']),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: Text('Current condition: ${a.condition}', style: AppText.caption),
          ),
          formField(
            'Condition Date',
            DateBox(
              value: _date,
              error: _errors['date'],
              onPicked: (d) => setState(() {
                _date = d;
                _errors.remove('date');
              }),
            ),
          ),
          formField(
            'Comments',
            TextField(
              controller: _comments,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: inputStyle,
              decoration: const InputDecoration(hintText: 'What did you observe?'),
            ),
          ),
          const FieldLabel('Add Photos (optional)'),
          PhotoStrip(
            photos: _photos,
            onAdd: (p) => setState(() => _photos = [..._photos, p]),
            onRemove: (i) => setState(() => _photos = [..._photos]..removeAt(i)),
          ),
        ];
      },
    );
  }
}
