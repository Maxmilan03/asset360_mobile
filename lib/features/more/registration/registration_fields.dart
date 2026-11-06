import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/live_registration_repository.dart';
import 'package:asset360_mobile/data/repositories/live_uploads.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/features/assets/criticality_sheet.dart';
import 'package:asset360_mobile/features/more/registration/live_options.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Applies a change to the form and rebuilds the step ([bump] re-reads text fields set by code).
typedef FormEdit = void Function(VoidCallback change, {bool bump});

/// Category* › Sub Category* › Asset Type* (steps 1 and 2 edit the same values). Mock mode: asset
/// types come from registration_options plus types added in Administration → Master Data for the
/// sub category. API mode: GET /api/asset-categories (top level → children) and
/// /api/asset-category-types?categoryId=<sub category id>.
class ClassificationFields extends ConsumerWidget {
  const ClassificationFields({
    super.key,
    required this.form,
    required this.edit,
    required this.onTypePicked,
    this.errors = const {},
  });

  final AssetRegistration form;
  final FormEdit edit;
  final ValueChanged<String> onTypePicked;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = form.classification;
    final lists = RegLists(ref);
    List<String> localTypes() {
      final category = assetCategories.firstWhereOrNull((o) => o.name == c.category);
      final sub = category?.subCategories.firstWhereOrNull((s) => s.name == c.subCategory);
      final master = ref.watch(masterDataProvider).types;
      return <String>{
        ...?sub?.types.map((t) => t.name),
        for (final e in master.entries)
          if (sub != null && e.value == sub.name) e.key,
      }.toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegDropdown.source(
          lists.categories,
          label: 'Category',
          required: true,
          value: c.category,
          error: errors['Category'],
          onChanged: (v) => edit(() {
            if (v == c.category) return;
            c
              ..category = v
              ..subCategory = null
              ..assetType = null
              ..assetSubType = null;
          }),
        ),
        RegDropdown.source(
          lists.subCategories(c.category),
          label: 'Sub Category',
          required: true,
          value: c.subCategory,
          error: errors['SubCategory'],
          onChanged: (v) => edit(() {
            if (v == c.subCategory) return;
            c
              ..subCategory = v
              ..assetType = null
              ..assetSubType = null;
          }),
        ),
        RegDropdown.source(
          lists.assetTypes(c.category, c.subCategory, local: apiMode ? const [] : localTypes()),
          label: 'Asset Type',
          required: true,
          value: c.assetType,
          error: errors['AssetType'],
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
/// level directly clears the assessment. API mode: levels from GET /api/asset-criticality/options;
/// the assessment is a local extra, so Assess says it is not available yet.
class CriticalityField extends ConsumerWidget {
  const CriticalityField({super.key, required this.form, required this.edit, this.required = false, this.error});

  final AssetRegistration form;
  final FormEdit edit;
  final bool required;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessed = apiMode ? null : form.local.criticalityAssessment?.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: FieldLabel('Criticality', required: required)),
            AssessLink(
              onTap: () async {
                if (apiMode) return showNotAvailableYet(context, 'Criticality assessment');
                final r = await showCriticalityAssessment(context, initial: form.local.criticalityAssessment);
                final level = r?.result?.level;
                if (r == null || level == null) return;
                edit(() {
                  form
                    ..local.criticalityAssessment = r
                    ..criticality = level;
                });
              },
            ),
          ],
        ),
        RegDropdown.source(
          RegLists(ref).criticalities,
          label: 'Criticality',
          showLabel: false,
          value: form.criticality,
          required: required,
          error: error,
          dotColor: (o) => ChipTone.forAsset(o).foreground,
          bottom: assessed == null ? 14 : 4,
          onChanged: (v) => edit(() {
            form
              ..criticality = v
              ..local.criticalityAssessment = null;
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
    this.error,
    this.status,
  });

  /// Chips over an [OptionSource] (spinner / error with Retry / empty text instead of chips).
  RegChoiceChips.source(
    OptionSource source, {
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.error,
  }) : options = source.options,
       status = optionSourceStatus(source);

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool required;
  final String? error;

  /// Shown instead of the chips while the options load, failed or are empty.
  final Widget? status;

  @override
  Widget build(BuildContext context) => FormField<String>(
    key: ValueKey('$label#$value'),
    initialValue: value,
    forceErrorText: error,
    builder: (state) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, required: required),
          ?status,
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
  const RegMultiChips({
    super.key,
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.status,
  });

  RegMultiChips.source(
    OptionSource source, {
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  }) : options = source.options,
       status = optionSourceStatus(source);

  final String label;
  final List<String> selected;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;
  final Widget? status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        ?status,
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

/// Text field with suggestions (Model, Manufacturer, Supplier / Vendor). Free text is allowed.
class RegAutocomplete extends StatelessWidget {
  const RegAutocomplete({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.required = false,
    this.hint,
    this.error,
  }) : status = null;

  /// Suggestions from an [OptionSource]: its loading / error / empty state (with Retry) shows
  /// under the field, which stays editable.
  RegAutocomplete.source(
    OptionSource source, {
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.hint,
    this.error,
  }) : options = source.options,
       status = optionSourceStatus(source);

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool required;
  final String? hint;
  final String? error;
  final Widget? status;

  Widget _field({double bottom = 14}) => Padding(
    padding: EdgeInsets.only(bottom: bottom),
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
          forceErrorText: error,
          decoration: InputDecoration(hintText: hint, errorMaxLines: 2),
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : v),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => status == null
      ? _field()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(bottom: 2),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: status),
          ],
        );
}

