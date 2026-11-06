import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_detail_screen.dart';
import 'package:asset360_mobile/features/assets/assets_list_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_actions_screen.dart';
import 'package:asset360_mobile/features/auth/authenticator_screen.dart';
import 'package:asset360_mobile/features/auth/auth_diagnostics_screen.dart';
import 'package:asset360_mobile/features/auth/authenticator_setup_screen.dart';
import 'package:asset360_mobile/features/auth/forgot_password_screen.dart';
import 'package:asset360_mobile/features/auth/login_screen.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/more/documents/add_document_screen.dart';
import 'package:asset360_mobile/features/more/documents/document_detail_screen.dart';
import 'package:asset360_mobile/features/more/documents/document_viewer_screen.dart';
import 'package:asset360_mobile/features/more/documents/documents_screen.dart';
import 'package:asset360_mobile/features/more/account/help_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/activities_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/asset_health_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/asset_location_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/asset_overview_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/cost_summary_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/maintenance_performance_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/recent_alerts_screen.dart';
import 'package:asset360_mobile/features/home/drilldowns/recent_assets_screen.dart';
import 'package:asset360_mobile/features/home/home_screen.dart';
import 'package:asset360_mobile/features/more/account/profile_screen.dart';
import 'package:asset360_mobile/features/work/inspection/create_inspection_screen.dart';
import 'package:asset360_mobile/features/work/inspection/inspection_hub_screen.dart';
import 'package:asset360_mobile/features/work/inspection/inspection_screen.dart';
import 'package:asset360_mobile/features/work/issues/issue_detail_screen.dart';
import 'package:asset360_mobile/features/work/issues/issues_screen.dart';
import 'package:asset360_mobile/features/work/issues/report_issue_screen.dart';
import 'package:asset360_mobile/features/more/inventory/inventory_screen.dart';
import 'package:asset360_mobile/features/more/inventory/part_detail_screen.dart';
import 'package:asset360_mobile/features/more/inventory/procurement_screens.dart';
import 'package:asset360_mobile/features/more/inventory/stock_movement_screen.dart';
import 'package:asset360_mobile/features/home/my_approvals_screen.dart';
import 'package:asset360_mobile/features/home/my_tasks_screen.dart';
import 'package:asset360_mobile/features/work/maintenance/create_work_order_screen.dart';
import 'package:asset360_mobile/features/work/maintenance/maintenance_calendar_screen.dart';
import 'package:asset360_mobile/features/work/maintenance/maintenance_hub_screen.dart';
import 'package:asset360_mobile/features/work/maintenance/maintenance_lists.dart';
import 'package:asset360_mobile/features/work/maintenance/work_order_screen.dart';
import 'package:asset360_mobile/features/more/account/admin_screen.dart';
import 'package:asset360_mobile/features/more/alerts/alert_detail_screen.dart';
import 'package:asset360_mobile/features/more/alerts/alerts_screen.dart';
import 'package:asset360_mobile/features/more/alerts/notifications_screen.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/features/work/audit/asset_audit_screen.dart';
import 'package:asset360_mobile/features/work/audit/audit_asset_screen.dart';
import 'package:asset360_mobile/features/work/audit/audit_pages.dart';
import 'package:asset360_mobile/features/work/audit/audit_session_screen.dart';
import 'package:asset360_mobile/features/work/audit/compliance_screen.dart';
import 'package:asset360_mobile/features/more/insights/contracts_warranty_screen.dart';
import 'package:asset360_mobile/features/more/insights/financial_screen.dart';
import 'package:asset360_mobile/features/more/all_modules.dart';
import 'package:asset360_mobile/features/work/movement/custody_screen.dart';
import 'package:asset360_mobile/features/work/movement/movement_hub_screen.dart';
import 'package:asset360_mobile/features/work/movement/movement_pages.dart';
import 'package:asset360_mobile/features/work/movement/transfer_asset_screen.dart';
import 'package:asset360_mobile/features/assets/live/live_assignment_screens.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart' show AppScaffold, NotAvailableYet;
import 'package:asset360_mobile/features/more/insights/reports_screen.dart';
import 'package:asset360_mobile/features/more/registration/register_asset_screen.dart';
import 'package:asset360_mobile/features/more/registration/registration_hub_screen.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';
import 'package:asset360_mobile/features/more/sync/offline_sync_screen.dart';
import 'package:asset360_mobile/features/more/sync/pending_sync_screen.dart';
import 'package:asset360_mobile/features/more/sync/syncing_screen.dart';
import 'package:asset360_mobile/features/more/account/data_check_screen.dart';
import 'package:asset360_mobile/features/more/tracking/asset_tracking_screen.dart';
import 'package:asset360_mobile/features/more/tracking/telemetry_view.dart';
import 'package:asset360_mobile/features/more/tracking/tracking_hub_screen.dart';
import 'package:asset360_mobile/features/more/tracking/tracking_pages.dart';
import 'package:asset360_mobile/features/more/account/demo_tags_screen.dart';
import 'package:asset360_mobile/features/more/account/scanner_settings_screen.dart';
import 'package:asset360_mobile/features/more/account/settings_screen.dart';
import 'package:asset360_mobile/features/more/local_data/local_data_screen.dart';
import 'package:asset360_mobile/features/assets/scan/scan_history_screen.dart';
import 'package:asset360_mobile/features/assets/scan/scan_result_screen.dart';
import 'package:asset360_mobile/features/assets/scan/scan_screen.dart';
import 'package:asset360_mobile/features/work/wip/production_order_screen.dart';
import 'package:asset360_mobile/features/work/wip/wip_hub_screen.dart';
import 'package:asset360_mobile/features/work/wip/wip_unit_screen.dart';
import 'package:asset360_mobile/features/work/work_hub_screen.dart';
import 'package:asset360_mobile/app/client_demo.dart';
import 'package:asset360_mobile/app/router/main_shell.dart';
import 'package:asset360_mobile/app/router/routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Unregistered location used to refuse a screen the client demo does not allow.
const _demoBlocked = '/demo-blocked';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the session changes (sign-in, logout).
  final refresh = ValueNotifier<int>(0);
  // One navigator per tab. Every signed-in screen, sheet and dialog lives on these,
  // under the bottom bar, so the bar and the Scan button are always visible.
  final branchKeys = [
    for (final name in ['home', 'assets', 'work', 'more']) GlobalKey<NavigatorState>(debugLabel: name),
  ];
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    // A location no route matches (a screen left out by the client demo) is
    // ignored: go_router keeps the current screen.
    onException: (_, state, _) => debugPrint('Ignored navigation to ${state.uri}'),
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final onAuth = Routes.authRoutes.contains(loc);
      if (!session.loggedIn) {
        if ((loc == Routes.authenticator || loc == Routes.authenticatorSetup) && !session.passwordVerified) {
          return Routes.login;
        }
        return onAuth ? null : Routes.login;
      }
      // Bare /scan… (no tab) opens Scan on the Home tab.
      if (loc == Routes.scan || loc.startsWith('${Routes.scan}/')) {
        return demoCanOpen('${Routes.home}$loc') ? '${Routes.home}$loc' : _demoBlocked;
      }
      // Client demo safety net: a screen that is not allowed is never opened. It is
      // not registered, and this unregistered target lands in onException (stay put).
      if (!demoCanOpen(state.uri.path)) return _demoBlocked;
      // Signed in: the sign-in screens are no longer reachable.
      if (onAuth && loc != Routes.splash) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, pageBuilder: (_, state) => _fade(state, const LoginScreen())),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.authenticator, builder: (_, _) => const AuthenticatorScreen()),
      GoRoute(path: Routes.authenticatorSetup, builder: (_, _) => const AuthenticatorSetupScreen()),
      GoRoute(path: Routes.authDiagnostics, builder: (_, _) => const AuthDiagnosticsScreen()),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) =>
            _fade(state, MainShell(navigationShell: shell, location: state.uri.path, branchKeys: branchKeys)),
        branches: [
          // Client demo: only the allowed screens are registered (demoRoutes).
          for (final (i, root) in [_homeRoute(), _assetsRoute(), _workRoute(), _moreRoute()].indexed)
            StatefulShellBranch(navigatorKey: branchKeys[i], routes: demoRoutes([root])),
        ],
      ),
    ],
  );
});

