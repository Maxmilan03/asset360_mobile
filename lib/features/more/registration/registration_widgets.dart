import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';

/// Values handed from the hub to the form: a scan, RFID read or photo, or a draft to resume.
class RegistrationPrefill {
  const RegistrationPrefill({this.photo, this.barcode, this.tagId, this.draftId});

  final String? photo;
  final String? barcode;
  final String? tagId;

  /// My Drafts → resume this saved draft.
  final String? draftId;
}

// ---------------------------------------------------------------- RFID / NFC read

/// "Hold the tag near the phone" sheet: pulses for 2 s, then simulates a read of an
/// unused tag (RFID-A360-000789, …). Returns the tag ID, or null if cancelled.
Future<String?> showRfidReadSheet(BuildContext context, WidgetRef ref) {
  final assets = ref.read(assetsProvider.notifier);
  var n = 789;
  while (assets.ownerOf('RFID-A360-${n.toString().padLeft(6, '0')}') != null) {
    n++;
  }
  final tag = 'RFID-A360-${n.toString().padLeft(6, '0')}';
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _RfidSheet(tag: tag),
  );
}

class _RfidSheet extends StatefulWidget {
  const _RfidSheet({required this.tag});

  final String tag;

  @override
  State<_RfidSheet> createState() => _RfidSheetState();
}

class _RfidSheetState extends State<_RfidSheet> {
  bool _read = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _read = true);
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.pop(context, widget.tag);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_read ? 'Tag read' : 'Hold the tag near the phone', style: AppText.sectionTitle),
            const SizedBox(height: 6),
            Text(
              _read ? widget.tag : 'Keep the RFID / NFC tag against the back of the phone',
              textAlign: TextAlign.center,
              style: _read ? AppText.bodyStrong.copyWith(color: AppColors.primary) : AppText.secondary,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 150,
              height: 150,
              child: _read
                  ? const Icon(Icons.check_circle_rounded, size: 84, color: AppColors.green)
                  : const PulseRings(icon: Icons.contactless_rounded),
            ),
            const SizedBox(height: 16),
            if (!_read)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
          ],
        ),
      ),
    );
  }
}

/// "This tag belongs to MTR-00123 – View asset?" Returns true for View Asset.
Future<bool> confirmViewExisting(BuildContext context, String code, String assetId, String assetName) {
  return showConfirmDialog(
    context,
    title: 'Tag already registered',
    message: '$code belongs to $assetId – $assetName. View asset?',
    confirmLabel: 'View Asset',
  );
}

// ---------------------------------------------------------------- form fields

/// Gap below every form field.
const regGap = SizedBox(height: 14);

/// Bold section title inside a step ("Basic Information", "Identification Preview" …).
class RegSection extends StatelessWidget {
  const RegSection(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppText.bodyStrong.copyWith(fontSize: 15))),
        ?trailing,
      ],
    ),
  );
}

/// Labelled text field that writes to the form on every keystroke. The text is read from
/// [value] when the field is built; bump [revision] to push a value set elsewhere (a scan).
class RegTextField extends StatelessWidget {
  const RegTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.hint,
    this.suffix,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.caps = TextCapitalization.sentences,
    this.revision = 0,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;
  final String? hint;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextCapitalization caps;
  final int revision;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: LabeledField(
      label: label,
      required: required,
      child: TextFormField(
        key: ValueKey('$label#$revision'),
        initialValue: value ?? '',
        style: inputStyle,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: 1,
        textCapitalization: caps,
        decoration: InputDecoration(hintText: hint, suffixIcon: suffix, errorMaxLines: 2),
        onChanged: (v) => onChanged(v.trim().isEmpty ? null : v),
        validator:
            validator ?? (required ? (v) => (v ?? '').trim().isEmpty ? 'Enter the ${label.toLowerCase()}' : null : null),
      ),
    ),
  );
}

/// Number field ("12,500" is accepted); [onChanged] gets null when empty or not a number.
class RegNumberField extends StatelessWidget {
  const RegNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.hint,
    this.suffixText,
    this.decimals = true,
    this.min,
    this.bottom = 14,
  });

  final String label;
  final num? value;
  final ValueChanged<double?> onChanged;
  final bool required;
  final String? hint;
  final String? suffixText;
  final bool decimals;
  final num? min;
  final double bottom;

  static double? parse(String? v) => double.tryParse((v ?? '').replaceAll(',', '').trim());

  /// 1000.0 → "1000", 12.5 → "12.5".
  static String format(num? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottom),
    child: LabeledField(
      label: label,
      required: required,
      child: TextFormField(
        key: ValueKey('$label#num'),
        initialValue: format(value),
        style: inputStyle,
        keyboardType: TextInputType.numberWithOptions(decimal: decimals),
        decoration: InputDecoration(hintText: hint, suffixText: suffixText, errorMaxLines: 2),
        onChanged: (v) => onChanged(parse(v)),
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.isEmpty) return required ? 'Enter the ${label.toLowerCase()}' : null;
          final n = parse(s);
          if (n == null || (!decimals && n != n.roundToDouble())) return 'Enter a number';
          if (min != null && n < min!) return 'Must be at least ${format(min)}';
          return null;
        },
      ),
    ),
  );
}

/// Labelled dropdown; [required] adds the * and a "Select …" error.
class RegDropdown extends StatelessWidget {
  const RegDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.required = false,
    this.hint = 'Select',
    this.bottom = 14,
    this.dotColor,
    this.showLabel = true,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool required;
  final String hint;
  final double bottom;

  /// Shows a coloured dot before each option (Status, Condition, Criticality).
  final Color Function(String)? dotColor;

  /// False when the caller draws the label itself (Criticality + Assess).
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    Widget item(String o) => Row(
      children: [
        if (dotColor != null) ...[Icon(Icons.circle, size: 10, color: dotColor!(o)), const SizedBox(width: 8)],
        Flexible(child: Text(o, overflow: TextOverflow.ellipsis, style: inputStyle)),
      ],
    );
    final field = DropdownButtonFormField<String>(
      key: ValueKey('$label#$value#${options.length}#${options.firstOrNull}'),
      initialValue: options.contains(value) ? value : null,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      hint: Text(options.isEmpty ? '—' : hint, style: hintStyle),
      items: [for (final o in options) DropdownMenuItem(value: o, child: item(o))],
      onChanged: options.isEmpty ? null : onChanged,
      validator: required ? (v) => v == null ? 'Select the ${label.toLowerCase()}' : null : null,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: showLabel ? LabeledField(label: label, required: required, child: field) : field,
    );
  }
}

/// Tappable date field with a label.
class RegDateField extends StatelessWidget {
  const RegDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
    this.required = false,
    this.error,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final bool required;
  final String? error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: LabeledField(
      label: label,
      required: required,
      child: DateBox(value: value, onPicked: onPicked, error: error),
    ),
  );
}

/// Read-only value in a grey box (auto-calculated Total Cost, Warranty End Date).
class RegReadOnly extends StatelessWidget {
  const RegReadOnly({super.key, required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: LabeledField(
      label: label,
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.greyBg,
          helperText: note,
          prefixIcon: Icon(Icons.calculate_outlined, size: 18, color: AppColors.textSecondary),
        ),
        child: Text(value, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
      ),
    ),
  );
}

/// "A › B › C" path in a soft violet box (classification path, location path).
class RegBreadcrumb extends StatelessWidget {
  const RegBreadcrumb({super.key, required this.parts, required this.icon, this.empty = '—'});

  final List<String> parts;
  final IconData icon;
  final String empty;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            parts.isEmpty ? empty : parts.join('  ›  '),
            style: AppText.body.copyWith(fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
