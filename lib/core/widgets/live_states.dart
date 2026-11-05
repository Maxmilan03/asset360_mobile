import 'package:flutter/material.dart';

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
