import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/session_actions.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';

enum ModuleAction { go, profile, logout }

/// One tile of the All Modules sheet.
class ModuleDef {
  const ModuleDef(this.label, this.icon, this.color, this.route, {this.action = ModuleAction.go, this.prefix});

  final String label;
  final IconData icon;
  final Color color;
  final String route;
  final ModuleAction action;

  /// Location prefix that marks this module as current (defaults to [route]).
  final String? prefix;

  /// Whether the client demo allows the tile (client_demo.dart). Logout is always on.
  bool get enabled => switch (action) {
    ModuleAction.go => demoCanOpen(route),
    ModuleAction.profile => demoCanOpen(Routes.profileFrom(Routes.home)),
    ModuleAction.logout => true,
  };

  bool matches(String location) {
    if (action == ModuleAction.profile) return location.endsWith('/${Routes.profileSegment}');
    if (action == ModuleAction.logout) return false;
    final p = prefix ?? route;
    return location == p || location.startsWith('$p/');
  }
}

const allModules = [
  ModuleDef('Dashboard', Icons.dashboard_rounded, AppColors.iconViolet, Routes.home),
  ModuleDef('Assets', Icons.inventory_2_rounded, AppColors.iconBlue, Routes.assets),
  ModuleDef('Tracking & IoT', Icons.location_on_rounded, AppColors.iconTeal, Routes.tracking),
  ModuleDef('Movement & Custody', Icons.swap_horiz_rounded, AppColors.iconGreen, Routes.movement),
  ModuleDef('Maintenance', Icons.build_rounded, AppColors.iconOrange, Routes.maintenance),
  ModuleDef('Inspection', Icons.fact_check_rounded, AppColors.iconGreen, Routes.inspection),
  ModuleDef('Inventory', Icons.category_rounded, AppColors.iconBlue, Routes.inventory),
  ModuleDef('WIP / Operations', Icons.precision_manufacturing_rounded, AppColors.iconViolet, Routes.wip),
  ModuleDef('Audit & Compliance', Icons.verified_user_rounded, AppColors.iconTeal, Routes.audit),
  ModuleDef('Contracts & Warranty', Icons.handshake_rounded, AppColors.iconOrange, Routes.contracts),
  ModuleDef('Financial', Icons.account_balance_wallet_rounded, AppColors.iconGreen, Routes.financial),
  ModuleDef('Reports & Analytics', Icons.bar_chart_rounded, AppColors.iconBlue, Routes.reports),
  ModuleDef('Administration', Icons.admin_panel_settings_rounded, AppColors.iconViolet, Routes.admin),
];

const moreModules = [
  ModuleDef('Issues / Defects', Icons.warning_rounded, AppColors.iconRed, Routes.issues),
  ModuleDef('Alerts & Notifications', Icons.notifications_active_rounded, AppColors.iconOrange, Routes.alerts),
  ModuleDef('Documents', Icons.description_rounded, AppColors.iconBlue, Routes.documents),
  ModuleDef('Asset Registration', Icons.add_box_rounded, AppColors.iconGreen, Routes.registration),
  ModuleDef('Offline Sync', Icons.cloud_sync_rounded, AppColors.iconTeal, Routes.offlineSync),
  ModuleDef('Profile', Icons.person_rounded, AppColors.iconViolet, '', action: ModuleAction.profile),
  ModuleDef('Settings', Icons.settings_rounded, Color(0xFF5B5A74), Routes.settings),
  ModuleDef('Local Data', Icons.storage_rounded, AppColors.iconTeal, Routes.localData),
  ModuleDef('Help & Support', Icons.help_rounded, AppColors.iconBlue, Routes.help),
  ModuleDef('Logout', Icons.logout_rounded, AppColors.red, '', action: ModuleAction.logout),
];

/// Opens a tile's module: go to its route, push Profile on the current tab, or confirm Logout.
void openModule(BuildContext context, WidgetRef ref, ModuleDef m, {required String from}) {
  if (!m.enabled) return;
  switch (m.action) {
    case ModuleAction.go:
      GoRouter.of(context).go(m.route);
    case ModuleAction.profile:
      if (!from.endsWith('/${Routes.profileSegment}')) GoRouter.of(context).push(Routes.profileFrom(from));
    case ModuleAction.logout:
      confirmLogout(context, ref);
  }
}

/// The module that owns [location], if any (highlighted in the grid).
ModuleDef? currentModule(String location) {
  ModuleDef? best;
  for (final m in [...allModules, ...moreModules]) {
    if (!m.matches(location)) continue;
    if (best == null || (m.prefix ?? m.route).length > (best.prefix ?? best.route).length) best = m;
  }
  return best;
}

/// "All Modules" sheet opened by the bar's More button. Returns the tapped tile.
/// It is shown on the current tab's navigator, so the bar (and the Scan button) stays
/// visible and usable just below the sheet.
Future<ModuleDef?> showAllModulesSheet(BuildContext context, {required String location}) {
  return showModalBottomSheet<ModuleDef>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .82),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
              child: Row(
                children: [
                  Expanded(child: Text('All Modules', style: AppText.sectionTitle)),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: AllModulesGrid(location: location, onSelect: (m) => Navigator.pop(context, m)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Module grid + "More" section, shared by the sheet and the More tab page.
class AllModulesGrid extends ConsumerWidget {
  const AllModulesGrid({super.key, required this.location, required this.onSelect});

  final String location;
  final ValueChanged<ModuleDef> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = currentModule(location);
    final unread = ref.watch(unreadNotificationCountProvider);
    Widget grid(List<ModuleDef> mods) => GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.08,
      children: [
        for (final m in mods)
          _ModuleTile(
            module: m,
            selected: identical(m, current),
            badge: m.route == Routes.alerts ? unread : 0,
            onTap: m.enabled ? () => onSelect(m) : null,
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        grid(allModules),
        const SizedBox(height: 18),
        Text('More', style: AppText.sectionTitle),
        const SizedBox(height: 10),
        grid(moreModules),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, required this.selected, required this.onTap, this.badge = 0});

  final ModuleDef module;
  final bool selected;

  /// Null keeps the tile visible but inert (module switched off).
  final VoidCallback? onTap;
  final int badge;

  static const _selectedBg = Color(0xFFDCD0FC);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.tile);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? _selectedBg : AppColors.tileLavender,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.primary.withValues(alpha: .5) : Colors.transparent),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(module.icon, size: 28, color: selected ? AppColors.primary : module.color),
                      const SizedBox(height: 8),
                      Text(
                        module.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: module.action == ModuleAction.logout
                              ? AppColors.red
                              : selected
                              ? AppColors.primary
                              : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.badge, borderRadius: BorderRadius.circular(9)),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The More tab's own page (reached with Back from a module opened from the sheet).
class AllModulesScreen extends ConsumerWidget {
  const AllModulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'All Modules',
            subtitle: 'Every Asset360 module in one place',
            help: 'Tap a module to open it. The same list opens from the More button on every screen.',
          ),
          const SizedBox(height: 16),
          AllModulesGrid(
            location: Routes.more,
            onSelect: (m) => openModule(context, ref, m, from: Routes.more),
          ),
          const SizedBox(height: 18),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.data == null ? '' : ' v${snap.data!.version} (${snap.data!.buildNumber})';
              return Text('Purple IQ Asset360$v', textAlign: TextAlign.center, style: AppText.caption);
            },
          ),
        ],
      ),
    );
  }
}
