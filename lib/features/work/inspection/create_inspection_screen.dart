import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/checklist/checklist.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/inspections_mock.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';

/// Create Inspection: asset, template, due date and time, inspector.
class CreateInspectionScreen extends ConsumerStatefulWidget {
  const CreateInspectionScreen({super.key, this.assetId});

  final String? assetId;

  @override
  ConsumerState<CreateInspectionScreen> createState() => _CreateInspectionScreenState();
}

class _CreateInspectionScreenState extends ConsumerState<CreateInspectionScreen> {
  late String? _assetId = widget.assetId == null ? null : ref.read(assetsProvider).byCode(widget.assetId!)?.id;
  String? _template;
  late DateTime _due = DateTime(DemoClock.today.year, DemoClock.today.month, DemoClock.today.day + 1, 10);
  late String _inspectorId = ref.read(currentUserProvider).id;
  final _errors = <String, String>{};

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: _due.isBefore(DemoClock.today) ? DemoClock.today : _due,
      firstDate: DemoClock.today,
      lastDate: DemoClock.today.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      useRootNavigator: false,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    setState(() {
      _due = DateTime(d.year, d.month, d.day, t?.hour ?? _due.hour, t?.minute ?? _due.minute);
      _errors.remove('due');
    });
  }

  Future<void> _save() async {
    setState(() {
      _errors
        ..clear()
        ..addAll({
          if (_assetId == null) 'asset': 'Choose the asset to inspect',
          if (_template == null) 'template': 'Choose a checklist template',
          if (_due.isBefore(DemoClock.now)) 'due': 'The due time must be in the future',
        });
    });
    if (_errors.isNotEmpty) return;
    final id = ref
        .read(inspectionsProvider.notifier)
        .create(assetId: _assetId!, template: _template!, dueAt: _due, inspectorId: _inspectorId);
    final open = await showSuccessSheet(
      context,
      title: 'Inspection scheduled',
      message: '$id is due ${DemoClock.formatDateTime(_due)}.',
      primaryLabel: 'Open Inspection',
      secondaryLabel: 'Done',
    );
    if (!mounted) return;
    open ? context.pushReplacement(Routes.inspectionDetail(id)) : context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetId == null ? null : ref.watch(assetByIdProvider(_assetId!));
    final people = ref.watch(peopleProvider);
    final template = _template == null ? null : inspectionTemplates[_template];
    final sections = template?.$3();
    Widget error(String key) => _errors[key] == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_errors[key]!, style: AppText.caption.copyWith(color: AppColors.red)),
          );
    return AppScaffold(
      bottomActions: Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: _save, child: const Text('Schedule')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const PageTitle(title: 'Create Inspection', subtitle: 'Pick the asset, checklist, time and inspector'),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Asset',
            required: true,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: asset == null
                  ? ListTile(
                      leading: Icon(Icons.search_rounded, color: AppColors.primary),
                      title: const Text('Select asset'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickAsset,
                    )
                  : AssetListTile(
                      title: asset.id,
                      subtitle: asset.name,
                      location: asset.location,
                      imagePath: asset.imagePath,
                      fallbackIcon: assetIcon(asset),
                      trailingTop: Text('Change', style: TextStyle(color: AppColors.primary)),
                      onTap: _pickAsset,
                    ),
            ),
          ),
          error('asset'),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Checklist template',
            required: true,
            child: DropdownButtonFormField<String>(
              initialValue: _template,
              isExpanded: true,
              hint: Text('Select template', style: hintStyle),
              decoration: InputDecoration(errorText: _errors['template']),
              items: [for (final t in inspectionTemplates.keys) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() {
                _template = v;
                _errors.remove('template');
              }),
            ),
          ),
          if (sections != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${sections.length} sections · ${sections.totalItems} items: ${sections.map((s) => s.title).join(', ')}',
                style: AppText.caption,
              ),
            ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Due date and time',
            required: true,
            child: InkWell(
              onTap: _pickDue,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: InputDecoration(
                  errorText: _errors['due'],
                  prefixIcon: const Icon(Icons.event_rounded, size: 18),
                ),
                child: Text(DemoClock.formatDateTime(_due), style: AppText.body),
              ),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Inspector',
            required: true,
            child: DropdownButtonFormField<String>(
              initialValue: _inspectorId,
              isExpanded: true,
              items: [
                for (final p in people)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.labelWithRole, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _inspectorId = v ?? _inspectorId),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAsset() async {
    final id = await showAssetPicker(context, selectedId: _assetId);
    if (id != null) {
      setState(() {
        _assetId = id;
        _errors.remove('asset');
      });
    }
  }
}
