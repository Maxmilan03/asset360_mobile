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
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/drilldowns/live/live_recent_assets_screen.dart';

final _n = NumberFormat('#,###');

/// Status chips: null = All.
const _chips = <String?>[null, AssetStatus.active, AssetStatus.underMaintenance];

/// Home "Recent Assets" → View All: detailed assets by last activity, newest first.
/// API mode: [LiveRecentAssetsScreen] (GET /api/dashboards/mobile/recent-assets).
class RecentAssetsScreen extends StatelessWidget {
  const RecentAssetsScreen({super.key, this.status, this.type, this.site});

  /// API mode filters from Home / Asset Overview links: status group key, asset type, site.
  final String? status;
  final String? type;
  final String? site;

  @override
  Widget build(BuildContext context) =>
      apiMode ? LiveRecentAssetsScreen(status: status, type: type, site: site) : const _MockRecentAssets();
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
