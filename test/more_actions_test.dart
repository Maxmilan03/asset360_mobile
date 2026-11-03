import 'dart:typed_data';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/disposal.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/disposals_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/add_document_action_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/add_media_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';
import 'package:asset360_mobile/features/assets/more_actions/print_tag_screen.dart';
import 'package:asset360_mobile/features/assets/more_actions/share_asset_screen.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _id = 'LAP-0098';

Future<ProviderContainer> _open(WidgetTester tester, String route) async {
  tester.view.physicalSize = const Size(1170, 2532);
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

Future<void> _tapText(WidgetTester tester, String text) => _tap(tester, find.text(text).last);

/// A FilledButton (also FilledButton.icon) by its label.
Future<void> _button(WidgetTester tester, String label) => _tap(
  tester,
  find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is FilledButton)).last,
);

/// Opens a More Actions row and checks the action screen shows the asset card.
Future<void> _action(WidgetTester tester, String row) async {
  // The last action's SnackBar may cover the bottom rows.
  for (final m in tester.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
    m.hideCurrentSnackBar();
  }
  await tester.pumpAndSettle();
  await _tapText(tester, row);
  expect(find.text(_id), findsWidgets, reason: row);
  expect(find.text('Laptop'), findsWidgets, reason: '$row: asset type on the card');
}

String _location(ProviderContainer c) => c.read(routerProvider).state.uri.toString();

Asset _asset(ProviderContainer c) => c.read(assetByIdProvider(_id))!;

