import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_common.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_actions_screen.dart';

/// More Actions in API mode: the asset from the Asset service (`?asset=` = registration ID or any
/// tag code, a search, or a scan resolved through GET …/lookup) and the ten actions; those without a
/// backend say "Not available yet".
class LiveMoreActionsScreen extends ConsumerStatefulWidget {
  const LiveMoreActionsScreen({super.key, this.assetId});

  final String? assetId;

  @override
  ConsumerState<LiveMoreActionsScreen> createState() => _LiveMoreActionsScreenState();
}

class _LiveMoreActionsScreenState extends ConsumerState<LiveMoreActionsScreen> {
  late String? _code = widget.assetId;

  // Unknown codes are accepted too: the server's lookup decides (the local register is empty).
  late final _target = ScanTarget(
    accepts: const {MatchType.asset, MatchType.none},
    onScan: (r) => _select(r.event.value),
    debugLabel: 'LiveMoreActions',
  );

  @override
  void didUpdateWidget(LiveMoreActionsScreen old) {
    super.didUpdateWidget(old);
    if (widget.assetId != old.assetId && widget.assetId != null) _code = widget.assetId;
  }

  void _select(String code) {
    if (!mounted) return;
    setState(() => _code = code.trim());
  }

  Future<void> _search() async {
    final id = await showLiveAssetPicker(context);
    if (id != null) _select(id);
  }

  Future<void> _scan() async {
    final code = await captureScan(context);
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

  void _open(MoreAction action, AssetRegistration? r) {
    if (r == null) {
      context.showSnack('Select an asset first');
      return;
    }
    if (!action.availableLive) {
      showNotAvailableYet(context, action.label);
      return;
    }
    final id = r.assetRegistrationId;
    if (action == MoreAction.favorites) {
      final fav = ref.read(liveFavoritesProvider).contains(id);
      ref.read(liveFavoritesProvider.notifier).toggle(id);
      context.showSnack(fav ? '${r.title} removed from Favorites' : '${r.title} added to Favorites');
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    context.push(Routes.moreActionFrom(GoRouterState.of(context).uri.path, action.slug, id));
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    final idAsync = code == null ? null : ref.watch(liveAssetIdProvider(code));
    final id = idAsync?.value;
    final assetAsync = id == null ? null : ref.watch(liveAssetProvider(id));
    final asset = assetAsync?.value;
    final favorites = ref.watch(liveFavoritesProvider);
    final loading = (idAsync?.isLoading ?? false) || (assetAsync?.isLoading ?? false);
    final error = idAsync?.error ?? assetAsync?.error;
    return ScanTargetScope(
      target: _target,
      child: AppScaffold(
        body: ListView(
          padding: context.pagePadding,
          children: [
            const PageTitle(title: 'More Actions', subtitle: 'Additional asset actions'),
            const SizedBox(height: 14),
            if (asset != null)
              LiveAssetCard(asset: asset, onChange: _search)
            else if (loading)
              const ListSkeleton(rows: 1)
            else ...[
              SelectAssetCard(onSearch: _search, onScan: _scan),
              if (code != null) ...[
                const SizedBox(height: 8),
                Text(
                  error != null ? ApiException.from(error).message : 'No asset matches "$code". Search or scan again.',
                  style: AppText.caption.copyWith(color: AppColors.red),
                ),
              ],
            ],
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, action) in MoreAction.values.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 64, color: AppColors.divider),
                    MoreActionRow(
                      action: action,
                      enabled: asset != null && action.availableLive,
                      label: action == MoreAction.favorites && asset != null && favorites.contains(id)
                          ? 'Remove from Favorites'
                          : null,
                      note: action.availableLive ? null : notAvailableYetMessage,
                      onTap: () => _open(action, asset),
                    ),
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

/// `/<tab>/more-actions/favorites` in API mode: favorites are kept on this device
/// ([liveFavoritesProvider]); the backend has no favorite groups.
class LiveFavoriteScreen extends ConsumerWidget {
  const LiveFavoriteScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(liveFavoritesProvider);
    return LiveActionPage(
      action: MoreAction.favorites,
      assetId: assetId,
      button: (r) {
        final fav = favorites.contains(r.assetRegistrationId);
        return FilledButton.icon(
          onPressed: () {
            ref.read(liveFavoritesProvider.notifier).toggle(r.assetRegistrationId);
            finishAction(context, fav ? '${r.title} removed from Favorites' : '${r.title} added to Favorites');
          },
          icon: Icon(fav ? Icons.star_border_rounded : Icons.star_rounded),
          label: Text(fav ? 'Remove from Favorites' : 'Add to Favorites'),
        );
      },
      builder: (context, r) => [
        Text(
          favorites.contains(r.assetRegistrationId)
              ? '${r.title} is in your Favorites on this device.'
              : 'Favorites are kept on this device. Favorite groups are not available yet.',
          style: AppText.secondary,
        ),
      ],
    );
  }
}
