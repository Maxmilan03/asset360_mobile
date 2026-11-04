import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/disposals_repository.dart';
import 'package:asset360_mobile/features/assets/asset_actions.dart';
import 'package:asset360_mobile/features/assets/asset_iot_tab.dart';
import 'package:asset360_mobile/features/assets/asset_overview_tab.dart';
import 'package:asset360_mobile/features/assets/asset_tabs.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

enum AssetTab { overview, location, iot, maintenance, inspection, financial, documents, history }

extension on AssetTab {
  String get label => switch (this) {
    AssetTab.iot => 'IoT',
    _ => name[0].toUpperCase() + name.substring(1),
  };
}

enum _Menu { edit, moreActions, print, share, duplicate, linkIot, retire, delete }

/// Asset 360° view: header, photo + specs, stats, actions and eight tabs.
class AssetDetailScreen extends ConsumerStatefulWidget {
  const AssetDetailScreen({super.key, required this.assetId, this.initialTab});

  final String assetId;

  /// Tab name from `?tab=` (e.g. "financial").
  final String? initialTab;

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> {
  late AssetTab _tab = AssetTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => AssetTab.overview);
  bool _editing = false;

  void _go(AssetTab t) => setState(() {
    _tab = t;
    if (t != AssetTab.overview) _editing = false;
  });

  void _toggleFavorite(Asset a) {
    ref.read(assetsProvider.notifier).toggleFavorite(a.id);
    context.showSnack(a.favorite ? '${a.id} removed from Favorites' : '${a.id} added to Favorites');
  }

  void _onMenu(_Menu m, Asset a) {
    switch (m) {
      case _Menu.edit:
        setState(() {
          _tab = AssetTab.overview;
          _editing = true;
        });
        context.showSnack('Edit the key information below, then tap Save');
      case _Menu.moreActions:
        openMoreActions(context, assetId: a.id);
      case _Menu.print:
        openMoreAction(context, MoreAction.printTag, a.id);
      case _Menu.share:
        openMoreAction(context, MoreAction.share, a.id);
      case _Menu.duplicate:
        duplicateAsset(context, ref, a);
      case _Menu.linkIot:
        showLinkIotSheet(context, ref, a);
      case _Menu.retire:
        retireAsset(context, ref, a);
      case _Menu.delete:
        deleteAsset(context, ref, a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(assetByIdProvider(widget.assetId));
    if (a == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Asset not found',
          message: '${widget.assetId} is not in the register.',
          actionLabel: 'Back to Assets',
          onAction: () => context.go(Routes.assets),
        ),
      );
    }
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          _Header(asset: a, onFavorite: () => _toggleFavorite(a), onMenu: (m) => _onMenu(m, a)),
          const SizedBox(height: 14),
          if (_tab == AssetTab.overview) ...[
            _PhotoAndSpecs(asset: a),
            const SizedBox(height: 12),
            _StatCards(asset: a, onTab: _go),
            const SizedBox(height: 12),
            _ActionGrid(asset: a, onTab: _go),
            const SizedBox(height: 6),
          ],
          SegmentTabs(
            tabs: [for (final t in AssetTab.values) SegmentTab(t.label)],
            selected: _tab.index,
            onChanged: (i) => _go(AssetTab.values[i]),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            AssetTab.overview => KeyInformationCard(
              asset: a,
              editing: _editing,
              onEditingChanged: (v) => setState(() => _editing = v),
            ),
            AssetTab.location => AssetLocationTab(asset: a),
            AssetTab.iot => AssetIotTab(asset: a),
            AssetTab.maintenance => AssetMaintenanceTab(asset: a),
            AssetTab.inspection => AssetInspectionTab(asset: a),
            AssetTab.financial => AssetFinancialTab(asset: a),
            AssetTab.documents => AssetDocumentsTab(asset: a),
            AssetTab.history => AssetHistoryTab(asset: a),
          },
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.asset, required this.onFavorite, required this.onMenu});

  final Asset asset;
  final VoidCallback onFavorite;
  final ValueChanged<_Menu> onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disposalPending = ref.watch(disposalsProvider).pendingFor(asset.id) != null;
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
                  Text(asset.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.pageTitle),
                  StatusChip(asset.status),
                  if (disposalPending)
                    const StatusChip('Disposal pending', tone: ChipTone.amber, icon: Icons.hourglass_top_rounded),
                ],
              ),
              const SizedBox(height: 3),
              Text(asset.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.pageSubtitle),
            ],
          ),
        ),
        _SquareIcon(
          tooltip: asset.favorite ? 'Remove from Favorites' : 'Add to Favorites',
          icon: asset.favorite ? Icons.star_rounded : Icons.star_border_rounded,
          color: asset.favorite ? AppColors.amber : AppColors.text,
          onTap: DemoGuard.tap(DemoAction.assetFavourite, onFavorite),
        ),
        const SizedBox(width: 8),
        DemoGuard(
          action: DemoAction.assetMenu,
          child: PopupMenuButton<_Menu>(
            tooltip: 'More',
            onSelected: onMenu,
            itemBuilder: (_) => [
              for (final (m, icon, label) in [
                (_Menu.edit, Icons.edit_outlined, 'Edit Asset'),
                (_Menu.moreActions, Icons.more_horiz_rounded, 'More Actions'),
                (_Menu.print, Icons.print_outlined, 'Print Tag'),
                (_Menu.share, Icons.share_outlined, 'Share'),
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
                      Text(label, style: TextStyle(color: m == _Menu.delete ? AppColors.red : AppColors.text)),
                    ],
                  ),
                ),
            ],
            child: const _SquareIcon(icon: Icons.more_vert_rounded),
          ),
        ),
      ],
    );
  }
}

