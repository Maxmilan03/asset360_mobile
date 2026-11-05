import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/features/more/documents/document_widgets.dart';

/// In-app viewer: PDFs with pdfx (pinch-zoom, page count), images in a zoomable viewer.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.id, this.version});

  final String id;
  final String? version;

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  PdfControllerPinch? _pdf;
  int _page = 1;
  int _pages = 0;
  String? _error;

  String? get _path {
    final d = ref.read(documentsProvider).doc(widget.id);
    if (d == null) return null;
    if (widget.version == null) return d.filePath;
    return d.versions.where((v) => v.version == widget.version).firstOrNull?.filePath ?? d.filePath;
  }

  @override
  void initState() {
    super.initState();
    final d = ref.read(documentsProvider).doc(widget.id);
    final path = _path;
    if (d != null && path != null && d.isPdf) {
      try {
        _pdf = PdfControllerPinch(
          document: path.startsWith('assets/') ? PdfDocument.openAsset(path) : PdfDocument.openFile(path),
        );
      } catch (_) {
        _error = 'This PDF could not be opened.';
      }
    }
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(documentsProvider).doc(widget.id);
    if (d == null) {
      return AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Document not found', message: widget.id),
      );
    }
    final path = _path;
    return AppScaffold(
      backgroundColor: AppColors.greyBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: PageTitle(
              title: d.name,
              subtitle: [
                d.type,
                widget.version ?? d.version ?? '',
                if (_pages > 0) 'Page $_page of $_pages',
              ].where((s) => s.isNotEmpty).join(' · '),
              trailing: IconButton(
                tooltip: 'Download',
                onPressed: () => downloadDocument(context, d),
                icon: Icon(Icons.download_rounded, color: AppColors.primary),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: context.bottomInset),
              child: path == null
                  ? const EmptyState(icon: Icons.insert_drive_file_outlined, title: 'No file attached')
                  : d.isImage
                  ? InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: Image(image: photoProvider(path), errorBuilder: photoError, fit: BoxFit.contain),
                      ),
                    )
                  : _pdf != null && _error == null
                  ? PdfViewPinch(
                      controller: _pdf!,
                      onDocumentLoaded: (doc) => setState(() => _pages = doc.pagesCount),
                      onPageChanged: (p) => setState(() => _page = p),
                      onDocumentError: (_) => setState(() => _error = 'This PDF could not be opened.'),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(docIcon(d.extension), size: 64, color: docIconColor(d.extension)),
                            const SizedBox(height: 12),
                            Text(
                              _error ?? 'Preview is not available for .${d.extension} files.',
                              textAlign: TextAlign.center,
                              style: AppText.secondary,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => downloadDocument(context, d),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Download to open'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
