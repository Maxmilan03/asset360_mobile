import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/csv.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/registration/bulk_import.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

void main() {
  setUp(() => DemoClock.frozen = true);

  test('CSV parser handles quotes and escaped quotes', () {
    expect(parseCsv('a,"b, c","say ""hi"""\r\n\n1,2,3'), [
      ['a', 'b, c', 'say "hi"'],
      ['1', '2', '3'],
    ]);
  });

  test('sample bulk CSV: 3 valid rows, the reused CNC-00123 tag is rejected', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final rows = validateBulkCsv(sampleBulkCsv, (v) => c.read(assetsProvider.notifier).ownerOf(v)?.id);
    expect(rows.where((r) => r.valid).length, 3);
    final bad = rows.singleWhere((r) => !r.valid);
    expect(bad.id, 'UPS-00001');
    expect(bad.errors, contains('tag_id already used by CNC-00123'));
  });

  testWidgets('register a new asset end to end; duplicates are blocked', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    c.read(routerProvider).go(Routes.registration);
    await tester.pumpAndSettle();
    expect(find.text('Capture Asset Information'), findsOneWidget);
    expect(find.text('Existing'), findsNWidgets(3));

    await tester.tap(find.text('Manual Entry'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'MTR-00123');
    await tester.enterText(fields.at(1), 'Spare Motor – Line 3');
    await tester.enterText(fields.at(3), 'RFID-A360-000123');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Already used by MTR-00123'), findsOneWidget);
    expect(find.text('Already used by CNC-00123'), findsOneWidget);

    await tester.enterText(fields.at(3), '');
    await tester.tap(find.text('Suggest next ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Electric Motor').last);
    await tester.pumpAndSettle();
    expect(find.text('MTR-00124'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2: category and type came from the suggestion.
    expect(find.text('Classification'), findsWidgets);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3: cascading Site → Building → Floor.
    expect(find.text('Choose the category and asset type'), findsNothing);
    expect(find.text('Room / Zone'), findsOneWidget);
    for (final (hint, option) in [('Select', 'Dubai Factory'), ('Select', 'Main Plant'), ('Select', 'Floor 2')]) {
      await tester.tap(find.text(hint).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 4: warranty is required.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the warranty expiry'), findsOneWidget);
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Asset details are ready to be registered'), findsOneWidget);
    await tester.tap(find.text('Register Asset'));
    await tester.pumpAndSettle();
    expect(find.text('Asset registered'), findsOneWidget);
    expect(c.read(assetByIdProvider('MTR-00124'))?.location, 'Main Plant / Floor 2');
    expect(c.read(orgSummaryProvider).totalAssets, 12459);
    expect(c.read(assetsProvider).search('Spare Motor').single.id, 'MTR-00124');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget); // Recent Scans on the hub

    // Unmount and dispose now so the provider timers (clock tick) stop before the test ends.
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
