import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';

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
    useRootNavigator: false,
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
                decoration: BoxDecoration(color: AppColors.greenBg, shape: BoxShape.circle),
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

/// Sheet header: bold title and a grey subtitle.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppText.sectionTitle),
      if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: AppText.secondary)],
      const SizedBox(height: 14),
    ],
  );
}

/// Padded, scrollable bottom-sheet body that stays above the keyboard.
Widget sheetFrame(BuildContext context, List<Widget> children) => SafeArea(
  child: Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  ),
);

/// "Reject …?" style dialog with a required reason. Returns the trimmed reason, or null on Cancel.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Reject',
  String hint = 'Reason (required)',
  bool destructive = true,
}) {
  return showDialog<String>(
    context: context,
    useRootNavigator: false,
    builder: (_) => _ReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      hint: hint,
      destructive: destructive,
    ),
  );
}

/// Owns its text controller, so it is disposed only after the dialog's exit animation.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.hint,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String hint;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(hintText: widget.hint, errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.destructive ? AppColors.red : null,
            minimumSize: const Size(96, 44),
          ),
          onPressed: () {
            final r = _controller.text.trim();
            if (r.isEmpty) {
              setState(() => _error = 'Please enter a reason');
            } else {
              Navigator.pop(context, r);
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
