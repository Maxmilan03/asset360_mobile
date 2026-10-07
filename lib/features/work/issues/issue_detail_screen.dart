import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/models/issue.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/work/maintenance/create_work_order_screen.dart';
import 'package:asset360_mobile/features/work/maintenance/wo_widgets.dart';
import 'package:asset360_mobile/features/work/issues/report_issue_screen.dart';

enum IssueTab {
  details('Details'),
  workOrders('Work Orders'),
  timeline('Timeline'),
  attachments('Attachments');

  const IssueTab(this.label);
  final String label;
}

/// Issue detail (right screen of design/10_issues_defects.jpg).
class IssueDetailScreen extends ConsumerStatefulWidget {
  const IssueDetailScreen({super.key, required this.id, this.initialTab});

  final String id;
  final String? initialTab;

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  late IssueTab _tab = IssueTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => IssueTab.details);

  IssuesNotifier get _n => ref.read(issuesProvider.notifier);

  @override
  void didUpdateWidget(IssueDetailScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) {
      _tab = IssueTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => _tab);
    }
  }

  Future<void> _setStatus(Issue i, String status, {String? comment}) async {
    if (status == i.status) return;
    if (status == IssueStatus.closed) return _close(i);
    _n.updateStatus(i.id, status, note: comment?.trim().isEmpty ?? true ? null : comment!.trim());
    context.showSnack('${i.id} is now $status');
  }

  Future<void> _close(Issue i) async {
    final notes = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (_) => _TextDialog(
        title: 'Close ${i.id}?',
        message: 'Describe how the issue was resolved.',
        hint: 'Resolution notes (required)',
        action: 'Close Issue',
      ),
    );
    if (notes == null || !mounted) return;
    _n.close(i.id, notes);
    context.showSnack('${i.id} closed');
  }

  Future<void> _updateStatusSheet(Issue i) async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StatusSheet(issue: i),
    );
    if (result != null && mounted) await _setStatus(i, result.$1, comment: result.$2);
  }

  void _createWorkOrder(Issue i) => context.push(
    Routes.createWorkOrder(assetId: i.assetId),
    extra: WoPrefill(
      title: i.title,
      description: 'Created from ${i.id}. ${i.description}',
      priority: i.priority,
      issueId: i.id,
      photos: i.photos,
      workType: i.type == 'Breakdown' ? 'Breakdown' : 'Corrective',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(issueByIdProvider(widget.id));
    if (i == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Issue not found', message: widget.id),
      );
    }
    final closed = i.status == IssueStatus.closed;
    return AppScaffold(
      bottomActions: closed
          ? null
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _close(i),
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Close Issue')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _createWorkOrder(i),
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Create Work Order')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _updateStatusSheet(i),
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Update Status')),
                  ),
                ),
              ],
            ),
      body: ListView(
        padding: closed ? context.pagePadding : const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.camera_alt_outlined, color: AppColors.text, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(i.id, style: AppText.pageTitle.copyWith(fontSize: 20)),
                        PriorityChip(i.priority),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.pageSubtitle),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('issue-status'),
                tooltip: 'Change status',
                enabled: !closed,
                onSelected: (s) => _setStatus(i, s),
                itemBuilder: (_) => [
                  for (final s in IssueStatus.all)
                    PopupMenuItem(value: s, child: Text(s == IssueStatus.closed ? 'Closed (asks for resolution)' : s)),
                ],
                child: StatusChip(i.status, trailingIcon: closed ? null : Icons.keyboard_arrow_down_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SegmentTabs(
            tabs: [
              for (final t in IssueTab.values)
                SegmentTab(t.label, count: t == IssueTab.workOrders ? i.workOrderIds.length : null),
            ],
            selected: _tab.index,
            onChanged: (n) => setState(() => _tab = IssueTab.values[n]),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            IssueTab.details => _Details(issue: i, onReassign: () => _reassign(i)),
            // List tabs show a loading shimmer the first time they open.
            IssueTab.workOrders => LoadingGate(
              key: const ValueKey('workOrders'),
              rows: 1,
              child: _WorkOrders(issue: i, onCreate: closed ? null : () => _createWorkOrder(i)),
            ),
            IssueTab.timeline => LoadingGate(
              key: const ValueKey('timeline'),
              rows: 3,
              child: _Timeline(issue: i),
            ),
            IssueTab.attachments => LoadingGate(
              key: const ValueKey('attachments'),
              rows: 2,
              child: _Attachments(issue: i),
            ),
          },
        ],
      ),
    );
  }

  Future<void> _reassign(Issue i) async {
    final people = ref.read(peopleProvider);
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => sheetFrame(sheet, [
        SheetTitle('Assign ${i.id}', subtitle: 'Maintenance Team'),
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
            trailing: p.id == i.assigneeId ? Icon(Icons.check_rounded, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(sheet, p.id),
          ),
      ]),
    );
    if (id == null || id == i.assigneeId || !mounted) return;
    _n.assign(i.id, id);
    context.showSnack('${i.id} assigned to ${ref.read(personByIdProvider(id))?.name}');
  }
}

