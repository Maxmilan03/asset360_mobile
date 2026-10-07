import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/data/models/wip.dart';
import 'package:asset360_mobile/data/repositories/wip_repository.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/features/work/wip/wip_widgets.dart';

enum WipView { all, inProcess, completed, delayed, onHold }

/// WIP / Operations hub (left screen of design/13_wip_operations.jpg).
class WipHubScreen extends ConsumerStatefulWidget {
  const WipHubScreen({super.key, this.initialView});

  final String? initialView;

  @override
  ConsumerState<WipHubScreen> createState() => _WipHubScreenState();
}

class _WipHubScreenState extends ConsumerState<WipHubScreen> {
  late WipView _view = WipView.values.firstWhere((v) => v.name == widget.initialView, orElse: () => WipView.all);
  String _query = '';
  FilterSelection _filters = const {};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(WipHubScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialView != old.initialView) {
      _view = WipView.values.firstWhere((v) => v.name == widget.initialView, orElse: () => _view);
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> _scanToMove() async {
    final wip = ref.read(wipProvider);
    final code = await showScanCapture(
      context,
      title: 'Scan Unit / Serial',
      suggestions: [for (final o in wip.active) o.unitSerial],
    );
    if (code == null || !mounted) return;
    final o = ref.read(wipProvider).byUnit(code);
    if (o == null) {
      context.showSnack('No unit in production matches "$code"');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Consumer(
        builder: (sheet, ref, _) {
          final mo = ref.watch(wipProvider).order(o.id)!;
          final i = mo.currentOpIndex;
          final next = i >= 0 && i + 1 < mo.operations.length ? mo.operations[i + 1] : null;
          return sheetFrame(sheet, [
            SheetTitle(mo.unitSerial, subtitle: '${mo.id} · ${mo.product}'),
            InfoRow(label: 'Current station', value: mo.currentStation),
            InfoRow(label: 'Operation', value: i < 0 ? '—' : '${mo.operations[i].name} (${mo.operations[i].status})'),
            InfoRow(label: 'Next station', value: next?.location ?? (i < 0 ? '—' : 'Last operation')),
            const SizedBox(height: 10),
            StationProgress(operations: mo.operations),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(sheet);
                await moveToNextFlow(context, ref, mo);
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Move to next station'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(sheet);
                context.push(Routes.wipUnit(mo.unitSerial));
              },
              child: const Text('Open WIP Tracking'),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _startOperation() async {
    final list = ref.read(wipProvider).startable;
    final picked = await showModalBottomSheet<ProductionOrder>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => sheetFrame(sheet, [
        const SheetTitle('Start Operation', subtitle: 'Orders whose next operation is ready'),
        if (list.isEmpty) Text('Nothing to start – every order has an operation running.', style: AppText.secondary),
        for (final o in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_rounded, color: AppColors.green, size: 32),
            title: Text('${o.id} · ${o.operations[o.nextStartIndex].name}', style: AppText.bodyStrong),
            subtitle: Text('${o.product} · ${o.operations[o.nextStartIndex].location}', style: AppText.caption),
            onTap: () => Navigator.pop(sheet, o),
          ),
      ]),
    );
    if (picked == null || !mounted) return;
    final op = picked.operations[picked.nextStartIndex];
    ref.read(wipProvider.notifier).startOperation(picked.id, picked.nextStartIndex);
    context.showSnack('${op.name} started for ${picked.id}');
  }

  Future<void> _endOperation() async {
    final list = ref.read(wipProvider).running;
    final picked = await showModalBottomSheet<ProductionOrder>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => sheetFrame(sheet, [
        const SheetTitle('End Operation', subtitle: 'Running operations'),
        if (list.isEmpty) Text('No operation is running.', style: AppText.secondary),
        for (final o in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop_circle_rounded, color: AppColors.red, size: 32),
            title: Text('${o.id} · ${o.operations[o.currentOpIndex].name}', style: AppText.bodyStrong),
            subtitle: Text(
              '${o.operations[o.currentOpIndex].location} · ${liveMinutes(o.operations[o.currentOpIndex])} min',
              style: AppText.caption,
            ),
            onTap: () => Navigator.pop(sheet, o),
          ),
      ]),
    );
    if (picked == null || !mounted) return;
    await showEndOperationSheet(context, ref, picked, picked.currentOpIndex);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final wip = ref.watch(wipProvider);
    final s = wip.summary;
    final lists = {
      WipView.all: wip.active,
      WipView.inProcess: wip.withStatus(MoStatus.inProcess),
      WipView.completed: wip.withStatus(MoStatus.completed),
      WipView.delayed: wip.withStatus(MoStatus.delayed),
      WipView.onHold: wip.withStatus(MoStatus.onHold),
    };
    final totals = {
      WipView.all: s.allWip,
      WipView.inProcess: s.inProcess,
      WipView.completed: s.completedToday,
      WipView.delayed: s.delayed,
      WipView.onHold: s.onHold,
    };
    final q = _query.trim().toLowerCase();
    final rows = lists[_view]!
        .where(
          (o) =>
              (q.isEmpty ||
                  '${o.id} ${o.product} ${o.unitSerial} ${o.currentStation} ${o.locationPath}'.toLowerCase().contains(
                    q,
                  )) &&
              (_filters['Status']?.contains(o.status) ?? true) &&
              (_filters['Area']?.contains(o.area) ?? true),
        )
        .toList();
    final kpis = [
      (WipView.all, Icons.settings_suggest_rounded, 'WIP in Process', s.allWip, TileTone.sky),
      (WipView.completed, Icons.check_circle_rounded, 'Completed Today', s.completedToday, TileTone.mint),
      (WipView.delayed, Icons.schedule_rounded, 'Delayed', s.delayed, TileTone.pink),
      (WipView.onHold, Icons.pause_circle_rounded, 'On Hold', s.onHold, TileTone.peach),
    ];
    final actions = [
      (Icons.qr_code_scanner_rounded, 'Scan to Move', TileTone.lavender, _scanToMove),
      (Icons.play_circle_rounded, 'Start Operation', TileTone.mint, _startOperation),
      (Icons.stop_circle_rounded, 'End Operation', TileTone.pink, _endOperation),
      (
        Icons.warning_rounded,
        'Report Issue',
        TileTone.peach,
        () {
          final o = wip.running.isEmpty ? null : wip.running.first;
          if (o == null) {
            context.push(Routes.reportIssue);
          } else {
            reportProductionIssue(context, o);
          }
        },
      ),
    ];
    return AppScaffold(
      body: LazyListPage(
        header: [
          PageTitle(
            title: 'WIP / Operations',
            subtitle: 'Track production flow, WIP assets and operations in real-time',
            help:
                'Production orders use MO- numbers. Plant figures (${s.allWip} WIP, ${s.inProcess} in process …) are '
                'summary totals; the list shows sample orders. Start, end and move operations to drive an order to '
                'completion.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (n, (v, icon, label, value, tone)) in kpis.indexed) ...[
                if (n > 0) const SizedBox(width: 8),
                Expanded(
                  child: KpiTile(
                    icon: icon,
                    value: '$value',
                    label: label,
                    tone: tone,
                    onTap: () => setState(() => _view = v),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (n, (icon, label, tone, onTap)) in actions.indexed) ...[
                if (n > 0) const SizedBox(width: 8),
                Expanded(
                  child: ActionTile(icon: icon, label: label, tone: tone, height: 82, labelSize: 11.5, onTap: onTap),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SegmentTabs(
            tabs: [
              SegmentTab('All WIP', count: s.allWip),
              SegmentTab('In Process', count: s.inProcess),
              SegmentTab('Completed', count: s.completedToday),
              SegmentTab('Delayed', count: s.delayed),
            ],
            selected: _view == WipView.onHold ? -1 : _view.index,
            onChanged: (i) => setState(() => _view = WipView.values[i]),
          ),
          if (_view == WipView.onHold) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                InputChip(
                  label: Text('On Hold (${s.onHold})'),
                  onDeleted: () => setState(() => _view = WipView.all),
                  deleteButtonTooltipMessage: 'Show all',
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search by Order No., Product, Serial No. or Location...',
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            filterGroups: [
              const FilterGroup(
                title: 'Status',
                options: [MoStatus.inProcess, MoStatus.delayed, MoStatus.onHold, MoStatus.completed],
              ),
              FilterGroup(title: 'Area', options: {for (final o in wip.orders) o.area}.toList()),
            ],
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 12),
        ],
        list: SliverLoadingGate(
          rows: 4,
          sliver: rows.isEmpty
              ? SliverToBoxAdapter(
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.precision_manufacturing_outlined,
                      title: 'No orders match',
                      message: q.isEmpty && _filters.isEmpty
                          ? 'No production orders in this view.'
                          : 'Try another order number, product, serial or filter.',
                      actionLabel: q.isEmpty && _filters.isEmpty ? null : 'Clear filters',
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
                  indent: 88,
                  itemBuilder: (_, i) => MoRow(order: rows[i]),
                ),
        ),
        footer: [
          const SizedBox(height: 8),
          Text('Showing ${rows.length} of ${totals[_view]}', textAlign: TextAlign.center, style: AppText.caption),
        ],
      ),
    );
  }
}

/// End an operation: good / scrap quantities and the quality result.
Future<void> showEndOperationSheet(BuildContext context, WidgetRef ref, ProductionOrder o, int index) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EndSheet(order: o, index: index),
    );

class _EndSheet extends ConsumerStatefulWidget {
  const _EndSheet({required this.order, required this.index});

  final ProductionOrder order;
  final int index;

  @override
  ConsumerState<_EndSheet> createState() => _EndSheetState();
}

class _EndSheetState extends ConsumerState<_EndSheet> {
  late final _good = TextEditingController(text: '${widget.order.plannedQty - widget.order.completedQty}');
  final _scrap = TextEditingController(text: '0');
  bool _passed = true;
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _good.dispose();
    _scrap.dispose();
    _note.dispose();
    super.dispose();
  }

  void _end() {
    final good = int.tryParse(_good.text.trim());
    final scrap = int.tryParse(_scrap.text.trim());
    final err = good == null || good < 0 || scrap == null || scrap < 0
        ? 'Enter whole numbers'
        : good + scrap == 0
        ? 'Enter the quantities processed'
        : !_passed && _note.text.trim().isEmpty
        ? 'Describe the quality failure'
        : null;
    if (err != null) return setState(() => _error = err);
    final op = widget.order.operations[widget.index];
    ref
        .read(wipProvider.notifier)
        .endOperation(
          widget.order.id,
          widget.index,
          good: good,
          scrap: scrap,
          qcPassed: _passed,
          note: _passed ? null : _note.text.trim(),
        );
    Navigator.pop(context);
    context.showSnack('${op.name} ended · $good good, $scrap scrap${_passed ? '' : ' · QC failed'}');
  }

  @override
  Widget build(BuildContext context) {
    final op = widget.order.operations[widget.index];
    return sheetFrame(context, [
      SheetTitle('End ${op.name}', subtitle: '${widget.order.id} · ${op.location} · ${liveMinutes(op)} min'),
      FieldPair(
        TextField(
          controller: _good,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Good qty'),
        ),
        TextField(
          controller: _scrap,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Scrap qty'),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Passed quality check'),
        value: _passed,
        onChanged: (v) => setState(() => _passed = v),
      ),
      if (!_passed)
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'What failed?'),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_error!, style: AppText.caption.copyWith(color: AppColors.red)),
        ),
      const SizedBox(height: 16),
      FilledButton(onPressed: _end, child: const Text('End Operation')),
    ]);
  }
}
