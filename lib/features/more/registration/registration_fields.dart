import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/features/assets/criticality_sheet.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Applies a change to the form and rebuilds the step ([bump] re-reads text fields set by code).
typedef FormEdit = void Function(VoidCallback change, {bool bump});

/// Category* › Sub Category* › Asset Type* (steps 1 and 2 edit the same values). Asset types come
/// from registration_options plus types added in Administration → Master Data for the sub category.
class ClassificationFields extends ConsumerWidget {
  const ClassificationFields({super.key, required this.form, required this.edit, required this.onTypePicked});

  final RegistrationForm form;
  final FormEdit edit;
  final ValueChanged<String> onTypePicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = form.classification;
    final category = assetCategories.firstWhereOrNull((o) => o.name == c.category);
    final sub = category?.subCategories.firstWhereOrNull((s) => s.name == c.subCategory);
    final master = ref.watch(masterDataProvider).types;
    final types = <String>{
      ...?sub?.types.map((t) => t.name),
      for (final e in master.entries)
        if (sub != null && e.value == sub.name) e.key,
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegDropdown(
          label: 'Category',
          required: true,
          value: c.category,
          options: [for (final o in assetCategories) o.name],
          onChanged: (v) => edit(() {
            if (v == c.category) return;
            c
              ..category = v
              ..subCategory = null
              ..assetType = null
              ..assetSubType = null;
          }),
        ),
        RegDropdown(
          label: 'Sub Category',
          required: true,
          value: c.subCategory,
          options: [for (final s in category?.subCategories ?? const <SubCategoryOption>[]) s.name],
          onChanged: (v) => edit(() {
            if (v == c.subCategory) return;
            c
              ..subCategory = v
              ..assetType = null
              ..assetSubType = null;
          }),
        ),
        RegDropdown(
          label: 'Asset Type',
          required: true,
          value: c.assetType,
          options: types,
          onChanged: (v) {
            if (v == null || v == c.assetType) return;
            edit(() {
              c
                ..assetType = v
                ..assetSubType = null;
            });
            onTypePicked(v);
          },
        ),
      ],
    );
  }
}

/// Criticality dropdown with an "Assess" link (the sheet's level fills the dropdown); picking a
/// level directly clears the assessment.
class CriticalityField extends StatelessWidget {
  const CriticalityField({super.key, required this.form, required this.edit, this.required = false});

  final RegistrationForm form;
  final FormEdit edit;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final assessed = form.criticalityAssessment?.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: FieldLabel('Criticality', required: required)),
            AssessLink(
              onTap: () async {
                final r = await showCriticalityAssessment(context, initial: form.criticalityAssessment);
                final level = r?.result?.level;
                if (r == null || level == null) return;
                edit(() {
                  form
                    ..criticalityAssessment = r
                    ..criticality = level;
                });
              },
            ),
          ],
        ),
        RegDropdown(
          label: 'Criticality',
          showLabel: false,
          value: form.criticality,
          options: AssetOptions.criticalityLevels,
          required: required,
          dotColor: (o) => ChipTone.forAsset(o).foreground,
          bottom: assessed == null ? 14 : 4,
          onChanged: (v) => edit(() {
            form
              ..criticality = v
              ..criticalityAssessment = null;
          }),
        ),
        if (assessed != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Assessed: score ${assessed.score.toStringAsFixed(1)} / 5 → ${assessed.level}',
              style: AppText.caption,
            ),
          ),
      ],
    );
  }
}

/// Single-choice chips that take part in form validation (Tagging Method*).
class RegChoiceChips extends StatelessWidget {
  const RegChoiceChips({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.required = false,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) => FormField<String>(
    key: ValueKey('$label#$value'),
    initialValue: value,
    validator: required ? (v) => v == null ? 'Select the ${label.toLowerCase()}' : null : null,
    builder: (state) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, required: required),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                IconFilterChip(
                  label: o,
                  selected: value == o,
                  onTap: () {
                    state.didChange(o);
                    onChanged(o);
                  },
                ),
            ],
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(state.errorText!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            ),
        ],
      ),
    ),
  );
}

/// Multi-select chips (Compliance Standards).
class RegMultiChips extends StatelessWidget {
  const RegMultiChips({super.key, required this.label, required this.selected, required this.options, required this.onChanged});