/// Asset Images: several photos, the first is primary; tap a photo to view, make primary or remove.
/// API mode: each picked photo (and a local photo handed in by the hub) is uploaded to the Media
/// service (category "asset-images") and only the returned URL goes into the list; the local
/// preview shows a spinner until then, a failed upload is reported and not added.
class AssetImagesField extends ConsumerStatefulWidget {
  const AssetImagesField({super.key, required this.images, required this.onChanged, this.onAdded});

  final List<String> images;
  final ValueChanged<List<String>> onChanged;

  /// API mode: an uploaded photo's URL, appended to the form's current list (the upload may
  /// finish after this field is gone).
  final ValueChanged<String>? onAdded;

  /// Tests replace the camera / gallery sheet (returns a local file path).
  @visibleForTesting
  static Future<String?> Function()? debugPickPhoto;

  @override
  ConsumerState<AssetImagesField> createState() => _AssetImagesFieldState();
}

class _AssetImagesFieldState extends ConsumerState<AssetImagesField> {
  /// Local files being uploaded (API mode).
  final _uploading = <String>[];

  @override
  void initState() {
    super.initState();
    if (!apiMode) return;
    final local = [
      for (final p in widget.images)
        if (!isRemoteMedia(p) && !p.startsWith('assets/')) p,
    ];
    if (local.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged([...widget.images.where((p) => !local.contains(p))]);
      local.forEach(_upload);
    });
  }

  Future<void> _upload(String path) async {
    final uploader = ref.read(assetUploaderProvider);
    final uploads = ref.read(registrationUploadsProvider.notifier);
    final add = widget.onAdded ?? (url) => widget.onChanged([...widget.images, url]);
    setState(() => _uploading.add(path));
    uploads.started();
    try {
      final file = await uploader.upload(path, category: AssetFileRules.imageCategory, imageOnly: true);
      add(file.url);
    } catch (e) {
      if (mounted) context.showSnack('Photo not added: ${ApiException.from(e).message}');
    } finally {
      uploads.finished();
      if (mounted) setState(() => _uploading.remove(path));
    }
  }

  Future<void> _add() async {
    final p = await (AssetImagesField.debugPickPhoto?.call() ?? pickPhoto(context));
    if (p == null || !mounted) return;
    apiMode ? await _upload(p) : widget.onChanged([...widget.images, p]);
  }

  Future<void> _photoMenu(BuildContext context, int i) async {
    final images = widget.images;
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
        widget.onChanged([images[i], ...images.where((p) => p != images[i])]);
      case 'remove':
        widget.onChanged([...images]..removeAt(i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    Widget frame({required String path, required bool primary, required List<Widget> overlay, VoidCallback? onTap}) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 96,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: primary ? AppColors.primary : AppColors.border, width: primary ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(image: photoProvider(path), errorBuilder: photoError, fit: BoxFit.cover),
                ...overlay,
              ],
            ),
          ),
        );
    Widget thumb(int i) => frame(
      path: images[i],
      primary: i == 0,
      onTap: () => _photoMenu(context, i),
      overlay: [if (i == 0) const Positioned(left: 4, top: 4, child: StatusChip('Primary', tone: ChipTone.purple))],
    );
    Widget uploading(String path) => frame(
      path: path,
      primary: false,
      onTap: () => context.showSnack('Uploading the photo…'),
      overlay: const [
        ColoredBox(
          color: Color(0x88000000),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
              SizedBox(height: 6),
              Text('Uploading…', style: TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
    final count = images.length + _uploading.length;
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
              itemCount: count + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => i < images.length
                  ? thumb(i)
                  : i < count
                  ? uploading(_uploading[i - images.length])
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        fixedSize: const Size(96, 84),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile)),
                      ),
                      onPressed: _add,
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
/// API mode: the type and size are checked first ([AssetFileRules]: JPG, PNG, WEBP or PDF), then
/// each file is uploaded to the Media service (category "asset-documents") and stored as
/// [UploadedFile.toAssetDocument] (the server rejects documents without a URL).
class DocumentUploadField extends ConsumerStatefulWidget {
  const DocumentUploadField({
    super.key,
    required this.label,
    required this.documents,
    required this.onChanged,
    this.onAdded,
    this.error,
  });

  final String label;
  final List<AssetDocument> documents;
  final ValueChanged<List<AssetDocument>> onChanged;

  /// API mode: an uploaded document, appended to the form's current list.
  final ValueChanged<AssetDocument>? onAdded;

  /// Validator / server message for the list ("Documents", "Attachments").
  final String? error;

  /// Tests replace file_picker (returns name, bytes, path).
  @visibleForTesting
  static Future<List<({String name, int bytes, String? path})>?> Function()? debugPickFiles;

  @override
  ConsumerState<DocumentUploadField> createState() => _DocumentUploadFieldState();
}

class _DocumentUploadFieldState extends ConsumerState<DocumentUploadField> {
  /// File names being uploaded (API mode).
  final _uploading = <String>[];

  Future<void> _pick(BuildContext context) async {
    try {
      final picked =
          await (DocumentUploadField.debugPickFiles?.call() ??
              FilePicker.pickFiles().then(
                (files) async => [for (final f in files) (name: f.name, bytes: await f.length() ?? 0, path: f.path)],
              ));
      if (picked == null || picked.isEmpty || !context.mounted) return;
      if (apiMode) {
        await _uploadAll(context, picked);
        return;
      }
      final ok = [
        for (final f in picked)
          if (f.bytes <= maxUploadMb * 1024 * 1024) f,
      ];
      final tooBig = picked.length - ok.length;
      if (tooBig > 0 && context.mounted) {
        context.showSnack(
          '$tooBig file${tooBig == 1 ? ' is' : 's are'} over $maxUploadMb MB and ${tooBig == 1 ? 'was' : 'were'} not added',
        );
      }
      if (ok.isEmpty) return;
      widget.onChanged([
        ...widget.documents,
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

  Future<void> _uploadAll(BuildContext context, List<({String name, int bytes, String? path})> picked) async {
    final rejected = <String>[];
    final ok = <({String name, String path})>[];
    for (final f in picked) {
      final problem = f.path == null
          ? 'the file could not be read'
          : AssetFileRules.check(f.name, size: f.bytes)?.replaceFirst(RegExp(r'\.$'), '');
      problem == null ? ok.add((name: f.name, path: f.path!)) : rejected.add('${f.name}: $problem');
    }
    if (rejected.isNotEmpty) context.showSnack('Not added – ${rejected.join('; ')}');
    final uploader = ref.read(assetUploaderProvider);
    final uploads = ref.read(registrationUploadsProvider.notifier);
    final add = widget.onAdded ?? (d) => widget.onChanged([...widget.documents, d]);
    await Future.wait([
      for (final f in ok)
        () async {
          setState(() => _uploading.add(f.name));
          uploads.started();
          try {
            final up = await uploader.upload(f.path, category: AssetFileRules.documentCategory, fileName: f.name);
            add(up.toAssetDocument());
          } catch (e) {
            if (mounted) this.context.showSnack('${f.name} not added: ${ApiException.from(e).message}');
          } finally {
            uploads.finished();
            if (mounted) setState(() => _uploading.remove(f.name));
          }
        }(),
    ]);
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
  Widget build(BuildContext context) {
    final documents = widget.documents;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel('${widget.label} (${documents.length})'),
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
                onPressed: () => widget.onChanged([...documents]..removeAt(i)),
              ),
            ),
          for (final name in _uploading)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const SizedBox.square(
                dimension: 34,
                child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
              subtitle: Text('Uploading…', style: AppText.caption),
            ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(widget.error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            ),
          OutlinedButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.upload_file_rounded, size: 20),
            label: Text(apiMode ? 'Upload (JPG, PNG, WEBP or PDF)' : 'Upload (max $maxUploadMb MB each)'),
          ),
        ],
      ),
    );
  }
}
