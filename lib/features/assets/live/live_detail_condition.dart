import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_common.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// API mode "Update Condition": POST /api/asset-condition-assessments
/// (CreateAssetConditionAssessmentRequest). Required: assessment date (not in the future), overall
/// condition (GET …/ratings), health score 0–100. Optional: physical condition, performance, safety
/// (same ratings) and remarks (≤ 1000). Assessed By is the signed-in user (set by the server).
class LiveUpdateConditionScreen extends ConsumerStatefulWidget {
  const LiveUpdateConditionScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<LiveUpdateConditionScreen> createState() => _LiveUpdateConditionScreenState();
}

class _LiveUpdateConditionScreenState extends ConsumerState<LiveUpdateConditionScreen> {
  DateTime? _date = liveToday();
  String? _overall, _physical, _performance, _safety;
  final _score = TextEditingController();
  final _remarks = TextEditingController();
  final _errors = <String, String>{};
  bool _busy = false;

  @override
  void dispose() {
    _score.dispose();
    _remarks.dispose();
    super.dispose();
  }

  double? get _scoreValue => double.tryParse(_score.text.trim().replaceAll(',', '.'));

  Future<void> _save(AssetRegistration r) async {
    _errors.clear();
    if (_date == null) {
      _errors['AssessmentDate'] = 'Choose the assessment date';
    } else if (_date!.isAfter(liveToday())) {
      _errors['AssessmentDate'] = 'The assessment date cannot be in the future';
    }
    if (_overall == null) _errors['OverallCondition'] = 'Choose the overall condition';
    final score = _scoreValue;
    if (_score.text.trim().isEmpty) {
      _errors['HealthScore'] = 'Enter the health score';
    } else if (score == null || score < 0 || score > 100) {
      _errors['HealthScore'] = 'The health score must be between 0 and 100';
    }
    setState(() {});
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    final id = r.assetRegistrationId;
    try {
      await ref
          .read(assetsApiProvider)
          .createConditionAssessment(
            CreateConditionAssessmentRequest(
              assetRegistrationId: id,
              assessmentDate: _date!,
              overallCondition: _overall!,
              healthScore: score!,
              physicalCondition: _physical,
              performance: _performance,
              safety: _safety,
              remarks: blankToNull(_remarks.text),
            ),
          );
      invalidateLiveAsset(ref, id);
      if (mounted) finishAction(context, '${r.title}: condition updated to $_overall (${liveNum(score)})');
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.from(e);
      setState(() {
        _busy = false;
        _errors.addAll(err.fieldErrors);
      });
      context.showSnack(err.message);
    }
  }

  Widget _ratings(
    List<String> ratings,
    String? value,
    ValueChanged<String?> onChanged, {
    required String key,
    bool optional = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in ratings)
            IconFilterChip(
              label: c,
              selected: value == c,
              onTap: () => setState(() {
                // Optional ratings: tapping the chosen one clears it.
                onChanged(optional && value == c ? null : c);
                _errors.remove(key);
              }),
            ),
        ],
      ),
      fieldError(_errors[key]),
      const SizedBox(height: 14),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final ratings = ref.watch(conditionRatingsProvider);
    return LiveActionPage(
      action: MoreAction.updateCondition,
      assetId: widget.assetId,
      button: (r) =>
          busyButton(busy: _busy, onPressed: () => _save(r), label: 'Update Condition', icon: Icons.fact_check),
      builder: (context, r) {
        final current = ref.watch(liveConditionProvider(r.assetRegistrationId)).value;
        final score = (_scoreValue ?? 0).clamp(0, 100).toDouble();
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              current == null
                  ? 'No condition assessment yet'
                  : 'Current: ${current.overallCondition} · health ${liveNum(current.healthScore)} '
                        '· ${liveDate(current.assessmentDate) ?? ''}',
              style: AppText.caption,
            ),
          ),
          formField(
            'Assessment Date',
            required: true,
            DateBox(
              value: _date,
              error: _errors['AssessmentDate'],
              onPicked: (d) => setState(() {
                _date = d;
                _errors.remove('AssessmentDate');
              }),
            ),
          ),
          LiveAsync<List<String>>(
            value: ratings,
            onRetry: () => ref.invalidate(conditionRatingsProvider),
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('Overall Condition', required: true),
                _ratings(list, _overall, (v) => _overall = v, key: 'OverallCondition'),
                const FieldLabel('Health Score (0–100)', required: true),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: score,
                        max: 100,
                        divisions: 100,
                        label: score.round().toString(),
                        onChanged: (v) => setState(() {
                          _score.text = v.round().toString();
                          _errors.remove('HealthScore');
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      child: TextField(
                        key: const ValueKey('healthScore'),
                        controller: _score,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        textAlign: TextAlign.center,
                        style: inputStyle,
                        decoration: const InputDecoration(hintText: '0–100'),
                        onChanged: (_) => setState(() => _errors.remove('HealthScore')),
                      ),
                    ),
                  ],
                ),
                fieldError(_errors['HealthScore']),
                const SizedBox(height: 14),
                const FieldLabel('Physical Condition'),
                _ratings(list, _physical, (v) => _physical = v, key: 'PhysicalCondition', optional: true),
                const FieldLabel('Performance'),
                _ratings(list, _performance, (v) => _performance = v, key: 'Performance', optional: true),
                const FieldLabel('Safety'),
                _ratings(list, _safety, (v) => _safety = v, key: 'Safety', optional: true),
              ],
            ),
          ),
          formField(
            'Remarks',
            TextField(
              controller: _remarks,
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              style: inputStyle,
              decoration: InputDecoration(hintText: 'What did you observe?', errorText: _errors['Remarks']),
            ),
          ),
          if (_errors['AssessedBy'] case final e?) Text(e, style: AppText.caption.copyWith(color: AppColors.red)),
        ];
      },
    );
  }
}
