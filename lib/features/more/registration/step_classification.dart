import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/features/more/registration/live_options.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Icons of the Asset Sub Type picture cards (keys in registration_options).
const _subTypeIcons = <String, IconData>{
  'diesel': Icons.local_gas_station_rounded,
  'gas': Icons.propane_tank_outlined,
  'ups': Icons.battery_charging_full_rounded,
  'solar': Icons.solar_power_outlined,
  'lathe': Icons.precision_manufacturing_outlined,
  'milling': Icons.settings_suggest_outlined,
  'machining': Icons.factory_outlined,
  'motor': Icons.settings_outlined,
  'servo': Icons.rotate_right_rounded,
  'dc': Icons.electric_bolt_rounded,
  'electric': Icons.electric_bolt_rounded,
  'reach': Icons.forklift,
  'hvac': Icons.ac_unit_rounded,
  'modular': Icons.view_module_outlined,
  'rooftop': Icons.roofing_rounded,
  'air': Icons.air_rounded,
  'water': Icons.water_drop_outlined,
  'pump': Icons.water_rounded,
  'laptop': Icons.laptop_mac_rounded,
  'rugged': Icons.laptop_chromebook_rounded,
  'workstation': Icons.computer_rounded,
};

/// Step 2 Classification (AssetClassificationDto). The only place Category / Sub Category /
/// Asset Type and Criticality are entered. [errors] by backend field path. API mode: every list
/// comes from the server (RegLists: Master Data or the Asset service's options); Cost Center and
/// the Asset Sub Type cards stay local.
class StepClassification extends ConsumerStatefulWidget {
  const StepClassification({
    super.key,
    required this.form,
    required this.edit,
    required this.onTypePicked,
    required this.errors,
  });

  final AssetRegistration form;
  final FormEdit edit;
  final ValueChanged<String> onTypePicked;
  final Map<String, String> errors;

  @override
  ConsumerState<StepClassification> createState() => _StepClassificationState();
}

class _StepClassificationState extends ConsumerState<StepClassification> {
  final _keyword = TextEditingController();

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  void _addKeyword() {
    final k = _keyword.text.trim();
    if (k.isEmpty) return;
    final c = widget.form.classification;
    widget.edit(() {
      if (!c.keywords.contains(k)) c.keywords = [...c.keywords, k];
    });
    _keyword.clear();
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form, edit = widget.edit, c = form.classification, errors = widget.errors;
    final subTypes = assetTypeOption(c.assetType)?.subTypes ?? const <AssetSubType>[];
    final lists = RegLists(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegBreadcrumb(parts: c.path, icon: Icons.account_tree_outlined, empty: 'Choose a category'),
        ClassificationFields(form: form, edit: edit, onTypePicked: widget.onTypePicked, errors: errors),
        if (subTypes.isNotEmpty) ...[
          const FieldLabel('Asset Sub Type'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              for (final t in subTypes)
                _SubTypeCard(
                  subType: t,
                  selected: c.assetSubType == t.name,
                  onTap: () => edit(() => c.assetSubType = c.assetSubType == t.name ? null : t.name),
                ),
            ],
          ),
          regGap,
        ],
        RegDropdown.source(
          lists.functionPurposes,
          label: 'Function / Purpose',
          value: c.functionPurpose,
          onChanged: (v) => edit(() => c.functionPurpose = v),
        ),
        CriticalityField(form: form, edit: edit, required: true, error: errors['Criticality']),
        RegDropdown.source(
          lists.departments,
          label: 'Department',
          required: true,
          value: c.department,
          error: errors['Department'],
          onChanged: (v) => edit(() => c.department = v),
        ),
        RegDropdown.source(
          lists.costCenters,
          label: 'Cost Center',
          value: c.costCenter,
          onChanged: (v) => edit(() => c.costCenter = v),
        ),
        RegDropdown.source(
          lists.businessUnits,
          label: 'Business Unit',
          value: c.businessUnit,
          onChanged: (v) => edit(() => c.businessUnit = v),
        ),
        RegChoiceChips.source(
          lists.taggingMethods,
          label: 'Tagging Method',
          required: true,
          value: c.taggingMethod,
          error: errors['TaggingMethod'],
          onChanged: (v) => edit(() => c.taggingMethod = v),
        ),
        RegDropdown.source(
          lists.complianceCategories,
          label: 'Compliance Category',
          value: c.complianceCategory,
          onChanged: (v) => edit(() => c.complianceCategory = v),
        ),
        RegDropdown.source(
          lists.lifecycleStages,
          label: 'Lifecycle Stage',
          required: true,
          value: c.lifecycleStage,
          error: errors['LifecycleStage'],
          onChanged: (v) => edit(() => c.lifecycleStage = v),
        ),
        LabeledField(
          label: 'Keywords / Tags',
          child: TextField(
            controller: _keyword,
            style: inputStyle,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Type a keyword and press +',
              suffixIcon: IconButton(
                tooltip: 'Add keyword',
                icon: const Icon(Icons.add_rounded),
                onPressed: _addKeyword,
              ),
            ),
            onSubmitted: (_) => _addKeyword(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in c.keywords)
              InputChip(
                label: Text(k),
                visualDensity: VisualDensity.compact,
                onDeleted: () => edit(() => c.keywords = [...c.keywords]..remove(k)),
              ),
          ],
        ),
      ],
    );
  }
}

class _SubTypeCard extends StatelessWidget {
  const _SubTypeCard({required this.subType, required this.selected, required this.onTap});

  final AssetSubType subType;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primarySoft : AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _subTypeIcons[subType.icon] ?? Icons.category_outlined,
              size: 28,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              subType.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
