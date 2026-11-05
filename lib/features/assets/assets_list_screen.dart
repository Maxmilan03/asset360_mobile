import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/mock/home_mock.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/features/assets/live/live_assets_list_screen.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';

enum _Scope { all, mine, nearby, favorites }

const _status = 'Status';
const _category = 'Category';
const _location = 'Location';
const _criticality = 'Criticality';
const _condition = 'Condition';
const _type = 'Asset Type';
const _building = 'Site / Building';

/// Assets tab: search, scan, scope chips, filters and the asset list.
/// In API mode this is [LiveAssetsListScreen] (server data); otherwise the mock list.
class AssetsListScreen extends StatelessWidget {
  const AssetsListScreen({super.key, this.initialStatus, this.initialType, this.initialLocation});

  /// Opened from Home's status legend with `?status=…`.
  final String? initialStatus;

  /// Opened from Asset Overview with `?type=…` (a breakdown type, see `assetTypeGroup`).
  final String? initialType;

  /// Opened from Asset Overview with `?location=…` (a site / building, see `assetLocationGroup`).
  final String? initialLocation;

  @override
  Widget build(BuildContext context) => apiMode
      ? LiveAssetsListScreen(initialStatus: initialStatus)
      : _MockAssetsListScreen(initialStatus: initialStatus, initialType: initialType, initialLocation: initialLocation);
}

class _MockAssetsListScreen extends ConsumerStatefulWidget {
  const _MockAssetsListScreen({this.initialStatus, this.initialType, this.initialLocation});

  /// Opened from Home's status legend with `?status=…`.
  final String? initialStatus;

  /// Opened from Asset Overview with `?type=…` (a breakdown type, see `assetTypeGroup`).
  final String? initialType;

  /// Opened from Asset Overview with `?location=…` (a site / building, see `assetLocationGroup`).
  final String? initialLocation;

  @override
  ConsumerState<_MockAssetsListScreen> createState() => _AssetsListScreenState();
}

