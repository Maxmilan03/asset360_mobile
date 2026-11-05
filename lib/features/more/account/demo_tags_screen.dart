import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/scans_mock.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';

/// Developer → Print demo tags: real, scannable QR codes for the mock records, so Scan &
/// Identify can be tried by pointing a second phone at this screen.
class DemoTagsScreen extends ConsumerStatefulWidget {
  const DemoTagsScreen({super.key});

  @override
  ConsumerState<DemoTagsScreen> createState() => _DemoTagsScreenState();
}

class _DemoTagsScreenState extends ConsumerState<DemoTagsScreen> {
  int _group = 0;

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetsProvider);
    final parts = ref.watch(inventoryProvider).parts;
    // API mode: the server's newest assets (their asset tags), never the mock register.
    final live = apiMode
        ? (ref.watch(recentLiveAssetsProvider).value ?? const <AssetListItem>[])
        : const <AssetListItem>[];
    final groups = <(String, List<(String code, String title, String subtitle)>)>[
      (
        'Assets',
        apiMode
            ? [
                for (final a in live)
                  (a.assetTag ?? a.assetRegistrationId, a.assetTag ?? a.assetRegistrationId, a.assetName ?? ''),
              ]
            : [for (final a in assets) (a.id, a.id, a.name)],
      ),
      ('Parts', [for (final p in parts) (p.id, p.id, p.name)]),
      (
        'Locations',
        [for (final l in scanLocations.take(8)) ('$locationCodePrefix$l', l.split(' – ').last, l.split(' – ').first)],
      ),
      ('Not registered', [(demoUnregisteredTag, demoUnregisteredTag, 'Opens "Tag not registered"')]),
    ];
    final tags = groups[_group].$2;
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Print demo tags',
            subtitle: 'Scan these from a second phone',
            help:
                'Every QR code on this page is a real code for a record in the demo data. Open Scan & Identify on '
                'another phone and point it at a tag. Turn the screen brightness up for faster reads.',
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < groups.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconFilterChip(
                      label: '${groups[i].$1} (${groups[i].$2.length})',
                      selected: _group == i,
                      onTap: () => setState(() => _group = i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .78,
            children: [
              for (final (code, title, subtitle) in tags)
                AppCard(
                  onTap: () => _showLargeTag(context, code, title, subtitle),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(6),
                            child: QrCode(data: code, size: 120),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-width QR code in a dialog (easier to read from a second phone).
Future<void> _showLargeTag(BuildContext context, String code, String title, String subtitle) {
  return showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, c) => QrCode(data: code, size: c.maxWidth.clamp(120, 260).toDouble()),
            ),
          ),
          const SizedBox(height: 10),
          Text(subtitle, textAlign: TextAlign.center, style: AppText.secondary),
          const SizedBox(height: 4),
          SelectableText(code, textAlign: TextAlign.center, style: AppText.caption),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}
