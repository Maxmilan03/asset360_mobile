import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/work_order.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/session_repository.dart';

/// "Complete all tasks first (2 of 6 done)".
String tasksFirstMessage(WorkOrder wo) => 'Complete all tasks first (${wo.tasksDone} of ${wo.tasks.length} done)';

/// Changes the status with the rules of the WO: On Hold needs a reason, Completed needs every task done,
/// Closed runs the close-out. [comment] is logged with the change.
Future<void> changeWoStatus(BuildContext context, WidgetRef ref, WorkOrder wo, String status, {String? comment}) async {
  if (status == wo.status) return;
  if (status == WoStatus.closed) {
    await startCloseWorkOrder(context, ref, wo);
    return;
  }
  if (status == WoStatus.completed && !wo.allTasksDone) {
    context.showSnack(tasksFirstMessage(wo));
    return;
  }
  var note = comment?.trim().isEmpty ?? true ? null : comment!.trim();
  if (status == WoStatus.onHold && note == null) {
    note = await _askReason(context, wo.id);
    if (note == null) return;
  }
  ref.read(workOrdersProvider.notifier).updateStatus(wo.id, status, note: note);
  if (context.mounted) context.showSnack('${wo.id} is now $status');
}

Future<String?> _askReason(BuildContext context, String woId) => showDialog<String>(
  context: context,
  useRootNavigator: false,
  builder: (_) => _ReasonDialog(woId: woId),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.woId});

  final String woId;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();
  String? _error;

  static const _quick = ['Waiting for spare parts', 'Waiting for shutdown window', 'Waiting for vendor'];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Put ${widget.woId} on hold?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why is the work on hold?'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in _quick)
                ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() {
                    _text.text = q;
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            maxLines: 2,
            decoration: InputDecoration(hintText: 'Reason (required)', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final r = _text.text.trim();
            if (r.isEmpty) {
              setState(() => _error = 'Please enter a reason');
            } else {
              Navigator.pop(context, r);
            }
          },
          child: const Text('Put On Hold'),
        ),
      ],
    );
  }
}

/// Update Status ▾: statuses + optional comment.
Future<void> showUpdateStatusSheet(BuildContext context, WidgetRef ref, WorkOrder wo) async {
  final result = await showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StatusSheet(wo: wo),
  );
  if (result == null || !context.mounted) return;
  await changeWoStatus(context, ref, wo, result.$1, comment: result.$2);
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.wo});

  final WorkOrder wo;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late String _status = widget.wo.status;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return sheetFrame(context, [
      SheetTitle('Update Status', subtitle: '${widget.wo.id} · now ${widget.wo.status}'),
      RadioGroup<String>(
        groupValue: _status,
        onChanged: (v) => setState(() => _status = v ?? _status),
        child: Column(
          children: [
            for (final s in WoStatus.all)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: s,
                title: Row(children: [StatusChip(s)]),
                subtitle: switch (s) {
                  WoStatus.onHold => Text('Asks for a reason', style: AppText.caption),
                  WoStatus.completed || WoStatus.closed when !widget.wo.allTasksDone => Text(
                    tasksFirstMessage(widget.wo),
                    style: AppText.caption.copyWith(color: AppColors.red),
                  ),
                  WoStatus.closed => Text('Opens the close-out', style: AppText.caption),
                  _ => null,
                },
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _comment,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Comment', hintText: 'Optional note for the history'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.pop(context, (_status, _comment.text)),
        child: const Text('Update Status'),
      ),
    ]);
  }
}

/// Assigned To → people picker.
Future<void> showReassignSheet(BuildContext context, WidgetRef ref, WorkOrder wo) async {
  final people = ref.read(peopleProvider);
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => sheetFrame(context, [
      SheetTitle('Assign ${wo.id}', subtitle: 'Choose the technician'),
      for (final p in people)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Text(
              p.initials,
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(p.name, style: AppText.bodyStrong),
          subtitle: Text(p.role, style: AppText.caption),
          trailing: p.id == wo.assigneeId ? Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
          onTap: () => Navigator.pop(context, p.id),
        ),
    ]),
  );
  if (id == null || id == wo.assigneeId || !context.mounted) return;
  ref.read(workOrdersProvider.notifier).reassign(wo.id, id);
  context.showSnack('${wo.id} assigned to ${ref.read(personByIdProvider(id))?.name}');
}

