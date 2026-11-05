import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/reference/technical_templates.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/validation/asset_registration_validator.dart';
import 'package:asset360_mobile/features/assets/asset_actions.dart';
import 'package:asset360_mobile/features/more/registration/live_options.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Step 5 Additional Information (AssetAdditionalInformationDto): Technical Details (template per
/// asset type, technical_templates.dart) | Operational Details | Custom Fields | Attachments,
/// then the phone-only links (Parent Asset, IoT device). Nothing here is required; [errors] are
/// the backend's value rules ("Technical.Weight", "Operational.OperatingHoursPerDay", "CustomFields",
/// "Attachments" …). API mode: the unit / shift / standard lists come from the server.
class StepAdditional extends ConsumerStatefulWidget {
  const StepAdditional({super.key, required this.form, required this.edit, this.errors = const {}});

  final AssetRegistration form;
  final FormEdit edit;
  final Map<String, String> errors;

  @override
  ConsumerState<StepAdditional> createState() => _StepAdditionalState();
}

class _StepAdditionalState extends ConsumerState<StepAdditional> {
  int _tab = 0;

  Map<String, String> get _errors => widget.errors;

  /// The tab that holds the first error (new errors switch to it).
  static int? _tabOf(Map<String, String> errors) {
    for (final k in errors.keys) {
      if (k.startsWith('Technical.')) return 0;
      if (k.startsWith('Operational.')) return 1;
      if (k == 'CustomFields') return 2;
      if (k == 'Attachments') return 3;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tab = _tabOf(widget.errors) ?? 0;
  }

  @override
  void didUpdateWidget(StepAdditional old) {
    super.didUpdateWidget(old);
    final tab = _tabOf(widget.errors);
    if (tab != null && !mapEquals(old.errors, widget.errors) && !_errorsOnTab(_tab)) _tab = tab;
  }

  bool _errorsOnTab(int tab) => widget.errors.keys.any((k) => _tabOf({k: ''}) == tab);

  Widget _errorLine(String? message) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(message, style: const TextStyle(color: AppColors.red, fontSize: 12)),
        );