void main() {
  setUp(() {
    DemoClock.frozen = true;
    // No connectivity plugin in tests (runAsync below would let its stream start).
    NetworkNotifier.listenToDevice = false;
  });
  tearDown(() => NetworkNotifier.listenToDevice = true);

  test('disposal: pending blocks a second request, approve → Disposed, reject keeps the status', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(disposalsProvider.notifier);
    final disposedBefore = c.read(orgSummaryProvider).statusCounts[AssetStatus.disposed]!;
    final approvalsBefore = c.read(homeDataProvider).pendingApprovals;

    final id = n.submit(assetId: _id, reason: 'End of Life', requestedDate: DemoClock.today)!;
    expect(c.read(disposalsProvider).pendingFor(_id)?.id, id);
    expect(n.submit(assetId: _id, reason: 'Other: again', requestedDate: DemoClock.today), isNull);
    expect(c.read(homeDataProvider).pendingApprovals, approvalsBefore + 1);
    expect(c.read(homeDataProvider).approvalTasks.map((t) => t.id), contains(id));

    n.approve(id);
    expect(c.read(disposalsProvider).first.status, DisposalStatus.approved);
    expect(c.read(assetByIdProvider(_id))!.status, AssetStatus.disposed);
    expect(c.read(orgSummaryProvider).statusCounts[AssetStatus.disposed], disposedBefore + 1);
    expect(c.read(homeDataProvider).pendingApprovals, approvalsBefore);
    // A disposed asset cannot be requested again.
    expect(n.submit(assetId: _id, reason: 'End of Life', requestedDate: DemoClock.today), isNull);

    final other = n.submit(assetId: 'MTR-00123', reason: 'Upgrade / Replacement', requestedDate: DemoClock.today)!;
    n.reject(other, 'Still in warranty');
    expect(c.read(disposalsProvider).first.rejectReason, 'Still in warranty');
    expect(c.read(assetByIdProvider('MTR-00123'))!.status, AssetStatus.active);
    expect(c.read(disposalsProvider).pendingFor('MTR-00123'), isNull);
  });

  test('condition history, favorite groups and offline queueing', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(networkProvider.notifier).setSimulatedOffline(true);
    final queued = c.read(syncProvider).pending.length;
    final assets = c.read(assetsProvider.notifier);

    assets.updateCondition(_id, condition: 'Fair', date: DemoClock.today, comments: 'Scratched lid');
    final a = c.read(assetByIdProvider(_id))!;
    expect(a.condition, 'Fair');
    expect(a.conditionHistory.single.previous, 'Good');
    expect(a.conditionHistory.single.comments, 'Scratched lid');

    expect(c.read(favoriteGroupsProvider.notifier).add('Loan Pool'), isTrue);
    expect(c.read(favoriteGroupsProvider.notifier).add('loan pool'), isFalse);
    assets.setFavorite(_id, favorite: true, group: 'Loan Pool', note: 'Spare laptop');
    expect(c.read(assetsProvider).favoritesIn('Loan Pool').map((a) => a.id), [_id]);
    // Seeded favorites carry a group too.
    expect(c.read(assetsProvider).favoritesIn('Critical Equipment').map((a) => a.id), ['GEN-00045']);

    c.read(disposalsProvider.notifier).submit(assetId: _id, reason: 'End of Life', requestedDate: DemoClock.today);
    expect(c.read(syncProvider).pending.length, queued + 1, reason: 'changes to one asset collapse into one item');
    expect(c.read(syncProvider).pending.first.subtitle, startsWith('Disposal Request'));
  });

  testWidgets('Home → More Actions → LAP-0098 → all ten actions change the asset', (tester) async {
    Uint8List? printed;
    ShareParams? shared;
    AddDocumentActionScreen.debugPickFile = (_) async => ('Dell_Latitude_Manual.pdf', '/tmp/manual.pdf', 1.2);
    AddMediaScreen.debugPickPhoto = (_) async => 'assets/images/laptop.webp';
    AddMediaScreen.debugPickVideo = (_) async => '/tmp/lap_walkaround.mp4';
    VideoPreview.debugDisablePlayer = true;
    PrintTagScreen.debugLayoutPdf = (bytes, _) async {
      printed = bytes;
      return true;
    };
    ShareAssetScreen.debugShare = (p) async => shared = p;
    addTearDown(() {
      AddDocumentActionScreen.debugPickFile = null;
      AddMediaScreen.debugPickPhoto = null;
      AddMediaScreen.debugPickVideo = null;
      VideoPreview.debugDisablePlayer = false;
      PrintTagScreen.debugLayoutPdf = null;
      ShareAssetScreen.debugShare = null;
    });

    final c = await _open(tester, Routes.home);
    await _tapText(tester, 'More Actions');
    expect(_location(c), Routes.moreActionsFrom(Routes.home));

    // Rows are greyed until an asset is selected.
    await _tapText(tester, 'Print Asset Tag');
    expect(find.text('Select an asset first'), findsOneWidget);
    expect(_location(c), Routes.moreActionsFrom(Routes.home));

    await _tapText(tester, 'Search by Asset ID or name');
    await tester.enterText(find.byType(TextField).last, _id);
    await tester.pumpAndSettle();
    await _tapText(tester, _id);
    expect(find.text('Change'), findsOneWidget);

    // 1. Check Out → Check In
    await _action(tester, 'Check in / Check Out');
    await _button(tester, 'Check Out');
    expect(find.text('Choose who takes the asset'), findsOneWidget);
    await _tapText(tester, 'Search people');
    await _tapText(tester, 'Ahmed Ali');
    await _tap(tester, find.byType(SelectField).first);
    await _tapText(tester, 'Project Work');
    await _button(tester, 'Check Out');
    expect(_location(c), Routes.moreActionsFrom(Routes.home));
    expect(_asset(c).custodian, 'Ahmed Ali (Operations)');
    expect(c.read(movementsProvider).checkedOutAssetIds, contains(_id));

    await _action(tester, 'Check in / Check Out'); // opens on Check In now
    await _tapText(tester, 'Good');
    await _button(tester, 'Check In');
    expect(_asset(c).custodian, 'Unassigned');
    expect(c.read(movementsProvider).checkedOutAssetIds, isNot(contains(_id)));

    // 2. Assign Custodian
    await _action(tester, 'Assign Custodian');
    await _tapText(tester, 'Search by name or employee ID');
    await _tapText(tester, 'Mohammed Rafi');
    expect(find.text('Custodian Details'), findsOneWidget);
    expect(find.text('EMP-RAFI'), findsOneWidget);
    await _button(tester, 'Assign Custodian');
    expect(_asset(c).custodian, 'Mohammed Rafi (Maintenance Technician)');

    // 3. Update Condition
    await _action(tester, 'Update Condition');
    await _tapText(tester, 'Fair');
    await _button(tester, 'Update Condition');
    expect(_asset(c).condition, 'Fair');
    expect(_asset(c).conditionHistory, hasLength(1));

    // 4. Add Document
    await _action(tester, 'Add Document');
    await _button(tester, 'Upload Document');
    expect(find.text('Choose the document type'), findsOneWidget);
    await _tap(tester, find.byType(SelectField).first);
    await _tapText(tester, 'Manual');
    await _tapText(tester, 'Tap to upload or drag and drop');
    await _button(tester, 'Upload Document');
    expect(c.read(documentsProvider).forAsset(_id).map((d) => d.name), contains('Dell_Latitude_Manual.pdf'));

    // 5. Add Photo / Video
    final photos = _asset(c).photos.length;
    await _action(tester, 'Add Photo / Video');
    await _tapText(tester, 'Take or choose a photo');
    await _button(tester, 'Save Photo');
    expect(_asset(c).photos.length, photos + 1);
    await _action(tester, 'Add Photo / Video');
    await _tapText(tester, 'Video');
    await _tapText(tester, 'Choose Video');
    await tester.enterText(find.byType(TextField).last, 'Walk-around');
    await _button(tester, 'Save Video');
    expect(_asset(c).videos.single.caption, 'Walk-around');

    // 6. View on Map
    await _action(tester, 'View on Map');
    expect(find.text('Current Location'), findsOneWidget);
    await _tap(tester, find.byTooltip('Zoom in'));
    await _tap(tester, find.byTooltip('Recenter'));
    await _tapText(tester, 'Building A');
    await _tapText(tester, 'Building B');
    expect(find.textContaining('is on Building A, not on Building B'), findsOneWidget);
    expect(find.text('Open in Tracking'), findsNothing); // LAP-0098 has no IoT device
    await _tap(tester, find.byTooltip('Back'));

    // 7. Add to Favorites
    await _action(tester, 'Add to Favorites');
    await _tap(tester, find.byType(Switch).first);
    await _tapText(tester, 'My Assets (1)');
    await _tapText(tester, 'IT Equipment (0)');
    await _button(tester, 'Save to Favorites');
    expect(_asset(c).favorite, isTrue);
    expect(_asset(c).favoriteGroup, 'IT Equipment');

    // 8. Print Asset Tag (system print dialog with the PDF; copies applied)
    await _action(tester, 'Print Asset Tag');
    expect(find.text('Live Preview'), findsOneWidget);
    await _tap(tester, find.byTooltip('More copies'));
    final print = find.ancestor(of: find.text('Print'), matching: find.byWidgetPredicate((w) => w is FilledButton));
    await tester.ensureVisible(print);
    await tester.tap(print);
    // The PDF is built with real async work (fonts, logo decode).
    for (var i = 0; i < 20 && printed == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(String.fromCharCodes(printed!.take(4)), '%PDF');
    expect(find.text('Printed 2 labels for $_id'), findsOneWidget);

    // 9. Share (system share sheet; only the switched-on parts)
    await _action(tester, 'Share Asset Details');
    await _tap(tester, find.widgetWithText(SwitchListTile, 'Custodian'));
    await _tap(tester, find.widgetWithText(SwitchListTile, 'Photos'));
    final share = find.ancestor(of: find.text('Share'), matching: find.byWidgetPredicate((w) => w is FilledButton));
    await tester.ensureVisible(share);
    await tester.tap(share);
    for (var i = 0; i < 20 && shared == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(shared!.text, contains(_id));
    expect(shared!.text, contains('Location'));
    expect(shared!.text, isNot(contains('Custodian')));
    expect(shared!.files, hasLength(1));
    expect(shared!.text, contains('https://asset360.purpleiq.ae/a/$_id'));

    // 10. Create Disposal Request
    await _action(tester, 'Create Disposal Request');
    await _tap(tester, find.byType(SelectField).first);
    await _tapText(tester, 'Other');
    await _button(tester, 'Submit Request');
    expect(find.text('Describe the reason'), findsOneWidget);
    expect(find.text('Choose the requested date'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Battery swollen');
    await _tapText(tester, 'Select date');
    await _tapText(tester, 'OK');
    await _button(tester, 'Submit Request');
    expect(find.text('Disposal request submitted'), findsOneWidget);
    await _tapText(tester, 'Done');
    expect(_location(c), Routes.moreActionsFrom(Routes.home));
    expect(find.text('Disposal pending'), findsOneWidget);

    // A second request is blocked.
    await _action(tester, 'Create Disposal Request');
    expect(find.textContaining('A second request cannot be made'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit Request')).onPressed, isNull);

    // The asset page shows the changes.
    c.read(routerProvider).go(Routes.assetDetail(_id, tab: 'history'));
    await tester.pumpAndSettle();
    expect(find.text('Disposal pending'), findsOneWidget);
    expect(find.text('Condition History (1)'), findsOneWidget);
    expect(find.text('Good → Fair'), findsOneWidget);
    await _tapText(tester, 'Documents');
    expect(find.text('Dell_Latitude_Manual.pdf'), findsOneWidget);
    expect(find.text('Walk-around'), findsOneWidget);
    c.read(routerProvider).go(Routes.assetDetail(_id));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from Favorites'), findsOneWidget);

    // Approve from Home → Approvals → Disposed.
    c.read(routerProvider).go(Routes.approvals);
    await tester.pumpAndSettle();
    expect(find.text('Other: Battery swollen'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Approve').first); // disposal cards come first
    expect(find.text('Approve DSP-2026-0001?'), findsOneWidget);
    await _button(tester, 'Approve'); // confirm dialog
    expect(_asset(c).status, AssetStatus.disposed);
    expect(c.read(disposalsProvider).pendingFor(_id), isNull);
  });

  testWidgets('Asset page: More Actions tile and ⋮ open More Actions with the asset selected', (tester) async {
    final c = await _open(tester, Routes.assetDetail('MTR-00123'));
    await _tapText(tester, 'More Actions');
    expect(_location(c), Routes.moreActionsFrom(Routes.assets, assetId: 'MTR-00123'));
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Main Motor – Line 1'), findsOneWidget);
    await _tap(tester, find.byTooltip('Back'));
    // Back at the top of the asset page (the tile tap scrolled the header away).
    await tester.drag(find.byType(SegmentTabs), const Offset(0, 1200));
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('More'));
    await _tapText(tester, 'More Actions');
    expect(_location(c), Routes.moreActionsFrom(Routes.assets, assetId: 'MTR-00123'));
    await _tapText(tester, 'View on Map');
    expect(find.text('Open in Tracking'), findsOneWidget); // MTR-00123 has an IoT device
    await _tap(tester, find.byTooltip('Back'));
    await _tap(tester, find.byTooltip('Back'));
    await tester.drag(find.byType(SegmentTabs), const Offset(0, 1200));
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('More'));
    await _tapText(tester, 'Print Tag');
    expect(_location(c), Routes.moreActionFrom(Routes.assets, 'print-tag', 'MTR-00123'));
  });

  testWidgets('Rejecting a disposal asks for a reason', (tester) async {
    final c = await _open(tester, Routes.home);
    c.read(disposalsProvider.notifier).submit(assetId: _id, reason: 'End of Life', requestedDate: DemoClock.today);
    c.read(routerProvider).go(Routes.approvals);
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(OutlinedButton, 'Reject').first);
    await _tap(tester, find.widgetWithText(FilledButton, 'Reject'));
    expect(find.text('Please enter a reason'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Can be repaired');
    await _tap(tester, find.widgetWithText(FilledButton, 'Reject'));
    expect(c.read(disposalsProvider).single.status, DisposalStatus.rejected);
    expect(_asset(c).status, AssetStatus.active);
  });

  for (final size in [const Size(1080, 1920), const Size(1290, 2796)]) {
    testWidgets('${size.width ~/ 3}x${size.height ~/ 3} phone: More Actions and every action screen lay out', (
      tester,
    ) async {
      VideoPreview.debugDisablePlayer = true;
      addTearDown(() => VideoPreview.debugDisablePlayer = false);
      final c = await _open(tester, Routes.home);
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final router = c.read(routerProvider);
      for (final route in [
        Routes.moreActionsFrom(Routes.home),
        Routes.moreActionsFrom(Routes.home, assetId: 'MTR-00123'),
        for (final a in MoreAction.values) Routes.moreActionFrom(Routes.more, a.slug, 'CNC-00123'),
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route (scrolled)');
      }
      // Tabs of the two tabbed screens.
      router.go(Routes.moreActionFrom(Routes.more, 'check-in-out', 'CNC-00123'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Check In');
      router.go(Routes.moreActionFrom(Routes.more, 'media', 'CNC-00123'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Video');
      for (final t in ['Small Label', 'QR Only']) {
        router.go(Routes.moreActionFrom(Routes.more, 'print-tag', 'CNC-00123'));
        await tester.pumpAndSettle();
        await _tap(tester, find.byType(SelectField).first);
        await _tapText(tester, t);
        expect(tester.takeException(), isNull, reason: t);
      }
    });
  }
}
