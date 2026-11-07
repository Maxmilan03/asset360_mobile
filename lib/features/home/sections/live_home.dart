import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';

/// API mode (apiMode = true) pieces of Home. The cards themselves are in live_dashboard_cards.dart.

/// A Home card whose data has no backend in this phase: the design's title, "Not available yet"
/// inside. [onAction] (optional) keeps a "View All" that still leads somewhere real.
class HomeNotAvailableCard extends StatelessWidget {
  const HomeNotAvailableCard({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: title,
    actionLabel: actionLabel,
    onAction: onAction,
    child: const Align(alignment: Alignment.centerLeft, child: NotAvailableYetLine()),
  );
}

/// Pull-to-refresh on Home: reload every dashboard section (each shows its own shimmer) and the
/// Asset service summary other screens share.
void refreshLiveHome(WidgetRef ref) {
  refreshDashboard(ref);
  ref
    ..invalidate(assetSummaryProvider)
    ..invalidate(recentLiveAssetsProvider);
}
