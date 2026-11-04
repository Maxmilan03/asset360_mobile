import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';

/// Criticality chip coloured by [ChipTone.forAsset] (High is red, Low green).
class CriticalityChip extends StatelessWidget {
  const CriticalityChip(this.level, {super.key});

  final String level;

  @override
  Widget build(BuildContext context) => StatusChip(level, tone: ChipTone.forAsset(level));
}

/// "Assess" link next to a Criticality field.
class AssessLink extends StatelessWidget {
  const AssessLink({super.key, required this.onTap});

  /// Null = inert (client demo).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
    icon: const Icon(Icons.calculate_outlined, size: 18),
    label: const Text('Assess'),
  );
}

/// Likelihood, Consequence and the weighted criteria (asset_options.dart) with the level
/// calculated live by [assessCriticality]. Returns the assessment on Apply, null on Cancel.
Future<CriticalityAssessment?> showCriticalityAssessment(BuildContext context, {CriticalityAssessment? initial}) {
  return showModalBottomSheet<CriticalityAssessment>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AssessmentSheet(initial: initial ?? const CriticalityAssessment()),
  );
}

class _AssessmentSheet extends StatefulWidget {
  const _AssessmentSheet({required this.initial});

  final CriticalityAssessment initial;

  @override
  State<_AssessmentSheet> createState() => _AssessmentSheetState();
}

class _AssessmentSheetState extends State<_AssessmentSheet> {
  late String? _likelihood = widget.initial.likelihood;
  late String? _consequence = widget.initial.consequence;
  late final Map<String, String> _criteria = {...widget.initial.criteria};

  CriticalityAssessment get _assessment =>
      CriticalityAssessment(likelihood: _likelihood, consequence: _consequence, criteria: {..._criteria});

  Widget _rating(String? value, List<String> options, ValueChanged<String?> onChanged, {String? key}) =>
      DropdownButtonFormField<String>(
        key: key == null ? null : ValueKey(key),
        initialValue: value,
        isExpanded: true,
        isDense: true,
        hint: Text('Rate', style: hintStyle),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o,
              child: Text(o, style: inputStyle),
            ),
        ],
        onChanged: (v) => setState(() => onChanged(v)),
      );

  @override
  Widget build(BuildContext context) {
    final result = _assessment.result;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
      child: sheetFrame(context, [
        const SheetTitle('Assess Criticality', subtitle: 'Rate the likelihood, the consequence and each criterion'),
        FieldPair(
          LabeledField(
            label: 'Likelihood',
            child: _rating(_likelihood, AssetOptions.likelihoodRatings, (v) => _likelihood = v, key: 'likelihood'),
          ),
          LabeledField(
            label: 'Consequence',
            child: _rating(_consequence, AssetOptions.consequenceRatings, (v) => _consequence = v, key: 'consequence'),
          ),
        ),
        Text('Criteria', style: AppText.bodyStrong),
        const SizedBox(height: 8),
        for (final c in AssetOptions.criteria)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: c.name),
                        TextSpan(
                          text: '  ${c.weight}%',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                    style: AppText.body.copyWith(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: _rating(_criteria[c.name], AssetOptions.consequenceRatings, (v) {
                    if (v != null) _criteria[c.name] = v;
                  }, key: 'criterion-${c.name}'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.greyBg,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Calculated criticality', style: AppText.caption),
                    const SizedBox(height: 2),
                    Text(
                      result == null ? 'Rate at least one item' : 'Score ${result.score.toStringAsFixed(1)} / 5',
                      style: AppText.bodyStrong,
                    ),
                  ],
                ),
              ),
              if (result != null) CriticalityChip(result.level),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: result == null ? null : () => Navigator.pop(context, _assessment),
                child: Text(result == null ? 'Apply' : 'Apply ${result.level}'),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
