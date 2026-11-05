import 'dart:convert';
import 'dart:io';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/features/more/registration/register_asset_screen.dart';
import 'package:asset360_mobile/features/more/registration/registration_fields.dart';
import 'package:asset360_mobile/features/more/registration/registration_hub_screen.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_asset_backend.dart';

const _drafts = '/api/asset-registrations/drafts';

/// A server draft (AssetRegistrationDraftResponse): the complete sample registration.
Map<String, dynamic> _draft(String id, int currentStep, {Map<String, dynamic>? basicInformation}) => {
  ...sampleRegistration(),
  'id': 'db-$id',
  'assetRegistrationId': id,
  'currentStep': currentStep,
  'basicInformation': ?basicInformation,
  'updatedAt': '2026-10-02T08:00:00Z',
};

Map<String, dynamic> _json(Object? data) => jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

// ---------------------------------------------------------------- widget helpers

Finder _field(String label) => find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> && k.value.startsWith('$label#') && (w is FormField || w is Autocomplete);
});

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String text) async {
  var f = _field(label);
  if (tester.widget(f.first) is Autocomplete) f = find.descendant(of: f.first, matching: find.byType(TextFormField));
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.enterText(f.first, text);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String label, String option) async {
  await _tapVisible(tester, _field(label).first);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

/// [text] is shown inside the field labelled [label] (its error line).
void _expectUnder(String label, String text) => expect(
  find.descendant(of: _field(label).first, matching: find.text(text)),
  findsOneWidget,
  reason: label,
);

class _Harness {
  _Harness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;
}

Future<_Harness> _pump(WidgetTester tester, FakeAssetBackend backend) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.registration,
    routes: [
      GoRoute(
        path: Routes.registration,
        builder: (_, _) => const RegistrationHubScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, state) => RegisterAssetScreen(prefill: state.extra as RegistrationPrefill?),
          ),
        ],
      ),
      GoRoute(
        path: '/assets/detail/:id',
        builder: (_, state) => Scaffold(body: Text('Asset detail ${state.pathParameters['id']}')),
      ),
    ],
  );
  final c = ProviderContainer(overrides: backend.overrides);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(theme: AppTheme.current, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  return _Harness(c, router);
}

