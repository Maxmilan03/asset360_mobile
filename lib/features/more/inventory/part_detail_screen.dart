import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/inventory.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/features/more/inventory/inventory_actions.dart';
import 'package:asset360_mobile/features/more/inventory/inventory_widgets.dart';

/// Part Details (middle screen of design/12_inventory_spare_parts.jpg).
class PartDetailScreen extends ConsumerWidget {
  const PartDetailScreen({super.key, required this.partId});

  final String partId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(partByIdProvider(partId));
    if (p == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Part not found', message: partId),
      );
    }
    return AppScaffold(
      bottomActions: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push(Routes.requestPart(partId: p.id)),
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Create Request')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.newPurchaseOrder(partId: p.id)),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Create Purchase Order')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          PageTitle(
            leading: ScanPartButton(currentPartId: p.id),
            title: 'Part Details',
            subtitle: 'View stock, location and usage details',
            trailing: PopupMenuButton<String>(
              tooltip: 'Stock actions',
              icon: Icon(Icons.more_vert_rounded, color: AppColors.text),
              onSelected: (v) => switch (v) {
                'issue' => showIssueToWoSheet(context, ref, p),
                'count' => showStockCountSheet(context, ref, p),
                _ => context.push(Routes.partStock(p.id)),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'issue', child: Text('Issue to Work Order')),
                PopupMenuItem(value: 'count', child: Text('Stock Count Adjustment')),
                PopupMenuItem(value: 'history', child: Text('Stock Movement')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PartCard(part: p, onTap: () => showSpecSheet(context, p)),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Stock Overview',
            actionLabel: 'Edit',
            actionIcon: Icons.edit_outlined,
            onAction: () => showEditLevelsSheet(context, ref, p),
            child: Row(
              children: [
                for (final (n, (icon, label, value, tone)) in [
                  (Icons.inventory_2_rounded, 'Current Stock', p.qty, TileTone.mint),
                  (Icons.warning_rounded, 'Reorder Level', p.reorderLevel, TileTone.peach),
                  (Icons.shopping_bag_rounded, 'Reorder Qty', p.reorderQty, TileTone.sky),
                ].indexed) ...[
                  if (n > 0) const SizedBox(width: 8),
                  Expanded(
                    child: KpiTile(
                      icon: icon,
                      value: '$value',
                      label: label,
                      tone: tone,
                      onTap: () => n == 0 ? context.push(Routes.partStock(p.id)) : showEditLevelsSheet(context, ref, p),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Location Details',
            actionLabel: 'Manage',
            actionIcon: Icons.edit_outlined,
            onAction: () => showManageLocationSheet(context, ref, p),
            child: Column(
              children: [
                InfoRow(label: 'Primary Location', value: p.warehouse),
                InfoRow(label: 'Rack / Bin', value: p.bin),
                InkWell(
                  onTap: () => context.push(Routes.partStock(p.id, tab: 'reserved')),
                  child: InfoRow(
                    label: 'Reserved Qty',
                    value: '${p.reserved}',
                    valueWidget: Row(
                      children: [
                        Text('${p.reserved}', style: AppText.body.copyWith(fontSize: 13, color: AppColors.text)),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                InfoRow(
                  label: 'Available Qty',
                  value: '${p.available}',
                  valueColor: p.available <= p.reorderLevel ? AppColors.red : null,
                ),
                InfoRow(
                  label: 'Last Stock Update',
                  value: p.lastUpdate == null ? '—' : DemoClock.formatDateTime(p.lastUpdate!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Additional Information',
            child: Column(
              children: [
                InfoRow(label: 'Lead Time', value: '${p.leadTimeDays} days'),
                InfoRow(label: 'Unit Cost', value: money(p.unitCost, p.currency)),
                InfoRow(label: 'Preferred Supplier', value: p.supplier),
                InfoRow(label: 'Warranty', value: p.warrantyMonths == 0 ? '—' : '${p.warrantyMonths} months'),
                InfoRow(label: 'Remarks', value: p.remarks.isEmpty ? '—' : p.remarks),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.partStock(p.id)),
            icon: const Icon(Icons.sync_alt_rounded),
            label: Text('Stock Movement (${ref.watch(inventoryProvider).historyFor(p.id).length})'),
          ),
          if (p.status != StockStatus.inStock)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p.status == StockStatus.outOfStock
                    ? 'Out of stock – raise a purchase order.'
                    : 'At or below the reorder level – reorder ${p.reorderQty} ${p.unit}.',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.red),
              ),
            ),
        ],
      ),
    );
  }
}
