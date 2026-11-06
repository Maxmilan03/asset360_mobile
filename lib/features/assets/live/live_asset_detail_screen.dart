import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/asset_actions.dart';
import 'package:asset360_mobile/features/assets/asset_detail_screen.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_common.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_tabs.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_upload.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

enum _Menu {
  edit,
  moreActions,
  addDocument,
  updateCondition,
  print,
  share,
  refresh,
  duplicate,
  linkIot,
  retire,
  delete,
}

/// Asset 360° in API mode: GET /api/asset-registrations/{id} plus its images, documents, component
/// tree, current condition and criticality. Same layout as the mock screen (header, photo + specs,
/// stat cards, action grid, eight tabs); parts without a backend say "Not available yet".
class LiveAssetDetailScreen extends ConsumerStatefulWidget {
  const LiveAssetDetailScreen({super.key, required this.assetId, this.initialTab});

  /// assetRegistrationId ("AR000001").
  final String assetId;
  final String? initialTab;

  @override
  ConsumerState<LiveAssetDetailScreen> createState() => _LiveAssetDetailScreenState();
}

class _LiveAssetDetailScreenState extends ConsumerState<LiveAssetDetailScreen> {
  late AssetTab _tab = AssetTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => AssetTab.overview);

  String get _id => widget.assetId;

  Future<void> _refresh() async {
    invalidateLiveAsset(ref, _id);
    try {
      await ref.read(liveAssetProvider(_id).future);
    } catch (_) {
      // The error is shown by the screen.
    }
  }

  void _toggleFavorite(AssetRegistration r) {
    final fav = ref.read(liveFavoritesProvider).contains(_id);
    ref.read(liveFavoritesProvider.notifier).toggle(_id);
    context.showSnack(fav ? '${r.title} removed from Favorites' : '${r.title} added to Favorites');
  }

  void _onMenu(_Menu m, AssetRegistration r) {
    switch (m) {
      case _Menu.moreActions:
        openMoreActions(context, assetId: _id);
      case _Menu.addDocument:
        openMoreAction(context, MoreAction.addDocument, _id);
      case _Menu.updateCondition:
        openMoreAction(context, MoreAction.updateCondition, _id);
      case _Menu.print:
        openMoreAction(context, MoreAction.printTag, _id);
      case _Menu.share:
        openMoreAction(context, MoreAction.share, _id);
      case _Menu.refresh:
        _refresh();
        context.showSnack('Refreshing ${r.title} …');
      case _Menu.edit:
        context.push(Routes.assetEdit(_id));
      case _Menu.duplicate:
        showNotAvailableYet(context, 'Duplicate');
      case _Menu.linkIot:
        showNotAvailableYet(context, 'Link IoT Device');
      case _Menu.retire:
        showNotAvailableYet(context, 'Retire Asset');
      case _Menu.delete:
        _delete(r);
    }
  }

  /// DELETE /api/asset-registrations/{id} (soft delete) after a confirmation, then back to the
  /// refreshed list. Create Disposal Request stays in More Actions for a formal disposal.
  Future<void> _delete(AssetRegistration r) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${r.title}?',
      message: 'The asset will be removed from lists.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await LiveAssetEditor(ref).delete(_id);
      if (!mounted) return;
      // The SnackBar lives on the shell, so it stays while the list opens.
      context.showSnack('${r.title} deleted');
      context.go(Routes.assets);
    } catch (e) {
      if (mounted) context.showSnack('Could not delete ${r.title}: ${ApiException.from(e).message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(liveAssetProvider(_id))
        .when(
          loading: () => AppScaffold(
            body: ListView(padding: context.pagePadding, children: const [ListSkeleton(rows: 6)]),
          ),
          error: (e, _) => AppScaffold(
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: context.pagePadding,
                children: [
                  if (isNotFound(e))
                    LiveAssetNotFound(
                      message: ApiException.from(e).message,
                      actionLabel: 'Back to Assets',
                      onAction: () => context.go(Routes.assets),
                    )
                  else
                    LoadErrorState(error: e, onRetry: _refresh),
                ],
              ),
            ),
          ),
          data: (r) => AppScaffold(
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const ValueKey('liveAssetDetail'),
                padding: context.pagePadding,
                children: [
                  _Header(asset: r, onFavorite: () => _toggleFavorite(r), onMenu: (m) => _onMenu(m, r)),
                  const SizedBox(height: 14),
                  if (_tab == AssetTab.overview) ...[
                    _PhotoAndSpecs(asset: r),
                    const SizedBox(height: 12),
                    _StatCards(asset: r, onTab: (t) => setState(() => _tab = t)),
                    const SizedBox(height: 12),
                    _ActionGrid(assetId: _id),
                    const SizedBox(height: 6),
                  ],
                  SegmentTabs(
                    tabs: [for (final t in AssetTab.values) SegmentTab(t.label)],
                    selected: _tab.index,
                    onChanged: (i) => setState(() => _tab = AssetTab.values[i]),
                  ),
                  const SizedBox(height: 12),
                  switch (_tab) {
                    AssetTab.overview => LiveOverviewTab(asset: r),
                    AssetTab.location => LiveLocationTab(asset: r),
                    AssetTab.iot => const NotAvailableYet(feature: 'IoT telemetry', icon: Icons.sensors_rounded),
                    AssetTab.maintenance => const NotAvailableYet(
                      feature: 'Maintenance history',
                      icon: Icons.build_outlined,
                    ),
                    AssetTab.inspection => const NotAvailableYet(
                      feature: 'Inspections',
                      icon: Icons.assignment_outlined,
                    ),
                    AssetTab.financial => const NotAvailableYet(
                      feature: 'Depreciation and costs',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    AssetTab.documents => LiveDocumentsTab(asset: r),
                    AssetTab.history => const NotAvailableYet(feature: 'Asset history', icon: Icons.history_rounded),
                  },
                ],
              ),
            ),
          ),
        );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.asset, required this.onFavorite, required this.onMenu});

  final AssetRegistration asset;
  final VoidCallback onFavorite;
  final ValueChanged<_Menu> onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = asset.basicInformation;
    final favorite = ref.watch(liveFavoritesProvider).contains(asset.assetRegistrationId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    blankToNull(b.assetTag) ?? asset.assetRegistrationId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.pageTitle,
                  ),
                  if (blankToNull(b.status) != null) AssetStatusChip(b.status!),
                ],
              ),
              const SizedBox(height: 3),
              Text(asset.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.pageSubtitle),
            ],
          ),
        ),
        AssetSquareIcon(
          tooltip: favorite ? 'Remove from Favorites' : 'Add to Favorites',
          icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
          color: favorite ? AppColors.amber : AppColors.text,
          onTap: onFavorite,
        ),
        const SizedBox(width: 8),
        PopupMenuButton<_Menu>(
          tooltip: 'More',
          onSelected: onMenu,
          itemBuilder: (_) => [
            for (final (m, icon, label) in [
              (_Menu.edit, Icons.edit_outlined, 'Edit Asset'),
              (_Menu.moreActions, Icons.more_horiz_rounded, 'More Actions'),
              (_Menu.addDocument, Icons.upload_file_outlined, 'Add Document'),
              (_Menu.updateCondition, Icons.fact_check_outlined, 'Update Condition'),
              (_Menu.print, Icons.print_outlined, 'Print Tag'),
              (_Menu.share, Icons.share_outlined, 'Share'),
              (_Menu.refresh, Icons.refresh_rounded, 'Refresh'),
              (_Menu.duplicate, Icons.copy_all_rounded, 'Duplicate'),
              (_Menu.linkIot, Icons.sensors_rounded, 'Link IoT Device'),
              (_Menu.retire, Icons.archive_outlined, 'Retire Asset'),
              (_Menu.delete, Icons.delete_outline_rounded, 'Delete'),
            ])
              PopupMenuItem(
                value: m,
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: m == _Menu.delete ? AppColors.red : AppColors.text),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: m == _Menu.delete ? AppColors.red : AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: const AssetSquareIcon(icon: Icons.more_vert_rounded),
        ),
      ],
    );
  }
}

