import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/home_repository.dart';

/// What a quick-action ID looks like and where it goes.
class QuickActionDef {
  const QuickActionDef(this.label, this.icon, this.tone, this.route);

  final String label;
  final IconData icon;
  final TileTone tone;
  final String route;
}

final quickActionDefs = <String, QuickActionDef>{
  'scan': const QuickActionDef('Scan Asset', Icons.qr_code_scanner_rounded, TileTone.lavender, Routes.scan),
  'reportIssue': const QuickActionDef('Report Issue', Icons.build_rounded, TileTone.sky, Routes.reportIssue),
  'moveAsset': const QuickActionDef('Move Asset', Icons.swap_horiz_rounded, TileTone.mint, Routes.transferAsset),
  'createWorkOrder': QuickActionDef('Create Work Order', Icons.edit_document, TileTone.peach, Routes.createWorkOrder()),
  'startInspection': const QuickActionDef(
    'Start Inspection',
    Icons.check_box_rounded,
    TileTone.pink,
    Routes.inspection,
  ),
  'assetAudit': const QuickActionDef('Asset Audit', Icons.view_in_ar_rounded, TileTone.lavender, Routes.audit),
  'inventoryIssue': const QuickActionDef('Inventory Issue', Icons.inventory_2_rounded, TileTone.cyan, Routes.inventory),
  'registerAsset': const QuickActionDef('Register Asset', Icons.add_box_outlined, TileTone.mint, Routes.registration),
  'trackAsset': const QuickActionDef('Track Asset', Icons.location_on_outlined, TileTone.sky, Routes.tracking),
  'documents': const QuickActionDef('Documents', Icons.description_outlined, TileTone.lavender, Routes.documents),
  'offlineSync': const QuickActionDef('Offline Sync', Icons.cloud_sync_outlined, TileTone.cyan, Routes.offlineSync),
};

/// The rest of the modules, shown by "More Actions".
const _moreModules = [
  ('Maintenance', Icons.build_circle_outlined, TileTone.lavender, Routes.maintenance),
  ('Inspection', Icons.fact_check_outlined, TileTone.mint, Routes.inspection),
  ('Issues', Icons.warning_amber_rounded, TileTone.pink, Routes.issues),
  ('WIP / Ops', Icons.precision_manufacturing_outlined, TileTone.sky, Routes.wip),
  ('Movement', Icons.swap_horiz_rounded, TileTone.peach, Routes.movement),
  ('Tracking & IoT', Icons.location_on_outlined, TileTone.sky, Routes.tracking),
  ('Inventory', Icons.inventory_2_outlined, TileTone.cyan, Routes.inventory),
  ('Documents', Icons.description_outlined, TileTone.lavender, Routes.documents),
  ('Registration', Icons.add_box_outlined, TileTone.mint, Routes.registration),
  ('Alerts', Icons.notifications_active_outlined, TileTone.pink, Routes.alerts),
  ('Offline Sync', Icons.cloud_sync_outlined, TileTone.cyan, Routes.offlineSync),
  ('Scan History', Icons.history_rounded, TileTone.grey, Routes.scanHistory),
];

void openRoute(BuildContext context, String route) => context.go(route);

Future<void> showMoreActionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('More Actions', style: AppText.sectionTitle),
            const SizedBox(height: 12),
            GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .9,
              children: [
                for (final (label, icon, tone, route) in _moreModules)
                  ActionTile(
                    icon: icon,
                    label: label,
                    tone: tone,
                    onTap: () {
                      Navigator.pop(ctx);
                      openRoute(context, route);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Reorder and toggle quick actions (kept in memory).
Future<void> showCustomizeQuickActions(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CustomizeSheet(),
  );
}

class _CustomizeSheet extends ConsumerWidget {
  const _CustomizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(quickActionsProvider);
    final notifier = ref.read(quickActionsProvider.notifier);
    final enabled = actions.where((a) => a.enabled).length;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  const Expanded(child: Text('Customize Quick Actions', style: AppText.sectionTitle)),
                  TextButton(onPressed: notifier.reset, child: const Text('Reset')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Drag to reorder. The first $homeQuickActionSlots switched-on actions appear on Home '
                '($enabled on), followed by More Actions.',
                style: AppText.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: actions.length,
                onReorder: notifier.reorder,
                itemBuilder: (_, i) {
                  final a = actions[i];
                  final def = quickActionDefs[a.id]!;
                  return ListTile(
                    key: ValueKey(a.id),
                    leading: IconSquare(icon: def.icon, tone: def.tone, size: 38),
                    title: Text(def.label, style: AppText.bodyStrong),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: a.enabled,
                          activeTrackColor: AppColors.primary,
                          onChanged: (_) => notifier.toggle(a.id),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle_rounded, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
