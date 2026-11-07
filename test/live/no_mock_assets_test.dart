import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/asset_picker.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/token_store.dart';
import 'package:asset360_mobile/data/mock/assets_mock.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_asset_backend.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

/// API mode must never show the mock register: no mock asset ID on any asset screen.
void main() {
  late FakeAssetBackend backend;

  /// Every mock asset ID (CNC-00123, GEN-00045, MTR-00123, FL-012 …).
  final mockIds = [for (final a in seedAssets()) a.id];

  setUp(() {
    debugApiMode = true;
    DemoClock.frozen = true;
    SharedPreferences.setMockInitialValues({});
    backend = FakeAssetBackend();
  });
  tearDown(() => debugApiMode = null);

  /// Mock IDs visible in any Text / RichText on screen.
  List<String> visibleMockIds() => [
    for (final id in mockIds)
      if (find.textContaining(id, findRichText: true).evaluate().isNotEmpty) id,
  ];

  testWidgets('Home, Assets, Scan History, Recent Assets, Registration: live data only', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...backend.overrides,
        sessionProvider.overrideWith(_SignedIn.new),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      ],
    );
    expect(mockIds, containsAll(['CNC-00123', 'GEN-00045', 'MTR-00123', 'FL-012']));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    final router = c.read(routerProvider);

    final pages = {
      Routes.home: 'Diesel Generator 500 kVA',
      Routes.assets: 'Diesel Generator 500 kVA',
      Routes.scanHistoryFrom(Routes.home): 'No scans yet',
      Routes.recentAssets: 'Chiller Unit 2',
      Routes.registration: null,
    };
    for (final MapEntry(key: route, value: live) in pages.entries) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      expect(visibleMockIds(), isEmpty, reason: route);
      if (live != null) expect(find.textContaining(live), findsWidgets, reason: route);
    }

    // Home: the Dashboard service's data (test/live/dashboard_test.dart); only My Tasks has no endpoint.
    router.go(Routes.home);
    await tester.pumpAndSettle();
    expect(find.text('Asset Overview'), findsOneWidget);
    expect(find.text('Not available yet'), findsOneWidget);

    expect(c.read(assetsProvider), isEmpty, reason: 'no mock assets in the register');
    expect(c.read(scanHistoryProvider), isEmpty, reason: 'the seed scans point at mock assets');
    await tester.runAsync(() => c.read(assetSummaryProvider.future));
    expect(c.read(orgSummaryProvider).totalAssets, 2, reason: 'the org summary is the server summary');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('the asset picker lists live assets (search on the server) and returns the assetRegistrationId', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: backend.overrides,
        child: MaterialApp(
          theme: AppTheme.current,
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  TextButton(onPressed: () async => picked = await showAssetPicker(context), child: const Text('Pick')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    expect(find.text('Diesel Generator 500 kVA'), findsOneWidget);
    expect(find.text('Chiller Unit 2'), findsOneWidget);
    expect(visibleMockIds(), isEmpty);

    await tester.enterText(find.byType(TextField), 'chiller');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Diesel Generator 500 kVA'), findsNothing);
    expect(backend.calls('GET', '/api/asset-registrations').last.uri.queryParameters['search'], 'chiller');

    await tester.tap(find.text('Chiller Unit 2'));
    await tester.pumpAndSettle();
    expect(picked, 'AR000002');
  });
}
