import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_condition.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_more_actions.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_upload.dart';
import 'package:asset360_mobile/features/assets/more_actions/add_document_action_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/add_media_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/assign_custodian_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/check_in_out_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/disposal_request_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/favorites_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';
import 'package:asset360_mobile/features/assets/more_actions/print_tag_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/share_asset_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/update_condition_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/view_on_map_screen.dart';

/// The screen for `/<tab>/more-actions/<slug>?asset=…`.
Widget moreActionScreen(String slug, String? assetId) => switch (MoreAction.bySlug(slug)) {
  // API mode: the backend's forms; actions without a backend say "Not available yet".
  final a? when apiMode && !a.availableLive => AppScaffold(
    body: Center(
      child: NotAvailableYet(feature: a.title, icon: a.icon),
    ),
  ),
  MoreAction.updateCondition when apiMode => LiveUpdateConditionScreen(assetId: assetId),
  MoreAction.addDocument when apiMode => LiveAddDocumentScreen(assetId: assetId),
  MoreAction.addMedia when apiMode => LiveAddPhotoScreen(assetId: assetId),
  MoreAction.favorites when apiMode => LiveFavoriteScreen(assetId: assetId),
  MoreAction.checkInOut => CheckInOutScreen(assetId: assetId),
  MoreAction.assignCustodian => AssignCustodianScreen(assetId: assetId),
  MoreAction.updateCondition => UpdateConditionScreen(assetId: assetId),
  MoreAction.addDocument => AddDocumentActionScreen(assetId: assetId),
  MoreAction.addMedia => AddMediaScreen(assetId: assetId),
  MoreAction.viewOnMap => ViewOnMapScreen(assetId: assetId),
  MoreAction.favorites => FavoritesScreen(assetId: assetId),
  MoreAction.printTag => PrintTagScreen(assetId: assetId),
  MoreAction.share => ShareAssetScreen(assetId: assetId),
  MoreAction.disposal => DisposalRequestScreen(assetId: assetId),
  null => const AppScaffold(
    body: EmptyState(icon: Icons.help_outline_rounded, title: 'Unknown action', message: 'This action does not exist.'),
  ),
};

/// More Actions: the selected asset (or a picker) and ten asset actions.
/// A scan from any source (camera icon, TC57 trigger, NFC …) selects the asset while this screen is visible.
class MoreActionsScreen extends ConsumerStatefulWidget {
  const MoreActionsScreen({super.key, this.assetId});

  /// From `?asset=` (Asset detail, Scan result); null from Home.
  final String? assetId;

  @override
  ConsumerState<MoreActionsScreen> createState() => _MoreActionsScreenState();
}

class _MoreActionsScreenState extends ConsumerState<MoreActionsScreen> {
  late String? _assetId = _resolve(widget.assetId);
  late final _target = ScanTarget(accepts: const {MatchType.asset}, onScan: _onScan, debugLabel: 'MoreActions');

  String? _resolve(String? code) => code == null ? null : ref.read(assetsProvider).byCode(code)?.id;

  @override
  void didUpdateWidget(MoreActionsScreen old) {
    super.didUpdateWidget(old);
    if (apiMode) return;
    if (widget.assetId != old.assetId && widget.assetId != null) _assetId = _resolve(widget.assetId);
  }

  void _select(String id) {
    setState(() => _assetId = id);
    context.showSnack('Selected $id');
  }

  void _onScan(ScanResult r) {
    if (mounted && r.matchId != null) _select(r.matchId!);
  }

  Future<void> _search() async {
    final id = await showAssetPicker(context, selectedId: _assetId);
    if (id != null && mounted) setState(() => _assetId = id);
  }

  /// Camera scan through ScanService (history, duplicate guard, tag links).
  Future<void> _scan() async {
    final code = await captureScan(context, suggestions: const ['LAP-0098', 'MTR-00123', 'CNC-00123']);
    if (code == null || !mounted) return;
    await handleScanEvent(
      context,
      ref,
      ScanEvent(
        value: code.code,
        format: code.format,
        source: code.format == 'manual' ? ScanSource.manual : ScanSource.camera,
      ),
      requester: _target,
    );
  }

  void _open(MoreAction action) {
    if (_assetId == null) {
      context.showSnack('Select an asset first');
      return;
    }
    // A SnackBar from this screen would cover the action's sticky button.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    context.push(Routes.moreActionFrom(GoRouterState.of(context).uri.path, action.slug, _assetId!));
  }

  @override
  Widget build(BuildContext context) {
    // API mode: the asset comes from the Asset service (no mock assets are read).
    if (apiMode) return LiveMoreActionsScreen(assetId: widget.assetId);
    final asset = _assetId == null ? null : ref.watch(assetByIdProvider(_assetId!));
    return ScanTargetScope(
      target: _target,
      child: AppScaffold(
        body: ListView(
          padding: context.pagePadding,
          children: [
            const PageTitle(title: 'More Actions', subtitle: 'Additional asset actions'),
            const SizedBox(height: 14),
            if (asset != null)
              MoreActionAssetCard(asset: asset, onChange: _search)
            else
              SelectAssetCard(onSearch: _search, onScan: _scan),
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, action) in MoreAction.values.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 64, color: AppColors.divider),
                    MoreActionRow(action: action, enabled: asset != null, onTap: () => _open(action)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Select an asset": search field + scan button (also the live More Actions).
class SelectAssetCard extends StatelessWidget {
  const SelectAssetCard({super.key, required this.onSearch, required this.onScan});

  final VoidCallback onSearch;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Select an asset', style: AppText.cardTitle),
          const SizedBox(height: 2),
          Text('Search, or scan the asset tag (camera or scanner trigger)', style: AppText.caption),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onSearch,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                    ),
                    child: Text('Search by Asset ID or name', style: hintStyle),
                  ),
                ),
              ),
              ScanSuffix(onTap: onScan, tooltip: 'Scan asset tag'),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row of More Actions; [note] is a grey line under the label (e.g. "Not available yet").
class MoreActionRow extends StatelessWidget {
  const MoreActionRow({
    super.key,
    required this.action,
    required this.enabled,
    required this.onTap,
    this.label,
    this.note,
  });

  final MoreAction action;
  final bool enabled;
  final VoidCallback onTap;

  /// Replaces [MoreAction.label] (e.g. "Remove from Favorites").
  final String? label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              IconSquare(icon: action.icon, tone: enabled ? TileTone.lavender : TileTone.grey, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label ?? action.label, style: AppText.bodyStrong),
                    if (note != null) Text(note!, style: AppText.caption),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
