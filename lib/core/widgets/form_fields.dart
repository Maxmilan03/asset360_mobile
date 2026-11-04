import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';

/// Text style for values typed or picked in forms.
TextStyle get inputStyle => TextStyle(fontSize: 13.5, color: AppColors.text);
TextStyle get hintStyle => TextStyle(fontSize: 13.5, color: AppColors.textMuted);

/// Grey label above a form field, with a red * when required.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.red),
            ),
        ],
      ),
      style: AppText.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500),
    ),
  );
}

/// Label + field, used for every input in the registration form.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.required = false});

  final String label;
  final bool required;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      FieldLabel(label, required: required),
      child,
    ],
  );
}

/// Two fields side by side.
class FieldPair extends StatelessWidget {
  const FieldPair(this.left, this.right, {super.key});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    ),
  );
}

/// Dropdown whose options show a coloured dot (Status, Condition, Criticality …).
class DotDropdown extends StatelessWidget {
  const DotDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.colorOf,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final Color Function(String) colorOf;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String o) => Row(
      children: [
        Icon(Icons.circle, size: 10, color: colorOf(o)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(o, overflow: TextOverflow.ellipsis, style: inputStyle),
        ),
      ],
    );
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: [for (final o in options) DropdownMenuItem(value: o, child: item(o))],
      onChanged: (v) => onChanged(v!),
    );
  }
}

/// Tappable date box with a calendar icon; [error] shows red text underneath.
class DateBox extends StatelessWidget {
  const DateBox({
    super.key,
    required this.value,
    required this.onPicked,
    this.error,
    this.hint = 'Select date',
    this.firstDate,
  });

  final DateTime? value;

  /// Earliest selectable day (e.g. today for "not in the past").
  final DateTime? firstDate;
  final ValueChanged<DateTime> onPicked;
  final String? error;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final d = await showDatePicker(
          useRootNavigator: false,
          context: context,
          initialDate: value ?? firstDate ?? DemoClock.today,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: DateTime(2045),
        );
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: error,
          errorMaxLines: 2,
          prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
        ),
        child: Text(
          value == null ? hint : DemoClock.formatDate(value!),
          style: AppText.body.copyWith(fontSize: 13, color: value == null ? AppColors.textMuted : AppColors.text),
        ),
      ),
    );
  }
}

/// Violet square scan button used as a text-field suffix.
class ScanSuffix extends StatelessWidget {
  const ScanSuffix({super.key, required this.onTap, this.tooltip = 'Scan', this.icon = Icons.qr_code_scanner_rounded});

  final VoidCallback onTap;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: SizedBox.square(
            dimension: 32,
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
        ),
      ),
    ),
  );
}
