import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/inventory.dart';
import '../../data/repositories/inventory_repository.dart';
import 'inventory_widgets.dart';

/// Inventory / Spare Parts hub (left screen of design/12_inventory_spare_parts.jpg).
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key, this.initialTab});

  /// all, low, reorder or reserved.
  final String? initialTab;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  static const _tabKeys = ['all', 'low', 'reorder', 'reserved'];
  late int _tab = _index(widget.initialTab);
  String _query = '';
  FilterSelection _filters = const {};
  final _search = TextEditingController();

  static int _index(String? k) => _tabKeys.contains(k) ? _tabKeys.indexOf(k!) : 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(InventoryScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) _tab = _index(widget.initialTab);
  }

  @override
  Widget build(BuildContext context) {
    final inv = ref.watch(inventoryProvider);
    final lists = [inv.parts, inv.lowStock, inv.reorder, inv.reserved];
    final rows = inv
        .search(lists[_tab], _query)
        .where(
          (p) =>
              (_filters['Category']?.contains(p.category) ?? true) &&
              (_filters['Warehouse']?.contains(p.warehouse) ?? true) &&
              (_filters['Stock status']?.contains(p.status) ?? true),
        )
        .toList();
    final categories = {for (final p in inv.parts) p.category}.toList()..sort();
    final warehouses = {for (final p in inv.parts) p.warehouse}.toList()..sort();
    final tiles = [
      (
        Icons.inventory_2_rounded,
        'View Inventory',
        'All Spare Parts',
        TileTone.lavender,
        () => setState(() => _tab = 0),
      ),
      (
        Icons.shopping_cart_rounded,
        'Request Part',
        'Create Request',
        TileTone.sky,
        () => context.push(Routes.partRequests),
      ),
      (
        Icons.receipt_long_rounded,
        'Purchase Orders',
        'Track Orders',
        TileTone.peach,
        () => context.push(Routes.purchaseOrders),
      ),
      (
        Icons.bar_chart_rounded,
        'Stock Reports',
        'Usage & Forecast',
        TileTone.sky,
        () => context.push(Routes.stockReports),
      ),
    ];
    return AppScaffold(
      body: LazyListPage(
        header: [
          PageTitle(
            title: 'Inventory / Spare Parts',
            subtitle: 'Manage spare parts, stock levels and procurement',
            help:
                'The organisation has ${inv.totalItems} inventory items; ${inv.parts.length} detailed records are '
                'shown. Stock status is computed from quantity vs reorder level. Reserved stock is held for work '
                'orders and is not available to issue.',
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              for (final (icon, label, sub, tone, onTap) in tiles)
                ActionTile(icon: icon, label: label, subtitle: sub, tone: tone, onTap: onTap),
            ],
          ),
          const SizedBox(height: 14),
          SegmentTabs(
            tabs: [
              SegmentTab('All Items', count: inv.totalItems),
              SegmentTab('Low Stock', count: inv.lowStock.length),
              SegmentTab('Reorder', count: inv.reorder.length),
              SegmentTab('Reserved', count: inv.reserved.length),
            ],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search by Part No., Name or Category...',
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            filterGroups: [
              FilterGroup(title: 'Category', options: categories),
              FilterGroup(title: 'Warehouse', options: warehouses),
              const FilterGroup(
                title: 'Stock status',
                options: [StockStatus.inStock, StockStatus.lowStock, StockStatus.outOfStock],
              ),
            ],
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 12),
        ],
        list: SliverLoadingGate(
          rows: 5,
          sliver: rows.isEmpty
              ? SliverToBoxAdapter(
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No parts match',
                      message: _query.isEmpty && _filters.isEmpty
                          ? 'No parts in this list right now.'
                          : 'Try another part number, name or filter.',
                      actionLabel: _query.isEmpty && _filters.isEmpty ? null : 'Clear filters',
                      onAction: () => setState(() {
                        _search.clear();
                        _query = '';
                        _filters = const {};
                      }),
                    ),
                  ),
                )
              : SliverCardList(
                  itemCount: rows.length,
                  indent: 90,
                  itemBuilder: (_, i) => PartRow(part: rows[i]),
                ),
        ),
        footer: [
          const SizedBox(height: 8),
          Text(
            _tab == 0 && _query.isEmpty && _filters.isEmpty
                ? 'Showing ${rows.length} of ${inv.totalItems}'
                : '${rows.length} of ${lists[_tab].length} parts',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
