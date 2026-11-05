import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/disposals_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_common.dart';

/// The ten rows of More Actions, in the order of the design. [slug] is the route segment.
enum MoreAction {
  checkInOut(
    'check-in-out',
    'Check in / Check Out',
    'Check In / Check Out',
    'Hand the asset to a person or take it back',
    Icons.sync_alt_rounded,
  ),
  assignCustodian(
    'assign-custodian',
    'Assign Custodian',
    'Assign Custodian',
    'Make a person responsible for the asset',
    Icons.person_add_alt_1_outlined,
  ),
  updateCondition(
    'condition',
    'Update Condition',
    'Update Condition',
    'Record the asset\'s physical condition',
    Icons.fact_check_outlined,
  ),
  addDocument('document', 'Add Document', 'Add Document', 'Upload a file for the asset', Icons.upload_file_outlined),
  addMedia(
    'media',
    'Add Photo / Video',
    'Add Photo / Video',
    'Add photos or a short video to the asset',
    Icons.add_a_photo_outlined,
  ),
  viewOnMap('map', 'View on Map', 'View on Map', 'Where the asset is', Icons.location_on_outlined),
  favorites(
    'favorites',
    'Add to Favorites',
    'Add to Favorites',
    'Keep the asset in a favorite group',
    Icons.favorite_border_rounded,
  ),
  printTag('print-tag', 'Print Asset Tag', 'Print Asset Tag', 'Print a barcode / QR label', Icons.print_outlined),
  share(
    'share',
    'Share Asset Details',
    'Share Asset Details',
    'Send the asset details to someone',
    Icons.share_outlined,
  ),
  disposal(
    'disposal',
    'Create Disposal Request',
    'Create Disposal Request',
    'Ask to dispose of the asset',
    Icons.delete_outline_rounded,
  );

  const MoreAction(this.slug, this.label, this.title, this.subtitle, this.icon);

  final String slug;

  /// Row label on More Actions.
  final String label;

  /// Screen title.
  final String title;
  final String subtitle;
  final IconData icon;

  static MoreAction? bySlug(String slug) => values.where((a) => a.slug == slug).firstOrNull;

  /// Actions the backend supports in API mode (the rest say "Not available yet").
  bool get availableLive => switch (this) {
    updateCondition || addDocument || addMedia || favorites || printTag || share => true,
    _ => false,
  };
}

/// The asset at the top of More Actions and of every action screen: photo, ID, name, type,
/// status chip (and "Disposal pending"). [onChange] adds the "Change" button.
class MoreActionAssetCard extends ConsumerWidget {
  const MoreActionAssetCard({super.key, required this.asset, this.onChange});

  final Asset asset;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = asset;
    // API mode: disposals are not on the server yet (no mock data is read).
    final disposalPending = !apiMode && ref.watch(disposalsProvider).pendingFor(a.id) != null;
    return AppCard(
      child: Row(
        children: [
          AssetThumb(imagePath: a.gallery.firstOrNull, fallbackIcon: assetIcon(a), size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(a.type, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    AssetStatusChip(a.status),
                    if (disposalPending)
                      const StatusChip('Disposal pending', tone: ChipTone.amber, icon: Icons.hourglass_top_rounded),
                  ],
                ),
              ],
            ),
          ),
          if (onChange != null) TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

/// Frame of an action screen: title, the asset card, the form and a sticky [button].
class MoreActionPage extends ConsumerWidget {
  const MoreActionPage({super.key, required this.action, required this.assetId, required this.builder, this.button});

  final MoreAction action;
  final String? assetId;
  final List<Widget> Function(BuildContext context, Asset asset) builder;
  final Widget Function(Asset asset)? button;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // API mode: the asset comes from the Asset service, mapped to an Asset for the shared forms.
    if (apiMode && assetId != null) {
      return LiveAssetLoader(code: assetId!, builder: (context, r) => _page(context, liveAsAsset(r)));
    }
    final a = assetId == null || apiMode ? null : ref.watch(assetsProvider).byCode(assetId!);
    if (a == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Select an asset first',
          message: assetId == null ? 'Open this action from More Actions.' : '$assetId is not in the register.',
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
      );
    }
    return _page(context, a);
  }

  Widget _page(BuildContext context, Asset a) {
    return AppScaffold(
      bottomActions: button?.call(a),
      body: ListView(
        padding: button == null ? context.pagePadding : const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          PageTitle(title: action.title, subtitle: action.subtitle),
          const SizedBox(height: 14),
          MoreActionAssetCard(asset: a),
          const SizedBox(height: 16),
          ...builder(context, a),
        ],
      ),
    );
  }
}

/// Field label + field with the standard gap below.
Widget formField(String label, Widget child, {bool required = false}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: LabeledField(label: label, required: required, child: child),
);

/// Red helper text under a control that has no InputDecoration of its own.
Widget fieldError(String? text) => text == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: AppText.caption.copyWith(color: AppColors.red)),
      );

/// Simple dropdown with a "Select" hint and an error line.
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.error,
    this.hint = 'Select',
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String? error;
  final String hint;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    icon: const Icon(Icons.keyboard_arrow_down_rounded),
    hint: Text(hint, style: hintStyle),
    decoration: InputDecoration(errorText: error),
    items: [
      for (final o in options)
        DropdownMenuItem(
          value: o,
          child: Text(o, overflow: TextOverflow.ellipsis, style: inputStyle),
        ),
    ],
    onChanged: (v) => v == null ? null : onChanged(v),
  );
}

/// Ends an action: back to More Actions (or wherever the screen was opened from) with a SnackBar.
void finishAction(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  if (context.canPop()) context.pop();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
