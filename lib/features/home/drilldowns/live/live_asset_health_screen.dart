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
import 'package:asset360_mobile/features/home/home_style.dart';
import 'package:asset360_mobile/features/home/sections/live_dashboard_cards.dart';

const _bands = ['healthy', 'warning', 'critical'];

ChipTone _tone(String band) => switch (band) {
  'healthy' => ChipTone.green,
  'warning' => ChipTone.amber,
  _ => ChipTone.red,
};

int _count(DashHealthGroup g, String band) => switch (band) {
  'healthy' => g.healthy,
  'warning' => g.warning,
  _ => g.critical,
};

/// API mode Asset Health: GET /api/dashboards/mobile/asset-health?top=10 — Overview (donut, bands,
/// top critical assets) | By Asset Type | By Location (site). Thresholds are the server's: latest
/// assessment score ≥ 70 healthy, ≥ 40 warning, else critical (unassessed assets fall back to
/// their condition, then status).
class LiveAssetHealthScreen extends ConsumerStatefulWidget {
  const LiveAssetHealthScreen({super.key});

  @override
  ConsumerState<LiveAssetHealthScreen> createState() => _LiveAssetHealthScreenState();
}

class _LiveAssetHealthScreenState extends ConsumerState<LiveAssetHealthScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final provider = dashAssetHealthProvider((top: LiveAssetHealthCard.top, site: ref.watch(dashSiteProvider)));
    return DrilldownPage(
      title: 'Asset Health',
      subtitle: 'Healthy ≥ 70 · Warning 40–69 · Critical < 40',
      onRefresh: () => ref.invalidate(provider),
      children: [
        SegmentTabs(
          tabs: const [SegmentTab('Overview'), SegmentTab('By Asset Type'), SegmentTab('By Location')],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 14),
        DashSection<DashAssetHealth>(
          provider: provider,
          onRetry: (ref) => ref.invalidate(provider),
          rows: 4,
          isEmpty: (h) => h.totalAssets == 0,
          emptyIcon: Icons.health_and_safety_outlined,
          emptyTitle: 'No assets to score yet',
          emptyMessage: 'Registered assets appear here with their health.',
          builder: (h) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: switch (_tab) {
              0 => _overview(h),
              1 => [_GroupList(groups: h.byAssetType, byType: true)],
              _ => [_GroupList(groups: h.byLocation, byType: false)],
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _overview(DashAssetHealth h) => [
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DonutWithLegend(
            center: DonutCenter(value: dashPct(h.healthyPercent), caption: 'Healthy', fontSize: 21),
            slices: [
              for (final b in h.breakdown)
                DonutSlice(
                  label: b.label,
                  value: b.count.toDouble(),
                  color: dashHealthColor(b.key),
                  onTap: () => _showBandSheet(context, h, b),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${dashNumber.format(h.totalAssets)} assets · tap a band to see the asset types behind it',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    SectionCard(
      title: 'Assets by Health Status',
      child: Column(
        children: [
          for (final b in h.breakdown)
            InkWell(
              onTap: () => _showBandSheet(context, h, b),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(b.label, style: AppText.body.copyWith(fontSize: 13))),
                        Text(dashNumber.format(b.count), style: AppText.bodyStrong.copyWith(fontSize: 13)),
                        SizedBox(
                          width: 48,
                          child: Text(dashPct(b.percent), textAlign: TextAlign.right, style: AppText.caption),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StackedMiniBar(
                      values: [b.count],
                      colors: [dashHealthColor(b.key)],
                      height: 10,
                      fraction: b.percent / 100,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    SectionCard(
      title: 'Top Assets with Critical Health',
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: h.criticalAssets.isEmpty
          ? const EmptyState(
              icon: Icons.health_and_safety_outlined,
              title: 'No assets in critical health',
              message: 'No asset needs attention right now.',
            )
          : Column(
              children: [
                for (var i = 0; i < h.criticalAssets.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _CriticalRow(asset: h.criticalAssets[i]),
                ],
              ],
            ),
    ),
  ];
}

/// The asset types with the most assets in band [b]; a row opens Recent Assets of that type.
Future<void> _showBandSheet(BuildContext context, DashAssetHealth h, DashBreakdownItem b) {
  final types = [...h.byAssetType.where((t) => _count(t, b.key) > 0)]
    ..sort((x, y) => _count(y, b.key).compareTo(_count(x, b.key)));
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (ctx) => sheetFrame(ctx, [
      SheetTitle('${b.label} assets', subtitle: '${dashNumber.format(b.count)} assets · top asset types'),
      const SizedBox(height: 8),
      if (types.isEmpty)
        EmptyState(icon: Icons.inbox_outlined, title: 'No ${b.label.toLowerCase()} assets')
      else
        for (final t in types.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: IconSquare(icon: assetTypeIcon(t.key), tone: TileTone.lavender, size: 36),
            title: Text(t.key, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
            subtitle: Text('${(_count(t, b.key) * 100 / (t.total == 0 ? 1 : t.total)).round()}% of ${t.total}'),
            trailing: StatusChip(dashNumber.format(_count(t, b.key)), tone: _tone(b.key)),
            onTap: () {
              Navigator.pop(ctx);
              context.push(Routes.recentAssetsFiltered(type: t.key));
            },
          ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
    ]),
  );
}

class _CriticalRow extends StatelessWidget {
  const _CriticalRow({required this.asset});

  final DashCriticalAsset asset;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(Routes.assetDetail(asset.assetRegistrationId)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          IconSquare(icon: assetTypeIcon(asset.assetType ?? ''), tone: TileTone.pink, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.assetTag ?? asset.assetRegistrationId, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  asset.assetName ?? asset.assetType ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.red),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        asset.issue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (asset.healthScore != null) StatusChip('${asset.healthScore!.round()}%', tone: ChipTone.red),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    ),
  );
}

/// By Asset Type / By Location: one row per group with a stacked Healthy / Warning / Critical bar;
/// a row opens Recent Assets of that type / site.
class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups, required this.byType});

  final List<DashHealthGroup> groups;
  final bool byType;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const EmptyState(icon: Icons.inbox_outlined, title: 'No assets');
    final max = groups.fold(0, (m, g) => g.total > m ? g.total : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeriesLegend(items: [for (final b in _bands) ('${b[0].toUpperCase()}${b.substring(1)}', dashHealthColor(b))]),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: groups[i].key.toLowerCase() == 'others'
                      ? () => context.showSnack(
                          'These ${groups[i].total} assets have no ${byType ? 'asset type' : 'site'} recorded',
                        )
                      : () => context.push(
                          byType
                              ? Routes.recentAssetsFiltered(type: groups[i].key)
                              : Routes.recentAssetsFiltered(site: groups[i].key),
                        ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        IconSquare(
                          icon: byType ? assetTypeIcon(groups[i].key) : Icons.location_city_rounded,
                          tone: byType ? TileTone.lavender : TileTone.sky,
                          size: 38,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      groups[i].key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.bodyStrong.copyWith(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    dashNumber.format(groups[i].total),
                                    style: AppText.bodyStrong.copyWith(fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              StackedMiniBar(
                                values: [for (final b in _bands) _count(groups[i], b)],
                                colors: [for (final b in _bands) dashHealthColor(b)],
                                fraction: max == 0 ? 0 : groups[i].total / max,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${[for (final b in _bands) dashNumber.format(_count(groups[i], b))].join(' · ')}'
                                ' · ${dashPct(groups[i].healthyPercent)} healthy',
                                style: AppText.caption.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
