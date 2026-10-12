import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/inventory_mock.dart';
import 'package:asset360_mobile/data/models/inventory.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/features/more/inventory/inventory_widgets.dart';

enum StockTab {
  history('Stock History'),
  usage('Usage'),
  reserved('Reserved'),
  pos('Purchase Orders');

  const StockTab(this.label);
  final String label;
}

/// Stock Movement (right screen of design/12_inventory_spare_parts.jpg). Without a part it lists every movement.
class StockMovementScreen extends ConsumerStatefulWidget {
  const StockMovementScreen({super.key, this.partId, this.initialTab});

  final String? partId;
  final String? initialTab;

  @override
  ConsumerState<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  late StockTab _tab = _initialTab();

  /// The tab from the route; the client demo only opens Stock History.
  StockTab _initialTab() {
    final t = StockTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => StockTab.history);
    return t == StockTab.history || demoCanDo(DemoAction.stockOtherTabs) ? t : StockTab.history;
  }

  String _query = '';
  FilterSelection _filters = const {};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _dates = {'Last 7 days': 7, 'Last 30 days': 30};

  @override
  Widget build(BuildContext context) {
    final inv = ref.watch(inventoryProvider);
    final part = widget.partId == null ? null : inv.part(widget.partId!);
    final txns = widget.partId == null ? inv.txns : inv.historyFor(widget.partId!);
    final q = _query.trim().toLowerCase();
    final rows = txns
        .where(
          (t) =>
              (q.isEmpty ||
                  '${t.ref} ${t.po ?? ''} ${t.remarks ?? ''} ${t.assetId ?? ''} ${t.partId}'.toLowerCase().contains(
                    q,
                  )) &&
              (_filters['Type']?.contains(t.type) ?? true) &&
              (_filters['Date']?.every((d) => DemoClock.now.difference(t.at).inDays < _dates[d]!) ?? true),
        )
        .toList();
    final history = part == null || _tab == StockTab.history;
    return AppScaffold(
      body: LazyListPage(
        header: [
          PageTitle(
            leading: ScanPartButton(currentPartId: part?.id),
            title: 'Stock Movement',
            subtitle: part == null ? 'All inventory transactions' : 'Track all inventory transactions for this part',
          ),
          const SizedBox(height: 12),
          if (part != null) ...[
            PartCard(part: part, compact: true, onTap: () => context.push(Routes.partDetail(part.id))),
            const SizedBox(height: 6),
            SegmentTabs(
              tabs: [
                for (final t in StockTab.values)
                  SegmentTab(t.label, enabled: t == StockTab.history || demoCanDo(DemoAction.stockOtherTabs)),
              ],
              selected: _tab.index,
              onChanged: (i) => setState(() => _tab = StockTab.values[i]),
            ),
            const SizedBox(height: 12),
          ],
          if (history) ...[
            SearchFilterBar(
              hint: 'Search by reference, work order or remarks...',
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              filterGroups: [
                const FilterGroup(title: 'Type', options: TxnType.all),
                FilterGroup(title: 'Date', options: _dates.keys.toList(), multiSelect: false),
              ],
              selection: _filters,
              onFiltersChanged: (f) => setState(() => _filters = f),
            ),
            const SizedBox(height: 12),
          ],
        ],
        list: !history
            ? SliverToBoxAdapter(
                child: LoadingGate(
                  key: ValueKey(_tab),
                  rows: 3,
                  child: switch (_tab) {
                    StockTab.usage => _usage(inv, part),
                    StockTab.reserved => _reserved(part),
                    _ => _pos(inv, part),
                  },
                ),
              )
            : SliverLoadingGate(
                key: ValueKey(_tab),
                rows: 5,
                sliver: rows.isEmpty
                    ? SliverToBoxAdapter(
                        child: AppCard(
                          child: EmptyState(
                            icon: Icons.sync_alt_rounded,
                            title: 'No movements',
                            message: txns.isEmpty
                                ? 'No stock transactions recorded yet.'
                                : 'No transactions match your search or filters.',
                            actionLabel: txns.isEmpty ? null : 'Clear filters',
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
                        indent: 62,
                        itemBuilder: (_, i) => TxnRow(txn: rows[i], showPart: part == null),
                      ),
              ),
        footer: [
          if (history && part != null && rows.length == txns.length && txns.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Opening balance ${txns.last.balanceAfter - txns.last.qtyChange} → current stock ${part.qty}',
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
            ),
        ],
      ),
    );
  }

  Widget _usage(InventoryState inv, Part p) {
    final usage = inv.monthlyUsage(p.id);
    final total = usage.fold<int>(0, (a, b) => a + b);
    final date = inv.reorderDate(p.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Monthly consumption (${p.unit})', style: AppText.bodyStrong),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: BarSeriesChart(values: [for (final u in usage) u.toDouble()], labels: usageMonths, unit: p.unit),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              InfoRow(label: 'Used (6 months)', value: '$total ${p.unit}'),
              InfoRow(label: 'Average / month', value: inv.averageUsage(p.id).toStringAsFixed(1)),
              InfoRow(label: 'Available now', value: '${p.available}'),
              InfoRow(
                label: 'Reorder by (est.)',
                value: date == null ? 'No usage recorded' : DemoClock.formatDate(date),
                valueColor: date != null && !date.isAfter(DemoClock.today) ? AppColors.red : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reserved(Part p) {
    final wos = ref.watch(workOrdersProvider);
    final byWo = [
      for (final w in wos)
        if (w.isActive)
          for (final wp in w.parts)
            if (wp.partId == p.id && wp.status == 'Reserved') (w, wp.qty),
    ];
    final other = p.reserved - byWo.fold<int>(0, (s, e) => s + e.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${p.reserved} ${p.unit} reserved · ${p.available} available', style: AppText.secondary),
        const SizedBox(height: 10),
        if (byWo.isEmpty && other <= 0)
          const AppCard(
            child: EmptyState(icon: Icons.lock_open_rounded, title: 'No reservations'),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (w, qty) in byWo)
                  ListTile(
                    leading: const Icon(Icons.build_circle_rounded, color: AppColors.orange),
                    title: Text('${w.id} · $qty ${p.unit}', style: AppText.bodyStrong),
                    subtitle: Text('${w.title} · ${w.assetId}', style: AppText.caption),
                    onTap: DemoGuard.push(context, Routes.workOrder(w.id)),
                    trailing: TextButton(
                      onPressed: () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: 'Release $qty from ${w.id}?',
                          message: 'The part is removed from the work order and goes back to available stock.',
                          confirmLabel: 'Release',
                        );
                        if (!ok || !mounted) return;
                        ref.read(workOrdersProvider.notifier).removePart(w.id, p.id);
                        context.showSnack('$qty × ${p.id} released from ${w.id}');
                      },
                      child: const Text('Release'),
                    ),
                  ),
                if (other > 0)
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded, color: AppColors.orange),
                    title: Text('Other reservations · $other ${p.unit}', style: AppText.bodyStrong),
                    subtitle: Text('Held without a work order', style: AppText.caption),
                    trailing: TextButton(
                      onPressed: () {
                        ref.read(inventoryProvider.notifier).unreserve(p.id, other);
                        context.showSnack('$other × ${p.id} released');
                      },
                      child: const Text('Release'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pos(InventoryState inv, Part p) {
    final pos = inv.posFor(p.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pos.isEmpty)
          const AppCard(
            child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No purchase orders'),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final po in pos)
                  ListTile(
                    leading: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                    title: Text(po.id, style: AppText.bodyStrong),
                    subtitle: Text(
                      '${po.qty} ${p.unit} · ${po.supplier ?? ''} · ${DemoClock.formatDate(po.createdAt)}',
                      style: AppText.caption,
                    ),
                    trailing: StatusChip(po.status, tone: requestTone(po.status)),
                    onTap: () => context.push(Routes.purchaseOrder(po.id)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.newPurchaseOrder(partId: p.id)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Purchase Order'),
        ),
      ],
    );
  }
}
