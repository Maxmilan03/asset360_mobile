import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Step 1 Basic Information (AssetBasicInformationDto; Category / Sub Category / Asset Type are
/// the classification values, shown here like the web form).
class StepBasic extends ConsumerWidget {
  const StepBasic({
    super.key,
    required this.form,
    required this.edit,
    required this.revision,
    required this.onTypePicked,
    required this.onSuggestId,
    required this.onGenerateQr,
    required this.onPrintLabel,
  });

  final RegistrationForm form;
  final FormEdit edit;
  final int revision;
  final ValueChanged<String> onTypePicked;
  final VoidCallback onSuggestId;
  final VoidCallback onGenerateQr;
  final VoidCallback onPrintLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = form.basicInformation;
    final assets = ref.read(assetsProvider.notifier);
    String? unique(String? v, {String? except}) {
      final s = (v ?? '').trim().toUpperCase();
      if (s.isEmpty || s == except) return null;
      final owner = assets.ownerOf(s);
      return owner == null ? null : 'Already used by ${owner.id}';
    }

    Future<void> scanInto(String title, void Function(String) set) async {
      final code = await showScanCapture(context, title: title, suggestions: const ['MTR-00123', 'QR-A360-000901']);
      if (code != null) edit(() => set(code.toUpperCase()), bump: true);
    }

    Color dot(String o) => ChipTone.forAsset(o).foreground;
    final tag = (b.assetTag ?? '').trim().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegTextField(
          label: 'Asset Name',
          required: true,
          value: b.assetName,
          hint: 'e.g. Diesel Generator 500 kVA',
          onChanged: (v) => edit(() => b.assetName = v),
          validator: (v) => (v ?? '').trim().length < 3 ? 'Enter the asset name' : null,
        ),
        RegTextField(
          label: 'Asset Tag / Asset ID',
          required: true,
          value: b.assetTag,
          revision: revision,
          hint: 'e.g. GEN-00047',
          caps: TextCapitalization.characters,
          suffix: ScanSuffix(onTap: () => scanInto('Scan Asset Tag', (c) => b.assetTag = c)),
          onChanged: (v) => edit(() => b.assetTag = v),
          validator: (v) {
            final s = (v ?? '').trim().toUpperCase();
            if (s.isEmpty) return 'Enter the asset tag';
            if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{2,19}$').hasMatch(s)) return 'Use letters, digits and -';
            return unique(s);
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: onSuggestId,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Suggest next ID', style: AppText.link),
              ),
            ),
          ),
        ),
        RegTextField(
          label: 'Barcode / QR Code',
          value: b.barcode,
          revision: revision,
          hint: 'Defaults to the asset tag',
          caps: TextCapitalization.characters,
          suffix: ScanSuffix(onTap: () => scanInto('Scan Barcode / QR Code', (c) => b.barcode = c)),
          onChanged: (v) => edit(() => b.barcode = v),
          // The new asset may carry its own tag as barcode.
          validator: (v) => unique(v, except: tag),
        ),
        RegTextField(
          label: 'RFID Tag ID',
          value: b.rfidTagId,
          revision: revision,
          hint: 'RFID-A360-…',
          caps: TextCapitalization.characters,
          suffix: ScanSuffix(
            tooltip: 'Read RFID / NFC',
            icon: Icons.contactless_rounded,
            onTap: () async {
              final read = await showRfidReadSheet(context, ref);
              if (read != null) edit(() => b.rfidTagId = read, bump: true);
            },
          ),
          onChanged: (v) => edit(() => b.rfidTagId = v),
          validator: unique,
        ),
        ClassificationFields(form: form, edit: edit, onTypePicked: onTypePicked),
        RegTextField(label: 'Model', value: b.model, hint: 'e.g. C500 D5', onChanged: (v) => b.model = v),
        RegAutocomplete(
          label: 'Manufacturer',
          value: b.manufacturer,
          options: ref.watch(masterDataProvider).manufacturers,
          hint: 'e.g. Cummins',
          onChanged: (v) => b.manufacturer = v,
        ),
        RegTextField(
          label: 'Serial Number',
          value: b.serialNumber,
          hint: 'Manufacturer serial',
          caps: TextCapitalization.characters,
          onChanged: (v) => b.serialNumber = v,
        ),
        RegDropdown(
          label: 'Status',
          required: true,
          value: b.status,
          options: AssetOptions.statuses,
          dotColor: dot,
          onChanged: (v) => edit(() => b.status = v),
        ),
        RegDropdown(
          label: 'Condition',
          value: b.condition,
          options: AssetOptions.conditions,
          dotColor: dot,
          onChanged: (v) => edit(() => b.condition = v),
        ),
        CriticalityField(form: form, edit: edit),
        RegTextField(
          label: 'Description',
          value: b.description,
          maxLines: 3,
          hint: 'What the asset is and does',
          onChanged: (v) => b.description = v,
        ),
        AssetImagesField(images: b.images, onChanged: (v) => edit(() => b.images = v)),
        const RegSection('Identification Preview'),
        _IdentificationPreview(form: form, onGenerateQr: onGenerateQr, onPrintLabel: onPrintLabel),
      ],
    );
  }
}

/// QR code of the asset tag with tag, barcode, RFID and name; Generate QR Code / Print Label.
class _IdentificationPreview extends StatelessWidget {
  const _IdentificationPreview({required this.form, required this.onGenerateQr, required this.onPrintLabel});

  final RegistrationForm form;
  final VoidCallback onGenerateQr;
  final VoidCallback onPrintLabel;

  @override
  Widget build(BuildContext context) {
    final b = form.basicInformation;
    final tag = (b.assetTag ?? '').trim().toUpperCase();
    String or(String? v) => v == null || v.trim().isEmpty ? '—' : v.trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: tag.isEmpty
                    ? SizedBox.square(
                        dimension: 96,
                        child: Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.textMuted),
                      )
                    : QrCode(data: tag, size: 96),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    InfoRow(label: 'Asset Tag', value: or(b.assetTag).toUpperCase(), labelWidth: 78),
                    InfoRow(label: 'Barcode', value: or(b.barcode ?? (tag.isEmpty ? null : tag)), labelWidth: 78),
                    InfoRow(label: 'RFID', value: or(b.rfidTagId), labelWidth: 78),
                    InfoRow(label: 'Name', value: or(b.assetName), labelWidth: 78),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGenerateQr,
                  icon: const Icon(Icons.qr_code_rounded, size: 20),
                  label: const FittedBox(child: Text('Generate QR Code')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrintLabel,
                  icon: const Icon(Icons.print_outlined, size: 20),
                  label: const FittedBox(child: Text('Print Label')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
