import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Numbered progress header for multi-step flows (Asset, From, To, Details, Review).
/// Steps before [current] show a ✓. Tapping a completed step calls [onStepTap].
class StepperHeader extends StatelessWidget {
  const StepperHeader({super.key, required this.steps, required this.current, this.onStepTap});

  final List<String> steps;
  final int current;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: InkWell(
              onTap: i < current && onStepTap != null ? () => onStepTap!(i) : null,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _line(i > 0, i <= current)),
                      _circle(i),
                      Expanded(child: _line(i < steps.length - 1, i < current)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // One-word labels shrink to fit; longer ones wrap onto two lines ("Location & / Custody").
                  _label(steps[i], i == current),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _label(String text, bool active) {
    final label = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        color: active ? AppColors.primary : AppColors.textSecondary,
      ),
    );
    return text.contains(' ') ? label : FittedBox(fit: BoxFit.scaleDown, child: label);
  }

  Widget _line(bool visible, bool done) =>
      Container(height: 1.5, color: !visible ? Colors.transparent : (done ? AppColors.primary : AppColors.border));

  Widget _circle(int i) {
    final done = i < current;
    final active = i == current;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? AppColors.primary : AppColors.surface,
        border: Border.all(color: done || active ? AppColors.primary : AppColors.border, width: 1.5),
      ),
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.text,
              ),
            ),
    );
  }
}
