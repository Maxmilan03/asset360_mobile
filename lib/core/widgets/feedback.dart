import 'package:flutter/material.dart';

extension FeedbackX on BuildContext {
  /// Shows a floating SnackBar, replacing any SnackBar that is already visible.
  void showSnack(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Bottom inset that content must clear (system nav + the raised bottom bar).
  double get bottomInset => MediaQuery.paddingOf(this).bottom;

  /// Standard padding for a scrolling page body inside [AppScaffold].
  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset);
}
