import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock/demo_ids.dart';
import '../../data/repositories/session_repository.dart';
import '../../features/assets/asset_detail_screen.dart';
import '../../features/assets/assets_list_screen.dart';
import '../../features/auth/authenticator_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/common/coming_soon_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/my_approvals_screen.dart';
import '../../features/home/my_tasks_screen.dart';
import '../../features/maintenance/create_work_order_screen.dart';
import '../../features/maintenance/maintenance_calendar_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/registration/register_asset_screen.dart';
import '../../features/registration/registration_hub_screen.dart';
import '../../features/registration/registration_widgets.dart';
import '../../features/settings/data_check_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/work/work_hub_screen.dart';
import 'main_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the session changes (sign-in, logout).
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final onAuth = Routes.authRoutes.contains(loc);
      if (!session.loggedIn) {
        if (loc == Routes.authenticator && !session.passwordVerified) return Routes.login;
        return onAuth ? null : Routes.login;
      }
      // Signed in: the sign-in screens are no longer reachable.
      if (onAuth && loc != Routes.splash) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, pageBuilder: (_, state) => _fade(state, const LoginScreen())),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.authenticator, builder: (_, _) => const AuthenticatorScreen()),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) => _fade(state, MainShell(navigationShell: shell)),
        branches: [
          _branch(_homeRoute()),
          _branch(_assetsRoute()),
          _branch(_scanRoute()),
          _branch(_workRoute()),
          _branch(_moreRoute()),
        ],
      ),
    ],
  );
});

/// Smooth cross-fade (splash → login, authenticator → home).
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 450),
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);

StatefulShellBranch _branch(GoRoute root) => StatefulShellBranch(routes: [root]);

/// Placeholder route; later prompts swap the builder for the real screen.
GoRoute _soon(
  String path,
  String title,
  String subtitle,
  int prompt, {
  List<ScreenLink> links = const [],
  List<RouteBase> routes = const [],
}) {
  return GoRoute(
    path: path,
    builder: (_, state) => ComingSoonScreen(
      title: title,
      subtitle: subtitle,
      prompt: prompt,
      links: links,
      filter: state.uri.query.isEmpty ? null : Uri.decodeComponent(state.uri.query),
    ),
    routes: routes,
  );
}

/// Placeholder for a detail route whose title is the ID in the path.
GoRoute _soonDetail(String path, String param, String subtitle, int prompt) {
  return GoRoute(
    path: path,
    builder: (_, state) => ComingSoonScreen(title: state.pathParameters[param]!, subtitle: subtitle, prompt: prompt),
  );
}

/// Notifications and Profile exist under every tab, so the header bell and
/// avatar open them without switching tabs.
List<RouteBase> _shared() => [
  _soon(
    Routes.notificationsSegment,
    'Notifications',
    'Stay updated with alerts and messages',
    13,
    links: [const ScreenLink('Alerts & Notifications', Routes.alerts, icon: Icons.notifications_active_outlined)],
  ),
  _soon(
    Routes.profileSegment,
    'Profile',
    'Your details, role and password',
    19,
    links: const [
      ScreenLink('Settings', Routes.settings, icon: Icons.settings_outlined),
      ScreenLink('Help & Support', Routes.help, icon: Icons.help_outline_rounded),
    ],
  ),
];

GoRoute _homeRoute() => GoRoute(
  path: Routes.home,
  builder: (_, _) => const HomeScreen(),
  routes: [
    GoRoute(path: 'approvals', builder: (_, _) => const MyApprovalsScreen()),
    GoRoute(
      path: 'tasks',
      builder: (_, state) => MyTasksScreen(initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0),
    ),
    ..._shared(),
  ],
);

GoRoute _assetsRoute() => GoRoute(
  path: Routes.assets,
  builder: (_, state) => AssetsListScreen(initialStatus: state.uri.queryParameters['status']),
  routes: [
    GoRoute(
      path: 'detail/:assetId',
      builder: (_, state) => AssetDetailScreen(assetId: state.pathParameters['assetId']!),
    ),
    ..._shared(),
  ],
);

