import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';

/// What a quick-action ID looks like and where it goes.
class QuickActionDef {
  const QuickActionDef(this.label, this.icon, this.tone, this.route);

  final String label;
  final IconData icon;
  final TileTone tone;
  final String route;
}

final quickActionDefs = <String, QuickActionDef>{
  'scan': QuickActionDef('Scan Asset', Icons.qr_code_scanner_rounded, TileTone.lavender, Routes.scan),
  'reportIssue': QuickActionDef('Report Issue', Icons.build_rounded, TileTone.sky, Routes.reportIssue),
  'moveAsset': QuickActionDef('Move Asset', Icons.swap_horiz_rounded, TileTone.mint, Routes.transferAsset),
  'createWorkOrder': QuickActionDef('Create Work Order', Icons.edit_document, TileTone.peach, Routes.createWorkOrder()),
  'startInspection': QuickActionDef('Start Inspection', Icons.check_box_rounded, TileTone.pink, Routes.inspection),
  'assetAudit': QuickActionDef('Asset Audit', Icons.view_in_ar_rounded, TileTone.lavender, Routes.audit),
  'inventoryIssue': QuickActionDef('Inventory Issue', Icons.inventory_2_rounded, TileTone.cyan, Routes.inventory),
  'registerAsset': QuickActionDef('Register Asset', Icons.add_box_outlined, TileTone.mint, Routes.registration),
  'trackAsset': QuickActionDef('Track Asset', Icons.location_on_outlined, TileTone.sky, Routes.tracking),
  'documents': QuickActionDef('Documents', Icons.description_outlined, TileTone.lavender, Routes.documents),
  'offlineSync': QuickActionDef('Offline Sync', Icons.cloud_sync_outlined, TileTone.cyan, Routes.offlineSync),
};

/// The screen a quick-action route opens (the Scan markers resolve to Scan on Home).
String quickActionTarget(String route) => switch (route) {
  Routes.scan => Routes.scanFrom(Routes.home),
  Routes.scanHistory => Routes.scanHistoryFrom(Routes.home),
  _ => route,
};

/// Opens a quick-action / module route. Scan opens on top of the current screen.
void openRoute(BuildContext context, String route) {
  final here = GoRouterState.of(context).uri.path;
  if (route == Routes.scan) {
    context.push(Routes.scanFrom(here));
  } else if (route == Routes.scanHistory) {
    context.push(Routes.scanHistoryFrom(here));
  } else {
    context.go(route);
  }
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
                  Expanded(child: Text('Customize Quick Actions', style: AppText.sectionTitle)),
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
                          child: Padding(
                            padding: const EdgeInsets.all(8),
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