/// + Add Part: pick from inventory with a quantity; reserves it (available stock goes down).
Future<void> showAddPartSheet(BuildContext context, WidgetRef ref, WorkOrder wo) async {
  final result = await showModalBottomSheet<(String, int)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddPartSheet(),
  );
  if (result == null || !context.mounted) return;
  ref.read(workOrdersProvider.notifier).addPart(wo.id, result.$1, result.$2);
  context.showSnack('${result.$2} × ${result.$1} reserved for ${wo.id}');
}

class _AddPartSheet extends ConsumerStatefulWidget {
  const _AddPartSheet();

  @override
  ConsumerState<_AddPartSheet> createState() => _AddPartSheetState();
}

class _AddPartSheetState extends ConsumerState<_AddPartSheet> {
  String? _partId;
  int _qty = 1;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final parts = ref.watch(inventoryProvider).parts;
    final q = _query.toLowerCase();
    final shown = parts.where((p) => q.isEmpty || '${p.id} ${p.name}'.toLowerCase().contains(q)).toList();
    final chosen = _partId == null ? null : ref.watch(partByIdProvider(_partId!));
    return sheetFrame(context, [
      const SheetTitle('Add Part', subtitle: 'Reserve a spare part from inventory'),
      TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: 'Search part number or name',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 6),
      for (final p in shown)
        ListTile(
          contentPadding: EdgeInsets.zero,
          selected: p.id == _partId,
          leading: AssetThumb(imagePath: p.imagePath, fallbackIcon: Icons.settings_outlined, size: 40),
          title: Text('${p.id} · ${p.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
          subtitle: Text('${p.available} available · ${p.warehouse}', style: AppText.caption),
          trailing: p.available == 0
              ? const StatusChip('Out of Stock')
              : Icon(
                  p.id == _partId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: AppColors.primary,
                ),
          onTap: p.available == 0
              ? () => context.showSnack('${p.id} has no stock available')
              : () => setState(() {
                  _partId = p.id;
                  _qty = 1;
                }),
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: Text('Quantity', style: AppText.bodyStrong)),
          IconButton(
            tooltip: 'Fewer',
            onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Text('$_qty', style: AppText.bodyStrong),
          IconButton(
            tooltip: 'More',
            onPressed: chosen != null && _qty < chosen.available ? () => setState(() => _qty++) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: chosen == null ? null : () => Navigator.pop(context, (chosen.id, _qty)),
        child: Text(chosen == null ? 'Choose a part' : 'Reserve $_qty × ${chosen.id}'),
      ),
    ]);
  }
}

/// Simulated voice note: "Recording…" with a running timer and Stop. Returns "Voice note 0:12".
Future<String?> showVoiceRecorder(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => const _RecorderSheet(),
);

class _RecorderSheet extends StatefulWidget {
  const _RecorderSheet();

  @override
  State<_RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends State<_RecorderSheet> {
  int _seconds = 0;
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _label => '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return sheetFrame(context, [
      Text('Recording…', textAlign: TextAlign.center, style: AppText.sectionTitle),
      const SizedBox(height: 16),
      const Center(
        child: PulseRings(icon: Icons.mic_rounded, size: 120, color: AppColors.red),
      ),
      const SizedBox(height: 12),
      Text(_label, textAlign: TextAlign.center, style: AppText.pageTitle),
      const SizedBox(height: 4),
      Text('Demo: no audio is recorded', textAlign: TextAlign.center, style: AppText.caption),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Discard')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.pop(context, 'Voice note ${_seconds == 0 ? '0:01' : _label}'),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop'),
            ),
          ),
        ],
      ),
    ]);
  }
}

/// Plays a recorded voice note ("Voice note 0:12"): a simulated player with a running progress bar.
Future<void> showVoicePlayback(BuildContext context, String label) => showModalBottomSheet<void>(
  context: context,
  builder: (_) => _PlaybackSheet(label: label),
);

class _PlaybackSheet extends StatefulWidget {
  const _PlaybackSheet({required this.label});

  final String label;

  @override
  State<_PlaybackSheet> createState() => _PlaybackSheetState();
}

class _PlaybackSheetState extends State<_PlaybackSheet> {
  /// Length parsed from the label ("Voice note 0:12" → 12 s).
  late final int _length = () {
    final m = RegExp(r'(\d+):(\d{2})').firstMatch(widget.label);
    final s = m == null ? 5 : int.parse(m[1]!) * 60 + int.parse(m[2]!);
    return s < 1 ? 1 : s;
  }();
  int _position = 0;
  bool _playing = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (_position >= _length) _position = 0;
    _playing = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _position++;
        if (_position >= _length) {
          _playing = false;
          t.cancel();
        }
      });
    });
  }

  void _toggle() => setState(() {
    if (_playing) {
      _timer?.cancel();
      _playing = false;
    } else {
      _start();
    }
  });

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return sheetFrame(context, [
      SheetTitle(widget.label, subtitle: 'Demo playback: no audio was recorded'),
      Row(
        children: [
          IconButton.filled(
            tooltip: _playing ? 'Pause' : 'Play',
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _position / _length, minHeight: 6),
            ),
          ),
          const SizedBox(width: 12),
          Text('${_fmt(_position)} / ${_fmt(_length)}', style: AppText.caption),
        ],
      ),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
    ]);
  }
}

