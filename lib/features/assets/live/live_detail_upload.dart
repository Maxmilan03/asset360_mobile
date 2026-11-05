import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/data/repositories/live_uploads.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_common.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Photos and documents of a live asset: pick → check type / size (AssetFileRules) → Media upload →
/// POST /api/asset-images or /api/asset-documents → refresh the asset.

/// TEMP: image types offered until the backend publishes a list (ImageType is free text, ≤ 100).
const liveImageTypes = ['General', 'Front View', 'Nameplate', 'Installation', 'Damage'];

/// TEMP: document types offered until the backend publishes a list (DocumentType is free text, ≤ 100).
const liveDocumentTypes = ['Manual', 'Warranty', 'Certificate', 'Invoice', 'Drawing', 'Report', 'Other'];

/// A picked local file.
typedef LivePickedFile = ({String name, String path, int? size});

/// Test hooks for the camera / gallery and the system file picker.
abstract final class LiveDetailUpload {
  @visibleForTesting
  static Future<String?> Function(BuildContext context)? debugPickPhoto;
  @visibleForTesting
  static Future<LivePickedFile?> Function(BuildContext context)? debugPickFile;

  static Future<String?> pickImage(BuildContext context) => (debugPickPhoto ?? pickPhoto)(context);

  /// System file picker limited to the types the Media service accepts.
  static Future<LivePickedFile?> pickFile(BuildContext context) async {
    if (debugPickFile != null) return debugPickFile!(context);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: AssetFileRules.mediaExtensions.toList(),
      );
      if (files.isEmpty) return null;
      final f = files.first;
      if (f.path == null) return null;
      return (name: f.name, path: f.path!, size: await f.length());
    } catch (_) {
      if (context.mounted) context.showSnack('Could not open files. Allow file access and try again.');
      return null;
    }
  }
}

/// Uploads photos to asset [id] and refreshes it. Throws [ApiException].
Future<int> uploadLivePhotos(
  WidgetRef ref,
  String id,
  List<String> paths, {
  required String imageType,
  String? description,
}) async {
  final created = await ref
      .read(assetUploaderProvider)
      .addPhotos(id, paths, imageType: imageType, description: blankToNull(description));
  invalidateLiveAsset(ref, id);
  return created.length;
}

/// Asset 360° "Add Photo": camera / gallery → image type sheet → upload → refresh.
Future<void> addLivePhoto(BuildContext context, WidgetRef ref, String id) async {
  final path = await LiveDetailUpload.pickImage(context);
  if (path == null || !context.mounted) return;
  final problem = AssetFileRules.check(AssetUploader.fileNameOf(path), imageOnly: true);
  if (problem != null) {
    context.showSnack(problem);
    return;
  }
  final details = await showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PhotoDetailsSheet(path: path),
  );
  if (details == null || !context.mounted) return;
  try {
    await runWithProgress(
      context,
      'Uploading photo …',
      () => uploadLivePhotos(ref, id, [path], imageType: details.$1, description: details.$2),
    );
    if (context.mounted) context.showSnack('Photo added (${details.$1})');
  } catch (e) {
    if (context.mounted) context.showSnack(liveErrorMessage(e));
  }
}

class _PhotoDetailsSheet extends StatefulWidget {
  const _PhotoDetailsSheet({required this.path});

  final String path;

  @override
  State<_PhotoDetailsSheet> createState() => _PhotoDetailsSheetState();
}

class _PhotoDetailsSheetState extends State<_PhotoDetailsSheet> {
  final _type = TextEditingController(text: liveImageTypes.first);
  final _description = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _type.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final type = _type.text.trim();
    if (type.isEmpty) {
      setState(() => _error = 'Enter the image type');
      return;
    }
    Navigator.pop(context, (type, _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) => sheetFrame(context, [
    const SheetTitle('Add Photo', subtitle: 'Choose what the photo shows'),
    ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 140,
        child: Image(image: photoProvider(widget.path), errorBuilder: photoError, fit: BoxFit.cover),
      ),
    ),
    const SizedBox(height: 14),
    const FieldLabel('Image Type', required: true),
    SuggestField(
      controller: _type,
      suggestions: liveImageTypes,
      maxLength: 100,
      hint: 'e.g. Front View',
      error: _error,
      onChanged: () => _error == null ? null : setState(() => _error = null),
    ),
    const SizedBox(height: 14),
    formField(
      'Description',
      TextField(
        controller: _description,
        maxLength: 1000,
        style: inputStyle,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Optional', counterText: ''),
      ),
    ),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(onPressed: _save, child: const Text('Upload')),
        ),
      ],
    ),
  ]);
}

// ---------------------------------------------------------------- More Actions → Add Photo / Video

/// API mode "Add Photo / Video": several photos, an image type and a description → one upload.
/// Videos have no backend yet.
class LiveAddPhotoScreen extends ConsumerStatefulWidget {
  const LiveAddPhotoScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<LiveAddPhotoScreen> createState() => _LiveAddPhotoScreenState();
}

