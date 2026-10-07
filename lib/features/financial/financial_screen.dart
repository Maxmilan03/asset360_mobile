import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/asset.dart';
import '../../data/repositories/assets_repository.dart';
import '../assets/asset_ui.dart';
import '../home/home_screen.dart' show CostSummaryCard;

/// Value, book value and depreciation of one category.
class _CategoryValue {
  _CategoryValue(this.category);

  final String category;
  int count = 0;
  double cost = 0, book = 0;

  double get depreciation => cost - book;
  double get depreciatedPct => cost == 0 ? 0 : depreciation / cost;
}

/// Financial: org cost summary, asset value and depreciation per category, costliest assets.
class FinancialScreen extends ConsumerWidget {
  const FinancialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final assets = ref.watch(assetsProvider);
    final byCategory = <String, _CategoryValue>{};
    for (final a in assets) {
      final v = byCategory.putIfAbsent(a.category, () => _CategoryValue(a.category));
      v.count++;
      v.cost += a.purchaseCost;
      v.book += a.bookValue;
    }
    final categories = byCategory.values.toList()..sort((a, b) => b.cost.compareTo(a.cost));
    final totalCost = categories.fold<double>(0, (s, c) => s + c.cost);
    final totalBook = categories.fold<double>(0, (s, c) => s + c.book);
    final top = [...assets]..sort((a, b) => b.tco.compareTo(a.tco));

    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Financial',
            subtitle: 'Costs, asset value and depreciation',
            help:
                'The cost summary is the organisation-wide figure shown on Home. Asset value, depreciation '
                '(straight-line) and TCO are worked out from the detailed asset records.',
          ),
          const SizedBox(height: 14),
          const CostSummaryCard(),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: .82,
            children: [
              KpiTile(
                icon: Icons.shopping_cart_outlined,
                value: compactMoney(totalCost),
                label: 'Asset Value',
                caption: 'at purchase',
                tone: TileTone.lavender,
              ),
              KpiTile(
                icon: Icons.account_balance_wallet_outlined,
                value: compactMoney(totalBook),
                label: 'Book Value',
                caption: DemoClock.formatShort(DemoClock.now),
                tone: TileTone.sky,
              ),
              KpiTile(
                icon: Icons.trending_down_rounded,
                value: compactMoney(totalCost - totalBook),
                label: 'Depreciation',
                caption: '${totalCost == 0 ? 0 : ((totalCost - totalBook) / totalCost * 100).round()}% written off',
                tone: TileTone.peach,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Based on ${assets.length} detailed asset records', style: AppText.caption),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Value by Category',
            child: LoadingGate(
              rows: 3,
              card: false,
              child: categories.isEmpty
                  ? const EmptyState(icon: Icons.category_outlined, title: 'No assets with a cost yet')
                  : Column(
                      children: [
                        for (final c in categories)
                          _CategoryRow(
                            value: c,
                            onTap: () => _showCategory(context, c, assets.where((a) => a.category == c.category)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Top 5 Costliest Assets (TCO)',
            child: LoadingGate(
              rows: 5,
              card: false,
              child: top.isEmpty
                  ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No assets yet')
                  : Column(
                      children: [for (final (i, a) in top.take(5).indexed) _TopRow(rank: i + 1, asset: a)],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "AED 1.9M", "AED 482K".
String compactMoney(double v) {
  if (v >= 1e6) return 'AED ${(v / 1e6).toStringAsFixed(v >= 1e7 ? 0 : 1)}M';
  if (v >= 1e3) return 'AED ${(v / 1e3).round()}K';
  return 'AED ${v.round()}';
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.rank, required this.asset});

  final int rank;
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(Routes.assetDetail(asset.id, tab: 'financial')),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                '$rank',
                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13),
                  ),
                  Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                ],
              ),
            ),
            Text(formatAed(asset.tco), style: AppText.bodyStrong.copyWith(fontSize: 13, color: AppColors.primary)),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.value, required this.onTap});

  final _CategoryValue value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${c.category} (${c.count})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatAed(c.cost), style: AppText.bodyStrong.copyWith(fontSize: 13)),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.depreciatedPct,
                minHeight: 7,
                color: AppColors.iconOrange,
                backgroundColor: AppColors.tileSky,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Book ${formatAed(c.book)} · depreciation ${formatAed(c.depreciation)} '
              '(${(c.depreciatedPct * 100).round()}%)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// Category breakdown sheet: every asset of the category with purchase and book value.
Future<void> _showCategory(BuildContext context, _CategoryValue c, Iterable<Asset> assets) {
  final list = assets.toList()..sort((a, b) => b.purchaseCost.compareTo(a.purchaseCost));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .75),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SheetTitle(
                c.category,
                subtitle: '${c.count} assets · value ${formatAed(c.cost)} · book ${formatAed(c.book)}',
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final a = list[i];
                  return ListTile(
                    leading: AssetThumb(imagePath: a.imagePath, fallbackIcon: assetIcon(a), size: 40),
                    title: Text(a.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                    subtitle: Text(
                      '${a.name} · book ${formatAed(a.bookValue)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                    trailing: Text(formatAed(a.purchaseCost), style: AppText.bodyStrong.copyWith(fontSize: 13)),
                    onTap: () {
                      Navigator.pop(sheet);
                      context.push(Routes.assetDetail(a.id, tab: 'financial'));
                    },
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
