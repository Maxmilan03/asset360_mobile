import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/assets_repository.dart';

/// Values handed from the hub tiles to the form (scan, RFID read, photo).
class RegistrationPrefill {
  const RegistrationPrefill({this.photo, this.barcode, this.tagId});

  final String? photo;
  final String? barcode;
  final String? tagId;
}

/// Text style for values typed or picked in the registration form.
const inputStyle = TextStyle(fontSize: 13.5, color: AppColors.text);
const hintStyle = TextStyle(fontSize: 13.5, color: AppColors.textMuted);

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
  const DateBox({super.key, required this.value, required this.onPicked, this.error, this.hint = 'Select date'});

  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final String? error;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DemoClock.today,
          firstDate: DateTime(2000),
          lastDate: DateTime(2045),
        );
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: error,
          errorMaxLines: 2,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
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
  const ScanSuffix({super.key, required this.onTap, this.tooltip = 'Scan'});

  final VoidCallback onTap;
  final String tooltip;

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
          child: const SizedBox.square(
            dimension: 32,
            child: Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.primary),
          ),
        ),
      ),
    ),
  );
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

class _RfidSheetState extends State<_RfidSheet> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  bool _read = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _pulse.stop();
      setState(() => _read = true);
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.pop(context, widget.tag);
      });
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
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
                  : AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, _) => Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final offset in [0.0, .5])
                            Builder(
                              builder: (_) {
                                final t = (_pulse.value + offset) % 1;
                                return Container(
                                  width: 60 + 90 * t,
                                  height: 60 + 90 * t,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(alpha: .25 * (1 - t)),
                                  ),
                                );
                              },
                            ),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.contactless_rounded, color: Colors.white, size: 34),
                          ),
                        ],
                      ),
                    ),
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
