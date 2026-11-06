import 'dart:convert';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_repository.dart';
import 'package:asset360_mobile/data/api/token_store.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/live/live_assignment_screens.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_asset_backend.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _ar1 = '/api/asset-registrations/AR000001';

Map<String, dynamic> _json(Object? data) => jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

/// The sample assignment as the app sends it back (same values; dates in Dart's ISO format).
Map<String, dynamic> _loadedAssignment() =>
    _json(AssetRegistration.fromJson(sampleRegistration()).locationAssignment.assignment.toJson());

/// Edit (PUT, complete sections), Delete (soft delete), Move (PUT locationAssignment) and the status
/// chip colours, against the fake Asset service.
void main() {
  // ---------------------------------------------------------------- the update request

  group('UpdateAssetRegistrationRequest.changes', () {
    AssetRegistration loaded() => AssetRegistration.fromJson(sampleRegistration()).copy();

    test('nothing changed → nothing to send', () {
      final r = loaded();
      expect(UpdateAssetRegistrationRequest.changes(r, r.copy()).isEmpty, isTrue);
    });

    test('a changed field sends its WHOLE section, every other value as loaded; other sections left out', () {
      final original = loaded();
      final edited = original.copy()..basicInformation.status = 'In Storage';
      final body = _json(UpdateAssetRegistrationRequest.changes(original, edited).toJson());
      expect(body.keys, ['basicInformation']);
      expect(body['basicInformation'], {...(sampleRegistration()['basicInformation'] as Map), 'status': 'In Storage'});
    });

    test('criticality lives in two sections: both are sent complete', () {
      final original = loaded();
      final edited = original.copy()..criticality = 'Medium';
      final body = _json(UpdateAssetRegistrationRequest.changes(original, edited).toJson());
      expect(body.keys, ['basicInformation', 'classification']);
      expect(body['classification'], {...(sampleRegistration()['classification'] as Map), 'criticality': 'Medium'});
    });

    test('move: the new Master Data location + the current assignment unchanged; GPS of the old place cleared', () {
      final original = loaded();
      final tree = MdLocationIndex(MdLocationNode.parseTree(mdLocationTree));
      final moved = movedTo(original, tree.pathTo(tree.byId('loc-z1')!));
      final body = _json(UpdateAssetRegistrationRequest.changes(original, moved).toJson());
      expect(body.keys, ['locationAssignment']);
      final la = body['locationAssignment'] as Map;
      expect(la['assignment'], _loadedAssignment(), reason: 'the assignment as loaded');
      expect(la['location'], {
        'projectId': null,
        'countryId': 'loc-ae',
        'countryName': 'UAE',
        'siteId': 'loc-ms',
        'siteName': 'Main Site',
        'buildingId': 'loc-ba',
        'buildingName': 'Block A',
        'floorId': 'loc-gf',
        'floorName': 'Ground',
        'zoneId': 'loc-z1',
        'zoneName': 'Zone 1',
        'roomId': null,
        'roomName': null,
        'locationPath': 'UAE > Main Site > Block A > Ground > Zone 1',
        'latitude': null,
        'longitude': null,
      });
    });
  });

  // ---------------------------------------------------------------- status colours

  test('status chips: green Active / Available, blue Assigned, amber maintenance / repair / storage, '
      'red out of service / disposed, grey Inactive and unknown', () {
    Color c(String s) => ChipTone.forAsset(s).foreground;
    for (final s in ['Active', 'Available']) {
      expect(c(s), AppColors.green, reason: s);
    }
    expect(c('Assigned'), ChipTone.blue.foreground);
    for (final s in ['Under Maintenance', 'In Repair', 'In Storage']) {
      expect(c(s), AppColors.amber, reason: s);
    }
    for (final s in ['Out of Service', 'Disposed']) {
      expect(c(s), AppColors.red, reason: s);
    }
    for (final s in ['Inactive', 'Retired', 'Something new']) {
      expect(AssetOptions.toneOf(s), OptionTone.grey, reason: s);
    }
    expect(AssetOptions.toneOf('in storage'), OptionTone.amber, reason: 'case-insensitive');
  });

  // ---------------------------------------------------------------- screens

  late FakeAssetBackend backend;

  setUp(() {
    backend = FakeAssetBackend();
    debugApiMode = true;
    NetworkNotifier.listenToDevice = false;
  });

  tearDown(() {
    debugApiMode = null;
    NetworkNotifier.listenToDevice = true;
  });

  Future<ProviderContainer> open(WidgetTester tester, [String? push]) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
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
    c.read(routerProvider).go(Routes.assets);
    await tester.pumpAndSettle();
    c.read(routerProvider).push(Routes.assetDetail('AR000001'));
    await tester.pumpAndSettle();
    if (push != null) {
      c.read(routerProvider).push(push);
      await tester.pumpAndSettle();
    }
    return c;
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith('$label#') && w is FormField;
  });

  /// A FilledButton (also FilledButton.icon) by its label.
  Finder button(String label) =>
      find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is FilledButton)).last;

  Map<String, dynamic> put() => _json(backend.calls('PUT', _ar1).single.data);

  Future<void> menu(WidgetTester tester, String item) async {
    await tap(tester, find.byTooltip('More').first);
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Edit Asset: wizard pre-filled; Next through every step changes nothing; Save changes sends only '
      'the complete Basic Information section; detail refreshed', (tester) async {
    await open(tester);
    await menu(tester, 'Edit Asset');
    expect(find.text('Edit Asset'), findsWidgets);
    expect(find.text('Save as Draft'), findsNothing);

    await tester.enterText(field('Asset Name').first, 'Diesel Generator 500 kVA (B)');
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tap(tester, find.text('Next'));
    }
    expect(find.text('Review your changes before saving'), findsOneWidget, reason: 'every step passed its checks');
    expect(backend.requests.where((r) => r.method != 'GET'), isEmpty, reason: 'Next saves nothing');

    await tap(tester, find.text('Save changes'));
    final body = put();
    expect(body.keys, ['basicInformation'], reason: 'only the changed section');
    expect(body['basicInformation'], {
      ...(sampleRegistration()['basicInformation'] as Map),
      'assetName': 'Diesel Generator 500 kVA (B)',
    });
    expect(find.textContaining('changes saved (Basic Information)'), findsOneWidget);
    expect(find.text('Diesel Generator 500 kVA (B)'), findsWidgets, reason: 'detail reloaded');
    expect(backend.calls('GET', _ar1).length, greaterThan(1));
  });

  testWidgets('Edit Asset: no change → nothing sent; a 400 opens the step with the error; 409 under the tag', (
    tester,
  ) async {
    await open(tester, Routes.assetEdit('AR000001'));
    Future<void> toReview(int from) async {
      for (var i = from; i < 5; i++) {
        await tap(tester, find.text('Next'));
      }
      expect(find.text('Save changes'), findsOneWidget);
    }

    await toReview(0);
    await tap(tester, find.text('Save changes'));
    expect(find.text('No changes to save'), findsOneWidget);
    expect(backend.calls('PUT', _ar1), isEmpty);

    await tap(tester, find.text('Basic'));
    await tester.enterText(field('Serial Number').first, 'SN-1');
    await tester.pumpAndSettle();
    backend.on(
      'PUT',
      _ar1,
      (_) => const FakeReply(400, {
        'title': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {
          'Classification.Department': ['Department is required'],
        },
      }),
    );
    await toReview(0);
    await tap(tester, find.text('Save changes'));
    expect(
      find.descendant(of: field('Department').first, matching: find.text('Department is required')),
      findsOneWidget,
      reason: 'the step of the error opens',
    );

    backend.on(
      'PUT',
      _ar1,
      (_) => const FakeReply(409, {'message': "An asset with tag 'TAG-0001' is already registered."}),
    );
    await toReview(1);
    await tap(tester, find.text('Save changes'));
    expect(
      find.descendant(
        of: field('Asset Tag / Asset ID').first,
        matching: find.text("An asset with tag 'TAG-0001' is already registered."),
      ),
      findsOneWidget,
    );
    expect(backend.calls('PUT', _ar1), hasLength(2));
  });

  testWidgets('Key Information: inline Edit → Status saved with the complete Basic Information section', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Key Information'), findsOneWidget);
    await tap(tester, find.text('Edit').first);
    await tap(tester, field('Status').first);
    await tester.tap(find.text('In Storage').last);
    await tester.pumpAndSettle();
    await tap(tester, button('Save'));

    final body = put();
    expect(body.keys, ['basicInformation']);
    expect(body['basicInformation'], {...(sampleRegistration()['basicInformation'] as Map), 'status': 'In Storage'});
    expect(find.text('Key information saved'), findsOneWidget);
    final chip = tester.widget<StatusChip>(find.widgetWithText(StatusChip, 'In Storage').first);
    expect(chip.tone?.foreground, AppColors.amber);
  });

  testWidgets('Delete: confirm "removed from lists" → DELETE → back on the refreshed list', (tester) async {
    final c = await open(tester);
    final listCalls = backend.calls('GET', '/api/asset-registrations').length;
    await menu(tester, 'Delete');
    expect(find.text('The asset will be removed from lists.'), findsOneWidget);
    await tap(tester, find.text('Cancel').last);
    expect(backend.calls('DELETE', _ar1), isEmpty);

    await menu(tester, 'Delete');
    await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
    expect(backend.calls('DELETE', _ar1), hasLength(1));
    expect(c.read(routerProvider).state.uri.path, Routes.assets);
    expect(find.text('Diesel Generator 500 kVA deleted'), findsOneWidget);
    expect(backend.calls('GET', '/api/asset-registrations').length, greaterThan(listCalls), reason: 'list reloaded');
    expect(find.text('TAG-0001'), findsNothing, reason: 'gone from the list');
  });

  testWidgets('Move Asset: PUT with the complete locationAssignment (new location, assignment unchanged)', (
    tester,
  ) async {
    await open(tester, Routes.withAsset(Routes.transferAsset, 'AR000001'));
    Future<void> pick(String label, String option) async {
      await tap(tester, field(label).first);
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    await pick('Country', 'UAE');
    await pick('Site', 'Main Site');
    await pick('Building', 'Block A');
    await pick('Floor', 'First');
    await tap(tester, button('Move'));
    final body = put();
    expect(body.keys, ['locationAssignment']);
    final la = body['locationAssignment'] as Map;
    expect(la['assignment'], _loadedAssignment());
    expect(
      [
        (la['location'] as Map)['floorId'],
        (la['location'] as Map)['floorName'],
        (la['location'] as Map)['locationPath'],
      ],
      ['loc-f1', 'First', 'UAE > Main Site > Block A > First'],
    );
    expect(find.text('Diesel Generator 500 kVA moved to UAE > Main Site > Block A > First'), findsOneWidget);
  });
}
