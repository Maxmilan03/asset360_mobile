import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';

/// Big screen title + grey subtitle + optional "?" help icon.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle, this.help, this.trailing, this.leading});

  final String title;
  final String? subtitle;

  /// Text shown in the help bottom sheet. The "?" icon is hidden when null.
  final String? help;
  final Widget? trailing;

  /// Small widget before the title (e.g. the registration form's step icon).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          Padding(padding: const EdgeInsets.only(top: 3), child: leading),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.pageTitle),
              if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: AppText.pageSubtitle)],
            ],
          ),
        ),
        ?trailing,
        if (help != null)
          IconButton(
            tooltip: 'Help',
            visualDensity: VisualDensity.compact,
            onPressed: () => showHelpSheet(context, title: title, body: help!),
            icon: const Icon(Icons.help_rounded, color: Color(0xFF6E7590), size: 22),
          ),
      ],
    );
  }
}

Future<void> showHelpSheet(BuildContext context, {required String title, required String body}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('About $title', style: AppText.sectionTitle)),
              ],
            ),
            const SizedBox(height: 14),
            Text(body, style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
            ),
          ],
        ),
      ),
    ),
  );
}
