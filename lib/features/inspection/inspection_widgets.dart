import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/checklist/checklist.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/inspection.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/inspections_repository.dart';
import '../assets/asset_ui.dart';
import '../maintenance/create_work_order_screen.dart';

/// Hub row: photo, INS number, asset + type, location, status chip (Overdue / Due Today / …) and date.
class InspectionRow extends ConsumerWidget {
  const InspectionRow({super.key, required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = inspection;
    final asset = ref.watch(assetByIdProvider(i.assetId));
    return AssetListTile(
      title: i.id,
      subtitle: i.title,
      location: asset?.location ?? i.assetId,
      imagePath: asset?.imagePath,
      fallbackIcon: asset == null ? Icons.fact_check_outlined : assetIcon(asset),
      trailingTop: StatusChip(InspectionQueries.displayStatus(i)),
      trailingBottom: DemoClock.formatDate(i.dueAt),
      onTap: () => context.push(Routes.inspectionDetail(i.id)),
    );
  }
}

/// Default severity for a negative answer: the last (worst) option is High, others Medium.
String severityFor(CheckItem item) {
  if (item.type == CheckType.choice && item.options.isNotEmpty && item.value == item.options.last) return 'High';
  return 'Medium';
}

/// "Add Finding": description, severity and photos. Returns the new finding ID.
Future<String?> showAddFindingSheet(BuildContext context, WidgetRef ref, String inspectionId, {CheckItem? item}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FindingSheet(inspectionId: inspectionId, item: item),
    );

class _FindingSheet extends ConsumerStatefulWidget {
  const _FindingSheet({required this.inspectionId, this.item});

  final String inspectionId;
  final CheckItem? item;

  @override
  ConsumerState<_FindingSheet> createState() => _FindingSheetState();
}

class _FindingSheetState extends ConsumerState<_FindingSheet> {
  late final _title = TextEditingController(text: _defaultTitle);
  final _description = TextEditingController();
  late String _severity = widget.item == null ? 'Medium' : severityFor(widget.item!);
  List<String> _photos = [];
  String? _error;

  String get _defaultTitle {
    final i = widget.item;
    if (i == null) return '';
    if (i.type == CheckType.number || i.type == CheckType.tick) {
      return '${i.label}: ${i.type == CheckType.tick ? i.reading : i.value} ${i.unit ?? ''} (normal ${i.rangeLabel})';
    }
    return '${i.label}: ${i.value}';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the finding a short title');
      return;
    }
    final id = ref
        .read(inspectionsProvider.notifier)
        .addFinding(
          widget.inspectionId,
          title: _title.text.trim(),
          severity: _severity,
          description: _description.text.trim(),
          questionCode: widget.item?.code,
          photos: _photos,
        );
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return sheetFrame(context, [
      SheetTitle(
        'Add Finding',
        subtitle: widget.item == null ? 'Record a problem found during the inspection' : 'Item ${widget.item!.code}',
      ),
      TextField(
        controller: _title,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Finding *', errorText: _error),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _description,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Description', hintText: 'What did you see? What should be done?'),
      ),
      const SizedBox(height: 12),
      Text('Severity', style: AppText.bodyStrong),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: [
          for (final s in findingSeverities)
            ChoiceChip(
              label: Text(s),
              selected: _severity == s,
              onSelected: (_) => setState(() => _severity = s),
              selectedColor: ChipTone.forPriority(s).background,
              labelStyle: TextStyle(
                color: _severity == s ? ChipTone.forPriority(s).foreground : AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      PhotoStrip(
        title: 'Photos',
        photos: _photos,
        thumbWidth: 96,
        thumbHeight: 72,
        onAdd: (p) => setState(() => _photos = [..._photos, p]),
        onRemove: (i) => setState(() => _photos = [..._photos]..removeAt(i)),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: _save, child: const Text('Save Finding')),
          ),
        ],
      ),
    ]);
  }
}

/// Opens Create Work Order prefilled from the finding (asset, title, severity → priority).
void createWorkOrderForFinding(BuildContext context, Inspection ins, Finding f) {
  context.push(
    Routes.createWorkOrder(assetId: ins.assetId),
    extra: WoPrefill(
      title: f.title,
      description: [
        'From ${ins.id} (${ins.title})${f.questionCode == null ? '' : ', item ${f.questionCode}'}.',
        if (f.description.isNotEmpty) f.description,
      ].join(' '),
      priority: f.severity,
      findingId: f.id,
    ),
  );
}

/// Finding row: severity chip, title, inspection + asset, status chip.
class FindingRow extends ConsumerWidget {
  const FindingRow({super.key, required this.finding, required this.inspection});

  final Finding finding;
  final Inspection inspection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetByIdProvider(inspection.assetId));
    return AssetListTile(
      title: finding.title,
      titleLeading: PriorityChip(finding.severity),
      subtitle: '${inspection.assetId} · ${asset?.name ?? ''}',
      imagePath: finding.photos.isNotEmpty ? finding.photos.first : asset?.imagePath,
      fallbackIcon: Icons.report_problem_outlined,
      details: [
        Text(
          '${finding.id} · ${inspection.id} · ${DemoClock.formatDate(finding.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption,
        ),
      ],
      trailingTop: StatusChip(finding.status, tone: _tone(finding.status)),
      onTap: () => context.push(Routes.finding(finding.id)),
    );
  }

  static ChipTone _tone(String s) => switch (s) {
    FindingStatus.open => ChipTone.red,
    FindingStatus.actionTaken => ChipTone.blue,
    _ => ChipTone.green,
  };
}
