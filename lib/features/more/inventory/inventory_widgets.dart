import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/inventory.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';

/// Stock chip: In Stock green / Low Stock amber / Out of Stock red (computed from qty vs reorder level).
ChipTone stockTone(String status) => switch (status) {
  StockStatus.inStock => ChipTone.green,
  StockStatus.lowStock => ChipTone.amber,
  _ => ChipTone.red,
};

String money(double v, [String currency = 'USD']) => '$currency ${v.toStringAsFixed(2)}';

/// Inventory list row: photo, name, part no., category, warehouse, stock chip and qty.
class PartRow extends StatelessWidget {
  const PartRow({super.key, required this.part, this.onTap});

  final Part part;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = part;
    return AssetListTile(
      title: p.name,
      subtitle: 'Part No: ${p.id}',
      imagePath: p.imagePath,
      fallbackIcon: Icons.settings_outlined,
      details: [
        Text('Category: ${p.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
        IconLine(icon: Icons.location_on_outlined, text: p.warehouse),
      ],
      trailingTop: StatusChip(p.status, tone: stockTone(p.status)),
      trailingBottom: 'Qty: ${p.qty}',
      onTap: onTap ?? () => context.push(Routes.partDetail(p.id)),
    );
  }
}

/// Camera icon before the Part Details / Stock Movement title: scans a part label and opens that part.
class ScanPartButton extends ConsumerWidget {
  const ScanPartButton({super.key, this.currentPartId});

  /// The part already on screen (scanning it again just says so).
  final String? currentPartId;

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final inv = ref.read(inventoryProvider);
    final code = await showScanCapture(
      context,
      title: 'Scan Part Label',
      suggestions: [
        ?currentPartId,
        for (final p in inv.parts.take(3))
          if (p.id != currentPartId) p.id,
      ],
    );
    if (code == null || !context.mounted) return;
    final c = code.trim().toUpperCase();
    final part = ref.read(inventoryProvider).parts.where((p) => p.id.toUpperCase() == c).firstOrNull;
    if (part == null) {
      context.showSnack('No spare part matches "$code"');
    } else if (part.id == currentPartId) {
      context.showSnack('${part.id} · ${part.name} – this part is already open');
    } else {
      context.push(Routes.partDetail(part.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => DemoGuard(
    action: DemoAction.partScanLabel,
    child: IconButton(
      tooltip: 'Scan part label',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => _scan(context, ref),
      icon: Icon(Icons.camera_alt_outlined, color: AppColors.text, size: 22),
    ),
  );
}

/// Part header card (Part Details, Stock Movement): photo, name, stock chip and key facts.
class PartCard extends StatelessWidget {
  const PartCard({super.key, required this.part, this.onTap, this.compact = false});

  final Part part;
  final VoidCallback? onTap;

  /// Stock Movement shows only part no. and category.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = part;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AssetThumb(imagePath: p.imagePath, fallbackIcon: Icons.settings_outlined, size: compact ? 72 : 92),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                    ),
                    Flexible(child: StatusChip(p.status, tone: stockTone(p.status))),
                  ],
                ),
                const SizedBox(height: 4),
                InfoRow(label: 'Part No', value: p.id, labelWidth: 84),
                InfoRow(label: 'Category', value: p.category, labelWidth: 84),
                if (!compact) ...[
                  InfoRow(label: 'Unit', value: p.unit, labelWidth: 84),
                  InfoRow(label: 'Manufacturer', value: p.manufacturer, labelWidth: 84),
                  InfoRow(label: 'Description', value: p.description, labelWidth: 84),
                ],
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// Icon and colour per ledger entry type.
(IconData, ChipTone) txnLook(String type) => switch (type) {
  TxnType.received || TxnType.returned => (Icons.add_circle_rounded, ChipTone.green),
  TxnType.issued || TxnType.issuedToWo || TxnType.issuedToProduction => (Icons.remove_circle_rounded, ChipTone.red),
  TxnType.transferred => (Icons.swap_horizontal_circle_rounded, ChipTone.blue),
  TxnType.reserved => (Icons.build_circle_rounded, ChipTone.orange),
  TxnType.released => (Icons.lock_open_rounded, ChipTone.purple),
  _ => (Icons.tune_rounded, ChipTone.grey),
};

/// The tap on a ledger reference, or null when the client demo keeps it inert
/// (only REF: WO-… links are allowed; GRN / PO / TR stay inert).
VoidCallback? stockRefTap(BuildContext context, WidgetRef ref, String reference) {
  final allowed = reference.startsWith('WO-')
      ? demoCanDo(DemoAction.stockRefLinks) && demoCanOpen(Routes.workOrder(reference))
      : reference.startsWith('PO-')
      ? demoCanOpen(Routes.purchaseOrder(reference))
      : demoCanDo(DemoAction.stockOtherRefs);
  return allowed ? () => openStockRef(context, ref, reference) : null;
}

/// Opens what a ledger reference points at: WO detail, PO detail or the goods receipt.
void openStockRef(BuildContext context, WidgetRef ref, String reference) {
  if (reference.startsWith('WO-')) {
    context.push(Routes.workOrder(reference));
  } else if (reference.startsWith('PO-')) {
    context.push(Routes.purchaseOrder(reference));
  } else if (reference.startsWith('GRN-')) {
    showGrnSheet(context, ref, reference);
  } else {
    context.showSnack('$reference is an internal stock reference');
  }
}

/// Goods receipt view.
Future<void> showGrnSheet(BuildContext context, WidgetRef ref, String grn) {
  final inv = ref.read(inventoryProvider);
  final t = inv.grn(grn);
  final part = t == null ? null : inv.part(t.partId);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => sheetFrame(sheet, [
      SheetTitle('Goods Receipt $grn', subtitle: t == null ? 'Not found' : DemoClock.formatDateTime(t.at)),
      if (t != null) ...[
        InfoRow(label: 'Part', value: '${t.partId} · ${part?.name ?? ''}'),
        InfoRow(label: 'Quantity received', value: '+${t.qtyChange} ${part?.unit ?? ''}'),
        InfoRow(label: 'Supplier', value: t.from ?? '—'),
        InfoRow(label: 'Purchase order', value: t.po ?? '—'),
        InfoRow(label: 'Received into', value: part?.warehouse ?? '—'),
        InfoRow(label: 'Balance after', value: '${t.balanceAfter}'),
        if (t.po != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(sheet);
              context.push(Routes.purchaseOrder(t.po!));
            },
            child: Text('Open ${t.po}'),
          ),
        ],
      ],
    ]),
  );
}

