import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/wip.dart';
import '../../data/repositories/wip_repository.dart';
import '../issues/report_issue_screen.dart';

/// MO status chip colours.
ChipTone moTone(String s) => switch (s) {
  MoStatus.completed => ChipTone.green,
  MoStatus.delayed => ChipTone.red,
  MoStatus.onHold => ChipTone.amber,
  MoStatus.queued => ChipTone.grey,
  _ => ChipTone.blue,
};

/// Circles joined by lines: done = filled violet ✓, current = ring, failed = red !, pending = grey.
class StationProgress extends StatelessWidget {
  const StationProgress({super.key, required this.operations, this.size = 18, this.showTimes = false});

  final List<Operation> operations;
  final double size;

  /// Shows the start / completion time under each label (WIP Tracking flow).
  final bool showTimes;

  @override
  Widget build(BuildContext context) {
    final ops = operations;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ops.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Container(height: 2, color: ops[i - 1].isDone ? AppColors.primary : AppColors.border),
                    ),
                    _dot(ops[i]),
                    Expanded(
                      child: i == ops.length - 1
                          ? const SizedBox.shrink()
                          : Container(height: 2, color: ops[i].isDone ? AppColors.primary : AppColors.border),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ops[i].station,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    fontSize: 10,
                    color: ops[i].isRunning ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: ops[i].isRunning ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (showTimes && (ops[i].completedAt ?? ops[i].startedAt) != null)
                  Text(
                    '${DemoClock.formatShort(ops[i].completedAt ?? ops[i].startedAt!)}\n'
                    '${DemoClock.formatTime(ops[i].completedAt ?? ops[i].startedAt!)}',
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(fontSize: 9.5),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(Operation o) {
    final s = size;
    return switch (o.status) {
      OpStatus.completed => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: s * .7, color: Colors.white),
      ),
      OpStatus.failed => Container(
        width: s,
        height: s,
        decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
        child: Icon(Icons.priority_high_rounded, size: s * .7, color: Colors.white),
      ),
      OpStatus.inProgress || OpStatus.paused => Container(
        width: s,
        height: s,
        padding: EdgeInsets.all(s * .22),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: o.status == OpStatus.paused ? AppColors.amber : AppColors.primary, width: 2),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: o.status == OpStatus.paused ? AppColors.amber : AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
      _ => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.greyBg,
          border: Border.all(color: AppColors.border, width: 2),
        ),
      ),
    };
  }
}

/// Hub row: photo, MO number, status chip, product, serial, current station and the mini progress bar.
class MoRow extends StatelessWidget {
  const MoRow({super.key, required this.order});

  final ProductionOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return InkWell(
      onTap: () => context.push(Routes.productionOrder(o.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
        child: Row(
          children: [
            AssetThumb(imagePath: o.imagePath, fallbackIcon: Icons.precision_manufacturing_outlined, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          o.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.cardTitle.copyWith(fontSize: 14.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(o.status, tone: moTone(o.status)),
                    ],
                  ),
                  Text(
                    o.product,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 12.5),
                  ),
                  InkWell(
                    onTap: () => context.push(Routes.wipUnit(o.unitSerial)),
                    child: Text(
                      'Serial No:  ${o.unitSerial}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: AppColors.primary),
                    ),
                  ),
                  Text(
                    'Current Station:  ${o.currentStation}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                  StationProgress(operations: o.operations, size: 16),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// "Move to Next Operation": confirm, then "Passed quality check?". A failed check marks the step red,
/// records a quality finding and makes the order Delayed.
Future<void> moveToNextFlow(BuildContext context, WidgetRef ref, ProductionOrder o) async {
  final i = o.currentOpIndex;
  if (i < 0) {
    context.showSnack(o.allOpsDone ? 'All operations are done – complete the order' : 'Start the next operation first');
    return;
  }
  final op = o.operations[i];
  if (op.status == OpStatus.failed) {
    context.showSnack('${op.name} failed its quality check – start rework from the Production Order');
    return;
  }
  final next = i + 1 < o.operations.length ? o.operations[i + 1] : null;
  final ok = await showConfirmDialog(
    context,
    title: 'Move ${o.unitSerial}?',
    message: next == null
        ? 'Complete ${op.name} (the last operation).'
        : 'Complete ${op.name} at ${op.location} and start ${next.name} at ${next.location}.',
    confirmLabel: 'Move',
  );
  if (!ok || !context.mounted) return;
  final passed = await showDialog<String?>(
    context: context,
    useRootNavigator: false,
    builder: (_) => const _QcDialog(),
  );
  if (passed == null || !context.mounted) return;
  final failed = passed != 'pass';
  ref.read(wipProvider.notifier).moveToNext(o.id, qcPassed: !failed, note: failed ? passed : null);
  context.showSnack(
    failed
        ? 'Quality check failed – ${op.name} marked red and a finding recorded'
        : next == null
        ? '${op.name} completed – the order can now be completed'
        : '${o.unitSerial} moved to ${next.location}',
  );
}

/// Returns 'pass', or the failure note.
class _QcDialog extends StatefulWidget {
  const _QcDialog();

  @override
  State<_QcDialog> createState() => _QcDialogState();
}

class _QcDialogState extends State<_QcDialog> {
  bool _failing = false;
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Passed quality check?'),
      content: _failing
          ? TextField(
              controller: _note,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(hintText: 'What failed? (required)', errorText: _error),
            )
          : const Text('Confirm the unit passed the quality check for this operation.'),
      actions: _failing
          ? [
              TextButton(onPressed: () => setState(() => _failing = false), child: const Text('Back')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: () {
                  final t = _note.text.trim();
                  if (t.isEmpty) return setState(() => _error = 'Describe the failure');
                  Navigator.pop(context, t);
                },
                child: const Text('Record Failure'),
              ),
            ]
          : [
              TextButton(onPressed: () => setState(() => _failing = true), child: const Text('No')),
              FilledButton(onPressed: () => Navigator.pop(context, 'pass'), child: const Text('Yes')),
            ],
    );
  }
}

/// Report Issue with the MO / unit attached; type defaults to Production.
void reportProductionIssue(BuildContext context, ProductionOrder o) => context.push(
  Routes.reportIssue,
  extra: IssuePrefill(
    reference: o.id,
    type: 'Production',
    title: '${o.product} – issue at ${o.currentStation}',
    description: 'Unit ${o.unitSerial} (${o.id}) at ${o.currentStation}. ',
    location: o.locationPath,
  ),
);
