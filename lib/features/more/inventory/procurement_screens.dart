import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/inventory_mock.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/models/inventory.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/more/inventory/inventory_widgets.dart';

/// Searchable part list in a sheet. Returns the chosen part number.
Future<String?> showPartPicker(BuildContext context) =>
    showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (_) => const _PartPicker());

class _PartPicker extends ConsumerStatefulWidget {
  const _PartPicker();

  @override
  ConsumerState<_PartPicker> createState() => _PartPickerState();
}

class _PartPickerState extends ConsumerState<_PartPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final inv = ref.watch(inventoryProvider);
    final parts = inv.search(inv.parts, _q);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Search part number, name or category',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: parts.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 90),
              itemBuilder: (_, i) => PartRow(part: parts[i], onTap: () => Navigator.pop(context, parts[i].id)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Part field: tap to pick.
class _PartField extends ConsumerWidget {
  const _PartField({required this.partId, required this.onChanged, this.error});

  final String? partId;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = partId == null ? null : ref.watch(partByIdProvider(partId!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: p == null
              ? ListTile(
                  leading: Icon(Icons.search_rounded, color: AppColors.primary),
                  title: const Text('Select part'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final id = await showPartPicker(context);
                    if (id != null) onChanged(id);
                  },
                )
              : PartRow(
                  part: p,
                  onTap: () async {
                    final id = await showPartPicker(context);
                    if (id != null) onChanged(id);
                  },
                ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!, style: AppText.caption.copyWith(color: AppColors.red)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Purchase orders

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final inv = ref.watch(inventoryProvider);
    final all = inv.purchaseOrders;
    final rows = all.where((p) => _status == null || p.status == _status).toList();
    int n(String s) => all.where((p) => p.status == s).length;
    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'New Purchase Order',
        onPressed: () => context.push(Routes.newPurchaseOrder()),
        child: const Icon(Icons.add_rounded),
      ),
      body: LazyListPage(
        header: [
          PageTitle(title: 'Purchase Orders', subtitle: '${n(RequestStatus.open)} open · ${all.length} in total'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in [null, RequestStatus.open, RequestStatus.received])
                IconFilterChip(
                  label: s == null ? 'All (${all.length})' : '$s (${n(s)})',
                  selected: _status == s,
                  onTap: () => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        list: SliverLoadingGate(
          rows: 5,
          sliver: rows.isEmpty
              ? SliverToBoxAdapter(
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: _status == null
                          ? 'No purchase orders yet'
                          : 'No ${_status!.toLowerCase()} purchase orders',
                      actionLabel: 'New Purchase Order',
                      onAction: () => context.push(Routes.newPurchaseOrder()),
                    ),
                  ),
                )
              : SliverCardList(
                  itemCount: rows.length,
                  itemBuilder: (_, i) =>
                      _PoTile(po: rows[i], partName: inv.part(rows[i].partId)?.name ?? rows[i].partId),
                ),
        ),
      ),
    );
  }
}

class _PoTile extends StatelessWidget {
  const _PoTile({required this.po, required this.partName});

  final PartRequest po;
  final String partName;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
    title: Text(po.id, style: AppText.bodyStrong),
    subtitle: Text(
      '$partName × ${po.qty} · ${po.supplier ?? ''}\n${DemoClock.formatDate(po.createdAt)} · ${money(po.total)}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppText.caption,
    ),
    isThreeLine: true,
    trailing: StatusChip(po.status, tone: requestTone(po.status)),
    onTap: () => context.push(Routes.purchaseOrder(po.id)),
  );
}

