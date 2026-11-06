import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_common.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart' show formField;
import 'package:asset360_mobile/features/more/registration/live_options.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Overview → Key Information in API mode. "Edit" turns Status, Condition, Criticality and Purchase
/// Date into fields; Save sends PUT /api/asset-registrations/{id} with the COMPLETE sections they
/// live in (Status / Condition → basicInformation, Criticality → basicInformation + classification,
/// Purchase Date → purchaseWarranty), built from the asset as loaded plus the change
/// ([LiveAssetEditor.save]). Location and Assigned To change through Move Asset and Assign Custodian.
class LiveKeyInformationCard extends ConsumerStatefulWidget {
  const LiveKeyInformationCard({super.key, required this.asset});

  final AssetRegistration asset;

  @override
  ConsumerState<LiveKeyInformationCard> createState() => _LiveKeyInformationCardState();
}

class _LiveKeyInformationCardState extends ConsumerState<LiveKeyInformationCard> {
  bool _editing = false, _busy = false;

  /// The asset being edited (a copy of [LiveKeyInformationCard.asset]).
  late AssetRegistration _draft;

  /// Server field errors ("BasicInformation.Status" …) shown under the fields.
  Map<String, String> _errors = const {};

  void _start() => setState(() {
    _draft = widget.asset.copy();
    _errors = const {};
    _editing = true;
  });

  void _cancel() => setState(() {
    _editing = false;
    _errors = const {};
  });

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final saved = await LiveAssetEditor(ref).save(widget.asset, _draft);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _editing = false;
      });
      context.showSnack(saved == null ? 'No changes to save' : 'Key information saved');
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.from(e);
      setState(() {
        _busy = false;
        _errors = err.fieldErrors;
      });
      // The whole asset is re-checked: a problem in another field is fixed with Edit Asset.
      final other = err.fieldErrors.entries.where((f) => !_shownKeys.contains(f.key)).firstOrNull;
      context.showSnack(other == null ? err.message : '${other.value} · fix it with Edit Asset');
    }
  }

  static const _shownKeys = {
    'BasicInformation.Status',
    'BasicInformation.Condition',
    'BasicInformation.Criticality',
    'Classification.Criticality',
    'PurchaseWarranty.Purchase.PurchaseDate',
  };

  @override
  Widget build(BuildContext context) {
    final r = _editing ? _draft : widget.asset;
    final b = r.basicInformation;
    final l = r.locationAssignment.location, a = r.locationAssignment.assignment;
    final p = r.purchaseWarranty.purchase, w = r.purchaseWarranty.warranty;
    return SectionCard(
      title: 'Key Information',
      actionLabel: _editing ? null : 'Edit',
      actionIcon: Icons.edit_outlined,
      onAction: _start,
      child: _editing ? _form(r) : _view(r, b, l, a, p, w),
    );
  }

  Widget _view(
    AssetRegistration r,
    AssetBasicInformation b,
    AssetLocation l,
    AssetAssignment a,
    AssetPurchase p,
    AssetWarranty w,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (blankToNull(b.status) != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(width: 132, child: Text('Status', style: AppText.secondary)),
              AssetStatusChip(b.status!),
            ],
          ),
        ),
      LiveInfoRows([
        ('Condition', b.condition),
        ('Criticality', r.criticality),
        ('Location', l.serverLocationPath ?? l.locationPath),
        ('Assigned To', a.assignedToName),
        ('Purchase Date', liveDate(p.purchaseDate)),
        ('Warranty Expiry', liveDate(w.warrantyEndDate ?? w.warrantyEndPreview)),
      ]),
    ],
  );

  Widget _form(AssetRegistration r) {
    final lists = RegLists(ref);
    final b = r.basicInformation, p = r.purchaseWarranty.purchase;
    Color dot(String o) => ChipTone.forAsset(o).foreground;
    void edit(VoidCallback change) => setState(change);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegDropdown.source(
          lists.statuses,
          label: 'Status',
          required: true,
          value: b.status,
          dotColor: dot,
          error: _errors['BasicInformation.Status'],
          onChanged: (v) => edit(() => b.status = v),
        ),
        RegDropdown.source(
          lists.conditions,
          label: 'Condition',
          value: b.condition,
          dotColor: dot,
          error: _errors['BasicInformation.Condition'],
          onChanged: (v) => edit(() => b.condition = v),
        ),
        RegDropdown.source(
          lists.criticalities,
          label: 'Criticality',
          required: true,
          value: r.criticality,
          dotColor: dot,
          error: _errors['Classification.Criticality'] ?? _errors['BasicInformation.Criticality'],
          onChanged: (v) => edit(() => r.criticality = v),
        ),
        formField(
          'Purchase Date',
          required: true,
          DateBox(
            value: p.purchaseDate,
            error: _errors['PurchaseWarranty.Purchase.PurchaseDate'],
            onPicked: (d) => edit(() => p.purchaseDate = d),
          ),
        ),
        Text('Location and Assigned To change with Move Asset and Assign Custodian.', style: AppText.caption),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: busyButton(busy: _busy, onPressed: _save, label: 'Save'),
            ),
          ],
        ),
      ],
    );
  }
}
