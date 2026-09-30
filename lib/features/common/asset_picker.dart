import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/assets_repository.dart';

/// Bottom sheet with a searchable asset list. Returns the chosen asset ID.
Future<String?> showAssetPicker(BuildContext context, {String title = 'Select Asset', String? selectedId}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AssetPickerSheet(title: title, selectedId: selectedId),
  );
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
                    Expanded(child: Text(widget.title, style: AppText.sectionTitle)),
                    Text('${assets.length} assets', style: AppText.caption),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by Asset ID, name, serial or location',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: assets.isEmpty
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
                            trailingTop: StatusChip(a.status),
                            showChevron: false,
                            selected: a.id == widget.selectedId,
                            onTap: () => Navigator.pop(context, a.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
