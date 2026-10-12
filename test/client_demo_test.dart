import 'dart:async';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/client_demo.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts the app already signed in (with "Remember me"), so the splash goes to Home.
class _SignedInSession extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(_SignedInSession.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Asset360App)));
}

/// The location on top (pushed routes included).
String _location(ProviderContainer c) => c.read(routerProvider).state.uri.toString();

Future<void> _go(WidgetTester tester, ProviderContainer c, String route) async {
  c.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  expect(_location(c), route);
}

bool _exists(Finder f) {
  try {
    return f.evaluate().isNotEmpty;
  } on StateError {
    return false; // `.first` of nothing
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  // Lazy lists only build what is near the viewport: scroll back up until [f] exists.
  for (var i = 0; i < 8 && !_exists(f); i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Taps [f] and checks nothing happened: same location, no SnackBar, sheet, dialog or menu.
Future<void> _expectInert(WidgetTester tester, ProviderContainer c, Finder f) async {
  final before = _location(c);
  await _tap(tester, f);
  expect(_location(c), before, reason: '$f navigated');
  expect(find.byType(SnackBar), findsNothing, reason: '$f showed a SnackBar');
  expect(find.byType(BottomSheet), findsNothing, reason: '$f opened a sheet');
  expect(find.byType(Dialog), findsNothing, reason: '$f opened a dialog');
  expect(find.byType(PopupMenuItem<String>), findsNothing, reason: '$f opened a menu');
}

void main() {
  setUp(() {
    DemoClock.frozen = true;
    debugClientDemo = true;
  });
  tearDown(() => debugClientDemo = false);

  testWidgets('Home: listed links work, everything else is inert, the router refuses other screens', (tester) async {
    final c = await _pumpApp(tester);
    expect(_location(c), Routes.home);

    for (final f in [
      find.text('Inspections').first,
      find.text('Approvals').first,
      find.text('Critical Alert'),
      find.text('Report Issue'),
      find.text('Start Inspection'),
      find.text('Asset Audit').first,
      find.text('More Actions'),
      find.text('Customize'),
      find.byTooltip('Notifications'),
      find.byTooltip('Account menu'),
      find.byTooltip('Select site'),
    ]) {
      await _expectInert(tester, c, f);
    }

    // Safety net: a screen that is not allowed is refused, go or push.
    c.read(routerProvider).go(Routes.alerts);
    await tester.pumpAndSettle();
    expect(_location(c), Routes.home);
    unawaited(c.read(routerProvider).push(Routes.inspectionDetail('INS-2026-0001')));
    await tester.pumpAndSettle();
    expect(_location(c), Routes.home);
    expect(find.text('Quick Actions'), findsOneWidget);

    await _tap(tester, find.text('Work Orders').first);
    expect(_location(c), Routes.maintenanceTab('mine'));
    await _go(tester, c, Routes.home);
    await _tap(tester, find.text('Move Asset'));
    expect(_location(c), Routes.transferAsset);
    await _go(tester, c, Routes.home);
    await _tap(tester, find.text('Inventory Issue'));
    expect(_location(c), Routes.inventory);
  });

  testWidgets('Scan → Manual Entry CNC-00123 opens Asset detail directly; all 8 tabs open', (tester) async {
    final c = await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan & Identify'), findsOneWidget);
    await _expectInert(tester, c, find.text('Multi Scan'));
    await _expectInert(tester, c, find.byIcon(Icons.history_rounded));

    await tester.tap(find.text('Manual Entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'CNC-00123');
    await tester.pump();
    await tester.tap(find.text('Find Asset'));
    await tester.pumpAndSettle();
    expect(_location(c), Routes.assetDetail('CNC-00123'));
    expect(find.text('Asset Identified'), findsNothing);

    for (final tab in [
      'Location',
      'IoT',
      'Maintenance',
      'Inspection',
      'Financial',
      'Documents',
      'History',
      'Overview',
    ]) {
      await _tap(tester, find.text(tab).first);
      expect(_location(c), Routes.assetDetail('CNC-00123'));
    }
  });

  testWidgets('Asset detail: blocked actions are inert, favourite and Move Asset work', (tester) async {
    final c = await _pumpApp(tester);
    await _go(tester, c, Routes.assetDetail('CNC-00123'));
    for (final label in [
      'Create Work Order',
      'Create Inspection',
      'Report Issue',
      'Check Out',
      'View on Map',
      'Add Photo',
      'More Actions',
    ]) {
      await _expectInert(tester, c, find.text(label).first);
    }
    await _expectInert(tester, c, find.byTooltip('More'));

    final before = c.read(assetsProvider).byCode('CNC-00123')!.favorite;
    await _tap(tester, find.byTooltip(before ? 'Remove from Favorites' : 'Add to Favorites'));
    expect(c.read(assetsProvider).byCode('CNC-00123')!.favorite, !before);

    await _tap(tester, find.text('Move Asset').first);
    expect(_location(c), Routes.withAsset(Routes.transferAsset, 'CNC-00123'));
  });

  testWidgets('Work order: only Overview; Close is inert; Update Status opens', (tester) async {
    final c = await _pumpApp(tester);
    await _go(tester, c, Routes.workOrder('WO-2026-0045'));
    await _expectInert(tester, c, find.text('Tasks'));
    expect(find.text('Issue Description'), findsOneWidget); // still on Overview
    await _expectInert(tester, c, find.text('Close Work Order'));
    await _tap(tester, find.text('Update Status'));
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('Stock Movement: other tabs and GRN links are inert; a WO link opens the work order', (tester) async {
    final c = await _pumpApp(tester);
    await _go(tester, c, Routes.partStock('BR-6205'));
    await _expectInert(tester, c, find.text('Usage'));
    await _expectInert(tester, c, find.textContaining('REF: GRN-').first);
    await _tap(tester, find.textContaining('REF: WO-').first);
    expect(_location(c), startsWith('/work/maintenance/orders/WO-'));
  });

  testWidgets('More sheet: blocked tiles inert, Inventory opens, Logout → Login', (tester) async {
    final c = await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    expect(find.text('All Modules'), findsOneWidget);
    for (final label in ['Tracking & IoT', 'Inspection', 'Administration', 'Offline Sync', 'Profile']) {
      final tile = find.descendant(of: find.byType(BottomSheet), matching: find.text(label));
      await _tap(tester, tile);
      expect(find.text('All Modules'), findsOneWidget, reason: label);
      expect(_location(c), Routes.home, reason: label);
    }
    await _tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Inventory')));
    expect(_location(c), Routes.inventory);

    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    await _tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Logout')));
    expect(find.text('Are you sure you want to log out of Asset360?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(_location(c), Routes.login);
  });
}