/// Stock history entry: type icon, title, REF (link), From / To / Asset, time, signed qty and running balance.
class TxnRow extends ConsumerWidget {
  const TxnRow({super.key, required this.txn, this.showPart = false});

  final StockTxn txn;
  final bool showPart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = txn;
    final (icon, tone) = txnLook(t.type);
    final reservation = t.qtyChange == 0 && t.reservedChange != 0;
    final amount = reservation ? t.reservedChange : t.qtyChange;
    final sign = amount > 0 ? '+ ' : (amount < 0 ? '- ' : '');
    final amountColor = reservation ? AppColors.orange : (amount >= 0 ? AppColors.green : AppColors.red);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: tone.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                ),
                if (showPart) Text(t.partId, style: AppText.caption.copyWith(color: AppColors.primary)),
                InkWell(
                  onTap: stockRefTap(context, ref, t.ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'REF: ${t.ref}',
                      style: AppText.caption.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                if (t.from != null)
                  Text('From:  ${t.from}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                if (t.to != null)
                  Text('To:  ${t.to}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                if (t.po != null && !t.ref.startsWith('PO-'))
                  Text('PO:  ${t.po}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                if (t.assetId != null)
                  Text('Asset:  ${t.assetId}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                if (t.remarks != null) Text(t.remarks!, style: AppText.caption.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(DemoClock.formatDateTime(t.at), style: AppText.caption.copyWith(fontSize: 10.5)),
              const SizedBox(height: 6),
              Text(
                reservation ? '$sign${amount.abs()} reserved' : '$sign${amount.abs()}',
                style: AppText.cardTitle.copyWith(color: amountColor, fontSize: reservation ? 13 : 17),
              ),
              const SizedBox(height: 4),
              Text('Balance: ${t.balanceAfter}', style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

/// PO / request status chip colours.
ChipTone requestTone(String status) => switch (status) {
  RequestStatus.received || RequestStatus.approved => ChipTone.green,
  RequestStatus.open => ChipTone.blue,
  RequestStatus.pending => ChipTone.amber,
  _ => ChipTone.grey,
};