  @override
  Widget build(BuildContext context) {
    final info = widget.form.additionalInformation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentTabs(
          tabs: [
            const SegmentTab('Technical Details'),
            const SegmentTab('Operational Details'),
            SegmentTab('Custom Fields', count: info.customFields.length),
            SegmentTab('Attachments', count: info.attachments.length),
          ],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        switch (_tab) {
          0 => _technical(),
          1 => _operational(),
          2 => _customFields(),
          _ => DocumentUploadField(
            label: 'Attachments',
            documents: info.attachments,
            error: _errors['Attachments'],
            onChanged: (v) => widget.edit(() => info.attachments = v),
            onAdded: (d) => widget.edit(() => info.attachments = [...info.attachments, d]),
          ),
        },
        const SizedBox(height: 8),
        LocalExtrasCard(form: widget.form, edit: widget.edit),
      ],
    );
  }

  Widget _technical() {
    final edit = widget.edit;
    final type = widget.form.classification.assetType;
    final t = widget.form.additionalInformation.technical;
    final template = technicalTemplateFor(type);
    final lists = RegLists(ref);
    void setSpec(SpecField f, String? v) => edit(() => t.setSpec(f.name, v, f.unit));
    Widget unitPair(Widget value, Widget unit) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: value),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: unit),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (template.specs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: IconLine(
              icon: Icons.info_outline_rounded,
              text: type == null
                  ? 'Choose the asset type in step 2 to see its technical fields.'
                  : 'No technical template for $type yet. Add the details in Technical Remarks.',
            ),
          ),
        for (final f in template.specs)
          if (f.options.isNotEmpty)
            RegDropdown.source(
              f.serverList == null
                  ? OptionSource(f.options)
                  : lists.additional(f.serverList!, f.options, f.name.toLowerCase()),
              label: f.unit == null ? f.name : '${f.name} (${f.unit})',
              value: t.spec(f.name)?.value,
              onChanged: (v) => setSpec(f, v),
            )
          else
            RegTextField(
              label: f.name,
              value: t.spec(f.name)?.value,
              hint: f.hint,
              keyboardType: f.numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
              suffix: f.unit == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(widthFactor: 1, child: Text(f.unit!, style: AppText.caption)),
                    ),
              validator: f.numeric
                  ? (v) => (v ?? '').trim().isEmpty || RegNumberField.parse(v) != null ? null : 'Enter a number'
                  : null,
              onChanged: (v) => setSpec(f, v),
            ),
        if (template.dimensions) ...[
          const FieldLabel('Dimensions (L × W × H)'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value, set) in [
                ('L', t.dimensionLength, (double? v) => t.dimensionLength = v),
                ('W', t.dimensionWidth, (double? v) => t.dimensionWidth = v),
                ('H', t.dimensionHeight, (double? v) => t.dimensionHeight = v),
              ]) ...[
                Expanded(
                  child: RegNumberField(label: label, value: value, onChanged: (v) => edit(() => set(v))),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: RegDropdown.source(
                  lists.dimensionUnits,
                  label: 'Unit',
                  value: t.dimensionUnit,
                  onChanged: (v) => edit(() => t.dimensionUnit = v),
                ),
              ),
            ],
          ),
          _errorLine(_errors['Technical.Dimensions']),
        ],
        if (template.weight)
          unitPair(
            RegNumberField(
              label: 'Weight',
              value: t.weight,
              error: _errors['Technical.Weight'],
              onChanged: (v) => edit(() => t.weight = v),
            ),
            RegDropdown.source(
              lists.weightUnits,
              label: 'Weight Unit',
              value: t.weightUnit,
              onChanged: (v) => edit(() => t.weightUnit = v),
            ),
          ),
        if (template.lifespan)
          unitPair(
            RegNumberField(
              label: 'Expected Lifespan',
              value: t.expectedLifespan,
              decimals: false,
              error: _errors['Technical.ExpectedLifespan'],
              onChanged: (v) => edit(() => t.expectedLifespan = v?.toInt()),
            ),
            RegDropdown.source(
              lists.lifespanUnits,
              label: 'Lifespan Unit',
              value: t.expectedLifespanUnit,
              onChanged: (v) => edit(() => t.expectedLifespanUnit = v),
            ),
          ),
        RegTextField(
          label: 'Technical Remarks',
          value: t.technicalRemarks,
          maxLines: 3,
          maxLength: RegistrationValidator.remarksMax,
          error: _errors['Technical.TechnicalRemarks'],
          onChanged: (v) => edit(() => t.technicalRemarks = v),
        ),
      ],
    );
  }

  Widget _operational() {
    final edit = widget.edit;
    final o = widget.form.additionalInformation.operational;
    final lists = RegLists(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: RegNumberField(
                label: 'Operating Hours (Per Day)',
                value: o.operatingHoursPerDay,
                error: _errors['Operational.OperatingHoursPerDay'],
                onChanged: (v) => edit(() => o.operatingHoursPerDay = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: RegDropdown.source(
                lists.operatingHoursUnits,
                label: 'Unit',
                value: o.operatingHoursUnit,
                onChanged: (v) => edit(() => o.operatingHoursUnit = v),
              ),
            ),
          ],
        ),
        RegDropdown.source(
          lists.operatingShifts,
          label: 'Operating Shift',
          value: o.operatingShift,
          onChanged: (v) => edit(() => o.operatingShift = v),
        ),
        RegDropdown.source(
          lists.utilizations,
          label: 'Utilization',
          value: o.utilization,
          onChanged: (v) => edit(() => o.utilization = v),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: RegNumberField(
                label: 'Maintenance Frequency',
                value: o.maintenanceFrequency,
                decimals: false,
                hint: 'Every …',
                error: _errors['Operational.MaintenanceFrequency'],
                onChanged: (v) => edit(() => o.maintenanceFrequency = v?.toInt()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: RegDropdown.source(
                lists.maintenanceFrequencyUnits,
                label: 'Frequency Unit',
                value: o.maintenanceFrequencyUnit,
                onChanged: (v) => edit(() => o.maintenanceFrequencyUnit = v),
              ),
            ),
          ],
        ),
        RegDateField(
          label: 'Last Maintenance Date',
          value: o.lastMaintenanceDate,
          onPicked: (d) => edit(() => o.lastMaintenanceDate = d),
        ),
        RegDateField(
          label: 'Next Maintenance Date',
          value: o.nextMaintenanceDate,
          error: _errors['Operational.NextMaintenanceDate'],
          onPicked: (d) => edit(() => o.nextMaintenanceDate = d),
        ),
        RegMultiChips.source(
          lists.complianceStandards,
          label: 'Compliance Standards',
          selected: o.complianceStandards,
          onChanged: (v) => edit(() => o.complianceStandards = v),
        ),
      ],
    );
  }

  Widget _customFields() {
    final info = widget.form.additionalInformation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _errorLine(_errors['CustomFields']),
        if (info.customFields.isEmpty)
          const EmptyState(
            icon: Icons.dashboard_customize_outlined,
            title: 'No custom fields',
            message: 'Add any extra detail this asset needs, e.g. Fuel Card No.',
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  color: AppColors.greyBg,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text('Field', style: AppText.caption)),
                      Expanded(flex: 5, child: Text('Value', style: AppText.caption)),
                      const SizedBox(width: 72),
                    ],
                  ),
                ),
                for (final (i, f) in info.customFields.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.fieldName, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                              Text(f.fieldType ?? 'Text', style: AppText.caption),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(customFieldDisplay(f), style: AppText.body.copyWith(fontSize: 13)),
                        ),
                        IconButton(
                          tooltip: 'Edit ${f.fieldName}',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editField(i),
                        ),
                        IconButton(
                          tooltip: 'Remove ${f.fieldName}',
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          onPressed: () => widget.edit(() => info.customFields = [...info.customFields]..removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _editField(null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Field'),
        ),
      ],
    );
  }

  /// Add (index null) or edit a custom field.
  Future<void> _editField(int? index) async {
    final info = widget.form.additionalInformation;
    final existing = index == null ? null : info.customFields[index];
    final result = await showModalBottomSheet<AssetCustomField>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomFieldSheet(
        initial: existing,
        types: RegLists(ref).customFieldTypes,
        taken: [
          for (final f in info.customFields)
            if (f != existing) f.fieldName.toLowerCase(),
        ],
      ),
    );
    if (result == null) return;
    widget.edit(() {
      final list = [...info.customFields];
      index == null ? list.add(result) : list[index] = result;
      info.customFields = list;
    });
  }
}

