import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';

class SegmentTab {
  const SegmentTab(this.label, {this.count, this.enabled = true});

  final String label;
  final int? count;

  /// False shows the tab but it can't be selected (client demo).
  final bool enabled;

  String get text => count == null ? label : '$label ($count)';
}

/// Underlined text tabs with optional counts: "My Work Orders (8)  PM Due (12) …".
/// Tabs spread across the width when they fit and scroll horizontally when not.
class SegmentTabs extends StatelessWidget {
  const SegmentTabs({super.key, required this.tabs, required this.selected, required this.onChanged});

  final List<SegmentTab> tabs;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _Tab(tab: tabs[i], active: i == selected, onTap: tabs[i].enabled ? () => onChanged(i) : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.active, required this.onTap});

  final SegmentTab tab;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2.5)),
        ),
        child: Text(
          tab.text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
