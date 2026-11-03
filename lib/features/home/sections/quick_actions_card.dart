import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/features/assets/asset_actions.dart';
import 'package:asset360_mobile/features/home/quick_actions.dart';

class QuickActionsCard extends ConsumerWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(quickActionsProvider).where((a) => a.enabled).take(homeQuickActionSlots).toList();
    return SectionCard(
      title: 'Quick Actions',
      actionLabel: 'Customize',
      actionIcon: null,
      onAction: DemoGuard.tap(DemoAction.homeCustomize, () => showCustomizeQuickActions(context)),
      child: GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .95,
        children: [
          for (final a in shown)
            ActionTile(
              icon: quickActionDefs[a.id]!.icon,
              label: quickActionDefs[a.id]!.label,
              tone: quickActionDefs[a.id]!.tone,
              labelSize: 11.5,
              onTap: DemoGuard.open(
                quickActionTarget(quickActionDefs[a.id]!.route),
                () => openRoute(context, quickActionDefs[a.id]!.route),
              ),
            ),
          ActionTile(
            icon: Icons.more_horiz_rounded,
            label: 'More Actions',
            tone: TileTone.grey,
            labelSize: 11.5,
            onTap: DemoGuard.tap(DemoAction.homeMoreActions, () => openMoreActions(context)),
          ),
        ],
      ),
    );
  }
}