class _CustomFieldSheet extends StatefulWidget {
  const _CustomFieldSheet({required this.initial, required this.taken, required this.types});

  final AssetCustomField? initial;
  final List<String> taken;

  /// Field types: local list, or the server's (with Yes/No) in API mode.
  final OptionSource types;

  @override
  State<_CustomFieldSheet> createState() => _CustomFieldSheetState();
}

/// Add Field: Field Name, Field Type (Text / Number / Date / Dropdown, and Yes/No from the server)
/// and Value. A Dropdown field asks for its options first (comma separated); only the chosen value
/// is stored (the backend's AssetCustomFieldDto has fieldName, fieldType and value).
class _CustomFieldSheetState extends State<_CustomFieldSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.fieldName);
  late final _value = TextEditingController(text: _isType(CustomFieldType.date) ? null : widget.initial?.value);
  late final _options = TextEditingController(text: _isType(CustomFieldType.dropdown) ? widget.initial?.value : null);
  late String _type = widget.types.options.contains(widget.initial?.fieldType)
      ? widget.initial!.fieldType!
      : CustomFieldType.text;
  late DateTime? _date = _isType(CustomFieldType.date) ? DateTime.tryParse(widget.initial?.value ?? '') : null;
  late String? _choice = _isType(CustomFieldType.dropdown) || _isType(CustomFieldType.yesNo)
      ? widget.initial?.value
      : null;

  bool _isType(String t) => widget.initial?.fieldType == t;

  List<String> get _optionList => {
    for (final o in _options.text.split(','))
      if (o.trim().isNotEmpty) o.trim(),
  }.toList();

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _options.dispose();
    super.dispose();
  }

  String? get _result => switch (_type) {
    CustomFieldType.date => _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!),
    CustomFieldType.dropdown || CustomFieldType.yesNo => _choice,
    _ => _value.text.trim().isEmpty ? null : _value.text.trim(),
  };

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: sheetFrame(context, [
      SheetTitle(widget.initial == null ? 'Add Field' : 'Edit Field'),
      LabeledField(
        label: 'Field Name',
        required: true,
        child: TextFormField(
          controller: _name,
          autofocus: widget.initial == null,
          style: inputStyle,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Asset Color'),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return 'Field Name is required.';
            return widget.taken.contains(s.toLowerCase()) ? 'This field already exists' : null;
          },
        ),
      ),
      regGap,
      RegDropdown.source(
        widget.types,
        label: 'Field Type',
        value: _type,
        onChanged: (v) => setState(() {
          if (v != _type && (v == CustomFieldType.yesNo || _type == CustomFieldType.yesNo)) _choice = null;
          _type = v!;
        }),
      ),
      switch (_type) {
        CustomFieldType.yesNo => RegDropdown(
          label: 'Value',
          value: _choice,
          options: const ['Yes', 'No'],
          onChanged: (v) => setState(() => _choice = v),
        ),
        CustomFieldType.date => RegDateField(label: 'Value', value: _date, onPicked: (d) => setState(() => _date = d)),
        CustomFieldType.dropdown => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Options',
              child: TextFormField(
                controller: _options,
                style: inputStyle,
                decoration: const InputDecoration(hintText: 'e.g. Yellow, Green, Grey'),
                onChanged: (_) => setState(() {
                  if (!_optionList.contains(_choice)) _choice = null;
                }),
              ),
            ),
            regGap,
            RegDropdown(
              label: 'Value',
              value: _choice,
              options: _optionList,
              hint: _optionList.isEmpty ? 'Enter the options first' : 'Select',
              onChanged: (v) => setState(() => _choice = v),
            ),
          ],
        ),
        _ => LabeledField(
          label: 'Value',
          child: TextFormField(
            controller: _value,
            style: inputStyle,
            keyboardType: _type == CustomFieldType.number ? const TextInputType.numberWithOptions(decimal: true) : null,
            validator: (v) =>
                _type == CustomFieldType.number && (v ?? '').trim().isNotEmpty && RegNumberField.parse(v) == null
                ? 'Enter a number'
                : null,
          ),
        ),
      },
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () {
          if (!(_form.currentState?.validate() ?? false)) return;
          Navigator.pop(context, AssetCustomField(fieldName: _name.text.trim(), fieldType: _type, value: _result));
        },
        child: Text(widget.initial == null ? 'Add Field' : 'Save Field'),
      ),
    ]),
  );
}