GoRoute _scanRoute() => _soon(
  Routes.scan,
  'Scan & Identify',
  'Scan QR code, barcode, NFC / RFID or BLE',
  7,
  links: [
    ScreenLink(
      'Asset Identified (${DemoIds.scannedAsset})',
      Routes.scanResult(DemoIds.scannedAsset),
      icon: Icons.qr_code_2_rounded,
    ),
    const ScreenLink('Scan History', Routes.scanHistory, icon: Icons.history_rounded),
  ],
  routes: [
    _soonDetail('result/:assetId', 'assetId', 'Asset Identified', 7),
    _soon('history', 'Scan History', 'Your recent scans', 7),
    ..._shared(),
  ],
);

GoRoute _workRoute() => GoRoute(
  path: Routes.work,
  builder: (_, _) => const WorkHubScreen(),
  routes: [
    _soon(
      'maintenance',
      'Maintenance',
      'Manage work orders, preventive maintenance and asset service',
      10,
      links: [
        ScreenLink(
          'Work order ${DemoIds.workOrder}',
          Routes.workOrder(DemoIds.workOrder),
          icon: Icons.assignment_outlined,
        ),
        const ScreenLink('Maintenance Calendar', Routes.maintenanceCalendar, icon: Icons.calendar_month_outlined),
      ],
      routes: [
        _soonDetail('orders/:woId', 'woId', 'Work order detail', 10),
        GoRoute(path: 'calendar', builder: (_, _) => const MaintenanceCalendarScreen()),
        GoRoute(
          path: 'new',
          builder: (_, state) => CreateWorkOrderScreen(assetId: state.uri.queryParameters['asset']),
        ),
      ],
    ),
    _soon(
      'inspection',
      'Inspection',
      'Conduct inspections, checklists and compliance',
      11,
      links: [
        ScreenLink(
          'Inspection ${DemoIds.inspection}',
          Routes.inspectionDetail(DemoIds.inspection),
          icon: Icons.fact_check_outlined,
        ),
      ],
      routes: [
        _soonDetail('detail/:id', 'id', 'Inspection checklist', 11),
        _soon('new', 'Create Inspection', 'Pick a checklist, inspector and due date', 11),
      ],
    ),
    _soon(
      'issues',
      'Issues / Defects',
      'Report, track and resolve asset issues',
      12,
      links: [
        const ScreenLink('Report Issue / Defect', Routes.reportIssue, icon: Icons.add_alert_outlined),
        ScreenLink('Issue ${DemoIds.issue}', Routes.issueDetail(DemoIds.issue), icon: Icons.report_outlined),
      ],
      routes: [
        _soon('report', 'Report Issue / Defect', 'Describe the problem and attach evidence', 12),
        _soonDetail('detail/:id', 'id', 'Issue detail', 12),
      ],
    ),
    _soon(
      'wip',
      'WIP / Operations',
      'Track production orders and units through each station',
      15,
      links: [
        ScreenLink(
          'WIP unit ${DemoIds.wipUnit}',
          Routes.wipUnit(DemoIds.wipUnit),
          icon: Icons.precision_manufacturing_outlined,
        ),
        ScreenLink(
          'Production order ${DemoIds.productionOrder}',
          Routes.productionOrder(DemoIds.productionOrder),
          icon: Icons.receipt_long_outlined,
        ),
      ],
      routes: [
        _soonDetail('unit/:unitId', 'unitId', 'WIP Tracking', 15),
        _soonDetail('order/:moId', 'moId', 'Production Order', 15),
      ],
    ),
    _soon(
      'movement',
      'Movement & Custody',
      'Transfer, assign and track asset movement',
      9,
      links: const [
        ScreenLink('Transfer Asset', Routes.transferAsset, icon: Icons.swap_horiz_rounded),
        ScreenLink('Movement History', Routes.movementHistory, icon: Icons.history_rounded),
      ],
      routes: [
        _soon('transfer', 'Transfer Asset', 'Move asset from one location or custodian to another', 9),
        _soon('history', 'Movement History', 'All transfers, check-outs and check-ins', 9),
      ],
    ),
    _soon(
      'audit',
      'Asset Audit',
      'Verify assets physically against the register',
      17,
      links: [
        ScreenLink(
          'Audit session ${DemoIds.audit}',
          Routes.auditSession(DemoIds.audit),
          icon: Icons.view_in_ar_rounded,
        ),
      ],
      routes: [_soonDetail('session/:id', 'id', 'Audit session', 17)],
    ),
    ..._shared(),
  ],
);

