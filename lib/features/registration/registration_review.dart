import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/asset.dart';
import '../../data/repositories/assets_repository.dart';
import '../assets/asset_ui.dart';
import 'register_asset_screen.dart';

/// Step 5: ready banner, summary card, details grid and collapsible sections.
class RegistrationReview extends ConsumerWidget {
  const RegistrationReview({super.key, required this.draft, required this.onEdit});

  final RegistrationDraft draft;

  /// Jumps to a form step (0 = Basic … 3 = Additional).
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = draft;
    String date(DateTime? v) => v == null ? '—' : DemoClock.formatDate(v);
    String or(String v) => v.isEmpty ? '—' : v;
    final parent = d.parentId == null ? null : ref.watch(assetByIdProvider(d.parentId!));
    final left = [
      ('Asset ID', d.id),
      ('Serial Number', or(d.serial)),
      ('Tag ID (RFID)', or(d.tagId)),
      ('Barcode / QR', d.barcode.isEmpty ? d.id : d.barcode),
      ('Status', d.status),
      ('Condition', d.condition),
      ('Operational Status', d.operationalStatus),
      ('Criticality', d.criticality),
    ];
    final right = [
      ('Category', d.category ?? '—'),
      ('Asset Type', d.type ?? '—'),
      ('Model', or(d.model)),
      ('Manufacturer', or(d.manufacturer)),
      ('Purchase Date', date(d.purchase)),
      ('Commissioned', date(d.commissioned)),
      ('Warranty Expiry', date(d.warranty)),
      ('AMC', d.amc ? 'Yes (${d.amcVendor})' : 'No'),
    ];

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
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.green, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asset details are ready to be registered',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.green),
                    ),
                    SizedBox(height: 2),
                    Text('Please review the information below and click Register.', style: AppText.caption),
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
              AssetThumb(imagePath: d.photo, size: 76, fallbackIcon: Icons.add_photo_alternate_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(d.id, style: AppText.cardTitle.copyWith(fontSize: 16))),
                        StatusChip(d.status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(d.name, style: AppText.body.copyWith(fontSize: 13)),
                    const SizedBox(height: 3),
                    Text('${d.type} | ${d.category}', style: AppText.caption),
                    const SizedBox(height: 4),
                    IconLine(icon: Icons.location_on_outlined, text: '${d.location}, ${d.site}'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Asset Details',
          actionLabel: 'Edit',
          actionIcon: Icons.edit_outlined,
          onAction: () => onEdit(0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Grid(rows: left)),
              const SizedBox(width: 10),
              Expanded(child: _Grid(rows: right)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Collapsible(
          icon: Icons.location_on_outlined,
          title: 'Location & Custody',
          onEdit: () => onEdit(2),
          rows: [
            ('Site', d.site ?? '—'),
            ('Location', d.location),
            ('Custodian', d.custodian),
            ('Department', d.department ?? '—'),
            ('Parent Asset', parent == null ? 'None' : '${parent.id} – ${parent.name}'),
            ('Tags', d.tags.isEmpty ? '—' : d.tags.join(', ')),
          ],
        ),
        _Collapsible(
          icon: Icons.account_balance_outlined,
          title: 'Financial Information',
          onEdit: () => onEdit(3),
          rows: [
            ('Purchase Cost', d.cost == null ? '—' : formatAed(d.cost!)),
            ('Supplier', or(d.supplier)),
            ('PO Number', or(d.po)),
            ('Expected Life', '${d.life} years'),
            ('AMC', d.amc ? 'Yes (${d.amcVendor})' : 'No'),
            ('IoT Device', d.iot == null ? 'None' : '${d.iot!.model} · ${d.iot!.imei}'),
          ],
        ),
        _Collapsible(
          icon: Icons.description_outlined,
          title: 'Documents (${d.docs.length})',
          onEdit: () => onEdit(3),
          rows: [
            if (d.docs.isEmpty) ('Files', 'No documents attached'),
            for (final f in d.docs) (f.name, '${f.sizeMb.toStringAsFixed(1)} MB'),
          ],
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 10.5, color: AppColors.text, height: 1.3);
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 82,
                  child: Text(label, style: style.copyWith(color: AppColors.textSecondary)),
                ),
                const Text(': ', style: style),
                Expanded(child: Text(value, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Row with icon, title and "Edit"; tapping the row expands the details.
class _Collapsible extends StatefulWidget {
  const _Collapsible({required this.icon, required this.title, required this.onEdit, required this.rows});

  final IconData icon;
  final String title;
  final VoidCallback onEdit;
  final List<(String, String)> rows;

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: AppColors.text),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.title, style: AppText.bodyStrong)),
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  Icon(
                    _open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [for (final (l, v) in widget.rows) InfoRow(label: l, value: v, labelWidth: 110)],
              ),
            ),
        ],
      ),
    );
  }
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
      child: Padding(
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
                        SnackBar(content: Text('QR tag for ${asset.id} sent to Zebra ZD421 – Store (demo)')),
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
