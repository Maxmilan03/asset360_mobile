import 'dart:async';
import 'dart:convert';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/dashboard/network_status_live.dart';
import 'package:asset360_mobile/data/api/token_store.dart';
import 'package:asset360_mobile/data/mock/assets_mock.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/home_style.dart';
import 'package:asset360_mobile/features/home/quick_actions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_samples.dart';
import 'fake_asset_backend.dart';

DashboardApi _api(FakeAssetBackend b, {int offset = 240}) => DashboardApi(
  ApiClient(Dio(BaseOptions(baseUrl: 'http://dash.test:5470'))..httpClientAdapter = b, checkConfig: false),
  utcOffsetMinutes: offset,
);

Map<String, String> _query(FakeAssetBackend b, String path) => b.calls('GET', path).last.uri.queryParameters;

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

// ------------------------------------------------------------------ fake WebSocket

class _FakeSocket implements LiveSocket {
  _FakeSocket({this.fail = false});

  final bool fail;
  final controller = StreamController<Object?>();
  bool closed = false;

  @override
  Future<void> get ready => fail ? Future.error(const SocketExceptionLike()) : Future.value();

  @override
  Stream<Object?> get messages => controller.stream;

  @override
  Future<void> close() async {
    closed = true;
    if (!controller.isClosed) unawaited(controller.close());
  }

  void send(Map<String, Object?> json) => controller.add(jsonEncode(json));

