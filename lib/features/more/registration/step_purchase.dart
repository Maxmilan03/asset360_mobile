import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/validation/asset_registration_validator.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/more/registration/live_options.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

final _money = NumberFormat('#,##0.00');

/// "AED 525,000.00" (also for the server's currency labels: "AED - UAE Dirham" → "AED").
String formatMoney(double v, String? currency) => '${currencyCode(currency)} ${_money.format(v)}';

/// ISO code of a stored currency: "AED" (mock mode) or "AED - UAE Dirham" (the server's list).
String currencyCode(String? currency) {
  final c = (currency ?? '').split(' - ').first.trim();
  return c.isEmpty ? 'AED' : c;
}

/// Step 4 Purchase & Warranty (AssetPurchaseWarrantyDto). Total Cost and Warranty End Date are
/// "calculated" previews ([AssetPurchase.totalCostPreview] / [AssetWarranty.warrantyEndPreview]);
/// the server recalculates them. [errors] by backend field path ("Purchase.PurchaseCost" …).
class StepPurchase extends ConsumerWidget {
  const StepPurchase({super.key, required this.form, required this.edit, required this.errors});

  final AssetRegistration form;
  final FormEdit edit;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pw = form.purchaseWarranty, p = pw.purchase, w = pw.warranty;
    final total = p.totalCostPreview;
    final end = w.warrantyEndPreview;
    final currency = currencyCode(p.currency);
    final lists = RegLists(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegTextField(
          label: 'Purchase Order Number',
          required: true,
          value: p.purchaseOrderNumber,
          hint: 'PO-2026-…',
          caps: TextCapitalization.characters,
          error: errors['Purchase.PurchaseOrderNumber'],
          onChanged: (v) => p.purchaseOrderNumber = v,
        ),
        RegTextField(
          label: 'Invoice Number',
          value: p.invoiceNumber,
          hint: 'INV-…',
          caps: TextCapitalization.characters,
          onChanged: (v) => p.invoiceNumber = v,
        ),
        RegAutocomplete(
          label: 'Supplier / Vendor',
          required: true,
          value: p.supplierVendor,
          options: suppliers, // Master Management, still local
          hint: 'Supplier',
          error: errors['Purchase.SupplierVendor'],
          onChanged: (v) => p.supplierVendor = v,
        ),
        RegAutocomplete(
          label: 'Manufacturer',
          required: true,
          value: p.manufacturer,
          options: lists.manufacturers(() => ref.watch(masterDataProvider).manufacturers),
          hint: 'e.g. Cummins',
          error: errors['Purchase.Manufacturer'],
          onChanged: (v) => p.manufacturer = v,
        ),
        RegDateField(
          label: 'Purchase Date',
          required: true,
          value: p.purchaseDate,
          error: errors['Purchase.PurchaseDate'],
          onPicked: (d) => edit(() => p.purchaseDate = d),
        ),
        RegDateField(
          label: 'Delivery Date',
          value: p.deliveryDate,
          error: errors['Purchase.DeliveryDate'],
          // The web starts the warranty on delivery.
          onPicked: (d) => edit(() {
            p.deliveryDate = d;
            w.warrantyStartDate ??= d;
          }),
        ),
        RegNumberField(
          label: 'Purchase Cost ($currency)',
          required: true,
          value: p.purchaseCost,
          hint: '0.00',
          suffixText: currency,
          error: errors['Purchase.PurchaseCost'],
          onChanged: (v) => edit(() => p.purchaseCost = v),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: RegNumberField(
                label: 'Quantity',
                required: true,
                value: p.quantity,
                error: errors['Purchase.Quantity'],
                onChanged: (v) => edit(() => p.quantity = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: RegDropdown.source(
                lists.quantityUnits,
                label: 'Unit',
                value: p.quantityUnit,
                onChanged: (v) => edit(() => p.quantityUnit = v),
              ),
            ),
          ],
        ),
        RegDropdown.source(
          lists.currencies,
          label: 'Currency',
          value: p.currency,
          labelOf: (c) => AssetOptions.currencies[c] ?? c,
          onChanged: (v) => edit(() => p.currency = v),
        ),
        RegNumberField(
          label: 'Tax (VAT %)',
          value: p.taxPercent,
          suffixText: '%',
          error: errors['Purchase.TaxPercent'],
          onChanged: (v) => edit(() => p.taxPercent = v),
        ),
        RegReadOnly(
          label: 'Total Cost ($currency) · calculated',
          value: total == null ? '—' : formatMoney(total, currency),
          note: 'Purchase cost × (1 + tax %). The server recalculates it on save.',
        ),
        RegDropdown.source(
          lists.paymentTerms,
          label: 'Payment Terms',
          value: p.paymentTerms,
          onChanged: (v) => edit(() => p.paymentTerms = v),
        ),
        RegDropdown.source(
          lists.procurementMethods,
          label: 'Procurement Method',
          value: p.procurementMethod,
          onChanged: (v) => edit(() => p.procurementMethod = v),
        ),
        RegTextField(
          label: 'Project / Reference',
          value: p.projectReference,
          hint: 'e.g. PRJ-Expansion-2026',
          onChanged: (v) => p.projectReference = v,
        ),
        RegTextField(
          label: 'Remarks',
          value: p.remarks,
          maxLines: 3,
          maxLength: RegistrationValidator.remarksMax,
          error: errors['Purchase.Remarks'],
          onChanged: (v) => edit(() => p.remarks = v),
        ),
        DocumentUploadField(
          label: 'Invoice & Documents',
          documents: pw.documents,
          error: errors['Documents'],
          onChanged: (v) => edit(() => pw.documents = v),
          onAdded: (d) => edit(() => pw.documents = [...pw.documents, d]),
        ),
        const RegSection('Warranty & Support Information'),
        RegDropdown.source(
          lists.warrantyTypes,
          label: 'Warranty Type',
          value: w.warrantyType,
          onChanged: (v) => edit(() => w.warrantyType = v),
        ),
        RegDateField(
          label: 'Warranty Start Date',
          value: w.warrantyStartDate,
          onPicked: (d) => edit(() => w.warrantyStartDate = d),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: RegNumberField(
                label: 'Warranty Period',
                value: w.warrantyPeriod,
                decimals: false,
                error: errors['Warranty.WarrantyPeriod'],
                onChanged: (v) => edit(() => w.warrantyPeriod = v?.toInt()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: RegDropdown.source(
                lists.warrantyPeriodUnits,
                label: 'Period Unit',
                value: w.warrantyPeriodUnit,
                error: errors['Warranty.WarrantyPeriodUnit'],
                onChanged: (v) => edit(() => w.warrantyPeriodUnit = v),
              ),
            ),
          ],
        ),
        RegReadOnly(
          label: 'Warranty End Date · calculated',
          value: end == null ? '—' : DemoClock.formatDate(end),
          note: 'Start date + warranty period. The server recalculates it on save.',
          error: errors['Warranty.WarrantyEndDate'],
        ),
        SwitchListTile(
          value: w.amcIncluded,
          contentPadding: EdgeInsets.zero,
          title: Text('AMC Included', style: AppText.body),
          onChanged: (v) => edit(() => w.amcIncluded = v),
        ),
        RegDropdown.source(
          lists.supportCoverages,
          label: 'Support Coverage',
          value: w.supportCoverage,
          onChanged: (v) => edit(() => w.supportCoverage = v),
        ),
        RegDropdown(
          // Master Management, still local.
          label: 'Service Provider',
          value: w.serviceProvider,
          options: AssetOptions.serviceProviders,
          onChanged: (v) => edit(() => w.serviceProvider = v),
        ),
        RegTextField(
          label: 'Warranty Reference',
          value: w.warrantyReference,
          hint: 'Certificate / contract no.',
          onChanged: (v) => w.warrantyReference = v,
        ),
      ],
    );
  }
}
