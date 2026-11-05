import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/home/sections/live_home.dart';

class RecentAssetsCard extends ConsumerWidget {
  const RecentAssetsCard({super.key});

  /// Rows on Home (API mode: the newest of [recentLiveAssetsProvider]).
  static const liveRows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apiMode) {
      return SectionCard(
        title: 'Recent Assets',
        actionLabel: 'View All',
        onAction: DemoGuard.push(context, Routes.recentAssets),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: LiveCardBody(
          provider: recentLiveAssetsProvider,
          builder: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No assets yet',
                  message: 'Registered assets appear here.',
                )
              : Column(
                  children: [
                    for (final (i, a) in items.take(liveRows).indexed) ...[
                      if (i > 0) const Divider(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LiveAssetTile(
                          item: a,
                          onTap: DemoGuard.open(
                            Routes.assetDetail(a.assetRegistrationId),
                            () => context.go(Routes.assetDetail(a.assetRegistrationId)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      );
    }
    final assets = ref.watch(homeDataProvider).recentAssets;
    return SectionCard(
      title: 'Recent Assets',
      actionLabel: 'View All',
      onAction: DemoGuard.push(context, Routes.recentAssets),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          if (assets.isEmpty)
            const EmptyState(icon: Icons.inventory_2_outlined, title: 'No recent assets')
          else
            for (var i = 0; i < assets.length; i++) ...[
              if (i > 0) const Divider(),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AssetListTile(
                  title: assets[i].id,
                  subtitle: assets[i].name,
                  location: assets[i].location,
                  imagePath: assets[i].imagePath,
                  trailingTop: StatusChip(assets[i].status),
                  onTap: DemoGuard.open(Routes.assetDetail(assets[i].id), () {
                    ref.read(recentAssetsProvider.notifier).viewed(assets[i].id);
                    context.go(Routes.assetDetail(assets[i].id));
                  }),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