Future<void> _openForm(WidgetTester tester, _Harness h, [RegistrationPrefill? prefill]) async {
  h.router.push(Routes.newRegistration, extra: prefill);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAssetBackend backend;

  setUp(() {
    debugApiMode = true;
    DemoClock.frozen = true;
    NetworkNotifier.listenToDevice = false;
    SharedPreferences.setMockInitialValues({});
    backend = FakeAssetBackend();
  });

  tearDown(() {
    debugApiMode = null;
    NetworkNotifier.listenToDevice = true;
    AssetImagesField.debugPickPhoto = null;
  });

  testWidgets('step 1 Next posts the draft and keeps the AR id; step 2 Next PUTs the classification DTO; '
      'Save as Draft sends saveAsDraft=true', (tester) async {
    backend
      ..on('POST', _drafts, (o) {
        final basic = (_json(o.data))['basicInformation'] as Map<String, dynamic>;
        return FakeReply(201, _draft('AR000123', 1, basicInformation: basic));
      })
      ..on('PUT', '$_drafts/AR000123/classification', (o) => FakeReply(200, _draft('AR000123', 2)))
      ..on('PUT', '$_drafts/AR000123/location-assignment', (o) => FakeReply(200, _draft('AR000123', 3)));
    final h = await _pump(tester, backend);
    await _openForm(tester, h);

    // Step 1: the status list is the server's (Out of Service is not a local value).
    await _tapVisible(tester, _field('Status').first);
    expect(find.text('Out of Service'), findsWidgets);
    await tester.tap(find.text('Active').last);
    await tester.pumpAndSettle();
    await _enter(tester, 'Asset Name', 'Fire Pump 2');
    await _enter(tester, 'Asset Tag / Asset ID', 'FP-0002');
    await _tapButton(tester, 'Next');
    final post = backend.calls('POST', _drafts).single;
    expect(post.uri.queryParameters, isNot(contains('saveAsDraft')));
    final basic = _json(post.data)['basicInformation'] as Map<String, dynamic>;
    expect([basic['assetName'], basic['assetTag'], basic['status']], ['Fire Pump 2', 'FP-0002', 'Active']);
    expect(find.text('Step 2 of 5 · Category and type'), findsOneWidget);
    expect(find.text('Draft AR000123 · saved on the server'), findsOneWidget);

    // Step 2: categories / types / criticality / fixed lists from the server.
    await _pick(tester, 'Category', 'Machinery & Equipment');
    await _pick(tester, 'Sub Category', 'Power Generation');
    await _pick(tester, 'Asset Type', 'Generator');
    expect(
      backend.requests.any((r) => r.uri.path == '/api/asset-category-types' && r.uri.query == 'categoryId=cat2'),
      isTrue,
    );
    await _pick(tester, 'Function / Purpose', 'Other');
    await _pick(tester, 'Criticality', 'High');
    await _pick(tester, 'Department', 'Facilities Management');
    await _tapVisible(tester, find.text('QR Code'));
    await _pick(tester, 'Lifecycle Stage', 'Planned');
    await _tapButton(tester, 'Next');
    final put = backend.calls('PUT', '$_drafts/AR000123/classification').single;
    expect(put.uri.queryParameters, isNot(contains('saveAsDraft')));
    expect(_json(put.data), {
      'category': 'Machinery & Equipment',
      'subCategory': 'Power Generation',
      'assetType': 'Generator',
      'assetSubType': null,
      'functionPurpose': 'Other',
      'criticality': 'High',
      'department': 'Facilities Management',
      'costCenter': null,
      'businessUnit': null,
      'taggingMethod': 'QR Code',
      'complianceCategory': null,
      'lifecycleStage': 'Planned',
      'keywords': <Object?>[],
    });
    expect(backend.calls('POST', _drafts), hasLength(1), reason: 'the draft is created once');

    // Step 3: local locations (said so) → Save as Draft.
    expect(find.text('Step 3 of 5 · Where and with whom'), findsOneWidget);
    expect(find.text('Locations are not from the server yet'), findsOneWidget);
    await _tapVisible(tester, find.text('Save as Draft'));
    final save = backend.calls('PUT', '$_drafts/AR000123/location-assignment').single;
    expect(save.uri.queryParameters['saveAsDraft'], 'true');
    expect(find.textContaining('Draft AR000123 saved'), findsOneWidget);
  });

  testWidgets('409 duplicate tag shows under Asset Tag; 400 field errors show under their fields; '
      'Save as Draft of a new form posts with saveAsDraft', (tester) async {
    var reply = const FakeReply(409, {'message': "An asset with tag 'TAG-0001' is already registered."});
    backend.on('POST', _drafts, (_) => reply);
    final h = await _pump(tester, backend);
    await _openForm(tester, h);
    await _enter(tester, 'Asset Name', 'Generator 2');
    await _enter(tester, 'Asset Tag / Asset ID', 'TAG-0001');
    await _tapButton(tester, 'Next');
    _expectUnder('Asset Tag / Asset ID', "An asset with tag 'TAG-0001' is already registered.");
    expect(find.text('Step 1 of 5 · Asset details and identification'), findsOneWidget);

    reply = const FakeReply(400, {
      'title': 'One or more validation errors occurred.',
      'errors': {
        'AssetName': ['AssetName is required'],
        'Status': ['Status is required'],
      },
    });
    await _tapButton(tester, 'Next');
    _expectUnder('Asset Name', 'AssetName is required');
    _expectUnder('Status', 'Status is required');
    expect(find.text('Generator 2'), findsWidgets, reason: 'the input is kept');

    reply = FakeReply(201, _draft('AR000124', 1));
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars(); // it covers the buttons
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Save as Draft'));
    expect(backend.calls('POST', _drafts).last.uri.queryParameters['saveAsDraft'], 'true');
    expect(find.textContaining('Draft AR000124 saved'), findsOneWidget);
  });

  testWidgets('network error keeps the form; submit 400 opens the step with the error; '
      'submit → success with the id → View Asset opens the asset', (tester) async {
    var putReply = FakeReply(200, _draft('AR000300', 5));
    var submitReply = const FakeReply(400, {
      'errors': {
        'Classification.Department': ['Department is required'],
        'PurchaseWarranty.Purchase.PurchaseCost': ['PurchaseCost is required'],
      },
    });
    backend
      ..on('GET', '$_drafts/AR000300', (_) => FakeReply(200, _draft('AR000300', 5)))
      ..on('PUT', '$_drafts/AR000300/additional-information', (_) => putReply)
      ..on('POST', '$_drafts/AR000300/submit', (_) => submitReply);
    final h = await _pump(tester, backend);
    await _openForm(tester, h, const RegistrationPrefill(draftId: 'AR000300'));
    expect(find.text('Step 5 of 5 · Custom fields and attachments'), findsOneWidget, reason: 'currentStep 5 → step 5');

    putReply = const FakeReply(500, {'message': 'boom'});
    await _tapButton(tester, 'Next');
    expect(find.textContaining('The server had a problem (500)'), findsOneWidget);
    expect(find.text('Step 5 of 5 · Custom fields and attachments'), findsOneWidget);

    putReply = FakeReply(200, _draft('AR000300', 5));
    await _tapButton(tester, 'Next');
    expect(find.text('Asset details are ready to be submitted'), findsOneWidget);
    await _tapButton(tester, 'Submit');
    expect(find.text('Step 2 of 5 · Category and type'), findsOneWidget, reason: 'first step with an error');
    _expectUnder('Department', 'Department is required');

    // Next on each step saves it again, then Submit succeeds.
    submitReply = FakeReply(201, {..._draft('AR000300', 5)}..remove('currentStep'));
    backend.on('PUT', '$_drafts/AR000300/*', (_) => FakeReply(200, _draft('AR000300', 5)));
    for (var i = 0; i < 4 && find.text('Submit').evaluate().isEmpty; i++) {
      await _tapButton(tester, 'Next');
    }
    expect(backend.calls('PUT', '$_drafts/AR000300/classification'), hasLength(1));
    await _tapButton(tester, 'Submit');
    expect(backend.calls('POST', '$_drafts/AR000300/submit'), hasLength(2));
    expect(find.text('Asset registered'), findsOneWidget);
    expect(find.text('AR000300'), findsWidgets);
    expect(find.textContaining('AR000300 – Diesel Generator 500 kVA'), findsOneWidget);
    await _tapButton(tester, 'View Asset');
    expect(find.text('Asset detail AR000300'), findsOneWidget);
    expect(h.router.routerDelegate.currentConfiguration.last.matchedLocation, Routes.assetDetail('AR000300'));
  });

  testWidgets('My Drafts: GET /drafts (error + Retry), resume opens the right step, delete calls DELETE', (
    tester,
  ) async {
    var listReply = const FakeReply(503, {'message': 'down'});
    var drafts = [
      _draft('AR000200', 3, basicInformation: {'assetName': 'Pump A', 'assetTag': 'P-A', 'status': 'Active'}),
      _draft('AR000201', 1, basicInformation: {'assetName': 'Pump B', 'assetTag': 'P-B', 'status': 'Active'}),
    ];
    backend
      ..on('GET', _drafts, (_) => listReply)
      ..on('GET', '$_drafts/AR000200', (_) => FakeReply(200, drafts.first))
      ..on('DELETE', '$_drafts/AR000201', (_) {
        drafts = drafts.take(1).toList();
        return const FakeReply(204);
      });
    final h = await _pump(tester, backend);
    expect(find.text('Could not load your drafts'), findsOneWidget);
    listReply = FakeReply(200, drafts);
    backend.on('GET', _drafts, (_) => FakeReply(200, drafts));
    await _tapVisible(tester, find.text('Retry'));
    expect(find.text('My Drafts (2)'), findsOneWidget);
    expect(find.textContaining('Step 3 · Location & Assignment'), findsOneWidget);

    await _tapVisible(tester, find.text('Pump A'));
    expect(backend.calls('GET', '$_drafts/AR000200'), hasLength(1));
    expect(find.text('Step 3 of 5 · Where and with whom'), findsOneWidget, reason: 'currentStep 3 → step 3');
    h.router.pop();
    await tester.pumpAndSettle();

    final gets = backend.calls('GET', _drafts).length;
    await tester.tap(find.byTooltip('Delete draft').last);
    await tester.pumpAndSettle();
    await _tapButton(tester, 'Delete');
    expect(backend.calls('DELETE', '$_drafts/AR000201'), hasLength(1));
    expect(backend.calls('GET', _drafts).length, greaterThan(gets), reason: 'list refreshed');
    expect(find.text('My Drafts (1)'), findsOneWidget);
    expect(find.text('Pump B'), findsNothing);
  });

  testWidgets('dropdowns: a server-only currency from /options; empty categories → message', (tester) async {
    final options = _json(sampleOptions);
    (options['purchaseWarranty'] as Map)['currencies'] = ['OMR - Omani Rial', 'AED - UAE Dirham'];
    backend
      ..on('GET', '/api/asset-registrations/options', (_) => FakeReply(200, options))
      ..on('GET', '/api/asset-categories', (_) => const FakeReply(200, []))
      ..on('GET', '$_drafts/AR000400', (_) => FakeReply(200, _draft('AR000400', 4)))
      // No category chosen yet, so the empty server list shows its hint.
      ..on('GET', '$_drafts/AR000401', (_) => FakeReply(200, {..._draft('AR000401', 2), 'classification': null}));
    final h = await _pump(tester, backend);

    await _openForm(tester, h, const RegistrationPrefill(draftId: 'AR000400'));
    expect(find.text('Step 4 of 5 · Cost and warranty details'), findsOneWidget);
    await _pick(tester, 'Currency', 'OMR - Omani Rial');
    expect(find.textContaining('Purchase Cost (OMR)'), findsOneWidget);
    h.router.pop();
    await tester.pumpAndSettle();
    if (find.text('Discard').evaluate().isNotEmpty) await _tapButton(tester, 'Discard');

    await _openForm(tester, h, const RegistrationPrefill(draftId: 'AR000401'));
    expect(find.text('Step 2 of 5 · Category and type'), findsOneWidget);
    expect(find.text('No categories on the server yet'), findsOneWidget);
  });

  testWidgets('Bulk CSV is not available yet; Recent Scans (mock register) is not shown', (tester) async {
    await _pump(tester, backend);
    expect(find.text('Recent Scans'), findsNothing);
    expect(find.text('My Drafts (0)'), findsOneWidget);
    await tester.tap(find.text('Bulk Registration'));
    await tester.pump();
    expect(find.text('Bulk CSV import: Not available yet.'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('photo upload sends category asset-images and stores the returned url', (tester) async {
    final dir = Directory.systemTemp.createTempSync('reg_live');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}/pump.jpg')..writeAsBytesSync(List.filled(64, 1));
    AssetImagesField.debugPickPhoto = () async => photo.path;
    backend.on('POST', _drafts, (o) {
      final basic = (_json(o.data))['basicInformation'] as Map<String, dynamic>;
      return FakeReply(201, _draft('AR000600', 1, basicInformation: basic));
    });
    final h = await _pump(tester, backend);
    await _openForm(tester, h);
    await _enter(tester, 'Asset Name', 'Pump');
    await _enter(tester, 'Asset Tag / Asset ID', 'P-6');
    await tester.ensureVisible(find.text('Add Image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Image'));
    for (var i = 0; i < 40 && find.text('Asset Images (1)').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final upload = backend.requests.singleWhere((r) => r.uri.path == '/api/media/upload');
    final form = upload.data as FormData;
    expect(form.fields.singleWhere((f) => f.key == 'category').value, 'asset-images');
    expect(find.text('Asset Images (1)'), findsOneWidget);

    await _tapButton(tester, 'Next');
    final basic = _json(backend.calls('POST', _drafts).single.data)['basicInformation'] as Map<String, dynamic>;
    expect(basic['images'], ['http://localhost:5300/uploads/asset-images/pump.jpg']);
  });
}
