import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';

/// "Label : Value" row as used in review and detail cards.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 128,
    this.valueColor,
    this.valueWidget,
    this.showColon = true,
  });

  /// Label above value (WO detail style: "Open Date" over "25 Sep 2026 10:24 AM").
  const factory InfoRow.stacked({Key? key, required String label, required String value, Color? valueColor}) =
      _StackedInfo;

  final String label;
  final String value;
  final double labelWidth;
  final Color? valueColor;
  final Widget? valueWidget;
  final bool showColon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: AppText.secondary),
          ),
          if (showColon)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(':', style: AppText.secondary),
            ),
          Expanded(
            child:
                valueWidget ??
                Text(value, style: AppText.body.copyWith(fontSize: 13, color: valueColor ?? AppColors.text)),
          ),
        ],
      ),
    );
  }
}

class _StackedInfo extends InfoRow {
  const _StackedInfo({super.key, required super.label, required super.value, super.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 3),
        Text(value, style: AppText.bodyStrong.copyWith(fontSize: 13, color: valueColor ?? AppColors.text)),
      ],
    );
  }
}

/// Small grey icon + text line (location pin, "From:", calendar …).
class IconLine extends StatelessWidget {
  const IconLine({super.key, required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;
  Color get _color => color ?? AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: _color),
          ),
        ),
      ],
    );
  }
}