// ---------------------------------------------------------------- Close work order

/// Close Work Order: disabled (with a message) until every task is done; then resolution notes,
/// labour hours, parts actually used and a signature.
Future<void> startCloseWorkOrder(BuildContext context, WidgetRef ref, WorkOrder wo) async {
  if (!wo.allTasksDone) {
    context.showSnack(tasksFirstMessage(wo));
    return;
  }
  final closed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (_) => _CloseSheet(woId: wo.id),
  );
  if (closed == true && context.mounted) {
    await showSuccessSheet(
      context,
      title: '${wo.id} closed',
      message: 'The asset is back to Active and the parts used were issued from stock.',
    );
  }
}

class _CloseSheet extends ConsumerStatefulWidget {
  const _CloseSheet({required this.woId});

  final String woId;

  @override
  ConsumerState<_CloseSheet> createState() => _CloseSheetState();
}

class _CloseSheetState extends ConsumerState<_CloseSheet> {
  final _resolution = TextEditingController();
  final _hours = TextEditingController();
  final _used = <String, int>{};
  var _signature = <List<(double, double)>>[];
  final _errors = <String, String>{};

  @override
  void dispose() {
    _resolution.dispose();
    _hours.dispose();
    super.dispose();
  }

  void _close() {
    final hours = double.tryParse(_hours.text.trim().replaceAll(',', '.'));
    setState(() {
      _errors
        ..clear()
        ..addAll({
          if (_resolution.text.trim().isEmpty) 'resolution': 'Describe what was done',
          if (hours == null || hours <= 0 || hours > 100) 'hours': 'Enter the hours worked (e.g. 3.5)',
          if (_signature.isEmpty) 'signature': 'Sign to close the work order',
        });
    });
    if (_errors.isNotEmpty) return;
    ref
        .read(workOrdersProvider.notifier)
        .close(
          widget.woId,
          resolution: _resolution.text.trim(),
          labourHours: hours!,
          usedQty: _used,
          signature: _signature,
        );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final wo = ref.watch(workOrderByIdProvider(widget.woId))!;
    final reserved = wo.parts.where((p) => p.status == 'Reserved').toList();
    return sheetFrame(context, [
      SheetTitle('Close ${wo.id}', subtitle: 'All ${wo.tasks.length} tasks are complete'),
      TextField(
        controller: _resolution,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Resolution notes *',
          hintText: 'e.g. Replaced both bearings, vibration now 1.6 mm/s',
          errorText: _errors['resolution'],
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _hours,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Labour hours *', suffixText: 'h', errorText: _errors['hours']),
      ),
      const SizedBox(height: 14),
      Text('Parts used', style: AppText.bodyStrong),
      const SizedBox(height: 4),
      if (reserved.isEmpty)
        Text('No reserved parts', style: AppText.secondary)
      else
        for (final p in reserved)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p.partId} · ${ref.watch(partByIdProvider(p.partId))?.name ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body,
                ),
              ),
              IconButton(
                tooltip: 'Fewer ${p.partId}',
                onPressed: (_used[p.partId] ?? p.qty) > 0
                    ? () => setState(() => _used[p.partId] = (_used[p.partId] ?? p.qty) - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text('${_used[p.partId] ?? p.qty} / ${p.qty}', style: AppText.bodyStrong),
              IconButton(
                tooltip: 'More ${p.partId}',
                onPressed: (_used[p.partId] ?? p.qty) < p.qty
                    ? () => setState(() => _used[p.partId] = (_used[p.partId] ?? p.qty) + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
      Text('Unused reserved parts go back to available stock.', style: AppText.caption),
      const SizedBox(height: 14),
      Text('Technician signature', style: AppText.bodyStrong),
      const SizedBox(height: 6),
      SignaturePad(onChanged: (s) => setState(() => _signature = s)),
      if (_errors['signature'] != null)
        Text(_errors['signature']!, style: AppText.caption.copyWith(color: AppColors.red)),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _close,
        icon: const Icon(Icons.task_alt_rounded),
        label: const Text('Close Work Order'),
      ),
    ]);
  }
}
