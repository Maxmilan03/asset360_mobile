import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';

enum ChipTone {
  green(AppColors.green, AppColors.greenBg),
  amber(AppColors.amber, AppColors.amberBg),
  orange(AppColors.orange, AppColors.orangeBg),
  red(AppColors.red, AppColors.redBg),
  blue(AppColors.blue, AppColors.blueBg),
  purple(AppColors.purple, AppColors.purpleBg),
  grey(AppColors.grey, AppColors.greyBg);

  const ChipTone(this.foreground, this.background);
  final Color foreground;
  final Color background;

  /// Tone for a status label, so every screen colors the same word the same way.
  static ChipTone forStatus(String status) {
    return switch (status.toLowerCase()) {
      'active' ||
      'completed' ||
      'verified' ||
      'open' ||
      'scheduled' ||
      'approved' ||
      'received' ||
      'resolved' ||
      'passed' ||
      'pass' ||
      'online' ||
      'synced' ||
      'good' ||
      'in stock' ||
      'found' ||
      'available' ||
      'running' ||
      'excellent' ||
      'closed' => green,
      'pending' ||
      'pending approval' ||
      'medium' ||
      'low stock' ||
      'due today' ||
      'under maintenance' ||
      'draft' ||
      'on hold' ||
      'warning' ||
      'queued' ||
      'fair' ||
      'idle' ||
      'under repair' ||
      'partial' => amber,
      'high' || 'major' => orange,
      'critical' ||
      'overdue' ||
      'out of stock' ||
      'failed' ||
      'fail' ||
      'rejected' ||
      'disposed' ||
      'missing' ||
      'breakdown' ||
      'poor' ||
      'stopped' ||
      'not starting' ||
      'error' => red,
      'in progress' || 'in transit' || 'moving' || 'syncing' || 'info' || 'new' => blue,
      'assigned' || 'checked out' || 'reserved' => purple,
      _ => grey,
    };
  }

  static ChipTone forPriority(String priority) {
    return switch (priority.toLowerCase()) {
      'critical' => red,
      'high' => orange,
      'medium' => amber,
      _ => grey, // Low: design shows a pale grey-lavender chip
    };
  }
}

/// Small rounded label with colored text on a pale background.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone, this.icon, this.onTap, this.trailingIcon});

  final String label;

  /// Defaults to [ChipTone.forStatus] of [label].
  final ChipTone? tone;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ChipTone.forStatus(label);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: t.foreground), const SizedBox(width: 4)],
          Text(label, style: AppText.chip.copyWith(color: t.foreground)),
          if (trailingIcon != null) ...[const SizedBox(width: 2), Icon(trailingIcon, size: 16, color: t.foreground)],
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.chip), child: chip);
  }
}

/// Critical / High / Medium / Low chip, a little wider than a status chip.
class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key, this.onTap});

  final String priority;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = ChipTone.forPriority(priority);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(AppRadius.chip)),
        child: Text(priority, style: AppText.chip.copyWith(color: t.foreground)),
      ),
    );
  }
}

/// Pill used for filter rows such as "All (12)  Work Orders (5)".
class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.greyBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined filter chip with a leading icon ("All", "My Assets", "Nearby" …);
/// filled violet when selected.
class IconFilterChip extends StatelessWidget {
  const IconFilterChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small grey tag with a leading icon, e.g. "⚙ Machine" in asset rows.
class TagLabel extends StatelessWidget {
  const TagLabel(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(color: AppColors.greyBg, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: AppColors.textSecondary), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 10.5, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
