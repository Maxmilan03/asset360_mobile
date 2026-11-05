import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/assets/asset_actions.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';

/// Asset Identified (middle screen of design/05_scan_identify.jpg): success banner, the asset
/// card and a 3×3 grid of actions, each opened for this asset.
class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key, required this.assetId});

  final String assetId;

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (apiMode) return _LiveScanResult(assetId: widget.assetId);
    final asset = ref.watch(assetsProvider.select((list) => list.byCode(widget.assetId)));
    if (asset == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Asset not found',
          message: '${widget.assetId} is no longer in the asset register.',
          actionLabel: 'Back to Scan',
          onAction: () => context.pop(),
        ),
      );
    }
    final actions = [
      (
        Icons.view_list_rounded,
        'View Details',
        TileTone.lavender,
        DemoGuard.push(context, Routes.assetDetail(asset.id)),
      ),
      ...assetActions(context, ref, asset),
    ];
    return AppScaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        padding: context.pagePadding,
        children: [
          const _SuccessBanner(),
          const SizedBox(height: 18),
          _AssetCard(asset: asset),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              for (final (icon, label, tone, onTap) in actions)
                ActionTile(icon: icon, label: label, tone: tone, onTap: onTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: PageTitle(title: 'Asset Identified', subtitle: 'Asset details loaded successfully'),
        ),
      ],
    );
  }
}

/// Photo, ID, name, type, location and status; taps through to Asset 360°.
class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: DemoGuard.push(context, Routes.assetDetail(asset.id)),
      child: Row(
        children: [
          AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 112),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.centerRight, child: AssetStatusChip(asset.status)),
                const SizedBox(height: 2),
                Text(
                  asset.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.pageTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  asset.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  asset.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.secondary.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                IconLine(icon: Icons.location_on_rounded, text: asset.location),
                Padding(
                  padding: const EdgeInsets.only(left: 17, top: 2),
                  child: Text(asset.site, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// API mode: the live record (GET /api/asset-registrations/{assetRegistrationId}) with View Details.
class _LiveScanResult extends ConsumerWidget {
  const _LiveScanResult({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveAssetProvider(assetId));
    void open() => context.push(Routes.assetDetail(assetId));
    return AppScaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        padding: context.pagePadding,
        children: [
          const _SuccessBanner(),
          const SizedBox(height: 18),
          switch (live) {
            AsyncData(:final value) => LiveAssetTile(item: AssetListItem.fromRegistration(value), onTap: open),
            AsyncError(:final error) => LoadErrorState(
              error: error,
              onRetry: () => ref.invalidate(liveAssetProvider(assetId)),
            ),
            _ => const ListSkeleton(rows: 1),
          },
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: open,
            icon: const Icon(Icons.view_list_rounded),
            label: const Text('View Details'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan another'),
          ),
        ],
      ),
    );
  }
}
