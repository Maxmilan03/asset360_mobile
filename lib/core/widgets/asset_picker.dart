import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/models/asset_registration_mapping.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';

/// The asset chosen in [pickAsset]: its id (API mode: the assetRegistrationId) and "id – name".
typedef PickedAsset = ({String id, String label});

/// Bottom sheet with a searchable asset list. Returns the chosen asset ID (API mode: the
/// assetRegistrationId of a live asset).
Future<String?> showAssetPicker(BuildContext context, {String title = 'Select Asset', String? selectedId}) async =>
    (await pickAsset(context, title: title, selectedId: selectedId))?.id;

/// [showAssetPicker] with the chosen asset's label.
Future<PickedAsset?> pickAsset(BuildContext context, {String title = 'Select Asset', String? selectedId}) {
  return showModalBottomSheet<PickedAsset>(
    context: context,
    isScrollControlled: true,
    builder: (_) => apiMode
        ? _LiveAssetPickerSheet(title: title, selectedId: selectedId)
        : _AssetPickerSheet(title: title, selectedId: selectedId),
  );
}

/// The picker's frame: title + count, search field, list.
class _PickerFrame extends StatelessWidget {
  const _PickerFrame({required this.title, required this.count, required this.onSearch, required this.body});

  final String title;
  final String count;
  final ValueChanged<String> onSearch;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: AppText.sectionTitle)),
                    Text(count, style: AppText.caption),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: apiMode
                        ? 'Search by asset tag, name or ID'
                        : 'Search by Asset ID, name, serial or location',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetPickerSheet extends ConsumerStatefulWidget {
  const _AssetPickerSheet({required this.title, this.selectedId});

  final String title;
  final String? selectedId;

  @override
  ConsumerState<_AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends ConsumerState<_AssetPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetsProvider).search(_query);
    return _PickerFrame(
      title: widget.title,
      count: '${assets.length} assets',
      onSearch: (v) => setState(() => _query = v),
      body: assets.isEmpty
          ? const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No assets found',
              message: 'Try another ID or name.',
            )
          : ListView.separated(
              itemCount: assets.length,
              separatorBuilder: (_, _) => const Divider(indent: 90),
              itemBuilder: (_, i) {
                final a = assets[i];
                return AssetListTile(
                  title: a.id,
                  subtitle: a.name,
                  location: a.location,
                  imagePath: a.imagePath,
                  trailingTop: AssetStatusChip(a.status),
                  showChevron: false,
                  selected: a.id == widget.selectedId,
                  onTap: () => Navigator.pop(context, (id: a.id, label: '${a.id} – ${a.name}')),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------- API mode

/// One live asset row (GET /api/asset-registrations item): tag (else registration ID), name,
/// location path, server image and status.
class LiveAssetTile extends StatelessWidget {
  const LiveAssetTile({
    super.key,
    required this.item,
    required this.onTap,
    this.selected = false,
    this.showChevron = true,
    this.trailingBottom,
    this.statusChip,
  });

  final AssetListItem item;

  /// Replaces the default [AssetStatusChip] of `item.status` (dashboard rows colour it by status group).
  final Widget? statusChip;
  final VoidCallback? onTap;
  final bool selected;
  final bool showChevron;
  final String? trailingBottom;

  static String locationOf(AssetListItem i) =>
      i.locationPath ?? [i.siteName, i.buildingName, i.floorName].nonNulls.join(' / ');

  @override
  Widget build(BuildContext context) {
    final tag = item.assetTag;
    return AssetListTile(
      title: tag ?? item.assetRegistrationId,
      subtitle: item.assetName ?? 'Untitled asset',
      location: locationOf(item).isEmpty ? null : locationOf(item),
      imagePath: item.imageUrl,
      details: [if (tag != null) TagLabel(item.assetRegistrationId, icon: Icons.tag_rounded)],
      trailingTop: statusChip ?? (item.status == null ? null : AssetStatusChip(item.status!)),
      trailingBottom: trailingBottom,
      showChevron: showChevron,
      selected: selected,
      onTap: onTap,
    );
  }
}

/// Live picker: GET /api/asset-registrations?search= (debounced), first 20 rows.
class _LiveAssetPickerSheet extends ConsumerStatefulWidget {
  const _LiveAssetPickerSheet({required this.title, this.selectedId});

  final String title;
  final String? selectedId;

  @override
  ConsumerState<_LiveAssetPickerSheet> createState() => _LiveAssetPickerSheetState();
}

class _LiveAssetPickerSheetState extends ConsumerState<_LiveAssetPickerSheet> {
  static const debounce = Duration(milliseconds: 350);

  Timer? _debounce;
  AssetListQuery _query = const AssetListQuery();
  bool _picking = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String v) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () {
      if (mounted) setState(() => _query = AssetListQuery(search: v.trim().isEmpty ? null : v.trim()));
    });
  }

  /// Returns the id at once; the server record is cached first (best effort) so the screens that
  /// look an asset up by id (work orders, issues …) can show it.
  Future<void> _pick(AssetListItem i) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final r = await ref.read(assetsApiProvider).get(i.assetRegistrationId);
      final by = ref.read(currentUserProvider).name;
      ref.read(assetsProvider.notifier).cacheLive(r.toAsset(by: by).copyWith(id: r.assetRegistrationId));
    } catch (_) {
      // The id is enough.
    }
    if (!mounted) return;
    Navigator.pop(context, (id: i.assetRegistrationId, label: '${i.assetRegistrationId} – ${i.assetName ?? ''}'));
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(liveAssetListProvider(_query));
    final data = list.value;
    return _PickerFrame(
      title: widget.title,
      count: data == null ? '' : '${data.totalCount} assets',
      onSearch: _search,
      body: switch (list) {
        AsyncError(:final error) when data == null => LoadErrorState(
          error: error,
          onRetry: () => ref.invalidate(liveAssetListProvider(_query)),
        ),
        _ when data == null => const ListSkeleton(rows: 5, card: false),
        _ when data.items.isEmpty => const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No assets found',
          message: 'Try another tag, name or ID.',
        ),
        _ => Stack(
          children: [
            ListView.separated(
              itemCount: data.items.length + 1,
              separatorBuilder: (_, _) => const Divider(indent: 90),
              itemBuilder: (_, i) {
                if (i == data.items.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        data.hasMore
                            ? 'Showing ${data.items.length} of ${data.totalCount}. Search to narrow the list.'
                            : 'Showing ${data.items.length} of ${data.totalCount}',
                        style: AppText.caption,
                      ),
                    ),
                  );
                }
                final a = data.items[i];
                return LiveAssetTile(
                  item: a,
                  showChevron: false,
                  selected: a.assetRegistrationId == widget.selectedId,
                  onTap: () => _pick(a),
                );
              },
            ),
            if (_picking) const LinearProgressIndicator(),
          ],
        ),
      },
    );
  }
}
