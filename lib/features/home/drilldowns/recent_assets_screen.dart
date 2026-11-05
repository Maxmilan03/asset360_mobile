import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';

final _n = NumberFormat('#,###');

/// Status chips: null = All.
const _chips = <String?>[null, AssetStatus.active, AssetStatus.underMaintenance];

/// Home "Recent Assets" → View All: detailed assets by last activity, newest first.
/// API mode: the server's assets, newest first (createdAt desc), 20 per page.
class RecentAssetsScreen extends StatelessWidget {
  const RecentAssetsScreen({super.key});

  @override
  Widget build(BuildContext context) => apiMode ? const _LiveRecentAssets() : const _MockRecentAssets();
}

class _MockRecentAssets extends ConsumerStatefulWidget {
  const _MockRecentAssets();

  @override
  ConsumerState<_MockRecentAssets> createState() => _RecentAssetsScreenState();
}

class _RecentAssetsScreenState extends ConsumerState<_MockRecentAssets> {
  final _search = TextEditingController();
  String _query = '';
  String? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    _search.clear();
    _query = '';
    _status = null;
  });

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(orgSummaryProvider);
    final site = ref.watch(sessionProvider.select((s) => s.site));
    final last = ref.watch(assetLastActivityProvider);
    final q = _query.trim().toLowerCase();
    final list =
        ref
            .watch(assetsProvider)
            .where((a) => site == 'All Sites' || a.site == site)
            .where((a) => _status == null || AssetStatus.bucketOf(a.status) == _status)
            .where(
              (a) =>
                  q.isEmpty ||
                  a.id.toLowerCase().contains(q) ||
                  a.name.toLowerCase().contains(q) ||
                  a.location.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) {
            final x = last[a.id], y = last[b.id];
            if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
            return y.compareTo(x);
          });
    int orgCount(String? s) => s == null ? org.totalAssets : (org.statusCounts[s] ?? 0);

    return DrilldownPage(
      title: 'Recent Assets',
      subtitle: site == 'All Sites' ? 'Sorted by last activity' : 'Sorted by last activity · $site',
      skeletonRows: 6,
      sliver: list.isEmpty
          ? SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No assets found',
                message: 'Try another search or status.',
                actionLabel: 'Clear search & filters',
                onAction: _clear,
              ),
            )
          : SliverCardList(
              itemCount: list.length,
              indent: 90,
              itemBuilder: (_, i) => _RecentRow(asset: list[i], at: last[list[i].id]),
            ),
      footer: [ShowingFooter(text: 'Showing ${list.length} of ${_n.format(orgCount(_status))}')],
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          style: AppText.body.copyWith(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Search by Asset ID, Name, Location...',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.text, size: 22),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() {
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
              for (final s in _chips) ...[
                PillChip(
                  label: '${s ?? 'All'} (${_n.format(orgCount(s))})',
                  selected: _status == s,
                  onTap: () => setState(() => _status = s),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _RecentRow extends ConsumerWidget {
  const _RecentRow({required this.asset, required this.at});

  final Asset asset;
  final DateTime? at;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AssetListTile(
      title: asset.id,
      subtitle: asset.name,
      location: asset.location,
      imagePath: asset.imagePath,
      fallbackIcon: assetIcon(asset),
      details: [TagLabel(asset.category, icon: assetIcon(asset))],
      trailingTop: AssetStatusChip(asset.status),
      trailingBottom: at == null ? null : DemoClock.timeAgo(at!),
      onTap: () {
        ref.read(recentAssetsProvider.notifier).viewed(asset.id);
        context.push(Routes.assetDetail(asset.id));
      },
    );
  }
}

// ---------------------------------------------------------------- API mode

class _LiveRecentAssets extends ConsumerStatefulWidget {
  const _LiveRecentAssets();

  @override
  ConsumerState<_LiveRecentAssets> createState() => _LiveRecentAssetsState();
}

class _LiveRecentAssetsState extends ConsumerState<_LiveRecentAssets> {
  final _search = TextEditingController();
  Timer? _debounce;
  String? _status;
  String _query = '';

  AssetListQuery get _listQuery => AssetListQuery(
    search: _query.trim().isEmpty ? null : _query.trim(),
    status: _status,
    sortBy: 'createdAt',
    sortDirection: 'desc',
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
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
  });

  @override
  Widget build(BuildContext context) {
    final q = _listQuery;
    final list = ref.watch(liveAssetListProvider(q));
    final data = list.value;
    final summary = ref.watch(assetSummaryProvider).value;
    int? count(String? s) => summary == null ? null : (s == null ? summary.total : summary.statusCounts[s]);
    final Widget sliver;
    if (data == null) {
      sliver = SliverToBoxAdapter(
        child: list.hasError
            ? LoadErrorState(error: list.error!, onRetry: () => ref.invalidate(liveAssetListProvider(q)))
            : const ListSkeleton(rows: 6),
      );
    } else if (data.items.isEmpty) {
      sliver = SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No assets found',
          message: 'Try another search or status.',
          actionLabel: 'Clear search & filters',
          onAction: _clear,
        ),
      );
    } else {
      sliver = SliverCardList(
        itemCount: data.items.length,
        indent: 90,
        itemBuilder: (_, i) {
          // Infinite scroll: the next page when the last row is built.
          if (i == data.items.length - 1 && data.hasMore && data.loadMoreError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(liveAssetListProvider(q).notifier).loadMore();
            });
          }
          final a = data.items[i];
          return LiveAssetTile(
            item: a,
            trailingBottom: a.createdAt == null ? null : DemoClock.formatDate(a.createdAt!.toLocal()),
            onTap: () => context.push(Routes.assetDetail(a.assetRegistrationId)),
          );
        },
      );
    }
    return DrilldownPage(
      title: 'Recent Assets',
      subtitle: 'Newest first',
      skeletonRows: 6,
      onRefresh: () => ref
        ..invalidate(liveAssetListProvider(q))
        ..invalidate(assetSummaryProvider),
      sliver: sliver,
      footer: [
        if (data != null) ...[
          if (data.loadingMore) const Center(child: CircularProgressIndicator()),
          if (data.loadMoreError != null)
            Center(
              child: TextButton.icon(
                onPressed: () => ref.read(liveAssetListProvider(q).notifier).loadMore(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Could not load more. Retry'),
              ),
            ),
          ShowingFooter(text: 'Showing ${data.items.length} of ${_n.format(data.totalCount)}'),
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
              for (final s in _chips) ...[
                PillChip(
                  label: count(s) == null ? (s ?? 'All') : '${s ?? 'All'} (${_n.format(count(s))})',
                  selected: _status == s,
                  onTap: () => setState(() => _status = s),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
