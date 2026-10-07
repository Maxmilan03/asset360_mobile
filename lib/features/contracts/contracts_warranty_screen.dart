import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/asset.dart';
import '../../data/repositories/assets_repository.dart';
import '../assets/asset_ui.dart';

/// Contracts expiring within this many days are highlighted amber.
const _soonDays = 90;

enum _Kind { warranty, amc }

/// Contracts & Warranty: warranties and AMC contracts from the asset register, with Renew.
class ContractsWarrantyScreen extends ConsumerStatefulWidget {
  const ContractsWarrantyScreen({super.key});

  @override
  ConsumerState<ContractsWarrantyScreen> createState() => _ContractsWarrantyScreenState();
}

class _ContractsWarrantyScreenState extends ConsumerState<ContractsWarrantyScreen> {
  _Kind _kind = _Kind.warranty;
  _Filter _filter = _Filter.all;

  /// Shimmer rows until [LoadingGate.delay] has passed (the list itself is lazy, so it cannot sit
  /// inside a [LoadingGate]).
  late bool _loading = LoadingGate.delay > Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_loading) _timer = Timer(LoadingGate.delay, () => setState(() => _loading = false));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final assets = ref.watch(assetsProvider);
    final warranties = [...assets]..sort((a, b) => a.warrantyExpiry.compareTo(b.warrantyExpiry));
    final amcs = assets.where((a) => a.amc != null && a.amcExpiry != null).toList()
      ..sort((a, b) => a.amcExpiry!.compareTo(b.amcExpiry!));
    final all = _kind == _Kind.warranty ? warranties : amcs;
    DateTime end(Asset a) => _kind == _Kind.warranty ? a.warrantyExpiry : a.amcExpiry!;
    _Filter state(Asset a) {
      final d = DemoClock.daysUntil(end(a));
      return d < 0 ? _Filter.expired : (d <= _soonDays ? _Filter.soon : _Filter.active);
    }

    int count(_Filter f) => f == _Filter.all ? all.length : all.where((a) => state(a) == f).length;
    final rows = _filter == _Filter.all ? all : all.where((a) => state(a) == _filter).toList();

    final header = <Widget>[
      const PageTitle(
        title: 'Contracts & Warranty',
        subtitle: 'Warranties and maintenance contracts',
        help:
            'Warranty and AMC end dates come from each asset. Amber = ends within 90 days, red = expired. '
            'Renew records the new end date, cost and vendor on the asset. Tap a chip to filter the list.',
      ),
      const SizedBox(height: 12),
      SegmentTabs(
        tabs: [
          SegmentTab('Warranties', count: warranties.length),
          SegmentTab('AMC Contracts', count: amcs.length),
        ],
        selected: _kind.index,
        onChanged: (i) => setState(() => _kind = _Kind.values[i]),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _Filter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconFilterChip(
                  icon: f.icon,
                  label: f == _Filter.soon ? 'Ending in $_soonDays days (${count(f)})' : '${f.label} (${count(f)})',
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = f),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];

    final Widget? single = _loading
        ? const ListSkeleton(rows: 5)
        : rows.isEmpty
        ? EmptyState(
            icon: Icons.handshake_outlined,
            title: 'No ${_kind == _Kind.warranty ? 'warranties' : 'AMC contracts'} here',
            message: _filter == _Filter.all ? null : 'Nothing is ${_filter.label.toLowerCase()} right now.',
            actionLabel: _filter == _Filter.all ? null : 'Show all',
            onAction: _filter == _Filter.all ? null : () => setState(() => _filter = _Filter.all),
          )
        : null;

    return AppScaffold(
      body: ListView.builder(
        padding: context.pagePadding,
        itemCount: header.length + (single != null ? 1 : rows.length),
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          if (single != null) return single;
          final a = rows[i - header.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: _ContractRow(asset: a, kind: _kind, end: end(a)),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _Filter {
  all('All', Icons.list_rounded),
  expired('Expired', Icons.error_outline_rounded),
  soon('Ending soon', Icons.schedule_rounded),
  active('Active', Icons.verified_outlined);

  const _Filter(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ContractRow extends ConsumerWidget {
  const _ContractRow({required this.asset, required this.kind, required this.end});

  final Asset asset;
  final _Kind kind;
  final DateTime end;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = DemoClock.daysUntil(end);
    final (chip, tint) = days < 0
        ? (const StatusChip('Expired', tone: ChipTone.red), AppColors.redBg.withValues(alpha: .45))
        : days <= _soonDays
        ? (StatusChip('$days days', tone: ChipTone.amber), AppColors.amberBg.withValues(alpha: .55))
        : (const StatusChip('Active', tone: ChipTone.green), null);
    final what = kind == _Kind.warranty
        ? 'Ends ${DemoClock.formatDate(end)}'
        : '${asset.amc} · ends ${DemoClock.formatDate(end)}';
    return AssetListTile(
      title: asset.id,
      subtitle: asset.name,
      imagePath: asset.imagePath,
      fallbackIcon: assetIcon(asset),
      background: tint,
      details: [
        IconLine(
          icon: kind == _Kind.warranty ? Icons.verified_user_outlined : Icons.handshake_outlined,
          text: what,
          color: days < 0 ? AppColors.red : AppColors.textSecondary,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _renew(context, ref),
            icon: const Icon(Icons.autorenew_rounded, size: 16),
            label: const Text('Renew'),
          ),
        ),
      ],
      trailingTop: chip,
      onTap: () => context.push(Routes.assetDetail(asset.id)),
    );
  }

  Future<void> _renew(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<(DateTime, double, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RenewSheet(asset: asset, kind: kind, current: end),
    );
    if (result == null || !context.mounted) return;
    final (until, cost, vendor) = result;
    final assets = ref.read(assetsProvider.notifier);
    if (kind == _Kind.warranty) {
      assets.renewWarranty(asset.id, until: until, cost: cost, vendor: vendor);
    } else {
      assets.renewAmc(asset.id, until: until, cost: cost, vendor: vendor);
    }
    context.showSnack(
      '${kind == _Kind.warranty ? 'Warranty' : 'AMC'} for ${asset.id} renewed until ${DemoClock.formatDate(until)}',
    );
  }
}

class _RenewSheet extends StatefulWidget {
  const _RenewSheet({required this.asset, required this.kind, required this.current});

  final Asset asset;
  final _Kind kind;
  final DateTime current;

  @override
  State<_RenewSheet> createState() => _RenewSheetState();
}

class _RenewSheetState extends State<_RenewSheet> {
  final _form = GlobalKey<FormState>();
  late DateTime _until = () {
    final from = widget.current.isAfter(DemoClock.today) ? widget.current : DemoClock.today;
    return DateTime(from.year + 1, from.month, from.day);
  }();
  late final _cost = TextEditingController(
    text: widget.kind == _Kind.amc ? (widget.asset.amcCost ?? 0).toStringAsFixed(0) : '',
  );
  late final _vendor = TextEditingController(
    text: widget.kind == _Kind.amc ? widget.asset.amc : widget.asset.manufacturer.replaceAll('—', ''),
  );
  String? _dateError;

  @override
  void dispose() {
    _cost.dispose();
    _vendor.dispose();
    super.dispose();
  }

  void _save() {
    final ok = _form.currentState!.validate();
    setState(
      () => _dateError = _until.isAfter(widget.current) && _until.isAfter(DemoClock.today)
          ? null
          : 'Choose a date after ${DemoClock.formatDate(widget.current.isAfter(DemoClock.today) ? widget.current : DemoClock.today)}',
    );
    if (!ok || _dateError != null) return;
    Navigator.pop(context, (_until, double.parse(_cost.text.replaceAll(',', '').trim()), _vendor.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.kind == _Kind.warranty ? 'Warranty' : 'AMC';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Renew $label – ${widget.asset.id}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.sectionTitle,
              ),
              const SizedBox(height: 4),
              Text('Current end date: ${DemoClock.formatDate(widget.current)}', style: AppText.secondary),
              const SizedBox(height: 14),
              LabeledField(
                label: 'New end date',
                required: true,
                child: DateBox(value: _until, error: _dateError, onPicked: (d) => setState(() => _until = d)),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: widget.kind == _Kind.warranty ? 'Cost (AED)' : 'Yearly cost (AED)',
                required: true,
                child: TextFormField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '').trim());
                    return n == null || n < 0 ? 'Enter the cost' : null;
                  },
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Vendor',
                required: true,
                child: TextFormField(
                  controller: _vendor,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the vendor' : null,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(onPressed: _save, child: const Text('Renew')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