GoRoute _moreRoute() => GoRoute(
  path: Routes.more,
  builder: (_, _) => const MoreScreen(),
  routes: [
    _soon(
      'tracking',
      'Tracking & IoT',
      'Real-time location, sensors and telemetry',
      8,
      links: [
        ScreenLink(
          'Asset Tracking (${DemoIds.trackedAsset})',
          Routes.trackAsset(DemoIds.trackedAsset),
          icon: Icons.location_on_outlined,
        ),
      ],
      routes: [_soonDetail('asset/:assetId', 'assetId', 'Asset Tracking', 8)],
    ),
    _soon(
      'inventory',
      'Inventory / Spare Parts',
      'Manage stock, spare parts and consumables',
      14,
      links: [
        ScreenLink('Part ${DemoIds.part}', Routes.partDetail(DemoIds.part), icon: Icons.settings_outlined),
        const ScreenLink('Stock Movement', Routes.stockMovement, icon: Icons.sync_alt_rounded),
      ],
      routes: [
        _soonDetail('part/:partId', 'partId', 'Part Details', 14),
        _soon('stock-movement', 'Stock Movement', 'Receipts, issues and transfers', 14),
      ],
    ),
    _soon(
      'documents',
      'Documents',
      'Manuals, certificates, warranties and reports',
      16,
      links: [
        const ScreenLink('Add Document', Routes.addDocument, icon: Icons.upload_file_outlined),
        ScreenLink(
          'Document ${DemoIds.document}',
          Routes.documentDetail(DemoIds.document),
          icon: Icons.description_outlined,
        ),
      ],
      routes: [
        _soon('add', 'Add Document', 'Upload and link a document to an asset', 16),
        _soonDetail('detail/:id', 'id', 'Document Details', 16),
      ],
    ),
    GoRoute(
      path: 'registration',
      builder: (_, _) => const RegistrationHubScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, state) => RegisterAssetScreen(prefill: state.extra as RegistrationPrefill?),
        ),
        GoRoute(path: 'bulk', builder: (_, _) => const RegistrationHubScreen(bulk: true)),
      ],
    ),
    _soon(
      'alerts',
      'Alerts & Notifications',
      'Monitor alarms, thresholds and messages',
      13,
      links: [
        ScreenLink('Alert ${DemoIds.alert}', Routes.alertDetail(DemoIds.alert), icon: Icons.battery_alert_rounded),
        ScreenLink('Notifications', Routes.notificationsFrom(Routes.more), icon: Icons.notifications_none_rounded),
      ],
      routes: [_soonDetail('detail/:id', 'id', 'Alert Details', 13)],
    ),
    _soon(
      'sync',
      'Offline Sync',
      'Work offline and sync your changes later',
      18,
      links: const [
        ScreenLink('Pending Sync', Routes.pendingSync, icon: Icons.pending_actions_outlined),
        ScreenLink('Syncing Data', Routes.syncProgress, icon: Icons.cloud_sync_outlined),
      ],
      routes: [
        _soon('pending', 'Pending Sync', 'Changes waiting to be uploaded', 18),
        _soon('progress', 'Syncing Data', 'Uploading your offline changes', 18),
      ],
    ),
    GoRoute(
      path: 'settings',
      builder: (_, _) => const SettingsScreen(),
      routes: [GoRoute(path: 'data-check', builder: (_, _) => const DataCheckScreen())],
    ),
    _soon('help', 'Help & Support', 'FAQs, contact support and report a bug', 19),
    ..._shared(),
  ],
);
