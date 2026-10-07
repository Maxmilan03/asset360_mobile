import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import 'info_row.dart';
import 'photo_strip.dart';
import 'tiles.dart';

/// Product photo (bundled or picked file) in a white rounded box, or an icon in a soft square when
/// there is no photo.
class AssetThumb extends StatelessWidget {
  const AssetThumb({super.key, this.imagePath, this.fallbackIcon = Icons.inventory_2_outlined, this.size = 64});

  final String? imagePath;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imagePath == null) return IconSquare(icon: fallbackIcon, tone: TileTone.lavender, size: size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image(
        image: photoProvider(imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(fallbackIcon, color: AppColors.textMuted),
      ),
    );
  }
}

/// List row: photo, ID (optionally after a priority chip), name, detail lines,
/// a status chip and date on the right, and a chevron.
class AssetListTile extends StatelessWidget {
  const AssetListTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.location,
    this.details = const [],
    this.imagePath,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.titleLeading,
    this.titleTrailing,
    this.trailingTop,
    this.trailingBottom,
    this.showChevron = true,
    this.selected = false,
    this.background,
  });

  final String title;
  final String? subtitle;

  /// Shown with a pin icon.
  final String? location;

  /// Extra lines under the location (e.g. "From: IT Store").
  final List<Widget> details;
  final String? imagePath;
  final IconData fallbackIcon;
  final Widget? titleLeading;

  /// Small widget right after the title (e.g. the priority chip on issue rows).
  final Widget? titleTrailing;
  final Widget? trailingTop;
  final String? trailingBottom;
  final bool showChevron;
  final bool selected;

  /// Row tint (e.g. amber for "expiring"); [selected] wins.
  final Color? background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : background ?? AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              AssetThumb(imagePath: imagePath, fallbackIcon: fallbackIcon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (titleLeading != null) ...[
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: titleLeading,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitle.copyWith(fontSize: 14.5),
                          ),
                        ),
                        if (titleTrailing != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: titleTrailing,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(fontSize: 12.5, color: AppColors.text),
                      ),
                    ],
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      IconLine(icon: Icons.location_on_outlined, text: location!),
                    ],
                    for (final d in details) Padding(padding: const EdgeInsets.only(top: 3), child: d),
                  ],
                ),
              ),
              if (trailingTop != null || trailingBottom != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (trailingTop != null) FittedBox(fit: BoxFit.scaleDown, child: trailingTop),
                      if (trailingBottom != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          trailingBottom!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(color: AppColors.text),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
