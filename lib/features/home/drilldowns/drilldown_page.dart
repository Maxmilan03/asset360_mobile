import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';

/// Frame of every Home drill-down: AppHeader with back arrow, page title, pull-to-refresh
/// that shows a shimmer while "reloading", and a shimmer the first time the page opens.
///
/// [children] are the box widgets under the title; [sliver] (optional) is a lazy list after
/// them and [footer] goes below it (e.g. "Showing X of Y").
class DrilldownPage extends StatefulWidget {
  const DrilldownPage({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.children = const [],
    this.sliver,
    this.footer = const [],
    this.skeletonRows = 4,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final Widget? sliver;
  final List<Widget> footer;
  final int skeletonRows;

  /// Extra work on pull-to-refresh (the shimmer shows either way).
  final VoidCallback? onRefresh;

  /// How long the pull-to-refresh shimmer stays (tests set zero).
  static Duration refreshDelay = const Duration(milliseconds: 800);

  @override
  State<DrilldownPage> createState() => _DrilldownPageState();
}

class _DrilldownPageState extends State<DrilldownPage> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    widget.onRefresh?.call();
    await Future<void>.delayed(DrilldownPage.refreshDelay);
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final skeleton = ListSkeleton(rows: widget.skeletonRows);
    return AppScaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, widget.sliver == null ? pad.bottom + 64 : 0),
              sliver: SliverList.list(
                children: [
                  PageTitle(title: widget.title, subtitle: widget.subtitle, trailing: widget.trailing),
                  const SizedBox(height: 14),
                  if (_refreshing)
                    skeleton
                  else
                    LoadingGate(
                      rows: widget.skeletonRows,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
                    ),
                ],
              ),
            ),
            if (widget.sliver != null && !_refreshing) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLoadingGate(rows: widget.skeletonRows, sliver: widget.sliver!),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, pad.bottom + 64),
                sliver: SliverList.list(children: widget.footer),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Showing 20 of 12,458" footer line.
class ShowingFooter extends StatelessWidget {
  const ShowingFooter({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: AppText.secondary));
}
