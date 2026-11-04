import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/reference/technical_templates.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Step 5 Additional Information (AssetAdditionalInformationDto): Technical Details (template per
/// asset type, technical_templates.dart) | Operational Details | Custom Fields | Attachments.
class StepAdditional extends StatefulWidget {
  const StepAdditional({super.key, required this.form, required this.edit, this.dateError});

  final RegistrationForm form;
  final FormEdit edit;
  final String? dateError;

  @override
  State<StepAdditional> createState() => _StepAdditionalState();
}

class _StepAdditionalState extends State<StepAdditional> {
  int _tab = 0;

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
            onChanged: (v) => widget.edit(() => info.attachments = v),
          ),
        },
      ],
    );
  }

  Widget _technical() {
    final edit = widget.edit;
    final type = widget.form.classification.assetType;
    final t = widget.form.additionalInformation.technical;
    final template = technicalTemplateFor(type);
    void setSpec(SpecField f, String? v) =>
        edit(() => t.specifications[f.name] = AssetSpecification(name: f.name, value: v, unit: f.unit));
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
                  ? 'Choose the asset type in step 1 to see its technical fields.'
                  : 'No technical template for $type yet. Add the details in Technical Remarks.',
            ),
          ),
        for (final f in template.specs)
          if (f.options.isNotEmpty)
            RegDropdown(
              label: f.unit == null ? f.name : '${f.name} (${f.unit})',
              value: t.specifications[f.name]?.value,
              options: f.options,
              onChanged: (v) => setSpec(f, v),
            )
          else
            RegTextField(
              label: f.name,
              value: t.specifications[f.name]?.value,
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
                  child: RegNumberField(label: label, value: value, min: 0, onChanged: (v) => edit(() => set(v))),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: RegDropdown(
                  label: 'Unit',
                  value: t.dimensionUnit,
                  options: dimensionUnits,
                  onChanged: (v) => edit(() => t.dimensionUnit = v),
                ),
              ),
            ],
          ),
        ],
        if (template.weight)
          unitPair(
            RegNumberField(label: 'Weight', value: t.weight, min: 0, onChanged: (v) => edit(() => t.weight = v)),
            RegDropdown(
              label: 'Weight Unit',
              value: t.weightUnit,
              options: weightUnits,
              onChanged: (v) => edit(() => t.weightUnit = v),
            ),
          ),
        if (template.lifespan)
          unitPair(
            RegNumberField(
              label: 'Expected Lifespan',
              value: t.expectedLifespan,
              min: 1,
              decimals: false,
              onChanged: (v) => edit(() => t.expectedLifespan = v?.toInt()),
            ),
            RegDropdown(
              label: 'Lifespan Unit',
              value: t.expectedLifespanUnit,
              options: lifespanUnits,
              onChanged: (v) => edit(() => t.expectedLifespanUnit = v),
            ),
          ),
        RegTextField(
          label: 'Technical Remarks',
          value: t.technicalRemarks,
          maxLines: 3,
          onChanged: (v) => t.technicalRemarks = v,
        ),
      ],
    );
  }

  Widget _operational() {
    final edit = widget.edit;
    final o = widget.form.additionalInformation.operational;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegNumberField(
          label: 'Operating Hours per Day',
          value: o.operatingHoursPerDay,
          min: 0,
          suffixText: 'hrs/day',
          onChanged: (v) => edit(() => o.operatingHoursPerDay = v),
        ),
        RegDropdown(
          label: 'Operating Shift',
          value: o.operatingShift,
          options: operatingShifts,
          onChanged: (v) => edit(() => o.operatingShift = v),
        ),
        RegDropdown(
          label: 'Utilization',
          value: o.utilization,
          options: utilizationLevels,
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
                min: 1,
                decimals: false,
                hint: 'Every …',
                onChanged: (v) => edit(() => o.maintenanceFrequency = v?.toInt()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: RegDropdown(
                label: 'Frequency Unit',
                value: o.maintenanceFrequencyUnit,
                options: maintenanceFrequencyUnits,
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
          error: widget.dateError,
          onPicked: (d) => edit(() => o.nextMaintenanceDate = d),
        ),
        RegMultiChips(
          label: 'Compliance Standards',
          selected: o.complianceStandards,
          options: complianceStandards,
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
                        Expanded(flex: 5, child: Text(f.value ?? '—', style: AppText.body.copyWith(fontSize: 13))),
                        IconButton(
                          tooltip: 'Edit ${f.fieldName}',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editField(i),
                        ),
                        IconButton(
                          tooltip: 'Remove ${f.fieldName}',
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          onPressed: () =>
                              widget.edit(() => info.customFields = [...info.customFields]..removeAt(i)),
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
  const _CustomFieldSheet({required this.initial, required this.taken});

  final AssetCustomField? initial;
  final List<String> taken;

  @override
  State<_CustomFieldSheet> createState() => _CustomFieldSheetState();
}

class _CustomFieldSheetState extends State<_CustomFieldSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.fieldName);
  late final _value = TextEditingController(text: widget.initial?.value);
  late String _type = widget.initial?.fieldType ?? customFieldTypes.first;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

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
          decoration: const InputDecoration(hintText: 'e.g. Fuel Card No.'),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return 'Enter the field name';
            return widget.taken.contains(s.toLowerCase()) ? 'This field already exists' : null;
          },
        ),
      ),
      regGap,
      RegDropdown(label: 'Field Type', value: _type, options: customFieldTypes, onChanged: (v) => setState(() => _type = v!)),
      LabeledField(
        label: 'Value',
        child: TextFormField(
          controller: _value,
          style: inputStyle,
          keyboardType: _type == 'Number' ? const TextInputType.numberWithOptions(decimal: true) : null,
          validator: (v) => _type == 'Number' && (v ?? '').trim().isNotEmpty && RegNumberField.parse(v) == null
              ? 'Enter a number'
              : null,
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () {
          if (!(_form.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            AssetCustomField(
              fieldName: _name.text.trim(),
              fieldType: _type,
              value: _value.text.trim().isEmpty ? null : _value.text.trim(),
            ),
          );
        },
        child: Text(widget.initial == null ? 'Add Field' : 'Save Field'),
      ),
    ]),
  );
}
