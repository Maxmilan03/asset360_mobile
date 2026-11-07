import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_map.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';

/// API mode Asset Location: GET /api/dashboards/mobile/asset-locations?status=&search= — every asset
/// whose location has latitude / longitude, on an OpenStreetMap map, pins coloured by status
/// group. Tap a pin (or a row) → asset card → View Details (live Asset detail). The mock floor
/// plan is not used in API mode.
class LiveAssetLocationScreen extends ConsumerStatefulWidget {
  const LiveAssetLocationScreen({super.key});

  @override
  ConsumerState<LiveAssetLocationScreen> createState() => _LiveAssetLocationScreenState();
}

class _LiveAssetLocationScreenState extends ConsumerState<LiveAssetLocationScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _status;
  String? _selected;

  DashLocationsQuery get _q =>
      (status: _status, search: _query.trim().isEmpty ? null : _query.trim(), site: ref.watch(dashSiteProvider));

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _query = v;
          _selected = null;
        });
      }
    });
  }

  void _select(DashLocatedAsset a) {
    setState(() => _selected = a.assetRegistrationId);
    try {
      _map.move(DashAssetMap.point(a), 16);
    } catch (_) {
      // The map is not on screen yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = dashAssetLocationsProvider(_q);
    final byStatus = ref.watch(provider).value?.byStatus ?? const <DashBreakdownItem>[];
    final total = byStatus.fold(0, (a, b) => a + b.count);
    return DrilldownPage(
      title: 'Asset Location (Live)',
      subtitle: 'Assets with map coordinates · ${dashSiteLabel(ref.watch(dashSiteProvider))}',
      skeletonRows: 3,
      onRefresh: () => ref.invalidate(provider),
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          style: AppText.body.copyWith(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Search asset, tag, type or location',
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
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              PillChip(
                label: byStatus.isEmpty ? 'All' : 'All (${dashNumber.format(total)})',
                selected: _status == null,
                onTap: () => setState(() {
                  _status = null;
                  _selected = null;
                }),
              ),
              const SizedBox(width: 8),
              for (final s in byStatus)
                if (s.count > 0 || s.key == _status) ...[
                  PillChip(
                    dot: dashStatusColor(s.key),
                    label: '${s.label} (${dashNumber.format(s.count)})',
                    selected: _status == s.key,
                    onTap: () => setState(() {
                      _status = s.key;
                      _selected = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        DashSection<DashAssetLocations>(
          provider: provider,
          onRetry: (ref) => ref.invalidate(provider),
          rows: 4,
          builder: (l) {
            if (l.assets.isEmpty) {
              final filtered = _q.search != null || _status != null;
              return EmptyState(
                icon: Icons.location_off_outlined,
                title: filtered ? 'No matching assets on the map' : 'No assets on the map yet',
                message: filtered
                    ? 'Try another search or status.'
                    : 'Assets appear here once their location has latitude and longitude.',
              );
            }
            final selected = l.assets.where((a) => a.assetRegistrationId == _selected).firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: SizedBox(
                    height: 340,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DashAssetMap(
                            controller: _map,
                            assets: l.assets,
                            center: l.center,
                            selectedId: _selected,
                            onPinTap: _select,
                            onMapTap: () => setState(() => _selected = null),
                          ),
                        ),
                        if (selected != null)
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 28,
                            child: _AssetCard(asset: selected, onClose: () => setState(() => _selected = null)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, a) in l.assets.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 52),
                        ListTile(
                          leading: Icon(Icons.location_on_rounded, color: dashStatusColor(a.statusGroup)),
                          title: Text(
                            a.assetName ?? a.assetTag ?? a.assetRegistrationId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                          ),
                          subtitle: Text(
                            [?a.assetTag, ?a.locationLabel].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption,
                          ),
                          trailing: a.status == null ? null : DashStatusChip(label: a.status!, groupKey: a.statusGroup),
                          selected: a.assetRegistrationId == _selected,
                          onTap: () => _select(a),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ShowingFooter(text: '${l.totalCount} ${l.totalCount == 1 ? 'asset' : 'assets'} on the map'),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onClose});

  final DashLocatedAsset asset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    elevation: 0,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: AppShadows.card),
      child: Row(
        children: [
          IconSquare(icon: Icons.location_on_rounded, tone: TileTone.lavender, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  asset.assetName ?? asset.assetTag ?? asset.assetRegistrationId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  [?asset.assetTag, ?asset.assetType, ?asset.model].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                if (asset.locationLabel != null)
                  Text(
                    asset.locationLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(fontSize: 11.5),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (asset.status != null) DashStatusChip(label: asset.status!, groupKey: asset.statusGroup),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push(Routes.assetDetail(asset.assetRegistrationId)),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded, size: 20), onPressed: onClose),
        ],
      ),
    ),
  );
}
