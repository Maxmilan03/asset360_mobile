import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/checklist/checklist_widgets.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/features/work/maintenance/wo_actions.dart';

/// Tasks tab: progress bar computed from completed tasks and an accordion of the tasks.
/// Only the task in progress can be edited; Complete Task opens the next one.
class WoTasksTab extends ConsumerStatefulWidget {
  const WoTasksTab({super.key, required this.wo});

  final WorkOrder wo;

  @override
  ConsumerState<WoTasksTab> createState() => _WoTasksTabState();
}

class _WoTasksTabState extends ConsumerState<WoTasksTab> {
  late final Set<String> _open = {?widget.wo.openTaskId};
  final _controllers = <String, TextEditingController>{};

  TextEditingController _controller(String key, String initial) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wo = widget.wo;
    final done = wo.tasksDone, total = wo.tasks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Task Progress', style: AppText.bodyStrong)),
                  Text('$done / $total', style: AppText.bodyStrong),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 8,
                  color: AppColors.green,
                  backgroundColor: AppColors.greyBg,
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
              for (final (i, t) in wo.tasks.indexed) ...[
                if (i > 0) const Divider(height: 1),
                _taskHeader(i, t),
                if (_open.contains(t.id)) _taskBody(wo, i, t),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskHeader(int i, WoTask t) {
    final expanded = _open.contains(t.id);
    return InkWell(
      onTap: () => setState(() => expanded ? _open.remove(t.id) : _open.add(t.id)),
      child: Container(
        color: t.status == TaskStatus.inProgress ? AppColors.primarySoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.isDone
                    ? AppColors.green
                    : t.status == TaskStatus.inProgress
                    ? AppColors.primary
                    : AppColors.greyBg,
              ),
              child: t.isDone
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.status == TaskStatus.inProgress ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(fontSize: 13.5),
              ),
            ),
            if (t.isDone && t.completedAt != null)
              Text(DemoClock.formatTime(t.completedAt!), style: AppText.caption)
            else
              StatusChip(t.status),
            const SizedBox(width: 4),
            Icon(
              expanded ? Icons.keyboard_arrow_up_rounded : Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskBody(WorkOrder wo, int index, WoTask t) {
    final editable = t.id == wo.openTaskId && wo.isActive;
    final notifier = ref.read(workOrdersProvider.notifier);
    final before = index == 0 ? null : wo.tasks[index - 1];
    return Container(
      color: t.status == TaskStatus.inProgress ? AppColors.primarySoft.withValues(alpha: .4) : null,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Checklist', style: AppText.bodyStrong)),
              Text('${t.checklistDone} / ${t.checklist.length} completed', style: AppText.caption),
            ],
          ),
          if (!editable && !t.isDone)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                wo.isActive
                    ? 'Starts after "${before?.title ?? 'the previous task'}" is completed'
                    : 'Work order closed',
                style: AppText.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          for (final c in t.checklist)
            CheckItemView(
              key: ValueKey(c.code),
              item: c,
              enabled: editable,
              onChanged: (item) => notifier.setChecklistItem(wo.id, t.id, item),
            ),
          if (editable || t.notes.isNotEmpty || t.voiceNotes.isNotEmpty || t.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notes', style: AppText.bodyStrong),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller('${t.id}-notes', t.notes),
                    enabled: editable,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Findings, readings, remarks'),
                    onChanged: (v) => notifier.setTaskNotes(wo.id, t.id, v),
                  ),
                ),
                if (editable)
                  IconButton(
                    tooltip: 'Record voice note',
                    onPressed: () async {
                      final label = await showVoiceRecorder(context);
                      if (label != null && mounted) notifier.addVoiceNote(wo.id, t.id, label);
                    },
                    icon: Icon(Icons.mic_rounded, color: AppColors.primary),
                  ),
              ],
            ),
            if (t.voiceNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final v in t.voiceNotes)
                    ActionChip(
                      avatar: Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.primary),
                      label: Text(v),
                      onPressed: () => showVoicePlayback(context, v),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.build_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text('Add Photos / Video (${t.photos.length})', style: AppText.body)),
                if (editable)
                  for (final (icon, tip, source, video) in [
                    (Icons.photo_camera_outlined, 'Take photo', ImageSource.camera, false),
                    (Icons.photo_library_outlined, 'Choose from gallery', ImageSource.gallery, false),
                    (Icons.videocam_outlined, 'Record video', ImageSource.camera, true),
                  ])
                    IconButton.outlined(
                      tooltip: tip,
                      onPressed: () => _addMedia(wo.id, t.id, source, video: video),
                      icon: Icon(icon, size: 20),
                    ),
              ],
            ),
            if (t.photos.isNotEmpty) ...[
              const SizedBox(height: 6),
              PhotoStrip(photos: t.photos, thumbWidth: 88, thumbHeight: 66),
            ],
          ],
          if (editable) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: t.checklistComplete
                  ? () {
                      notifier.completeTask(wo.id, t.id);
                      final next = index + 1 < wo.tasks.length ? wo.tasks[index + 1] : null;
                      setState(() {
                        _open.remove(t.id);
                        if (next != null) _open.add(next.id);
                      });
                      context.showSnack(
                        next == null ? 'All tasks done – you can close the work order' : '${t.title} completed',
                      );
                    }
                  : null,
              child: const Text('Complete Task'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addMedia(String woId, String taskId, ImageSource source, {required bool video}) async {
    try {
      final picker = ImagePicker();
      final file = video
          ? await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 2))
          : await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
      if (file == null || !mounted) return;
      ref.read(workOrdersProvider.notifier).addTaskPhoto(woId, taskId, file.path);
      context.showSnack(video ? 'Video added to the task' : 'Photo added to the task');
    } catch (_) {
      if (mounted) context.showSnack('Camera / gallery not available. Allow access in Settings.');
    }
  }
}
