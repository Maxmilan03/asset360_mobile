import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';

/// API mode (apiMode = true) pieces of Home.

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

/// Loading (shimmer) / error (message + Retry) / data for a live Home card.
class LiveCardBody<T> extends ConsumerWidget {
  const LiveCardBody({super.key, required this.provider, required this.builder, this.rows = 2});

  final FutureProvider<T> provider;
  final Widget Function(T value) builder;
  final int rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(provider)) {
    AsyncData(:final value) => builder(value),
    AsyncError(:final error) => LoadErrorState(error: error, onRetry: () => ref.invalidate(provider)),
    _ => ListSkeleton(rows: rows, card: false),
  };
}

/// Pull-to-refresh on Home: reload what the live cards show.
void refreshLiveHome(WidgetRef ref) {
  ref
    ..invalidate(assetSummaryProvider)
    ..invalidate(recentLiveAssetsProvider);
}