class _LiveAddPhotoScreenState extends ConsumerState<LiveAddPhotoScreen> {
  int _tab = 0;
  List<String> _photos = [];
  final _type = TextEditingController(text: liveImageTypes.first);
  final _description = TextEditingController();
  final _errors = <String, String>{};
  bool _busy = false;

  @override
  void dispose() {
    _type.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final path = await LiveDetailUpload.pickImage(context);
    if (path == null || !mounted) return;
    final problem = AssetFileRules.check(AssetUploader.fileNameOf(path), imageOnly: true);
    setState(() {
      if (problem != null) {
        _errors['file'] = problem;
      } else {
        _photos = [..._photos, path];
        _errors.remove('file');
      }
    });
  }

  Future<void> _save(AssetRegistration r) async {
    _errors.clear();
    if (_photos.isEmpty) _errors['file'] = 'Add at least one photo';
    if (_type.text.trim().isEmpty) _errors['ImageType'] = 'Enter the image type';
    setState(() {});
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final n = await uploadLivePhotos(
        ref,
        r.assetRegistrationId,
        _photos,
        imageType: _type.text.trim(),
        description: _description.text,
      );
      if (mounted) finishAction(context, '$n photo${n == 1 ? '' : 's'} added to ${r.title}');
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.from(e);
      setState(() {
        _busy = false;
        _errors.addAll(err.fieldErrors);
      });
      context.showSnack(err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveActionPage(
      action: MoreAction.addMedia,
      assetId: widget.assetId,
      button: (r) => _tab == 0
          ? busyButton(busy: _busy, onPressed: () => _save(r), label: 'Save Photo', icon: Icons.cloud_upload_outlined)
          : FilledButton(onPressed: () => showNotAvailableYet(context, 'Videos'), child: const Text('Save Video')),
      builder: (context, r) => [
        SegmentTabs(
          tabs: const [SegmentTab('Photo'), SegmentTab('Video')],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 14),
        if (_tab == 1)
          const NotAvailableYet(feature: 'Asset videos', icon: Icons.videocam_outlined)
        else ...[
          const FieldLabel('Photos', required: true),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => i == _photos.length
                  ? _AddBox(onTap: _busy ? null : _add)
                  : Stack(
                      children: [
                        GestureDetector(
                          onTap: () => openPhotoViewer(context, _photos, initialIndex: i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image(
                              image: photoProvider(_photos[i]),
                              errorBuilder: photoError,
                              width: 112,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton(
                            tooltip: 'Remove photo',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _photos = [..._photos]..removeAt(i)),
                            icon: const Icon(Icons.cancel_rounded, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          fieldError(_errors['file'] ?? _errors['Images']),
          const SizedBox(height: 4),
          Text('JPG, PNG or WEBP · up to 20 MB each', style: AppText.caption),
          const SizedBox(height: 14),
          const FieldLabel('Image Type', required: true),
          SuggestField(
            controller: _type,
            suggestions: liveImageTypes,
            maxLength: 100,
            hint: 'e.g. Front View',
            error: _errors['ImageType'],
            onChanged: () => _errors.containsKey('ImageType') ? setState(() => _errors.remove('ImageType')) : null,
          ),
          const SizedBox(height: 14),
          formField(
            'Description',
            TextField(
              controller: _description,
              maxLength: 1000,
              maxLines: 2,
              style: inputStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'Optional', errorText: _errors['Description']),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddBox extends StatelessWidget {
  const _AddBox({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 112,
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
          const SizedBox(height: 4),
          Text('Add Photo', style: AppText.link.copyWith(fontSize: 12)),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- More Actions → Add Document

/// API mode "Add Document": file (JPG / PNG / WEBP / PDF), name, type, lifecycle stage, version,
/// optional expiry and description → Media upload → POST /api/asset-documents.
class LiveAddDocumentScreen extends ConsumerStatefulWidget {
  const LiveAddDocumentScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<LiveAddDocumentScreen> createState() => _LiveAddDocumentScreenState();
}

class _LiveAddDocumentScreenState extends ConsumerState<LiveAddDocumentScreen> {
  LivePickedFile? _file;
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _stage = TextEditingController();
  final _version = TextEditingController(text: '1.0');
  final _description = TextEditingController();
  DateTime? _expiry;
  bool _stagePreset = false;
  bool _busy = false;
  final _errors = <String, String>{};

  @override
  void dispose() {
    for (final c in [_name, _type, _stage, _version, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await LiveDetailUpload.pickFile(context);
    if (f == null || !mounted) return;
    final problem = AssetFileRules.check(f.name, size: f.size);
    setState(() {
      if (problem != null) {
        _file = null;
        _errors['file'] = problem;
        return;
      }
      _file = f;
      _errors.remove('file');
      if (_name.text.trim().isEmpty) {
        final dot = f.name.lastIndexOf('.');
        _name.text = dot > 0 ? f.name.substring(0, dot) : f.name;
        _errors.remove('DocumentName');
      }
    });
  }

  void _clear(String key) => _errors.containsKey(key) ? setState(() => _errors.remove(key)) : null;

  Future<void> _upload(AssetRegistration r) async {
    _errors.clear();
    void need(String key, TextEditingController c, String message) {
      if (c.text.trim().isEmpty) _errors[key] = message;
    }

    if (_file == null) _errors['file'] = 'Choose a file';
    need('DocumentName', _name, 'Enter the document name');
    need('DocumentType', _type, 'Enter the document type');
    need('LifecycleStage', _stage, 'Enter the lifecycle stage');
    need('Version', _version, 'Enter the version');
    if (_file != null) {
      final problem = AssetFileRules.check(_file!.name, size: _file!.size);
      if (problem != null) _errors['file'] = problem;
    }
    setState(() {});
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final f = _file!;
      await ref
          .read(assetUploaderProvider)
          .addDocument(
            r.assetRegistrationId,
            f.path,
            fileName: f.name,
            documentName: _name.text.trim(),
            documentType: _type.text.trim(),
            lifecycleStage: _stage.text.trim(),
            version: _version.text.trim(),
            expiryDate: _expiry,
            description: blankToNull(_description.text),
          );
      invalidateLiveAsset(ref, r.assetRegistrationId);
      if (mounted) finishAction(context, '${_name.text.trim()} uploaded to ${r.title}');
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.from(e);
      setState(() {
        _busy = false;
        for (final MapEntry(:key, :value) in err.fieldErrors.entries) {
          _errors[switch (key) {
                'FileName' || 'FileUrl' || 'FileSize' => 'file',
                _ => key,
              }] =
              value;
        }
      });
      context.showSnack(err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = ref.watch(registrationOptionsProvider).value?.lifecycleStages ?? const <String>[];
    return LiveActionPage(
      action: MoreAction.addDocument,
      assetId: widget.assetId,
      button: (r) =>
          busyButton(busy: _busy, onPressed: () => _upload(r), label: 'Upload Document', icon: Icons.upload_file),
      builder: (context, r) {
        if (!_stagePreset) {
          _stagePreset = true;
          _stage.text = r.classification.lifecycleStage ?? '';
        }
        return [
          const FieldLabel('File', required: true),
          _FileBox(file: _file, error: _errors['file'] != null, onTap: _busy ? null : _pick),
          fieldError(_errors['file']),
          const SizedBox(height: 14),
          formField(
            'Document Name',
            required: true,
            TextField(
              controller: _name,
              maxLength: 200,
              style: inputStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Operation Manual',
                errorText: _errors['DocumentName'],
                counterText: '',
              ),
              onChanged: (_) => _clear('DocumentName'),
            ),
          ),
          const FieldLabel('Document Type', required: true),
          SuggestField(
            controller: _type,
            suggestions: liveDocumentTypes,
            maxLength: 100,
            hint: 'e.g. Manual',
            error: _errors['DocumentType'],
            onChanged: () => _clear('DocumentType'),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Lifecycle Stage', required: true),
          SuggestField(
            controller: _stage,
            suggestions: stages,
            maxLength: 100,
            hint: 'e.g. In Use',
            error: _errors['LifecycleStage'],
            onChanged: () => _clear('LifecycleStage'),
          ),
          const SizedBox(height: 14),
          formField(
            'Version',
            required: true,
            TextField(
              controller: _version,
              maxLength: 20,
              style: inputStyle,
              decoration: InputDecoration(hintText: '1.0', errorText: _errors['Version'], counterText: ''),
              onChanged: (_) => _clear('Version'),
            ),
          ),
          formField(
            'Expiry Date',
            Row(
              children: [
                Expanded(
                  child: DateBox(
                    value: _expiry,
                    firstDate: liveToday(),
                    hint: 'Optional',
                    error: _errors['ExpiryDate'],
                    onPicked: (d) => setState(() => _expiry = d),
                  ),
                ),
                if (_expiry != null)
                  IconButton(
                    tooltip: 'Clear expiry date',
                    onPressed: () => setState(() => _expiry = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          formField(
            'Description',
            TextField(
              controller: _description,
              maxLength: 1000,
              maxLines: 3,
              style: inputStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'Optional', errorText: _errors['Description']),
            ),
          ),
        ];
      },
    );
  }
}

class _FileBox extends StatelessWidget {
  const _FileBox({required this.file, required this.error, required this.onTap});

  final LivePickedFile? file;
  final bool error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = file;
    final pdf = f != null && AssetFileRules.extensionOf(f.name) == 'pdf';
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            f == null
                ? Icons.cloud_upload_outlined
                : pdf
                ? Icons.picture_as_pdf_outlined
                : Icons.image_outlined,
            size: 32,
            color: error ? AppColors.red : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f?.name ?? 'Choose a file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  f == null
                      ? 'PDF, JPG, PNG or WEBP · PDF up to 25 MB, images up to 20 MB'
                      : (liveSize(f.size) ?? 'Tap to choose another file'),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