/// Custom field value for the table: dates as "15 Jun 2026".
String customFieldDisplay(AssetCustomField f) {
  final v = f.value;
  if (v == null || v.isEmpty) return '—';
  final d = f.fieldType == CustomFieldType.date ? DateTime.tryParse(v) : null;
  return d == null ? v : DemoClock.formatDate(d);
}

/// Parent Asset and IoT device: optional, kept on this phone only (the backend registration has
/// no field for them; parent → /api/asset-hierarchy, IoT → device pairing, later). API mode: both
/// are "Not available yet" (the pickers would read the mock register).
class LocalExtrasCard extends ConsumerWidget {
  const LocalExtrasCard({super.key, required this.form, required this.edit});

  final AssetRegistration form;
  final FormEdit edit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apiMode) {
      Widget row(IconData icon, String title) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: IconSquare(icon: icon, tone: TileTone.lavender, size: 38),
        title: Text(title, style: AppText.body),
        subtitle: Text(notAvailableYetMessage, style: AppText.caption),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showNotAvailableYet(context, title),
      );
      return SectionCard(
        title: 'Links',
        child: Column(
          children: [
            row(Icons.account_tree_outlined, 'Parent Asset'),
            const Divider(height: 1),
            row(Icons.sensors_rounded, 'IoT Device'),
          ],
        ),
      );
    }
    final x = form.local;
    final parent = x.parentAssetId == null ? null : ref.watch(assetByIdProvider(x.parentAssetId!));
    final unlinked = ref.watch(unlinkedIotDevicesProvider);
    final device = unlinked.firstWhereOrNull((d) => d.imei == x.iotDeviceImei);
    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool set,
      required VoidCallback onTap,
      required VoidCallback onClear,
      required String clearTooltip,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconSquare(icon: icon, tone: TileTone.lavender, size: 38),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
      subtitle: Text(subtitle, style: AppText.caption),
      trailing: set
          ? IconButton(tooltip: clearTooltip, icon: const Icon(Icons.close_rounded), onPressed: onClear)
          : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
    return SectionCard(
      title: 'Links (this phone)',
      child: Column(
        children: [
          row(
            icon: Icons.account_tree_outlined,
            title: parent == null ? 'Parent Asset: none' : 'Parent Asset: ${parent.id} – ${parent.name}',
            subtitle: 'Optional · top-level asset when empty',
            set: parent != null,
            clearTooltip: 'Clear parent asset',
            onClear: () => edit(() => x.parentAssetId = null),
            onTap: () async {
              final id = await showAssetPicker(context, title: 'Parent Asset', selectedId: x.parentAssetId);
              if (id != null) edit(() => x.parentAssetId = id);
            },
          ),
          const Divider(height: 1),
          row(
            icon: Icons.sensors_rounded,
            title: device == null ? 'IoT Device: none' : 'IoT Device: ${device.model} · ${device.type}',
            subtitle: device == null ? '${unlinked.length} unlinked devices available' : 'IMEI ${device.imei}',
            set: device != null,
            clearTooltip: 'Unlink IoT device',
            onClear: () => edit(() => x.iotDeviceImei = null),
            onTap: () async {
              if (unlinked.isEmpty) {
                context.showSnack('No unlinked IoT devices in the store');
                return;
              }
              final d = await showIotDevicePicker(context, unlinked);
              if (d != null) edit(() => x.iotDeviceImei = d.imei);
            },
          ),
        ],
      ),
    );
  }
}
