import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/sections/live_devices_card.dart';

/// Home → Live Devices → View Devices: GET /api/dashboards/network-status/tags (tag id, record
/// count, mapped asset), highest count first. A row with an asset opens the live Asset detail.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(networkTagsProvider);
    final live = ref.watch(liveDevicesProvider);
    final counts = live.counts ?? ref.watch(networkStatusProvider).value;
    final list = tags.value;
    final Widget sliver;
    if (tags.hasError && !tags.isLoading) {
      sliver = SliverToBoxAdapter(
        child: LoadErrorState(error: tags.error!, onRetry: () => ref.invalidate(networkTagsProvider)),
      );
    } else if (list == null || tags.isLoading) {
      sliver = const SliverToBoxAdapter(child: ListSkeleton(rows: 6));
    } else if (list.isEmpty) {
      sliver = const SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.sensors_off_rounded,
          title: 'No tags reporting yet',
          message: 'Tags appear here once they send data.',
        ),
      );
    } else {
      sliver = SliverCardList(
        itemCount: list.length,
        indent: 62,
        itemBuilder: (_, i) => _TagRow(tag: list[i]),
      );
    }
    return DrilldownPage(
      title: 'Devices',
      subtitle: counts == null
          ? 'Tags by record count'
          : '${dashNumber.format(counts.totalOnline)} online · ${dashNumber.format(counts.totalOffline)} offline',
      trailing: LiveDot(connection: live.connection),
      skeletonRows: 6,
      onRefresh: () => ref
        ..invalidate(networkTagsProvider)
        ..invalidate(networkStatusProvider),
      sliver: sliver,
      footer: [
        if (list != null && list.isNotEmpty) ShowingFooter(text: '${list.length} ${list.length == 1 ? 'tag' : 'tags'}'),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag});

  final TagRecordCount tag;

  @override
  Widget build(BuildContext context) {
    final assetId = tag.assetId;
    return InkWell(
      onTap: assetId == null
          ? () => context.showSnack('No asset is linked to tag ${tag.tagId}')
          : () => context.push(Routes.assetDetail(assetId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            IconSquare(icon: Icons.sensors_rounded, tone: TileTone.sky, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.tagId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tag.assetName ?? assetId ?? 'No asset linked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: assetId == null ? AppColors.textMuted : null),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dashNumber.format(tag.count), style: AppText.bodyStrong),
                Text('records', style: AppText.caption),
              ],
            ),
            if (assetId != null) Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
