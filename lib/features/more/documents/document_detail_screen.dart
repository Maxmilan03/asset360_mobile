import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/more/documents/document_widgets.dart';

/// Document Details (middle screen of design/14_documents.jpg).
class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  bool _editing = false;
  bool _allRelated = false;
  final _name = TextEditingController();
  final _version = TextEditingController();
  final _description = TextEditingController();
  String _type = DocType.manual;
  String? _category;
  DateTime? _expiry;

  @override
  void dispose() {
    _name.dispose();
    _version.dispose();
    _description.dispose();
    super.dispose();
  }

  void _startEdit(AssetDocument d) => setState(() {
    _name.text = d.name;
    _version.text = d.version ?? '';
    _description.text = d.description;
    _type = d.type;
    _category = d.category;
    _expiry = d.expiry;
    _editing = true;
  });

  void _save(AssetDocument d) {
    final name = _name.text.trim();
    if (name.isEmpty) {
      context.showSnack('The name cannot be empty');
      return;
    }
    ref
        .read(documentsProvider.notifier)
        .update(
          d.copyWith(
            name: name,
            type: _type,
            category: _category,
            version: _version.text.trim().isEmpty ? d.version : _version.text.trim(),
            description: _description.text.trim(),
            expiry: DocType.expires(_type) ? _expiry : null,
            clearExpiry: !DocType.expires(_type) || _expiry == null,
          ),
        );
    setState(() => _editing = false);
    context.showSnack('Document information saved');
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(documentsProvider);
    final d = st.doc(widget.id);
    if (d == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Document not found',
          message: '${widget.id} may have been deleted.',
          actionLabel: 'Back to Documents',
          onAction: () => context.pop(),
        ),
      );
    }
    final asset = ref.watch(assetByIdProvider(d.assetId));
    final related = st.forAsset(d.assetId).where((x) => x.id != d.id).toList();
    final shown = _allRelated ? related : related.take(4).toList();
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(title: 'Document Details'),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AssetThumb(
                  imagePath: asset?.imagePath,
                  fallbackIcon: asset == null ? Icons.description_outlined : assetIcon(asset),
                  size: 84,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(docIcon(d.extension), color: docIconColor(d.extension), size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              d.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyStrong,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          StatusChip(d.type, tone: docTypeTone(d.type)),
                          if (d.pendingReview) const StatusChip('Pending review', tone: ChipTone.amber),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(asset?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                      Text(d.assetId, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                    ],
                  ),
                ),
                DocMenuButton(doc: d, onDeleted: () => context.pop()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(Routes.documentView(d.id)),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => downloadDocument(context, d),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                ),
              ),
            ],
          ),
          if (d.pendingReview) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(documentsProvider.notifier).update(d.copyWith(pendingReview: false));
                context.showSnack('${d.name} approved');
              },
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Approve document'),
            ),
          ],
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Document Information',
                  actionLabel: _editing ? null : 'Edit',
                  actionIcon: Icons.edit_outlined,
                  onAction: () => _startEdit(d),
                ),
                const SizedBox(height: 8),
                if (_editing) ..._editFields(d) else ..._infoRows(d),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Related Documents (${related.length})',
            actionLabel: related.length > 4 && !_allRelated ? 'View All' : null,
            actionIcon: null,
            onAction: () => setState(() => _allRelated = true),
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: related.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('No other documents for this asset', style: AppText.secondary),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 64),
                        DocRow(doc: shown[i], compact: true),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Versions (${d.versions.length})',
            actionLabel: 'Upload new',
            actionIcon: Icons.upload_file_rounded,
            onAction: () => replaceDocumentVersion(context, ref, d),
            child: Column(
              children: [
                for (final v in d.versions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: v.version == d.version ? AppColors.primary : AppColors.greyBg,
                      child: Text(
                        v.version,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: v.version == d.version ? Colors.white : AppColors.text,
                        ),
                      ),
                    ),
                    title: Text(
                      v.version == d.version ? '${v.version} (current)' : v.version,
                      style: AppText.bodyStrong,
                    ),
                    subtitle: Text(
                      [DemoClock.formatDateTime(v.at), v.by, '${v.sizeMb.toStringAsFixed(1)} MB', ?v.note].join(' · '),
                      style: AppText.caption,
                    ),
                    onTap: () => context.push(Routes.documentView(d.id, version: v.version)),
                    trailing: v.version == d.version
                        ? null
                        : TextButton(
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Restore ${v.version}?',
                                message: '${v.version} becomes the current version of ${d.name}.',
                                confirmLabel: 'Restore',
                              );
                              if (!ok || !context.mounted) return;
                              ref.read(documentsProvider.notifier).restoreVersion(d.id, v.version);
                              context.showSnack('${v.version} restored');
                            },
                            child: const Text('Restore'),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _infoRows(AssetDocument d) => [
    InfoRow(label: 'Document Name', value: d.name),
    InfoRow(label: 'Document Type', value: d.type),
    InkWell(
      onTap: () => context.push(Routes.assetDetail(d.assetId)),
      child: InfoRow(
        label: 'Asset',
        value: d.assetId,
        valueWidget: Text(
          d.assetId,
          style: AppText.body.copyWith(
            fontSize: 13,
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
        ),
      ),
    ),
    InfoRow(label: 'Category', value: d.category ?? '—'),
    InfoRow(label: 'Version', value: d.version ?? '—'),
    InfoRow(label: 'File Size', value: d.sizeLabel),
    InfoRow(label: 'Upload Date', value: DemoClock.formatDateTime(d.uploadedAt)),
    InfoRow(label: 'Uploaded By', value: d.uploadedBy),
    if (d.expiry != null)
      InfoRow(
        label: 'Expiry Date',
        value: docDateLabel(d),
        valueColor: expiryState(d) == ExpiryState.valid ? null : AppColors.red,
      ),
    InfoRow(label: 'Description', value: d.description.isEmpty ? '—' : d.description),
  ];

  List<Widget> _editFields(AssetDocument d) => [
    TextField(
      controller: _name,
      decoration: const InputDecoration(labelText: 'Document Name'),
    ),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(
      initialValue: DocType.all.contains(_type) ? _type : DocType.other,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Document Type'),
      items: [for (final t in DocType.all) DropdownMenuItem(value: t, child: Text(t))],
      onChanged: (v) => setState(() => _type = v ?? _type),
    ),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(
      initialValue: docCategories.contains(_category) ? _category : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Category'),
      items: [for (final c in docCategories) DropdownMenuItem(value: c, child: Text(c))],
      onChanged: (v) => setState(() => _category = v),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: _version,
      decoration: const InputDecoration(labelText: 'Version'),
    ),
    if (DocType.expires(_type)) ...[
      const SizedBox(height: 10),
      LabeledField(
        label: 'Expiry Date',
        child: DateBox(value: _expiry, firstDate: DemoClock.today, onPicked: (v) => setState(() => _expiry = v)),
      ),
    ],
    const SizedBox(height: 10),
    TextField(
      controller: _description,
      maxLines: 3,
      maxLength: 500,
      decoration: const InputDecoration(labelText: 'Description'),
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
        const SizedBox(width: 8),
        FilledButton(onPressed: () => _save(d), child: const Text('Save')),
      ],
    ),
  ];
}
