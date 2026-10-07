import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/inventory.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/maintenance_repository.dart';

/// Warehouses stock can be transferred to.
const warehouses = ['Main Warehouse', 'Warehouse B', 'Maintenance Store', 'Spares Store (Mezzanine)'];

/// Number field returning an int, with an error.
Widget _intField(TextEditingController c, String label, {String? error, String? suffix}) => TextField(
  controller: c,
  keyboardType: TextInputType.number,
  decoration: InputDecoration(labelText: label, errorText: error, suffixText: suffix),
);

// ---------------------------------------------------------------- Stock Overview → Edit

Future<void> showEditLevelsSheet(BuildContext context, WidgetRef ref, Part p) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _LevelsSheet(part: p),
);

class _LevelsSheet extends ConsumerStatefulWidget {
  const _LevelsSheet({required this.part});

  final Part part;

  @override
  ConsumerState<_LevelsSheet> createState() => _LevelsSheetState();
}

class _LevelsSheetState extends ConsumerState<_LevelsSheet> {
  late final _level = TextEditingController(text: '${widget.part.reorderLevel}');
  late final _qty = TextEditingController(text: '${widget.part.reorderQty}');
  String? _levelError, _qtyError;

  @override
  void dispose() {
    _level.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _save() {
    final level = int.tryParse(_level.text.trim());
    final qty = int.tryParse(_qty.text.trim());
    setState(() {
      _levelError = level == null || level < 0 ? 'Enter a whole number, 0 or more' : null;
      _qtyError = qty == null || qty <= 0
          ? 'Enter a quantity above 0'
          : (level != null && qty <= level ? 'Reorder qty should be more than the reorder level' : null);
    });
    if (_levelError != null || _qtyError != null) return;
    ref.read(inventoryProvider.notifier).updateLevels(widget.part.id, reorderLevel: level, reorderQty: qty);
    Navigator.pop(context);
    context.showSnack('Stock levels updated');
  }

  @override
  Widget build(BuildContext context) => sheetFrame(context, [
    SheetTitle('Edit Stock Levels', subtitle: '${widget.part.id} · current stock ${widget.part.qty}'),
    _intField(_level, 'Reorder level', error: _levelError, suffix: widget.part.unit),
    const SizedBox(height: 12),
    _intField(_qty, 'Reorder quantity', error: _qtyError, suffix: widget.part.unit),
    const SizedBox(height: 16),
    FilledButton(onPressed: _save, child: const Text('Save')),
  ]);
}

// ---------------------------------------------------------------- Location Details → Manage

Future<void> showManageLocationSheet(BuildContext context, WidgetRef ref, Part p) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ManageSheet(part: p),
);

class _ManageSheet extends ConsumerStatefulWidget {
  const _ManageSheet({required this.part});

  final Part part;

  @override
  ConsumerState<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends ConsumerState<_ManageSheet> {
  bool _transfer = false;
  late final _bin = TextEditingController(text: widget.part.bin);
  final _qty = TextEditingController();
  String? _to;
  String? _error;

  @override
  void dispose() {
    _bin.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _save() {
    final p = ref.read(partByIdProvider(widget.part.id))!;
    final n = ref.read(inventoryProvider.notifier);
    if (!_transfer) {
      final bin = _bin.text.trim().toUpperCase();
      if (bin.isEmpty) return setState(() => _error = 'Enter the rack / bin');
      n.updateLocation(p.id, bin: bin);
      Navigator.pop(context);
      context.showSnack('Bin changed to $bin');
      return;
    }
    final qty = int.tryParse(_qty.text.trim());
    final err = qty == null || qty <= 0
        ? 'Enter a quantity'
        : qty > p.available
        ? 'Only ${p.available} available (reserved stock cannot move)'
        : _to == null
        ? 'Choose the destination'
        : null;
    if (err != null) return setState(() => _error = err);
    final refNo = n.transfer(p.id, qty!, to: _to!);
    Navigator.pop(context);
    context.showSnack('$qty × ${p.id} transferred to $_to ($refNo)');
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(partByIdProvider(widget.part.id))!;
    return sheetFrame(context, [
      SheetTitle('Manage Location', subtitle: '${p.warehouse} · ${p.bin}'),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Change Bin'), icon: Icon(Icons.shelves)),
          ButtonSegment(value: true, label: Text('Transfer Stock'), icon: Icon(Icons.swap_horiz_rounded)),
        ],
        selected: {_transfer},
        onSelectionChanged: (s) => setState(() {
          _transfer = s.first;
          _error = null;
        }),
      ),
      const SizedBox(height: 14),
      if (!_transfer)
        TextField(
          controller: _bin,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: 'Rack / Bin', hintText: 'e.g. A-12-04', errorText: _error),
        )
      else ...[
        _intField(_qty, 'Quantity (${p.available} available)', suffix: p.unit),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _to,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Destination warehouse', errorText: _error),
          items: [
            for (final w in warehouses)
              if (w != p.warehouse) DropdownMenuItem(value: w, child: Text(w)),
          ],
          onChanged: (v) => setState(() {
            _to = v;
            _error = null;
          }),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(onPressed: _save, child: Text(_transfer ? 'Transfer' : 'Save')),
    ]);
  }
}