class PurchaseOrderScreen extends ConsumerWidget {
  const PurchaseOrderScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(inventoryProvider);
    final po = inv.request(id);
    if (po == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Not found', message: id),
      );
    }
    final part = inv.part(po.partId);
    return AppScaffold(
      bottomActions: po.isOpen
          ? FilledButton.icon(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Receive ${po.id}?',
                  message: '${po.qty} × ${po.partId} are added to ${part?.warehouse ?? 'stock'} with a goods receipt.',
                  confirmLabel: 'Receive (GRN)',
                );
                if (!ok || !context.mounted) return;
                final grn = ref.read(inventoryProvider.notifier).receivePo(po.id);
                context.showSnack('$grn posted · ${po.qty} added to stock');
                await showGrnSheet(context, ref, grn);
              },
              icon: const Icon(Icons.move_to_inbox_rounded),
              label: const Text('Receive (GRN)'),
            )
          : null,
      body: ListView(
        padding: po.isOpen ? const EdgeInsets.fromLTRB(16, 16, 16, 24) : context.pagePadding,
        children: [
          PageTitle(
            title: po.id,
            subtitle: 'Purchase Order · ${po.supplier ?? '—'}',
            trailing: StatusChip(po.status, tone: requestTone(po.status)),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                InfoRow(label: 'Supplier', value: po.supplier ?? '—'),
                InfoRow(label: 'Created', value: DemoClock.formatDateTime(po.createdAt)),
                InfoRow(label: 'Expected', value: po.expectedAt == null ? '—' : DemoClock.formatDate(po.expectedAt!)),
                if (po.receivedAt != null) InfoRow(label: 'Received', value: DemoClock.formatDateTime(po.receivedAt!)),
                if (po.remarks != null) InfoRow(label: 'Notes', value: po.remarks!),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Lines (1)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (part != null) PartRow(part: part),
                const Divider(),
                InfoRow(label: 'Quantity', value: '${po.qty} ${part?.unit ?? ''}'),
                InfoRow(label: 'Unit cost', value: money(po.unitCost ?? 0, part?.currency ?? 'USD')),
                InfoRow(label: 'Line total', value: money(po.total, part?.currency ?? 'USD')),
              ],
            ),
          ),
          if (po.grn != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showGrnSheet(context, ref, po.grn!),
              icon: const Icon(Icons.inventory_rounded),
              label: Text('Goods receipt ${po.grn}'),
            ),
          ],
        ],
      ),
    );
  }
}

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key, this.partId});

  final String? partId;

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends ConsumerState<PurchaseOrderFormScreen> {
  String? _partId;
  final _supplier = TextEditingController();
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  DateTime? _expected;
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    if (widget.partId != null) _setPart(widget.partId!);
  }

  @override
  void dispose() {
    _supplier.dispose();
    _qty.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _setPart(String id) {
    final p = ref.read(partByIdProvider(id));
    if (p == null) return;
    _partId = id;
    _supplier.text = p.supplier == '—' ? '' : p.supplier;
    _qty.text = '${p.reorderQty}';
    _cost.text = p.unitCost.toStringAsFixed(2);
    _expected = DemoClock.today.add(Duration(days: p.leadTimeDays));
    _errors.remove('part');
  }

  double get _total => (int.tryParse(_qty.text) ?? 0) * (double.tryParse(_cost.text) ?? 0);

  Future<void> _save() async {
    final qty = int.tryParse(_qty.text.trim());
    final cost = double.tryParse(_cost.text.trim());
    setState(() {
      _errors
        ..clear()
        ..addAll({
          if (_partId == null) 'part': 'Choose a part',
          if (_supplier.text.trim().isEmpty) 'supplier': 'Enter the supplier',
          if (qty == null || qty <= 0) 'qty': 'Enter a quantity',
          if (cost == null || cost < 0) 'cost': 'Enter the unit cost',
          if (_expected == null) 'date': 'Choose the expected date',
        });
    });
    if (_errors.isNotEmpty) return;
    final id = ref
        .read(inventoryProvider.notifier)
        .createRequest(
          _partId!,
          qty!,
          kind: 'Purchase Order',
          supplier: _supplier.text.trim(),
          unitCost: cost,
          expectedAt: _expected,
        );
    final open = await showSuccessSheet(
      context,
      title: '$id created',
      message: 'Open purchase order for $qty × $_partId · ${money(qty * cost!)}',
      primaryLabel: 'View Purchase Order',
      secondaryLabel: 'Done',
    );
    if (!mounted) return;
    open ? context.pushReplacement(Routes.purchaseOrder(id)) : context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = _partId == null ? null : ref.watch(partByIdProvider(_partId!));
    return AppScaffold(
      bottomActions: FilledButton(onPressed: _save, child: Text('Create PO · ${money(_total, p?.currency ?? 'USD')}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const PageTitle(title: 'Create Purchase Order', subtitle: 'Order stock from a supplier'),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Part',
            required: true,
            child: _PartField(partId: _partId, error: _errors['part'], onChanged: (id) => setState(() => _setPart(id))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _supplier,
            decoration: InputDecoration(labelText: 'Supplier *', errorText: _errors['supplier']),
          ),
          const SizedBox(height: 12),
          FieldPair(
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: 'Quantity *', errorText: _errors['qty'], suffixText: p?.unit),
            ),
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Unit cost *',
                errorText: _errors['cost'],
                prefixText: '${p?.currency ?? 'USD'} ',
              ),
            ),
          ),
          const SizedBox(height: 4),
          LabeledField(
            label: 'Expected date',
            required: true,
            child: DateBox(
              value: _expected,
              firstDate: DemoClock.today,
              error: _errors['date'],
              onPicked: (d) => setState(() => _expected = d),
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Row(
              children: [
                Expanded(child: Text('Total', style: AppText.bodyStrong)),
                Text(money(_total, p?.currency ?? 'USD'), style: AppText.cardTitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Part requests

class PartRequestsScreen extends ConsumerWidget {
  const PartRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(inventoryProvider);
    final me = ref.watch(currentUserProvider).id;
    final mine = inv.partRequests.where((r) => r.requesterId == me).toList();
    return AppScaffold(
      bottomActions: FilledButton.icon(
        onPressed: () => context.push(Routes.requestPart()),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Request Part'),
      ),
      body: LazyListPage(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        header: [
          PageTitle(title: 'My Requests', subtitle: '${mine.length} part requests'),
          const SizedBox(height: 12),
        ],
        list: SliverLoadingGate(
          rows: 4,
          sliver: mine.isEmpty
              ? SliverToBoxAdapter(
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'No requests yet',
                      message: 'Request a spare part and track it here.',
                      actionLabel: 'Request Part',
                      onAction: () => context.push(Routes.requestPart()),
                    ),
                  ),
                )
              : SliverCardList(
                  itemCount: mine.length,
                  itemBuilder: (_, i) {
                    final r = mine[i];
                    return ListTile(
                      leading: Icon(Icons.shopping_cart_rounded, color: AppColors.primary),
                      title: Text(
                        '${r.id} · ${inv.part(r.partId)?.name ?? r.partId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong,
                      ),
                      subtitle: Text(
                        [
                          'Qty ${r.qty}',
                          if (r.neededBy != null) 'Needed by ${DemoClock.formatDate(r.neededBy!)}',
                          if (r.workOrderId != null) r.workOrderId!,
                          if (r.remarks != null) r.remarks!,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                      trailing: StatusChip(r.status, tone: requestTone(r.status)),
                      onTap: () => r.status == RequestStatus.pending
                          ? _cancel(context, ref, r)
                          : context.push(Routes.partDetail(r.partId)),
                    );
                  },
                ),
        ),
        footer: [
          const SizedBox(height: 8),
          if (mine.any((r) => r.status == RequestStatus.pending))
            Text('Tap a pending request to cancel it.', textAlign: TextAlign.center, style: AppText.caption),
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, PartRequest r) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel ${r.id}?',
      message: 'The request for ${r.qty} × ${r.partId} is withdrawn.',
      confirmLabel: 'Cancel Request',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    ref.read(inventoryProvider.notifier).cancelRequest(r.id);
    context.showSnack('${r.id} cancelled');
  }
}

class RequestPartScreen extends ConsumerStatefulWidget {
  const RequestPartScreen({super.key, this.partId});

  final String? partId;

  @override
  ConsumerState<RequestPartScreen> createState() => _RequestPartScreenState();
}

class _RequestPartScreenState extends ConsumerState<RequestPartScreen> {
  late String? _partId = widget.partId;
  final _qty = TextEditingController(text: '1');
  DateTime? _neededBy;
  String? _wo;
  String? _reason;
  final _errors = <String, String>{};

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qty.text.trim());
    setState(() {
      _errors
        ..clear()
        ..addAll({
          if (_partId == null) 'part': 'Choose a part',
          if (qty == null || qty <= 0) 'qty': 'Enter a quantity',
          if (_neededBy == null) 'date': 'Choose when it is needed',
          if (_reason == null) 'reason': 'Choose a reason',
        });
    });
    if (_errors.isNotEmpty) return;
    final id = ref
        .read(inventoryProvider.notifier)
        .createRequest(_partId!, qty!, kind: 'Request', neededBy: _neededBy, workOrderId: _wo, remarks: _reason);
    await showSuccessSheet(context, title: 'Request $id submitted', message: 'It is Pending with the stores team.');
    if (!mounted) return;
    context.pushReplacement(Routes.partRequests);
  }

  @override
  Widget build(BuildContext context) {
    final wos = ref.watch(workOrdersProvider).active;
    return AppScaffold(
      bottomActions: FilledButton(onPressed: _submit, child: const Text('Submit Request')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const PageTitle(title: 'Request Part', subtitle: 'Ask the stores team for a spare part'),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Part',
            required: true,
            child: _PartField(
              partId: _partId,
              error: _errors['part'],
              onChanged: (id) => setState(() {
                _partId = id;
                _errors.remove('part');
              }),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Quantity *', errorText: _errors['qty']),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Needed by',
            required: true,
            child: DateBox(
              value: _neededBy,
              firstDate: DemoClock.today,
              error: _errors['date'],
              onPicked: (d) => setState(() => _neededBy = d),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _wo,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Linked work order (optional)'),
            items: [
              const DropdownMenuItem(child: Text('None')),
              for (final w in wos)
                DropdownMenuItem(
                  value: w.id,
                  child: Text('${w.id} · ${w.title}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _wo = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Reason *', errorText: _errors['reason']),
            items: [for (final r in partRequestReasons) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => _reason = v),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Stock reports

class StockReportsScreen extends ConsumerStatefulWidget {
  const StockReportsScreen({super.key});

  @override
  ConsumerState<StockReportsScreen> createState() => _StockReportsScreenState();
}

class _StockReportsScreenState extends ConsumerState<StockReportsScreen> {
  /// Forecast part; defaults to the most consumed part.
  String? _part;

  @override
  Widget build(BuildContext context) {
    final inv = ref.watch(inventoryProvider);
    final totals = [
      for (var m = 0; m < usageMonths.length; m++)
        inv.parts.fold<int>(0, (s, p) => s + inv.monthlyUsage(p.id)[m]).toDouble(),
    ];
    final top = [for (final p in inv.parts) (p, inv.monthlyUsage(p.id).fold<int>(0, (a, b) => a + b))]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final part = inv.part(_part ?? '') ?? top.first.$1;
    final perDay = inv.averageUsage(part.id) / 30;
    // Forecast: available stock over the next 60 days at the average usage rate.
    final forecast = [
      for (var d = 0; d <= 60; d += 5) TrendPoint(d.toDouble(), (part.available - perDay * d).clamp(0, 1e9).toDouble()),
    ];
    final date = inv.reorderDate(part.id);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(title: 'Stock Reports', subtitle: 'Usage and forecast'),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Usage – last 6 months (all parts)',
            child: SizedBox(
              height: 190,
              child: BarSeriesChart(values: totals, labels: usageMonths, unit: 'units'),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Top 5 consumed parts',
            child: Column(
              children: [
                for (final (i, (p, n)) in top.take(5).indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primarySoft,
                      child: Text('${i + 1}', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                    subtitle: Text(p.id, style: AppText.caption),
                    trailing: Text('$n ${p.unit}', style: AppText.bodyStrong),
                    selected: p.id == part.id,
                    onTap: () {
                      setState(() => _part = p.id);
                      context.showSnack('Forecast below now shows ${p.name}');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Forecast',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('forecast-${part.id}'),
                  initialValue: part.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Part'),
                  items: [
                    for (final p in inv.parts)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.id} · ${p.name}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _part = v ?? part.id),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: TrendChart(
                    key: ValueKey(part.id),
                    points: forecast,
                    unit: part.unit,
                    xLabel: (x) => '+${x.toInt()}d',
                    xInterval: 10,
                    minY: 0,
                    decimals: 0,
                  ),
                ),
                const SizedBox(height: 8),
                InfoRow(label: 'Available now', value: '${part.available}'),
                InfoRow(label: 'Average usage', value: '${inv.averageUsage(part.id).toStringAsFixed(1)} / month'),
                InfoRow(label: 'Reorder level', value: '${part.reorderLevel}'),
                InfoRow(
                  label: 'Reorder date (est.)',
                  value: date == null ? 'No usage recorded' : DemoClock.formatDate(date),
                  valueColor: date != null && !date.isAfter(DemoClock.today) ? AppColors.red : AppColors.primary,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.push(Routes.partDetail(part.id)),
                  child: const Text('Open part'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
