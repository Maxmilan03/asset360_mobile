import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';

/// Returns true when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelLabel)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.red) : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Green-check success sheet shown at the end of a flow.
/// Returns true when the primary button was pressed.
Future<bool> showSuccessSheet(
  BuildContext context, {
  required String title,
  String? message,
  String primaryLabel = 'Done',
  String? secondaryLabel,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .4, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(color: AppColors.greenBg, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 52),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: AppText.pageTitle.copyWith(fontSize: 20)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: AppText.pageSubtitle.copyWith(fontSize: 14)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(primaryLabel)),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(secondaryLabel)),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
