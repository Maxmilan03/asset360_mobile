import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/asset_actions.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_common.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_upload.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Tab contents of the live Asset 360° screen.

/// Every photo of the asset: the asset-images records first, then basicInformation.images not
/// already listed. (url, caption)
List<(String, String?)> liveGallery(AssetRegistration r, List<AssetImageRecord> images) {
  final seen = <String>{};
  return [
    for (final i in images)
      if (seen.add(i.fileUrl)) (i.fileUrl, i.imageType),
    for (final u in r.basicInformation.images)
      if (seen.add(u)) (u, null),
  ];
}

// ---------------------------------------------------------------- Overview

class LiveOverviewTab extends ConsumerWidget {
  const LiveOverviewTab({super.key, required this.asset});

  final AssetRegistration asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = asset;
    final b = r.basicInformation, c = r.classification;
    final l = r.locationAssignment.location, a = r.locationAssignment.assignment;
    final p = r.purchaseWarranty.purchase, w = r.purchaseWarranty.warranty;
    final t = r.additionalInformation.technical, o = r.additionalInformation.operational;
    const gap = SizedBox(height: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiveConditionCard(assetId: r.assetRegistrationId),
        gap,
        LiveCriticalityCard(assetId: r.assetRegistrationId),
        gap,
        LivePhotosCard(asset: r),
        gap,
        SectionCard(
          title: 'Basic Information',
          child: LiveInfoRows([
            ('Registration ID', r.assetRegistrationId),
            ('Asset Name', b.assetName),
            ('Asset Tag', b.assetTag),
            ('Barcode / QR', b.barcode),
            ('RFID Tag ID', b.rfidTagId),
            ('NFC UID', b.nfcUid),
            ('Manufacturer', b.manufacturer),
            ('Model', b.model),
            ('Serial Number', b.serialNumber),
            ('Status', b.status),
            ('Condition', b.condition),
            ('Criticality', r.criticality),
            ('Description', b.description),
          ]),
        ),
        gap,
        SectionCard(
          title: 'Classification',
          child: LiveInfoRows([
            ('Category', c.category),
            ('Sub Category', c.subCategory),
            ('Asset Type', c.assetType),
            ('Asset Sub Type', c.assetSubType),
            ('Function / Purpose', c.functionPurpose),
            ('Department', c.department),
            ('Cost Center', c.costCenter),
            ('Business Unit', c.businessUnit),
            ('Tagging Method', c.taggingMethod),
            ('Compliance Category', c.complianceCategory),
            ('Lifecycle Stage', c.lifecycleStage),
            ('Keywords', c.keywords.join(', ')),
          ]),
        ),
        gap,
        SectionCard(
          title: 'Location & Assignment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiveInfoRows([
                ('Location', l.serverLocationPath ?? l.locationPath),
                ('GPS', l.latitude == null || l.longitude == null ? null : '${l.latitude}, ${l.longitude}'),
              ]),
              const LiveSubTitle('Assignment'),
              LiveInfoRows([
                ('Assigned To', a.assignedToName),
                ('Custodian Department', a.custodianDepartment),
                ('Responsible Team', a.responsibleTeam),
                ('Ownership', a.ownershipType),
                ('Cost Center', a.costCenter),
                ('Start Date', liveDate(a.assignmentStartDate)),
                ('End Date', liveDate(a.assignmentEndDate)),
              ], empty: 'Not assigned'),
            ],
          ),
        ),
        gap,
        SectionCard(
          title: 'Purchase & Warranty',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiveInfoRows([
                ('PO Number', p.purchaseOrderNumber),
                ('Invoice Number', p.invoiceNumber),
                ('Supplier / Vendor', p.supplierVendor),
                ('Manufacturer', p.manufacturer),
                ('Purchase Date', liveDate(p.purchaseDate)),
                ('Delivery Date', liveDate(p.deliveryDate)),
                ('Purchase Cost', liveMoney(p.purchaseCost, p.currency)),
                ('Quantity', liveNum(p.quantity, p.quantityUnit)),
                ('Tax', p.taxPercent == null ? null : '${liveNum(p.taxPercent)} %'),
                ('Total Cost', liveMoney(p.totalCost ?? p.totalCostPreview, p.currency)),
                ('Currency', p.currency),
                ('Payment Terms', p.paymentTerms),
                ('Procurement Method', p.procurementMethod),
                ('Project Reference', p.projectReference),
                ('Remarks', p.remarks),
              ]),
              const LiveSubTitle('Invoice & Documents'),
              LiveFileList(files: r.purchaseWarranty.documents),
              const LiveSubTitle('Warranty'),
              LiveInfoRows([
                ('Warranty Type', w.warrantyType),
                ('Start Date', liveDate(w.warrantyStartDate)),
                ('Period', w.warrantyPeriod == null ? null : liveNum(w.warrantyPeriod, w.warrantyPeriodUnit)),
                ('End Date', liveDate(w.warrantyEndDate ?? w.warrantyEndPreview)),
                ('AMC Included', w.amcIncluded ? 'Yes' : 'No'),
                ('Support Coverage', w.supportCoverage),
                ('Service Provider', w.serviceProvider),
                ('Reference', w.warrantyReference),
              ]),
            ],
          ),
        ),
        gap,
        SectionCard(
          title: 'Additional Information',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LiveSubTitle('Specifications'),
              LiveInfoRows([
                for (final s in t.specifications) (s.name, [?s.value, ?s.unit].join(' ')),
                (
                  'Dimensions (L × W × H)',
                  [t.dimensionLength, t.dimensionWidth, t.dimensionHeight].every((v) => v == null)
                      ? null
                      : '${[
                              for (final v in [t.dimensionLength, t.dimensionWidth, t.dimensionHeight]) liveNum(v) ?? '–',
                            ].join(' × ')}'
                            '${t.dimensionUnit == null ? '' : ' ${t.dimensionUnit}'}',
                ),
                ('Weight', liveNum(t.weight, t.weightUnit)),
                ('Expected Lifespan', liveNum(t.expectedLifespan, t.expectedLifespanUnit)),
                ('Technical Remarks', t.technicalRemarks),
              ]),
              const LiveSubTitle('Operational'),
              LiveInfoRows([
                ('Operating Hours / Day', liveNum(o.operatingHoursPerDay, o.operatingHoursUnit)),
                ('Operating Shift', o.operatingShift),
                ('Utilization', o.utilization),
                ('Maintenance Every', liveNum(o.maintenanceFrequency, o.maintenanceFrequencyUnit)),
                ('Last Maintenance', liveDate(o.lastMaintenanceDate)),
                ('Next Maintenance', liveDate(o.nextMaintenanceDate)),
                ('Compliance Standards', o.complianceStandards.join(', ')),
              ]),
              const LiveSubTitle('Custom Fields'),
              LiveInfoRows([
                for (final f in r.additionalInformation.customFields) (f.fieldName, f.value),
              ], empty: 'None'),
              const LiveSubTitle('Attachments'),
              LiveFileList(files: r.additionalInformation.attachments),
            ],
          ),
        ),
        gap,
        LiveComponentsCard(assetId: r.assetRegistrationId),
        gap,
        LiveInfoRows([
          ('Created', [liveDate(r.createdAt), r.createdBy].nonNulls.join(' · ')),
          ('Updated', [liveDate(r.updatedAt), r.updatedBy].nonNulls.join(' · ')),
        ], empty: ''),
      ],
    );
  }
}

