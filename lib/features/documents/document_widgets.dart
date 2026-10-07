import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// File types accepted on upload.
const allowedDocExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'];
const maxDocSizeMb = 10.0;

/// Type chip colour.
ChipTone docTypeTone(String type) => switch (type) {
  DocType.manual || DocType.maintenance || DocType.serviceReport => ChipTone.blue,
  DocType.warranty || DocType.insurance => ChipTone.green,
  DocType.certificate || DocType.contract => ChipTone.purple,
  DocType.photo => ChipTone.amber,
  DocType.invoice => ChipTone.orange,
  _ => ChipTone.grey,
};

IconData docIcon(String extension) => switch (extension) {
  'pdf' => Icons.picture_as_pdf_rounded,
  'doc' || 'docx' => Icons.description_rounded,
  'xls' || 'xlsx' => Icons.table_chart_rounded,
  'jpg' || 'jpeg' || 'png' => Icons.image_rounded,
  _ => Icons.insert_drive_file_rounded,
};

Color docIconColor(String extension) => switch (extension) {
  'pdf' => AppColors.red,
  'xls' || 'xlsx' => AppColors.green,
  'jpg' || 'jpeg' || 'png' => AppColors.iconBlue,
  _ => AppColors.primary,
};

/// File thumbnail: the photo itself for images, else a file-type icon square.
class DocThumb extends StatelessWidget {
  const DocThumb({super.key, required this.doc, this.size = 52});

  final AssetDocument doc;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (doc.isImage && doc.filePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image(
          image: photoProvider(doc.filePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _icon(),
        ),
      );
    }
    return _icon();
  }

  Widget _icon() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: docIconColor(doc.extension).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(docIcon(doc.extension), color: docIconColor(doc.extension), size: size * .55),
  );
}

/// "20 Sep 2026", or "Valid till: 25 Sep 2028" for expiring types.
String docDateLabel(AssetDocument d) => d.expiry == null
    ? DemoClock.formatDate(d.uploadedAt)
    : switch (expiryState(d)) {
        ExpiryState.expired => 'Expired: ${DemoClock.formatDate(d.expiry!)}',
        ExpiryState.expiring => 'Expires: ${DemoClock.formatDate(d.expiry!)}',
        _ => 'Valid till: ${DemoClock.formatDate(d.expiry!)}',
      };

/// Documents list row: thumbnail, name, type chip, "asset | name", size | date, and the ⋮ menu.
class DocRow extends ConsumerWidget {
  const DocRow({super.key, required this.doc, this.compact = false});

  final AssetDocument doc;

  /// Related Documents: no asset line, chevron instead of ⋮.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = doc;
    final asset = ref.watch(assetByIdProvider(d.assetId));
    final state = expiryState(d);
    return InkWell(
      onTap: () => context.push(Routes.documentDetail(d.id)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, compact ? 8 : 10, 4, compact ? 8 : 10),
        child: Row(
          children: [
            DocThumb(doc: d, size: compact ? 40 : 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong.copyWith(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusChip(d.type, tone: docTypeTone(d.type)),
                    ],
                  ),
                  if (!compact)
                    Text(
                      '${d.assetId}  |  ${asset?.name ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: AppColors.text),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (!compact) ...[
                        Text(d.sizeLabel, style: AppText.caption),
                        Text('  |  ', style: AppText.caption),
                      ],
                      Icon(
                        d.expiry == null ? Icons.event_outlined : Icons.verified_outlined,
                        size: 12,
                        color: state == ExpiryState.expired || state == ExpiryState.expiring
                            ? AppColors.red
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            text: docDateLabel(d),
                            children: [
                              if (d.pendingReview)
                                const TextSpan(
                                  text: '  •  Pending',
                                  style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: state == ExpiryState.expired || state == ExpiryState.expiring ? AppColors.red : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (compact) Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary) else DocMenuButton(doc: d),
          ],
        ),
      ),
    );
  }
}

/// ⋮ View, Download, Share, Rename, Replace Version, Delete.
class DocMenuButton extends ConsumerWidget {
  const DocMenuButton({super.key, required this.doc, this.onDeleted});

  final AssetDocument doc;

