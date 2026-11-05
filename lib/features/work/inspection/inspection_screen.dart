import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/checklist/checklist.dart';
import 'package:asset360_mobile/core/checklist/checklist_widgets.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/data/models/inspection.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/work/inspection/inspection_widgets.dart';

enum InsTab {
  details('Details'),
  checklist('Checklist'),
  findings('Findings'),
  documents('Documents');

  const InsTab(this.label);
  final String label;
}

/// Inspection (middle and right screens of design/09_inspection.jpg).
class InspectionScreen extends ConsumerStatefulWidget {
  const InspectionScreen({super.key, required this.id, this.initialTab});

  final String id;
  final String? initialTab;

  @override
  ConsumerState<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends ConsumerState<InspectionScreen> {
  late InsTab _tab = InsTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => InsTab.checklist);

  /// Expanded section; == sections.length means the Summary & Submit step.
  int _section = 0;
  List<List<SignaturePoint>> _signature = const [];
  String? _submitError;

  @override
  void didUpdateWidget(InspectionScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) {
      _tab = InsTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => _tab);
    }
  }

  InspectionsNotifier get _n => ref.read(inspectionsProvider.notifier);

  void _goTo(int section) => setState(() {
    _section = section;
    _submitError = null;
  });

  Future<void> _onItemChanged(Inspection ins, CheckItem before, CheckItem after) async {
    _n.setItem(ins.id, after);
    // A newly chosen negative answer opens "Add Finding" (unless the item already has an open finding).
    final choice = after.type == CheckType.choice || after.type == CheckType.yesNo;
    final hasFinding = ins.findings.any((f) => f.questionCode == after.code && f.isOpen);
    if (choice && after.negative && after.value != before.value && !hasFinding) {
      final id = await showAddFindingSheet(context, ref, ins.id, item: after);
      if (id != null && mounted) context.showSnack('Finding $id added');
    }
  }

  Future<void> _submit(Inspection ins) async {
    final missing = ins.sections.indexed.where((e) => !e.$2.complete).map((e) => e.$1 + 1).toList();
    if (missing.isNotEmpty) {
      setState(() => _submitError = 'Answer every item first (section ${missing.join(', ')})');
      return;
    }
    if (_signature.isEmpty) {
      setState(() => _submitError = 'Sign to submit the inspection');
      return;
    }
    _n.complete(ins.id, signature: _signature);
    final done = ref.read(inspectionByIdProvider(ins.id))!;
    await showSuccessSheet(
      context,
      title: '${ins.id} completed',
      message: 'Score ${done.passedQuestions} / ${done.totalQuestions}. It is now in the Completed list.',
    );
    if (!mounted) return;
    final open = done.findings.where((f) => f.status == FindingStatus.open).toList();
    if (open.isNotEmpty) await _offerWorkOrders(done, open);
  }

  /// After Submit: "Create Work Order" for each open finding.
  Future<void> _offerWorkOrders(Inspection ins, List<Finding> open) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => sheetFrame(sheet, [
      SheetTitle('Open findings (${open.length})', subtitle: 'Create a work order to fix each one'),
      for (final f in open)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(width: 70, child: PriorityChip(f.severity)),
          title: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
          trailing: TextButton(
            onPressed: () {
              Navigator.pop(sheet);
              createWorkOrderForFinding(context, ins, f);
            },
            child: const Text('Create Work Order'),
          ),
        ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => Navigator.pop(sheet), child: const Text('Later')),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final ins = ref.watch(inspectionByIdProvider(widget.id));
    if (ins == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Inspection not found', message: widget.id),
      );
    }
    final summary = _section >= ins.sections.length;
    final checklistActions = _tab == InsTab.checklist && !ins.isCompleted;
    return AppScaffold(
      bottomActions: checklistActions ? _checklistButtons(ins, summary) : null,
      body: ListView(
        padding: checklistActions ? const EdgeInsets.fromLTRB(16, 16, 16, 24) : context.pagePadding,
        children: [
          _Header(
            inspection: ins,
            onComplete: () => setState(() {
              _tab = InsTab.checklist;
              _section = ins.sections.length;
            }),
          ),
          const SizedBox(height: 6),
          SegmentTabs(
            tabs: [
              for (final t in InsTab.values)
                SegmentTab(t.label, count: t == InsTab.findings ? ins.findings.length : null),
            ],
            selected: _tab.index,
            onChanged: (i) => setState(() => _tab = InsTab.values[i]),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            InsTab.details => _DetailsTab(inspection: ins),
            InsTab.checklist => summary ? _summary(ins) : _checklist(ins),
            // List tabs show a loading shimmer the first time they open.
            InsTab.findings => LoadingGate(
              key: const ValueKey('findings'),
              rows: 2,
              child: _FindingsTab(inspection: ins),
            ),
            InsTab.documents => LoadingGate(
              key: const ValueKey('documents'),
              rows: 2,
              child: _DocumentsTab(inspection: ins),
            ),
          },
        ],
      ),
    );
  }

  Widget _checklistButtons(Inspection ins, bool summary) {
    final last = _section == ins.sections.length - 1;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _section == 0
                ? () {
                    _n.saveDraft(ins.id);
                    context.showSnack('Draft saved');
                  }
                : () => _goTo(_section - 1),
            child: Text(_section == 0 ? 'Save as Draft' : 'Previous'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: summary
              ? FilledButton.icon(
                  onPressed: () => _submit(ins),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit'),
                )
              : FilledButton(
                  onPressed: () => _goTo(_section + 1),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_section == 0 ? 'Next' : (last ? 'Save & Review' : 'Save & Next')),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _checklist(Inspection ins) {
    final editable = !ins.isCompleted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChecklistProgress(done: ins.answeredQuestions, total: ins.totalQuestions),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (n, s) in ins.sections.indexed) ...[
                if (n > 0) const Divider(height: 1),
                CheckSectionHeader(
                  number: n + 1,
                  section: s,
                  expanded: n == _section,
                  onTap: () => _goTo(n == _section ? -1 : n),
                ),
                if (n == _section)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in s.items)
                          CheckItemView(
                            key: ValueKey('${ins.id}-${item.code}'),
                            item: item,
                            enabled: editable,
                            onChanged: (next) => _onItemChanged(ins, item, next),
                            onAddFinding: () async {
                              final id = await showAddFindingSheet(context, ref, ins.id, item: item);
                              if (id != null && mounted) context.showSnack('Finding $id added');
                            },
                          ),
                        const SizedBox(height: 8),
                        Text('Notes', style: AppText.bodyStrong),
                        const SizedBox(height: 6),
                        _SectionNotes(
                          key: ValueKey('${ins.id}-notes-$n'),
                          initial: s.notes,
                          enabled: editable,
                          onChanged: (v) => _n.setSectionNotes(ins.id, n, v),
                        ),
                        const SizedBox(height: 12),
                        PhotoStrip(
                          title: 'Photos',
                          photos: s.photos,
                          onAdd: editable ? (p) => _n.addSectionPhoto(ins.id, n, p) : null,
                          onRemove: editable ? (i) => _n.removeSectionPhoto(ins.id, n, i) : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (ins.isCompleted) ...[const SizedBox(height: 12), _ScoreCard(inspection: ins)],
      ],
    );
  }

  Widget _summary(Inspection ins) {
    final unanswered = [
      for (final (n, s) in ins.sections.indexed)
        if (!s.complete) (n, s),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Summary & Submit', style: AppText.sectionTitle),
        const SizedBox(height: 10),
        _ScoreCard(inspection: ins),
        if (unanswered.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Still to answer', style: AppText.bodyStrong.copyWith(color: AppColors.red)),
                for (final (n, s) in unanswered)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${n + 1}. ${s.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('${s.answered} / ${s.items.length}'),
                    onTap: () => _goTo(n),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        SectionCard(
          title: 'Findings (${ins.findings.length})',
          actionLabel: 'Add',
          actionIcon: Icons.add_rounded,
          onAction: () => showAddFindingSheet(context, ref, ins.id),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: ins.findings.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('No findings', style: AppText.secondary),
                )
              : Column(
                  children: [
                    for (final f in ins.findings)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(width: 70, child: PriorityChip(f.severity)),
                        title: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(f.status, style: AppText.caption),
                        onTap: () => context.push(Routes.finding(f.id)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Inspector signature', style: AppText.bodyStrong),
              const SizedBox(height: 4),
              Text(ref.watch(personByIdProvider(ins.inspectorId))?.labelWithRole ?? '', style: AppText.caption),
              const SizedBox(height: 8),
              SignaturePad(onChanged: (s) => setState(() => _signature = s)),
            ],
          ),
        ),
        if (_submitError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_submitError!, style: AppText.caption.copyWith(color: AppColors.red)),
          ),
      ],
    );
  }
}