  /// The server / network drops the connection.
  void drop() => controller.close();
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

void main() {
  late FakeAssetBackend backend;

  setUp(() {
    backend = FakeAssetBackend();
    SharedPreferences.setMockInitialValues({});
  });

  // ================================================================ parsing (one per endpoint)

  group('parsing: contract-shaped JSON of every endpoint', () {
    test('GET /mobile/home: greeting, quick actions and the summary cards', () async {
      final h = await _api(backend).getHome();
      expect(_query(backend, DashboardApi.home), {'utcOffsetMinutes': '240'});
      expect(h.greeting.salutation, 'Good Afternoon');
      expect(h.greeting.userName, 'max.milan');
      expect(h.greeting.generatedAtUtc, DateTime.utc(2026, 11, 7, 10, 15));
      expect(h.quickActions.openWorkOrders, 37);
      expect(h.quickActions.pendingInspections, 29);
      expect(h.quickActions.pendingApprovals, 17);
      expect(h.quickActions.criticalAlerts, 13);
      expect(h.assetOverview.totalAssets, 2);
      expect(h.assetOverview.breakdown.map((b) => b.key), [
        'operational',
        'under-maintenance',
        'out-of-service',
        'retired',
      ]);
      expect(h.maintenancePerformance.plannedPercent, 57.1);
      expect(h.maintenancePerformance.months, 6);
      expect(h.maintenancePerformance.total, 7);
      expect(h.upcomingActivities.map((u) => (u.type, u.count, u.when)), [
        ('WorkOrder', 1, 'Today'),
        ('Inspection', 0, 'Today'),
        ('Approval', 17, 'Pending'),
      ]);
      expect(h.recentAlerts.single.severity, DashSeverity.critical);
      expect(h.assetLocation.assetsWithLocation, 1);
      expect(h.assetLocation.center!.latitude, 25.0657);
      expect(h.assetLocation.assets.single.longitude, 55.1713);
      expect(h.assetHealth.healthyPercent, 50);
      expect(h.assetHealth.breakdown.last.key, 'critical');
    });

    test('GET /mobile/asset-overview?search=', () async {
      final o = await _api(backend).getAssetOverview(search: 'gen');
      expect(_query(backend, DashboardApi.assetOverview), {'search': 'gen'});
      expect(o.totalAssets, 2);
      expect(o.byType.single.label, 'Generator');
      expect(o.byLocation, isEmpty);
      final all = await _api(backend).getAssetOverview();
      expect(_query(backend, DashboardApi.assetOverview), isEmpty, reason: 'null search is not sent');
      expect(all.byLocation.map((l) => l.label), ['Main Site', 'North Plant']);
      expect(all.byStatus.first.percent, 50);
    });

    test('GET /mobile/maintenance-performance?months=&assetType=&site=&utcOffsetMinutes=', () async {
      final m = await _api(backend).getMaintenancePerformance(months: 12, assetType: 'Generator', site: 'Main Site');
      expect(_query(backend, DashboardApi.maintenancePerformance), {
        'months': '12',
        'assetType': 'Generator',
        'site': 'Main Site',
        'utcOffsetMinutes': '240',
      });
      expect(m.period.label, 'Last 6 Months');
      expect(m.period.fromUtc, DateTime.utc(2026, 6));
      expect((m.counts.total, m.counts.planned, m.counts.unplanned, m.counts.overdue), (7, 4, 2, 1));
      expect(m.trend.map((t) => t.label), ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov']);
      expect(m.trend[4].overdue, 1);
      expect(m.mttr.value, 5.5);
      expect(m.mttr.unit, 'hrs');
      expect(m.mttr.changePercent, -12.5);
      expect(m.mttr.isImprovement, isTrue);
      expect(m.mtbf.changePercent, isNull);
      expect(m.mtbf.isImprovement, isNull);
      expect(m.byAssetType.first.assetType, 'Generator');
      expect(m.byAssetType.last.plannedPercent, 33.3);
    });

    test('GET /mobile/upcoming-activities?from=&to=&type=', () async {
      final a = await _api(
        backend,
      ).getUpcomingActivities(from: DateTime(2026, 11, 1), to: DateTime(2026, 12, 26), type: 'WorkOrder');
      expect(_query(backend, DashboardApi.upcomingActivities), {
        'from': '2026-11-01',
        'to': '2026-12-26',
        'type': 'WorkOrder',
        'utcOffsetMinutes': '240',
      });
      expect(a.from, DateTime(2026, 11, 1));
      expect(a.totalCount, 2);
      expect(a.days.first.date, DateTime(2026, 11, 9));
      expect(a.days.first.workOrders, 1);
      final wo = a.items.first;
      expect(wo.type, DashActivityType.workOrder);
      expect(wo.reference, 'WO-7781');
      expect(wo.startUtc, DateTime.utc(2026, 11, 9, 5));
      expect(wo.endUtc, DateTime.utc(2026, 11, 9, 7));
      expect(wo.priority, 'High');
      expect(a.items.last.location, isNull);
      expect(a.items.last.endUtc, isNull);
    });

    test('GET /mobile/recent-alerts?severity=&days=&page=&pageSize=', () async {
      final r = await _api(backend).getRecentAlerts(severity: 'Critical', days: 30, page: 2, pageSize: 50);
      expect(_query(backend, DashboardApi.recentAlerts), {
        'severity': 'Critical',
        'days': '30',
        'page': '2',
        'pageSize': '50',
      });
      expect((r.counts.all, r.counts.critical, r.counts.warning, r.counts.info), (2, 1, 1, 0));
      expect(r.totalCount, 1);
      final a = r.items.single;
      expect(a.source, 'IoT');
      expect(a.title, 'High Temperature');
      expect(a.assetId, 'TAG-0001');
      expect(a.occurredAtUtc, DateTime.utc(2026, 11, 7, 9));
    });

    test('GET /mobile/asset-locations?status=&search= (coordinates per asset)', () async {
      final l = await _api(backend).getAssetLocations(status: 'operational', search: 'gen');
      expect(_query(backend, DashboardApi.assetLocations), {'status': 'operational', 'search': 'gen'});
      expect(l.totalCount, 1);
      expect(l.center!.longitude, 55.1713);
      final a = l.assets.single;
      expect((a.latitude, a.longitude), (25.0657, 55.1713));
      expect(a.statusGroup, 'operational');
      expect(a.locationLabel, 'Block A - Ground');
      final empty = DashAssetLocations.fromJson(dashLocationsEmptyJson);
      expect(empty.center, isNull);
      expect(empty.assets, isEmpty);
    });

    test('GET /mobile/asset-health?top=', () async {
      final h = await _api(backend).getAssetHealth(top: 10);
      expect(_query(backend, DashboardApi.assetHealth), {'top': '10'});
      expect(h.totalAssets, 2);
      expect(h.byAssetType.last.critical, 1);
      expect(h.byLocation.first.key, 'Main Site');
      final c = h.criticalAssets.single;
      expect(c.assetRegistrationId, 'AR000002');
      expect(c.healthScore, 31.5);
      expect(c.issue, 'Compressor vibration high');
    });

    test('GET /mobile/cost-summary?period=&year=', () async {
      final c = await _api(backend).getCostSummary(period: DashCostPeriod.year, year: 2025);
      expect(_query(backend, DashboardApi.costSummary), {'period': 'year', 'year': '2025'});
      expect(c.currency, 'AED');
      expect(c.period.label, 'YTD 2026');
      expect(c.totalCost, 12500.5);
      expect(c.previousPeriodCost, 10000);
      expect(c.changePercent, 25);
      expect(c.categories.map((g) => g.key), ['maintenance', 'operations', 'spare-parts']);
      expect(c.monthlyTrend.last.spareParts, 2000);
      expect(c.byAssetType.first.amount, 9000);
    });

    test('GET /mobile/recent-assets?status=&search=&assetType=&site=&page=&pageSize=', () async {
      final r = await _api(backend).getRecentAssets(
        status: 'operational',
        search: 'die',
        assetType: 'Generator',
        site: 'Main Site',
        page: 1,
        pageSize: 20,
      );
      expect(_query(backend, DashboardApi.recentAssets), {
        'status': 'operational',
        'search': 'die',
        'assetType': 'Generator',
        'site': 'Main Site',
        'page': '1',
        'pageSize': '20',
      });
      expect(r.counts.first.key, 'all');
      expect(r.counts.first.count, 2);
      final a = r.items.single;
      expect(a.assetRegistrationId, 'AR000001');
      expect(a.manufacturer, 'Cummins');
      expect(a.createdAtUtc, DateTime.utc(2026, 10, 1, 8));
      final item = dashAssetItem(a);
      expect(item.locationPath, 'Block A - Ground');
      expect(item.status, 'Active');
    });

    test('GET /network-status and /network-status/tags', () async {
      final api = _api(backend);
      final n = await api.getNetworkStatus();
      expect((n.totalOnline, n.totalOffline, n.total), (12, 3, 15));
      final tags = await api.getNetworkStatusTags();
      expect(tags.first.tagId, 'E2801170000002089A1B');
      expect(tags.first.count, 420);
      expect(tags.first.assetId, 'AR000001');
      expect(tags.last.assetId, isNull);
    });

    test('tolerant: missing / wrongly typed fields read as 0 / null / empty, never throw', () {
      final h = DashHome.fromJson({'quickActions': 'oops', 'recentAlerts': 3});
      expect(h.quickActions.openWorkOrders, 0);
      expect(h.recentAlerts, isEmpty);
      expect(h.assetLocation.center, isNull);
      final m = DashMaintenance.fromJson(null);
      expect(m.counts.total, 0);
      expect(m.mttr.changePercent, isNull);
      expect(DashCostSummary.fromJson(const {}).currency, 'AED');
      expect(NetworkStatusCounts.fromJson({'totalOnline': '4'}).totalOnline, 4);
      expect(TagRecordCount.list({'items': dashTagsJson}).length, 2, reason: 'a wrapped list is read too');
    });

    test('live URL: ws:// for http, wss:// for https, path kept', () {
      expect(
        DashboardApi.liveUri('http://172.16.100.26:5470').toString(),
        'ws://172.16.100.26:5470/api/dashboards/network-status/live',
      );
      expect(
        DashboardApi.liveUri('https://dash.example.com/gw/').toString(),
        'wss://dash.example.com/gw/api/dashboards/network-status/live',
      );
    });
  });

  // ================================================================ WebSocket reconnect

  group('NetworkStatusSocket', () {
    late List<_FakeSocket> sockets;
    late List<_FakeTimer> timers;
    late List<NetworkStatusCounts> counts;
    late List<LiveConnection> states;
    late List<bool> failNext;
    late List<String?> tokens;

    NetworkStatusSocket create() => NetworkStatusSocket(
      uri: Uri.parse('ws://dash.test:5470/api/dashboards/network-status/live'),
      token: () async => 'access-1',
      connect: (uri, token) {
        tokens.add(token);
        final s = _FakeSocket(fail: failNext.isNotEmpty && failNext.removeAt(0));
        sockets.add(s);
        return s;
      },
      schedule: (d, cb) {
        final t = _FakeTimer(d, cb);
        timers.add(t);
        return t;
      },
      onCounts: counts.add,
      onConnection: states.add,
    );

    setUp(() {
      sockets = [];
      timers = [];
      counts = [];
      states = [];
      failNext = [];
      tokens = [];
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('connects with the Bearer token, pushes counts, ignores non-JSON', () async {
      final ws = create()..start();
      await settle();
      expect(tokens, ['access-1']);
      expect(ws.state, LiveConnection.connected);
      sockets.single.send({'totalOnline': 12, 'totalOffline': 3});
      sockets.single.controller.add('not json');
      sockets.single.send({'totalOnline': 11, 'totalOffline': 4});
      await settle();
      expect(counts, const [
        NetworkStatusCounts(totalOnline: 12, totalOffline: 3),
        NetworkStatusCounts(totalOnline: 11, totalOffline: 4),
      ]);
      expect(ws.state, LiveConnection.connected, reason: 'a bad message keeps the connection');
      await ws.stop();
    });

    test('backs off 2 s, 5 s, 10 s, then 30 s max; a message resets the backoff', () async {
      final ws = create()..start();
      await settle();
      expect(states, [LiveConnection.connecting, LiveConnection.connected]);

      // The server drops the socket; the next three attempts fail to open, then two more.
      failNext = [true, true, true, true];
      sockets.last.drop();
      await settle();
      expect(ws.state, LiveConnection.waiting);
      final delays = <Duration>[];
      for (var i = 0; i < 5; i++) {
        delays.add(timers.last.delay);
        timers.last.fire();
        await settle();
      }
      expect(delays, const [
        Duration(seconds: 2),
        Duration(seconds: 5),
        Duration(seconds: 10),
        Duration(seconds: 30),
        Duration(seconds: 30),
      ]);
      expect(sockets.length, 6);
      expect(ws.state, LiveConnection.connected, reason: 'the 6th attempt opened');

      // A message resets the backoff: the next drop waits 2 s again.
      sockets.last.send({'totalOnline': 1, 'totalOffline': 0});
      await settle();
      expect(ws.failures, 0);
      sockets.last.drop();
      await settle();
      expect(timers.last.delay, const Duration(seconds: 2));
      await ws.stop();
    });

    test('stop closes the socket, cancels the pending reconnect and never reconnects', () async {
      final ws = create()..start();
      await settle();
      final first = sockets.single;
      await ws.stop();
      expect(first.closed, isTrue);
      expect(ws.state, LiveConnection.stopped);
      expect(timers, isEmpty, reason: 'a deliberate close is not a drop');

      ws.start();
      await settle();
      sockets.last.drop();
      await settle();
      final pending = timers.single;
      expect(pending.isActive, isTrue);
      await ws.stop();
      expect(pending.isActive, isFalse);
      pending.fire();
      await settle();
      expect(sockets.length, 2, reason: 'no reconnect after stop');
    });

    test('LiveDevicesNotifier: REST counts first, socket messages replace them, setActive opens / closes', () async {
      debugApiMode = true;
      addTearDown(() {
        debugApiMode = null;
        LiveDevicesNotifier.debugScheduler = null;
      });
      final previous = LiveDevicesNotifier.debugConnector;
      addTearDown(() => LiveDevicesNotifier.debugConnector = previous);
      LiveDevicesNotifier.debugConnector = (uri, token) {
        expect(uri.toString(), endsWith('/api/dashboards/network-status/live'));
        final s = _FakeSocket();
        sockets.add(s);
        return s;
      };
      LiveDevicesNotifier.debugScheduler = (d, cb) => _FakeTimer(d, cb);
      final c = liveContainer(backend);
      addTearDown(c.dispose);
      c.listen(liveDevicesProvider, (_, _) {});
      await c.read(networkStatusProvider.future);
      await settle();
      expect(c.read(liveDevicesProvider).counts, const NetworkStatusCounts(totalOnline: 12, totalOffline: 3));

      c.read(liveDevicesProvider.notifier).setActive(true);
      await settle();
      expect(c.read(liveDevicesProvider).live, isTrue);
      sockets.single.send({'totalOnline': 20, 'totalOffline': 1});
      await settle();
      expect(c.read(liveDevicesProvider).counts, const NetworkStatusCounts(totalOnline: 20, totalOffline: 1));

      c.read(liveDevicesProvider.notifier).setActive(false);
      await settle();
      expect(sockets.single.closed, isTrue);
      expect(c.read(liveDevicesProvider).connection, LiveConnection.stopped);
    });
  });

  // ================================================================ Home + drill-downs (API mode)

  group('Home in API mode', () {
    late ProviderContainer c;

    setUp(() {
      debugApiMode = true;
      DemoClock.frozen = true;
      DrilldownPage.refreshDelay = Duration.zero;
    });
    tearDown(() => debugApiMode = null);

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          ...backend.overrides,
          sessionProvider.overrideWith(_SignedIn.new),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        ],
      );
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();
    }

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      c.dispose();
    }

    bool shows(String text) => find.textContaining(text, findRichText: true).evaluate().isNotEmpty;

    testWidgets('every section shows its endpoint data and no mock value', (tester) async {
      // The mock Home's distinctive values (read with apiMode off).
      debugApiMode = false;
      final mock = ProviderContainer();
      final home = mock.read(homeDataProvider);
      final org = mock.read(orgSummaryProvider);
      final mockTexts = <String>{
        for (final a in seedAssets()) a.id,
        for (final a in home.recentAlerts) a.message,
        for (final a in mock.read(upcomingActivitiesProvider)) a.title,
        NumberFormat('#,###').format(org.totalAssets),
        compactAed(org.totalCost),
      }
        // Quick Actions are the same tiles in both modes (navigation, not data).
        ..removeAll([for (final d in quickActionDefs.values) d.label])
        ..removeWhere((t) => t.length < 3);
      mock.dispose();
      debugApiMode = true;
      expect(mockTexts, contains('12,458'));

      await pumpApp(tester);
      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final leaked = [
        for (final t in mockTexts)
          if (shows(t)) t,
      ];
      expect(leaked, isEmpty, reason: 'mock values on the API-mode Home');

      // /mobile/home: greeting + the four counters.
      expect(shows('Good Afternoon'), isTrue);
      for (final n in ['37', '29', '17', '13']) {
        expect(find.text(n), findsWidgets, reason: 'counter $n');
      }
      // One section per endpoint.
      expect(shows('Generator load bank test'), isTrue, reason: '/upcoming-activities');
      expect(shows('High Temperature'), isTrue, reason: '/recent-alerts');
      expect(find.text('57%'), findsOneWidget, reason: '/maintenance-performance planned share');
      expect(find.text('5.5 hrs'), findsOneWidget, reason: 'MTTR');
      expect(shows('Diesel Generator 500 kVA'), isTrue, reason: '/recent-assets');
      expect(find.text('13K'), findsOneWidget, reason: '/cost-summary total');
      expect(find.text('Live Devices'), findsOneWidget);
      expect(find.text('12'), findsWidgets, reason: 'devices online');
      expect(find.text('Live'), findsOneWidget, reason: 'the socket is connected');
      expect(find.text('My Tasks'), findsOneWidget);
      expect(find.text('Not available yet'), findsOneWidget, reason: 'only My Tasks has no endpoint');

      // Each section called its own endpoint.
      for (final p in [
        DashboardApi.home,
        DashboardApi.assetOverview,
        DashboardApi.maintenancePerformance,
        DashboardApi.upcomingActivities,
        DashboardApi.recentAlerts,
        DashboardApi.assetLocations,
        DashboardApi.assetHealth,
        DashboardApi.costSummary,
        DashboardApi.recentAssets,
        DashboardApi.networkStatus,
      ]) {
        expect(backend.calls('GET', p), isNotEmpty, reason: p);
      }
      await dispose(tester);
    });

    testWidgets('one failing section shows its own error + Retry; the rest still show', (tester) async {
      var healthUp = false;
      backend.on(
        'GET',
        DashboardApi.assetHealth,
        (_) => healthUp ? const FakeReply(200, dashHealthJson) : const FakeReply(500, {'message': 'boom'}),
      );
      backend.on('GET', DashboardApi.assetLocations, (_) => const FakeReply(200, dashLocationsEmptyJson));
      await pumpApp(tester);
      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      expect(find.textContaining('The server had a problem (500)'), findsOneWidget);
      expect(find.text('No assets on the map yet'), findsOneWidget, reason: 'empty data: a short message');
      expect(shows('High Temperature'), isTrue, reason: 'other sections still load');

      healthUp = true;
      final retry = find.text('Retry');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      // Lift it above the bottom bar.
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.textContaining('The server had a problem (500)'), findsNothing);
      expect(find.text('Asset Health'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('site selector narrows Maintenance + Recent Assets with site=', (tester) async {
      await pumpApp(tester);
      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select site'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('North Plant').last);
      await tester.pumpAndSettle();
      expect(_query(backend, DashboardApi.maintenancePerformance)['site'], 'North Plant');
      expect(_query(backend, DashboardApi.recentAssets)['site'], 'North Plant');
      expect(find.text('Showing North Plant only'), findsOneWidget);
      expect(shows('Chiller Unit 2'), isTrue);
      await dispose(tester);
    });

    testWidgets('drill-downs read their endpoint (tabs, filters) and show no mock values', (tester) async {
      await pumpApp(tester);
      final router = c.read(routerProvider);
      final mockIds = [for (final a in seedAssets()) a.id];

      Future<void> open(String route) async {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        expect(
          [
            for (final id in mockIds)
              if (shows(id)) id,
          ],
          isEmpty,
          reason: route,
        );
        expect(find.text('Not available yet'), findsNothing, reason: route);
      }

      await open(Routes.assetOverview);
      expect(find.text('Total Assets'), findsOneWidget);
      await tester.ensureVisible(find.text('By Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By Location'));
      await tester.pumpAndSettle();
      expect(find.text('North Plant'), findsWidgets);
      await tester.tap(find.text('North Plant').last);
      await tester.pumpAndSettle();
      expect(_query(backend, DashboardApi.recentAssets)['site'], 'North Plant');
      expect(find.text('Chiller Unit 2'), findsOneWidget);

      await open(Routes.maintenancePerformance);
      expect(find.text('Planned WOs'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 12 Months').last);
      await tester.pumpAndSettle();
      expect(_query(backend, DashboardApi.maintenancePerformance)['months'], '12');
      await tester.ensureVisible(find.text('By Asset Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By Asset Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chiller'));
      await tester.pumpAndSettle();
      expect(_query(backend, DashboardApi.maintenancePerformance)['assetType'], 'Chiller');

      await open(Routes.activitiesView('list'));
      expect(find.text('Generator load bank test'), findsOneWidget);
      expect(_query(backend, DashboardApi.upcomingActivities).keys, containsAll(['from', 'to']));
      await tester.tap(find.text('Generator load bank test'));
      await tester.pump();
      expect(find.textContaining('Work orders: Not available yet'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await open(Routes.recentAlertsSeverity(DashSeverity.critical));
      expect(_query(backend, DashboardApi.recentAlerts)['severity'], 'Critical');
      expect(find.text('High Temperature'), findsOneWidget);
      expect(find.text('Work Order Overdue'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('alertDays')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 30 days').last);
      await tester.pumpAndSettle();
      expect(_query(backend, DashboardApi.recentAlerts)['days'], '30');

      await open(Routes.assetHealth);
      expect(find.text('Compressor vibration high'), findsOneWidget);
      await tester.ensureVisible(find.text('By Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By Location'));
      await tester.pumpAndSettle();
      expect(find.text('North Plant'), findsOneWidget);

      await open(Routes.costSummary);
      expect(find.text('AED 12,501'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('costPeriod')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 12 Months').last);
      await tester.pumpAndSettle();
      expect(_query(backend, DashboardApi.costSummary)['period'], 'last-12-months');

      await open(Routes.recentAssets);
      expect(find.text('Diesel Generator 500 kVA'), findsOneWidget);
      await tester.ensureVisible(find.text('Under Maintenance (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Under Maintenance (1)'));
      await tester.pumpAndSettle();
      expect(_query(backend, DashboardApi.recentAssets)['status'], 'under-maintenance');
      expect(find.text('Diesel Generator 500 kVA'), findsNothing);

      await open(Routes.assetLocation);
      expect(find.text('1 asset on the map'), findsOneWidget);

      await open(Routes.devices);
      expect(find.text('E2801170000002089A1B'), findsOneWidget);
      expect(find.text('No asset linked'), findsOneWidget);
      await tester.tap(find.text('E2801170000002089A1B'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation, Routes.assetDetail('AR000001'));
      await dispose(tester);
    });

    testWidgets('pull-to-refresh on Home reloads every section', (tester) async {
      await pumpApp(tester);
      c.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      final before = backend.calls('GET', DashboardApi.costSummary).length;
      await tester.fling(find.byType(CustomScrollView).first, const Offset(0, 600), 1500);
      await tester.pumpAndSettle();
      expect(backend.calls('GET', DashboardApi.costSummary).length, greaterThan(before));
      expect(backend.calls('GET', DashboardApi.home).length, greaterThan(1));
      await dispose(tester);
    });
  });
}
