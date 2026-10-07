import 'package:flutter/material.dart';

extension FeedbackX on BuildContext {
  /// Shows a floating SnackBar, replacing any SnackBar that is already visible.
  void showSnack(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), margin: snackMargin));
  }

  /// Floating SnackBar margin: lifted above the sticky buttons of the caller's page
  /// (see [markStickyActions]), else the default.
  EdgeInsets? get snackMargin {
    final route = ModalRoute.of(this);
    final sticky = route != null && (_stickyRoutes[route] ?? false);
    return sticky ? const EdgeInsets.fromLTRB(15, 5, 15, 10 + stickyActionsHeight) : null;
  }

  /// Bottom inset that content must clear (system nav + the raised bottom bar).
  double get bottomInset => MediaQuery.paddingOf(this).bottom;

  /// Standard padding for a scrolling page body inside [AppScaffold].
  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset);
}

/// Height of an [AppScaffold] sticky button row (12 + 48 + 12 padding).
const double stickyActionsHeight = 72;

final _stickyRoutes = Expando<bool>('stickyActions');

/// Records whether the page (route) of [context] shows sticky bottom buttons. SnackBars are shown by the shell,
/// over the page, so [FeedbackX.showSnack] lifts them above those buttons.
void markStickyActions(BuildContext context, bool sticky) {
  final route = ModalRoute.of(context);
  if (route != null) _stickyRoutes[route] = sticky;
}
