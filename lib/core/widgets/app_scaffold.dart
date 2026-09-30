import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import 'app_header.dart';
import 'feedback.dart';

/// Page frame used by every screen inside the shell: purple header on top and
/// a light sheet with rounded top corners that holds the content.
///
/// The shell's bottom bar floats over the page, so scrolling bodies should use
/// [FeedbackX.pagePadding] (or a ListView without explicit padding).
/// [bottomActions] is a sticky button area kept clear of the bottom bar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.header,
    this.bottomActions,
    this.floatingActionButton,
    this.backgroundColor = AppColors.background,
  });

  final Widget body;
  final Widget? header;
  final Widget? bottomActions;
  final Widget? floatingActionButton;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (bottomActions != null) {
      content = Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(context: context, removeBottom: true, child: body),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + context.bottomInset), child: bottomActions),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.headerBottom,
      floatingActionButton: floatingActionButton == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: context.bottomInset),
              child: floatingActionButton,
            ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Column(
          children: [
            header ?? const AppHeader(),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                child: ColoredBox(color: backgroundColor, child: content),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
