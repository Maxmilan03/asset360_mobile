import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/more/documents/add_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _doc = 'DOC-2026-0045';

Future<ProviderContainer> _open(WidgetTester tester, String route, {Size size = const Size(1170, 2532)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  c.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _settleSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Small (360×640 dp) and large (430×932 dp) phones.
const _phones = [('small 360x640 phone', Size(1080, 1920)), ('large 430x932 phone', Size(1290, 2796))];

void main() {
  setUp(() => DemoClock.frozen = true);

  test('counts 64 / 8 / 42 / 6; uploads, renames, versions and deletes update them', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    DocumentsState st() => c.read(documentsProvider);
    final n = c.read(documentsProvider.notifier);
    expect(st().summary.total, 64);
    expect(st().expiringSoon, 8);
    expect(st().compliant, 42);
    expect(st().pending, 6);
    final tabs = st().summary.byBucket;
    expect([tabs['Manuals'], tabs['Warranty'], tabs['Certificates'], tabs['Others']], [12, 8, 14, 30]);
    expect(tabs.values.fold<int>(0, (a, b) => a + b), 64);

    // A warranty that expires within 30 days counts as Expiring Soon and in the Warranty tab.
    final id = n.add(
      assetId: 'GEN-00045',
      name: 'GEN-00045_Extended_Warranty.pdf',
      type: DocType.warranty,
      sizeMb: 1.2,
      expiry: DemoClock.today.add(const Duration(days: 20)),
    );
    expect(st().docs.first.id, id);
    expect(st().summary.total, 65);
    expect(st().summary.byBucket['Warranty'], 9);
    expect(st().expiringSoon, 9);
    expect(st().doc(id)!.version, 'v1.0');
    expect(st().doc(id)!.versions, hasLength(1));

    n.rename(id, 'Extended_Warranty.pdf');
    expect(st().doc(id)!.name, 'Extended_Warranty.pdf');

    expect(n.replaceVersion(_doc, fileName: 'manual.pdf', path: '/tmp/manual.pdf', sizeMb: 2.5), 'v2.2');
    expect(st().doc(_doc)!.version, 'v2.2');
    expect(st().doc(_doc)!.versions.map((v) => v.version), ['v2.2', 'v2.1', 'v2.0', 'v1.0']);
    n.restoreVersion(_doc, 'v2.0');
    expect(st().doc(_doc)!.version, 'v2.0');

    n.delete(id);
    expect(st().doc(id), isNull);
    expect(st().summary.total, 64);
    expect(st().expiringSoon, 8);
  });

  testWidgets('list: tiles filter, tabs, search, ⋮ rename and delete', (tester) async {
    final c = await _open(tester, Routes.documents);
    expect(find.text('Manage all asset related documents and files'), findsOneWidget);
    for (final t in ['64', '8', '42', '6']) {
      expect(find.text(t), findsWidgets);
    }
    expect(find.text('GEN-00045_User_Manual.pdf'), findsOneWidget);

    await _tap(tester, find.text('Expiring Soon'));
    expect(find.text('Expiring Soon (8)'), findsOneWidget);
    expect(find.text('FP-0021_Fire_Safety_Certificate.pdf'), findsOneWidget);
    expect(find.text('GEN-00045_User_Manual.pdf'), findsNothing);
    await _tap(tester, find.byTooltip('Show all'));

    await _tap(tester, find.text('Warranty (8)'));
    expect(find.text('GEN-00045_Warranty.pdf'), findsOneWidget);
    expect(find.text('GEN-00045_User_Manual.pdf'), findsNothing);
    await _tap(tester, find.text('All (64)'));

    await tester.enterText(find.byType(TextField).first, 'CNC');
    await tester.pumpAndSettle();
    expect(find.text('CNC-00123_Warranty.pdf'), findsOneWidget);
    expect(find.text('GEN-00045_Warranty.pdf'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    // ⋮ Rename on the first row (the manual).
    await _tap(tester, find.byTooltip('Document actions').first);
    await _tap(tester, find.text('Rename').last);
    await tester.enterText(find.byType(TextField).last, 'Generator_Manual');
    await _tap(tester, find.widgetWithText(FilledButton, 'Rename'));
    expect(c.read(documentsProvider).doc(_doc)!.name, 'Generator_Manual.pdf');
    await _settleSnack(tester);

    // ⋮ Delete asks first.
    final total = c.read(documentsProvider).summary.total;
    await _tap(tester, find.byTooltip('Document actions').first);
    await _tap(tester, find.text('Delete').last);
    await _tap(tester, find.widgetWithText(FilledButton, 'Delete'));
    expect(c.read(documentsProvider).doc(_doc), isNull);
    expect(c.read(documentsProvider).summary.total, total - 1);
  });

  testWidgets('details: info, inline edit, related count equals rows, restore a version', (tester) async {
    final c = await _open(tester, Routes.documentDetail(_doc));
    expect(find.text('Document Details'), findsOneWidget);
    expect(find.text('GEN-00045_User_Manual.pdf'), findsWidgets);

    await _tap(tester, find.text('Edit'));
    await tester.enterText(find.widgetWithText(TextField, 'Version'), 'v2.1a');
    await _tap(tester, find.text('Save'));
    expect(c.read(documentsProvider).doc(_doc)!.version, 'v2.1a');
    await _settleSnack(tester);

    final related = c.read(documentsProvider).forAsset('GEN-00045').length - 1;
    expect(find.text('Related Documents ($related)'), findsOneWidget);
    await _tap(tester, find.text('View All'));
    expect(find.text('View All'), findsNothing);
    for (final d in c.read(documentsProvider).forAsset('GEN-00045').where((d) => d.id != _doc)) {
      expect(find.text(d.name), findsOneWidget, reason: d.name);
    }

    // Restore v2.0 (the edit above renamed the current version, so every listed version offers Restore).
    await _tap(tester, find.text('Restore').at(1));
    await _tap(tester, find.widgetWithText(FilledButton, 'Restore'));
    expect(c.read(documentsProvider).doc(_doc)!.version, 'v2.0');
    expect(find.text('v2.0 (current)'), findsOneWidget);
  });

  testWidgets('add document: validation, expiry for warranties, upload adds to the top', (tester) async {
    AddDocumentScreen.debugPickFile = (_) async => ('GEN-00045_AMC_Warranty.pdf', '/tmp/amc.pdf', 0.8);
    addTearDown(() => AddDocumentScreen.debugPickFile = null);
    final c = await _open(tester, Routes.addDocument);
    expect(find.text('Tap to upload or drag and drop'), findsOneWidget);
    expect(find.text('Max size: 10 MB'), findsOneWidget);
    expect(find.text('Expiry Date *'), findsNothing);

    await _tap(tester, find.text('Upload Document'));
    expect(find.text('Select the asset'), findsOneWidget);
    expect(find.text('Select the document type'), findsOneWidget);
    expect(find.text('Choose a file'), findsOneWidget);
    await _settleSnack(tester);

    c.read(routerProvider).go(Routes.withAsset(Routes.addDocument, 'GEN-00045'));
    await tester.pumpAndSettle();
    expect(find.text('GEN-00045'), findsWidgets);
    expect(find.text('Select an asset'), findsNothing);

    await _tap(tester, find.byType(DropdownButtonFormField<String>).first);
    await _tap(tester, find.text(DocType.warranty).last);
    expect(find.text('Expiry Date *'), findsOneWidget);
    await _tap(tester, find.text('Tap to upload or drag and drop'));
    expect(find.text('GEN-00045_AMC_Warranty.pdf'), findsOneWidget);
    expect(find.text('819 KB'), findsOneWidget);
    // Name autofilled from the file.
    expect(find.widgetWithText(TextFormField, 'GEN-00045_AMC_Warranty'), findsOneWidget);

    // Expiry is required for a warranty.
    await _tap(tester, find.text('Upload Document'));
    expect(find.text('Select the expiry date'), findsOneWidget);
    expect(c.read(documentsProvider).summary.total, 64);
    await _settleSnack(tester);

    await _tap(tester, find.text('Select date'));
    await _tap(tester, find.text('OK'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Add a short description of the document'), 'AMC');
    await tester.pumpAndSettle();
    expect(find.text('3/500'), findsOneWidget);

    await tester.tap(find.text('Upload Document'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final st = c.read(documentsProvider);
    expect(st.summary.total, 65);
    expect(st.docs.first.name, 'GEN-00045_AMC_Warranty.pdf');
    expect(st.docs.first.expiry, DemoClock.today);
    expect(st.expiringSoon, 9);
    expect(find.text('Documents'), findsWidgets);
    expect(find.text('65'), findsWidgets);
    expect(find.text('9'), findsWidgets);
    expect(find.text('GEN-00045_AMC_Warranty.pdf'), findsOneWidget);
  });

  testWidgets('list: loading shimmer first, then rows; a search with no match shows the empty state', (tester) async {
    final c = await _open(tester, Routes.home);
    c.read(routerProvider).go(Routes.documents);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Loading'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'zzz-no-such-file');
    await tester.pumpAndSettle();
    expect(find.text('No documents match'), findsOneWidget);
    await _tap(tester, find.text('Clear filters'));
    expect(find.text('No documents match'), findsNothing);
    expect(find.text(c.read(documentsProvider).docs.first.name), findsOneWidget);
  });

  for (final (label, size) in _phones) {
    testWidgets('$label: document screens lay out without overflow', (tester) async {
      final c = await _open(tester, Routes.documents, size: size);
      for (final route in [
        Routes.documents,
        Routes.documentsTab('expiring'),
        Routes.documentsTab('pending'),
        Routes.documentsTab('certificates'),
        Routes.documentDetail(_doc),
        Routes.documentDetail('DOC-2026-0061'),
        Routes.addDocument,
        Routes.withAsset(Routes.addDocument, 'GEN-00045'),
      ]) {
        c.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }
}