class _PhotoAndSpecs extends ConsumerWidget {
  const _PhotoAndSpecs({required this.asset});

  final AssetRegistration asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = asset.assetRegistrationId;
    final b = asset.basicInformation, c = asset.classification;
    final images = ref.watch(liveAssetImagesProvider(id)).value ?? const [];
    final gallery = [for (final (u, _) in liveGallery(asset, images)) u];
    final specs = [
      ('Asset Type', c.assetType),
      ('Category', c.subCategory ?? c.category),
      ('Model', b.model),
      ('Manufacturer', b.manufacturer),
      ('Serial No.', b.serialNumber),
      ('Tag ID (RFID)', b.rfidTagId),
    ];
    final code = blankToNull(b.barcode) ?? blankToNull(b.assetTag) ?? id;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 8,
            child: GestureDetector(
              onTap: gallery.isEmpty ? () => addLivePhoto(context, ref, id) : () => openPhotoViewer(context, gallery),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  border: Border.all(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (gallery.isEmpty)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 44, color: AppColors.textMuted),
                          const SizedBox(height: 6),
                          Text('Add photo', style: AppText.link),
                        ],
                      )
                    else
                      Image(image: photoProvider(gallery.first), errorBuilder: photoError, fit: BoxFit.cover),
                    if (gallery.length > 1)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Text('${gallery.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, value) in specs) AssetSpecRow(label, blankToNull(value) ?? '—'),
                  const AssetSpecRow('Barcode / QR', ''),
                  Padding(
                    padding: const EdgeInsets.only(left: 78, top: 2),
                    child: Code39Barcode(data: code, height: 26),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCards extends ConsumerWidget {
  const _StatCards({required this.asset, required this.onTab});

  final AssetRegistration asset;
  final ValueChanged<AssetTab> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = asset.assetRegistrationId;
    final condition = ref.watch(liveConditionProvider(id)).value;
    final assessment = ref.watch(liveCriticalityProvider(id)).value;
    final level = assessment?.criticalityLevel ?? asset.criticality;
    final crit = ChipTone.forAsset(level ?? '');
    final critColor = crit.foreground == AppColors.grey ? AppColors.green : crit.foreground;
    final p = asset.purchaseWarranty.purchase, w = asset.purchaseWarranty.warranty;
    final warrantyEnd = w.warrantyEndDate ?? w.warrantyEndPreview;
    final expired = warrantyEnd != null && warrantyEnd.isBefore(liveToday());
    Widget card({
      required Widget top,
      required String value,
      required String label,
      Color? valueColor,
      VoidCallback? onTap,
    }) => Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          children: [
            SizedBox(height: 40, child: Center(child: top)),
            const SizedBox(height: 6),
            if (value.isNotEmpty)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: AppText.bodyStrong.copyWith(fontSize: 13, color: valueColor)),
              ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: AppText.caption.copyWith(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        card(
          top: ProgressRing(
            value: ((condition?.healthScore ?? 0) / 100).clamp(0, 1),
            size: 42,
            strokeWidth: 5,
            color: healthColor(condition?.healthScore ?? 0),
            center: Text(
              condition == null ? '—' : '${liveNum(condition.healthScore)}%',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
          value: '',
          label: 'Health Score',
          onTap: () => condition == null
              ? openMoreAction(context, MoreAction.updateCondition, id)
              : showHelpSheet(
                  context,
                  title: 'Health Score ${liveNum(condition.healthScore)}%',
                  body:
                      '${condition.overallCondition} condition, assessed on ${liveDate(condition.assessmentDate) ?? '—'} '
                      'by ${condition.assessedBy}. 80% and above is Good, 60–79% is Fair and below 60% needs attention. '
                      'Use Update Condition to record a new assessment.',
                ),
        ),
        const SizedBox(width: 8),
        card(
          top: Icon(Icons.speed_rounded, size: 34, color: critColor),
          value: level ?? '—',
          valueColor: critColor,
          label: 'Criticality',
          onTap: () => showHelpSheet(
            context,
            title: 'Criticality',
            body: assessment == null
                ? 'No criticality assessment yet. The registered criticality is ${level ?? 'not set'}.'
                : 'Assessed ${assessment.criticalityLevel} (score ${liveNum(assessment.criticalityScore)}) on '
                      '${liveDate(assessment.assessmentDate) ?? '—'}. Next review: '
                      '${liveDate(assessment.nextReviewDate) ?? 'not set'}.',
          ),
        ),
        const SizedBox(width: 8),
        card(
          top: const Icon(Icons.check_circle_rounded, size: 30, color: AppColors.green),
          value: _age(p.purchaseDate),
          label: 'Age',
          onTap: () => showHelpSheet(
            context,
            title: 'Age',
            body: p.purchaseDate == null
                ? 'The purchase date is not recorded.'
                : 'Purchased on ${liveDate(p.purchaseDate)}. Expected lifespan: '
                      '${liveNum(asset.additionalInformation.technical.expectedLifespan, asset.additionalInformation.technical.expectedLifespanUnit) ?? 'not recorded'}.',
          ),
        ),
        const SizedBox(width: 8),
        card(
          top: Icon(Icons.calendar_month_rounded, size: 30, color: expired ? AppColors.red : AppColors.iconBlue),
          value: liveDate(warrantyEnd) ?? '—',
          valueColor: expired ? AppColors.red : null,
          label: 'Warranty Expiry',
          onTap: () => onTab(AssetTab.documents),
        ),
      ],
    );
  }

  static String _age(DateTime? purchased) {
    if (purchased == null) return '—';
    final months = (liveToday().difference(purchased).inDays / 30.44).floor();
    if (months < 1) return '< 1 Month';
    if (months < 12) return '$months Month${months == 1 ? '' : 's'}';
    return '${(months / 12).toStringAsFixed(1)} Years';
  }
}

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: .98,
    children: [
      for (final (icon, label, tone, onTap) in liveAssetActions(context, ref, assetId))
        ActionTile(icon: icon, label: label, tone: tone, onTap: onTap, labelSize: 11.5),
    ],
  );
}
