import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';

/// Home KPI tile: icon, big number, label and a colored sub-label.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
    this.caption,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? caption;
  final TileTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SoftTile(
      tone: tone,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tone.foreground, size: 26),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppText.kpiNumber),
          ),
          const SizedBox(height: 2),
          // Label and caption keep one line each and shrink to fit narrow tiles / large text.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: AppText.bodyStrong.copyWith(fontSize: 12.5)),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(caption!, maxLines: 1, style: AppText.caption.copyWith(color: tone.foreground, fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon + label in a soft colored tile (Home quick actions, module hubs).
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.subtitle,
    this.height,
    this.labelSize = 12.5,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final TileTone tone;
  final VoidCallback onTap;

  /// Count shown in a small circle at the top-right (hidden when null or 0).
  final int? badge;
  final Color? badgeColor;
  Color get _badgeColor => badgeColor ?? AppColors.primary;
  final double? height;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _SoftTile(
              tone: tone,
              onTap: onTap,
              bordered: true,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: tone.foreground, size: 28),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontSize: labelSize, fontWeight: FontWeight.w500, height: 1.2),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if ((badge ?? 0) > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _badgeColor, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Icon in a soft colored rounded square (list leading icons, menu rows).
class IconSquare extends StatelessWidget {
  const IconSquare({super.key, required this.icon, required this.tone, this.size = 40});

  final IconData icon;
  final TileTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(size * .26)),
      child: Icon(icon, color: tone.foreground, size: size * .52),
    );
  }
}

class _SoftTile extends StatelessWidget {
  const _SoftTile({required this.tone, required this.child, this.onTap, this.padding, this.bordered = false});

  final TileTone tone;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.tile);
    return Material(
      color: tone.background,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: bordered ? BorderSide(color: tone.foreground.withValues(alpha: .14)) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Center(child: child),
        ),
      ),
    );
  }
}
