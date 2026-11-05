import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_asset_row.dart';
import 'package:asset360_mobile/features/assets/live/live_filter_sheet.dart';
import 'package:asset360_mobile/features/assets/live/live_list_logic.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

enum LiveScope { all, mine, favorites }

/// Assets tab in API mode: GET /api/asset-registrations with server search, filters, sort, status
/// summary and infinite scroll. Reads no mock asset data.
class LiveAssetsListScreen extends ConsumerStatefulWidget {
  const LiveAssetsListScreen({super.key, this.initialStatus});

  /// Opened from Home's status legend with `?status=…` ("Other" has no single server value).
  final String? initialStatus;

  @override
  ConsumerState<LiveAssetsListScreen> createState() => _LiveAssetsListScreenState();
}

/// What the list area shows, from the server list or from the favorites.
class _ListView {
  const _ListView({
    this.items,
    this.error,
    this.totalCount = 0,
    this.summary,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Null while the first page loads (or failed).
  final List<AssetListItem>? items;
  final Object? error;
  final int totalCount;
  final AssetStatusSummary? summary;
  final bool hasMore, loadingMore;
  final Object? loadMoreError;
}

class _LiveAssetsListScreenState extends ConsumerState<LiveAssetsListScreen> {
  static const _debounce = Duration(milliseconds: 300);

  final _search = TextEditingController();
  Timer? _timer;
  String _searchText = '';
  late AssetListQuery _q = AssetListQuery(status: _statusParam(widget.initialStatus));
  LiveScope _scope = LiveScope.all;

  /// Kept while a new query loads, so the cards do not blink.
  AssetStatusSummary _lastSummary = AssetStatusSummary.empty;

  static String? _statusParam(String? s) => s == null || s == AssetStatus.other ? null : s;

  @override
  void didUpdateWidget(LiveAssetsListScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialStatus != old.initialStatus && widget.initialStatus != null) {
      setState(() => _q = _q.copyWith(status: () => _statusParam(widget.initialStatus)));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted && v.trim() != _searchText) setState(() => _searchText = v.trim());
    });
  }

  /// The query sent to the server (search + My Assets scope applied).
  AssetListQuery _effective(String? myId) {
    var q = _q.copyWith(search: () => _searchText.isEmpty ? null : _searchText);
    if (_scope == LiveScope.mine) q = q.copyWith(custodianUserId: () => myId);
    return q;
  }

  bool get _filtered => _searchText.isNotEmpty || _q.filterCount > 0;

  void _clearAll() {
    _timer?.cancel();
    setState(() {
      _search.clear();
      _searchText = '';
      _q = AssetListQuery(sortBy: _q.sortBy, sortDirection: _q.sortDirection);
      _scope = LiveScope.all;
    });
  }

  Future<void> _openFilters() async {
    final next = await showLiveFilterSheet(context, query: _q, showCustodian: _scope != LiveScope.mine);
    if (next != null && mounted) setState(() => _q = next.copyWith(search: () => null));
  }

  Future<void> _openSort() async {
    final s = await showLiveSortSheet(context, query: _q);
    if (s != null && mounted) {
      setState(() => _q = _q.copyWith(sortBy: () => s.sortBy, sortDirection: () => s.sortDirection));
    }
  }

  void _setStatus(String? status) => setState(() => _q = _q.copyWith(status: () => status));

  Future<void> _scan() async {
    final code = await showScanCapture(context);
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      final hit = await ref.read(assetsApiProvider).lookup(code);
      if (!mounted) return;
      if (hit != null) {
        context.push(Routes.assetDetail(hit.asset.assetRegistrationId));
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Tag not registered: $code'),
            margin: context.snackMargin,
            action: SnackBarAction(
              label: 'Register',
              onPressed: () => context.push(Routes.newRegistration, extra: RegistrationPrefill(barcode: code.trim())),
            ),
          ),
        );
    } catch (e) {
      if (mounted) context.showSnack(ApiException.from(e).message);
    }
  }

  // ---------------------------------------------------------------- data

  _ListView _serverView(AssetListQuery q) {
    final async = ref.watch(liveAssetListProvider(q));
    final d = async.value;
    if (d != null) {
      return _ListView(
        items: d.items,
        totalCount: d.totalCount,
        summary: d.summary,
        hasMore: d.hasMore,
        loadingMore: d.loadingMore,
        loadMoreError: d.loadMoreError,
      );
    }
    return _ListView(error: async.hasError ? async.error : null);
  }

  List<String> get _favoriteIds => ref.read(liveFavoritesProvider).toList()..sort();

  /// Favorites: each one read by id (GET /api/asset-registrations/{id}), then searched, filtered and
  /// sorted here with the server's rules. A favorite deleted on the server (404) is skipped.
  _ListView _favoritesView(AssetListQuery q) {
    final ids = ref.watch(liveFavoritesProvider).toList()..sort();
    final results = [for (final id in ids) ref.watch(liveAssetProvider(id))];
    if (results.any((r) => !r.hasValue && !r.hasError)) return const _ListView();
    for (final r in results) {
      if (r.hasError && !r.hasValue && ApiException.from(r.error!).kind != ApiErrorKind.notFound) {
        return _ListView(error: r.error);
      }
    }
    final anyStatus = q.copyWith(status: () => null);
    final rows = [
      for (final r in results)
        if (r.value case final reg? when registrationMatches(reg, anyStatus)) AssetListItem.fromRegistration(reg),
    ];
    final items = [
      for (final i in rows)
        if (q.status == null || i.status?.toLowerCase() == q.status!.toLowerCase()) i,
    ]..sort(itemComparator(q.sortBy, q.sortDirection));
    return _ListView(items: items, totalCount: items.length, summary: summarize(rows));
  }

  Future<void> _refresh(AssetListQuery q) async {
    ref.invalidate(assetListFiltersProvider);
    try {
      if (_scope == LiveScope.favorites) {
        final ids = _favoriteIds;
        for (final id in ids) {
          ref.invalidate(liveAssetProvider(id));
        }
        await Future.wait([
          for (final id in ids) ref.read(liveAssetProvider(id).future).then<void>((_) {}, onError: (_) {}),
        ]);
      } else {
        await ref.read(liveAssetListProvider(q).notifier).refresh();
      }
    } catch (e) {
      if (mounted) context.showSnack(ApiException.from(e).message);
    }
  }

  void _retry(AssetListQuery q) {
    if (_scope == LiveScope.favorites) {
      for (final id in _favoriteIds) {
        ref.invalidate(liveAssetProvider(id));
      }
    } else {
      ref.invalidate(liveAssetListProvider(q));
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(myUserIdProvider);
    if (_scope == LiveScope.mine && myId == null) _scope = LiveScope.all;
    final q = _effective(myId);
    final view = _scope == LiveScope.favorites ? _favoritesView(q) : _serverView(q);
    if (view.summary != null) _lastSummary = view.summary!;
    final items = view.items;

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
      body: RefreshIndicator(
        onRefresh: () => _refresh(q),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: context.pagePadding.copyWith(bottom: 10),
              sliver: SliverList.list(children: _header(myId)),
            ),
            SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: _list(view, q)),
            if (items != null && items.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, context.pagePadding.bottom + 64),
                sliver: SliverList.list(children: _footer(view, q)),
              )
            else
              SliverToBoxAdapter(child: SizedBox(height: context.pagePadding.bottom + 64)),
          ],
        ),
      ),
    );
  }

  List<Widget> _header(String? myId) {
    final active = _activeFilters();
    return [
      const PageTitle(title: 'Assets', subtitle: 'Search, scan or filter assets'),
      const SizedBox(height: 14),
      SearchFilterBar(
        controller: _search,
        hint: 'Search by Asset ID, Name, Serial No...',
        onChanged: _onSearch,
        onScan: _scan,
        scanAllowed: demoCanDo(DemoAction.assetsListScan),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (scope, label, icon) in const [
              (LiveScope.all, 'All', Icons.grid_view_rounded),
              (LiveScope.mine, 'My Assets', Icons.person_outline_rounded),
              (LiveScope.favorites, 'Favorites', Icons.star_border_rounded),
            ])
              if (scope != LiveScope.mine || myId != null)
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
      const SizedBox(height: 12),
      _StatusCards(summary: _lastSummary, status: _q.status, onSelect: _setStatus, onOther: _openFilters),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text(
              _scope == LiveScope.favorites ? 'Favorite Assets' : 'Asset List',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong,
            ),
          ),
          _LinkButton(
            label: 'Sort',
            icon: Icons.swap_vert_rounded,
            tooltip: 'Sort: ${AssetSortKeys.all[_q.sortBy ?? 'createdAt']}',
            onTap: _openSort,
          ),
          const SizedBox(width: 8),
          _LinkButton(
            label: active.isEmpty ? 'Filter' : 'Filter (${active.length})',
            icon: Icons.filter_alt_outlined,
            onTap: _openFilters,
          ),
        ],
      ),
      if (active.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (group, label, clear) in active)
              InputChip(
                label: Text(label),
                labelStyle: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                backgroundColor: AppColors.primarySoft,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                deleteIconColor: AppColors.primary,
                tooltip: group,
                onDeleted: () => setState(() => _q = clear(_q)),
                onPressed: _openFilters,
              ),
            ActionChip(
              label: const Text('Clear all'),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _q = withoutFilters(_q)),
            ),
          ],
        ),
      ],
    ];
  }

  /// (group, chip label, remove) for every filter in use.
  List<(String, String, AssetListQuery Function(AssetListQuery))> _activeFilters() {
    final needsNames = _q.locationId != null || _q.custodianUserId != null;
    final f = needsNames ? ref.watch(assetListFiltersProvider).value : null;
    String locationLabel(String id) => f?.locations.where((l) => l.id == id).firstOrNull?.path ?? id;
    String custodianLabel(String id) => f?.custodians.where((c) => c.userId == id).firstOrNull?.name ?? id;
    return [
      if (_q.category case final v?) ('Category', v, (q) => q.copyWith(category: () => null)),
      if (_q.assetType case final v?) ('Asset Type', v, (q) => q.copyWith(assetType: () => null)),
      if (_q.status case final v?) ('Status', v, (q) => q.copyWith(status: () => null)),
      if (_q.locationId case final v?) ('Location', locationLabel(v), (q) => q.copyWith(locationId: () => null)),
      if (_q.department case final v?) ('Department', v, (q) => q.copyWith(department: () => null)),
      if (_q.custodianUserId case final v? when _scope != LiveScope.mine)
        ('Custodian', custodianLabel(v), (q) => q.copyWith(custodianUserId: () => null)),
      if (_q.criticality case final v?) ('Criticality', v, (q) => q.copyWith(criticality: () => null)),
      if (_q.manufacturer case final v?) ('Manufacturer', v, (q) => q.copyWith(manufacturer: () => null)),
      if (_q.condition case final v?) ('Condition', v, (q) => q.copyWith(condition: () => null)),
    ];
  }

  Widget _list(_ListView view, AssetListQuery q) {
    final items = view.items;
    if (items == null) {
      if (view.error != null) {
        return SliverToBoxAdapter(
          child: AppCard(
            child: LoadErrorState(title: 'Could not load assets', error: view.error!, onRetry: () => _retry(q)),
          ),
        );
      }
      return const SliverToBoxAdapter(child: ListSkeleton(rows: 6));
    }
    if (items.isEmpty) return SliverToBoxAdapter(child: AppCard(child: _empty()));
    return SliverCardList(
      itemCount: items.length,
      indent: 90,
      itemBuilder: (_, i) {
        // Infinite scroll: the last row being built (it is near the viewport) loads the next page.
        if (i == items.length - 1 && view.hasMore && !view.loadingMore && view.loadMoreError == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ref.read(liveAssetListProvider(q).notifier).loadMore();
          });
        }
        return LiveAssetRow(key: ValueKey(items[i].assetRegistrationId), item: items[i]);
      },
    );
  }

  Widget _empty() {
    if (!_filtered && _scope == LiveScope.favorites) {
      return EmptyState(
        icon: Icons.star_border_rounded,
        title: 'No favorites yet',
        message: 'Tap the ☆ on an asset to add it to Favorites.',
        actionLabel: 'Show all assets',
        onAction: () => setState(() => _scope = LiveScope.all),
      );
    }
    if (!_filtered && _scope == LiveScope.all) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No assets yet',
        message: 'Registered assets will appear here.',
        actionLabel: 'Register asset',
        onAction: () => context.push(Routes.registration),
      );
    }
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No assets found',
      message: 'Try another search or clear the filters.',
      actionLabel: 'Clear search & filters',
      onAction: _clearAll,
    );
  }

  List<Widget> _footer(_ListView view, AssetListQuery q) => [
    if (view.loadingMore)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      ),
    // Only while pages remain: a stale error survives a successful retry in LiveAssetListNotifier.
    if (view.loadMoreError case final e? when view.hasMore)
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ApiException.from(e).message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.secondary,
              ),
            ),
            TextButton(
              onPressed: () => ref.read(liveAssetListProvider(q).notifier).loadMore(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    Center(
      child: Text(
        'Showing ${formatLiveCount(view.items!.length)} of ${formatLiveCount(view.totalCount)}',
        style: AppText.secondary,
      ),
    ),
  ];
}

