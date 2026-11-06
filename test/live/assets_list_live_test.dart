import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/features/assets/assets_list_screen.dart';
import 'package:asset360_mobile/features/assets/live/live_assets_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_asset_backend.dart';

/// The Assets tab in API mode (LiveAssetsListScreen) against the fake Asset service.
void main() {
  late FakeAssetBackend backend;

  setUp(() {
    debugApiMode = true;
    SharedPreferences.setMockInitialValues({});
    backend = FakeAssetBackend();
  });
  tearDown(() => debugApiMode = null);

  List<RequestQuery> listCalls() => [
    for (final r in backend.calls('GET', '/api/asset-registrations')) r.uri.queryParameters,
  ];

  Future<void> pump(WidgetTester tester, {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/assets',
      routes: [
        GoRoute(
          path: '/assets',
          builder: (_, state) => AssetsListScreen(initialStatus: state.uri.queryParameters['status']),
          routes: [
            GoRoute(
              path: 'detail/:assetId',
              builder: (_, state) => Scaffold(body: Text('Detail ${state.pathParameters['assetId']}')),
            ),
          ],
        ),
        GoRoute(
          path: '/more/registration',
          builder: (_, _) => const Scaffold(body: Text('Registration hub')),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => const Scaffold(body: Text('New registration')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [...backend.overrides, ...overrides],
        child: MaterialApp.router(theme: AppTheme.current, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('API mode: first page from the server, status cards, "Showing 2 of 2", no mock data', (tester) async {
    await pump(tester);
    expect(find.byType(LiveAssetsListScreen), findsOneWidget);
    expect(find.text('Diesel Generator 500 kVA'), findsOneWidget);
    expect(find.text('Chiller Unit 2'), findsOneWidget);
    expect(find.text('TAG-0001'), findsOneWidget);
    expect(find.text('UAE > Main Site > Block A > Ground'), findsOneWidget);
    expect(find.text('Machinery & Equipment / Generator'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget, reason: 'criticality label');
    expect(find.text('Showing 2 of 2'), findsOneWidget);
    expect(listCalls().first, {'page': '1', 'pageSize': '20'});
    // Summary cards (sampleSummary: total 2, active 1, under maintenance 1).
    expect(
      find.descendant(of: find.byKey(const ValueKey('status-card-Total')), matching: find.text('2')),
      findsOneWidget,
    );
    for (final id in ['CNC-00123', 'GEN-00045', 'MTR-00123', 'FL-012']) {
      expect(find.textContaining(id), findsNothing, reason: '$id is mock data');
    }
    // Tap a row → Asset detail with the registration ID.
    await tap(tester, find.text('Chiller Unit 2'));
    expect(find.text('Detail AR000002'), findsOneWidget);
  });

  testWidgets('status card sends status=…; Total clears it', (tester) async {
    await pump(tester);
    await tap(tester, find.byKey(const ValueKey('status-card-Under Maintenance')));
    expect(listCalls().last['status'], 'Under Maintenance');
    expect(find.text('Diesel Generator 500 kVA'), findsNothing);
    expect(find.text('Showing 1 of 1'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('status-card-Total')));
    expect(listCalls().last.containsKey('status'), isFalse);
    expect(find.text('Showing 2 of 2'), findsOneWidget);
  });

  testWidgets('search is debounced 300 ms and sent as search=', (tester) async {
    await pump(tester);
    final before = listCalls().length;
    await tester.enterText(find.byType(TextField), 'chill');
    await tester.pump(const Duration(milliseconds: 150));
    expect(listCalls().length, before, reason: 'nothing sent before 300 ms');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(listCalls().last['search'], 'chill');
    expect(find.text('Chiller Unit 2'), findsOneWidget);
    expect(find.text('Diesel Generator 500 kVA'), findsNothing);

    // No match → "No assets found" + Clear search & filters.
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('No assets found'), findsOneWidget);
    await tap(tester, find.text('Clear search & filters'));
    expect(listCalls().last.containsKey('search'), isFalse);
    expect(find.text('Showing 2 of 2'), findsOneWidget);
  });

  testWidgets('filter sheet: Master Data values first plus /filters values, types narrowed by category, one value '
      'sent per filter', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Filter'));
    expect(backend.calls('GET', '/api/asset-registrations/filters'), isNotEmpty);
    expect(find.widgetWithText(FilterChip, 'Generator'), findsOneWidget);
    // Master Data department / condition / pump type, and the value only an asset holds.
    for (final v in ['Facilities Management', 'Facilities', 'Needs Attention', 'Pump']) {
      expect(find.widgetWithText(FilterChip, v, skipOffstage: false), findsOneWidget, reason: v);
    }
    expect(find.widgetWithText(FilterChip, 'Diesel Sets', skipOffstage: false), findsNothing, reason: 'child category');
    await tap(tester, find.widgetWithText(FilterChip, 'HVAC'));
    expect(find.widgetWithText(FilterChip, 'Generator'), findsNothing, reason: 'types of HVAC only');
    expect(find.widgetWithText(FilterChip, 'Chiller'), findsOneWidget);
    await tap(tester, find.widgetWithText(FilterChip, 'UAE > Main Site'));
    await tap(tester, find.widgetWithText(FilterChip, 'Sara Ali'));
    await tap(tester, find.text('Apply'));
    final q = listCalls().last;
    expect(q['category'], 'HVAC');
    expect(q['locationId'], 'S1');
    expect(q['custodianUserId'], 'u-100');
    // Active filters as chips (location by path, custodian by name) + Clear all.
    expect(find.widgetWithText(InputChip, 'UAE > Main Site'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Sara Ali'), findsOneWidget);
    expect(find.text('Filter (3)'), findsOneWidget);
    await tap(tester, find.text('Clear all'));
    final cleared = listCalls().last;
    expect(cleared.keys.toSet(), {'page', 'pageSize'});
  });

  testWidgets('sort sheet sends sortBy + sortDirection', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Sort'));
    for (final label in AssetSortKeys.all.values) {
      expect(find.text(label), findsOneWidget);
    }
    await tap(tester, find.text('Asset name'));
    await tap(tester, find.text('Ascending'));
    await tap(tester, find.text('Apply'));
    expect(listCalls().last['sortBy'], 'assetName');
    expect(listCalls().last['sortDirection'], 'asc');
  });

  testWidgets('infinite scroll: 25 assets over two pages', (tester) async {
    final many = [
      for (var i = 0; i < 25; i++)
        {
          ...sampleAssets.first,
          'assetRegistrationId': 'AR${i.toString().padLeft(6, '0')}',
          'assetTag': 'TAG-${i.toString().padLeft(4, '0')}',
          'imageUrl': null,
        },
    ];
    backend.on('GET', '/api/asset-registrations', (o) {
      final page = int.parse(o.uri.queryParameters['page']!);
      return FakeReply(200, {
        'items': many.skip((page - 1) * 20).take(20).toList(),
        'totalCount': 25,
        'page': page,
        'pageSize': 20,
        'summary': sampleSummary,
      });
    });
    await pump(tester);
    expect(find.text('TAG-0000'), findsOneWidget);
    expect(listCalls(), hasLength(1));
    for (var i = 0; i < 10 && find.text('Showing 25 of 25').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    expect(find.text('Showing 25 of 25'), findsOneWidget);
    expect(listCalls().map((q) => q['page']), ['1', '2']);
    expect(find.text('TAG-0024'), findsOneWidget);
  });

  testWidgets('load more failure → inline Retry', (tester) async {
    var failPage2 = true;
    final many = [
      for (var i = 0; i < 25; i++)
        {...sampleAssets.last, 'assetRegistrationId': 'AR${i.toString().padLeft(6, '0')}', 'assetTag': 'T-$i'},
    ];
    backend.on('GET', '/api/asset-registrations', (o) {
      final page = int.parse(o.uri.queryParameters['page']!);
      if (page == 2 && failPage2) return const FakeReply(500, {'message': 'Server busy'});
      return FakeReply(200, {
        'items': many.skip((page - 1) * 20).take(20).toList(),
        'totalCount': 25,
        'page': page,
        'pageSize': 20,
        'summary': sampleSummary,
      });
    });
    await pump(tester);
    for (var i = 0; i < 10 && find.text('Retry').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    expect(find.text('Showing 20 of 25'), findsOneWidget);
    failPage2 = false;
    await tap(tester, find.text('Retry'));
    for (var i = 0; i < 10 && find.text('Showing 25 of 25').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    expect(find.text('Showing 25 of 25'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('My Assets: hidden without a /me user id; with one it sends custodianUserId', (tester) async {
    await pump(tester);
    expect(find.text('My Assets'), findsNothing);
    expect(find.text('Nearby'), findsNothing);
  });

  testWidgets('My Assets with a user id', (tester) async {
    await pump(tester, overrides: [myUserIdProvider.overrideWithValue('u-100')]);
    await tap(tester, find.text('My Assets'));
    expect(listCalls().last['custodianUserId'], 'u-100');
  });

  testWidgets('first page error → Retry loads it', (tester) async {
    var fail = true;
    backend.on('GET', '/api/asset-registrations', (o) {
      if (fail) return const FakeReply(500, {'message': 'Asset service unavailable'});
      return const FakeReply(200, {
        'items': sampleAssets,
        'totalCount': 2,
        'page': 1,
        'pageSize': 20,
        'summary': sampleSummary,
      });
    });
    await pump(tester);
    expect(find.text('Could not load assets'), findsOneWidget);
    expect(find.textContaining('server had a problem (500)'), findsOneWidget);
    fail = false;
    await tap(tester, find.text('Retry'));
    expect(find.text('Diesel Generator 500 kVA'), findsOneWidget);
    expect(backend.calls('GET', '/api/asset-registrations'), hasLength(2));
  });

  testWidgets('empty register → "No assets yet" with Register asset', (tester) async {
    backend.on(
      'GET',
      '/api/asset-registrations',
      (_) => const FakeReply(200, {'items': [], 'totalCount': 0, 'page': 1, 'pageSize': 20, 'summary': {}}),
    );
    await pump(tester);
    expect(find.text('No assets yet'), findsOneWidget);
    await tap(tester, find.widgetWithText(OutlinedButton, 'Register asset'));
    expect(find.text('Registration hub'), findsOneWidget);
  });

  testWidgets('Favorites: star a row, then Favorites reads it by id', (tester) async {
    await pump(tester);
    await tap(tester, find.byTooltip('Add to favorites').first);
    await tap(tester, find.text('Favorites'));
    expect(backend.calls('GET', '/api/asset-registrations/AR000001'), isNotEmpty);
    expect(find.text('Diesel Generator 500 kVA'), findsOneWidget);
    expect(find.text('Chiller Unit 2'), findsNothing);
    expect(find.text('Showing 1 of 1'), findsOneWidget);
    await tap(tester, find.byTooltip('Remove from favorites'));
    expect(find.text('No favorites yet'), findsOneWidget);
  });
}

typedef RequestQuery = Map<String, String>;
