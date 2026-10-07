import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/registration_mock.dart';
import '../../data/repositories/assets_repository.dart';
import 'bulk_import.dart';

/// Bulk Registration: template → upload CSV → preview → import.
class BulkRegistrationPanel extends ConsumerStatefulWidget {
  const BulkRegistrationPanel({super.key});

  @override
  ConsumerState<BulkRegistrationPanel> createState() => _BulkRegistrationPanelState();
}

class _BulkRegistrationPanelState extends ConsumerState<BulkRegistrationPanel> {
  String? _fileName;
  List<BulkRow> _rows = const [];
  bool _importing = false;

  Future<void> _downloadTemplate() async {
    await Clipboard.setData(ClipboardData(text: bulkCsvColumns.join(',')));
    if (mounted) context.showSnack('Header row copied to the clipboard. Columns: ${bulkCsvColumns.join(', ')}');
  }

  void _load(String name, String text) {
    try {
      final rows = validateBulkCsv(text, (v) => ref.read(assetsProvider.notifier).ownerOf(v)?.id);
      setState(() {
        _fileName = name;
        _rows = rows;
      });
      if (rows.isEmpty) context.showSnack('$name has a header but no asset rows');
    } on BulkCsvException catch (e) {
      context.showSnack('$name: ${e.message}');
    }
  }

  Future<void> _upload() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['csv']);
      if (files.isEmpty || !mounted) return;
      final f = files.first;
      final text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
      if (mounted) _load(f.name, text);
    } catch (_) {
      if (mounted) context.showSnack('Could not open the file. Allow file access and try again.');
    }
  }

  Future<void> _import() async {
    final valid = _rows.where((r) => r.valid).toList();
    setState(() => _importing = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final assets = ref.read(assetsProvider.notifier);
    for (final r in valid) {
      assets.add(r.asset!);
    }
    setState(() {
      _importing = false;
      _rows = const [];
      _fileName = null;
    });
    final view = await showSuccessSheet(
      context,
      title: '${valid.length} assets imported',
      message: '${valid.map((r) => r.id).join(', ')} are now in the register.',
      primaryLabel: 'View Assets',
      secondaryLabel: 'Done',
    );
    if (view && mounted) context.go(Routes.assets);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _rows.where((r) => r.valid).length;
    final invalid = _rows.length - valid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: '1. Download Template',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fill one asset per row. Required: asset_id, name, category, type, site, location. '
                'Dates are YYYY-MM-DD.',
                style: AppText.secondary,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Download CSV template'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: '2. Upload CSV',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _upload,
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: DashedBorderPainter(color: AppColors.primary.withValues(alpha: .5), radius: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Column(
                      children: [
                        Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 34),
                        const SizedBox(height: 6),
                        Text(_fileName ?? 'Upload CSV', style: AppText.bodyStrong.copyWith(color: AppColors.primary)),
                        const SizedBox(height: 2),
                        Text('Tap to choose a .csv file', style: AppText.caption),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _load('sample_assets.csv', sampleBulkCsv),
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('No file? Use the sample CSV'),
              ),
            ],
          ),
        ),
        if (_rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: '3. Preview (${_rows.length} rows)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    StatusChip('$valid valid', tone: ChipTone.green, icon: Icons.check_circle_rounded),
                    const SizedBox(width: 8),
                    StatusChip(
                      '$invalid invalid',
                      tone: invalid == 0 ? ChipTone.grey : ChipTone.red,
                      icon: Icons.error,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 64,
                    horizontalMargin: 4,
                    columnSpacing: 14,
                    headingTextStyle: AppText.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.text),
                    columns: const [
                      DataColumn(label: Text('Line')),
                      DataColumn(label: Text('Asset')),
                      DataColumn(label: Text('Result')),
                    ],
                    rows: [
                      for (final r in _rows)
                        DataRow(
                          color: WidgetStatePropertyAll(r.valid ? null : AppColors.redBg.withValues(alpha: .4)),
                          cells: [
                            DataCell(Text('${r.line}', style: AppText.caption)),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 130),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.id.isEmpty ? '—' : r.id, style: AppText.bodyStrong.copyWith(fontSize: 12.5)),
                                    Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              r.valid
                                  ? const StatusChip('Valid', tone: ChipTone.green, icon: Icons.check_rounded)
                                  : ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 140),
                                      child: Text(
                                        r.errors.join('; '),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.caption.copyWith(color: AppColors.red),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: valid == 0 || _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.playlist_add_check_rounded),
                  label: Text(invalid == 0 ? 'Import $valid assets' : 'Import $valid valid assets'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