/// Registration file references (AssetDocumentDto): invoice documents, attachments.
class LiveFileList extends StatelessWidget {
  const LiveFileList({super.key, required this.files});

  final List<AssetDocument> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return Text('None', style: AppText.secondary);
    return Column(
      children: [
        for (final f in files)
          _FileRow(
            name: f.fileName,
            subtitle: [?liveSize(f.fileSize), ?liveDate(f.uploadedAt)].join(' · '),
            onTap: f.url == null ? null : () => openLiveFile(context, f.url!, fileName: f.fileName),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.name, required this.subtitle, this.onTap, this.trailing});

  final String name;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pdf = AssetFileRules.extensionOf(name) == 'pdf';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              pdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
              color: pdf ? AppColors.red : AppColors.iconBlue,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                  if (subtitle.isNotEmpty) Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            trailing ?? Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Condition & criticality

class LiveConditionCard extends ConsumerWidget {
  const LiveConditionCard({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'Current Condition',
    actionLabel: 'Update',
    actionIcon: Icons.edit_outlined,
    onAction: () => openMoreAction(context, MoreAction.updateCondition, assetId),
    child: LiveAsync<AssetConditionAssessment?>(
      value: ref.watch(liveConditionProvider(assetId)),
      onRetry: () => ref.invalidate(liveConditionProvider(assetId)),
      data: (c) => c == null
          ? Text('No assessment yet', style: AppText.secondary)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProgressRing(
                  value: (c.healthScore / 100).clamp(0, 1),
                  size: 56,
                  strokeWidth: 6,
                  color: healthColor(c.healthScore),
                  center: Text('${liveNum(c.healthScore)}%', style: AppText.chip),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AssetStatusChip(c.overallCondition),
                      const SizedBox(height: 4),
                      LiveInfoRows([
                        ('Health Score', '${liveNum(c.healthScore)} / 100'),
                        ('Assessed On', liveDate(c.assessmentDate)),
                        ('Assessed By', c.assessedBy),
                        ('Physical', c.physicalCondition),
                        ('Performance', c.performance),
                        ('Safety', c.safety),
                        ('Remarks', c.remarks),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}

Color healthColor(num score) => score >= 80
    ? AppColors.green
    : score >= 60
    ? AppColors.amber
    : AppColors.red;

class LiveCriticalityCard extends ConsumerWidget {
  const LiveCriticalityCard({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'Criticality Assessment',
    child: LiveAsync<AssetCriticalityAssessment?>(
      value: ref.watch(liveCriticalityProvider(assetId)),
      onRetry: () => ref.invalidate(liveCriticalityProvider(assetId)),
      data: (c) => c == null
          ? Text('No assessment yet', style: AppText.secondary)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(c.criticalityLevel, tone: ChipTone.forAsset(c.criticalityLevel)),
                const SizedBox(height: 4),
                LiveInfoRows([
                  ('Score', liveNum(c.criticalityScore)),
                  ('Likelihood', c.likelihood),
                  ('Consequence', c.consequence),
                  ('Assessed On', liveDate(c.assessmentDate)),
                  ('Assessed By', c.assessedBy),
                  ('Valid Until', liveDate(c.validUntil)),
                  ('Next Review', liveDate(c.nextReviewDate)),
                  ('Remarks', c.remarks),
                ]),
              ],
            ),
    ),
  );
}

// ---------------------------------------------------------------- Photos

class LivePhotosCard extends ConsumerWidget {
  const LivePhotosCard({super.key, required this.asset});

  final AssetRegistration asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = asset.assetRegistrationId;
    final images = ref.watch(liveAssetImagesProvider(id));
    return SectionCard(
      title: 'Photos',
      actionLabel: 'Add',
      actionIcon: Icons.add_a_photo_outlined,
      onAction: () => addLivePhoto(context, ref, id),
      child: LiveAsync<List<AssetImageRecord>>(
        value: images,
        onRetry: () => ref.invalidate(liveAssetImagesProvider(id)),
        data: (list) {
          final gallery = liveGallery(asset, list);
          if (gallery.isEmpty) return Text('No photos yet', style: AppText.secondary);
          final urls = [for (final (u, _) in gallery) u];
          return SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: gallery.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => openPhotoViewer(context, urls, initialIndex: i),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image(
                        image: photoProvider(urls[i]),
                        errorBuilder: photoError,
                        width: 104,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 104,
                      child: Text(
                        gallery[i].$2 ?? 'Photo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- Components

class LiveComponentsCard extends ConsumerWidget {
  const LiveComponentsCard({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'Components',
    child: LiveAsync<List<AssetComponentNode>>(
      value: ref.watch(liveComponentTreeProvider(assetId)),
      onRetry: () => ref.invalidate(liveComponentTreeProvider(assetId)),
      data: (tree) => tree.isEmpty
          ? Text('No components', style: AppText.secondary)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${tree.fold(0, (n, c) => n + c.count)} components', style: AppText.caption),
                for (final n in tree) _ComponentNode(node: n, depth: 0),
              ],
            ),
    ),
  );
}

class _ComponentNode extends StatefulWidget {
  const _ComponentNode({required this.node, required this.depth});

  final AssetComponentNode node;
  final int depth;

  @override
  State<_ComponentNode> createState() => _ComponentNodeState();
}

class _ComponentNodeState extends State<_ComponentNode> {
  late bool _open = widget.depth == 0;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final hasChildren = n.children.isNotEmpty;
    final pct = n.lifecyclePercent;
    final row = InkWell(
      onTap: hasChildren
          ? () => setState(() => _open = !_open)
          : () => showHelpSheet(
              context,
              title: n.componentName,
              body: [
                'Tag: ${n.componentTag}',
                if (n.status != null) 'Status: ${n.status}',
                if (pct != null) 'Lifecycle used: ${liveNum(pct)} %',
                if (n.expectedReplacementDate != null) 'Expected replacement: ${liveDate(n.expectedReplacementDate)}',
              ].join('\n'),
            ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(widget.depth * 18.0, 8, 0, 8),
        child: Row(
          children: [
            Icon(
              hasChildren ? (_open ? Icons.expand_more_rounded : Icons.chevron_right_rounded) : Icons.settings_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.componentName, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                  Text(
                    [
                      n.componentTag,
                      if (n.expectedReplacementDate != null) 'replace ${liveDate(n.expectedReplacementDate)}',
                    ].join(' · '),
                    style: AppText.caption,
                  ),
                  if (pct != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (pct / 100).clamp(0, 1),
                              minHeight: 5,
                              color: healthColor(100 - pct),
                              backgroundColor: AppColors.divider,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${liveNum(pct)}% life', style: AppText.caption.copyWith(fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (n.status != null) ...[const SizedBox(width: 8), AssetStatusChip(n.status!)],
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (_open)
          for (final c in n.children) _ComponentNode(node: c, depth: widget.depth + 1),
      ],
    );
  }
}

// ---------------------------------------------------------------- Location

class LiveLocationTab extends StatelessWidget {
  const LiveLocationTab({super.key, required this.asset});

  final AssetRegistration asset;

  @override
  Widget build(BuildContext context) {
    final l = asset.locationAssignment.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Current Location',
          child: LiveInfoRows([
            ('Location Path', l.serverLocationPath ?? l.locationPath),
            ('Country', l.countryName),
            ('Site', l.siteName),
            ('Building', l.buildingName),
            ('Floor', l.floorName),
            ('Zone', l.zoneName),
            ('Room', l.roomName),
            ('GPS', l.latitude == null || l.longitude == null ? null : '${l.latitude}, ${l.longitude}'),
          ]),
        ),
        const SizedBox(height: 12),
        const SectionCard(
          title: 'Location History',
          child: NotAvailableYet(feature: 'Location history', icon: Icons.history_rounded),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Documents

class LiveDocumentsTab extends ConsumerWidget {
  const LiveDocumentsTab({super.key, required this.asset});

  final AssetRegistration asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = asset.assetRegistrationId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Asset Documents',
          actionLabel: 'Add',
          actionIcon: Icons.upload_file_outlined,
          onAction: () => openMoreAction(context, MoreAction.addDocument, id),
          child: LiveAsync<List<AssetDocumentRecord>>(
            value: ref.watch(liveAssetDocumentsProvider(id)),
            onRetry: () => ref.invalidate(liveAssetDocumentsProvider(id)),
            data: (docs) => docs.isEmpty
                ? Text('No documents yet', style: AppText.secondary)
                : Column(
                    children: [
                      for (final d in docs)
                        _FileRow(
                          name: d.documentName,
                          subtitle: [
                            d.documentType,
                            'v${d.version}',
                            if (d.expiryDate != null) 'expires ${liveDate(d.expiryDate)}',
                            ?liveSize(d.fileSize),
                          ].join(' · '),
                          onTap: () => openLiveFile(context, d.fileUrl, fileName: d.fileName),
                          trailing: d.status == null ? null : StatusChip(d.status!),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Invoice & Documents',
          child: LiveFileList(files: asset.purchaseWarranty.documents),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Attachments',
          child: LiveFileList(files: asset.additionalInformation.attachments),
        ),
      ],
    );
  }
}
