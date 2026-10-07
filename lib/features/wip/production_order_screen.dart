import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/wip.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/wip_repository.dart';
import 'wip_hub_screen.dart';
import 'wip_widgets.dart';

enum MoTab {
  operations('Operations'),
  components('Components'),
  resources('Resources'),
  quality('Quality'),
  notes('Notes');

  const MoTab(this.label);
  final String label;
}

/// Production Order (right screen of design/13_wip_operations.jpg; the design calls it "Work Order").
class ProductionOrderScreen extends ConsumerStatefulWidget {
  const ProductionOrderScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProductionOrderScreen> createState() => _ProductionOrderScreenState();
}

class _ProductionOrderScreenState extends ConsumerState<ProductionOrderScreen> {
  MoTab _tab = MoTab.operations;
  final _note = TextEditingController();

  WipNotifier get _n => ref.read(wipProvider.notifier);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pause(ProductionOrder o) async {
    const reasons = ['Material shortage', 'Machine breakdown', 'Quality hold', 'Operator unavailable'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => sheetFrame(sheet, [
        SheetTitle('Pause ${o.id}', subtitle: 'Why is the order on hold?'),
        for (final r in reasons)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.pause_circle_outline_rounded, color: AppColors.amber),
            title: Text(r),
            onTap: () => Navigator.pop(sheet, r),
          ),
      ]),
    );
    if (reason == null || !mounted) return;
    _n.pause(o.id, reason);
    context.showSnack('${o.id} on hold – $reason');
  }

  Future<void> _complete(ProductionOrder o) async {
    if (!o.allOpsDone) {
      final done = o.operations.where((x) => x.isDone).length;
      context.showSnack('Finish every operation first ($done of ${o.operations.length} done)');
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Complete ${o.id}?',
      message: 'All ${o.plannedQty} units are recorded as completed and the order moves to Completed.',
      confirmLabel: 'Complete',
    );
    if (!ok || !mounted) return;
    _n.completeOrder(o.id);
    await showSuccessSheet(context, title: '${o.id} completed', message: '${o.product} · ${o.plannedQty} units');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final o = ref.watch(wipProvider).order(widget.id);
    if (o == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Order not found', message: widget.id),
      );
    }
    final onHold = o.status == MoStatus.onHold;
    return AppScaffold(
      bottomActions: !o.isActive
          ? null
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onHold
                        ? () {
                            _n.resume(o.id);
                            context.showSnack('${o.id} resumed');
                          }
                        : () => _pause(o),
                    icon: Icon(onHold ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
                    label: Text(onHold ? 'Resume' : 'Pause WO'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: o.allOpsDone
                        ? null
                        : FilledButton.styleFrom(
                            backgroundColor: AppColors.greyBg,
                            foregroundColor: AppColors.textMuted,
                          ),
                    onPressed: () => _complete(o),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Complete Work Order')),
                  ),
                ),
              ],
            ),
      body: ListView(
        padding: o.isActive ? const EdgeInsets.fromLTRB(16, 16, 16, 24) : context.pagePadding,
        children: [
          const PageTitle(
            title: 'Production Order',
            subtitle: 'Execute and track manufacturing operations',
            help:
                'Start each operation in sequence. Pause / End the running one. Complete the order when every '
                'operation is done.',
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                AssetThumb(imagePath: o.imagePath, fallbackIcon: Icons.precision_manufacturing_outlined, size: 76),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                      Text(o.product, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                      const SizedBox(height: 4),
                      StatusChip(o.status, tone: moTone(o.status)),
                      const SizedBox(height: 4),
                      InfoRow(label: 'Customer', value: o.customer, labelWidth: 84),
                      InfoRow(label: 'Planned Qty', value: '${o.plannedQty} Units', labelWidth: 84),
                      InfoRow(label: 'Completed Qty', value: '${o.completedQty} Units', labelWidth: 84),
                      InfoRow(label: 'Due Date', value: DemoClock.formatDate(o.dueDate), labelWidth: 84),
                      if (o.holdReason != null)
                        InfoRow(label: 'On hold', value: o.holdReason!, valueColor: AppColors.amber, labelWidth: 84),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ProgressRing(
                      value: o.progress,
                      size: 76,
                      strokeWidth: 9,
                      color: AppColors.green,
                      center: Text('${(o.progress * 100).round()}%', style: AppText.bodyStrong),
                    ),
                    const SizedBox(height: 4),
                    Text('Progress', style: AppText.caption),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.push(Routes.wipUnit(o.unitSerial)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: IconLine(
                icon: Icons.qr_code_2_rounded,
                text: 'Unit ${o.unitSerial} at ${o.currentStation} – open WIP Tracking',
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SegmentTabs(
            tabs: [for (final t in MoTab.values) SegmentTab(t.label)],
            selected: _tab.index,
            onChanged: (i) => setState(() => _tab = MoTab.values[i]),
          ),
          const SizedBox(height: 12),
          if (_tab == MoTab.notes)
            _notes(o)
          else
            LoadingGate(
              key: ValueKey(_tab),
              rows: 4,
              card: false,
              child: switch (_tab) {
                MoTab.operations => _operations(o),
                MoTab.components => _components(o),
                MoTab.resources => _resources(o),
                _ => _quality(o),
              },
            ),
        ],
      ),
    );
  }

  Widget _operations(ProductionOrder o) {
    final next = o.nextStartIndex;
    final blocked = o.status == MoStatus.onHold || !o.isActive;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < o.operations.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _opRow(o, i, canStart: i == next && !blocked, blocked: blocked),
          ],
        ],
      ),
    );
  }

  Widget _opRow(ProductionOrder o, int i, {required bool canStart, required bool blocked}) {
    final op = o.operations[i];
    final when = op.completedAt ?? op.startedAt;
    Widget button;
    if (op.isDone) {
      button = OutlinedButton(onPressed: () => _viewOp(o, i), child: const Text('View'));
    } else if (op.status == OpStatus.failed) {
      button = FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.red),
        onPressed: blocked
            ? null
            : () {
                _n.rework(o.id, i);
                context.showSnack('Rework started on ${op.name}');
              },
        child: const Text('Rework'),
      );
    } else if (op.isRunning) {
      button = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: blocked
                ? null
                : () {
                    if (op.status == OpStatus.paused) {
                      _n.resumeOperation(o.id, i);
                      context.showSnack('${op.name} resumed');
                    } else {
                      _n.pauseOperation(o.id, i);
                      context.showSnack('${op.name} paused');
                    }
                  },
            child: Text(op.status == OpStatus.paused ? 'Resume' : 'Pause'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(56, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: blocked ? null : () => showEndOperationSheet(context, ref, o, i),
            child: const Text('End'),
          ),
        ],
      );
    } else {
      button = FilledButton(
        onPressed: canStart
            ? () {
                _n.startOperation(o.id, i);
                context.showSnack('${op.name} started');
              }
            : null,
        child: const Text('Start'),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: op.isDone
                  ? AppColors.green
                  : op.status == OpStatus.failed
                  ? AppColors.red
                  : op.isRunning
                  ? AppColors.primary
                  : AppColors.textMuted,
            ),
            child: op.isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    '${i + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                StatusChip(op.status),
                const SizedBox(height: 3),
                if (when != null) IconLine(icon: Icons.event_rounded, text: DemoClock.formatDateTime(when)),
                Text(
                  op.status == OpStatus.pending
                      ? 'Est. Duration: ${op.expectedMins} mins'
                      : 'Duration: ${liveMinutes(op)} mins',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          button,
        ],
      ),
    );
  }

  void _viewOp(ProductionOrder o, int i) {
    final op = o.operations[i];
    final operator = ref.read(personByIdProvider(op.operatorId));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => sheetFrame(sheet, [
        SheetTitle(op.name, subtitle: op.location),
        InfoRow(label: 'Status', value: op.status),
        InfoRow(label: 'Started', value: op.startedAt == null ? '—' : DemoClock.formatDateTime(op.startedAt!)),
        InfoRow(label: 'Completed', value: op.completedAt == null ? '—' : DemoClock.formatDateTime(op.completedAt!)),
        InfoRow(label: 'Duration', value: '${op.actualMins ?? op.expectedMins} min (standard ${op.expectedMins})'),
        InfoRow(label: 'Operator', value: operator?.labelWithRole ?? '—'),
        if (op.goodQty != null) InfoRow(label: 'Good / Scrap', value: '${op.goodQty} / ${op.scrapQty ?? 0}'),
        InfoRow(label: 'Quality check', value: op.qcPassed == null ? '—' : (op.qcPassed! ? 'Passed' : 'Failed')),
      ]),
    );
  }

  Widget _components(ProductionOrder o) {
    final inv = ref.watch(inventoryProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, c) in o.components.indexed) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: Icon(
                c.outstanding == 0 ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                color: c.outstanding == 0 ? AppColors.green : AppColors.primary,
              ),
              title: Text(c.name, style: AppText.bodyStrong),
              subtitle: Text(
                [
                  'Required ${c.required} · Issued ${c.issued}',
                  if (c.partId != null) '${c.partId} · ${inv.part(c.partId!)?.available ?? 0} available',
                ].join('\n'),
                style: AppText.caption,
              ),
              isThreeLine: c.partId != null,
              onTap: c.partId == null ? null : () => context.push(Routes.partDetail(c.partId!)),
              trailing: c.outstanding == 0 || !o.isActive
                  ? null
                  : TextButton(
                      onPressed: () {
                        final qty = _n.issueComponent(o.id, i);
                        context.showSnack(
                          qty == 0 ? 'No ${c.name} available in stock' : '$qty × ${c.name} issued from Inventory',
                        );
                      },
                      child: const Text('Issue from\nInventory', textAlign: TextAlign.center),
                    ),
            ),
          ],
          if (o.components.isEmpty)
            const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No bill of materials',
              message: 'This order has no components to issue.',
            ),
        ],
      ),
    );
  }

  Widget _resources(ProductionOrder o) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final op in o.operations)
            ListTile(
              leading: Icon(Icons.precision_manufacturing_outlined, color: AppColors.primary),
              title: Text(op.location, style: AppText.bodyStrong),
              subtitle: Text(
                '${op.name} · ${ref.watch(personByIdProvider(op.operatorId))?.name ?? 'Operator not assigned yet'}',
                style: AppText.caption,
              ),
              trailing: StatusChip(op.status),
            ),
        ],
      ),
    );
  }

  Widget _quality(ProductionOrder o) {
    final fpy = o.firstPassYield;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              ProgressRing(
                value: fpy ?? 0,
                size: 64,
                strokeWidth: 8,
                color: (fpy ?? 0) >= .95 ? AppColors.green : AppColors.amber,
                center: Text(fpy == null ? '—' : '${(fpy * 100).toStringAsFixed(1)}%', style: AppText.caption),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'First-pass yield: good units ÷ (good + scrap) over the operations that recorded quantities.',
                  style: AppText.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (o.quality.isEmpty)
                const EmptyState(
                  icon: Icons.verified_outlined,
                  title: 'No checks yet',
                  message: 'Quality results appear when operations end.',
                ),
              for (final q in o.quality.reversed)
                ListTile(
                  leading: Icon(
                    q.passed ? Icons.verified_rounded : Icons.report_rounded,
                    color: q.passed ? AppColors.green : AppColors.red,
                  ),
                  title: Text(q.operation, style: AppText.bodyStrong),
                  subtitle: Text(
                    [DemoClock.formatDateTime(q.at), ?q.by, if (q.note != null) 'Finding: ${q.note}'].join(' · '),
                    style: AppText.caption,
                  ),
                  trailing: StatusChip(q.passed ? 'Passed' : 'Failed', tone: q.passed ? ChipTone.green : ChipTone.red),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notes(ProductionOrder o) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Add a note'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Add note',
              onPressed: () {
                final t = _note.text.trim();
                if (t.isEmpty) {
                  context.showSnack('Type a note first');
                  return;
                }
                _n.addNote(o.id, t);
                _note.clear();
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (o.notes.isEmpty)
                const EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'No notes yet',
                  message: 'Notes you add appear here with your name and time.',
                ),
              for (final n in o.notes.reversed)
                ListTile(
                  leading: Icon(Icons.sticky_note_2_outlined, color: AppColors.primary),
                  title: Text(n.title, style: AppText.body),
                  subtitle: Text([DemoClock.formatDateTime(n.at), ?n.by].join(' · '), style: AppText.caption),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