class _SectionNotes extends StatefulWidget {
  const _SectionNotes({super.key, required this.initial, required this.enabled, required this.onChanged});

  final String initial;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_SectionNotes> createState() => _SectionNotesState();
}

class _SectionNotesState extends State<_SectionNotes> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    enabled: widget.enabled,
    maxLines: null,
    textCapitalization: TextCapitalization.sentences,
    decoration: const InputDecoration(hintText: 'Add notes (optional)'),
    onChanged: widget.onChanged,
  );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final i = inspection;
    final pct = i.totalQuestions == 0 ? 0 : (i.passedQuestions * 100 / i.totalQuestions).round();
    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            value: pct / 100,
            size: 72,
            color: pct >= 80 ? AppColors.green : (pct >= 60 ? AppColors.amber : AppColors.red),
            center: Text('$pct%', style: AppText.bodyStrong),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score ${i.passedQuestions} / ${i.totalQuestions}', style: AppText.cardTitle),
                Text('items passed', style: AppText.caption),
                const SizedBox(height: 6),
                Text(
                  '${i.answeredQuestions} answered · ${i.findings.length} finding${i.findings.length == 1 ? '' : 's'}',
                  style: AppText.secondary,
                ),
                if (i.completedAt != null)
                  Text('Completed ${DemoClock.formatDateTime(i.completedAt!)}', style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.inspection, required this.onComplete});

  final Inspection inspection;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = inspection;
    final display = InspectionQueries.displayStatus(i);
    return Row(
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
                  if (display == 'Overdue' || display == 'Due Today') StatusChip(display),
                ],
              ),
              const SizedBox(height: 2),
              Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.pageSubtitle),
            ],
          ),
        ),
        PopupMenuButton<String>(
          key: const ValueKey('ins-status'),
          tooltip: 'Change status',
          enabled: !i.isCompleted,
          onSelected: (s) {
            if (s == InspectionStatus.completed) {
              onComplete();
            } else if (s != i.status) {
              ref.read(inspectionsProvider.notifier).setStatus(i.id, s);
              context.showSnack('${i.id} is now $s');
            }
          },
          itemBuilder: (_) => [
            for (final s in InspectionStatus.all)
              PopupMenuItem(
                value: s,
                child: Text(s == InspectionStatus.completed ? 'Completed (Summary & Submit)' : s),
              ),
          ],
          child: StatusChip(i.status, trailingIcon: i.isCompleted ? null : Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Details

class _DetailsTab extends ConsumerWidget {
  const _DetailsTab({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = inspection;
    final asset = ref.watch(assetByIdProvider(i.assetId));
    final inspector = ref.watch(personByIdProvider(i.inspectorId));
    final previous =
        ref
            .watch(inspectionsProvider)
            .where((x) => x.assetId == i.assetId && x.id != i.id && x.isCompleted && x.completedAt != null)
            .toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final last = previous.isEmpty ? null : previous.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (asset != null)
          AppCard(
            padding: EdgeInsets.zero,
            child: AssetListTile(
              title: asset.id,
              subtitle: asset.name,
              location: asset.location,
              imagePath: asset.imagePath,
              fallbackIcon: assetIcon(asset),
              trailingTop: AssetStatusChip(asset.status),
              onTap: () => context.push(Routes.assetDetail(asset.id)),
            ),
          ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              InfoRow(label: 'Template', value: i.template ?? '${i.type} checklist'),
              InfoRow(label: 'Type', value: i.type),
              InfoRow(label: 'Scheduled', value: DemoClock.formatDateTime(i.dueAt)),
              InfoRow(label: 'Inspector', value: inspector?.labelWithRole ?? '—'),
              InfoRow(label: 'Location', value: asset?.location ?? '—'),
              InfoRow(label: 'Status', value: InspectionQueries.displayStatus(i)),
              InfoRow(
                label: 'Last inspection',
                value: last == null
                    ? 'None on record'
                    : '${last.id} · ${last.passedQuestions}/${last.totalQuestions} passed · '
                          '${DemoClock.formatDate(last.completedAt!)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (!i.isCompleted)
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                useRootNavigator: false,
                initialDate: i.dueAt.isBefore(DemoClock.today) ? DemoClock.today : i.dueAt,
                firstDate: DemoClock.today,
                lastDate: DemoClock.today.add(const Duration(days: 365)),
              );
              if (d == null || !context.mounted) return;
              ref
                  .read(inspectionsProvider.notifier)
                  .reschedule(i.id, DateTime(d.year, d.month, d.day, i.dueAt.hour, i.dueAt.minute));
              context.showSnack('${i.id} rescheduled to ${DemoClock.formatDate(d)}');
            },
            icon: const Icon(Icons.event_rounded),
            label: const Text('Reschedule'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Findings

class _FindingsTab extends ConsumerWidget {
  const _FindingsTab({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = inspection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (i.findings.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.verified_outlined,
              title: 'No findings',
              message: 'Negative answers open "Add Finding" automatically.',
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (n, f) in i.findings.indexed) ...[
                  if (n > 0) const Divider(height: 1),
                  FindingRow(finding: f, inspection: i),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => showAddFindingSheet(context, ref, i.id),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Finding'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Documents

class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab({required this.inspection});

  final Inspection inspection;

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty || !context.mounted) return;
      for (final f in files) {
        final bytes = await f.length() ?? 0;
        final id = ref
            .read(documentsProvider.notifier)
            .add(
              assetId: inspection.assetId,
              name: f.name,
              type: f.name.toLowerCase().endsWith('.jpg') || f.name.toLowerCase().endsWith('.png')
                  ? DocType.photo
                  : DocType.serviceReport,
              sizeMb: bytes / (1024 * 1024),
              description: 'Uploaded with ${inspection.id}',
              filePath: f.path,
            );
        ref.read(inspectionsProvider.notifier).linkDocument(inspection.id, id);
      }
      if (context.mounted) context.showSnack('${files.length} document${files.length == 1 ? '' : 's'} uploaded');
    } catch (_) {
      if (context.mounted) context.showSnack('Could not open files. Allow file access and try again.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);
    final linked = [for (final id in inspection.documentIds) ?docs.doc(id)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: linked.isEmpty
              ? const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'No documents linked',
                  message: 'Upload reports, certificates or photos for this inspection.',
                )
              : Column(
                  children: [
                    for (final d in linked)
                      ListTile(
                        leading: Icon(
                          d.isPdf ? Icons.picture_as_pdf_rounded : Icons.description_outlined,
                          color: d.isPdf ? AppColors.red : AppColors.primary,
                        ),
                        title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                        subtitle: Text(
                          '${d.type} · ${d.sizeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(Routes.documentDetail(d.id)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _upload(context, ref),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Upload Document'),
        ),
      ],
    );
  }
}
