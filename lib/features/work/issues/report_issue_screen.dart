import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/issue.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/features/work/maintenance/create_work_order_screen.dart';

/// Report Issue opened from another module (e.g. a production order / unit on the shop floor).
class IssuePrefill {
  const IssuePrefill({required this.reference, this.type, this.title, this.description, this.location});

  /// What the issue is about when it is not an asset, e.g. "MO-2026-0018" (stored as the issue's asset ref).
  final String reference;
  final String? type;
  final String? title;
  final String? description;
  final String? location;
}

/// Icon per issue type (dropdown).
IconData issueTypeIcon(String type) => switch (type) {
  'Breakdown' => Icons.build_rounded,
  'Malfunction' => Icons.settings_suggest_rounded,
  'Damage' => Icons.broken_image_outlined,
  'Leakage' => Icons.water_drop_outlined,
  'Safety Hazard' => Icons.health_and_safety_outlined,
  'Electrical' => Icons.electric_bolt_rounded,
  'Production' => Icons.precision_manufacturing_outlined,
  _ => Icons.more_horiz_rounded,
};

/// Report Issue / Defect (middle screen of design/10_issues_defects.jpg).
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key, this.assetId, this.prefill});

  final String? assetId;
  final IssuePrefill? prefill;

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  late String? _assetId = widget.assetId == null ? null : ref.read(assetsProvider).byCode(widget.assetId!)?.id;
  late String? _type = widget.prefill?.type;
  String? _priority;
  late final _title = TextEditingController(text: widget.prefill?.title);
  late final _description = TextEditingController(text: widget.prefill?.description);

  /// Picked or scanned location; until then the issue takes the asset's (or the prefill's) location.
  LocationValue _location = LocationValue.empty;
  bool _locationEdited = false;
  late String _reporterId = ref.read(currentUserProvider).id;
  List<String> _photos = [];
  final _errors = <String, String>{};

  Asset? get _asset => _assetId == null ? null : ref.read(assetByIdProvider(_assetId!));

  /// The prefill's or the asset's location text.
  String? get _defaultLocation => widget.prefill?.location ?? _asset?.location;

  static const _priorities = [
    ('Critical', Icons.error_rounded),
    ('High', Icons.place_rounded),
    ('Medium', Icons.warning_rounded),
    ('Low', Icons.check_circle_rounded),
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _assetId != widget.assetId ||
      _type != null ||
      _priority != null ||
      _title.text.isNotEmpty ||
      _description.text.isNotEmpty ||
      _photos.isNotEmpty;

  void _setAsset(String id) {
    setState(() {
      _assetId = id;
      _errors.remove('asset');
    });
  }

  Future<void> _scanAsset() async {
    final code = await showScanCapture(context, suggestions: const ['GEN-00045', 'AHU-03', 'FL-012']);
    if (code == null || !mounted) return;
    final a = ref.read(assetsProvider).byCode(code);
    if (a == null) {
      context.showSnack('No asset matches "$code"');
      return;
    }
    _setAsset(a.id);
  }

  Future<void> _pickReporter() async {
    final people = ref.read(peopleProvider);
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => sheetFrame(sheet, [
        const SheetTitle('Reported By', subtitle: 'Report on behalf of a colleague'),
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
            trailing: p.id == _reporterId ? Icon(Icons.check_rounded, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(sheet, p.id),
          ),
      ]),
    );
    if (id != null) setState(() => _reporterId = id);
  }

  Future<void> _cancel() async {
    if (_dirty) {
      final discard = await showConfirmDialog(
        context,
        title: 'Discard this report?',
        message: 'What you entered will be lost.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    context.pop();
  }

  Future<void> _submit() async {
    setState(() {
      _errors
        ..clear()
        ..addAll({
          if (_assetId == null && widget.prefill == null) 'asset': 'Select the asset',
          if (_type == null) 'type': 'Choose the issue type',
          if (_priority == null) 'priority': 'Choose the priority',
          if (_title.text.trim().isEmpty) 'title': 'Enter a short title',
          if (_description.text.trim().length < 10) 'description': 'Describe the issue (at least 10 characters)',
        });
    });
    if (_errors.isNotEmpty) {
      context.showSnack('Please complete the required fields');
      return;
    }
    final issues = ref.read(issuesProvider.notifier);
    final id = issues.report(
      assetId: _assetId ?? widget.prefill!.reference,
      title: _title.text.trim(),
      type: _type!,
      priority: _priority!,
      description: _description.text.trim(),
      location: (_locationEdited ? _location.path : null) ?? _defaultLocation ?? '',
      photos: _photos,
      reporterId: _reporterId,
    );
    final createWo = await showSuccessSheet(
      context,
      title: 'Issue $id submitted',
      message: _priority == 'Critical'
          ? 'A critical alert was sent to the control room.'
          : 'The maintenance team has been notified.',
      primaryLabel: 'Create Work Order now',
      secondaryLabel: 'Done',
    );
    if (!mounted) return;
    if (createWo) {
      final issue = issues.byId(id)!;
      context.pushReplacement(
        Routes.createWorkOrder(assetId: ref.read(assetByIdProvider(issue.assetId)) == null ? null : issue.assetId),
        extra: WoPrefill(
          title: issue.title,
          description: 'Created from $id. ${issue.description}',
          priority: issue.priority,
          issueId: id,
          photos: issue.photos,
          workType: issue.type == 'Breakdown' ? 'Breakdown' : 'Corrective',
        ),
      );
    } else {
      context.pushReplacement(Routes.issueDetail(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetId == null ? null : ref.watch(assetByIdProvider(_assetId!));
    final reporter = ref.watch(personByIdProvider(_reporterId));
    Widget error(String key) => _errors[key] == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_errors[key]!, style: AppText.caption.copyWith(color: AppColors.red)),
          );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AppScaffold(
        header: AppHeader(onBack: _cancel),
        bottomActions: Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _submit, child: const Text('Submit Issue')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            PageTitle(
              leading: Icon(Icons.camera_alt_outlined, color: AppColors.text, size: 22),
              title: 'Report Issue / Defect',
              subtitle: 'Capture details of the issue to create a service request',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: FieldLabel('Asset', required: true)),
                ScanSuffix(onTap: _scanAsset, tooltip: 'Scan asset tag'),
              ],
            ),
            const SizedBox(height: 6),
            AppCard(
              padding: EdgeInsets.zero,
              onTap: () async {
                final id = await showAssetPicker(context, selectedId: _assetId);
                if (id != null) _setAsset(id);
              },
              child: asset == null && widget.prefill != null
                  ? ListTile(
                      leading: Icon(Icons.precision_manufacturing_outlined, color: AppColors.primary),
                      title: Text(widget.prefill!.reference, style: AppText.bodyStrong),
                      subtitle: Text('Production order · tap to link an asset instead', style: AppText.caption),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    )
                  : asset == null
                  ? ListTile(
                      leading: Icon(Icons.search_rounded, color: AppColors.primary),
                      title: const Text('Select asset'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 60),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(asset.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                                Text(
                                  asset.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.secondary,
                                ),
                                IconLine(icon: Icons.location_on_outlined, text: asset.location),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
            ),
            error('asset'),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Issue Type',
              required: true,
              child: DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                hint: Text('Select type', style: hintStyle),
                decoration: InputDecoration(errorText: _errors['type']),
                items: [
                  for (final t in issueTypes)
                    DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(issueTypeIcon(t), size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _type = v;
                  _errors.remove('type');
                }),
              ),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Priority', required: true),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final (n, (p, icon)) in _priorities.indexed) ...[
                  if (n > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _PriorityCard(
                      label: p,
                      icon: icon,
                      selected: _priority == p,
                      onTap: () => setState(() {
                        _priority = p;
                        _errors.remove('priority');
                      }),
                    ),
                  ),
                ],
              ],
            ),
            error('priority'),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Issue Title',
              required: true,
              child: TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: InputDecoration(
                  hintText: 'e.g. Generator not starting',
                  errorText: _errors['title'],
                  counterText: '',
                ),
                onChanged: (_) => _errors.remove('title'),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Description',
              required: true,
              child: TextField(
                controller: _description,
                maxLines: 4,
                maxLength: issueDescriptionMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What happened? What did you check?',
                  errorText: _errors['description'],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Location', style: AppText.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            // A location tag (QR, NFC or the scanner trigger) fills it; an asset tag fills the asset.
            LocationField(
              value: _locationEdited
                  ? _location
                  : LocationValue.parse(_defaultLocation, ref.watch(locationsProvider).value ?? const []) ??
                        LocationValue.empty,
              required: const {},
              onAsset: (id) {
                _setAsset(id);
                context.showSnack('Asset filled from tag: $id');
              },
              onChanged: (v) => setState(() {
                _location = v;
                _locationEdited = true;
              }),
            ),
            if (!_locationEdited && _defaultLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Defaults to: $_defaultLocation', style: AppText.caption),
              ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Reported By',
              child: InkWell(
                onTap: _pickReporter,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_rounded, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'Change reporter',
                      onPressed: _pickReporter,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                  child: Text(reporter?.name ?? '—', style: AppText.body),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PhotoStrip(
              title: 'Attachments',
              photos: _photos,
              thumbWidth: 96,
              thumbHeight: 76,
              allowVideo: true,
              addLabel: 'Add Photo / Video',
              onAdd: (p) => setState(() => _photos = [..._photos, p]),
              onRemove: (i) => setState(() => _photos = [..._photos]..removeAt(i)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = ChipTone.forPriority(label);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: tone.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? tone.foreground : Colors.transparent, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, color: tone.foreground, size: 22),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: tone.foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
