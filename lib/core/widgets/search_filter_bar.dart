import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';

/// One group of options in the filter sheet (e.g. "Priority": Critical, High …).
class FilterGroup {
  const FilterGroup({required this.title, required this.options, this.multiSelect = true});

  final String title;
  final List<String> options;
  final bool multiSelect;
}

/// Selected options per group title.
typedef FilterSelection = Map<String, Set<String>>;

/// Search field + violet filter button. The button opens a filter bottom sheet
/// built from [filterGroups]; the result is reported through [onFiltersChanged].
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.filterGroups = const [],
    this.selection = const {},
    this.onFiltersChanged,
    this.onScan,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final List<FilterGroup> filterGroups;
  final FilterSelection selection;
  final ValueChanged<FilterSelection>? onFiltersChanged;

  /// Shows a square scan button next to the field when set (design 03).
  final VoidCallback? onScan;

  int get _activeCount => selection.values.fold(0, (sum, s) => sum + s.length);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: AppText.body.copyWith(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.text, size: 22),
            ),
          ),
        ),
        if (onScan != null) ...[
          const SizedBox(width: 10),
          _SquareButton(tooltip: 'Scan', icon: Icons.qr_code_scanner_rounded, onPressed: onScan!),
        ],
        if (onFiltersChanged != null) ...[
          const SizedBox(width: 10),
          Badge(
            isLabelVisible: _activeCount > 0,
            backgroundColor: AppColors.primary,
            label: Text('$_activeCount'),
            child: _SquareButton(
              tooltip: 'Filters',
              icon: Icons.filter_alt_outlined,
              onPressed: () async {
                final result = await showFilterSheet(context, groups: filterGroups, selection: selection);
                if (result != null) onFiltersChanged!(result);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 46,
        height: 46,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(46, 46),
            side: const BorderSide(color: AppColors.border),
            backgroundColor: Colors.white,
          ),
          onPressed: onPressed,
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

/// Returns the new selection, or null when the sheet is dismissed.
Future<FilterSelection?> showFilterSheet(
  BuildContext context, {
  required List<FilterGroup> groups,
  required FilterSelection selection,
}) {
  return showModalBottomSheet<FilterSelection>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(groups: groups, initial: selection),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.groups, required this.initial});

  final List<FilterGroup> groups;
  final FilterSelection initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final FilterSelection _sel = {
    for (final g in widget.groups) g.title: {...?widget.initial[g.title]},
  };

  void _toggle(FilterGroup g, String option) {
    setState(() {
      final set = _sel[g.title]!;
      if (set.contains(option)) {
        set.remove(option);
      } else {
        if (!g.multiSelect) set.clear();
        set.add(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filters', style: AppText.sectionTitle),
              const SizedBox(height: 12),
              if (widget.groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No filters are available on this screen yet.', style: AppText.secondary),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in widget.groups) ...[
                      Text(g.title, style: AppText.bodyStrong),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in g.options)
                            FilterChip(
                              label: Text(o),
                              selected: _sel[g.title]!.contains(o),
                              onSelected: (_) => _toggle(g, o),
                              showCheckmark: false,
                              selectedColor: AppColors.primarySoft,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                fontSize: 13,
                                color: _sel[g.title]!.contains(o) ? AppColors.primary : AppColors.text,
                                fontWeight: FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: _sel[g.title]!.contains(o) ? AppColors.primary : AppColors.border,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, <String, Set<String>>{}),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, {
                        for (final e in _sel.entries)
                          if (e.value.isNotEmpty) e.key: e.value,
                      }),
                      child: const Text('Apply'),
                    ),
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