class _AssetsListScreenState extends ConsumerState<_MockAssetsListScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Scope _scope = _Scope.all;

  /// Favorites: one favorite group, or null for every group.
  String? _group;
  late FilterSelection _filters = _initialFilters(widget);

  static FilterSelection _initialFilters(_MockAssetsListScreen w) => {
    if (w.initialStatus != null) _status: {w.initialStatus!},
    if (w.initialType != null) _type: {w.initialType!},
    if (w.initialLocation != null) _building: {w.initialLocation!},
  };

  @override
  void didUpdateWidget(_MockAssetsListScreen old) {
    super.didUpdateWidget(old);
    final next = _initialFilters(widget);
    if (next.isNotEmpty &&
        (widget.initialStatus != old.initialStatus ||
            widget.initialType != old.initialType ||
            widget.initialLocation != old.initialLocation)) {
      setState(() => _filters = next);
    }
  }

  /// Org-wide count for "Showing X of Y": the summary figure of the one status / type /
  /// site filter in use, else every asset.
  int _orgTotal() {
    final org = ref.watch(orgSummaryProvider);
    final breakdown = ref.watch(assetBreakdownProvider);
    final only = _filters.entries.where((e) => e.value.isNotEmpty).toList();
    if (only.length == 1 && only.first.value.length == 1 && _scope == _Scope.all && _query.isEmpty) {
      final v = only.first.value.first;
      final n = switch (only.first.key) {
        _status => org.statusCounts[v],
        _type => breakdown.type(v)?.total,
        _building => breakdown.location(v)?.total,
        _ => null,
      };
      if (n != null) return n;
    }
    return org.totalAssets;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FilterGroup> _groups(List<Asset> all) => [
    const FilterGroup(title: _status, options: AssetStatus.all),
    const FilterGroup(title: _condition, options: AssetOptions.conditions),
    const FilterGroup(title: _type, options: homeAssetTypes),
    FilterGroup(title: _category, options: {...all.map((a) => a.category)}.toList()..sort()),
    FilterGroup(title: _building, options: [for (final s in ref.read(assetBreakdownProvider).byLocation) s.name]),
    FilterGroup(title: _location, options: {...all.map((a) => locationArea(a.location))}.toList()..sort()),
    const FilterGroup(title: _criticality, options: AssetOptions.criticalityLevels),
  ];

  bool _matches(Asset a) {
    bool ok(String group, String value) => _filters[group]?.contains(value) ?? true;
    return ok(_status, AssetStatus.bucketOf(a.status)) &&
        ok(_condition, a.condition) &&
        ok(_type, assetTypeGroup(a)) &&
        ok(_building, assetLocationGroup(a)) &&
        ok(_category, a.category) &&
        ok(_location, locationArea(a.location)) &&
        ok(_criticality, a.criticality);
  }

  Future<void> _openFilters(List<Asset> all) async {
    final result = await showFilterSheet(context, groups: _groups(all), selection: _filters);
    if (result != null) setState(() => _filters = result);
  }

  void _removeFilter(String group, String value) => setState(() {
    final next = {
      for (final e in _filters.entries) e.key: {...e.value},
    };
    next[group]!.remove(value);
    if (next[group]!.isEmpty) next.remove(group);
    _filters = next;
  });

  Future<void> _scan() async {
    final code = await showScanCapture(context, suggestions: const ['CNC-00123', 'MTR-00123', 'FL-012', 'GEN-00045']);
    if (code == null || !mounted) return;
    final asset = ref.read(assetsProvider).byCode(code);
    if (asset == null) {
      context.showSnack('No asset matches "$code"');
      return;
    }
    context.push(Routes.assetDetail(asset.id));
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(assetsProvider);
    final total = ref.watch(orgSummaryProvider).totalAssets;
    final shownOf = _orgTotal();
    final base = switch (_scope) {
      _Scope.all => all,
      _Scope.mine => ref.watch(myAssetsProvider),
      _Scope.nearby => all.nearby,
      _Scope.favorites => all.favoritesIn(_group),
    };
    final shown = base.search(_query).where(_matches).toList();
    final activeFilters = [
      for (final e in _filters.entries)
        for (final v in e.value) (e.key, v),
    ];

    return AppScaffold(
      floatingActionButton: DemoGuard(
        route: Routes.registration,
        child: FloatingActionButton(
          tooltip: 'Register asset',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () => context.push(Routes.registration),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: context.pagePadding.copyWith(bottom: 10),
            sliver: SliverList.list(
              children: [
                const PageTitle(title: 'Assets', subtitle: 'Search, scan or filter assets'),
                const SizedBox(height: 14),
                SearchFilterBar(
                  controller: _search,
                  hint: 'Search by Asset ID, Name, Serial No...',
                  onChanged: (v) => setState(() => _query = v),
                  onScan: _scan,
                  scanAllowed: demoCanDo(DemoAction.assetsListScan),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (scope, label, icon) in const [
                        (_Scope.all, 'All', Icons.grid_view_rounded),
                        (_Scope.mine, 'My Assets', Icons.person_outline_rounded),
                        (_Scope.nearby, 'Nearby', Icons.location_on_outlined),
                        (_Scope.favorites, 'Favorites', Icons.favorite_border_rounded),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconFilterChip(
                            label: label,
                            icon: icon,
                            selected: _scope == scope,
                            onTap: () => setState(() => _scope = scope),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_scope == _Scope.favorites) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final g in [null, ...ref.watch(favoriteGroupsProvider)])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('${g ?? 'All groups'} (${all.favoritesIn(g).length})'),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: _group == g ? Colors.white : AppColors.text,
                                fontWeight: FontWeight.w500,
                              ),
                              selected: _group == g,
                              showCheckmark: false,
                              selectedColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() => _group = g),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Assets (${formatCount(total)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong,
                      ),
                    ),
                    InkWell(
                      onTap: () => _openFilters(all),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Text(
                              activeFilters.isEmpty ? 'Filter' : 'Filter (${activeFilters.length})',
                              style: AppText.link,
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (activeFilters.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (group, value) in activeFilters)
                        InputChip(
                          label: Text(value),
                          labelStyle: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                          backgroundColor: AppColors.primarySoft,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                          deleteIconColor: AppColors.primary,
                          tooltip: group,
                          onDeleted: () => _removeFilter(group, value),
                          onPressed: () => _openFilters(all),
                        ),
                      ActionChip(
                        label: const Text('Clear all'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _filters = {}),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverLoadingGate(
              rows: 6,
              sliver: shown.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No assets found',
                        message: _scope == _Scope.favorites && _query.isEmpty && _filters.isEmpty
                            ? 'Tap the ☆ on an asset to add it to Favorites.'
                            : 'Try another search or clear the filters.',
                        actionLabel: 'Clear search & filters',
                        onAction: () => setState(() {
                          _search.clear();
                          _query = '';
                          _filters = {};
                          _scope = _Scope.all;
                          _group = null;
                        }),
                      ),
                    )
                  // Lazy: only the visible rows are built.
                  : SliverCardList(
                      itemCount: shown.length,
                      indent: 90,
                      itemBuilder: (_, i) => _AssetRow(asset: shown[i]),
                    ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, context.pagePadding.bottom + 64),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Text('Showing ${shown.length} of ${formatCount(shownOf)}', style: AppText.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return AssetListTile(
      title: asset.id,
      subtitle: asset.name,
      location: asset.location,
      imagePath: asset.imagePath,
      fallbackIcon: assetIcon(asset),
      details: [
        Row(
          children: [
            // The kind gets the larger share; the manufacturer shortens first.
            Flexible(flex: 3, child: TagLabel(shortAssetKind(asset), icon: assetIcon(asset))),
            if (asset.manufacturer != '—') ...[
              const SizedBox(width: 6),
              Flexible(flex: 2, child: TagLabel(asset.manufacturer)),
            ],
          ],
        ),
      ],
      trailingTop: AssetStatusChip(asset.status),
      onTap: () => context.push(Routes.assetDetail(asset.id)),
    );
  }
}
