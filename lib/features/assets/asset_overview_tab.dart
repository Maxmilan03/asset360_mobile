import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/asset.dart';
import '../../data/repositories/assets_repository.dart';
import 'asset_ui.dart';

/// Overview → Key Information. "Edit" turns the values into dropdowns and date
/// pickers; Save writes them through [AssetsNotifier.editKeyInfo].
class KeyInformationCard extends ConsumerStatefulWidget {
  const KeyInformationCard({super.key, required this.asset, required this.editing, required this.onEditingChanged});

  final Asset asset;
  final bool editing;
  final ValueChanged<bool> onEditingChanged;

  @override
  ConsumerState<KeyInformationCard> createState() => _KeyInformationCardState();
}

class _KeyInformationCardState extends ConsumerState<KeyInformationCard> {
  late String _status, _condition, _opStatus, _location, _custodian;
  late DateTime _purchase, _warranty;
  DateTime? _commissioned;
  late bool _hasAmc;
  late final _amcVendor = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(KeyInformationCard old) {
    super.didUpdateWidget(old);
    if (widget.editing && !old.editing) _reset();
  }

  @override
  void dispose() {
    _amcVendor.dispose();
    super.dispose();
  }

  void _reset() {
    final a = widget.asset;
    _status = a.status;
    _condition = a.condition;
    _opStatus = a.operationalStatus;
    _location = a.location;
    _custodian = a.custodian;
    _purchase = a.purchaseDate;
    _commissioned = a.commissionedDate;
    _warranty = a.warrantyExpiry;
    _hasAmc = a.amc != null;
    _amcVendor.text = a.amc ?? '';
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    useRootNavigator: false,
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2045),
  );

  void _save() {
    if (_commissioned != null && _commissioned!.isBefore(_purchase)) {
      context.showSnack('Commissioned date cannot be before the purchase date');
      return;
    }
    if (_warranty.isBefore(_purchase)) {
      context.showSnack('Warranty expiry cannot be before the purchase date');
      return;
    }
    if (_hasAmc && _amcVendor.text.trim().isEmpty) {
      context.showSnack('Enter the AMC provider');
      return;
    }
    ref
        .read(assetsProvider.notifier)
        .editKeyInfo(
          widget.asset.id,
          status: _status,
          condition: _condition,
          operationalStatus: _opStatus,
          location: _location,
          custodian: _custodian,
          purchaseDate: _purchase,
          commissionedDate: _commissioned,
          warrantyExpiry: _warranty,
          amc: _hasAmc ? _amcVendor.text.trim() : null,
        );
    widget.onEditingChanged(false);
    context.showSnack('Key information saved');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final a = widget.asset;
    final e = widget.editing;

    Widget dropdown(String value, List<String> options, ValueChanged<String> onChanged) => DropdownButton<String>(
      value: value,
      isExpanded: true,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: [
        for (final o in {...options, value})
          DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis, style: _valueStyle),
          ),
      ],
      onChanged: (v) => setState(() => onChanged(v!)),
    );

    Widget dateField(DateTime? value, ValueChanged<DateTime> onPicked) => InkWell(
      onTap: () async {
        final d = await _pickDate(value ?? DemoClock.today);
        if (d != null) setState(() => onPicked(d));
      },
      child: Row(
        children: [
          Expanded(child: Text(value == null ? 'Select date' : DemoClock.formatDate(value), style: _valueStyle)),
          Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.primary),
        ],
      ),
    );

    final warrantyDays = a.warrantyDaysLeft;
    final warrantyText = a.warrantyExpired
        ? '${DemoClock.formatDate(a.warrantyExpiry)} (Expired)'
        : '${DemoClock.formatDate(a.warrantyExpiry)} ($warrantyDays ${warrantyDays == 1 ? 'day' : 'days'})';

    final rows = <(IconData, String, Widget)>[
      (
        Icons.person_outline_rounded,
        'Asset Status',
        e ? dropdown(_status, [...AssetStatus.summary, AssetStatus.inTransit], (v) => _status = v) : _chip(a.status),
      ),
      (
        Icons.settings_outlined,
        'Condition',
        e ? dropdown(_condition, assetConditions, (v) => _condition = v) : _chip(a.condition),
      ),
      (
        Icons.speed_rounded,
        'Operational Status',
        e ? dropdown(_opStatus, operationalStatuses, (v) => _opStatus = v) : _chip(a.operationalStatus),
      ),
      (
        Icons.location_on_outlined,
        'Location',
        e
            ? dropdown(_location, locationOptions(ref), (v) => _location = v)
            : _iconValue(Icons.location_on_outlined, a.location),
      ),
      (
        Icons.badge_outlined,
        'Custodian',
        e
            ? dropdown(_custodian, custodianOptions(ref), (v) => _custodian = v)
            : _iconValue(Icons.person_outline_rounded, a.custodian),
      ),
      (
        Icons.event_outlined,
        'Purchase Date',
        e
            ? dateField(_purchase, (d) => _purchase = d)
            : _iconValue(Icons.calendar_today_outlined, DemoClock.formatDate(a.purchaseDate)),
      ),
      (
        Icons.event_available_outlined,
        'Commissioned Date',
        e
            ? dateField(_commissioned, (d) => _commissioned = d)
            : _iconValue(
                Icons.calendar_today_outlined,
                a.commissionedDate == null ? '—' : DemoClock.formatDate(a.commissionedDate!),
              ),
      ),
      (
        Icons.verified_user_outlined,
        'Warranty Expiry',
        e
            ? dateField(_warranty, (d) => _warranty = d)
            : _iconValue(
                Icons.calendar_today_outlined,
                warrantyText,
                color: a.warrantyWarning ? AppColors.red : AppColors.text,
              ),
      ),
      (
        Icons.handshake_outlined,
        'AMC',
        e
            ? Row(
                children: [
                  SizedBox(
                    height: 24,
                    child: Switch(value: _hasAmc, onChanged: (v) => setState(() => _hasAmc = v)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _amcVendor,
                      enabled: _hasAmc,
                      style: _valueStyle,
                      decoration: const InputDecoration(
                        hintText: 'Provider',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                ],
              )
            : Text(a.amc == null ? 'No' : 'Yes (${a.amc})', style: _valueStyle),
      ),
    ];

    return SectionCard(
      title: 'Key Information',
      actionLabel: e ? null : 'Edit',
      actionIcon: Icons.keyboard_arrow_down_rounded,
      onAction: () => widget.onEditingChanged(true),
      child: Column(
        children: [
          for (final (icon, label, value) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: e ? 5 : 4),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  SizedBox(width: 128, child: Text(label, style: AppText.secondary)),
                  Expanded(child: value),
                ],
              ),
            ),
          if (e) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _reset();
                      widget.onEditingChanged(false);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: _save, child: const Text('Save')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle get _valueStyle => TextStyle(fontSize: 12.5, color: AppColors.text);

Widget _chip(String label) => Align(alignment: Alignment.centerLeft, child: StatusChip(label));

Widget _iconValue(IconData icon, String text, {Color? color}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Icon(icon, size: 14, color: color == null || color == AppColors.text ? AppColors.textSecondary : color),
    ),
    const SizedBox(width: 5),
    Expanded(
      child: Text(text, style: _valueStyle.copyWith(color: color)),
    ),
  ],
);
