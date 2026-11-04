import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/registration_form.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

final _money = NumberFormat('#,##0.00');

/// "AED 525,000.00".
String formatMoney(double v, String? currency) => '${currency ?? 'AED'} ${_money.format(v)}';

/// Step 4 Purchase & Warranty (AssetPurchaseWarrantyDto). Total Cost and Warranty End Date are
/// calculated by [AssetPurchase.totalCost] / [AssetWarranty.warrantyEndDate].
class StepPurchase extends ConsumerWidget {
  const StepPurchase({super.key, required this.form, required this.edit, this.dateError});

  final RegistrationForm form;
  final FormEdit edit;
  final String? dateError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pw = form.purchaseWarranty, p = pw.purchase, w = pw.warranty;
    final total = p.totalCost;
    final end = w.warrantyEndDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegTextField(
          label: 'Purchase Order Number',
          required: true,
          value: p.purchaseOrderNumber,
          hint: 'PO-2026-…',
          caps: TextCapitalization.characters,
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
          options: suppliers,
          hint: 'Supplier',
          onChanged: (v) => p.supplierVendor = v,
        ),
        RegAutocomplete(
          label: 'Manufacturer',
          required: true,
          value: p.manufacturer,
          options: ref.watch(masterDataProvider).manufacturers,
          hint: 'e.g. Cummins',
          onChanged: (v) => p.manufacturer = v,
        ),
        RegDateField(
          label: 'Purchase Date',
          required: true,
          value: p.purchaseDate,
          error: dateError,
          onPicked: (d) => edit(() {
            p.purchaseDate = d;
            w.warrantyStartDate ??= d;
          }),
        ),
        RegDateField(label: 'Delivery Date', value: p.deliveryDate, onPicked: (d) => edit(() => p.deliveryDate = d)),
        RegNumberField(
          label: 'Purchase Cost (${p.currency ?? 'AED'})',
          required: true,
          value: p.purchaseCost,
          min: 0,
          hint: '0.00',
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
                min: 1,
                decimals: false,
                onChanged: (v) => edit(() => p.quantity = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: RegDropdown(
                label: 'Unit',
                value: p.quantityUnit,
                options: quantityUnits,
                onChanged: (v) => edit(() => p.quantityUnit = v),
              ),
            ),
          ],
        ),
        RegDropdown(
          label: 'Currency',
          value: p.currency,
          options: currencies,
          onChanged: (v) => edit(() => p.currency = v),
        ),
        RegNumberField(
          label: 'Tax (VAT %)',
          value: p.taxPercent,
          min: 0,
          suffixText: '%',
          onChanged: (v) => edit(() => p.taxPercent = v),
        ),
        RegReadOnly(
          label: 'Total Cost',
          value: total == null ? '—' : formatMoney(total, p.currency),
          note: 'Purchase cost × quantity × (1 + VAT %)',
        ),
        RegDropdown(
          label: 'Payment Terms',
          value: p.paymentTerms,
          options: paymentTerms,
          onChanged: (v) => edit(() => p.paymentTerms = v),
        ),
        RegDropdown(
          label: 'Procurement Method',
          value: p.procurementMethod,
          options: procurementMethods,
          onChanged: (v) => edit(() => p.procurementMethod = v),
        ),
        RegTextField(
          label: 'Project / Reference',
          value: p.projectReference,
          hint: 'e.g. PRJ-Expansion-2026',
          onChanged: (v) => p.projectReference = v,
        ),
        RegTextField(label: 'Remarks', value: p.remarks, maxLines: 3, onChanged: (v) => p.remarks = v),
        DocumentUploadField(
          label: 'Invoice & Documents',
          documents: pw.documents,
          onChanged: (v) => edit(() => pw.documents = v),
        ),
        const RegSection('Warranty'),
        RegDropdown(
          label: 'Warranty Type',
          value: w.warrantyType,
          options: warrantyTypes,
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
                min: 1,
                decimals: false,
                onChanged: (v) => edit(() => w.warrantyPeriod = v?.toInt()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: RegDropdown(
                label: 'Period Unit',
                value: w.warrantyPeriodUnit,
                options: periodUnits,
                onChanged: (v) => edit(() => w.warrantyPeriodUnit = v),
              ),
            ),
          ],
        ),
        RegReadOnly(
          label: 'Warranty End Date',
          value: end == null ? '—' : DemoClock.formatDate(end),
          note: 'Start date + warranty period',
        ),
        SwitchListTile(
          value: w.amcIncluded,
          contentPadding: EdgeInsets.zero,
          title: Text('AMC Included', style: AppText.body),
          onChanged: (v) => edit(() => w.amcIncluded = v),
        ),
        RegDropdown(
          label: 'Support Coverage',
          value: w.supportCoverage,
          options: supportCoverages,
          onChanged: (v) => edit(() => w.supportCoverage = v),
        ),
        RegDropdown(
          label: 'Service Provider',
          value: w.serviceProvider,
          options: serviceProviders,
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