  /// Called after a delete (Document Details pops back).
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Document actions',
      icon: Icon(Icons.more_vert_rounded, color: AppColors.text),
      onSelected: (v) async {
        switch (v) {
          case 'view':
            context.push(Routes.documentView(doc.id));
          case 'download':
            await downloadDocument(context, doc);
          case 'share':
            await shareDocument(context, doc);
          case 'rename':
            await renameDocument(context, ref, doc);
          case 'replace':
            await replaceDocumentVersion(context, ref, doc);
          case 'delete':
            if (await deleteDocument(context, ref, doc)) onDeleted?.call();
        }
      },
      itemBuilder: (_) => [
        for (final (v, icon, label) in [
          ('view', Icons.visibility_outlined, 'View'),
          ('download', Icons.download_rounded, 'Download'),
          ('share', Icons.share_outlined, 'Share'),
          ('rename', Icons.drive_file_rename_outline_rounded, 'Rename'),
          ('replace', Icons.upload_file_rounded, 'Replace Version'),
          ('delete', Icons.delete_outline_rounded, 'Delete'),
        ])
          PopupMenuItem(
            value: v,
            child: Row(
              children: [
                Icon(icon, size: 20, color: v == 'delete' ? AppColors.red : AppColors.text),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: v == 'delete' ? AppColors.red : AppColors.text)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Reads a bundled ('assets/…') or device file.
Future<Uint8List> readDocBytes(String path) async {
  if (path.startsWith('assets/')) return (await rootBundle.load(path)).buffer.asUint8List();
  return File(path).readAsBytes();
}

String _mime(String ext) => switch (ext) {
  'pdf' => 'application/pdf',
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  _ => 'application/octet-stream',
};

/// Download: saves a copy through the system save dialog (Downloads / Documents), then offers "Open".
Future<void> downloadDocument(BuildContext context, AssetDocument d) async {
  final path = d.filePath;
  if (path == null) {
    context.showSnack('${d.name} has no file attached');
    return;
  }
  try {
    final bytes = await readDocBytes(path);
    final uri = await FilePicker.saveFile(fileName: d.name, bytes: bytes, mimeType: _mime(d.extension));
    if (uri == null || !context.mounted) return; // cancelled
    final where = Uri.decodeComponent(uri.path);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          margin: context.snackMargin,
          content: Text('Saved to $where'),
          action: SnackBarAction(label: 'Open', onPressed: () => context.push(Routes.documentView(d.id))),
        ),
      );
  } catch (_) {
    if (context.mounted) context.showSnack('Could not save ${d.name}. Allow storage access and try again.');
  }
}

Future<void> shareDocument(BuildContext context, AssetDocument d) async {
  await Clipboard.setData(
    ClipboardData(text: '${d.name} (${d.type}, ${d.assetId})\nhttps://asset360.purpleiq.ae/documents/${d.id}'),
  );
  if (context.mounted) context.showSnack('Link to ${d.name} copied. The share sheet would open here (demo).');
}

Future<void> renameDocument(BuildContext context, WidgetRef ref, AssetDocument d) async {
  final name = await showDialog<String>(
    context: context,
    useRootNavigator: false,
    builder: (_) => _RenameDialog(initial: d.name),
  );
  if (name == null || name == d.name || !context.mounted) return;
  ref.read(documentsProvider.notifier).rename(d.id, name);
  context.showSnack('Renamed to $name');
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _c = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.initial.contains('.') ? '.${widget.initial.split('.').last}' : '';
    return AlertDialog(
      title: const Text('Rename document'),
      content: TextField(
        controller: _c,
        autofocus: true,
        decoration: InputDecoration(labelText: 'File name', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            var n = _c.text.trim();
            if (n.isEmpty) return setState(() => _error = 'Enter a name');
            if (ext.isNotEmpty && !n.toLowerCase().endsWith(ext.toLowerCase())) n = '$n$ext';
            Navigator.pop(context, n);
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

/// Picks a document file (allowed types, max 10 MB). Returns (name, path, MB) or null; shows the error itself.
Future<(String, String, double)?> pickDocumentFile(BuildContext context) async {
  try {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: allowedDocExtensions);
    if (files.isEmpty) return null;
    final f = files.first;
    final mb = (await f.length() ?? 0) / (1024 * 1024);
    if (mb > maxDocSizeMb) {
      if (context.mounted) context.showSnack('${f.name} is ${mb.toStringAsFixed(1)} MB – the limit is 10 MB');
      return null;
    }
    if (f.path == null) return null;
    return (f.name, f.path!, mb);
  } catch (_) {
    if (context.mounted) context.showSnack('Could not open files. Allow file access and try again.');
    return null;
  }
}

Future<void> replaceDocumentVersion(BuildContext context, WidgetRef ref, AssetDocument d) async {
  final picked = await pickDocumentFile(context);
  if (picked == null || !context.mounted) return;
  final v = ref
      .read(documentsProvider.notifier)
      .replaceVersion(d.id, fileName: picked.$1, path: picked.$2, sizeMb: picked.$3);
  context.showSnack('${d.name} updated to $v');
}

/// Returns true when deleted.
Future<bool> deleteDocument(BuildContext context, WidgetRef ref, AssetDocument d) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Delete ${d.name}?',
    message: 'The document and its ${d.versions.length} version${d.versions.length == 1 ? '' : 's'} are removed.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  ref.read(documentsProvider.notifier).delete(d.id);
  context.showSnack('${d.name} deleted');
  return true;
}
