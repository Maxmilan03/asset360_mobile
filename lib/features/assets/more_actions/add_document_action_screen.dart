import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';
import 'package:asset360_mobile/features/more/documents/add_document_screen.dart';
import 'package:asset360_mobile/features/more/documents/document_widgets.dart';

/// Type, title, file (PDF / Office / image, max 10 MB) and description → a document of the asset
/// (Documents module and the asset's Documents tab).
class AddDocumentActionScreen extends ConsumerStatefulWidget {
  const AddDocumentActionScreen({super.key, required this.assetId});

  final String? assetId;

  /// Tests replace the system file picker with a fixed file.
  @visibleForTesting
  static Future<(String, String, double)?> Function(BuildContext)? debugPickFile;

  @override
  ConsumerState<AddDocumentActionScreen> createState() => _AddDocumentActionScreenState();
}

class _AddDocumentActionScreenState extends ConsumerState<AddDocumentActionScreen> {
  String? _type;
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _expiry;
  (String, String, double)? _file;
  final _errors = <String, String>{};

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _expires => _type != null && DocType.expires(_type!);

  Future<void> _pick() async {
    // Files over 10 MB are refused by pickDocumentFile with an error message.
    final picked = await (AddDocumentActionScreen.debugPickFile ?? pickDocumentFile)(context);
    if (picked == null || !mounted) return;
    if (picked.$3 > maxDocSizeMb) {
      setState(() => _errors['file'] = '${picked.$1} is ${picked.$3.toStringAsFixed(1)} MB – the limit is 10 MB');
      return;
    }
    setState(() {
      _file = picked;
      _errors.remove('file');
      if (_title.text.trim().isEmpty) {
        final n = picked.$1;
        final dot = n.lastIndexOf('.');
        _title.text = dot > 0 ? n.substring(0, dot) : n;
        _errors.remove('title');
      }
    });
  }

  void _upload(Asset a) {
    _errors.clear();
    if (_type == null) _errors['type'] = 'Choose the document type';
    if (_title.text.trim().isEmpty) _errors['title'] = 'Enter the document title';
    if (_file == null) _errors['file'] = 'Choose a file';
    if (_expires && _expiry == null) _errors['expiry'] = 'Choose the expiry date';
    setState(() {});
    if (_errors.isNotEmpty) return;
    final f = _file!;
    final ext = f.$1.contains('.') ? f.$1.substring(f.$1.lastIndexOf('.')) : '';
    var name = _title.text.trim();
    if (ext.isNotEmpty && !name.toLowerCase().endsWith(ext.toLowerCase())) name = '$name$ext';
    ref
        .read(documentsProvider.notifier)
        .add(
          assetId: a.id,
          name: name,
          type: _type!,
          sizeMb: f.$3,
          description: _description.text.trim(),
          expiry: _expires ? _expiry : null,
          filePath: f.$2,
        );
    finishAction(context, '$name uploaded to ${a.id}');
  }

  @override
  Widget build(BuildContext context) {
    return MoreActionPage(
      action: MoreAction.addDocument,
      assetId: widget.assetId,
      button: (a) => FilledButton(onPressed: () => _upload(a), child: const Text('Upload Document')),
      builder: (context, a) => [
        formField(
          'Document Type',
          required: true,
          SelectField(
            value: _type,
            options: DocType.uploadTypes,
            error: _errors['type'],
            onChanged: (v) => setState(() {
              _type = v;
              _errors.remove('type');
            }),
          ),
        ),
        formField(
          'Document Title',
          required: true,
          TextField(
            controller: _title,
            style: inputStyle,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'e.g. User Manual', errorText: _errors['title']),
            onChanged: (_) => _errors.containsKey('title') ? setState(() => _errors.remove('title')) : null,
          ),
        ),
        const FieldLabel('Upload Document', required: true),
        DocumentUploadBox(
          file: _file,
          error: false,
          onTap: _pick,
          onClear: () => setState(() => _file = null),
        ),
        fieldError(_errors['file']),
        const SizedBox(height: 14),
        if (_expires)
          formField(
            'Expiry Date',
            required: true,
            DateBox(
              value: _expiry,
              firstDate: DemoClock.today,
              error: _errors['expiry'],
              onPicked: (d) => setState(() {
                _expiry = d;
                _errors.remove('expiry');
              }),
            ),
          ),
        formField(
          'Description',
          TextField(
            controller: _description,
            maxLines: 3,
            maxLength: 500,
            style: inputStyle,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Add a short description of the document'),
          ),
        ),
      ],
    );
  }
}
