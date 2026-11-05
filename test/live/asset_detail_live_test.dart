import 'dart:io';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/token_store.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_detail_upload.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_asset_backend.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _detail = '/assets/detail/AR000001';

/// Asset 360° in API mode against [FakeAssetBackend] (contract-shaped JSON for AR000001).
void main() {
  late FakeAssetBackend backend;

  setUp(() {
    backend = FakeAssetBackend();
    debugApiMode = true;
    // No connectivity plugin in tests (runAsync below would let its stream start).
    NetworkNotifier.listenToDevice = false;
  });

  tearDown(() {
    debugApiMode = null;
    NetworkNotifier.listenToDevice = true;
    LiveDetailUpload.debugPickPhoto = null;
    LiveDetailUpload.debugPickFile = null;
  });

  Future<ProviderContainer> open(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...backend.overrides,
          sessionProvider.overrideWith(_SignedIn.new),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        ],
        child: const Asset360App(),
      ),
    );
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return c;
  }

  /// A FilledButton (also FilledButton.icon) by its label.
  Finder button(String label) =>
      find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is FilledButton)).last;

  /// The visible page's vertical list (other pages and branches are offstage).
  Finder page() => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

  Future<void> see(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 250, scrollable: page());
    await tester.pumpAndSettle();
    expect(f, findsWidgets);
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.byType(SegmentTabs), -250, scrollable: page());
    await tester.pumpAndSettle();
    final tab = find.descendant(of: find.byType(SegmentTabs), matching: find.text(label)).first;
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets('detail: the five sections, photos, documents, components, condition; criticality 404', (tester) async {
    await open(tester, _detail);
    expect(find.text('TAG-0001'), findsWidgets);
    expect(find.text('Diesel Generator 500 kVA'), findsWidgets);
    expect(find.text('Generator'), findsWidgets, reason: 'Asset Type in the specs box');
    expect(backend.calls('GET', '/api/asset-registrations/AR000001'), isNotEmpty);
    expect(backend.calls('GET', '/api/asset-images').single.uri.queryParameters['assetRegistrationId'], 'AR000001');

    // Overview: condition, criticality, photos, sections, components.
    await see(tester, find.text('86 / 100'));
    expect(find.text('sara.ali'), findsWidgets);
    await see(tester, find.text('No assessment yet'));
    await see(tester, find.text('Front View'));
    await see(tester, find.text('Machinery & Equipment'));
    await see(tester, find.text('Power Generation'));
    await see(tester, find.text('UAE > Main Site > Block A > Ground'));
    await see(tester, find.text('Sara Ali'));
    await see(tester, find.text('AED 100,000'));
    await see(tester, find.text('invoice.pdf'));
    await see(tester, find.text('Power Rating'));
    expect(find.text('500 kVA'), findsWidgets);
    await see(tester, find.text('1000 L'));
    await see(tester, find.text('Engine'));
    expect(find.text('Fuel Pump'), findsOneWidget, reason: 'top level is expanded');
    expect(find.text('20.5% life'), findsOneWidget);

    // Documents tab: GET /api/asset-documents.
    await tapTab(tester, 'Documents');
    expect(find.text('Operation Manual'), findsOneWidget);
    expect(find.text('Manual · v1.0 · 500 KB'), findsOneWidget);

    // A tab without a backend.
    await tapTab(tester, 'IoT');
    expect(find.text('Not available yet'), findsOneWidget);
    await tapTab(tester, 'Maintenance');
    expect(find.text('Maintenance history is not connected to the server yet.'), findsOneWidget);

    // An action without a backend.
    await tapTab(tester, 'Overview');
    await tester.tap(find.text('Create Work Order'));
    await tester.pump();
    expect(find.text('Create Work Order: Not available yet.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('unknown asset: 404 → Asset not found with the server message', (tester) async {
    backend.on(
      'GET',
      '/api/asset-registrations/AR999999',
      (_) => const FakeReply(404, {'message': "Asset registration 'AR999999' was not found."}),
    );
    await open(tester, '/assets/detail/AR999999');
    expect(find.text('Asset not found'), findsOneWidget);
    expect(find.text("Asset registration 'AR999999' was not found."), findsOneWidget);
  });

  testWidgets('Update Condition posts the contract body, then the detail reloads', (tester) async {
    final c = await open(tester, _detail);
    await see(tester, find.text('86 / 100'));
    final before = backend.calls('GET', '/api/asset-condition-assessments/current').length;
    final update = find.text('Update').first;
    await tester.ensureVisible(update);
    await tester.pumpAndSettle();
    await tester.tap(update);
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.toString(), '/assets/more-actions/condition?asset=AR000001');
    expect(find.text('Current: Good · health 86 · 15 Oct 2026'), findsOneWidget);

    // Required fields first.
    await tester.tap(button('Update Condition'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the overall condition'), findsOneWidget);
    expect(find.text('Enter the health score'), findsOneWidget);
    expect(backend.calls('POST', '/api/asset-condition-assessments'), isEmpty);

    await tester.tap(find.text('Fair').first);
    await tester.enterText(find.byKey(const ValueKey('healthScore')), '72');
    await see(tester, find.text('Safety'));
    await see(tester, find.text('Excellent').last);
    await tester.tap(find.text('Excellent').last); // Safety
    await tester.enterText(find.widgetWithText(TextField, 'What did you observe?'), 'Oil leak fixed');
    await tester.pumpAndSettle();
    await tester.tap(button('Update Condition'));
    await tester.pumpAndSettle();

    final body = backend.calls('POST', '/api/asset-condition-assessments').single.data as Map;
    expect(body.keys.toSet(), {
      'assetRegistrationId',
      'assessmentDate',
      'assessedBy',
      'overallCondition',
      'healthScore',
      'physicalCondition',
      'performance',
      'safety',
      'remarks',
    });
    expect(body['assetRegistrationId'], 'AR000001');
    expect(body['overallCondition'], 'Fair');
    expect(body['healthScore'], 72);
    expect(body['safety'], 'Excellent');
    expect(body['physicalCondition'], isNull);
    expect(body['remarks'], 'Oil leak fixed');
    final now = DateTime.now();
    expect(DateTime.parse(body['assessmentDate'] as String).day, now.day, reason: 'defaults to today');

    expect(c.read(routerProvider).state.uri.toString(), _detail, reason: 'back on the detail');
    expect(find.textContaining('condition updated to Fair'), findsOneWidget);
    expect(
      backend.calls('GET', '/api/asset-condition-assessments/current').length,
      greaterThan(before),
      reason: 'liveAssetProviders invalidated',
    );
  });

  testWidgets('Update Condition shows the server 400 field errors under the fields', (tester) async {
    backend.on(
      'POST',
      '/api/asset-condition-assessments',
      (_) => const FakeReply(400, {
        'title': 'One or more validation errors occurred.',
        'errors': {
          'HealthScore': ['HealthScore must be between 0 and 100'],
        },
      }),
    );
    await open(tester, '/assets/more-actions/condition?asset=AR000001');
    await tester.tap(find.text('Good').first);
    await tester.enterText(find.byKey(const ValueKey('healthScore')), '50');
    await tester.tap(button('Update Condition'));
    await tester.pumpAndSettle();
    expect(find.text('HealthScore must be between 0 and 100'), findsOneWidget);
  });

  testWidgets('Add Document refuses a .docx before any upload request', (tester) async {
    LiveDetailUpload.debugPickFile = (_) async => (name: 'spec.docx', path: '/tmp/spec.docx', size: 2048);
    await open(tester, Routes.moreActionFrom(Routes.assets, 'document', 'AR000001'));
    expect(find.text('Add Document'), findsWidgets);
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
    expect(find.text('Only JPG, PNG, WEBP or PDF files can be uploaded.'), findsOneWidget);
    Finder field(String text) => find.byWidgetPredicate((w) => w is EditableText && w.controller.text == text);
    await see(tester, field('1.0')); // Version defaults to 1.0
    expect(field('In Use'), findsOneWidget, reason: 'lifecycle stage from classification');
    await tester.tap(button('Upload Document'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('PDF, JPG, PNG or WEBP'), -250, scrollable: page());
    expect(find.text('Choose a file'), findsWidgets);
    expect(backend.calls('POST', '/api/media/upload'), isEmpty);
    expect(backend.calls('POST', '/api/asset-documents'), isEmpty);
  });

  testWidgets('Add Photo: media upload (asset-images) → POST /api/asset-images with the returned url', (tester) async {
    final dir = Directory.systemTemp.createTempSync('live_photo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}/front.jpg')..writeAsBytesSync(List.filled(64, 1));
    LiveDetailUpload.debugPickPhoto = (_) async => photo.path;
    backend.on('POST', '/api/asset-images', (o) => const FakeReply(201, [sampleImage]));
    await open(tester, _detail);
    final imagesBefore = backend.calls('GET', '/api/asset-images').length;

    await tester.tap(find.text('Add Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Choose what the photo shows'), findsOneWidget);
    await tester.tap(find.text('Nameplate'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(button('Upload'));
      for (var i = 0; i < 20 && backend.calls('POST', '/api/asset-images').isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    final upload = backend.calls('POST', '/api/media/upload').single;
    final form = upload.data as FormData;
    expect(form.fields.firstWhere((f) => f.key == 'category').value, 'asset-images');
    expect(form.files.single.value.filename, 'front.jpg');
    expect(upload.uri.host, 'media.test');

    final body = backend.calls('POST', '/api/asset-images').single.data as Map;
    expect(body['assetRegistrationIds'], ['AR000001']);
    expect(body['imageType'], 'Nameplate');
    final image = (body['images'] as List).single as Map;
    expect(image['fileUrl'], 'http://localhost:5300/uploads/asset-images/front.jpg');
    expect(image['fileName'], 'front.jpg');
    expect(image['contentType'], 'image/jpeg');
    expect(find.text('Photo added (Nameplate)'), findsOneWidget);
    expect(backend.calls('GET', '/api/asset-images').length, greaterThan(imagesBefore), reason: 'gallery refreshed');
  });

  testWidgets('More Actions: live asset card; actions without a backend say Not available yet', (tester) async {
    await open(tester, Routes.moreActionsFrom(Routes.assets, assetId: 'TAG-0001'));
    expect(backend.calls('GET', '/api/asset-registrations/lookup'), isNotEmpty, reason: 'a tag is looked up');
    expect(find.text('Diesel Generator 500 kVA'), findsOneWidget);
    expect(find.text('Not available yet'), findsWidgets);
    await tester.tap(find.text('Assign Custodian'));
    await tester.pump();
    expect(find.text('Assign Custodian: Not available yet.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.ensureVisible(find.text('Add to Favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from Favorites'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
