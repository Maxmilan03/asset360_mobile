import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/widgets/cards.dart';
import 'package:asset360_mobile/core/widgets/feedback.dart';

/// Shimmer placeholder rows shown while a list "loads".
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 4, this.card = true});

  final int rows;

  /// Each row in its own [AppCard] (lists of cards) or plain rows (lists inside a card).
  final bool card;

  @override
  Widget build(BuildContext context) {
    Widget bar(double? w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
    );
    Widget row() => Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [bar(140, 13), const SizedBox(height: 8), bar(double.infinity, 11)],
          ),
        ),
      ],
    );
    return Semantics(
      label: 'Loading',
      // Never overflows when it fills a fixed-height area on a small phone.
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Shimmer.fromColors(
          baseColor: AppColors.dark ? const Color(0xFF2B2650) : const Color(0xFFE9E8F2),
          highlightColor: AppColors.dark ? const Color(0xFF3A3466) : const Color(0xFFF7F6FC),
          child: Column(
            children: [
              for (var i = 0; i < rows; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: card ? AppCard(child: row()) : row(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a [ListSkeleton] for [LoadingGate.delay] the first time a list appears, then [child]
/// (the demo data is in memory; this mimics the fetch a real backend would need).
class LoadingGate extends StatefulWidget {
  const LoadingGate({super.key, required this.child, this.rows = 4, this.card = true});

  /// How long the skeleton shows. Zero turns it off.
  static Duration delay = const Duration(milliseconds: 350);

  final Widget child;
  final int rows;
  final bool card;

  @override
  State<LoadingGate> createState() => _LoadingGateState();
}

/// `_loading` is true for [LoadingGate.delay] after the widget first appears.
mixin _GateTimer<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  late bool _loading = LoadingGate.delay > Duration.zero;

  @override
  void initState() {
    super.initState();
    if (_loading) _timer = Timer(LoadingGate.delay, () => setState(() => _loading = false));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _LoadingGateState extends State<LoadingGate> with _GateTimer {
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: _loading
        ? ListSkeleton(key: const ValueKey('skeleton'), rows: widget.rows, card: widget.card)
        : KeyedSubtree(key: const ValueKey('content'), child: widget.child),
  );
}

/// Sliver twin of [LoadingGate] for lazily built lists (SliverList.builder): a [ListSkeleton] for
/// [LoadingGate.delay] the first time the list appears, then [sliver].
class SliverLoadingGate extends StatefulWidget {
  const SliverLoadingGate({super.key, required this.sliver, this.rows = 4, this.card = true});

  final Widget sliver;
  final int rows;
  final bool card;

  @override
  State<SliverLoadingGate> createState() => _SliverLoadingGateState();
}

class _SliverLoadingGateState extends State<SliverLoadingGate> with _GateTimer {
  @override
  Widget build(BuildContext context) => _loading
      ? SliverToBoxAdapter(
          child: ListSkeleton(rows: widget.rows, card: widget.card),
        )
      : widget.sliver;
}

/// The rows of one [AppCard] built lazily: same white rounded card, border and shadow, divider between rows.
class SliverCardList extends StatelessWidget {
  const SliverCardList({super.key, required this.itemCount, required this.itemBuilder, this.indent = 0});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Divider indent between rows.
  final double indent;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(AppRadius.card);
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      sliver: SliverList.separated(
        itemCount: itemCount,
        separatorBuilder: (_, _) => Divider(height: 1, indent: indent),
        itemBuilder: (context, i) {
          final child = itemBuilder(context, i);
          final first = i == 0, last = i == itemCount - 1;
          if (!first && !last) return child;
          return ClipRRect(
            borderRadius: BorderRadius.vertical(top: first ? r : Radius.zero, bottom: last ? r : Radius.zero),
            child: child,
          );
        },
      ),
    );
  }
}

/// A lazy list with the loading shimmer: [empty] (in a card) when there are no rows, else the rows
/// built on demand, inside one card with dividers ([inCard]) or as separate cards.
class GatedSliverList extends StatelessWidget {
  const GatedSliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.empty,
    this.inCard = true,
    this.dividerIndent = 90,
    this.skeletonRows = 5,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Shown (inside a card) when [itemCount] is 0, e.g. an [EmptyState].
  final Widget empty;
  final bool inCard;
  final double dividerIndent;
  final int skeletonRows;

  @override
  Widget build(BuildContext context) => SliverLoadingGate(
    rows: skeletonRows,
    sliver: itemCount == 0
        ? SliverToBoxAdapter(child: AppCard(child: empty))
        : inCard
        ? SliverCardList(itemCount: itemCount, itemBuilder: itemBuilder, indent: dividerIndent)
        : SliverList.separated(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
          ),
  );
}

/// A page whose header widgets scroll with a lazily built list: [header] (title, tiles, tabs, search),
/// then [list] (a sliver, usually a [SliverLoadingGate] or [GatedSliverList]), then [footer].
class LazyListPage extends StatelessWidget {
  const LazyListPage({super.key, required this.header, required this.list, this.footer = const [], this.padding});

  final List<Widget> header;
  final Widget list;
  final List<Widget> footer;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: padding ?? context.pagePadding,
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverList.list(children: header),
            list,
            if (footer.isNotEmpty) SliverList.list(children: footer),
          ],
        ),
      ),
    ],
  );
}
