import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_list_logic.dart';

/// One server asset in the live list: photo, tag, name, location, category / type, criticality,
/// status and a favorite star (device only).
class LiveAssetRow extends ConsumerWidget {
  const LiveAssetRow({super.key, required this.item});

  final AssetListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = item.assetRegistrationId;
    final favorite = ref.watch(liveFavoritesProvider.select((s) => s.contains(id)));
    final kind = [item.category, item.assetType].nonNulls.where((s) => s.isNotEmpty).join(' / ');
    final criticality = item.criticality;
    return AssetListTile(
      title: item.assetTag ?? id,
      subtitle: item.assetName ?? (item.assetTag == null ? null : id),
      location: locationLine(item),
      imagePath: item.imageUrl,
      details: [
        if (kind.isNotEmpty || criticality != null)
          Row(
            children: [
              if (kind.isNotEmpty) Flexible(flex: 3, child: TagLabel(kind, icon: Icons.category_outlined)),
              if (criticality != null) ...[
                const SizedBox(width: 6),
                Flexible(flex: 2, child: _CriticalityLabel(criticality)),
              ],
            ],
          ),
      ],
      trailingTop: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (item.status != null) AssetStatusChip(item.status!),
          const SizedBox(height: 6),
          Tooltip(
            message: favorite ? 'Remove from favorites' : 'Add to favorites',
            child: InkResponse(
              radius: 20,
              onTap: () {
                ref.read(liveFavoritesProvider.notifier).toggle(id);
                context.showSnack(favorite ? 'Removed from Favorites' : 'Added to Favorites');
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 24,
                  color: favorite ? AppColors.amber : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
      onTap: () => context.push(Routes.assetDetail(id)),
    );
  }
}

/// Small coloured "⚠ High" label (criticality colours of asset_options).
class _CriticalityLabel extends StatelessWidget {
  const _CriticalityLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    final t = ChipTone.forAsset(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 11, color: t.foreground),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 10.5, color: t.foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
