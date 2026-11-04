import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';
import 'package:asset360_mobile/features/more/registration/registration_logic.dart';
import 'package:asset360_mobile/features/more/registration/step_purchase.dart';

/// Step 6 Review: ready banner, asset card, then one card per step with Edit.
class RegistrationReview extends StatelessWidget {
  const RegistrationReview({super.key, required this.form, required this.onEdit});

  final RegistrationForm form;

  /// Jumps to a form step (0 = Basic Information … 4 = Additional Information).
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final f = form;
    final b = f.basicInformation, c = f.classification;
    final l = f.locationAssignment.location, a = f.locationAssignment.assignment;
    final p = f.purchaseWarranty.purchase, w = f.purchaseWarranty.warranty;
    final t = f.additionalInformation.technical, o = f.additionalInformation.operational;
    String or(Object? v) => switch (v) {
      null => '—',
      final String s when s.trim().isEmpty => '—',
      final DateTime d => DemoClock.formatDate(d),
      final List<String> list => list.isEmpty ? '—' : list.join(', '),
      final double n => n == n.roundToDouble() ? n.toInt().toString() : n.toString(),
      _ => '$v',
    };
    String unit(Object? v, String? u) => v == null ? '—' : '${or(v)} ${u ?? ''}'.trim();
    final dims = [t.dimensionLength, t.dimensionWidth, t.dimensionHeight];
    final assessed = f.criticalityAssessment?.result;
    final tag = (b.assetTag ?? '').trim().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.greenBg,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: AppColors.green.withValues(alpha: .25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asset details are ready to be submitted',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.green),
                    ),
                    const SizedBox(height: 2),
                    Text('Please review the information below and tap Submit.', style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap: () => onEdit(0),
          child: Row(
            children: [
              AssetThumb(imagePath: b.images.firstOrNull, size: 76, fallbackIcon: Icons.add_photo_alternate_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitle.copyWith(fontSize: 16),
                          ),
                        ),
                        if (b.status != null) StatusChip(b.status!, tone: ChipTone.forAsset(b.status!)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(or(b.assetName), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
                    const SizedBox(height: 3),
                    Text(c.path.join(' › '), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                    const SizedBox(height: 4),
                    IconLine(icon: Icons.location_on_outlined, text: or(l.assetLocation)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          title: registrationStepTitles[0],
          onEdit: () => onEdit(0),
          rows: [
            ('Asset Name', or(b.assetName)),
            ('Asset Tag / ID', tag),
            ('Barcode / QR', or(b.barcode ?? tag)),
            ('RFID Tag ID', or(b.rfidTagId)),
            ('Model', or(b.model)),
            ('Manufacturer', or(b.manufacturer)),
            ('Serial Number', or(b.serialNumber)),
            ('Status', or(b.status)),
            ('Condition', or(b.condition)),
            ('Criticality', assessed == null ? or(f.criticality) : '${f.criticality} (assessed ${assessed.score.toStringAsFixed(1)} / 5)'),
            ('Description', or(b.description)),
            ('Images', '${b.images.length}'),
          ],
        ),
        _ReviewSection(
          title: registrationStepTitles[1],
          onEdit: () => onEdit(1),
          rows: [
            ('Category', or(c.category)),
            ('Sub Category', or(c.subCategory)),
            ('Asset Type', or(c.assetType)),
            ('Asset Sub Type', or(c.assetSubType)),
            ('Function / Purpose', or(c.functionPurpose)),
            ('Department', or(c.department)),
            ('Cost Center', or(c.costCenter)),
            ('Business Unit', or(c.businessUnit)),
            ('Tagging Method', or(c.taggingMethod)),
            ('Compliance', or(c.complianceCategory)),
            ('Lifecycle Stage', or(c.lifecycleStage)),
            ('Keywords', or(c.keywords)),
          ],
        ),
        _ReviewSection(
          title: registrationStepTitles[2],
          onEdit: () => onEdit(2),
          rows: [
            ('Location Path', l.parts.isEmpty ? '—' : l.parts.join(' › ')),
            ('Custodian', registrationCustodian(a)),
            ('Ownership', or(a.ownershipType)),
            ('Cost Center', or(a.costCenter)),
            ('Responsible Team', or(a.responsibleTeam)),
            ('Assignment', '${or(a.assignmentStartDate)} – ${a.assignmentEndDate == null ? 'Open' : or(a.assignmentEndDate)}'),
            ('Current', a.isCurrent ? 'Yes' : 'No'),
          ],
        ),
        _ReviewSection(
          title: registrationStepTitles[3],
          onEdit: () => onEdit(3),
          rows: [
            ('PO Number', or(p.purchaseOrderNumber)),
            ('Invoice Number', or(p.invoiceNumber)),
            ('Supplier / Vendor', or(p.supplierVendor)),
            ('Manufacturer', or(p.manufacturer)),
            ('Purchase Date', or(p.purchaseDate)),
            ('Delivery Date', or(p.deliveryDate)),
            ('Purchase Cost', p.purchaseCost == null ? '—' : formatMoney(p.purchaseCost!, p.currency)),
            ('Quantity', unit(p.quantity, p.quantityUnit)),
            ('VAT', unit(p.taxPercent, '%')),
            ('Total Cost', p.totalCost == null ? '—' : formatMoney(p.totalCost!, p.currency)),
            ('Payment Terms', or(p.paymentTerms)),
            ('Procurement', or(p.procurementMethod)),
            ('Project / Ref.', or(p.projectReference)),
            ('Documents', '${f.purchaseWarranty.documents.length}'),
            ('Warranty Type', or(w.warrantyType)),
            ('Warranty', '${or(w.warrantyStartDate)} – ${or(w.warrantyEndDate)}'),
            ('AMC Included', w.amcIncluded ? 'Yes' : 'No'),
            ('Support Coverage', or(w.supportCoverage)),
            ('Service Provider', or(w.serviceProvider)),
            ('Warranty Ref.', or(w.warrantyReference)),
          ],
        ),
        _ReviewSection(
          title: registrationStepTitles[4],
          onEdit: () => onEdit(4),
          rows: [
            for (final s in t.specifications.values)
              if (s.value != null && s.value!.trim().isNotEmpty) (s.name, unit(s.value, s.unit)),
            if (dims.any((d) => d != null))
              ('Dimensions', '${dims.map(or).join(' × ')} ${t.dimensionUnit ?? ''}'.trim()),
            if (t.weight != null) ('Weight', unit(t.weight, t.weightUnit)),
            if (t.expectedLifespan != null) ('Expected Lifespan', unit(t.expectedLifespan, t.expectedLifespanUnit)),
            ('Technical Remarks', or(t.technicalRemarks)),
            ('Operating Hours', o.operatingHoursPerDay == null ? '—' : '${or(o.operatingHoursPerDay)} hrs/day'),
            ('Operating Shift', or(o.operatingShift)),
            ('Utilization', or(o.utilization)),
            ('Maintenance', o.maintenanceFrequency == null ? '—' : 'Every ${unit(o.maintenanceFrequency, o.maintenanceFrequencyUnit)}'),
            ('Last / Next', '${or(o.lastMaintenanceDate)} / ${or(o.nextMaintenanceDate)}'),
            ('Compliance', or(o.complianceStandards)),
            for (final cf in f.additionalInformation.customFields) (cf.fieldName, or(cf.value)),
            ('Attachments', '${f.additionalInformation.attachments.length}'),
          ],
        ),
      ],
    );
  }
}

/// Section card with an Edit link and label / value rows.
class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.onEdit, required this.rows});

  final String title;
  final VoidCallback onEdit;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SectionCard(
      title: title,
      actionLabel: 'Edit',
      actionIcon: Icons.edit_outlined,
      onAction: onEdit,
      child: Column(children: [for (final (l, v) in rows) InfoRow(label: l, value: v, labelWidth: 118)]),
    ),
  );
}

// ---------------------------------------------------------------- success

enum RegisteredAction { view, another, done }

/// "Asset registered" sheet with the new ID and its QR code.
Future<RegisteredAction?> showRegisteredSheet(BuildContext context, Asset asset) {
  return showModalBottomSheet<RegisteredAction>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 52),
            const SizedBox(height: 8),
            Text('Asset registered', style: AppText.pageTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              '${asset.id} – ${asset.name} has been added to the register.',
              textAlign: TextAlign.center,
              style: AppText.pageSubtitle,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  QrCode(data: asset.id, size: 150),
                  const SizedBox(height: 4),
                  Text(asset.id, style: AppText.bodyStrong.copyWith(letterSpacing: .8)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, RegisteredAction.view),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View Asset'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          margin: context.snackMargin,
                          content: Text('QR tag for ${asset.id} sent to Zebra ZD421 – Store (demo)'),
                        ),
                      ),
                    icon: const Icon(Icons.print_outlined, size: 20),
                    label: const Text('Print Tag'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, RegisteredAction.another),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Register Another'),
                  ),
                ),
              ],
            ),
            TextButton(onPressed: () => Navigator.pop(context, RegisteredAction.done), child: const Text('Done')),
          ],
        ),
      ),
    ),
  );
}
