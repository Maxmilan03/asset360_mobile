import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

final _n = NumberFormat('#,###');

ChipTone _bandTone(HealthBand b) => switch (b) {
  HealthBand.healthy => ChipTone.green,
  HealthBand.warning => ChipTone.amber,
  HealthBand.critical => ChipTone.red,
};

/// Home "Asset Health" → View Details: Overview | By Asset Type | By Location.
class AssetHealthScreen extends ConsumerStatefulWidget {
  const AssetHealthScreen({super.key});

  @override
  ConsumerState<AssetHealthScreen> createState() => _AssetHealthScreenState();
}

class _AssetHealthScreenState extends ConsumerState<AssetHealthScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(assetBreakdownProvider);
    return DrilldownPage(
      title: 'Asset Health',
      subtitle: 'Healthy ≥ 80 · Warning 60–79 · Critical < 60',
      children: [
        SegmentTabs(
          tabs: const [SegmentTab('Overview'), SegmentTab('By Asset Type'), SegmentTab('By Location')],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 14),
        ...switch (_tab) {
          0 => _overview(b),
          1 => [_GroupList(stats: b.byType, byType: true)],
          _ => [_GroupList(stats: b.byLocation, byType: false)],
        },
      ],
    );
  }

  List<Widget> _overview(AssetBreakdown b) {
    final critical = ref.watch(criticalHealthAssetsProvider);
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonutWithLegend(
              center: DonutCenter(value: '${b.bandPct(HealthBand.healthy).round()}%', caption: 'Healthy', fontSize: 21),
              slices: [
                for (final band in HealthBand.values)
                  DonutSlice(
                    label: band.label,
                    value: b.band(band).toDouble(),
                    color: healthBandColors[band]!,
                    onTap: () => _showBandSheet(context, b, band),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_n.format(b.total)} assets · tap a band to see the asset types behind it',
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
            for (final band in HealthBand.values)
              InkWell(
                onTap: () => _showBandSheet(context, b, band),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(band.label, style: AppText.body.copyWith(fontSize: 13))),
                          Text(_n.format(b.band(band)), style: AppText.bodyStrong.copyWith(fontSize: 13)),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${b.bandPct(band).round()}%',
                              textAlign: TextAlign.right,
                              style: AppText.caption,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      StackedMiniBar(
                        values: [b.band(band)],
                        colors: [healthBandColors[band]!],
                        height: 10,
                        fraction: b.bandPct(band) / 100,
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
        child: critical.isEmpty
            ? const EmptyState(
                icon: Icons.health_and_safety_outlined,
                title: 'All assets healthy',
                message: 'No asset needs attention right now.',
              )
            : Column(
                children: [
                  for (var i = 0; i < critical.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _CriticalRow(asset: critical[i].$1, reason: critical[i].$2),
                  ],
                ],
              ),
      ),
    ];
  }
}

/// Bottom sheet: the asset types with the most assets in [band]; a row opens the filtered Assets list.
Future<void> _showBandSheet(BuildContext context, AssetBreakdown b, HealthBand band) {
  final types = [...b.byType]..sort((x, y) => y.count(band).compareTo(x.count(band)));
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (ctx) => sheetFrame(ctx, [
      SheetTitle('${band.label} assets', subtitle: '${_n.format(b.band(band))} assets · top asset types'),
      const SizedBox(height: 8),
      for (final t in types.take(5))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconSquare(icon: assetTypeIcon(t.name), tone: TileTone.lavender, size: 36),
          title: Text(t.name, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
          subtitle: Text('${(t.count(band) * 100 / (t.total == 0 ? 1 : t.total)).round()}% of ${_n.format(t.total)}'),
          trailing: StatusChip(_n.format(t.count(band)), tone: _bandTone(band)),
          onTap: () {
            Navigator.pop(ctx);
            context.push(Routes.assetsWithType(t.name));
          },
        ),
    ]),
  );
}

class _CriticalRow extends StatelessWidget {
  const _CriticalRow({required this.asset, required this.reason});

  final Asset asset;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final band = HealthBand.of(asset.healthScore);
    return InkWell(
      onTap: () => context.push(Routes.assetDetail(asset.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            _AssetThumb(asset: asset),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.id, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.red),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          reason,
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
            StatusChip('${asset.healthScore}%', tone: _bandTone(band)),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AssetThumb extends StatelessWidget {
  const _AssetThumb({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) => asset.imagePath == null
      ? IconSquare(icon: assetIcon(asset), tone: TileTone.pink, size: 44)
      : ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            asset.imagePath!,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => IconSquare(icon: assetIcon(asset), tone: TileTone.pink, size: 44),
          ),
        );
}

/// By Asset Type / By Location: one row per group with a stacked Healthy / Warning / Critical bar.
class _GroupList extends StatelessWidget {
  const _GroupList({required this.stats, required this.byType});

  final List<AssetGroupStat> stats;
  final bool byType;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const EmptyState(icon: Icons.inbox_outlined, title: 'No assets');
    final max = stats.fold(0, (m, s) => s.total > m ? s.total : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeriesLegend(items: [for (final b in HealthBand.values) (b.label, healthBandColors[b]!)]),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: () => context.push(
                    byType ? Routes.assetsWithType(stats[i].name) : Routes.assetsWithLocation(stats[i].name),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        IconSquare(
                          icon: byType ? assetTypeIcon(stats[i].name) : Icons.location_city_rounded,
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
                                      stats[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.bodyStrong.copyWith(fontSize: 13),
                                    ),
                                  ),
                                  Text(_n.format(stats[i].total), style: AppText.bodyStrong.copyWith(fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              StackedMiniBar(
                                values: [for (final b in HealthBand.values) stats[i].count(b)],
                                colors: [for (final b in HealthBand.values) healthBandColors[b]!],
                                fraction: max == 0 ? 0 : stats[i].total / max,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [for (final b in HealthBand.values) _n.format(stats[i].count(b))].join(' · '),
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