  final String label;
  final List<String> selected;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              IconFilterChip(
                label: o,
                icon: selected.contains(o) ? Icons.check_rounded : null,
                selected: selected.contains(o),
                onTap: () => onChanged(selected.contains(o) ? ([...selected]..remove(o)) : [...selected, o]),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Text field with suggestions (Manufacturer, Supplier / Vendor).
class RegAutocomplete extends StatelessWidget {
  const RegAutocomplete({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.required = false,
    this.hint,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: LabeledField(
      label: label,
      required: required,
      child: Autocomplete<String>(
        key: ValueKey('$label#auto'),
        initialValue: TextEditingValue(text: value ?? ''),
        optionsBuilder: (v) => options.where((o) => o.toLowerCase().contains(v.text.toLowerCase())),
        onSelected: onChanged,
        fieldViewBuilder: (context, controller, focus, _) => TextFormField(
          controller: controller,
          focusNode: focus,
          style: inputStyle,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : v),
          validator: required ? (v) => (v ?? '').trim().isEmpty ? 'Enter the ${label.toLowerCase()}' : null : null,
        ),
      ),
    ),
  );
}

/// Asset Images: several photos, the first is primary; tap a photo to view, make primary or remove.
class AssetImagesField extends StatelessWidget {
  const AssetImagesField({super.key, required this.images, required this.onChanged});

  final List<String> images;
  final ValueChanged<List<String>> onChanged;

  Future<void> _photoMenu(BuildContext context, int i) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View photo'),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            if (i > 0)
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Set as primary'),
                onTap: () => Navigator.pop(context, 'primary'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
              title: const Text('Remove'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'view':
        openPhotoViewer(context, images, initialIndex: i);
      case 'primary':
        onChanged([images[i], ...images.where((p) => p != images[i])]);
      case 'remove':
        onChanged([...images]..removeAt(i));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget thumb(int i) => GestureDetector(
      onTap: () => _photoMenu(context, i),
      child: Container(
        width: 96,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: i == 0 ? AppColors.primary : AppColors.border, width: i == 0 ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(image: photoProvider(images[i]), fit: BoxFit.cover),
            if (i == 0)
              const Positioned(left: 4, top: 4, child: StatusChip('Primary', tone: ChipTone.purple)),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel('Asset Images (${images.length})'),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => i < images.length
                  ? thumb(i)
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        fixedSize: const Size(96, 84),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile)),
                      ),
                      onPressed: () async {
                        final p = await pickPhoto(context);
                        if (p != null) onChanged([...images, p]);
                      },
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(Icons.add_photo_alternate_outlined), SizedBox(height: 4), Text('Add Image')],
                      ),
                    ),
            ),
          ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Tap a photo to make it the primary image', style: AppText.caption),
            ),
        ],
      ),
    );
  }
}

/// Upload list (Invoice & Documents, Attachments): file_picker, each file at most [maxUploadMb] MB.
class DocumentUploadField extends StatelessWidget {
  const DocumentUploadField({super.key, required this.label, required this.documents, required this.onChanged});

  final String label;
  final List<AssetDocument> documents;
  final ValueChanged<List<AssetDocument>> onChanged;

  /// Tests replace file_picker (returns name, bytes, path).
  @visibleForTesting
  static Future<List<({String name, int bytes, String? path})>?> Function()? debugPickFiles;

  Future<void> _pick(BuildContext context) async {
    try {
      final picked =
          await (debugPickFiles?.call() ??
              FilePicker.pickFiles().then(
                (files) async => [for (final f in files) (name: f.name, bytes: await f.length() ?? 0, path: f.path)],
              ));
      if (picked == null || picked.isEmpty) return;
      final ok = [for (final f in picked) if (f.bytes <= maxUploadMb * 1024 * 1024) f];
      final tooBig = picked.length - ok.length;
      if (tooBig > 0 && context.mounted) {
        context.showSnack('$tooBig file${tooBig == 1 ? ' is' : 's are'} over $maxUploadMb MB and ${tooBig == 1 ? 'was' : 'were'} not added');
      }
      if (ok.isEmpty) return;
      onChanged([
        ...documents,
        for (final f in ok)
          AssetDocument(
            fileName: f.name,
            url: f.path,
            contentType: _contentType(f.name),
            fileSize: f.bytes,
            uploadedAt: DemoClock.now,
          ),
      ]);
    } catch (_) {
      if (context.mounted) context.showSnack('Could not open files. Allow file access and try again.');
    }
  }

  static String _contentType(String name) => switch (name.split('.').last.toLowerCase()) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'doc' || 'docx' => 'application/msword',
    'xls' || 'xlsx' => 'application/vnd.ms-excel',
    _ => 'application/octet-stream',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel('$label (${documents.length})'),
        for (final (i, d) in documents.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: IconSquare(icon: Icons.description_outlined, tone: TileTone.lavender, size: 34),
            title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
            subtitle: Text('${d.sizeMb.toStringAsFixed(1)} MB', style: AppText.caption),
            trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => onChanged([...documents]..removeAt(i)),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.upload_file_rounded, size: 20),
          label: const Text('Upload (max $maxUploadMb MB each)'),
        ),
      ],
    ),
  );
}