/// 40×40 outlined square icon button (☆ and ⋮ in the header).
class _SquareIcon extends StatelessWidget {
  const _SquareIcon({required this.icon, this.onTap, this.tooltip, this.color});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  Color get _color => color ?? AppColors.text;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: _color, size: 22),
    );
    if (onTap == null) return box;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.button), child: box),
    );
  }
}

class _PhotoAndSpecs extends ConsumerWidget {
  const _PhotoAndSpecs({required this.asset});

  final Asset asset;

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final path = await pickPhoto(context);
    if (path == null || !context.mounted) return;
    ref.read(assetsProvider.notifier).addPhoto(asset.id, path);
    context.showSnack('Photo added to ${asset.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = asset.gallery;
    final specs = [
      ('Asset Type', asset.type),
      ('Category', asset.category),
      ('Model', asset.model ?? '—'),
      ('Manufacturer', asset.manufacturer),
      ('Serial No.', asset.serialNo ?? '—'),
      ('Tag ID (RFID)', asset.tagId ?? '—'),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 8,
            child: GestureDetector(
              onTap: gallery.isEmpty
                  ? DemoGuard.tap(DemoAction.assetAddPhoto, () => _addPhoto(context, ref))
                  : DemoGuard.tap(DemoAction.assetPhotoViewer, () => openPhotoViewer(context, gallery)),
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
                          Icon(assetIcon(asset), size: 44, color: AppColors.textMuted),
                          const SizedBox(height: 6),
                          Text('Add photo', style: AppText.link),
                        ],
                      )
                    else
                      Image(image: photoProvider(gallery.first), fit: BoxFit.cover),
                    if (gallery.length > 1)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
                              const SizedBox(width: 3),
                              Text('${gallery.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, value) in specs) _SpecRow(label, value),
                  const _SpecRow('Barcode / QR', ''),
                  Padding(
                    padding: const EdgeInsets.only(left: 78, top: 2),
                    child: Code39Barcode(data: asset.barcode ?? asset.id, height: 26),
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

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 10.5, color: AppColors.text, height: 1.3);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, maxLines: 1, style: style)),
          Text(': ', style: style),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCards extends ConsumerWidget {
  const _StatCards({required this.asset, required this.onTab});

  final Asset asset;
  final ValueChanged<AssetTab> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider); // age / warranty labels follow the demo clock
    final crit = ChipTone.forAsset(asset.criticality);
    final healthColor = asset.healthScore >= 80
        ? AppColors.green
        : asset.healthScore >= 60
        ? AppColors.amber
        : AppColors.red;
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
            value: asset.healthScore / 100,
            size: 42,
            strokeWidth: 5,
            color: healthColor,
            center: Text('${asset.healthScore}%', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
          value: '',
          label: 'Health Score',
          onTap: DemoGuard.tap(DemoAction.assetHealthSheet, () => showHealthScoreSheet(context, ref, asset)),
        ),
        const SizedBox(width: 8),
        card(
          top: Icon(
            Icons.speed_rounded,
            size: 34,
            color: crit.foreground == AppColors.grey ? AppColors.green : crit.foreground,
          ),
          value: asset.criticality,
          valueColor: crit.foreground == AppColors.grey ? AppColors.green : crit.foreground,
          label: 'Criticality',
          onTap: DemoGuard.tap(
            DemoAction.assetHelpSheet,
            () => showHelpSheet(
              context,
              title: 'Criticality',
              body:
                  '${asset.id} is rated ${asset.criticality}. Criticality reflects the impact of a failure on production, '
                  'safety and cost: Critical assets stop the plant or affect safety, High assets stop a line, Medium assets '
                  'slow work down and Low assets have little impact. It sets the default work-order priority and PM frequency.',
            ),
          ),
        ),
        const SizedBox(width: 8),
        card(
          top: const Icon(Icons.check_circle_rounded, size: 30, color: AppColors.green),
          value: asset.ageLabel,
          label: 'Age',
          onTap: () => onTab(AssetTab.financial),
        ),
        const SizedBox(width: 8),
        card(
          top: Icon(
            Icons.calendar_month_rounded,
            size: 30,
            color: asset.warrantyWarning ? AppColors.red : AppColors.iconBlue,
          ),
          value: DemoClock.formatDate(asset.warrantyExpiry),
          valueColor: asset.warrantyExpired ? AppColors.red : null,
          label: 'Warranty Expiry',
          onTap: () => onTab(AssetTab.documents),
        ),
      ],
    );
  }
}

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid({required this.asset, required this.onTab});

  final Asset asset;
  final ValueChanged<AssetTab> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = assetActions(context, ref, asset);
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: .98,
      children: [
        for (final (icon, label, tone, onTap) in actions)
          ActionTile(icon: icon, label: label, tone: tone, onTap: onTap, labelSize: 11.5),
      ],
    );
  }
}
