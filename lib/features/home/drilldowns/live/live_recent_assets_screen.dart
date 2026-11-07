import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';

/// API mode Recent Assets: GET /api/dashboards/mobile/recent-assets — newest first, 20 per page,
/// status chips from `counts` (status group keys), server search, and the asset type / site
/// filters Home and Asset Overview open it with. A row opens the live Asset detail.
class LiveRecentAssetsScreen extends ConsumerStatefulWidget {
  const LiveRecentAssetsScreen({super.key, this.status, this.type, this.site});

  final String? status;
  final String? type;
  final String? site;

  @override
  ConsumerState<LiveRecentAssetsScreen> createState() => _LiveRecentAssetsScreenState();
}

class _LiveRecentAssetsScreenState extends ConsumerState<LiveRecentAssetsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  late String? _status = widget.status;
  late String? _type = widget.type;
  late String? _site = widget.site;

  @override
  void didUpdateWidget(LiveRecentAssetsScreen old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status || old.type != widget.type || old.site != widget.site) {
      _status = widget.status;
      _type = widget.type;
      _site = widget.site;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  DashRecentAssetsQuery get _q =>
      (status: _status, search: _query.trim().isEmpty ? null : _query.trim(), assetType: _type, site: _site);

  void _onSearch(String v) {
    setState(() {}); // the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v);
    });
  }

  void _clear() => setState(() {
    _debounce?.cancel();
    _search.clear();
    _query = '';
    _status = null;
    _type = null;
    _site = null;
  });

  @override
  Widget build(BuildContext context) {
    final provider = dashRecentAssetsProvider(_q);
    final v = ref.watch(provider);
    final page = v.value;
    final Widget sliver;
    if (v.hasError && !v.isLoading) {
      sliver = SliverToBoxAdapter(
        child: LoadErrorState(error: v.error!, onRetry: () => ref.invalidate(provider)),
      );
    } else if (page == null || v.isLoading) {
      sliver = const SliverToBoxAdapter(child: ListSkeleton(rows: 6));
    } else if (page.items.isEmpty) {
      final filtered = _q.search != null || _status != null || _type != null || _site != null;
      sliver = SliverToBoxAdapter(
        child: EmptyState(
          icon: filtered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
          title: filtered ? 'No assets found' : 'No assets yet',
          message: filtered ? 'Try another search or status.' : 'Registered assets appear here.',
          actionLabel: filtered ? 'Clear search & filters' : null,
          onAction: filtered ? _clear : null,
        ),
      );
    } else {
      sliver = SliverCardList(
        itemCount: page.items.length,
        indent: 90,
        itemBuilder: (_, i) {
          if (i == page.items.length - 1 && page.hasMore && page.loadMoreError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(provider.notifier).loadMore();
            });
          }
          final a = page.items[i];
          return LiveAssetTile(
            item: dashAssetItem(a),
            trailingBottom: a.createdAtUtc == null ? null : DemoClock.formatDate(a.createdAtUtc!.toLocal()),
            onTap: () => context.push(Routes.assetDetail(a.assetRegistrationId)),
          );
        },
      );
    }
    final counts = page?.counts ?? const <DashBreakdownItem>[];
    return DrilldownPage(
      title: 'Recent Assets',
      subtitle: 'Newest first',
      skeletonRows: 6,
      onRefresh: () => ref.invalidate(dashRecentAssetsProvider),
      sliver: sliver,
      footer: [
        if (page != null && page.items.isNotEmpty && !v.isLoading) ...[
          if (page.loadingMore) const Center(child: CircularProgressIndicator()),
          if (page.loadMoreError != null)
            Center(
              child: TextButton.icon(
                onPressed: () => ref.read(provider.notifier).loadMore(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Could not load more. Retry'),
              ),
            ),
          ShowingFooter(text: 'Showing ${page.items.length} of ${dashNumber.format(page.totalCount)}'),
        ],
      ],
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          style: AppText.body.copyWith(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Search by asset tag, name or ID...',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.text, size: 22),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() {
                      _debounce?.cancel();
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c
                  in counts.isEmpty
                      ? const [DashBreakdownItem(key: 'all', label: 'All', count: 0, percent: 0)]
                      : counts)
                if (c.key == 'all' || c.count > 0 || c.key == _status) ...[
                  PillChip(
                    label: counts.isEmpty ? c.label : '${c.label} (${dashNumber.format(c.count)})',
                    selected: (_status ?? 'all') == c.key,
                    onTap: () => setState(() => _status = c.key == 'all' ? null : c.key),
                  ),
                  const SizedBox(width: 8),
                ],
            ],
          ),
        ),
        if (_type != null || _site != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_type != null) _chip(_type!, () => setState(() => _type = null)),
              if (_site != null) _chip(_site!, () => setState(() => _site = null)),
            ],
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) => InputChip(
    label: Text(label),
    labelStyle: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
    backgroundColor: AppColors.primarySoft,
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
    deleteIconColor: AppColors.primary,
    onDeleted: onDeleted,
  );
}