// ---------------------------------------------------------------- Details

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.issue, required this.onReassign});

  final Issue issue;
  final VoidCallback onReassign;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  bool _editing = false;
  late final _title = TextEditingController();
  late final _description = TextEditingController();
  late final _location = TextEditingController();
  String _type = issueTypes.first;
  String _priority = 'Medium';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  void _startEdit() {
    final i = widget.issue;
    setState(() {
      _title.text = i.title;
      _description.text = i.description;
      _location.text = i.location;
      _type = issueTypes.contains(i.type) ? i.type : issueTypes.last;
      _priority = i.priority;
      _editing = true;
    });
  }

  void _save() {
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      context.showSnack('Title and description cannot be empty');
      return;
    }
    ref
        .read(issuesProvider.notifier)
        .edit(
          widget.issue.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          type: _type,
          priority: _priority,
          location: _location.text.trim(),
        );
    setState(() => _editing = false);
    context.showSnack('Issue details saved');
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.issue;
    final asset = ref.watch(assetByIdProvider(i.assetId));
    final reporter = ref.watch(personByIdProvider(i.reporterId));
    final assignee = ref.watch(personByIdProvider(i.assigneeId));
    final closed = i.status == IssueStatus.closed;
    final notifier = ref.read(issuesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (asset != null)
          AppCard(
            onTap: () => context.push(Routes.assetDetail(asset.id)),
            child: Row(
              children: [
                AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 76),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              asset.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.cardTitle,
                            ),
                          ),
                          Flexible(child: StatusChip(asset.status)),
                        ],
                      ),
                      Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                      const SizedBox(height: 4),
                      IconLine(icon: Icons.location_on_outlined, text: asset.location),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Issue Information',
                actionLabel: _editing || closed ? null : 'Edit',
                actionIcon: Icons.edit_outlined,
                onAction: _startEdit,
              ),
              const SizedBox(height: 8),
              if (_editing) ...[
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  maxLength: issueDescriptionMax,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Issue Type'),
                  items: [
                    for (final t in issueTypes)
                      DropdownMenuItem(
                        value: t,
                        child: Row(children: [Icon(issueTypeIcon(t), size: 18), const SizedBox(width: 8), Text(t)]),
                      ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in const ['Critical', 'High', 'Medium', 'Low'])
                      ChoiceChip(
                        label: Text(p),
                        selected: _priority == p,
                        onSelected: (_) => setState(() => _priority = p),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
              ] else ...[
                InfoRow(label: 'Issue No.', value: i.id, labelWidth: 104),
                InfoRow(label: 'Title', value: i.title, labelWidth: 104),
                InfoRow(label: 'Description', value: i.description, labelWidth: 104),
                InfoRow(label: 'Issue Type', value: i.type, labelWidth: 104),
                InfoRow(
                  label: 'Priority',
                  value: i.priority,
                  labelWidth: 104,
                  valueWidget: Align(alignment: Alignment.centerLeft, child: PriorityChip(i.priority)),
                ),
                InfoRow(
                  label: 'Status',
                  value: i.status,
                  labelWidth: 104,
                  valueWidget: Align(alignment: Alignment.centerLeft, child: StatusChip(i.status)),
                ),
                InfoRow(label: 'Reported By', value: reporter?.name ?? i.reporterId, labelWidth: 104),
                InfoRow(label: 'Reported Date', value: DemoClock.formatDateTime(i.reportedAt), labelWidth: 104),
                InfoRow(label: 'Location', value: i.location, labelWidth: 104),
                InfoRow(label: 'Asset', value: i.assetId, labelWidth: 104),
                InkWell(
                  onTap: closed ? null : widget.onReassign,
                  child: InfoRow(
                    label: 'Assigned To',
                    value: '',
                    labelWidth: 104,
                    valueWidget: Row(
                      children: [
                        Expanded(
                          child: Text(
                            assignee == null
                                ? 'Unassigned'
                                : '${assignee.name} (${i.assignedTeam ?? 'Maintenance Team'})',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(fontSize: 13, color: AppColors.text),
                          ),
                        ),
                        if (!closed) Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                if (i.resolution != null)
                  InfoRow(label: 'Resolution', value: i.resolution!, labelWidth: 104, valueColor: AppColors.green),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Photos (${i.photos.length})',
                actionLabel: i.photos.isEmpty ? null : 'View All',
                actionIcon: null,
                onAction: () => _showGallery(context, ref, i),
              ),
              const SizedBox(height: 8),
              PhotoStrip(
                photos: i.photos,
                onAdd: closed
                    ? null
                    : (p) {
                        notifier.addPhoto(i.id, p);
                        context.showSnack('Photo added');
                      },
                onRemove: closed ? null : (n) => notifier.removePhoto(i.id, n),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "View All": grid of the issue's photos; tap to open, ✕ to remove.
Future<void> _showGallery(BuildContext context, WidgetRef ref, Issue issue) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) => Consumer(
    builder: (sheet, ref, _) {
      final i = ref.watch(issueByIdProvider(issue.id))!;
      return sheetFrame(sheet, [
        SheetTitle('Photos (${i.photos.length})', subtitle: i.id),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final (n, p) in i.photos.indexed)
              Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => openPhotoViewer(sheet, i.photos, initialIndex: n),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: photoProvider(p),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: AppColors.greyBg,
                          child: Icon(Icons.videocam_outlined, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  if (i.status != IssueStatus.closed)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filledTonal(
                        tooltip: 'Remove photo',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: () => ref.read(issuesProvider.notifier).removePhoto(i.id, n),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ]);
    },
  ),
);

// ---------------------------------------------------------------- Work orders

class _WorkOrders extends ConsumerWidget {
  const _WorkOrders({required this.issue, required this.onCreate});

  final Issue issue;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wos = ref.watch(workOrdersProvider);
    final linked = [for (final id in issue.workOrderIds) ?wos.where((w) => w.id == id).firstOrNull];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (linked.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.build_outlined,
              title: 'No work orders yet',
              message: 'Create one to fix it.',
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (n, w) in linked.indexed) ...[if (n > 0) const Divider(height: 1, indent: 90), WoRow(wo: w)],
              ],
            ),
          ),
        if (onCreate != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Work Order'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Timeline

class _Timeline extends ConsumerStatefulWidget {
  const _Timeline({required this.issue});

  final Issue issue;

  @override
  ConsumerState<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<_Timeline> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _send() {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    ref.read(issuesProvider.notifier).addComment(widget.issue.id, text);
    _comment.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.issue.timeline.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _comment,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Add comment'),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(tooltip: 'Post comment', onPressed: _send, icon: const Icon(Icons.send_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        if (log.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.timeline_rounded,
              title: 'No activity yet',
              message: 'Add the first comment.',
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var n = 0; n < log.length; n++)
                  _TimelineEntry(entry: log[n], first: n == 0, last: n == log.length - 1),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry, required this.first, required this.last});

  final LogEntry entry;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final comment = entry.title == 'Comment';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(
                comment ? Icons.chat_bubble_outline_rounded : Icons.circle,
                size: comment ? 16 : 12,
                color: first ? AppColors.primary : AppColors.illustration,
              ),
              if (!last) Expanded(child: Container(width: 2, color: AppColors.divider)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment ? (entry.note ?? '') : entry.title,
                    style: comment ? AppText.body : AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  if (!comment && entry.note != null) Text(entry.note!, style: AppText.body.copyWith(fontSize: 12.5)),
                  Text(
                    [if (comment) 'Comment', DemoClock.formatDateTime(entry.at), ?entry.by].join(' · '),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Attachments

class _Attachments extends ConsumerWidget {
  const _Attachments({required this.issue});

  final Issue issue;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles();
      final picked = <Attachment>[];
      for (final f in files) {
        final bytes = await f.length() ?? 0;
        picked.add(Attachment(name: f.name, sizeKb: (bytes / 1024).ceil(), path: f.path));
      }
      if (picked.isEmpty || !context.mounted) return;
      ref.read(issuesProvider.notifier).addAttachments(issue.id, picked);
      context.showSnack('${picked.length} file${picked.length == 1 ? '' : 's'} attached');
    } catch (_) {
      if (context.mounted) context.showSnack('Could not open files. Allow file access and try again.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = issue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: PhotoStrip(title: 'Photos', photos: i.photos),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Files (${i.attachments.length})', style: AppText.bodyStrong),
              const SizedBox(height: 8),
              if (i.attachments.isEmpty)
                const EmptyState(
                  icon: Icons.attach_file_rounded,
                  title: 'No files attached',
                  message: 'Add reports, invoices or other files.',
                ),
              for (final f in i.attachments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AttachmentTile(attachment: f),
                ),
            ],
          ),
        ),
        if (i.status != IssueStatus.closed) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.attach_file_rounded),
            label: const Text('Add Files'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Status sheet / text dialog

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.issue});

  final Issue issue;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late String _status = widget.issue.status;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return sheetFrame(context, [
      SheetTitle('Update Status', subtitle: '${widget.issue.id} · now ${widget.issue.status}'),
      RadioGroup<String>(
        groupValue: _status,
        onChanged: (v) => setState(() => _status = v ?? _status),
        child: Column(
          children: [
            for (final s in IssueStatus.all)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: s,
                title: Row(children: [StatusChip(s)]),
                subtitle: s == IssueStatus.closed ? Text('Asks for resolution notes', style: AppText.caption) : null,
              ),
          ],
        ),
      ),
      TextField(
        controller: _comment,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Comment', hintText: 'Added to the timeline'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.pop(context, (_status, _comment.text)),
        child: const Text('Update Status'),
      ),
    ]);
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.message, required this.hint, required this.action});

  final String title;
  final String message;
  final String hint;
  final String action;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(hintText: widget.hint, errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final t = _text.text.trim();
            if (t.isEmpty) {
              setState(() => _error = 'Required');
            } else {
              Navigator.pop(context, t);
            }
          },
          child: Text(widget.action),
        ),
      ],
    );
  }
}