/// "Sort ⇅" / "Filter ⏷" link in the list heading.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.icon, required this.onTap, this.tooltip});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.link),
            const SizedBox(width: 4),
            Icon(icon, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Total / Active / Under Maintenance / In Repair / Disposed / Other from the server summary
/// (counted without the status filter). A card sets the status filter; Total clears it; Other
/// opens the filter sheet (its statuses are listed there).
class _StatusCards extends StatelessWidget {
  const _StatusCards({required this.summary, required this.status, required this.onSelect, required this.onOther});

  final AssetStatusSummary summary;
  final String? status;
  final ValueChanged<String?> onSelect;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    final named = AssetStatus.values.contains(status);
    final cards = [
      ('Total', summary.total, Icons.inventory_2_outlined, AppColors.primary, null, status == null),
      ('Active', summary.active, Icons.check_circle_outline_rounded, AppColors.green, AssetStatus.active, null),
      (
        'Under Maintenance',
        summary.underMaintenance,
        Icons.build_outlined,
        AppColors.amber,
        AssetStatus.underMaintenance,
        null,
      ),
      ('In Repair', summary.inRepair, Icons.handyman_outlined, AppColors.orange, AssetStatus.inRepair, null),
      ('Disposed', summary.disposed, Icons.delete_outline_rounded, AppColors.red, AssetStatus.disposed, null),
      ('Other', summary.other, Icons.more_horiz_rounded, AppColors.grey, AssetStatus.other, status != null && !named),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, count, icon, color, value, forced) in cards)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _card(label, count, icon, color, value, forced ?? (status == value)),
            ),
        ],
      ),
    );
  }

  Widget _card(String label, int count, IconData icon, Color color, String? value, bool selected) => Container(
    key: ValueKey('status-card-$label'),
    width: 112,
    foregroundDecoration: selected
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.6),
          )
        : null,
    child: Semantics(
      selected: selected,
      child: CountCard(
        icon: icon,
        value: formatLiveCount(count),
        label: label,
        color: color,
        onTap: switch (value) {
          AssetStatus.other => onOther,
          null => () => onSelect(null),
          final v => () => onSelect(selected ? null : v),
        },
      ),
    ),
  );
}