// ---------------------------------------------------------------- ⋮ Issue to Work Order / Stock Count

Future<void> showIssueToWoSheet(BuildContext context, WidgetRef ref, Part p) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _IssueSheet(part: p),
);

class _IssueSheet extends ConsumerStatefulWidget {
  const _IssueSheet({required this.part});

  final Part part;

  @override
  ConsumerState<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends ConsumerState<_IssueSheet> {
  String? _wo;
  final _qty = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _issue() {
    final p = ref.read(partByIdProvider(widget.part.id))!;
    final qty = int.tryParse(_qty.text.trim());
    final err = _wo == null
        ? 'Choose the work order'
        : qty == null || qty <= 0
        ? 'Enter a quantity'
        : qty > p.available
        ? 'Only ${p.available} available'
        : null;
    if (err != null) return setState(() => _error = err);
    ref.read(workOrdersProvider.notifier).issuePart(_wo!, p.id, qty!);
    Navigator.pop(context);
    context.showSnack('$qty × ${p.id} issued to $_wo');
  }

  @override
  Widget build(BuildContext context) {
    final wos = ref.watch(workOrdersProvider).active;
    final p = ref.watch(partByIdProvider(widget.part.id))!;
    return sheetFrame(context, [
      SheetTitle('Issue to Work Order', subtitle: '${p.available} ${p.unit} available'),
      DropdownButtonFormField<String>(
        initialValue: _wo,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Work order'),
        items: [
          for (final w in wos)
            DropdownMenuItem(
              value: w.id,
              child: Text('${w.id} · ${w.title}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() {
          _wo = v;
          _error = null;
        }),
      ),
      const SizedBox(height: 12),
      _intField(_qty, 'Quantity', suffix: p.unit),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_error!, style: AppText.caption.copyWith(color: AppColors.red)),
        ),
      const SizedBox(height: 16),
      FilledButton(onPressed: _issue, child: const Text('Issue')),
    ]);
  }
}

Future<void> showStockCountSheet(BuildContext context, WidgetRef ref, Part p) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _CountSheet(part: p),
);

class _CountSheet extends ConsumerStatefulWidget {
  const _CountSheet({required this.part});

  final Part part;

  @override
  ConsumerState<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends ConsumerState<_CountSheet> {
  late final _count = TextEditingController(text: '${widget.part.qty}');
  final _reason = TextEditingController();
  String? _countError, _reasonError;

  @override
  void dispose() {
    _count.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    final p = ref.read(partByIdProvider(widget.part.id))!;
    final n = int.tryParse(_count.text.trim());
    setState(() {
      _countError = n == null || n < 0
          ? 'Enter the counted quantity'
          : n == p.qty
          ? 'Same as the system stock – nothing to adjust'
          : n < p.reserved
          ? 'At least ${p.reserved} are reserved for work orders'
          : null;
      _reasonError = _reason.text.trim().isEmpty ? 'Give a reason' : null;
    });
    if (_countError != null || _reasonError != null) return;
    ref.read(inventoryProvider.notifier).adjust(p.id, n!, reason: _reason.text.trim());
    Navigator.pop(context);
    context.showSnack('Stock adjusted to $n (${n - p.qty > 0 ? '+' : ''}${n - p.qty})');
  }

  @override
  Widget build(BuildContext context) => sheetFrame(context, [
    SheetTitle('Stock Count Adjustment', subtitle: 'System stock: ${widget.part.qty} ${widget.part.unit}'),
    _intField(_count, 'Counted quantity', error: _countError, suffix: widget.part.unit),
    const SizedBox(height: 12),
    TextField(
      controller: _reason,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Reason',
        hintText: 'e.g. Cycle count, damaged items',
        errorText: _reasonError,
      ),
    ),
    const SizedBox(height: 16),
    FilledButton(onPressed: _save, child: const Text('Adjust Stock')),
  ]);
}

/// Full spec sheet (chevron on the part card).
Future<void> showSpecSheet(BuildContext context, Part p) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) => sheetFrame(sheet, [
    SheetTitle(p.name, subtitle: 'Specification'),
    if (p.imagePath != null)
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(image: photoProvider(p.imagePath!), height: 180, fit: BoxFit.cover),
      ),
    const SizedBox(height: 12),
    for (final (k, v) in [
      ('Part No', p.id),
      ('Category', p.category),
      ('Manufacturer', p.manufacturer),
      ('Description', p.description.isEmpty ? '—' : p.description),
      ('Unit', p.unit),
      ('Unit Cost', '${p.currency} ${p.unitCost.toStringAsFixed(2)}'),
      ('Lead Time', '${p.leadTimeDays} days'),
      ('Preferred Supplier', p.supplier),
      ('Warranty', p.warrantyMonths == 0 ? '—' : '${p.warrantyMonths} months'),
      ('Reorder Level / Qty', '${p.reorderLevel} / ${p.reorderQty}'),
    ])
      InfoRow(label: k, value: v),
  ]),
);
