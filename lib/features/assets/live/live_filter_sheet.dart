import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';

/// Filter sheet of the live Assets list: the values of GET /api/asset-registrations/filters, one
/// value per filter (the server matches one value each). Returns the new query (search and sort
/// kept), or null when dismissed.
Future<AssetListQuery?> showLiveFilterSheet(
  BuildContext context, {
  required AssetListQuery query,
  bool showCustodian = true,
}) => showModalBottomSheet<AssetListQuery>(
  context: context,
  useRootNavigator: false,
  isScrollControlled: true,
  builder: (_) => _LiveFilterSheet(initial: query, showCustodian: showCustodian),
);

/// The query without any filter (search and sort kept).
AssetListQuery withoutFilters(AssetListQuery q) =>
    AssetListQuery(search: q.search, sortBy: q.sortBy, sortDirection: q.sortDirection);

class _LiveFilterSheet extends ConsumerStatefulWidget {
  const _LiveFilterSheet({required this.initial, required this.showCustodian});

  final AssetListQuery initial;
  final bool showCustodian;

  @override
  ConsumerState<_LiveFilterSheet> createState() => _LiveFilterSheetState();
}

typedef _Option = ({String value, String label});

class _LiveFilterSheetState extends ConsumerState<_LiveFilterSheet> {
  late AssetListQuery _q = widget.initial;

  List<_Option> _plain(Iterable<String> values) => [for (final v in values) (value: v, label: v)];

  List<Widget> _groups(AssetListFilters f) {
    final types = <String>{
      for (final t in f.assetTypes)
        if (_q.category == null || t.category == _q.category) t.assetType,
    };
    Widget group(String title, List<_Option> options, String? selected, void Function(String?) set) {
      if (options.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.bodyStrong),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in options)
                  _OptionChip(
                    label: o.label,
                    selected: selected == o.value,
                    onTap: () => setState(() => set(selected == o.value ? null : o.value)),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return [
      group('Category', _plain(f.categories), _q.category, (v) {
        // Keep the asset type only when it belongs to the new category.
        final keep =
            v == null ||
            _q.assetType == null ||
            f.assetTypes.any((t) => t.assetType == _q.assetType && t.category == v);
        _q = _q.copyWith(category: () => v, assetType: keep ? null : () => null);
      }),
      group('Asset Type', _plain(types), _q.assetType, (v) => _q = _q.copyWith(assetType: () => v)),
      group('Status', _plain(f.statuses), _q.status, (v) => _q = _q.copyWith(status: () => v)),
      group(
        'Location',
        [for (final l in f.locations) (value: l.id, label: l.path)],
        _q.locationId,
        (v) => _q = _q.copyWith(locationId: () => v),
      ),
      group('Department', _plain(f.departments), _q.department, (v) => _q = _q.copyWith(department: () => v)),
      if (widget.showCustodian)
        group(
          'Custodian',
          [for (final c in f.custodians) (value: c.userId, label: c.name ?? c.userId)],
          _q.custodianUserId,
          (v) => _q = _q.copyWith(custodianUserId: () => v),
        ),
      group('Criticality', _plain(f.criticalities), _q.criticality, (v) => _q = _q.copyWith(criticality: () => v)),
      group('Manufacturer', _plain(f.manufacturers), _q.manufacturer, (v) => _q = _q.copyWith(manufacturer: () => v)),
      group('Condition', _plain(f.conditions), _q.condition, (v) => _q = _q.copyWith(condition: () => v)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(assetListFiltersProvider);
    final Widget body;
    if (filters.hasValue) {
      body = SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _groups(filters.requireValue)),
      );
    } else if (filters.hasError) {
      body = LoadErrorState(error: filters.error!, onRetry: () => ref.invalidate(assetListFiltersProvider));
    } else {
      body = const ListSkeleton(rows: 3, card: false);
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: AppText.sectionTitle),
              const SizedBox(height: 12),
              Flexible(child: body),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, withoutFilters(_q)),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(onPressed: () => Navigator.pop(context, _q), child: const Text('Apply')),
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

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    selectedColor: AppColors.primarySoft,
    backgroundColor: AppColors.surface,
    labelStyle: TextStyle(
      fontSize: 13,
      color: selected ? AppColors.primary : AppColors.text,
      fontWeight: FontWeight.w500,
    ),
    side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
  );
}

// ---------------------------------------------------------------- sort

/// Sort sheet: one of [AssetSortKeys.all] + ascending / descending. Returns (sortBy, sortDirection),
/// or null when dismissed. Nothing chosen yet = the server default (Date added, newest first).
Future<({String sortBy, String sortDirection})?> showLiveSortSheet(
  BuildContext context, {
  required AssetListQuery query,
}) {
  var key = query.sortBy ?? 'createdAt';
  var dir = query.sortDirection ?? (query.sortBy == null ? 'desc' : 'asc');
  return showModalBottomSheet<({String sortBy, String sortDirection})>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => sheetFrame(context, [
        const SheetTitle('Sort by'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'asc', label: Text('Ascending'), icon: Icon(Icons.arrow_upward_rounded)),
            ButtonSegment(value: 'desc', label: Text('Descending'), icon: Icon(Icons.arrow_downward_rounded)),
          ],
          selected: {dir},
          onSelectionChanged: (s) => setSheet(() => dir = s.first),
        ),
        const SizedBox(height: 8),
        for (final MapEntry(key: k, value: label) in AssetSortKeys.all.entries)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              k == key ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: k == key ? AppColors.primary : AppColors.textMuted,
            ),
            title: Text(label, style: AppText.body),
            onTap: () => setSheet(() => key = k),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.pop(context, (sortBy: key, sortDirection: dir)),
          child: const Text('Apply'),
        ),
      ]),
    ),
  );
}
