import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/empty_state.dart';
import 'package:asset360_mobile/core/widgets/feedback.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';

/// Shared states for screens that read the live backend (apiMode = true).

/// Message for features the backend does not offer yet.
const notAvailableYetMessage = 'Not available yet';

/// A tab / section / sheet whose backend does not exist yet.
class NotAvailableYet extends StatelessWidget {
  const NotAvailableYet({super.key, this.feature, this.icon = Icons.hourglass_empty_rounded});

  /// "Maintenance history" → "Maintenance history is not available yet."
  final String? feature;
  final IconData icon;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: icon,
    title: notAvailableYetMessage,
    message: feature == null
        ? 'This part is not connected to the server yet.'
        : '$feature is not connected to the server yet.',
  );
}

/// A small inline "Not available yet" line (inside cards).
class NotAvailableYetLine extends StatelessWidget {
  const NotAvailableYetLine({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(notAvailableYetMessage, style: AppText.secondary),
  );
}

/// Every tap on an action without a backend: one SnackBar.
void showNotAvailableYet(BuildContext context, [String? feature]) =>
    context.showSnack(feature == null ? '$notAvailableYetMessage.' : '$feature: $notAvailableYetMessage.');

/// A failed load with Retry (the server's message, never a stack trace).
class LoadErrorState extends StatelessWidget {
  const LoadErrorState({super.key, required this.error, required this.onRetry, this.title = 'Could not load'});

  final Object error;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_rounded,
    title: title,
    message: ApiException.from(error).message,
    actionLabel: 'Retry',
    onAction: onRetry,
  );
}

/// One line for a server list inside a form field: a spinner while it loads, the error with Retry,
/// or "No `what` on the server yet" with Retry. Null when the list has items (show the field).
Widget? serverListStatus<T>(AsyncValue<List<T>> v, {required String what, required VoidCallback onRetry}) {
  if (v.hasError && !v.isLoading) {
    return InlineRetry(
      text: 'Could not load $what: ${ApiException.from(v.error!).message}',
      onRetry: onRetry,
      error: true,
    );
  }
  if (!v.hasValue) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
  if (v.requireValue.isEmpty) return InlineRetry(text: 'No $what on the server yet', onRetry: onRetry);
  return null;
}

/// A short message with a Retry button on the right.
class InlineRetry extends StatelessWidget {
  const InlineRetry({super.key, required this.text, required this.onRetry, this.error = false});

  final String text;
  final VoidCallback onRetry;
  final bool error;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(text, style: error ? AppText.caption.copyWith(color: AppColors.red) : AppText.caption),
      ),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Retry'),
      ),
    ],
  );
}
