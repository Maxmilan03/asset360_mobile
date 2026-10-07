import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/document.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/documents_repository.dart';
import '../common/asset_picker.dart';
import '../common/scan_capture.dart';
import 'document_widgets.dart';

/// Add Document (right screen of design/14_documents.jpg).
class AddDocumentScreen extends ConsumerStatefulWidget {
  const AddDocumentScreen({super.key, this.assetId});

  final String? assetId;

  /// Tests replace the system file picker with a fixed file.
  @visibleForTesting
  static Future<(String, String, double)?> Function(BuildContext)? debugPickFile;

  @override
  ConsumerState<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends ConsumerState<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _version = TextEditingController(text: 'v1.0');
  final _description = TextEditingController();
  String? _assetId;
  String? _type;
  String? _category;
  DateTime? _expiry;
  (String, String, double)? _file;
  bool _submitted = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _assetId = widget.assetId;
    _description.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(AddDocumentScreen old) {
    super.didUpdateWidget(old);
    if (widget.assetId != null && widget.assetId != old.assetId) _assetId = widget.assetId;
  }

  @override
  void dispose() {
    _name.dispose();
    _version.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _file != null || _type != null || _name.text.isNotEmpty || _description.text.isNotEmpty || _expiry != null;

  bool get _expires => _type != null && DocType.expires(_type!);

  Future<void> _pickAsset() async {
    final id = await showAssetPicker(context, selectedId: _assetId);
    if (id != null) setState(() => _assetId = id);
  }

  Future<void> _scanAsset() async {
    final code = await showScanCapture(context, suggestions: const ['GEN-00045', 'HVAC-0012', 'FP-0021']);
    if (code == null || !mounted) return;
    final a = ref.read(assetsProvider.notifier).ownerOf(code);
    if (a == null) {
      context.showSnack('No asset found for $code');
      return;
    }
    setState(() => _assetId = a.id);
  }

  Future<void> _pickFile() async {
    final picked = await (AddDocumentScreen.debugPickFile ?? pickDocumentFile)(context);
    if (picked == null || !mounted) return;
    setState(() {
      _file = picked;
      // Autofill the name from the file (without extension) unless the user typed one.
      if (_name.text.trim().isEmpty) {
        final n = picked.$1;
        final dot = n.lastIndexOf('.');
        _name.text = dot > 0 ? n.substring(0, dot) : n;
      }
    });
  }

  Future<void> _cancel() async {
    if (_dirty) {
      final ok = await showConfirmDialog(
        context,
        title: 'Discard document?',
        message: 'The selected file and details will be lost.',
        confirmLabel: 'Discard',
      );
      if (!ok) return;
    }
    if (mounted) context.pop();
  }

  Future<void> _upload() async {
    setState(() => _submitted = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _assetId == null || _type == null || _file == null || (_expires && _expiry == null)) {
      context.showSnack('Complete the required fields');
      return;
    }
    final f = _file!;
    final ext = f.$1.contains('.') ? f.$1.substring(f.$1.lastIndexOf('.')) : '';
    var name = _name.text.trim();
    if (ext.isNotEmpty && !name.toLowerCase().endsWith(ext.toLowerCase())) name = '$name$ext';
    // Simulated 1.5 s upload.
    for (var i = 1; i <= 15; i++) {
      setState(() => _progress = i / 15);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    ref
        .read(documentsProvider.notifier)
        .add(
          assetId: _assetId!,
          name: name,
          type: _type!,
          sizeMb: f.$3,
          category: _category,
          version: _version.text.trim().isEmpty ? null : _version.text.trim(),
          description: _description.text.trim(),
          expiry: _expires ? _expiry : null,
          filePath: f.$2,
        );
    context.showSnack('$name uploaded');
    context.go(Routes.documents);
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetId == null ? null : ref.watch(assetByIdProvider(_assetId!));
    final uploading = _progress != null;
    return AppScaffold(
      bottomActions: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (uploading) ...[
            Text('Uploading… ${((_progress ?? 0) * 100).round()}%', style: AppText.caption),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: _progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: uploading ? null : _cancel, child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: uploading ? null : _upload, child: const Text('Upload Document')),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const PageTitle(
              title: 'Add Document',
              subtitle: 'Upload and link document to an asset',
              help:
                  'Choose the asset, the document type and the file (PDF, Word, Excel or image, up to 10 MB). '
                  'Warranties, certificates, contracts and insurance need an expiry date; documents expiring '
                  'within 30 days count as Expiring Soon.',
            ),
            const SizedBox(height: 12),
            const FieldLabel('Select Asset', required: true),
            Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _submitted && asset == null ? AppColors.red : AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: asset == null
                  ? ListTile(
                      leading: IconSquare(icon: Icons.inventory_2_outlined, tone: TileTone.lavender, size: 40),
                      title: Text('Select an asset', style: AppText.bodyStrong),
                      subtitle: Text('Search by ID or name, or scan the tag', style: AppText.caption),
                      trailing: IconButton(
                        tooltip: 'Scan asset tag',
                        onPressed: _scanAsset,
                        icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                      ),
                      onTap: _pickAsset,
                    )
                  : AssetListTile(
                      title: asset.name,
                      subtitle: asset.id,
                      location: asset.location,
                      imagePath: asset.imagePath,
                      trailingTop: IconButton(
                        tooltip: 'Scan asset tag',
                        visualDensity: VisualDensity.compact,
                        onPressed: _scanAsset,
                        icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                      ),
                      onTap: _pickAsset,
                    ),
            ),
            // Always present so the fields below keep their list position (and their error state).
            _submitted && asset == null
                ? const Padding(
                    padding: EdgeInsets.only(top: 6, left: 12),
                    child: Text('Select the asset', style: TextStyle(color: AppColors.red, fontSize: 12)),
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 14),
            const FieldLabel('Document Type', required: true),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              hint: const Text('Select document type'),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.description_outlined, size: 20, color: AppColors.text),
              ),
              items: [for (final t in DocType.uploadTypes) DropdownMenuItem(value: t, child: Text(t))],
              validator: (v) => v == null ? 'Select the document type' : null,
              onChanged: (v) => setState(() {
                _type = v;
                if (!_expires) _expiry = null;
              }),
            ),
            const SizedBox(height: 14),
            const FieldLabel('File', required: true),
            _UploadBox(
              file: _file,
              error: _submitted && _file == null,
              onTap: uploading ? null : _pickFile,
              onClear: uploading ? null : () => setState(() => _file = null),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Document Name', required: true),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'e.g. Generator_Warranty_2026'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the document name' : null,
            ),
            const SizedBox(height: 14),
            FieldPair(
              LabeledField(
                label: 'Category',
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  hint: const Text('Select'),
                  items: [for (final c in docCategories) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setState(() => _category = v),
                ),
              ),
              LabeledField(
                label: 'Version',
                child: TextFormField(
                  controller: _version,
                  decoration: const InputDecoration(hintText: 'v1.0'),
                ),
              ),
            ),
            // One child whether or not the type expires, so the description keeps its state.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_expires) ...[
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'Expiry Date',
                    required: true,
                    child: DateBox(
                      value: _expiry,
                      firstDate: DemoClock.today,
                      error: _submitted && _expiry == null ? 'Select the expiry date' : null,
                      onPicked: (v) => setState(() => _expiry = v),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Description'),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(hintText: 'Add a short description of the document'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  const _UploadBox({required this.file, required this.error, required this.onTap, required this.onClear});

  final (String, String, double)? file;
  final bool error;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final f = file;
    if (f != null) {
      final ext = f.$1.contains('.') ? f.$1.split('.').last.toLowerCase() : '';
      return AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(docIcon(ext), color: docIconColor(ext), size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.$1, style: AppText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    f.$3 < 1 ? '${(f.$3 * 1024).round()} KB' : '${f.$3.toStringAsFixed(1)} MB',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            IconButton(tooltip: 'Remove file', onPressed: onClear, icon: const Icon(Icons.close_rounded)),
          ],
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        painter: DashedBorderPainter(color: error ? AppColors.red : AppColors.primary, radius: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 36),
              const SizedBox(height: 6),
              Text('Tap to upload or drag and drop', style: AppText.bodyStrong, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Supports PDF, DOC, DOCX, XLS, XLSX, JPG, PNG', style: AppText.caption, textAlign: TextAlign.center),
              Text('Max size: 10 MB', style: AppText.caption),
              if (error) ...[
                const SizedBox(height: 4),
                const Text('Choose a file', style: TextStyle(color: AppColors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