/// [routes] without the screens the client demo does not allow (lib/app/client_demo.dart):
/// a route is kept when its full path is in `kDemoScreens`, and its children are
/// filtered the same way. With the demo off the routes are returned unchanged.
@visibleForTesting
List<RouteBase> demoRoutes(List<RouteBase> routes, [String parent = '']) {
  if (!clientDemoActive) return routes;
  return [
    for (final r in routes)
      if (r is GoRoute)
        for (final full in [r.path.startsWith('/') ? r.path : '${parent == '/' ? '' : parent}/${r.path}'])
          if (demoScreenFor(full) != null)
            GoRoute(
              path: r.path,
              name: r.name,
              builder: r.builder,
              pageBuilder: r.pageBuilder,
              redirect: r.redirect,
              parentNavigatorKey: r.parentNavigatorKey,
              routes: demoRoutes(r.routes, full),
            ),
  ];
}

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

/// Notifications, Profile, Scan and More Actions exist under every tab, so the header bell,
/// avatar, the centre Scan button and asset actions open them without switching tabs.
List<RouteBase> _shared() => [
  GoRoute(
    path: Routes.notificationsSegment,
    builder: (_, _) => const NotificationsScreen(),
    routes: [GoRoute(path: 'settings', builder: (_, _) => const NotificationSettingsScreen())],
  ),
  GoRoute(path: Routes.profileSegment, builder: (_, _) => const ProfileScreen()),
  GoRoute(
    path: Routes.scanSegment,
    builder: (_, _) => const ScanScreen(),
    routes: [
      GoRoute(
        path: 'result/:assetId',
        builder: (_, state) => ScanResultScreen(assetId: state.pathParameters['assetId']!),
      ),
      GoRoute(path: 'history', builder: (_, _) => const ScanHistoryScreen()),
    ],
  ),
  GoRoute(
    path: Routes.moreActionsSegment,
    builder: (_, state) => MoreActionsScreen(assetId: state.uri.queryParameters['asset']),
    routes: [
      GoRoute(
        path: ':action',
        builder: (_, state) => moreActionScreen(state.pathParameters['action']!, state.uri.queryParameters['asset']),
      ),
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
    // Drill-downs of the Home cards (not in the client demo allow-list).
    GoRoute(path: 'asset-overview', builder: (_, _) => const AssetOverviewScreen()),
    GoRoute(path: 'maintenance-performance', builder: (_, _) => const MaintenancePerformanceScreen()),
    GoRoute(
      path: 'activities',
      builder: (_, state) => ActivitiesScreen(calendar: state.uri.queryParameters['view'] == 'calendar'),
    ),
    GoRoute(path: 'recent-alerts', builder: (_, _) => const RecentAlertsScreen()),
    GoRoute(path: 'asset-location', builder: (_, _) => const AssetLocationScreen()),
    GoRoute(path: 'asset-health', builder: (_, _) => const AssetHealthScreen()),
    GoRoute(path: 'cost-summary', builder: (_, _) => const CostSummaryScreen()),
    GoRoute(path: 'recent-assets', builder: (_, _) => const RecentAssetsScreen()),
    ..._shared(),
  ],
);

GoRoute _assetsRoute() => GoRoute(
  path: Routes.assets,
  builder: (_, state) => AssetsListScreen(
    initialStatus: state.uri.queryParameters['status'],
    initialType: state.uri.queryParameters['type'],
    initialLocation: state.uri.queryParameters['location'],
  ),
  routes: [
    GoRoute(
      path: 'detail/:assetId',
      builder: (_, state) =>
          AssetDetailScreen(assetId: state.pathParameters['assetId']!, initialTab: state.uri.queryParameters['tab']),
    ),
    ..._shared(),
  ],
);

GoRoute _workRoute() => GoRoute(
  path: Routes.work,
  builder: (_, _) => const WorkHubScreen(),
  routes: [
    GoRoute(
      path: 'maintenance',
      builder: (_, state) => MaintenanceHubScreen(initialTab: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'orders/:woId',
          builder: (_, state) =>
              WorkOrderScreen(woId: state.pathParameters['woId']!, initialTab: state.uri.queryParameters['tab']),
        ),
        GoRoute(path: 'calendar', builder: (_, _) => const MaintenanceCalendarScreen()),
        GoRoute(
          path: 'new',
          builder: (_, state) =>
              CreateWorkOrderScreen(assetId: state.uri.queryParameters['asset'], prefill: state.extra as WoPrefill?),
        ),
        GoRoute(path: 'pm', builder: (_, _) => const PmSchedulesScreen()),
        GoRoute(path: 'breakdowns', builder: (_, _) => const WoListScreen.breakdowns()),
        GoRoute(path: 'service-history', builder: (_, _) => const WoListScreen.history()),
      ],
    ),
    GoRoute(
      path: 'inspection',
      builder: (_, state) => InspectionHubScreen(initialView: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'detail/:id',
          builder: (_, state) =>
              InspectionScreen(id: state.pathParameters['id']!, initialTab: state.uri.queryParameters['tab']),
        ),
        GoRoute(
          path: 'new',
          builder: (_, state) => CreateInspectionScreen(assetId: state.uri.queryParameters['asset']),
        ),
        GoRoute(
          path: 'findings',
          builder: (_, _) => const FindingsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => FindingDetailScreen(id: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: 'issues',
      builder: (_, state) => IssuesScreen(initialTab: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'report',
          builder: (_, state) => ReportIssueScreen(assetId: state.uri.queryParameters['asset']),
        ),
        GoRoute(
          path: 'detail/:id',
          builder: (_, state) =>
              IssueDetailScreen(id: state.pathParameters['id']!, initialTab: state.uri.queryParameters['tab']),
        ),
      ],
    ),
    GoRoute(
      path: 'wip',
      builder: (_, state) => WipHubScreen(initialView: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'unit/:unitId',
          builder: (_, state) => WipUnitScreen(serial: state.pathParameters['unitId']!),
        ),
        GoRoute(
          path: 'order/:moId',
          builder: (_, state) => ProductionOrderScreen(id: state.pathParameters['moId']!),
        ),
      ],
    ),
    GoRoute(
      path: 'movement',
      builder: (_, state) => MovementHubScreen(initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '')),
      routes: [
        GoRoute(
          path: 'transfer',
          // API mode: Move with the Master Data location pickers (no move endpoint yet).
          builder: (_, state) => apiMode
              ? LiveMoveScreen(assetId: state.uri.queryParameters['asset'])
              : TransferAssetScreen(
                  assetIds: [
                    ?state.uri.queryParameters['asset'],
                    ...?state.uri.queryParameters['assets']?.split(',').where((s) => s.isNotEmpty),
                  ],
                ),
        ),
        GoRoute(path: 'history', builder: (_, _) => const MovementHistoryScreen()),
        GoRoute(
          path: 'request/:id',
          builder: (_, state) => MovementRequestScreen(id: state.pathParameters['id']!),
        ),
        for (final (path, action) in [
          ('check-out', CustodyAction.checkOut),
          ('check-in', CustodyAction.checkIn),
          ('assign', CustodyAction.assign),
          ('return', CustodyAction.returnAsset),
        ])
          GoRoute(
            path: path,
            // API mode: Check Out / Assign post an Asset-service assignment with a Master Data
            // employee; Check In / Return are not available yet.
            builder: (_, state) {
              final asset = state.uri.queryParameters['asset'];
              if (!apiMode) return CustodyScreen(action: action, assetId: asset);
              return switch (action) {
                CustodyAction.checkOut => LiveCheckInOutScreen(assetId: asset),
                CustodyAction.assign => LiveAssignCustodianScreen(assetId: asset),
                _ => AppScaffold(body: NotAvailableYet(feature: action.title)),
              };
            },
          ),
      ],
    ),
    GoRoute(
      path: 'audit',
      builder: (_, state) => AssetAuditScreen(initialTab: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(path: 'new', builder: (_, _) => const CreateAuditScreen()),
        GoRoute(path: 'compliance', builder: (_, _) => const ComplianceScreen()),
        GoRoute(
          path: 'session/:id',
          builder: (_, state) => AuditSessionScreen(id: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'asset/:assetId',
              builder: (_, state) => AuditAssetScreen(
                auditId: state.pathParameters['id']!,
                assetId: state.pathParameters['assetId']!,
                method: state.uri.queryParameters['method'],
              ),
            ),
            GoRoute(
              path: 'results',
              builder: (_, state) => AuditResultsScreen(
                id: state.pathParameters['id']!,
                result: state.uri.queryParameters['result'] ?? AuditResult.verified,
              ),
            ),
            GoRoute(
              path: 'report',
              builder: (_, state) => AuditReportScreen(id: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
    ..._shared(),
  ],
);

GoRoute _moreRoute() => GoRoute(
  path: Routes.more,
  builder: (_, _) => const AllModulesScreen(),
  routes: [
    GoRoute(path: 'local-data', builder: (_, _) => const LocalDataScreen()),
    GoRoute(path: 'scanner', builder: (_, _) => const ScannerSettingsScreen()),
    GoRoute(path: 'contracts', builder: (_, _) => const ContractsWarrantyScreen()),
    GoRoute(path: 'financial', builder: (_, _) => const FinancialScreen()),
    GoRoute(
      path: 'reports',
      builder: (_, _) => const ReportsScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, state) => ReportChartScreen(reportId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: 'admin',
      builder: (_, state) => AdminScreen(initialTab: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'users/:id',
          builder: (_, state) => AdminUserScreen(personId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: 'tracking',
      builder: (_, state) => TrackingHubScreen(initialTab: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'asset/:assetId',
          builder: (_, state) => AssetTrackingScreen(
            assetId: state.pathParameters['assetId']!,
            initialTab: state.uri.queryParameters['tab'],
          ),
          routes: [
            GoRoute(
              path: 'chart',
              builder: (_, state) => TelemetryChartScreen(
                assetId: state.pathParameters['assetId']!,
                metric: state.uri.queryParameters['metric'] ?? 'battery',
                range: state.uri.queryParameters['range'],
              ),
            ),
          ],
        ),
        GoRoute(path: 'activity', builder: (_, _) => const TrackingActivityScreen()),
        GoRoute(path: 'zones/new', builder: (_, _) => const AddGeofenceScreen()),
      ],
    ),
    GoRoute(
      path: 'inventory',
      builder: (_, state) => InventoryScreen(initialTab: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'part/:partId',
          builder: (_, state) => PartDetailScreen(partId: state.pathParameters['partId']!),
          routes: [
            GoRoute(
              path: 'movement',
              builder: (_, state) => StockMovementScreen(
                partId: state.pathParameters['partId'],
                initialTab: state.uri.queryParameters['tab'],
              ),
            ),
          ],
        ),
        GoRoute(path: 'stock-movement', builder: (_, _) => const StockMovementScreen()),
        GoRoute(
          path: 'requests',
          builder: (_, _) => const PartRequestsScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, state) => RequestPartScreen(partId: state.uri.queryParameters['part']),
            ),
          ],
        ),
        GoRoute(
          path: 'po',
          builder: (_, _) => const PurchaseOrdersScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, state) => PurchaseOrderFormScreen(partId: state.uri.queryParameters['part']),
            ),
            GoRoute(
              path: 'detail/:id',
              builder: (_, state) => PurchaseOrderScreen(id: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(path: 'reports', builder: (_, _) => const StockReportsScreen()),
      ],
    ),
    GoRoute(
      path: 'documents',
      builder: (_, state) => DocumentsScreen(initialTab: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'add',
          builder: (_, state) => AddDocumentScreen(assetId: state.uri.queryParameters['asset']),
        ),
        GoRoute(
          path: 'detail/:id',
          builder: (_, state) => DocumentDetailScreen(id: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'view',
              builder: (_, state) =>
                  DocumentViewerScreen(id: state.pathParameters['id']!, version: state.uri.queryParameters['version']),
            ),
          ],
        ),
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
    GoRoute(
      path: 'alerts',
      builder: (_, state) => AlertsScreen(initialTab: state.uri.queryParameters['tab']),
      routes: [
        GoRoute(
          path: 'detail/:id',
          builder: (_, state) => AlertDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: 'sync',
      builder: (_, _) => const OfflineSyncScreen(),
      routes: [
        GoRoute(
          path: 'pending',
          builder: (_, state) => PendingSyncScreen(initialTab: state.uri.queryParameters['tab']),
        ),
        GoRoute(path: 'progress', builder: (_, _) => const SyncingScreen()),
      ],
    ),
    GoRoute(
      path: 'settings',
      builder: (_, _) => const SettingsScreen(),
      routes: [
        GoRoute(path: 'data-check', builder: (_, _) => const DataCheckScreen()),
        GoRoute(path: 'demo-tags', builder: (_, _) => const DemoTagsScreen()),
        GoRoute(path: 'auth-diagnostics', builder: (_, _) => const AuthDiagnosticsScreen(inShell: true)),
      ],
    ),
    GoRoute(
      path: 'help',
      builder: (_, _) => const HelpScreen(),
      routes: [GoRoute(path: 'report-bug', builder: (_, _) => const ReportBugScreen())],
    ),
    ..._shared(),
  ],
);
