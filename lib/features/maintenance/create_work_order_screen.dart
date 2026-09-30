import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../common/asset_picker.dart';

const _priorities = ['Critical', 'High', 'Medium', 'Low'];
const _workTypes = ['Breakdown', 'Corrective', 'Scheduled', 'Inspection', 'Service', 'Calibration'];

/// Create Work Order: asset, title, priority, type, due date and assignee.
/// Saving adds the WO to the Maintenance list.
class CreateWorkOrderScreen extends ConsumerStatefulWidget {
  const CreateWorkOrderScreen({super.key, this.assetId});

  final String? assetId;

  @override
  ConsumerState<CreateWorkOrderScreen> createState() => _CreateWorkOrderScreenState();
}

class _CreateWorkOrderScreenState extends ConsumerState<CreateWorkOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late String? _assetId = widget.assetId;
  String _priority = 'Medium';
  String _workType = 'Corrective';
  bool _preventive = false;
  late DateTime _due = DateTime(DemoClock.now.year, DemoClock.now.month, DemoClock.now.day + 1, 17);
  String? _assigneeId;
  bool _assetError = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAsset() async {
    final id = await showAssetPicker(context, selectedId: _assetId);
    if (id == null) return;
    setState(() {
      _assetId = id;
      _assetError = false;
    });
  }

  Future<void> _pickDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DemoClock.today,
      lastDate: DemoClock.today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    setState(
      () => _due = DateTime(date.year, date.month, date.day, time?.hour ?? _due.hour, time?.minute ?? _due.minute),
    );
  }

  Future<void> _save() async {
    final validForm = _formKey.currentState!.validate();
    setState(() => _assetError = _assetId == null);
    if (!validForm || _assetId == null) return;
    if (_due.isBefore(DemoClock.now)) {
      context.showSnack('The due date must be in the future');
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final id = ref
        .read(workOrdersProvider.notifier)
        .create(
          assetId: _assetId!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          priority: _priority,
          category: _preventive ? 'Preventive Maintenance' : 'Corrective Maintenance',
          workType: _workType,
          dueAt: _due,
          assigneeId: _assigneeId,
        );
    setState(() => _saving = false);
    final open = await showSuccessSheet(
      context,
      title: 'Work order created',
      message: '$id has been added to Maintenance.',
      primaryLabel: 'View Work Order',
      secondaryLabel: 'Done',
    );
    if (!mounted) return;
    if (open) {
      context.pushReplacement(Routes.workOrder(id));
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetId == null ? null : ref.watch(assetByIdProvider(_assetId!));
    final people = ref.watch(peopleProvider);
    Widget label(String t, {bool required = true}) => Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 14),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: t),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.red),
              ),
          ],
        ),
        style: AppText.bodyStrong.copyWith(fontSize: 13),
      ),
    );

    return AppScaffold(
      bottomActions: Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('Create Work Order'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const PageTitle(
              title: 'Create Work Order',
              subtitle: 'Raise corrective or preventive maintenance',
              help:
                  'Choose the asset, describe the work, set the priority and due date, and optionally assign '
                  'a technician. The work order appears in Maintenance and on Home straight away.',
            ),
            label('Asset'),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _assetError ? AppColors.red : AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: asset == null
                  ? ListTile(
                      leading: const IconSquare(icon: Icons.qr_code_scanner_rounded, tone: TileTone.lavender, size: 40),
                      title: const Text('Select an asset', style: AppText.bodyStrong),
                      subtitle: const Text('Search by ID, name or location', style: AppText.caption),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickAsset,
                    )
                  : AssetListTile(
                      title: asset.id,
                      subtitle: asset.name,
                      location: asset.location,
                      imagePath: asset.imagePath,
                      trailingTop: StatusChip(asset.status),
                      onTap: _pickAsset,
                    ),
            ),
            // Always present so the fields below keep their list position (and their error state).
            _assetError
                ? const Padding(
                    padding: EdgeInsets.only(top: 6, left: 12),
                    child: Text('Select the asset', style: TextStyle(color: AppColors.red, fontSize: 12)),
                  )
                : const SizedBox.shrink(),
            label('Title'),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Generator – High vibration'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a short title' : null,
            ),
            label('Description', required: false),
            TextFormField(
              controller: _description,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What needs to be done?'),
            ),
            label('Priority'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _priorities)
                  ChoiceChip(
                    label: Text(p),
                    selected: _priority == p,
                    onSelected: (_) => setState(() => _priority = p),
                    selectedColor: ChipTone.forPriority(p).background,
                    labelStyle: TextStyle(
                      color: _priority == p ? ChipTone.forPriority(p).foreground : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: _priority == p ? ChipTone.forPriority(p).foreground : AppColors.border),
                    showCheckmark: false,
                  ),
              ],
            ),
            label('Type'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Corrective'), icon: Icon(Icons.build_rounded, size: 16)),
                ButtonSegment(value: true, label: Text('Preventive'), icon: Icon(Icons.event_repeat_rounded, size: 16)),
              ],
              selected: {_preventive},
              onSelectionChanged: (s) => setState(() {
                _preventive = s.first;
                _workType = _preventive ? 'Scheduled' : 'Corrective';
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _workType,
              decoration: const InputDecoration(labelText: 'Work type'),
              items: [for (final t in _workTypes) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => _workType = v ?? _workType),
            ),
            label('Due date'),
            InkWell(
              onTap: _pickDue,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                ),
                child: Text(DemoClock.formatDateTime(_due), style: AppText.body),
              ),
            ),
            label('Assign to', required: false),
            DropdownButtonFormField<String?>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(hintText: 'Unassigned'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                for (final p in people) DropdownMenuItem<String?>(value: p.id, child: Text(p.labelWithRole)),
              ],
              onChanged: (v) => setState(() => _assigneeId = v),
            ),
          ],
        ),
      ),
    );
  }
}
